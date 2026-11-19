# The accessor seam between a fitted SEM and the mediation extractors.
#
# Internal. The workers in extract-lavaan.R (simple, serial, parallel and
# four-way extraction) read a fitted model only through an accessor list, never
# by calling lavaan directly. `.sem_accessors_lavaan()` fills the list from a
# lavaan fit; a native fit supplies its own list with the same fields, so the
# workers are shared instead of copied (plan section 2.4, Q6).
#
# Fields (all functions of no arguments unless noted):
#   param_table(standardized)  parameter table: lhs, op, rhs, label, est, se
#                              (est.std when standardized = TRUE)
#   coef(), vcov()             free-parameter estimates and their covariance
#   partable()                 parameter table with the label column
#   data()                     the model's data (matrix or data.frame)
#   weights()                  case weights over the rows of data(), or NULL
#   converged()                logical convergence flag
#   nobs()                     sample size (per group)
#   names(type)                variable names of a type ("ov", "ov.ord")

.sem_accessors_lavaan <- function(object) {
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("Package 'lavaan' is required for this method but is not installed.",
         call. = FALSE)
  }
  force(object)
  structure(
    list(
      param_table = function(standardized = FALSE) {
        if (standardized) lavaan::standardizedSolution(object) else lavaan::parameterEstimates(object)
      },
      coef = function() lavaan::coef(object),
      vcov = function() lavaan::vcov(object),
      partable = function() lavaan::parTable(object),
      data = function() lavaan::lavInspect(object, "data"),
      weights = function() {
        w <- object@Data@weights
        if (length(w) > 1L && !all(vapply(w, is.null, logical(1)))) {
          stop("sampling weights in a multi-group lavaan fit are not supported ",
               "by the four-way decomposition", call. = FALSE)
        }
        if (length(w) == 1L) w[[1L]] else NULL
      },
      converged = function() lavaan::lavInspect(object, "converged"),
      nobs = function() lavaan::lavInspect(object, "nobs"),
      names = function(type) lavaan::lavNames(object, type)
    ),
    class = "sem_accessors"
  )
}

# TRUE when a lavaan fit has more than one level. `lavInspect(, "nlevels")` is the public API; the parameter
# table's `level` column is the fallback. When neither can be read the fit is treated as single-level, so the
# guard can never block an ordinary fit on its own failure.
.lavaan_is_multilevel <- function(object) {
  nl <- tryCatch(as.integer(lavaan::lavInspect(object, "nlevels")), error = function(e) NA_integer_)
  if (length(nl) == 1L && !is.na(nl)) return(nl > 1L)
  lev <- tryCatch(lavaan::parTable(object)$level, error = function(e) NULL)
  !is.null(lev) && length(unique(lev[!is.na(lev)])) > 1L
}

.assert_lavaan_single_level <- function(object) {
  if (!.lavaan_is_multilevel(object)) return(invisible(object))
  stop(structure(
    class = c("medfit_error_lavaan_multilevel", "error", "condition"),
    list(
      message = paste0(
        "The lavaan fit has more than two levels (or a level count that could not be read). ",
        "extract_mediation() reads exactly one or two levels; with more it would silently use the ",
        "within level only, with N equal to the total number of rows, so it refuses. Fit a single-level ",
        "or a two-level model instead (issue #394)."
      ),
      call = NULL
    )
  ))
}

# TRUE when a lavaan fit has more than one group; an unreadable fit counts as single-group (fail safe).
.lavaan_is_multigroup <- function(object) {
  ng <- tryCatch(as.integer(lavaan::lavInspect(object, "ngroups")), error = function(e) NA_integer_)
  length(ng) == 1L && !is.na(ng) && ng > 1L
}

.assert_lavaan_single_group <- function(object) {
  if (!.lavaan_is_multigroup(object)) return(invisible(object))
  stop(structure(
    class = c("medfit_error_lavaan_multigroup", "error", "condition"),
    list(
      message = paste0(
        "The lavaan fit has more than one group (a multi-group fit is not supported): extract_mediation() would ",
        "silently return the first group's paths with the total number of rows. Fit each group as its own ",
        "single-group model."
      ),
      call = NULL
    )
  ))
}

