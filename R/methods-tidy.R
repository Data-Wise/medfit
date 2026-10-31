# Tidyverse Methods (tidy, glance)
#
# This file provides tidyverse-compatible methods for mediation objects:
# - tidy(): Convert to tidy tibble of effects/paths
# - glance(): Single-row summary of model
#
# Note: S7 objects need explicit dispatch handling since S3 method dispatch
# looks for "medfit::MediationData" as the class name, which can't be
# used in a function name directly. We use wrapper functions instead.

# Register S3 methods for S7 classes by adding explicit class attribute
# Since S7 class names contain "::", we use .onLoad to register methods

#' Tidy, Glance, and Inference Methods for medfit Objects
#'
#' @description
#' `tidy()` converts a mediation data object or a [BootstrapResult] into a
#' tidy tibble, one row per path coefficient or effect. `glance()` returns a
#' one-row summary. The base generics [stats::coef()], [stats::vcov()],
#' [stats::confint()], and [stats::nobs()] also have methods for every
#' mediation class; see Details.
#'
#' @param x A [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], [JointMediationData], [ClusterMediationData],
#'   [BootstrapResult], or [SEMFit] object (a `SEMFit` has its own columns; see
#'   [SEMFit-methods]).
#' @param ... Passed to the class method: `type` (`"all"`, `"paths"`,
#'   `"effects"`, and for interaction objects `"components"`), `conf_int`
#'   (logical, add `conf_low`/`conf_high`), and `conf_level` (default 0.95).
#'
#' @return `tidy()`: a tibble (a data frame if tibble is not installed) with
#'   columns `term`, `estimate`, `std_error`, and, when `conf_int = TRUE`,
#'   `conf_low` and `conf_high`.
#'
#'   `glance()`: a one-row tibble with `nie`, `nde`, `te`, `pm`, `nobs`, and
#'   `converged`; interaction objects add `interaction` and `m_star`, and
#'   joint objects add `cde`, `structure`, `n_mediators`, `interactions`, and
#'   `m_star`.
#'
#' @details
#' Path standard errors are the square roots of the diagonal of `@vcov`.
#' Effect standard errors (NIE, NDE, TE, and for interaction objects the
#' four-way components) use the delta method over the full `@vcov`, the same
#' computation as `confint(parm = "effects")`, so `tidy(conf_int = TRUE)`
#' reproduces `confint()` exactly. Intervals are normal approximations
#' (\eqn{\hat{\theta} \pm z \, SE}{estimate +/- z * SE}); the sampling
#' distribution of a product of coefficients is skewed, so for inference on
#' indirect effects prefer [bootstrap_mediation()]. `tidy()` raises no warning
#' about this; `confint()` does.
#'
#' For a serial chain fitted as separate lm/glm regressions, `@vcov` has zero
#' covariances between equations, and the effect standard errors inherit that.
#' The proportion mediated (reported by `glance()`) has no standard error: it
#' is a ratio whose delta-method standard error is unstable when the total
#' effect is near zero, so bootstrap it instead.
#'
#' ## Bounded FIML
#'
#' For data extracted from a bounded FIML fit, `tidy()`, coefficients, covariance
#' and normal path/effect intervals are supported, but `glance()`, `pm()` and
#' bootstrap intervals refuse. The bootstrap recommendations above apply only
#' to other supported objects. `glance()` on the source [SEMFit] instead retains
#' likelihood and information-criterion fields, with model tests unavailable.
#' See [fit_sem()] for the bounded model, assumptions and inference limits.
#'
#' ## Base methods
#'
#' - `coef(object, type = "paths")`: the path coefficients; `type = "effects"`
#'   gives the effects, `"all"` both, and for interaction objects
#'   `"components"` gives the four-way components.
#' - `vcov(object)`: the stored `@vcov`, covering every entry of `@estimates`.
#' - `confint(object, parm = "paths", level = 0.95)`: normal intervals for the
#'   paths, or with `parm = "effects"` for the effects using the delta-method
#'   standard errors above (interaction objects also accept
#'   `parm = "components"`). With `parm = "effects"` it warns that the normal
#'   approximation may be inaccurate for an indirect effect.
#' - `nobs(object)`: the number of observations.
#'
#' @examples
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#' # tidy() is the generic from the generics package (also re-exported by broom)
#' generics::tidy(med_data)
#' generics::tidy(med_data, type = "effects", conf_int = TRUE)
#'
#' @seealso [bootstrap_mediation()], [MediationData]
tidy_s7_object <- function(x, ...) {
  if (any(c("conf.int", "conf.level") %in% ...names())) {
    return(do.call(tidy_s7_object, c(list(x), .rename_dotted_tidy_args(list(...)))))
  }
  if (S7::S7_inherits(x, MediationData)) {
    return(.tidy_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, SerialMediationData)) {
    return(.tidy_serial_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, ParallelMediationData)) {
    return(.tidy_parallel_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, InteractionMediationData)) {
    return(.tidy_interaction_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, JointMediationData)) {
    return(.tidy_joint_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, ClusterMediationData)) {
    return(.tidy_cluster_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, BootstrapResult)) {
    return(.tidy_bootstrap_result(x, ...))
  }
  if (S7::S7_inherits(x, SEMFit)) {
    return(.tidy_semfit(x, ...))
  }

  stop("tidy() not implemented for this S7 object type.", call. = FALSE)
}


