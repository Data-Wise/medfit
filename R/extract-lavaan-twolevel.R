# =============================================================================
# Two-level (1-1-1) extraction from a lavaan fit (#394, slice S2)
#
# `extract_mediation()` on a lavaan fit with two levels returns `TwoLevelMediationData`: the a, b and c'
# paths at the within and the between level, read from the fit's parameter table by free-parameter index
# (never by label), with the sub-block of the fit's joint covariance. The fit is read, never refit.
# Named internals (`.twolevel_key_rows`, `.twolevel_subvcov`, `.twolevel_cross_equal`, `.twolevel_icc`,
# `.twolevel_identification`) are replaceable in tests, which plant defects in them.
# =============================================================================

# Constants in one place; `options(medfit.twolevel_min_clusters = , medfit.between_icc_error = ,
# medfit.between_icc_warn = )` override them.
# `equal_diff` and `equal_var` are the tolerances of the numeric equality detector (`.twolevel_pair_equal()`).
.twolevel_defaults <- list(min_clusters = 50L, icc_error = 0.01, icc_warn = 0.05,
                           equal_diff = 1e-6, equal_var = 1e-10)

.twolevel_option <- function(name) {
  opt <- c(min_clusters = "medfit.twolevel_min_clusters", icc_error = "medfit.between_icc_error",
           icc_warn = "medfit.between_icc_warn", equal_diff = "medfit.twolevel_equal_diff",
           equal_var = "medfit.twolevel_equal_var")[[name]]
  getOption(opt, .twolevel_defaults[[name]])
}

# Number of levels of a lavaan fit: `lavInspect(, "nlevels")`, the parameter table's `level` column as the
# fallback, NA when neither can be read.
.lavaan_nlevels <- function(object) {
  nl <- tryCatch(as.integer(lavaan::lavInspect(object, "nlevels")), error = function(e) NA_integer_)
  if (length(nl) == 1L && !is.na(nl)) return(nl)
  lev <- tryCatch(lavaan::parTable(object)$level, error = function(e) NULL)
  if (is.null(lev)) return(NA_integer_)
  length(unique(lev[lev > 0L & !is.na(lev)]))
}

.twolevel_abort <- function(message, class) {
  rlang::abort(message, class = class, call = NULL)
}

.twolevel_converged <- function(fit) {
  isTRUE(tryCatch(lavaan::lavInspect(fit, "converged"), error = function(e) FALSE))
}

# The joint covariance of the free parameters as a plain matrix; NULL when lavaan cannot supply one.
.twolevel_read_vcov <- function(fit) {
  tryCatch(lavaan::vcov(fit), error = function(e) NULL)
}

# lavaan warns while it evaluates post.check; the adapter signals its own classed warning instead. An
# inadmissible solution (a negative variance, a non-positive-definite matrix) is a FALSE value, not an error
# (lavaan::lavInspect(fit, "post.check") returned FALSE for such fits and TRUE for non-converged and `se = "none"`
# fits in the probe behind this helper), so no error is expected and any error propagates.
.twolevel_admissible <- function(fit) {
  isTRUE(suppressWarnings(lavaan::lavInspect(fit, "post.check")))
}

# The lavaan version that made the fit, from the fit's own `@version` slot ("0.7-3" is normalized to "0.7.3");
# the installed version only when the slot is empty or unparsable.
.twolevel_fit_version <- function(fit) {
  v <- tryCatch(as.character(numeric_version(fit@version[1L])), error = function(e) character(0))
  if (length(v) != 1L || is.na(v)) v <- as.character(utils::packageVersion("lavaan"))
  v
}

# The path stems of the key, one per path and level: "a", "b", "c_prime" for one mediator; "a_<M>" for each
# mediator, then "b_<M>", then "c_prime" for k parallel mediators (SPEC-IG5 section 5). The key's `path` is the
# stem with the level suffix ("a_within", "a_M1_between").
.twolevel_path_stems <- function(mediator) {
  if (length(mediator) == 1L) return(c("a", "b", "c_prime"))
  c(paste0("a_", mediator), paste0("b_", mediator), "c_prime")
}

# The stems of a key, in key order (the within rows come first).
.twolevel_key_stems <- function(key) {
  unique(sub("_(within|between)$", "", key$path))
}

