# Base R Generic Methods for MediationData
#
# This file implements methods for base R generics:
# - coef(): Extract path coefficients
# - vcov(): Extract variance-covariance matrix
# - confint(): Compute confidence intervals
# - nobs(): Get number of observations
#
# BootstrapResult gets coef() and confint() at the end of this file.

#' Extract Coefficients from MediationData
#'
#' @description
#' Extract path coefficients or effect estimates from a MediationData object.
#'
#' @param object A MediationData object
#' @param type Character: type of coefficients to extract
#'   \itemize{
#'     \item `"paths"`: Path coefficients a, b, c' (default)
#'     \item `"effects"`: Mediation effects NIE, NDE, TE
#'     \item `"all"`: Full parameter vector
#'   }
#' @param ... Additional arguments (ignored)
#'
#' @return Named numeric vector of coefficients
#'
#' @examples
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#'
#' # Extract path coefficients (default)
#' coef(med_data)
#'
#' # Extract effect estimates
#' coef(med_data, type = "effects")
#'
#' # Extract all parameters
#' coef(med_data, type = "all")
#'
#' @seealso [MediationData], [bootstrap_mediation()]
#' @noRd
S7::method(coef, MediationData) <- function(object, type = c("paths", "effects", "all"), ...) {
  type <- match.arg(type)

  switch(type,
    paths = c(
      a = object@a_path,
      b = object@b_path,
      c_prime = object@c_prime
    ),
    effects = {
      nie <- object@a_path * object@b_path
      nde <- object@c_prime
      te <- nie + nde
      c(nie = nie, nde = nde, te = te)
    },
    all = object@estimates
  )
}


#' Extract Coefficients from SerialMediationData
#'
#' @description
#' Extract path coefficients or effect estimates from a SerialMediationData object.
#'
#' @param object A SerialMediationData object
#' @param type Character: type of coefficients to extract
#'   \itemize{
#'     \item `"paths"`: Path coefficients a, d (vector), b, c' (default)
#'     \item `"effects"`: Mediation effects: indirect (product of paths), direct, total
#'     \item `"all"`: Full parameter vector
#'   }
#' @param ... Additional arguments (ignored)
#'
#' @return Named numeric vector of coefficients
#'
#' @noRd
S7::method(coef, SerialMediationData) <- function(object, type = c("paths", "effects", "all"), ...) {
  type <- match.arg(type)

  switch(type,
    paths = {
      n_mediators <- length(object@mediators)
      paths <- c(a = object@a_path)

      # Add d paths with names
      if (n_mediators == 2) {
        paths <- c(paths, d = object@d_path)
      } else {
        d_names <- paste0("d", seq(2, n_mediators), seq(1, n_mediators - 1))
        d_vals <- stats::setNames(object@d_path, d_names)
        paths <- c(paths, d_vals)
      }

      c(paths, b = object@b_path, c_prime = object@c_prime)
    },
    effects = {
      indirect <- object@a_path * prod(object@d_path) * object@b_path
      direct <- object@c_prime
      total <- indirect + direct
      c(indirect = indirect, direct = direct, total = total)
    },
    all = object@estimates
  )
}


#' Extract Variance-Covariance Matrix from MediationData
#'
#' @description
#' Extract the variance-covariance matrix of parameter estimates.
#'
#' @param object A MediationData object
#' @param ... Additional arguments (ignored)
#'
#' @return A numeric matrix
#'
#' @examples
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#'
#' vcov(med_data)
#'
#' @seealso [MediationData]
#' @noRd
S7::method(vcov, MediationData) <- function(object, ...) {
  object@vcov
}


#' Extract Variance-Covariance Matrix from SerialMediationData
#'
#' @param object A SerialMediationData object
#' @param ... Additional arguments (ignored)
#'
#' @return A numeric matrix
#' @noRd
S7::method(vcov, SerialMediationData) <- function(object, ...) {
  object@vcov
}


