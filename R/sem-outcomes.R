# Version 1 outcome ledger (D1, reconciled with ADR D-11 and D-12).
#
# Internal. Every native fit, every zero-product branch and every MBCO null leaves a node of retained evidence: a
# stable ID, the exact restriction, the estimation sample and likelihood domain, the optimizer's acceptance state,
# feasibility, covariance availability and the original condition. Enumeration completeness (every required
# restriction was attempted) is not a global-optimum certificate, and a node never asserts feasibility it did not
# witness.
#
# The ledger does not change what a failure is. An unresolved required zero-product branch is still the classed
# error `medfit_error_no_convergence` (D-11, never a fit), now carrying the ledger as `$ledger` and the survivor's
# discrepancy as `$best_survivor` (diagnostic only, never a p-value). `mbco_sem()` keeps its unresolved result
# (#300) and carries the same field. Evidence a consumer cannot trust (missing, malformed, mismatched) is refused
# with `medfit_error_ledger`, a class of its own so that no caller mistakes it for an optimizer failure.

# Branch map (D3). A zero-product union fits every raw combination of parser-produced factors, duplicates included,
# in the grid's original order (ties go to the first), so the cap is on the RAW count, never on the number of
# distinct restriction sets. The count is a product checked for overflow before each step: it is an integer up to
# `.Machine$integer.max`, a double above it, and `Inf` once a further factor would overflow a double. Above 2^53 a
# double count need not be an exact cardinality; the refusal message says so.
.sem_raw_count <- function(counts) {
  if (any(!is.finite(counts) | counts < 1 | counts != floor(counts))) {
    stop("factor counts must be finite positive integers")
  }
  count <- 1
  for (n in counts) {
    if (count > .Machine$double.xmax / n) {
      return(Inf)
    }
    count <- count * n
  }
  if (count <= .Machine$integer.max) as.integer(count) else count
}

# The text of a raw count in a refusal: no scientific notation, "approximately" above 2^53, overflow named.
.sem_raw_count_text <- function(count) {
  if (is.infinite(count)) {
    return("overflow (Inf)")
  }
  paste0(if (count > 2^53) "approximately " else "", format(count, scientific = FALSE, trim = TRUE, digits = 22L))
}

.sem_branch_grid <- function(products) {
  do.call(expand.grid, c(lapply(products, `[[`, "factors"), stringsAsFactors = FALSE))
}

# `raw_to_canonical[b]` is a structural ID of raw row `b`: the sorted, distinct parsed constraint rows after the
# row's factors are set to zero. Duplicate or permuted products collapse; no affine solving or subsumption, so it is
# not an equivalence certificate. Over the cap nothing is enumerated: the state is `not_enumerated`, the unique
# count unknown, and there is no raw mapping.
.sem_branch_map <- function(constraints) {
  products <- .sem_zero_product_rows(constraints)
  if (!length(products)) {
    return(NULL)
  }
  counts <- vapply(products, function(p) length(p$factors), 0L)
  count <- .sem_raw_count(counts)
  out <- list(state = "not_enumerated", raw_count = count, factor_counts = counts,
              unique_count = NA_integer_, raw_to_canonical = NULL)
  if (count > 64L) {
    return(out)
  }
  grid <- .sem_branch_grid(products)
  # Length-prefixed fields make structural IDs unambiguous without a hash dependency.
  encode <- function(x) paste0(nchar(x, type = "bytes"), ":", x, collapse = "")
  ids <- vapply(seq_len(count), function(b) {
    cons <- constraints
    for (j in seq_along(products)) {
      cons$lhs[products[[j]]$row] <- grid[b, j]
      cons$rhs[products[[j]]$row] <- "0"
    }
    rows <- vapply(seq_len(nrow(cons)), function(i) {
      encode(trimws(unlist(cons[i, c("lhs", "op", "rhs")], use.names = FALSE)))
    }, "")
    encode(sort(unique(rows), method = "radix"))
  }, "")
  out$state <- "complete"
  out$unique_count <- length(unique(ids))
  out$raw_to_canonical <- ids
  out
}

.sem_condition_record <- function(e) {
  if (is.null(e)) {
    return(NULL)
  }
  list(class = class(e), message = conditionMessage(e), call = conditionCall(e))
}