# Rows of the parameter table for the paths at both levels: per level a (one per mediator), b (one per
# mediator), c', within then between. Exactly one row per path and level; a path absent at one level is not
# assumed to be 0. Each row's key is its free-parameter index `free` (0 for a fixed row).
.twolevel_key_rows <- function(pt, treatment, mediator, outcome) {
  pt <- pt[pt$op == "~", , drop = FALSE]
  k <- length(mediator)
  spec <- data.frame(
    path = .twolevel_path_stems(mediator),
    lhs = c(mediator, rep(outcome, k + 1L)),
    rhs = c(rep(treatment, k), mediator, treatment),
    stringsAsFactors = FALSE
  )
  rows <- list()
  for (level in 1:2) {
    for (i in seq_len(nrow(spec))) {
      hit <- pt[pt$level == level & pt$lhs == spec$lhs[i] & pt$rhs == spec$rhs[i], , drop = FALSE]
      lvl_name <- c("within", "between")[level]
      if (nrow(hit) != 1L) {
        .twolevel_abort(
          sprintf(paste0("Expected exactly one '%s ~ %s' row at the %s level, found %d. A path that is ",
                         "absent at a level is not assumed to be 0; add it to the model (or fix it ",
                         "with `0*`)."),
                  spec$lhs[i], spec$rhs[i], lvl_name, nrow(hit)),
          "medfit_error_twolevel_path_missing"
        )
      }
      rows[[length(rows) + 1L]] <- data.frame(
        path = paste0(spec$path[i], "_", lvl_name), level = lvl_name, lhs = hit$lhs, op = hit$op,
        rhs = hit$rhs, label = as.character(hit$label), plabel = as.character(hit$plabel),
        free = as.integer(hit$free), est = hit$est, stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

# The 2(2k + 1) square sub-block (6x6 for one mediator) of the joint covariance for the keyed rows, by position
# (free index), never by name
# (a label shared across levels gives duplicate column names). A fixed row (free == 0) is a zero row and
# column. Two paths that share an index repeat that row and column (correlation 1), which is the correct
# covariance of an equated parameter.
.twolevel_subvcov <- function(V, key) {
  idx <- key$free
  ok <- idx > 0L
  out <- matrix(0, nrow(key), nrow(key), dimnames = list(key$path, key$path))
  if (any(ok)) {
    out[ok, ok] <- as.matrix(V)[idx[ok], idx[ok], drop = FALSE]
  }
  out
}

# Is the pair (within, between) equated? `est` is c(within, between) and `V` their 2x2 covariance. The pair is
# equated when the estimated difference AND the variance of the difference are both effectively zero:
#   |d| <= equal_diff * max(1, |est|)   and   Var(d) <= equal_var * (V_ww + V_bb),   d = est_w - est_b.
# Never the correlation: correlation -1, or +1 between proportional but unequal paths, does not imply
# equality. Tolerances (calibrated on the oracle fits, 2026-11-11): an algebraic equality that lavaan keeps as
# two parameters (`a^2 - a2^2 == 0`) leaves |d| near 9e-9 and Var(d)/(V_ww + V_bb) near 1e-16; an unequal pair
# in the same model has |d| of 0.3 or more and a relative variance near 1. The 1e-6 and 1e-10 defaults sit
# two orders and six orders from the equated cases; override with `options(medfit.twolevel_equal_diff = ,
# medfit.twolevel_equal_var = )`.
.twolevel_pair_equal <- function(est, V) {
  if (length(est) != 2L || !all(is.finite(est)) || !all(is.finite(V))) return(FALSE)
  d <- est[[1L]] - est[[2L]]
  var_d <- V[1L, 1L] + V[2L, 2L] - 2 * V[1L, 2L]
  abs(d) <= .twolevel_option("equal_diff") * max(1, abs(est)) &&
    var_d <= .twolevel_option("equal_var") * (V[1L, 1L] + V[2L, 2L])
}

# Paths equated across the levels by the numeric criterion, among the free rows (a fixed row has no variance).
.twolevel_numeric_equal <- function(key, V) {
  equal <- vapply(.twolevel_key_stems(key), function(p) {
    nm <- paste0(p, c("_within", "_between"))
    rows <- match(nm, key$path)
    if (anyNA(rows) || any(key$free[rows] <= 0L) || is.null(V) || !all(nm %in% rownames(V))) return(FALSE)
    .twolevel_pair_equal(key$est[rows], V[nm, nm, drop = FALSE])
  }, logical(1))
  names(equal)[equal]
}

# Paths equated across the two levels, by stem ("a", "b", "c_prime"; "a_<M>", "b_<M>", "c_prime" with k
# mediators, SPEC-IG5 D5): (i) a shared non-zero free index, (ii) a shared non-empty label, (iii) a `==` row
# naming both labels (or their plabels), or (iv) the numeric criterion (`.twolevel_numeric_equal()`), which also
# finds an algebraic equality lavaan keeps as two parameters.
.twolevel_cross_equal <- function(pt, key, V = NULL) {
  eq_rows <- pt[pt$op == "==", , drop = FALSE]
  tags <- function(row) setdiff(c(row$label, row$plabel), "")
  stems <- .twolevel_key_stems(key)
  equal <- vapply(stems, function(p) {
    w <- key[key$path == paste0(p, "_within"), ]
    b <- key[key$path == paste0(p, "_between"), ]
    by_index <- w$free > 0L && w$free == b$free
    by_label <- nzchar(w$label) && w$label == b$label
    tw <- tags(w)
    tb <- tags(b)
    by_row <- nrow(eq_rows) > 0L && any(
      (eq_rows$lhs %in% tw & eq_rows$rhs %in% tb) | (eq_rows$lhs %in% tb & eq_rows$rhs %in% tw)
    )
    by_index || by_label || by_row
  }, logical(1))
  found <- union(names(equal)[equal], .twolevel_numeric_equal(key, V))
  found[order(match(found, stems))]
}

# Intraclass correlation per variable from the model-implied within and between covariances:
# Sigma_B / (Sigma_B + Sigma_W). A variable absent at the within level has ICC 1 (between-only); one absent
# at the between level has ICC 0. A non-finite or negative ratio (a Heywood case) is 0.
.twolevel_icc <- function(fit) {
  implied <- lavaan::lavInspect(fit, "implied")
  w <- implied[[1L]]$cov
  b <- implied[[2L]]$cov
  vars <- union(rownames(w), rownames(b))
  icc <- vapply(vars, function(v) {
    sw <- if (v %in% rownames(w)) w[v, v] else 0
    sb <- if (v %in% rownames(b)) b[v, v] else 0
    value <- sb / (sb + sw)
    if (is.finite(value)) min(max(value, 0), 1) else 0
  }, numeric(1))
  names(icc) <- vars
  icc
}

# TRUE when the symmetric matrix is positive definite after dropping fixed (zero) rows and rows repeated by
# an equality constraint; tolerance 1e-10 scaled by the largest eigenvalue.
.twolevel_is_pd <- function(M) {
  if (length(M) == 0L) return(TRUE)
  if (anyNA(M) || any(!is.finite(M))) return(FALSE)
  keep <- diag(M) != 0
  M <- M[keep, keep, drop = FALSE]
  if (nrow(M) == 0L) return(TRUE)
  scale <- max(abs(M))
  kept <- integer(0)
  for (i in seq_len(nrow(M))) {
    dup <- any(vapply(kept, function(j) all(abs(M[i, ] - M[j, ]) <= 1e-8 * scale), logical(1)))
    if (!dup) kept <- c(kept, i)
  }
  M <- M[kept, kept, drop = FALSE]
  ev <- eigen((M + t(M)) / 2, symmetric = TRUE, only.values = TRUE)$values
  min(ev) > 1e-10 * max(ev)
}

# Is the between level identified (S1-Q1)? FALSE when any of: the treatment or mediator ICC is below
# `icc_error`, a between-path covariance entry is not finite, the joint path block is not positive
# definite, the fit did not converge. The treatment and mediator ICCs drive the decision; the outcome ICC is
# only reported (a near-zero outcome ICC shows up as a Heywood case and as `admissible`). `post.check` alone
# is not used: a between SD of 0.05 passes it with a between SE far above 0.7.
.twolevel_identification <- function(fit, treatment, mediator, outcome, converged, V6) {
  icc <- .twolevel_icc(fit)
  icc_error <- .twolevel_option("icc_error")
  icc_warn <- .twolevel_option("icc_warn")
  icc_x <- icc[[treatment]]
  # D2 (IG5): all or nothing, the between level needs every mediator's ICC above `icc_error`
  icc_m <- unlist(icc[mediator], use.names = FALSE)
  reasons <- character(0)
  if (icc_x < icc_error) {
    reasons <- c(reasons, sprintf("the ICC of the treatment '%s' is %.4f (below %s)", treatment, icc_x, icc_error))
  }
  for (j in which(icc_m < icc_error)) {
    reasons <- c(reasons, sprintf("the ICC of the mediator '%s' is %.4f (below %s)", mediator[j], icc_m[j],
                                  icc_error))
  }
  # The key holds the within rows, then as many between rows
  between <- if (is.null(V6)) integer(0) else seq_len(nrow(V6))[-seq_len(nrow(V6) / 2)]
  if (is.null(V6) || any(!is.finite(V6[between, between]))) {
    reasons <- c(reasons, "a between-level covariance entry is not finite")
  } else if (!.twolevel_is_pd(V6)) {
    reasons <- c(reasons, "the joint covariance of the paths is not positive definite")
  }
  if (!isTRUE(converged)) reasons <- c(reasons, "the fit did not converge")
  list(
    icc = icc[unique(c(treatment, mediator, outcome))],
    identified = length(reasons) == 0L,
    weak = length(reasons) == 0L && (icc_x < icc_warn || any(icc_m < icc_warn)),
    reasons = reasons
  )
}

.twolevel_warn <- function(message, class, ...) {
  rlang::warn(message, class = class, ...)
}

# Check the arguments the adapter cannot honor before anything is read from the fit.
.twolevel_check_args <- function(pt, treatment, mediator, outcome, standardized, interaction, structure,
                                 decomposition, m_star, a_label, b_label, cp_label) {
  if (isTRUE(standardized)) {
    .twolevel_abort(
      paste0("standardized = TRUE is not supported for a two-level fit: a standardized path mixes the ",
             "within and the between variances. Use the unstandardized paths."),
      "medfit_error_twolevel_standardized"
    )
  }
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_character(mediator, min.len = 1L, any.missing = FALSE, min.chars = 1L, .var.name = "mediator")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
  .twolevel_check_roles(pt, treatment, mediator, outcome)
  has_product <- any(grepl(":", pt$rhs[pt$op == "~"], fixed = TRUE))
  if (!is.null(interaction) || has_product) {
    .twolevel_abort(
      paste0("A product (interaction) term is not supported for a two-level fit; the two-level paths ",
             "are linear and have no mediator-by-treatment product."),
      "medfit_error_twolevel_product"
    )
  }
  if (!identical(structure, "auto") || !identical(decomposition, "auto") || !is.null(m_star)) {
    .twolevel_abort(
      "`structure`, `decomposition` and `m_star` do not apply to a two-level fit; leave them unset.",
      "medfit_error_twolevel_unsupported"
    )
  }
  ignored <- c(a_label = !is.null(a_label) && !identical(a_label, "a"),
               b_label = !is.null(b_label) && !identical(b_label, "b"),
               cp_label = !is.null(cp_label) && !identical(cp_label, "cp"))
  if (any(ignored)) {
    .twolevel_warn(
      paste0("`", paste(names(ignored)[ignored], collapse = "`, `"), "` is ignored for a two-level fit: ",
             "the paths are read from the parameter table by variable names and level, not by label."),
      "medfit_warning_twolevel_labels_ignored",
      .frequency = "once", .frequency_id = "medfit_twolevel_labels_ignored"
    )
  }
  invisible(NULL)
}

# Roles (IG5): each mediator once, the treatment and the outcome not among them, and no mediator regressed on
# another at either level (a serial chain, which the parallel adapter does not decompose).
.twolevel_check_roles <- function(pt, treatment, mediator, outcome) {
  if (anyDuplicated(mediator)) {
    .twolevel_abort(
      sprintf("The mediator '%s' is listed more than once; pass each mediator once.",
              mediator[anyDuplicated(mediator)]),
      "medfit_error_twolevel_unsupported"
    )
  }
  overlap <- intersect(c(treatment, outcome), mediator)
  if (length(overlap) > 0L) {
    .twolevel_abort(
      sprintf("'%s' is listed both as a mediator and as the %s; a variable can have one role only.",
              overlap[1L], if (identical(overlap[1L], treatment)) "treatment" else "outcome"),
      "medfit_error_twolevel_unsupported"
    )
  }
  serial <- pt$op == "~" & pt$lhs %in% mediator & pt$rhs %in% mediator & pt$lhs != pt$rhs
  if (any(serial)) {
    i <- which(serial)[1L]
    # A predictor that is not itself regressed on the treatment at that level is a covariate, not a mediator
    pred <- pt$rhs[i]
    lvl <- pt$level[i]
    if (!any(pt$op == "~" & pt$lhs == pred & pt$rhs == treatment & pt$level == lvl)) {
      .twolevel_abort(
        sprintf(paste0("'%s' is listed as a mediator but is not regressed on the treatment (no '%s ~ %s' row ",
                       "at the %s level); it predicts the mediator '%s' ('%s ~ %s'). A mediator lies on a ",
                       "treatment -> mediator -> outcome path; pass a covariate in the model, not as a mediator."),
                pred, pred, treatment, c("within", "between")[lvl], pt$lhs[i], pt$lhs[i], pred),
        "medfit_error_twolevel_unsupported"
      )
    }
    .twolevel_abort(
      sprintf(paste0("A mediator predicts another mediator ('%s ~ %s' at the %s level): serial mediation is not ",
                     "supported for a two-level fit. The mediators must be parallel (each regressed on the ",
                     "treatment only)."),
              pt$lhs[i], pt$rhs[i], c("within", "between")[pt$level[i]]),
      "medfit_error_twolevel_unsupported"
    )
  }
  invisible(NULL)
}

# A variable that is not in the model at both levels (a cluster-level treatment: the 2-1-1 design) is not
# a two-level 1-1-1 mediation.
.twolevel_check_levels <- function(pt, vars) {
  for (v in vars) {
    for (level in 1:2) {
      rows <- pt[pt$level == level, , drop = FALSE]
      if (!v %in% c(rows$lhs, rows$rhs)) {
        .twolevel_abort(
          sprintf(paste0("The variable '%s' is not in the model at the %s level, so this is not a ",
                         "treatment-mediator-outcome design on level-1 units. A treatment assigned to ",
                         "clusters (2-1-1) is fitted with `fit_mediation(engine = \"lmer\", cluster = )`."),
                  v, c("within", "between")[level]),
          "medfit_error_twolevel_unsupported"
        )
      }
    }
  }
  invisible(NULL)
}

.twolevel_find_outcome <- function(pt, treatment, mediator) {
  cand <- setdiff(unique(pt$lhs[pt$op == "~" & pt$level == 1L]), c(treatment, mediator))
  if (length(cand) != 1L) {
    .twolevel_abort(
      "Could not determine the outcome: pass `outcome` (the within level has more than one candidate).",
      "medfit_error_twolevel_unsupported"
    )
  }
  cand
}

.extract_lavaan_twolevel <- function(object, treatment, mediator, outcome = NULL, standardized = FALSE,
                                     interaction = NULL, structure = "auto", decomposition = "auto",
                                     m_star = NULL, a_label = NULL, b_label = NULL, cp_label = NULL) {
  pt <- lavaan::parTable(object)

  # --- Arguments and design the adapter cannot honor ---
  .twolevel_check_args(pt, treatment, mediator, outcome, standardized, interaction, structure,
                       decomposition, m_star, a_label, b_label, cp_label)
  if (is.null(outcome)) outcome <- .twolevel_find_outcome(pt, treatment, mediator)
  .twolevel_check_levels(pt, c(treatment, mediator))

  # --- Keyed rows, joint covariance sub-block ---
  key <- .twolevel_key_rows(pt, treatment, mediator, outcome)
  V <- .twolevel_read_vcov(object)
  V6 <- if (is.null(V)) NULL else .twolevel_subvcov(V, key)
  converged <- .twolevel_converged(object)

  # The within block must be usable whatever happens at the between level.
  within <- which(key$level == "within")
  if (is.null(V6) || !.twolevel_is_pd(V6[within, within, drop = FALSE]) ||
        !all(is.finite(key$est[within]))) {
    .twolevel_abort(
      paste0("The two-level fit is not usable: ",
             if (!converged) "it did not converge and " else "",
             "the covariance of the within-level paths is unavailable or not positive definite."),
      "medfit_error_twolevel_unusable"
    )
  }

  # --- Between identification, admissibility, design size ---
  ident <- .twolevel_identification(object, treatment, mediator, outcome, converged, V6)
  identified <- ident$identified
  admissible <- .twolevel_admissible(object)
  n_clusters <- as.integer(lavaan::lavInspect(object, "nclusters"))[1L]
  cluster_sizes <- as.integer(lavaan::lavInspect(object, "cluster.size"))
  n_obs <- as.integer(lavaan::lavInspect(object, "nobs"))[1L]

  if (n_clusters < .twolevel_option("min_clusters")) {
    .twolevel_warn(
      sprintf(paste0("The fit has %d clusters (fewer than %d). Two-level estimates and between-level ",
                     "standard errors are unreliable with few clusters; the adapter still returns them."),
              n_clusters, .twolevel_option("min_clusters")),
      "medfit_warning_twolevel_few_clusters"
    )
  }
  if (!admissible) {
    .twolevel_warn(
      "The lavaan fit is not admissible (post.check is FALSE, for example a negative variance).",
      "medfit_warning_twolevel_inadmissible"
    )
  }
  if (!identified) {
    .twolevel_warn(
      paste0("The between level is not identified, so only the within-level paths are returned ",
             "(a within-only result): ", paste(ident$reasons, collapse = "; "), "."),
      "medfit_between_unidentified"
    )
  } else if (ident$weak) {
    .twolevel_warn(
      sprintf(paste0("The between-level variance of the treatment or the mediator is small (ICC below %s); ",
                     "between-level results are kept but may be imprecise."),
              .twolevel_option("icc_warn")),
      "medfit_warning_between_weak"
    )
  }

  # --- Assemble ---
  equal <- if (identified) .twolevel_cross_equal(pt, key, V6) else character(0)
  rows <- if (identified) seq_len(nrow(key)) else within
  est <- stats::setNames(key$est[rows], key$path[rows])
  # A within-only object keeps the audit rows but not between numbers it says do not exist
  shown <- if (identified) rep(TRUE, nrow(key)) else key$level == "within"
  se <- rep(NA_real_, nrow(key))
  se[shown] <- .safe_se(diag(V6)[shown], "the two-level fit")
  table <- data.frame(
    path = key$path, level = key$level, lhs = key$lhs, op = key$op, rhs = key$rhs, label = key$label,
    free = key$free, est = ifelse(shown, key$est, NA_real_), se = ifelse(shown, unname(se), NA_real_),
    stringsAsFactors = FALSE
  )
  opts <- lavaan::lavInspect(object, "options")
  paths <- stats::setNames(key$est, key$path)
  between_val <- function(nm) if (identified) unname(paths[[nm]]) else NA_real_
  version <- .twolevel_fit_version(object)

  shared <- list(
    c_prime_within = unname(paths[["c_prime_within"]]), c_prime_between = between_val("c_prime_between"),
    estimates = est,
    vcov = V6[rows, rows, drop = FALSE],
    parameter_table = table,
    treatment = treatment, outcome = outcome,
    cluster = as.character(lavaan::lavInspect(object, "cluster"))[1L],
    n_obs = n_obs, n_clusters = n_clusters, cluster_sizes = cluster_sizes,
    icc = ident$icc,
    between_identified = identified, admissible = admissible, converged = converged,
    cross_level_equal = equal,
    fixed_paths = key$path[key$free == 0L & key$path %in% names(est)],
    source = "lavaan",
    fixed_x = isTRUE(opts$fixed.x),
    information = as.character(opts$information)[1L],
    h1_information = as.character(opts$h1.information)[1L],
    se_type = as.character(opts$se)[1L],
    estimator = as.character(opts$estimator)[1L],
    missing = as.character(opts$missing)[1L],
    lavaan_version = version,
    call = paste(deparse(object@call), collapse = " "),
    between_parameterization = "latent",
    data = NULL,
    source_package = "lavaan",
    source_version = version
  )
  if (length(mediator) == 1L) {
    return(do.call(TwoLevelMediationData, c(list(
      a_within = unname(paths[["a_within"]]), b_within = unname(paths[["b_within"]]),
      a_between = between_val("a_between"), b_between = between_val("b_between"),
      mediator = mediator
    ), shared)))
  }
  # k >= 2 (IG5): the a and b paths are vectors named by the mediators; a within-only object keeps NA between
  path_vec <- function(stem, level) {
    nm <- paste0(stem, "_", mediator, "_", level)
    value <- vapply(nm, function(n) if (identical(level, "within")) unname(paths[[n]]) else between_val(n),
                    numeric(1))
    stats::setNames(value, mediator)
  }
  do.call(TwoLevelParallelMediationData, c(list(
    a_within = path_vec("a", "within"), b_within = path_vec("b", "within"),
    a_between = path_vec("a", "between"), b_between = path_vec("b", "between"),
    mediators = mediator
  ), shared))
}