#' Confidence Intervals for MediationData
#'
#' @description
#' Compute confidence intervals for path coefficients using either
#' normal approximation or bootstrap methods.
#'
#' @param object A MediationData object
#' @param parm Character vector specifying parameters. Options:
#'   \itemize{
#'     \item `"paths"`: a, b, c' (default)
#'     \item `"effects"`: nie, nde, te
#'     \item Specific names: e.g., `c("a", "b")`
#'   }
#' @param level Confidence level (default: 0.95)
#' @param method Character: method for computing CIs
#'   \itemize{
#'     \item `"normal"`: Normal approximation using SE (default)
#'     \item `"boot"`: Bootstrap CI (requires separate bootstrap call)
#'   }
#' @param ... Additional arguments passed to bootstrap if method = "boot"
#'
#' @return A matrix with columns for lower and upper bounds
#'
#' @details
#' For `method = "normal"`, confidence intervals are computed as:
#' \deqn{\hat{\theta} \pm z_{1-\alpha/2} \times SE(\hat{\theta})}{theta-hat +/- z * SE}
#'
#' For the indirect effect (NIE), the normal approximation may not be accurate

#' due to the product of coefficients. Consider using bootstrap methods
#' via [bootstrap_mediation()] for more robust inference on mediation effects.
#'
#' @examples
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#'
#' # 95% CI for paths (default)
#' confint(med_data)
#'
#' # 90% CI
#' confint(med_data, level = 0.90)
#'
#' @seealso [bootstrap_mediation()] for bootstrap confidence intervals
#' @noRd
S7::method(confint, MediationData) <- function(object, parm = "paths", level = 0.95,
                                               method = c("normal", "boot"), ...) {
  method <- match.arg(method)

  if (method == "boot") {
    stop("Bootstrap CI requires bootstrap_mediation(). Use method = 'normal' ",
         "for quick CI or call bootstrap_mediation() directly.", call. = FALSE)
  }

  # Determine which parameters to compute CIs for
  if (identical(parm, "paths")) {
    coefs <- c(a = object@a_path, b = object@b_path, c_prime = object@c_prime)
    # Get SEs from vcov diagonal (need to find correct indices)
    vcov_mat <- object@vcov
    param_names <- names(object@estimates)

    # Find indices for a, b, c' in the full parameter vector
    # a: coefficient of treatment in mediator model (typically "m_<treatment>")
    # b: coefficient of mediator in outcome model (typically "y_<mediator>")
    # c': coefficient of treatment in outcome model (typically "y_<treatment>")
    a_idx <- grep(paste0("^m_", object@treatment, "$"), param_names)
    b_idx <- grep(paste0("^y_", object@mediator, "$"), param_names)
    cp_idx <- grep(paste0("^y_", object@treatment, "$"), param_names)

    if (length(a_idx) == 0 || length(b_idx) == 0 || length(cp_idx) == 0) {
      # Fall back: try to extract from position
      warning("Could not identify parameter indices by name. Using position-based extraction.",
              call. = FALSE)
      se <- sqrt(diag(vcov_mat)[1:3])
    } else {
      se <- sqrt(diag(vcov_mat)[c(a_idx[1], b_idx[1], cp_idx[1])])
    }
    names(se) <- names(coefs)
  } else if (identical(parm, "effects")) {
    coefs <- coef(object, type = "effects")      # nie, nde, te
    warning("Normal approximation for NIE may be inaccurate. ",
            "Consider bootstrap_mediation() for robust inference.", call. = FALSE)
    # Delta method over the full vcov, including Cov(a, b) and Cov(ab, c')
    se <- .effect_se(object, c("nie", "nde", "te"))
  } else {
    stop("parm must be 'paths' or 'effects'", call. = FALSE)
  }

  # Compute CI
  alpha <- 1 - level
  z <- stats::qnorm(1 - alpha / 2)

  ci_lower <- coefs - z * se
  ci_upper <- coefs + z * se

  # Create matrix
  ci_mat <- cbind(ci_lower, ci_upper)
  colnames(ci_mat) <- c(
    paste0(format(100 * alpha / 2, digits = 3), " %"),
    paste0(format(100 * (1 - alpha / 2), digits = 3), " %")
  )

  ci_mat
}


