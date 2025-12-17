# Base R Generic Methods for MediationData
#
# This file implements methods for base R generics:
# - coef(): Extract path coefficients
# - vcov(): Extract variance-covariance matrix
# - confint(): Compute confidence intervals
# - nobs(): Get number of observations

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
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(X = rnorm(n))
#' mydata$M <- 0.5 * mydata$X + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)
#'
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
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
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(X = rnorm(n))
#' mydata$M <- 0.5 * mydata$X + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)
#'
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
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
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(X = rnorm(n))
#' mydata$M <- 0.5 * mydata$X + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)
#'
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
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
    # For effects (nie, nde, te), we need delta method or bootstrap
    # For now, provide warning and use simple approximation for NDE only
    coefs <- coef(object, type = "effects")

    # NDE = c' has straightforward SE
    # NIE = a*b requires delta method
    # For simplicity, only provide normal CI for NDE, warn about NIE
    warning("Normal approximation for NIE may be inaccurate. ",
            "Consider bootstrap_mediation() for robust inference.", call. = FALSE)

    # Use delta method for NIE: Var(a*b) ≈ b²*Var(a) + a²*Var(b) + 2ab*Cov(a,b)
    vcov_mat <- object@vcov
    param_names <- names(object@estimates)

    a_idx <- grep(paste0("^m_", object@treatment, "$"), param_names)
    b_idx <- grep(paste0("^y_", object@mediator, "$"), param_names)
    cp_idx <- grep(paste0("^y_", object@treatment, "$"), param_names)

    if (length(a_idx) > 0 && length(b_idx) > 0 && length(cp_idx) > 0) {
      var_a <- vcov_mat[a_idx[1], a_idx[1]]
      var_b <- vcov_mat[b_idx[1], b_idx[1]]
      var_cp <- vcov_mat[cp_idx[1], cp_idx[1]]
      # Cov(a, b) is typically 0 for separate models
      cov_ab <- 0

      a <- object@a_path
      b <- object@b_path

      # Delta method variance for a*b
      var_nie <- b^2 * var_a + a^2 * var_b + 2 * a * b * cov_ab
      se_nie <- sqrt(var_nie)
      se_nde <- sqrt(var_cp)
      # TE = NIE + NDE, assuming independence: Var(TE) = Var(NIE) + Var(NDE)
      se_te <- sqrt(var_nie + var_cp)

      se <- c(nie = se_nie, nde = se_nde, te = se_te)
    } else {
      stop("Could not compute SEs for effects. Use bootstrap_mediation() instead.",
           call. = FALSE)
    }
  } else {
    stop("parm must be 'paths', 'effects', or specific parameter names", call. = FALSE)
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
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(X = rnorm(n))
#' mydata$M <- 0.5 * mydata$X + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)
#'
#' med_data <- fit_mediation(
#'   formula_y = Y ~ X + M,
#'   formula_m = M ~ X,
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M"
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