# An accessor list passes through; anything else is taken to be a lavaan fit.
.sem_as_accessors <- function(object) {
  if (inherits(object, "sem_accessors")) object else .sem_accessors_lavaan(object)
}

# Accessor list for a native fit (`SEMFit`), with the same fields as the lavaan
# one so the extraction workers are shared. Names are those of `coef()`, lavaan's
# coefficient convention (the label when a row has one, else `lhs op rhs` without
# spaces), because the workers locate a path's covariance row by that name.
.sem_accessors_native <- function(object) {
  checkmate::assert_class(object, "medfit::SEMFit", .var.name = "object")
  tab <- object@table
  nm <- names(object@theta)
  coefs <- object@theta
  vc <- unname(object@vcov)
  dimnames(vc) <- list(nm, nm)
  ptab <- data.frame(
    lhs = tab$lhs, op = tab$op, rhs = tab$rhs, label = ifelse(is.na(tab$label), "", tab$label),
    est = tab$est, se = tab$se, stringsAsFactors = FALSE
  )
  obs <- object@internals$ram$obs
  structure(
    list(
      param_table = function(standardized = FALSE) {
        if (standardized) {
          stop("standardized estimates are not supported by engine = \"native\" in this version", call. = FALSE)
        }
        ptab
      },
      coef = function() coefs,
      vcov = function() vc,
      partable = function() ptab,
      data = function() object@data,
      weights = function() object@internals$weights,
      converged = function() object@converged,
      nobs = function() object@n_obs,
      names = function(type) if (identical(type, "ov")) obs else character()
    ),
    class = "sem_accessors"
  )
}

# Canonical name of the treatment-by-mediator product in a native fit's regressions, or NA when the model has none.
# `interaction` (optional) must be a product written with `:`; either order resolves to the stored `m:x` name.
.sem_native_interaction <- function(object, treatment, mediator, interaction = NULL) {
  checkmate::assert_string(interaction, null.ok = TRUE, .var.name = "interaction")
  tab <- object@table
  stored <- tab$rhs[tab$op == "~" & grepl(":", tab$rhs, fixed = TRUE)]
  canon <- .sem_product_name(treatment, mediator)
  if (!is.null(interaction)) {
    parts <- strsplit(interaction, ":", fixed = TRUE)[[1L]]
    if (length(parts) != 2L || !all(nzchar(parts))) {
      stop("`interaction` for a native fit must be the product written with `:`, as in '", treatment, ":", mediator,
           "'; a precomputed data column is fitted as an ordinary variable.", call. = FALSE)
    }
    if (!identical(.sem_product_name(parts[1L], parts[2L]), canon)) {
      stop("`interaction` ('", interaction, "') is not the product of the treatment '", treatment,
           "' and the mediator '", mediator, "'.", call. = FALSE)
    }
  }
  if (canon %in% stored) canon else NA_character_
}

# A product other than treatment:mediator that involves the treatment or the mediator changes the effects without
# changing a coefficient the a, b, c' and four-way formulas read, so it is refused on every single-mediator route.
.sem_stop_other_products <- function(object, treatment, mediator) {
  tab <- object@table
  prod <- unique(tab$rhs[tab$op == "~" & grepl(":", tab$rhs, fixed = TRUE)])
  prod <- setdiff(prod, .sem_product_name(treatment, mediator))
  hit <- prod[vapply(strsplit(prod, ":", fixed = TRUE), function(f) any(f %in% c(treatment, mediator)), logical(1))]
  if (length(hit)) {
    fac <- .sem_factor_of_product(object@internals$factors, hit[1L])
    if (!is.null(fac)) {
      stop("the native extraction does not support the product '", hit[1L], "': it comes from the factor `", fac,
           "`, so the effects differ by `", fac, "` and averaging over `", fac, "` is not supported. Fit the model ",
           "without the product, or compute the effects within each level of `", fac, "`.", call. = FALSE)
    }
    stop("the native extraction does not support the product '", hit[1L], "': a product involving the treatment ",
         "or the mediator other than '", .sem_product_name(treatment, mediator), "' changes the effects without ",
         "changing a coefficient the extraction reads. Remove it, or fit the model with lm/glm.", call. = FALSE)
  }
  invisible(NULL)
}

