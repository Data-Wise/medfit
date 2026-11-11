# =============================================================================
# TwoLevelMediationData: two-level (1-1-1) mediation from a lavaan two-level fit (#394, slice S2)
# =============================================================================

#' TwoLevelMediationData Class
#'
#' S7 class for two-level mediation in which treatment, mediator and outcome are all measured on level-1
#' units nested in clusters (1-1-1), with the paths estimated separately at the within and the between
#' level (latent cluster means, fixed slopes). Built by [extract_mediation()] from a `lavaan` two-level
#' fit; the same class is the target of a native fitter later (`source` says which).
#'
#' Per level the indirect effect is \eqn{NIE_l = a_l b_l}{NIE_l = a_l * b_l}, the direct effect is
#' \eqn{c'_l}{c'_l}, and the contrast \eqn{NIE_w - NIE_b}{NIE_w - NIE_b} is descriptive, not a test. When the
#' between level cannot be identified (for example a treatment with no between-cluster variance) the object
#' is **within-only**: the between properties are `NA_real_` and the between rows are absent from
#' `estimates` and `vcov`.
#'
#' @param a_within,b_within,c_prime_within Numeric scalars: within-level paths (always finite).
#' @param a_between,b_between,c_prime_between Numeric scalars: between-level paths; `NA_real_` when
#'   `between_identified` is `FALSE`.
#' @param estimates Named numeric vector of the identified path rows, in the order above.
#' @param vcov Covariance matrix of `estimates`: the sub-block of the fit's joint covariance, so the
#'   cross-level covariances are carried.
#' @param parameter_table Data frame, one row per path row (`path`, `level`, `lhs`, `op`, `rhs`, `label`,
#'   `free`, `est`, `se`), kept for audit.
#' @param treatment,mediator,outcome,cluster Character scalars: variable names.
#' @param n_obs,n_clusters Integer scalars: rows used and number of clusters.
#' @param cluster_sizes Integer vector of cluster sizes (length `n_clusters`).
#' @param icc Named numeric vector: intraclass correlation of treatment, mediator and outcome.
#' @param between_identified Logical scalar: whether the between level is identified.
#' @param admissible Logical scalar: `lavaan::lavInspect(fit, "post.check")`.
#' @param converged Logical scalar: whether the fit converged.
#' @param cross_level_equal Character vector: paths (`"a"`, `"b"`, `"c_prime"`) equated across levels.
#' @param fixed_paths Character vector: path rows with `free == 0` (variance 0 in `vcov`).
#' @param source Character scalar: `"lavaan"` or `"native"`.
#' @param fixed_x,information,h1_information,se_type,estimator,missing How the fit was made, read from it.
#' @param lavaan_version,call Character scalars: provenance of the fit.
#' @param between_parameterization Character scalar: `"latent"` (cluster means are latent).
#' @param data Data frame or `NULL`: always `NULL` for the lavaan adapter (the fit is never refit and the data
#'   are not copied); kept for the contract shared with the other mediation classes, which read `@data`.
#' @param source_package Character scalar: `"lavaan"`; kept for the dependents contract shared with the other
#'   mediation classes (`tests/testthat/test-dependents-contract.R` pins it across classes).
#'
#' @return A `TwoLevelMediationData` S7 object.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("lavaan", quietly = TRUE)) {
#'   set.seed(1)
#'   id <- rep(1:60, each = 5)
#'   xb <- stats::rnorm(60)[id]
#'   x <- xb + stats::rnorm(300)
#'   m <- 0.5 * x + stats::rnorm(60)[id] + stats::rnorm(300)
#'   y <- 0.4 * m + 0.2 * x + stats::rnorm(60)[id] + stats::rnorm(300)
#'   d <- data.frame(id = id, X = x, M = m, Y = y)
#'   model <- "
#'     level: 1
#'       M ~ X
#'       Y ~ M + X
#'     level: 2
#'       M ~ X
#'       Y ~ M + X
#'   "
#'   fit <- lavaan::sem(model, data = d, cluster = "id")
#'   td <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")
#'   td@a_within * td@b_within
#' }
#' }
#'
#' @export
TwoLevelMediationData <- S7::new_class(
  "TwoLevelMediationData",
  package = "medfit",
  properties = list(
    # Paths (scalars); also stored as alias rows of `estimates` and `vcov`
    a_within = S7::class_numeric,
    b_within = S7::class_numeric,
    c_prime_within = S7::class_numeric,
    a_between = S7::class_numeric,
    b_between = S7::class_numeric,
    c_prime_between = S7::class_numeric,

    # Parameters
    estimates = S7::class_numeric,
    vcov = S7::new_S3_class("matrix"),
    parameter_table = S7::class_data.frame,

    # Variables
    treatment = S7::class_character,
    mediator = S7::class_character,
    outcome = S7::class_character,
    cluster = S7::class_character,

    # Design
    n_obs = S7::class_integer,
    n_clusters = S7::class_integer,
    cluster_sizes = S7::class_integer,

    # Diagnostics
    icc = S7::class_numeric,
    between_identified = S7::class_logical,
    admissible = S7::class_logical,
    converged = S7::class_logical,
    cross_level_equal = S7::class_character,
    fixed_paths = S7::class_character,

    # Provenance: read from the fit, never refit
    source = S7::class_character,
    fixed_x = S7::class_logical,
    information = S7::class_character,
    h1_information = S7::class_character,
    se_type = S7::class_character,
    estimator = S7::class_character,
    missing = S7::class_character,
    lavaan_version = S7::class_character,
    call = S7::class_character,
    between_parameterization = S7::class_character,

    # Data and metadata (`class_data.frame | NULL` has no NULL default of its own)
    data = S7::new_property(S7::class_data.frame | NULL, default = NULL),
    source_package = S7::class_character
  ),

  validator = function(self) {
    within_rows <- c("a_within", "b_within", "c_prime_within")
    between_rows <- c("a_between", "b_between", "c_prime_between")
    identified <- self@between_identified

    # --- Scalars ---
    scalars <- list(
      treatment = self@treatment, mediator = self@mediator, outcome = self@outcome,
      cluster = self@cluster, n_obs = self@n_obs, n_clusters = self@n_clusters,
      between_identified = self@between_identified, admissible = self@admissible,
      converged = self@converged, source = self@source, fixed_x = self@fixed_x,
      information = self@information, h1_information = self@h1_information,
      se_type = self@se_type, estimator = self@estimator, missing = self@missing,
      lavaan_version = self@lavaan_version, call = self@call,
      between_parameterization = self@between_parameterization,
      source_package = self@source_package
    )
    for (nm in names(scalars)) {
      if (length(scalars[[nm]]) != 1L || is.na(scalars[[nm]])) {
        return(sprintf("%s must be a single non-missing value", nm))
      }
    }
    for (nm in within_rows) {
      value <- S7::prop(self, nm)
      if (length(value) != 1L || !is.finite(value)) {
        return(sprintf("%s must be a single finite value", nm))
      }
    }
    for (nm in between_rows) {
      value <- S7::prop(self, nm)
      if (length(value) != 1L) {
        return(sprintf("%s must be a single value", nm))
      }
      if (identified && !is.finite(value)) {
        return(sprintf("%s must be finite when between_identified is TRUE", nm))
      }
      if (!identified && !is.na(value)) {
        return(sprintf("%s must be NA when between_identified is FALSE", nm))
      }
    }
    if (!self@source %in% c("lavaan", "native")) {
      return("source must be \"lavaan\" or \"native\"")
    }

    # --- Design ---
    if (self@n_clusters != length(self@cluster_sizes)) {
      return("n_clusters must equal length(cluster_sizes)")
    }
    if (self@n_clusters < 2L) {
      return("a cluster design needs at least 2 clusters")
    }
    if (anyNA(self@cluster_sizes) || any(self@cluster_sizes < 1L)) {
      return("cluster_sizes must all be at least 1")
    }
    if (self@n_obs != sum(self@cluster_sizes)) {
      return("n_obs must equal sum(cluster_sizes)")
    }

    # --- Diagnostics ---
    icc <- self@icc
    if (anyNA(icc) || any(icc < 0) || any(icc > 1)) {
      return("icc must hold values in [0, 1]")
    }
    if (!identified && length(self@cross_level_equal) > 0L) {
      return("cross_level_equal must be empty when between_identified is FALSE")
    }

    # --- Estimates, vcov and the alias rows ---
    if (nrow(self@vcov) != ncol(self@vcov)) {
      return("vcov must be a square matrix")
    }
    if (length(self@estimates) != nrow(self@vcov)) {
      return("Number of estimates must match vcov dimensions")
    }
    nms <- names(self@estimates)
    if (is.null(nms) || anyNA(nms) || anyDuplicated(nms)) {
      return("estimates must have unique names")
    }
    if (!identical(rownames(self@vcov), nms) || !identical(colnames(self@vcov), nms)) {
      return("vcov dimnames must equal names(estimates)")
    }
    if (any(!is.finite(self@estimates))) {
      return("estimates must be finite")
    }
    if (any(!is.finite(self@vcov))) {
      return("vcov must be finite")
    }
    vscale <- max(1, abs(self@vcov))
    if (max(abs(self@vcov - t(self@vcov))) > 1e-8 * vscale) {
      return("vcov must be symmetric")
    }
    if (any(diag(self@vcov) < -1e-8 * vscale)) {
      return("the diagonal of vcov (the variances) must be non-negative")
    }
    if (!all(self@fixed_paths %in% nms)) {
      return("fixed_paths must name rows of estimates")
    }
    if (!identified && any(between_rows %in% nms)) {
      return("a within-only object must not carry between rows in estimates and vcov")
    }
    aliases <- if (identified) c(within_rows, between_rows) else within_rows
    if (!all(aliases %in% nms)) {
      return(sprintf("estimates and vcov must carry the alias rows %s", paste(aliases, collapse = ", ")))
    }
    paths <- vapply(aliases, function(nm) S7::prop(self, nm), numeric(1))
    if (!isTRUE(all.equal(unname(self@estimates[aliases]), unname(paths), tolerance = 1e-12))) {
      return("alias rows of estimates must equal the path properties")
    }

    # --- Parameter table ---
    needed <- c("path", "level", "lhs", "op", "rhs", "label", "free", "est", "se")
    if (!all(needed %in% names(self@parameter_table))) {
      return(sprintf("parameter_table must have the columns %s", paste(needed, collapse = ", ")))
    }

    NULL
  }
)