#' Confidence Intervals for SerialMediationData
#'
#' @description
#' Normal-approximation confidence intervals for the chain's path coefficients
#' or for the serial effects. Effect standard errors use the delta method over
#' the full `@vcov` (see [bootstrap_mediation()] for a bootstrap alternative).
#' For an lm/glm chain the equations are estimated separately, so `@vcov` has
#' zero covariances between equations.
#'
#' @param object A SerialMediationData object.
#' @param parm `"paths"` (a, the d paths as named by [paths()], b, c') or
#'   `"effects"` (nie, nde, te).
#' @param level Confidence level (default 0.95).
#' @param method `"normal"` (default) or `"boot"` (directs the user to
#'   [bootstrap_mediation()]).
#' @param ... Additional arguments (ignored).
#' @return A numeric matrix with lower/upper columns and one row per parameter.
#' @noRd
S7::method(confint, SerialMediationData) <- function(object,
                                                     parm = "paths",
                                                     level = 0.95,
                                                     method = c("normal", "boot"),
                                                     ...) {
  method <- match.arg(method)
  if (identical(method, "boot")) {
    stop("Bootstrap CIs are computed via bootstrap_mediation(); ",
         "call it directly with the desired statistic.", call. = FALSE)
  }
  checkmate::assert_choice(parm, c("paths", "effects"), .var.name = "parm")
  checkmate::assert_number(level, lower = 0, upper = 1, .var.name = "level")

  if (identical(parm, "paths")) {
    coefs <- paths(object)            # a, d (or d21, d32, ...), b, c_prime
    # paths() names the d paths by mediator pair; @vcov aliases them d1..dk
    alias <- c("a", paste0("d", seq_along(object@d_path)), "b", "c_prime")
    se <- sqrt(diag(object@vcov)[alias])
  } else {
    warning("Normal approximation for NIE may be inaccurate. ",
            "Consider bootstrap_mediation() for robust inference.", call. = FALSE)
    coefs <- c(nie = unname(nie(object)), nde = unname(nde(object)),
               te = unname(te(object)))
    se <- .effect_se(object, c("nie", "nde", "te"))
  }

  alpha <- 1 - level
  z <- stats::qnorm(1 - alpha / 2)
  ci_mat <- cbind(coefs - z * se, coefs + z * se)
  rownames(ci_mat) <- names(coefs)
  colnames(ci_mat) <- c(
    paste0(format(100 * alpha / 2, digits = 3), " %"),
    paste0(format(100 * (1 - alpha / 2), digits = 3), " %")
  )
  ci_mat
}


#' Number of Observations from MediationData
#'
#' @description
#' Extract the number of observations used in model fitting.
#'
#' @param object A MediationData object
#' @param ... Additional arguments (ignored)
#'
#' @return Integer: number of observations
#'
#' @examples
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#'
#' nobs(med_data)
#'
#' @noRd
S7::method(nobs, MediationData) <- function(object, ...) {
  object@n_obs
}


#' Number of Observations from SerialMediationData
#'
#' @param object A SerialMediationData object
#' @param ... Additional arguments (ignored)
#'
#' @return Integer: number of observations
#' @noRd
S7::method(nobs, SerialMediationData) <- function(object, ...) {
  object@n_obs
}


# --- Base-generic methods for ParallelMediationData ---

#' Extract Coefficients from ParallelMediationData
#'
#' @param object A ParallelMediationData object
#' @param type One of `"paths"` (per-mediator a/b + c'), `"effects"`
#'   (indirect/direct/total), or `"all"` (raw estimates).
#' @param ... Additional arguments (ignored)
#' @return A named numeric vector
#' @noRd
S7::method(coef, ParallelMediationData) <- function(object, type = c("paths", "effects", "all"), ...) {
  type <- match.arg(type)
  switch(type,
    paths = paths(object),
    effects = {
      indirect <- sum(object@a_paths * object@b_paths)
      direct <- object@c_prime
      c(indirect = indirect, direct = direct, total = indirect + direct)
    },
    all = object@estimates
  )
}

#' Extract Variance-Covariance Matrix from ParallelMediationData
#'
#' @param object A ParallelMediationData object
#' @param ... Additional arguments (ignored)
#' @return A numeric matrix
#' @noRd
S7::method(vcov, ParallelMediationData) <- function(object, ...) {
  object@vcov
}

#' Number of Observations from ParallelMediationData
#'
#' @param object A ParallelMediationData object
#' @param ... Additional arguments (ignored)
#' @return Integer: number of observations
#' @noRd
S7::method(nobs, ParallelMediationData) <- function(object, ...) {
  object@n_obs
}