# Literal zero/nonzero certificate (D2). Exact syntax proof only: an explicit `label == 0` equality and an explicit
# finite nonzero literal equality on the same parsed parameter label. No expression evaluation, tolerance, solver
# status, bounds or row-space inference is ever the proof, and a fixed value in the parameter table is not a premise
# (public syntax cannot label a fixed coefficient). An underflowed literal (`1e-999`) is unknown, never a zero.
# Returns the certificate (method, label, the two source rows with their values) or NULL (unknown, not "feasible").
.sem_literal_zero_certificate <- function(parameters, constraints) {
  if (!is.data.frame(parameters) || !all(c("label", "fixed") %in% names(parameters)) ||
        !is.data.frame(constraints) || !all(c("lhs", "op", "rhs") %in% names(constraints))) {
    return(NULL)
  }
  labels <- unique(parameters$label[nzchar(parameters$label)])
  rows <- list()
  literal <- function(text) {
    text <- trimws(text)
    if (!grepl("^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?$", text)) {
      return(NA_real_)
    }
    value <- as.numeric(text)
    # underflow is not a zero-fixing proof
    if (!is.finite(value) || (value == 0 && grepl("[1-9]", strsplit(text, "[eE]")[[1L]][1L]))) {
      return(NA_real_)
    }
    value
  }
  for (i in which(constraints$op == "==")) {
    for (side in c("lhs", "rhs")) {
      label <- trimws(constraints[[side]][i])
      value <- literal(constraints[[if (side == "lhs") "rhs" else "lhs"]][i])
      if (label %in% labels && !is.na(value)) {
        rows[[length(rows) + 1L]] <- list(label = label, value = value, source = "constraint", row = i)
      }
    }
  }
  for (label in labels) {
    mine <- Filter(function(x) identical(x$label, label), rows)
    zero <- Filter(function(x) x$value == 0, mine)
    nonzero <- Filter(function(x) x$value != 0, mine)
    if (length(zero) && length(nonzero)) {
      return(list(method = "literal_zero_nonzero", label = label, zero = zero[[1L]], nonzero = nonzero[[1L]]))
    }
  }
  NULL
}

# The text of a direct contradiction: the proof's two rows, in the optimizer's old wording ("constraint ... violated").
.sem_certificate_message <- function(constraints, certificate) {
  row <- function(r) sprintf("%s %s %s", constraints$lhs[r], constraints$op[r], constraints$rhs[r])
  sprintf("literal zero/nonzero contradiction: constraint '%s' is violated by the literal equality '%s'",
          row(certificate$zero$row), row(certificate$nonzero$row))
}

# A certified-empty node: retained, never optimized (outcome `excluded`, likelihood unavailable). It is not a fit.
.sem_excluded_outcome <- function(context, constraints, certificate) {
  node <- .sem_outcome(context, constraints, error = simpleError("literal zero/nonzero contradiction"))
  node$outcome <- "excluded"
  node$feasibility <- "certified_empty"
  node$certificate <- certificate
  node
}

# The certificate is reconstructed from the node's own parsed parameters and constraints and must equal the stored
# one; any field of an excluded node that a real one would not have refuses it.
.sem_valid_exclusion <- function(x) {
  tryCatch({
    proof <- .sem_literal_zero_certificate(x$context$model$parameters, x$constraints)
    !is.null(proof) && identical(x$certificate, proof) &&
      identical(x$schema_version, 1L) && identical(x$outcome, "excluded") &&
      identical(x$feasibility, "certified_empty") && identical(x$optimizer$state, "unresolved") &&
      identical(x$likelihood, list(state = "unavailable", f = NA_real_)) &&
      identical(x$enumeration, list(state = "complete", required = 0L)) && length(x$children) == 0L
  }, error = function(e) FALSE)
}

# Evaluate `expr`, holding its warnings and messages (muffled) and its error instead of signaling them, so the
# caller can put them in a ledger node and decide what to replay.
.sem_capture_outcome <- function(expr) {
  notices <- list(warnings = list(), messages = list())
  error <- NULL
  value <- tryCatch(
    withCallingHandlers(
      expr,
      warning = function(w) {
        notices$warnings[[length(notices$warnings) + 1L]] <<- w
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        notices$messages[[length(notices$messages) + 1L]] <<- m
        invokeRestart("muffleMessage")
      }
    ),
    error = function(e) {
      error <<- e
      NULL
    }
  )
  list(value = value, error = error, notices = notices)
}