# The contrast NIE_within - NIE_between is NA when the between level is unidentified or a or b is equated
# across levels (it is then zero by constraint, not an estimate).
.twolevel_contrast_available <- function(x) {
  isTRUE(x@between_identified) && !any(c("a", "b") %in% x@cross_level_equal)
}

#' Print Method for TwoLevelMediationData
#'
#' @param x A TwoLevelMediationData object
#' @param ... Additional arguments (unused)
#' @noRd
S7::method(print, TwoLevelMediationData) <- function(x, ...) {
  nie_w <- x@a_within * x@b_within
  nie_b <- x@a_between * x@b_between
  cat("<TwoLevelMediationData>\n")
  cat(sprintf("  %s -> %s -> %s  (clusters: %s; %s fit; between level: latent cluster means)\n",
              x@treatment, x@mediator, x@outcome, x@cluster, x@source))
  cat(sprintf("  n = %d in %d clusters (sizes %d to %d)   |   ICC: %s\n",
              x@n_obs, x@n_clusters, min(x@cluster_sizes), max(x@cluster_sizes),
              paste(sprintf("%s %.3f", names(x@icc), x@icc), collapse = ", ")))
  cat(sprintf("  a_within = %+.4f   b_within = %+.4f   c_prime_within = %+.4f\n",
              x@a_within, x@b_within, x@c_prime_within))
  if (x@between_identified) {
    cat(sprintf("  a_between = %+.4f   b_between = %+.4f   c_prime_between = %+.4f\n",
                x@a_between, x@b_between, x@c_prime_between))
  } else {
    cat("  Between level: not identified (within-only result); between paths and the contrast are NA\n")
  }
  cat(sprintf("  NIE within  (a_within * b_within)   = %+.4f\n", nie_w))
  if (x@between_identified) {
    cat(sprintf("  NIE between (a_between * b_between) = %+.4f\n", nie_b))
    contrast <- if (.twolevel_contrast_available(x)) sprintf("%+.4f", nie_w - nie_b) else "NA (constrained)"
    cat(sprintf("  Contrast (within - between)         = %s  (descriptive, not a test)\n", contrast))
  }
  if (length(x@cross_level_equal) > 0L) {
    cat(sprintf("  Paths equated across levels: %s\n", paste(x@cross_level_equal, collapse = ", ")))
  }
  if (length(x@fixed_paths) > 0L) {
    cat(sprintf("  Paths fixed: %s\n", paste(x@fixed_paths, collapse = ", ")))
  }
  if (!isTRUE(x@admissible)) cat("  Warning: the fit is not admissible (lavaan post.check is FALSE)\n")
  invisible(x)
}