# The factor a product term was expanded from (one of its sides is a generated dummy), or NULL.
.sem_factor_of_product <- function(factors, product) {
  sides <- strsplit(product, ":", fixed = TRUE)[[1L]]
  for (v in names(factors)) {
    if (any(sides %in% factors[[v]]$dummies)) {
      return(v)
    }
  }
  NULL
}

# `extract_mediation()` for a native fit: the shared lavaan-route workers read the
# fit through the native accessor list, so the structures, aliases and name
# conventions cannot drift from the lavaan route. Registered at source time (the
# class lives in this package).
S7::method(extract_mediation, SEMFit) <- function(object, treatment, mediator, ...) {
  args <- list(...)
  if (.sem_fiml_is(object)) return(.sem_fiml_extract(object, treatment, mediator, args))
  if (isTRUE(object@internals$ram$twolevel)) return(.sem_extract_twolevel(object, treatment, mediator, args))
  # a factor was expanded to dummies, so the effects have no single column to read (D9)
  as_factor <- intersect(c(treatment, mediator), names(object@internals$factors))
  if (length(as_factor)) {
    f <- as_factor[1L]
    dummies <- paste(object@internals$factors[[f]]$dummies, collapse = ", ")
    stop("`", f, "` is a factor in the model (expanded to ", dummies, "): the effects need a single numeric ",
         "column. For a two-level factor, recode it as a 0/1 numeric variable and name that column in the model and ",
         "here.", call. = FALSE)
  }
  # Four-way route: a treatment-by-mediator product in the outcome equation, written `x:m` and stored under its
  # canonical name (`x:m` and `m:x` are one term), is read through the accessor seam by the shared worker. Estimate
  # names, `outcome_predictors` and `source_package` therefore carry the canonical `m:x` where the lavaan route
  # keeps the spelling the user wrote.
  if (length(mediator) == 1L) {
    checkmate::assert_string(treatment, .var.name = "treatment")
    checkmate::assert_string(mediator, .var.name = "mediator")
    asked <- args$interaction
    decomposition <- match.arg(args$decomposition, c("auto", "four_way", "two_way"))
    int <- .sem_native_interaction(object, treatment, mediator, asked)
    .sem_stop_other_products(object, treatment, mediator)
    args$interaction <- if (is.null(asked)) NULL else int
    if (is.na(int) && (identical(decomposition, "four_way") || !is.null(asked))) {
      stop("the four-way decomposition of a native fit needs the treatment-by-mediator product in the outcome ",
           "equation: add `", treatment, ":", mediator, "` to it, for example `y ~ ", treatment, " + ", mediator,
           " + ", treatment, ":", mediator, "`. Native products are written in the model syntax, not as a ",
           "precomputed data column.", call. = FALSE)
    }
  } else if (!is.null(args$interaction)) {
    stop("`interaction` applies to a single mediator.", call. = FALSE)
  }
  out <- do.call(extract_mediation_lavaan,
                 c(list(.sem_accessors_native(object), treatment = treatment, mediator = mediator), args))
  out@source_package <- "medfit"
  out
}