.sem_replay_notices <- function(notices) {
  for (m in notices$messages) {
    message(m)
  }
  for (w in notices$warnings) {
    warning(w)
  }
  invisible(NULL)
}

.sem_outcome_context <- function(model, parsed, data, information, weights, meanstructure, fixed_x,
                                 n_starts, control, se_type, factors = NULL) {
  list(
    sample = data, model = list(syntax = model, parameters = parsed$parameters),
    domain = list(
      information = information, weights = weights, meanstructure = meanstructure,
      fixed_x = fixed_x, factors = factors,
      objective = if (is.null(weights)) "normal_ml_discrepancy" else "weighted_discrepancy"
    ),
    settings = list(n_starts = n_starts, control = control, se_type = se_type), n_obs = nrow(data)
  )
}

# One node. `result` is the engine's fit list (or the full fit's summary for an MBCO root), `error` the condition
# that stopped the call, `children` the nodes of the required restrictions.
# `union` is TRUE only for a zero-product union (`.sem_fit_branches()`), whose certified-empty branches are accounted
# for; any other parent (the MBCO root, whose null may be certified empty) stays unresolved next to an unresolved child.
.sem_outcome <- function(context, constraints, result = NULL, error = NULL, notices = list(), children = list(),
                         union = FALSE) {
  accepted <- is.null(error) && isTRUE(result$converged) && length(result$f) == 1L && is.finite(result$f) &&
    length(result$status) == 1L && !is.na(result$status)
  resolved <- accepted && all(vapply(children, function(x) {
    identical(x$outcome, "resolved") || (union && .sem_valid_exclusion(x))
  }, TRUE))
  list(
    schema_version = 1L, id = "fit", parent_id = NA_character_, constraints = constraints,
    context = context, enumeration = list(state = "complete", required = length(children)),
    # a malformed product row must not mask the error that is being recorded: the map is then `unavailable`
    branch_map = tryCatch(.sem_branch_map(constraints), error = function(e) {
      list(state = "unavailable", condition = .sem_condition_record(e))
    }),
    outcome = if (resolved) "resolved" else "unresolved",
    optimizer = list(
      state = if (accepted) "accepted" else "unresolved", status = result$status,
      decrement = result$decrement, retries = result$retries, optimum = result$optimum
    ),
    likelihood = list(
      state = if (accepted) "available" else "unavailable",
      f = if (accepted) result$f else NA_real_
    ),
    feasibility = if (accepted) "witness" else "unknown",
    covariance = if (is.null(result$vcov)) {
      "not_retained"
    } else if (all(is.finite(result$vcov))) {
      "available"
    } else {
      "unavailable"
    },
    improper = result$improper,
    notices = list(
      warnings = lapply(notices$warnings, .sem_condition_record),
      messages = lapply(notices$messages, .sem_condition_record)
    ),
    condition = .sem_condition_record(error), children = children
  )
}

# IDs are deterministic positions within the call (`fit/branch:2`, `mbco/null:1/branch:1`), not certificates that
# two nodes have equivalent parameter spaces.
.sem_rebase_outcome <- function(x, id, parent_id = NA_character_) {
  x$id <- id
  x$parent_id <- parent_id
  x$children <- lapply(seq_along(x$children), function(i) {
    .sem_rebase_outcome(x$children[[i]], paste0(id, "/branch:", i), id)
  })
  x
}

# The estimation sample is stored once, on the root node. A descendant that was fitted on the same rows carries only
# `context$sample_hash`, and `.sem_node_sample()` resolves it against the root; a node on different rows (a failed
# branch that never reached listwise deletion) keeps its own copy. The hash is of the whole object, attributes
# included, so a resolved sample is the very sample that was hashed.
.sem_compact_outcome <- function(x) {
  root <- x$context[["sample"]]
  if (!is.data.frame(root)) {
    return(x)
  }
  root_hash <- rlang::hash(root)
  x$context$sample_hash <- root_hash
  squeeze <- function(node) {
    own <- node$context[["sample"]]
    if (is.data.frame(own)) {
      node$context$sample_hash <- rlang::hash(own)
      if (identical(node$context$sample_hash, root_hash)) {
        node$context[["sample"]] <- NULL
      }
    }
    node$children <- lapply(node$children, squeeze)
    node
  }
  x$children <- lapply(x$children, squeeze)
  x
}