# The "Estimand and assumptions" block shared by summary(): fixed slopes, latent cluster means, the model
# the effects are read from, and the `fixed_x` note (stated without a number: the size of the SE gap depends
# on the data).
.twolevel_assumptions_block <- function(x) {
  items <- c(
    sprintf(paste0("Design: treatment `%s`, mediator `%s` and outcome `%s` measured on level-1 units in %d ",
                   "clusters (`%s`); the paths are estimated separately at the within and the between ",
                   "level."),
            x@treatment, x@mediator, x@outcome, x@n_clusters, x@cluster),
    "Fixed slopes (no random slopes); between effects are through latent cluster means.",
    "Linear paths with no mediator-by-treatment product; no confounding of the paths beyond the model.",
    "Per level NIE = a * b, NDE = c', TE = NIE + c'; the contrast is within minus between NIE.",
    "No cross-level total effect or proportion mediated is defined.",
    "Intervals are Wald (delta method); there is no small-sample correction."
  )
  if (isTRUE(x@fixed_x)) {
    items <- c(items, paste0(
      "fixed_x is TRUE: the between-path standard errors are conditional on the sample between-level ",
      "moments of the treatment; refit with fixed.x = FALSE for the unconditional ones."
    ))
  }
  wrap <- function(txt, first) strwrap(txt, width = 88, initial = first, prefix = "", exdent = 4)
  c("Estimand and assumptions:", wrap(items[1], "  "), unlist(lapply(items[-1], wrap, first = "  - ")))
}

