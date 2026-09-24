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

#' Tidy a medfit Object
#'
#' @description
#' Convert a mediation data object or a [BootstrapResult] into a tidy tibble,
#' one row per path coefficient or effect.
#'
#' @param x A [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], [JointMediationData], or [BootstrapResult]
#'   object.
#' @param ... Passed to the class method: `type` (`"all"`, `"paths"`,
#'   `"effects"`, and for interaction objects `"components"`), `conf.int`
#'   (logical, add `conf.low`/`conf.high`), and `conf.level` (default 0.95).
#'
#' @return A tibble (a data frame if tibble is not installed) with columns
#'   `term`, `estimate`, `std.error`, and, when `conf.int = TRUE`, `conf.low`
#'   and `conf.high`.
#'
#' @details
#' Path standard errors are the square roots of the diagonal of `@vcov`.
#' Effect standard errors (NIE, NDE, TE, and for interaction objects the
#' four-way components) use the delta method over the full `@vcov`, the same
#' computation as `confint(parm = "effects")`, so `tidy(conf.int = TRUE)`
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
#' generics::tidy(med_data, type = "effects", conf.int = TRUE)
#'
#' @seealso [bootstrap_mediation()], [MediationData]
#' @export
tidy.S7_object <- function(x, ...) {
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
  if (S7::S7_inherits(x, BootstrapResult)) {
    return(.tidy_bootstrap_result(x, ...))
  }

  stop("tidy() not implemented for this S7 object type.", call. = FALSE)
}


#' @export
glance.S7_object <- function(x, ...) {
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
  if (S7::S7_inherits(x, BootstrapResult)) {
    return(.glance_bootstrap_result(x, ...))
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
#' @param conf.int Logical: include confidence intervals? (default: FALSE)
#' @param conf.level Confidence level for intervals (default: 0.95)
#' @param ... Additional arguments (ignored)
#'
#' @return A tibble with columns:
#'   \itemize{
#'     \item `term`: Name of the coefficient or effect
#'     \item `estimate`: Point estimate
#'     \item `std.error`: Standard error (if available)
#'     \item `conf.low`: Lower CI bound (if conf.int = TRUE)
#'     \item `conf.high`: Upper CI bound (if conf.int = TRUE)
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
#' tidy(result, conf.int = TRUE)
#'
#' @noRd
.tidy_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                 conf.int = FALSE, conf.level = 0.95, ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL      # a, b, c_prime
  effect_vec <- if (type %in% c("all", "effects")) {
    c(nie = as.numeric(nie(x)), nde = as.numeric(nde(x)), te = as.numeric(te(x)))
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf.int, conf.level)
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
                                        conf.int = FALSE, conf.level = 0.95, ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  # paths() names the d paths by mediator pair (d, or d21, d32, ...);
  # @vcov aliases them d1..dk
  path_alias <- c("a", paste0("d", seq_along(x@d_path)), "b", "c_prime")
  effect_vec <- if (type %in% c("all", "effects")) {
    c(nie = as.numeric(nie(x)), nde = as.numeric(nde(x)), te = as.numeric(te(x)))
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf.int, conf.level,
                      path_alias = path_alias)
}


#' Glance at a SerialMediationData Object
#'
#' @inheritParams glance.MediationData
#' @param x A SerialMediationData object
#'
#' @noRd
.glance_serial_mediation_data <- function(x, ...) {
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
#' `confint()` uses, so `tidy(conf.int = TRUE)` and `confint()` agree. An
#' object without the alias rows gets `NA` SEs rather than an error. No
#' warning is raised here (GRILL D3).
#'
#' @param x A mediation data object with `@vcov`
#' @param path_vec Named numeric vector of path coefficients (or `NULL`)
#' @param effect_vec Named numeric vector of effects (or `NULL`); names must be
#'   canonical `.effect_se()` keys
#' @param conf.int,conf.level As in `.tidy_mediation_data()`
#' @param path_alias `@vcov` row names for `path_vec`, when they differ from
#'   `names(path_vec)` (serial d paths)
#' @noRd
.tidy_paths_effects <- function(x, path_vec, effect_vec, conf.int, conf.level,
                                path_alias = names(path_vec)) {
  vc <- x@vcov
  # match() gives NA (not an error) for a path name missing from @vcov
  path_se <- sqrt(diag(vc)[match(path_alias, rownames(vc))])
  effect_se <- if (length(effect_vec)) .effect_se_or_na(x, names(effect_vec)) else NULL

  result <- data.frame(
    term = c(names(path_vec), names(effect_vec)),
    estimate = unname(c(path_vec, effect_vec)),
    std.error = unname(c(path_se, effect_se)),
    stringsAsFactors = FALSE
  )

  if (conf.int) {
    z <- stats::qnorm(1 - (1 - conf.level) / 2)
    result$conf.low <- result$estimate - z * result$std.error
    result$conf.high <- result$estimate + z * result$std.error
  }

  if (requireNamespace("tibble", quietly = TRUE)) {
    result <- tibble::as_tibble(result)
  }

  result
}


#' Tidy a ParallelMediationData Object
#'
#' @param x A ParallelMediationData object
#' @param type `"all"` (default), `"paths"` (a1, b1, ..., c_prime), or
#'   `"effects"` (nie, nde, te)
#' @param conf.int Logical: add normal-approximation CIs from `std.error`?
#' @param conf.level Confidence level (default 0.95)
#' @param ... Additional arguments (ignored)
#' @return A tibble with `term`, `estimate`, `std.error` (and `conf.low`,
#'   `conf.high` when `conf.int = TRUE`)
#' @noRd
.tidy_parallel_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                          conf.int = FALSE, conf.level = 0.95,
                                          ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  effect_vec <- if (type %in% c("all", "effects")) {
    c(nie = as.numeric(nie(x)), nde = as.numeric(nde(x)), te = as.numeric(te(x)))
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf.int, conf.level)
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
#' @param conf.int Logical: add normal-approximation CIs from `std.error`?
#' @param conf.level Confidence level (default 0.95)
#' @param ... Additional arguments (ignored)
#' @return A tibble with `term`, `estimate`, `std.error` (and `conf.low`,
#'   `conf.high` when `conf.int = TRUE`)
#' @noRd
.tidy_interaction_mediation_data <- function(x,
                                             type = c("all", "paths",
                                                      "components", "effects"),
                                             conf.int = FALSE, conf.level = 0.95,
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
  .tidy_paths_effects(x, path_vec, effect_vec, conf.int, conf.level)
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
#' @param conf.int Logical: add normal-approximation CIs from `std.error`?
#' @param conf.level Confidence level (default 0.95)
#' @param ... Additional arguments (ignored)
#' @return A tibble with `term`, `estimate`, `std.error` (and `conf.low`,
#'   `conf.high` when `conf.int = TRUE`)
#' @noRd
.tidy_joint_mediation_data <- function(x, type = c("all", "paths", "effects"),
                                       conf.int = FALSE, conf.level = 0.95,
                                       ...) {
  type <- match.arg(type)
  path_vec <- if (type %in% c("all", "paths")) paths(x) else NULL
  effect_vec <- if (type %in% c("all", "effects")) {
    c(cde = x@cde, nde = x@nde, nie = x@nie, te = x@total_effect)
  }
  .tidy_paths_effects(x, path_vec, effect_vec, conf.int, conf.level)
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
    std.error = if (x@method != "plugin") stats::sd(x@boot_estimates) else NA_real_,
    conf.low = x@ci_lower,
    conf.high = x@ci_upper,
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