#' Confidence Intervals for ParallelMediationData
#'
#' @description
#' Normal-approximation confidence intervals for parallel-mediation path
#' coefficients (`parm = "paths"`) or effects (`parm = "effects"`). The indirect
#' effect is `sum(a_j * b_j)`; its variance uses the **delta method over the full
#' `{a1, b1, ..., ak, bk}` covariance sub-block**, so correlations among the
#' jointly-estimated `b_j` (and between them and `c'`) are accounted for -- a
#' naive per-mediator sum would understate it.
#'
#' @param object A ParallelMediationData object.
#' @param parm `"paths"` (per-mediator a/b plus c') or `"effects"`
#'   (indirect/direct/total).
#' @param level Confidence level (default 0.95).
#' @param method `"normal"` (delta-method normal approximation) or `"boot"`
#'   (directs the user to [bootstrap_mediation()]).
#' @param ... Additional arguments (ignored).
#' @return A numeric matrix with lower/upper columns and one row per parameter.
#' @noRd
S7::method(confint, ParallelMediationData) <- function(object,
                                                       parm = "paths",
                                                       level = 0.95,
                                                       method = c("normal", "boot"),
                                                       ...) {
  method <- match.arg(method)
  if (identical(method, "boot")) {
    stop("Bootstrap CIs are computed via bootstrap_mediation(); ",
         "call it directly with the desired statistic.", call. = FALSE)
  }
  checkmate::assert_number(level, lower = 0, upper = 1)

  vc <- object@vcov

  alpha <- 1 - level
  z <- stats::qnorm(1 - alpha / 2)

  if (identical(parm, "paths")) {
    coefs <- paths(object)                       # named a1, b1, ..., c_prime
    se <- sqrt(diag(vc)[names(coefs)])
  } else if (identical(parm, "effects")) {
    warning("Normal (delta-method) approximation for the indirect effect may be ",
            "inaccurate; consider bootstrap_mediation() for robust inference.",
            call. = FALSE)

    coefs <- coef(object, type = "effects")      # indirect, direct, total
    se <- .effect_se(object, c("nie", "nde", "te"))
    names(se) <- names(coefs)
  } else {
    stop("`parm` must be 'paths' or 'effects'.", call. = FALSE)
  }

  ci_mat <- cbind(coefs - z * se, coefs + z * se)
  colnames(ci_mat) <- c(
    paste0(format(100 * alpha / 2, digits = 3), " %"),
    paste0(format(100 * (1 - alpha / 2), digits = 3), " %")
  )
  ci_mat
}


# --- Base-generic methods for InteractionMediationData ---

#' Extract Coefficients from InteractionMediationData
#'
#' @param object An InteractionMediationData object
#' @param type One of `"paths"` (a/b/c'/theta3), `"components"` (the four-way
#'   CDE/INTref/INTmed/PIE), `"effects"` (nde/nie/total), or `"all"` (raw
#'   estimates).
#' @param ... Additional arguments (ignored)
#' @return A named numeric vector
#' @noRd
S7::method(coef, InteractionMediationData) <- function(object,
                                                       type = c("paths", "components", "effects", "all"),
                                                       ...) {
  type <- match.arg(type)
  switch(type,
    paths = paths(object),
    components = c(cde = object@cde, int_ref = object@int_ref,
                   int_med = object@int_med, pie = object@pie),
    effects = {
      direct <- object@cde + object@int_ref
      indirect <- object@int_med + object@pie
      c(nde = direct, nie = indirect, total = direct + indirect)
    },
    all = object@estimates
  )
}

#' Extract Variance-Covariance Matrix from InteractionMediationData
#'
#' @param object An InteractionMediationData object
#' @param ... Additional arguments (ignored)
#' @return A numeric matrix
#' @noRd
S7::method(vcov, InteractionMediationData) <- function(object, ...) {
  object@vcov
}

#' Number of Observations from InteractionMediationData
#'
#' @param object An InteractionMediationData object
#' @param ... Additional arguments (ignored)
#' @return Integer: number of observations
#' @noRd
S7::method(nobs, InteractionMediationData) <- function(object, ...) {
  object@n_obs
}