#' @rdname tidy_s7_object
glance_s7_object <- function(x, ...) {
  if (S7::S7_inherits(x, MediationData)) {
    return(.glance_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, SerialMediationData)) {
    return(.glance_serial_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, ParallelMediationData)) {
    return(.glance_parallel_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, InteractionMediationData)) {
    return(.glance_interaction_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, JointMediationData)) {
    return(.glance_joint_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, ClusterMediationData)) {
    return(.glance_cluster_mediation_data(x, ...))
  }
  if (S7::S7_inherits(x, BootstrapResult)) {
    return(.glance_bootstrap_result(x, ...))
  }
  if (S7::S7_inherits(x, SEMFit)) {
    return(.glance_semfit(x, ...))
  }

  stop("glance() not implemented for this S7 object type.", call. = FALSE)
}

#' Tidy a MediationData Object
#'
#' @description
#' Convert a MediationData object to a tidy tibble containing
#' path coefficients and mediation effects.
#'
#' @param x A MediationData object
#' @param type Character: what to include in output
#'   \itemize{
#'     \item `"all"`: Both paths and effects (default)
#'     \item `"paths"`: Only path coefficients (a, b, c')
#'     \item `"effects"`: Only mediation effects (NIE, NDE, TE)
#'   }
#' @param conf_int Logical: include confidence intervals? (default: FALSE)
#' @param conf_level Confidence level for intervals (default: 0.95)
#' @param ... Additional arguments (ignored)
#'
#' @return A tibble with columns:
#'   \itemize{
#'     \item `term`: Name of the coefficient or effect
#'     \item `estimate`: Point estimate
#'     \item `std_error`: Standard error (if available)
#'     \item `conf_low`: Lower CI bound (if conf_int = TRUE)
#'     \item `conf_high`: Upper CI bound (if conf_int = TRUE)
#'   }
#'
#' @examples
#' result <- med(
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1",
#'   outcome = "outcome",
#'   covariates = c("covariate1", "covariate2")
#' )
#'
#' # Get tidy output
#' tidy(result)
#'
#' # Only effects
#' tidy(result, type = "effects")
#'
#' # With confidence intervals
#' tidy(result, conf_int = TRUE)
#'
#' @noRd
.tidy_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                 conf_int = FALSE, conf_level = 0.95, ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL      # a, b, c_prime
  effect_vec <- if (type %in% c("all", "effects")) {
    c(nie = as.numeric(nie(x)), nde = as.numeric(nde(x)), te = as.numeric(te(x)))
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf_int, conf_level)
}


