# Effect Extractor Generics and Methods
#
# This file defines S7 generics and methods for extracting mediation effects:
# - nie(): Natural Indirect Effect (a * b)
# - nde(): Natural Direct Effect (c')
# - te(): Total Effect (nie + nde)
# - pm(): Proportion Mediated (nie / te)
# - paths(): All path coefficients

#' Extract Natural Indirect Effect (NIE)
#'
#' @description
#' Extract the natural indirect effect from a mediation analysis result.
#' The NIE represents the effect of treatment on outcome that operates
#' through the mediator.
#'
#' @param x A MediationData, SerialMediationData, or BootstrapResult object
#' @param ... Additional arguments passed to methods
#'
#' @return A numeric value (or named vector for SerialMediationData) with
#'   optional attributes for confidence intervals if available
#'
#' @details
#' For simple mediation (MediationData):
#' \deqn{NIE = a \times b}
#'
#' For serial mediation (SerialMediationData):
#' \deqn{NIE = a \times d_{21} \times d_{32} \times \ldots \times b}
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
#' nie(med_data)
#'
#' @seealso [nde()], [te()], [pm()], [paths()]
#' @export
nie <- S7::new_generic("nie", "x")


#' Extract Natural Direct Effect (NDE)
#'
#' @description
#' Extract the natural direct effect from a mediation analysis result.
#' The NDE represents the effect of treatment on outcome that does NOT
#' operate through the mediator.
#'
#' @param x A MediationData, SerialMediationData, or BootstrapResult object
#' @param ... Additional arguments passed to methods
#'
#' @return A numeric value with optional attributes for confidence intervals
#'
#' @details
#' For both simple and serial mediation:
#' \deqn{NDE = c'}
#'
#' where c' is the direct effect coefficient.
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
#' nde(med_data)
#'
#' @seealso [nie()], [te()], [pm()], [paths()]
#' @export
nde <- S7::new_generic("nde", "x")


#' Extract Total Effect (TE)
#'
#' @description
#' Extract the total effect from a mediation analysis result.
#' The TE is the sum of the indirect and direct effects.
#'
#' @param x A MediationData, SerialMediationData, or BootstrapResult object
#' @param ... Additional arguments passed to methods
#'
#' @return A numeric value with optional attributes for confidence intervals
#'
#' @details
#' \deqn{TE = NIE + NDE}
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
#' te(med_data)
#'
#' # Verify: TE = NIE + NDE
#' nie(med_data) + nde(med_data)
#'
#' @seealso [nie()], [nde()], [pm()], [paths()]
#' @export
te <- S7::new_generic("te", "x")


#' Extract Proportion Mediated (PM)
#'
#' @description
#' Extract the proportion of the total effect that is mediated (operates
#' through the mediator).
#'
#' @param x A MediationData, SerialMediationData, or BootstrapResult object
#' @param ... Additional arguments passed to methods
#'
#' @return A numeric value between 0 and 1 (or negative/greater than 1 in
#'   cases of suppression effects)
#'
#' @details
#' \deqn{PM = \frac{NIE}{TE} = \frac{NIE}{NIE + NDE}}
#'
#' The proportion mediated can be:
#' \itemize{
#'   \item Between 0 and 1: Normal mediation
#'   \item Greater than 1: Suppression (direct and indirect effects have
#'     opposite signs)
#'   \item Negative: Inconsistent mediation
#' }
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
#' pm(med_data)
#'
#' @seealso [nie()], [nde()], [te()], [paths()]
#' @export
pm <- S7::new_generic("pm", "x")


#' Extract All Path Coefficients
#'
#' @description
#' Extract all path coefficients from a mediation analysis result.
#'
#' @param x A MediationData or SerialMediationData object
#' @param ... Additional arguments passed to methods
#'
#' @return A named numeric vector of path coefficients
#'
#' @details
#' For simple mediation (MediationData):
#' \itemize{
#'   \item `a`: Treatment -> Mediator (X -> M)
#'   \item `b`: Mediator -> Outcome (M -> Y | X)
#'   \item `c_prime`: Direct effect (X -> Y | M)
#' }
#'
#' For serial mediation (SerialMediationData):
#' \itemize{
#'   \item `a`: Treatment -> First mediator
#'   \item `d21`, `d32`, ...: Mediator-to-mediator paths
#'   \item `b`: Last mediator -> Outcome
#'   \item `c_prime`: Direct effect
#' }
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
#' paths(med_data)
#'
#' @seealso [nie()], [nde()], [te()], [pm()]
#' @export
paths <- S7::new_generic("paths", "x")