#' Confidence Intervals for InteractionMediationData
#'
#' @description
#' Normal-approximation (delta-method) confidence intervals for the four-way
#' decomposition. `parm = "paths"` covers the raw coefficients (`a`, `b`,
#' `c_prime`, `theta3`); `parm = "components"` the four-way components (CDE,
#' INTref, INTmed, PIE); `parm = "effects"` the derived NDE/NIE/TE. Each interval
#' uses the delta method over the relevant sub-block of `@vcov`, so cross-equation
#' covariances are handled correctly (for lm/glm the mediator and outcome
#' equations are independent, so e.g. `cov(theta3, beta1) = 0`).
#'
#' @param object An InteractionMediationData object.
#' @param parm One of `"paths"`, `"components"`, `"effects"`.
#' @param level Confidence level (default 0.95).
#' @param method `"normal"` (delta method) or `"boot"` (directs to
#'   [bootstrap_mediation()]).
#' @param ... Additional arguments (ignored).
#' @return A two-column matrix of lower/upper bounds.
#' @noRd
S7::method(confint, InteractionMediationData) <- function(object,
                                                          parm = c("paths", "components", "effects"),
                                                          level = 0.95,
                                                          method = c("normal", "boot"),
                                                          ...) {
  parm <- match.arg(parm)
  method <- match.arg(method)
  if (method == "boot") {
    stop("method = 'boot' is not implemented here; use bootstrap_mediation().",
         call. = FALSE)
  }
  checkmate::assert_number(level, lower = 0, upper = 1)

  vc <- object@vcov
  alpha <- 1 - level
  z <- stats::qnorm(1 - alpha / 2)

  if (parm == "paths") {
    coefs <- paths(object)            # a, b, c_prime, theta3
    se <- sqrt(diag(vc)[names(coefs)])
  } else {
    # Delta method via the shared helper: engine-stored component rows (the
    # regmedint engine) or Gaussian-outcome gradients (the glm engine)
    if (parm == "components") {
      coefs <- c(cde = object@cde, int_ref = object@int_ref,
                 int_med = object@int_med, pie = object@pie)
      se <- .effect_se(object, c("cde", "int_ref", "int_med", "pie"))
    } else {
      coefs <- c(nde = object@nde, nie = object@nie, total = object@total_effect)
      se <- .effect_se(object, c("nde", "nie", "te"))
    }
    message("Normal (delta-method) approximation for four-way components; ",
            "consider bootstrap_mediation() for robust inference.")
  }

  ci_mat <- cbind(coefs - z * se, coefs + z * se)
  rownames(ci_mat) <- names(coefs)
  colnames(ci_mat) <- c(
    paste0(format(100 * alpha / 2, digits = 3), " %"),
    paste0(format(100 * (1 - alpha / 2), digits = 3), " %")
  )
  ci_mat
}


# --- Base-generic methods for JointMediationData ---

#' Extract Coefficients from JointMediationData
#'
#' @param object A JointMediationData object
#' @param type One of `"paths"` (raw path coefficients), `"effects"`
#'   (cde, nde, nie, total), or `"all"` (raw estimates).
#' @param ... Additional arguments (ignored)
#' @return A named numeric vector
#' @noRd
S7::method(coef, JointMediationData) <- function(object,
                                                 type = c("paths", "effects", "all"),
                                                 ...) {
  type <- match.arg(type)
  switch(type,
    paths = paths(object),
    effects = c(cde = object@cde, nde = object@nde, nie = object@nie,
                total = object@total_effect),
    all = object@estimates
  )
}

#' Extract Variance-Covariance Matrix from JointMediationData
#'
#' @param object A JointMediationData object
#' @param ... Additional arguments (ignored)
#' @return A numeric matrix
#' @noRd
S7::method(vcov, JointMediationData) <- function(object, ...) {
  object@vcov
}

#' Number of Observations from JointMediationData
#'
#' @param object A JointMediationData object
#' @param ... Additional arguments (ignored)
#' @return Integer: number of observations
#' @noRd
S7::method(nobs, JointMediationData) <- function(object, ...) {
  object@n_obs
}