# The sample of `node` within the ledger rooted at `root`: its own, or the root's when the digests agree; NULL when
# neither holds (a forged or mismatched digest). `root_hash` is the root sample's digest when the caller has it.
.sem_node_sample <- function(node, root, root_hash = rlang::hash(root$context[["sample"]])) {
  own <- node$context[["sample"]]
  if (!is.null(own)) {
    return(own)
  }
  if (identical(node$context$sample_hash, root_hash)) root$context[["sample"]] else NULL
}

# The D-11 error with its ledger. The message is the pre-ledger text; notices are carried in the ledger only.
# A node that is itself certified empty (a direct infeasible fit) is `medfit_sem_infeasible`; a union whose every
# required branch is certified empty is `medfit_sem_empty_union`. Both stay `medfit_error_no_convergence` (D-11).
.sem_abort_outcome <- function(message, ledger, best_survivor = NULL) {
  kind <- if (identical(ledger$feasibility, "certified_empty")) {
    "medfit_sem_infeasible"
  } else if (length(ledger$children) && all(vapply(ledger$children, .sem_valid_exclusion, TRUE))) {
    "medfit_sem_empty_union"
  } else {
    character()
  }
  .sem_no_convergence(message, ledger = ledger, best_survivor = best_survivor, subclass = kind)
}

# What `.sem_fit_syntax()` does with an error from its pipeline: keep its class (an optimizer failure stays
# `medfit_error_no_convergence`, a data or model error stays what it was), attach the ledger, and carry the notices
# raised before it, which were muffled, in the ledger (the message keeps its pre-ledger text).
.sem_reraise_outcome <- function(err, context, constraints, notices) {
  if (inherits(err, "medfit_error_ledger")) {
    stop(err)
  }
  held <- list(
    warnings = lapply(notices$warnings, .sem_condition_record),
    messages = lapply(notices$messages, .sem_condition_record)
  )
  if (!is.null(err$ledger)) {
    # a ledger made below (branches, over-cap refusal): this call's context and notices complete it
    ledger <- err$ledger
    # the parsed parameters are the premises of a literal certificate: the entry's context has none when it was
    # called with syntax, so keep the table the node below was built from
    context$model$parameters <- ledger$context$model$parameters
    ledger$context <- context
    ledger$notices$warnings <- c(ledger$notices$warnings, held$warnings)
    ledger$notices$messages <- c(ledger$notices$messages, held$messages)
    err$ledger <- .sem_compact_outcome(ledger)
    stop(err)
  }
  err$ledger <- .sem_outcome(context, constraints, error = err, notices = notices)
  stop(err)
}