# --- Methods for MediationData ---

#' @describeIn nie Method for MediationData
#' @noRd
S7::method(nie, MediationData) <- function(x, ...) {
  effect <- x@a_path * x@b_path
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nie"
  effect
}

#' @describeIn nde Method for MediationData
#' @noRd
S7::method(nde, MediationData) <- function(x, ...) {
  effect <- x@c_prime
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nde"
  effect
}

#' @describeIn te Method for MediationData
#' @noRd
S7::method(te, MediationData) <- function(x, ...) {
  effect <- x@a_path * x@b_path + x@c_prime
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "te"
  effect
}

#' @describeIn pm Method for MediationData
#' @noRd
S7::method(pm, MediationData) <- function(x, ...) {
  indirect <- x@a_path * x@b_path
  total <- indirect + x@c_prime

  if (abs(total) < .Machine$double.eps) {
    warning("Total effect is approximately zero; proportion mediated is undefined.",
            call. = FALSE)
    return(NA_real_)
  }

  prop <- indirect / total
  class(prop) <- c("mediation_effect", "numeric")
  attr(prop, "type") <- "pm"
  prop
}

#' @describeIn paths Method for MediationData
#' @noRd
S7::method(paths, MediationData) <- function(x, ...) {
  c(
    a = x@a_path,
    b = x@b_path,
    c_prime = x@c_prime
  )
}


# --- Methods for SerialMediationData ---

#' @describeIn nie Method for SerialMediationData
#' @noRd
S7::method(nie, SerialMediationData) <- function(x, ...) {
  effect <- x@a_path * prod(x@d_path) * x@b_path
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nie"
  attr(effect, "n_mediators") <- length(x@mediators)
  effect
}

#' @describeIn nde Method for SerialMediationData
#' @noRd
S7::method(nde, SerialMediationData) <- function(x, ...) {
  effect <- x@c_prime
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nde"
  effect
}

#' @describeIn te Method for SerialMediationData
#' @noRd
S7::method(te, SerialMediationData) <- function(x, ...) {
  indirect <- x@a_path * prod(x@d_path) * x@b_path
  effect <- indirect + x@c_prime
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "te"
  effect
}

#' @describeIn pm Method for SerialMediationData
#' @noRd
S7::method(pm, SerialMediationData) <- function(x, ...) {
  indirect <- x@a_path * prod(x@d_path) * x@b_path
  total <- indirect + x@c_prime

  if (abs(total) < .Machine$double.eps) {
    warning("Total effect is approximately zero; proportion mediated is undefined.",
            call. = FALSE)
    return(NA_real_)
  }

  prop <- indirect / total
  class(prop) <- c("mediation_effect", "numeric")
  attr(prop, "type") <- "pm"
  prop
}

#' @describeIn paths Method for SerialMediationData
#' @noRd
S7::method(paths, SerialMediationData) <- function(x, ...) {
  n_mediators <- length(x@mediators)
  result <- c(a = x@a_path)

  # Add d paths with appropriate names
  if (n_mediators == 2) {
    result <- c(result, d = x@d_path)
  } else {
    d_names <- paste0("d", seq(2, n_mediators), seq(1, n_mediators - 1))
    d_vals <- stats::setNames(x@d_path, d_names)
    result <- c(result, d_vals)
  }

  c(result, b = x@b_path, c_prime = x@c_prime)
}


# --- Methods for BootstrapResult ---

#' @describeIn nie Method for BootstrapResult (extracts estimate)
#' @noRd
S7::method(nie, BootstrapResult) <- function(x, ...) {
  # Only works if the statistic was NIE
  if (!is.null(attr(x@estimate, "type")) && attr(x@estimate, "type") != "nie") {
    warning("BootstrapResult may not contain NIE estimate.", call. = FALSE)
  }
  x@estimate
}


#' Print Method for mediation_effect
#'
#' @param x A mediation_effect object
#' @param ... Additional arguments (ignored)
#' @export
print.mediation_effect <- function(x, ...) {
  type <- attr(x, "type")
  type_label <- switch(type,
    nie = "Natural Indirect Effect (NIE)",
    nde = "Natural Direct Effect (NDE)",
    te = "Total Effect (TE)",
    pm = "Proportion Mediated (PM)",
    "Effect"
  )

  cat(type_label, ": ", format(unclass(x), digits = 4), "\n", sep = "")
  invisible(x)
}