#' Confidence Intervals for JointMediationData
#'
#' @description
#' Normal-approximation intervals. `parm = "paths"` covers the raw path
#' coefficients from `paths()`, with SEs from the diagonal of `@vcov`;
#' `parm = "effects"` covers CDE, NDE, NIE and TE, with delta-method SEs over
#' the stacked `@vcov` (conditional on the observed covariates). The effects
#' warn that the normal approximation may be inaccurate, as for the other
#' classes.
#'
#' @param object A JointMediationData object.
#' @param parm `"paths"` or `"effects"`.
#' @param level Confidence level (default 0.95).
#' @param method `"normal"`, or `"boot"` (directs to [bootstrap_mediation()]).
#' @param ... Additional arguments (ignored).
#' @return A two-column matrix of lower/upper bounds.
#' @noRd
S7::method(confint, JointMediationData) <- function(object,
                                                    parm = c("paths", "effects"),
                                                    level = 0.95,
                                                    method = c("normal", "boot"),
                                                    ...) {
  parm <- match.arg(parm)
  method <- match.arg(method)
  if (method == "boot") {
    stop("Bootstrap CIs are computed via bootstrap_mediation(); see ",
         "?joint_effects for a parametric recipe.", call. = FALSE)
  }
  checkmate::assert_number(level, lower = 0, upper = 1)
  z <- stats::qnorm(1 - (1 - level) / 2)
  if (parm == "paths") {
    coefs <- paths(object)
    se <- sqrt(diag(object@vcov)[names(coefs)])
  } else {
    warning("Normal (delta-method) approximation for the joint effects may be ",
            "inaccurate; consider bootstrap_mediation() for robust inference.",
            call. = FALSE)
    coefs <- c(cde = object@cde, nde = object@nde, nie = object@nie,
               te = object@total_effect)
    se <- .effect_se(object, names(coefs))
  }
  ci_mat <- cbind(coefs - z * se, coefs + z * se)
  rownames(ci_mat) <- names(coefs)
  alpha <- 1 - level
  colnames(ci_mat) <- c(
    paste0(format(100 * alpha / 2, digits = 3), " %"),
    paste0(format(100 * (1 - alpha / 2), digits = 3), " %")
  )
  ci_mat
}


# --- Base-generic methods for BootstrapResult ---

#' Extract the Point Estimate from a BootstrapResult
#'
#' @param object A BootstrapResult object
#' @param ... Additional arguments (ignored)
#' @return A named numeric scalar, `c(estimate = <value>)` (the same term name
#'   `tidy()` uses)
#' @noRd
S7::method(coef, BootstrapResult) <- function(object, ...) {
  # unname(): a statistic_fn that returns a named value (e.g. theta["a"] *
  # theta["b"]) leaves that name on @estimate, and c() would paste it on
  c(estimate = unname(object@estimate))
}


#' Confidence Interval from a BootstrapResult
#'
#' @description
#' With `level` left `NULL` (or equal to the stored `@ci_level`), returns the
#' stored `@ci_lower`/`@ci_upper` unchanged. A different `level` recomputes the
#' percentile interval from `@boot_estimates`. Plugin results carry no
#' bootstrap distribution, so their interval is `NA` with a warning.
#'
#' @param object A BootstrapResult object.
#' @param parm Ignored beyond validation; a BootstrapResult holds one statistic,
#'   `"estimate"`.
#' @param level Confidence level, or `NULL` (default) for the stored level.
#' @param ... Additional arguments (ignored).
#' @return A 1 x 2 numeric matrix with row `"estimate"` and percentage columns.
#' @noRd
S7::method(confint, BootstrapResult) <- function(object,
                                                 parm = "estimate",
                                                 level = NULL,
                                                 ...) {
  checkmate::assert_choice(parm, "estimate", .var.name = "parm")
  checkmate::assert_number(level, lower = 0, upper = 1, null.ok = TRUE,
                           .var.name = "level")

  stored_level <- object@ci_level
  if (is.null(level)) {
    level <- if (is.na(stored_level)) 0.95 else stored_level
  }
  alpha <- 1 - level

  if (identical(object@method, "plugin") || length(object@boot_estimates) == 0) {
    warning("A plugin BootstrapResult has no bootstrap distribution; ",
            "the confidence interval is NA.", call. = FALSE)
    ci <- c(NA_real_, NA_real_)
  } else if (!is.na(stored_level) && isTRUE(all.equal(level, stored_level))) {
    ci <- c(object@ci_lower, object@ci_upper)
  } else {
    ci <- stats::quantile(object@boot_estimates,
                          probs = c(alpha / 2, 1 - alpha / 2), names = FALSE)
  }

  ci_mat <- matrix(ci, nrow = 1, dimnames = list("estimate", NULL))
  colnames(ci_mat) <- c(
    paste0(format(100 * alpha / 2, digits = 3), " %"),
    paste0(format(100 * (1 - alpha / 2), digits = 3), " %")
  )
  ci_mat
}