#' Glance at a MediationData Object
#'
#' @description
#' Get a one-row summary of a MediationData object containing
#' key model statistics.
#'
#' @param x A MediationData object
#' @param ... Additional arguments (ignored)
#'
#' @return A one-row tibble with columns:
#'   \itemize{
#'     \item `nie`: Natural indirect effect
#'     \item `nde`: Natural direct effect
#'     \item `te`: Total effect
#'     \item `pm`: Proportion mediated
#'     \item `nobs`: Number of observations
#'     \item `converged`: Whether model converged
#'   }
#'
#' @examples
#' result <- med(
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1",
#'   outcome = "outcome",
#'   covariates = c("covariate1", "covariate2")
#' )
#'
#' glance(result)
#'
#' @noRd
.glance_mediation_data <- function(x, ...) {
  .sem_fiml_refuse(x, "glance() on extracted data")
  result <- data.frame(
    nie = as.numeric(nie(x)),
    nde = as.numeric(nde(x)),
    te = as.numeric(te(x)),
    pm = as.numeric(pm(x)),
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy a SerialMediationData Object
#'
#' @inheritParams tidy.MediationData
#' @param x A SerialMediationData object
#'
#' @noRd
.tidy_serial_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                        conf_int = FALSE, conf_level = 0.95, ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  # paths() names the d paths by mediator pair (d, or d21, d32, ...);
  # @vcov aliases them d1..dk
  path_alias <- if (!is.null(path_vec)) {
    c("a", paste0("d", seq_along(x@d_path)), "b", "c_prime")
  }
  effect_vec <- if (type %in% c("all", "effects")) {
    # nie: chain-specific (a * d1 * ... * b); nie_total + nde = te (all paths)
    te_val <- as.numeric(te(x))
    nde_val <- as.numeric(nde(x))
    c(nie = as.numeric(nie(x)), nie_total = te_val - nde_val,
      nde = nde_val, te = te_val)
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf_int, conf_level,
                      path_alias = path_alias)
}


#' Glance at a SerialMediationData Object
#'
#' @inheritParams glance.MediationData
#' @param x A SerialMediationData object
#'
#' @noRd
.glance_serial_mediation_data <- function(x, ...) {
  # One te() call: nie_total and pm derive from it (one warning when unavailable)
  te_val <- as.numeric(te(x))
  nde_val <- as.numeric(nde(x))
  result <- data.frame(
    nie = as.numeric(nie(x)),
    nie_total = te_val - nde_val,
    nde = nde_val,
    te = te_val,
    pm = as.numeric(.serial_pm_from_total(te_val, x@c_prime)),
    n_mediators = length(x@mediators),
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Build a Tidy Table from Named Path and Effect Vectors
#'
#' @description
#' Shared body for every mediation tidier. Path rows get standard errors from
#' the diagonal of `@vcov` (the path names, or `path_alias`, are aliases in it);
#' effect rows get delta-method standard errors from the same helper
#' `confint()` uses, so `tidy(conf_int = TRUE)` and `confint()` agree. An
#' object without the alias rows gets `NA` SEs rather than an error. No
#' warning is raised here (GRILL D3).
#'
#' @param x A mediation data object with `@vcov`
#' @param path_vec Named numeric vector of path coefficients (or `NULL`)
#' @param effect_vec Named numeric vector of effects (or `NULL`); names must be
#'   canonical `.effect_se()` keys
#' @param conf_int,conf_level As in `.tidy_mediation_data()`
#' @param path_alias `@vcov` row names for `path_vec`, when they differ from
#'   `names(path_vec)` (serial d paths)
#' @noRd
.tidy_paths_effects <- function(x, path_vec, effect_vec, conf_int, conf_level,
                                path_alias = names(path_vec), path_df = NULL) {
  vc <- x@vcov
  # match() gives NA (not an error) for a path name missing from @vcov
  path_se <- sqrt(diag(vc)[match(path_alias, rownames(vc))])
  effect_se <- if (length(effect_vec)) .effect_se_or_na(x, names(effect_vec)) else NULL
  if (.sem_fiml_origin(x) && "nie" %in% names(effect_se)) effect_se["nie"] <- NA_real_

  result <- data.frame(
    term = c(names(path_vec), names(effect_vec)),
    estimate = unname(c(path_vec, effect_vec)),
    std_error = unname(c(path_se, effect_se)),
    stringsAsFactors = FALSE
  )

  if (conf_int) {
    # Normal quantile, or a t quantile per path row when `path_df` is given
    # (Kenward-Roger df); effect rows stay normal.
    q <- rep(stats::qnorm(1 - (1 - conf_level) / 2), nrow(result))
    if (!is.null(path_df)) {
      i <- match(names(path_vec), result$term)
      q[i] <- stats::qt(1 - (1 - conf_level) / 2, df = path_df[names(path_vec)])
    }
    result$conf_low <- result$estimate - q * result$std_error
    result$conf_high <- result$estimate + q * result$std_error
  }

  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  if (.sem_fiml_is(x)) {
    attr(result, "fit_context") <- x@fit_context
    if (.sem_fiml_origin(x)) attr(result, "note") <- "NIE inference unavailable: zero delta gradient"
  }
  result
}


#' Tidy a ParallelMediationData Object
#'
#' @param x A ParallelMediationData object
#' @param type `"all"` (default), `"paths"` (a1, b1, ..., c_prime), or
#'   `"effects"` (nie, nde, te)
#' @param conf_int Logical: add normal-approximation CIs from `std_error`?
#' @param conf_level Confidence level (default 0.95)
#' @param ... Additional arguments (ignored)
#' @return A tibble with `term`, `estimate`, `std_error` (and `conf_low`,
#'   `conf_high` when `conf_int = TRUE`)
#' @noRd
.tidy_parallel_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                          conf_int = FALSE, conf_level = 0.95,
                                          ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  effect_vec <- if (type %in% c("all", "effects")) {
    c(nie = as.numeric(nie(x)), nde = as.numeric(nde(x)), te = as.numeric(te(x)))
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf_int, conf_level)
}


#' Glance at a ParallelMediationData Object
#'
#' @param x A ParallelMediationData object
#' @param ... Additional arguments (ignored)
#' @return A one-row tibble: nie, nde, te, pm, n_mediators, nobs, converged
#' @noRd
.glance_parallel_mediation_data <- function(x, ...) {
  result <- data.frame(
    nie = as.numeric(nie(x)),
    nde = as.numeric(nde(x)),
    te = as.numeric(te(x)),
    pm = as.numeric(pm(x)),
    n_mediators = length(x@mediators),
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy an InteractionMediationData Object
#'
#' @param x An InteractionMediationData object
#' @param type `"all"` (default), `"paths"` (a, b, c_prime, theta3),
#'   `"components"` (cde, int_ref, int_med, pie), or `"effects"` (nie, nde, te)
#' @param conf_int Logical: add normal-approximation CIs from `std_error`?
#' @param conf_level Confidence level (default 0.95)
#' @param ... Additional arguments (ignored)
#' @return A tibble with `term`, `estimate`, `std_error` (and `conf_low`,
#'   `conf_high` when `conf_int = TRUE`)
#' @noRd
.tidy_interaction_mediation_data <- function(x,
                                             type = c("all", "paths",
                                                      "components", "effects"),
                                             conf_int = FALSE, conf_level = 0.95,
                                             ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  components <- c(cde = x@cde, int_ref = x@int_ref, int_med = x@int_med,
                  pie = x@pie)
  effects <- c(nie = as.numeric(nie(x)), nde = as.numeric(nde(x)),
               te = as.numeric(te(x)))
  effect_vec <- switch(type,
    all = c(components, effects),
    paths = NULL,
    components = components,
    effects = effects
  )
  .tidy_paths_effects(x, path_vec, effect_vec, conf_int, conf_level)
}


#' Glance at an InteractionMediationData Object
#'
#' @param x An InteractionMediationData object
#' @param ... Additional arguments (ignored)
#' @return A one-row tibble: nie, nde, te, pm, interaction, m_star, nobs,
#'   converged
#' @noRd
.glance_interaction_mediation_data <- function(x, ...) {
  result <- data.frame(
    nie = as.numeric(nie(x)),
    nde = as.numeric(nde(x)),
    te = as.numeric(te(x)),
    pm = as.numeric(pm(x)),
    interaction = x@interaction,
    m_star = x@m_star,
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy a JointMediationData Object
#'
#' @param x A JointMediationData object
#' @param type `"all"` (default), `"paths"` (a1..aK, dij, b1..bK,
#'   theta3_<mediator>, c_prime), or `"effects"` (cde, nde, nie, te)
#' @param conf_int Logical: add normal-approximation CIs from `std_error`?
#' @param conf_level Confidence level (default 0.95)
#' @param ... Additional arguments (ignored)
#' @return A tibble with `term`, `estimate`, `std_error` (and `conf_low`,
#'   `conf_high` when `conf_int = TRUE`)
#' @noRd
.tidy_joint_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                       conf_int = FALSE, conf_level = 0.95,
                                       ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  effect_vec <- if (type %in% c("all", "effects")) {
    c(cde = x@cde, nde = x@nde, nie = x@nie, te = x@total_effect)
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf_int, conf_level)
}


#' Glance at a JointMediationData Object
#'
#' @param x A JointMediationData object
#' @param ... Additional arguments (ignored)
#' @return A one-row tibble: nie, nde, te, pm, cde, structure, n_mediators,
#'   interactions, m_star, nobs, converged
#' @noRd
.glance_joint_mediation_data <- function(x, ...) {
  result <- data.frame(
    nie = x@nie,
    nde = x@nde,
    te = x@total_effect,
    pm = as.numeric(pm(x)),
    cde = x@cde,
    structure = x@structure,
    n_mediators = length(x@mediators),
    interactions = paste(x@interactions, collapse = ", "),
    m_star = paste(sprintf("%s=%g", names(x@m_star), x@m_star), collapse = ", "),
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy a ClusterMediationData Object
#'
#' @param x A ClusterMediationData object
#' @param type `"all"` (default), `"paths"` (a, b_within, b_between, c_prime),
#'   or `"effects"` (nie, nde, te, own, spillover)
#' @param conf_int Logical: add normal-approximation CIs from `std_error`?
#' @param conf_level Confidence level (default 0.95)
#' @param ... Additional arguments (ignored)
#' @return A tibble with `term`, `estimate`, `std_error` (and `conf_low`,
#'   `conf_high` when `conf_int = TRUE`)
#' @noRd
.tidy_cluster_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                         conf_int = FALSE, conf_level = 0.95,
                                         ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  effect_vec <- if (type %in% c("all", "effects")) .cluster_effect_vec(x)
  path_df <- if (identical(x@se_type, "kr")) x@kr_df
  .tidy_paths_effects(x, path_vec, effect_vec, conf_int, conf_level,
                      path_df = path_df)
}


#' Glance at a ClusterMediationData Object
#'
#' @param x A ClusterMediationData object
#' @param ... Additional arguments (ignored)
#' @return A one-row tibble: nie, nde, te, pm, n_clusters, nobs, converged
#' @noRd
.glance_cluster_mediation_data <- function(x, ...) {
  result <- data.frame(
    nie = unclass(nie(x))[[1]],
    nde = x@c_prime,
    te = unclass(te(x))[[1]],
    pm = as.numeric(pm(x)),
    n_clusters = x@n_clusters,
    nobs = nobs(x),
    converged = x@converged,
    stringsAsFactors = FALSE
  )

  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy a BootstrapResult Object
#'
#' @param x A BootstrapResult object
#' @param ... Additional arguments (ignored)
#'
#' @return A tibble with bootstrap estimate and CI
#'
#' @noRd
.tidy_bootstrap_result <- function(x, ...) {
  result <- data.frame(
    term = "estimate",
    estimate = x@estimate,
    std_error = if (x@method != "plugin") stats::sd(x@boot_estimates) else NA_real_,
    conf_low = x@ci_lower,
    conf_high = x@ci_upper,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Glance at a BootstrapResult Object
#'
#' @param x A BootstrapResult object
#' @param ... Additional arguments (ignored)
#'
#' @return A one-row tibble with bootstrap summary
#'
#' @noRd
.glance_bootstrap_result <- function(x, ...) {
  result <- data.frame(
    estimate = x@estimate,
    ci_level = x@ci_level,
    method = x@method,
    n_boot = x@n_boot,
    stringsAsFactors = FALSE
  )

  # Convert to tibble if available
  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


# `conf.int` and `conf.level` became `conf_int` and `conf_level` (0.9.0); the old names keep working with a warning.
.rename_dotted_tidy_args <- function(args) {
  hit <- intersect(c("conf.int", "conf.level"), names(args))
  new <- gsub(".", "_", hit[1L], fixed = TRUE)
  lifecycle::deprecate_warn("0.9.0", paste0("tidy(", hit[1L], ")"), paste0("tidy(", new, ")"))
  names(args)[names(args) %in% hit] <- gsub(".", "_", names(args)[names(args) %in% hit], fixed = TRUE)
  args
}