# `extract_mediation()` on a native two-level fit (S4a.5, experimental): the lavaan adapter's object from the sem
# engine's fit. The ledger is read first: an inadmissible level refuses the fit whatever `@converged` says, and a
# ledger that does not describe this fit is `medfit_error_ledger`. The parameter table takes the adapter's shape, each
# row keyed by its free-parameter index (`par_map`; a label shared across levels is one index), so the 6x6 block of
# `@vcov` is read by position, never by name; the ICCs come from the engine's implied moments.
.sem_extract_twolevel <- function(object, treatment, mediator, args) {
  ledger <- object@diagnostics$ledger
  states <- vapply(ledger$admissibility, function(l) as.character(l$state)[1L], "")
  if (any(states != "admissible")) {
    bad <- names(states)[states != "admissible"]
    reasons <- unlist(lapply(ledger$admissibility[bad], `[[`, "reasons"), use.names = FALSE)
    .twolevel_abort(
      paste0("The two-level fit is inadmissible at the ", paste(bad, collapse = " and "), " level: ",
             paste(reasons, collapse = "; "), ". Its effects are not extracted."),
      "medfit_error_twolevel_inadmissible"
    )
  }
  .sem_require_outcome(list(
    ledger = ledger, f = object@f, converged = object@converged, data = object@data, n_obs = object@n_obs,
    constraints = object@internals$constraints, status = object@diagnostics$status,
    information = object@information, weights = object@internals$weights, fixed_x = object@internals$fixed_x,
    factors = object@internals$factors, ram = object@internals$ram, n_starts = object@internals$n_starts,
    control = object@internals$control, se_type = object@diagnostics$se_type
  ), object@model)
  tab <- object@table
  pm <- object@internals$par_map
  pt <- data.frame(
    lhs = tab$lhs, op = tab$op, rhs = tab$rhs, level = as.integer(tab$level),
    label = ifelse(is.na(tab$label), "", tab$label), plabel = "",
    free = ifelse(tab$free & !is.na(pm), as.integer(pm), 0L), est = tab$est, stringsAsFactors = FALSE
  )
  cons <- object@internals$constraints
  if (NROW(cons)) {
    pt <- rbind(pt, data.frame(lhs = cons$lhs, op = cons$op, rhs = cons$rhs, level = 0L, label = "", plabel = "",
                               free = 0L, est = NA_real_, stringsAsFactors = FALSE))
  }
  outcome <- args$outcome
  .twolevel_check_args(pt, treatment, mediator, outcome, isTRUE(args$standardized), args$interaction,
                       args$structure %||% "auto", args$decomposition %||% "auto", args$m_star,
                       args$a_label, args$b_label, args$cp_label)
  if (is.null(outcome)) outcome <- .twolevel_find_outcome(pt, treatment, mediator)
  .twolevel_check_levels(pt, c(treatment, mediator))
  key <- .twolevel_key_rows(pt, treatment, mediator, outcome)
  V6 <- .twolevel_subvcov(object@vcov, key)
  converged <- isTRUE(object@converged)
  .twolevel_check_within(key, V6, converged)
  mom <- .sem_twolevel_implied(object@internals$ram, unname(object@theta))
  ident <- .twolevel_identification(NULL, treatment, mediator, outcome, converged, V6,
                                    icc = .sem_twolevel_icc(mom$sigma_w, mom$sigma_b))
  ids <- object@internals$cluster_ids
  sizes <- as.integer(table(factor(ids, levels = unique(ids))))
  version <- as.character(utils::packageVersion("medfit"))
  .twolevel_assemble(
    pt, key, V6, ident, converged = converged, admissible = TRUE, n_obs = as.integer(object@n_obs),
    n_clusters = length(sizes), cluster_sizes = sizes, treatment = treatment, mediator = mediator,
    outcome = outcome,
    provenance = list(
      cluster = object@internals$cluster, source = "native",
      fixed_x = length(object@internals$fixed_x) > 0L, information = object@information,
      h1_information = "structured", se_type = object@diagnostics$se_type %||% "model", estimator = "ML",
      missing = "listwise", lavaan_version = character(0), call = paste(deparse(object@call), collapse = " "),
      between_parameterization = "latent", data = NULL, source_package = "medfit", source_version = version
    )
  )
}

# ICC per variable from the implied within and between covariances (a lavaan fit's through `.twolevel_icc()`): a
# variable absent at a level has variance 0 there, and a non-finite ratio is 0 (clamped to [0, 1]).
.sem_twolevel_icc <- function(w, b) {
  vars <- union(rownames(w), rownames(b))
  icc <- vapply(vars, function(v) {
    sw <- if (v %in% rownames(w)) w[v, v] else 0
    sb <- if (v %in% rownames(b)) b[v, v] else 0
    value <- sb / (sb + sw)
    if (is.finite(value)) min(max(value, 0), 1) else 0
  }, numeric(1))
  stats::setNames(icc, vars)
}