#' Summary Method for TwoLevelMediationData
#'
#' @param object A TwoLevelMediationData object
#' @param level Confidence level for the Wald intervals.
#' @param ... Additional arguments (ignored)
#' @noRd
S7::method(summary, TwoLevelMediationData) <- function(object, level = 0.95, ...) {
  checkmate::assert_number(level, lower = 0, upper = 1, .var.name = "level")
  est <- .twolevel_effect_vec(object)
  se <- .effect_se_or_na(object, names(est))
  z <- stats::qnorm(1 - (1 - level) / 2)
  effects <- data.frame(estimate = unname(est), std_error = unname(se),
                        conf_low = unname(est - z * se), conf_high = unname(est + z * se),
                        row.names = names(est))
  p <- paths(object)
  # A path with no row in vcov (the between paths of a within-only object) has no SE; only rows that exist
  # are checked for an invalid variance.
  p_idx <- match(names(p), rownames(object@vcov))
  p_se <- rep(NA_real_, length(p))
  p_se[!is.na(p_idx)] <- .safe_se(diag(object@vcov)[p_idx[!is.na(p_idx)]], "the two-level paths")
  structure(
    list(
      effects = effects,
      level = level,
      paths = data.frame(estimate = unname(p), std_error = unname(p_se), row.names = names(p)),
      block = .twolevel_assumptions_block(object),
      variables = c(treatment = object@treatment, mediator = object@mediator,
                    outcome = object@outcome, cluster = object@cluster),
      n_obs = object@n_obs,
      n_clusters = object@n_clusters,
      cluster_sizes = range(object@cluster_sizes),
      icc = object@icc,
      provenance = c(
        source = object@source, lavaan_version = object@lavaan_version, estimator = object@estimator,
        fixed_x = as.character(object@fixed_x), information = object@information,
        h1_information = object@h1_information, se = object@se_type, missing = object@missing
      ),
      flags = c(
        if (!object@between_identified) "Between level not identified: within-only result",
        if (length(object@cross_level_equal) > 0L) {
          paste0("Paths equated across levels: ", paste(object@cross_level_equal, collapse = ", "))
        },
        if (length(object@fixed_paths) > 0L) {
          paste0("Paths fixed: ", paste(object@fixed_paths, collapse = ", "))
        },
        if (!isTRUE(object@admissible)) "The fit is not admissible (lavaan post.check is FALSE)",
        if (!isTRUE(object@converged)) "The fit did not converge"
      )
    ),
    class = "summary_TwoLevelMediationData"
  )
}

#' Print Summary for TwoLevelMediationData
#'
#' @param x A summary_TwoLevelMediationData object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x`. Called for its side effect of printing the formatted summary.
#' @noRd
print_summary_twolevel_mediation_data <- function(x, ...) {
  cat("Summary of TwoLevelMediationData\n")
  cat("================================\n\n")
  cat(sprintf("%s -> %s -> %s, clusters `%s`\n", x$variables["treatment"], x$variables["mediator"],
              x$variables["outcome"], x$variables["cluster"]))
  cat("\nPath coefficients:\n")
  print(round(x$paths, 4))
  cat("\nEffects (unit contrast 0 -> 1):\n")
  print(round(x$effects, 4))
  cat(sprintf("  %g%% Wald intervals (delta method over the joint covariance).\n", 100 * x$level))
  cat("  The contrast (within - between NIE) is descriptive, not a test.\n")
  cat(sprintf("\nSample Size: %d in %d clusters (sizes %d to %d)\n", x$n_obs, x$n_clusters,
              x$cluster_sizes[1], x$cluster_sizes[2]))
  cat("ICC:        ", paste(sprintf("%s %.3f", names(x$icc), x$icc), collapse = ", "), "\n")
  cat(sprintf(
    "Fit:         %s %s (estimator %s, fixed_x %s, information %s, h1_information %s, se %s, missing %s)\n",
    x$provenance[["source"]], x$provenance[["lavaan_version"]], x$provenance[["estimator"]],
    x$provenance[["fixed_x"]], x$provenance[["information"]], x$provenance[["h1_information"]],
    x$provenance[["se"]], x$provenance[["missing"]]
  ))
  if (length(x$flags) > 0L) cat(paste0("  ", x$flags, "\n"), sep = "")
  cat("\n")
  cat(paste0(x$block, "\n"), sep = "")
  invisible(x)
}