# Strict structural validation before evidence is used. Missing or legacy evidence is not inferred from `converged`.
.sem_valid_outcome <- function(x, id = "fit", parent_id = NA_character_, root = NULL) {
  tryCatch({
    if (is.null(root)) {
      # the root holds the sample; a digest it carries must be the digest of that sample
      if (!is.data.frame(x$context[["sample"]]) ||
            !(is.null(x$context$sample_hash) || identical(x$context$sample_hash, rlang::hash(x$context[["sample"]])))) {
        return(FALSE)
      }
      root <- list(context = list(sample = x$context[["sample"]]), hash = rlang::hash(x$context[["sample"]]))
    }
    sample <- .sem_node_sample(x, root, root$hash)
    # Reconstruct the required restriction sets, so a dropped child cannot forge completeness.
    products <- .sem_zero_product_rows(x$constraints)
    count <- if (length(products)) .sem_raw_count(vapply(products, function(p) length(p$factors), 0L)) else 0L
    if (!is.finite(count) || count > 64L || length(x$children) != count) {
      return(FALSE)
    }
    grid <- if (length(products)) {
      .sem_branch_grid(products)
    }
    # the map is reconstructed from the node's own constraints, so a forged ID, count or state refuses the node
    is.list(x) && identical(x$branch_map, .sem_branch_map(x$constraints)) &&
      identical(x$schema_version, 1L) && identical(x$id, id) &&
      identical(x$parent_id, parent_id) && is.data.frame(x$constraints) &&
      all(c("lhs", "op", "rhs") %in% names(x$constraints)) && is.list(x$context) &&
      is.data.frame(sample) && is.list(x$context$model) && is.list(x$context$domain) &&
      identical(x$context$n_obs, nrow(sample)) &&
      is.list(x$children) && identical(x$enumeration, list(state = "complete", required = length(x$children))) &&
      identical(x$outcome, "resolved") && identical(x$optimizer$state, "accepted") &&
      length(x$optimizer$status) == 1L && is.finite(x$optimizer$status) &&
      identical(x$likelihood$state, "available") && length(x$likelihood$f) == 1L && is.finite(x$likelihood$f) &&
      identical(x$feasibility, "witness") && x$covariance %in% c("available", "unavailable", "not_retained") &&
      is.list(x$notices$warnings) && is.list(x$notices$messages) && is.null(x$condition) &&
      all(vapply(seq_along(x$children), function(i) {
        cons <- x$constraints
        for (j in seq_along(products)) {
          cons$lhs[products[[j]]$row] <- grid[i, j]
          cons$rhs[products[[j]]$row] <- "0"
        }
        child <- x$children[[i]]
        identical(child$constraints, cons) &&
          identical(.sem_node_sample(child, root, root$hash), root$context[["sample"]]) &&
          identical(child$context$domain, x$context$domain) &&
          identical(child$context$settings, x$context$settings) &&
          identical(child$context$model$parameters, x$context$model$parameters) &&
          (if (.sem_valid_exclusion(child)) {
            # a certified-empty branch: its proof is checked on its own parsed parameters and constraints
            identical(child$id, paste0(id, "/branch:", i)) && identical(child$parent_id, id)
          } else {
            .sem_valid_outcome(child, paste0(id, "/branch:", i), id, root)
          })
      }, TRUE)) &&
      (!length(x$children) || {
        # the minimum is over the resolved branches; at least one must exist (an all-excluded parent is not a fit)
        resolved <- Filter(function(child) identical(child$outcome, "resolved"), x$children)
        length(resolved) > 0L && identical(x$likelihood$f, min(vapply(resolved, function(child) child$likelihood$f, 0)))
      })
  }, error = function(e) FALSE)
}

# The refusal of evidence: a class of its own, never `medfit_error_no_convergence`, so `mbco_sem()` does not turn a
# forged or mismatched refit into an unresolved row.
.sem_abort_ledger <- function(reason, ledger) {
  stop(structure(class = c("medfit_error_ledger", "error", "condition"),
                 list(message = reason, call = NULL, ledger = ledger)))
}

# `fit` is the engine's fit list (or the fields of a `SEMFit` in that shape). The ledger must be valid and must
# describe this very fit: the same discrepancy, status, sample, restrictions, domain and settings.
.sem_require_outcome <- function(fit, model = NULL) {
  x <- fit$ledger
  good <- .sem_valid_outcome(x) && identical(x$likelihood$f, fit$f) && isTRUE(fit$converged) &&
    identical(x$context[["sample"]], fit$data) && identical(x$context$n_obs, fit$n_obs) &&
    identical(x$constraints, fit$constraints) &&
    identical(x$optimizer$status, fit$status) &&
    identical(x$context$domain$information, fit$information) &&
    identical(x$context$domain$weights, fit$weights) &&
    identical(x$context$domain$fixed_x, fit$fixed_x) &&
    identical(x$context$domain$meanstructure, isTRUE(fit$ram$has_mean)) &&
    identical(x$context$domain$factors, fit$factors) &&
    identical(x$context$settings, list(n_starts = fit$n_starts, control = fit$control, se_type = fit$se_type)) &&
    (is.null(model) || identical(x$context$model$syntax, model))
  if (!isTRUE(good)) {
    reason <- "missing, malformed or unresolved SEM outcome ledger"
    context <- .sem_outcome_context(model, NULL, fit$data, NULL, NULL, NULL, NULL, NULL, NULL, NULL)
    rejected <- .sem_outcome(context, fit$constraints, error = simpleError(reason))
    rejected$rejected_evidence <- x
    .sem_abort_ledger(reason, rejected)
  }
  invisible(x)
}
