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
.twolevel_defaults <- list(min_clusters = 50L, icc_error = 0.01, icc_warn = 0.05)

.twolevel_option <- function(name) {
  opt <- c(min_clusters = "medfit.twolevel_min_clusters", icc_error = "medfit.between_icc_error",
           icc_warn = "medfit.between_icc_warn")[[name]]
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

# Rows of the parameter table for the three paths at both levels, in the order a, b, c' within then
# between. Exactly one row per path and level; a path absent at one level is not assumed to be 0.
# Each row's key is its free-parameter index `free` (0 for a fixed row).
.twolevel_key_rows <- function(pt, treatment, mediator, outcome) {
  pt <- pt[pt$op == "~", , drop = FALSE]
  spec <- data.frame(
    path = c("a", "b", "c_prime"),
    lhs = c(mediator, outcome, outcome),
    rhs = c(treatment, mediator, treatment),
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

# The 6x6 sub-block of the joint covariance for the keyed rows, by position (free index), never by name
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

# Paths ("a", "b", "c_prime") equated across the two levels: (i) a shared non-zero free index, (ii) a shared
# non-empty label, or (iii) a `==` row naming both labels (or their plabels).
.twolevel_cross_equal <- function(pt, key) {
  eq_rows <- pt[pt$op == "==", , drop = FALSE]
  tags <- function(row) setdiff(c(row$label, row$plabel), "")
  equal <- vapply(c("a", "b", "c_prime"), function(p) {
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
  names(equal)[equal]
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
  icc_m <- icc[[mediator]]
  reasons <- character(0)
  if (icc_x < icc_error) {
    reasons <- c(reasons, sprintf("the ICC of the treatment '%s' is %.4f (below %s)", treatment, icc_x, icc_error))
  }
  if (icc_m < icc_error) {
    reasons <- c(reasons, sprintf("the ICC of the mediator '%s' is %.4f (below %s)", mediator, icc_m, icc_error))
  }
  between <- 4:6
  if (is.null(V6) || any(!is.finite(V6[between, between]))) {
    reasons <- c(reasons, "a between-level covariance entry is not finite")
  } else if (!.twolevel_is_pd(V6)) {
    reasons <- c(reasons, "the joint covariance of the paths is not positive definite")
  }
  if (!isTRUE(converged)) reasons <- c(reasons, "the fit did not converge")
  list(
    icc = icc[unique(c(treatment, mediator, outcome))],
    identified = length(reasons) == 0L,
    weak = length(reasons) == 0L && (icc_x < icc_warn || icc_m < icc_warn),
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
  if (!is.character(mediator) || length(mediator) != 1L) {
    .twolevel_abort(
      "A two-level fit supports exactly one mediator; pass a single mediator name.",
      "medfit_error_twolevel_unsupported"
    )
  }
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
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
  within <- 1:3
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
  equal <- if (identified) .twolevel_cross_equal(pt, key) else character(0)
  rows <- if (identified) seq_len(6L) else within
  est <- stats::setNames(key$est[rows], key$path[rows])
  # A within-only object keeps the audit rows but not between numbers it says do not exist
  shown <- if (identified) rep(TRUE, 6L) else key$level == "within"
  se <- rep(NA_real_, 6L)
  se[shown] <- .safe_se(diag(V6)[shown], "the two-level fit")
  table <- data.frame(
    path = key$path, level = key$level, lhs = key$lhs, op = key$op, rhs = key$rhs, label = key$label,
    free = key$free, est = ifelse(shown, key$est, NA_real_), se = ifelse(shown, unname(se), NA_real_),
    stringsAsFactors = FALSE
  )
  opts <- lavaan::lavInspect(object, "options")
  paths <- stats::setNames(key$est, key$path)
  between_val <- function(nm) if (identified) unname(paths[[nm]]) else NA_real_

  TwoLevelMediationData(
    a_within = unname(paths[["a_within"]]), b_within = unname(paths[["b_within"]]),
    c_prime_within = unname(paths[["c_prime_within"]]),
    a_between = between_val("a_between"), b_between = between_val("b_between"),
    c_prime_between = between_val("c_prime_between"),
    estimates = est,
    vcov = V6[rows, rows, drop = FALSE],
    parameter_table = table,
    treatment = treatment, mediator = mediator, outcome = outcome,
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
    lavaan_version = .twolevel_fit_version(object),
    call = paste(deparse(object@call), collapse = " "),
    between_parameterization = "latent",
    data = NULL,
    source_package = "lavaan"
  )
}
