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
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
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
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
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
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
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
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
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
#' med_data <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#'
#' paths(med_data)
#'
#' @seealso [nie()], [nde()], [te()], [pm()]
#' @export
paths <- S7::new_generic("paths", "x")


#' Four-Way Decomposition of a Mediation Effect
#'
#' @description
#' Return VanderWeele's (2014) four-way decomposition of the total effect for an
#' [InteractionMediationData] object: controlled direct effect (CDE), reference
#' interaction (INTref), mediated interaction (INTmed), and pure indirect effect
#' (PIE), together with the derived natural direct/indirect and total effects.
#'
#' @param x An [InteractionMediationData] object.
#' @param ... Additional arguments (ignored).
#'
#' @return A named numeric vector:
#'   `c(cde, int_ref, int_med, pie, nde, nie, total)`.
#'
#' @seealso [nie()], [nde()], [te()]
#' @export
decompose <- S7::new_generic("decompose", "x")


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


# --- Methods for ParallelMediationData ---

#' @describeIn nie Method for ParallelMediationData (sum of a_j * b_j)
#' @noRd
S7::method(nie, ParallelMediationData) <- function(x, ...) {
  effect <- sum(x@a_paths * x@b_paths)
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nie"
  attr(effect, "n_mediators") <- length(x@mediators)
  effect
}

#' @describeIn nde Method for ParallelMediationData
#' @noRd
S7::method(nde, ParallelMediationData) <- function(x, ...) {
  effect <- x@c_prime
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nde"
  effect
}

#' @describeIn te Method for ParallelMediationData
#' @noRd
S7::method(te, ParallelMediationData) <- function(x, ...) {
  indirect <- sum(x@a_paths * x@b_paths)
  effect <- indirect + x@c_prime
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "te"
  effect
}

#' @describeIn pm Method for ParallelMediationData
#' @noRd
S7::method(pm, ParallelMediationData) <- function(x, ...) {
  indirect <- sum(x@a_paths * x@b_paths)
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

#' @describeIn paths Method for ParallelMediationData
#' @noRd
S7::method(paths, ParallelMediationData) <- function(x, ...) {
  k <- length(x@mediators)
  # Interleave a_j, b_j with names a1, b1, a2, b2, ...
  result <- numeric(0)
  for (j in seq_len(k)) {
    result <- c(result,
                stats::setNames(x@a_paths[j], paste0("a", j)),
                stats::setNames(x@b_paths[j], paste0("b", j)))
  }
  c(result, c_prime = x@c_prime)
}


# --- Methods for InteractionMediationData ---

#' @describeIn nie Method for InteractionMediationData (INTmed + PIE)
#' @noRd
S7::method(nie, InteractionMediationData) <- function(x, ...) {
  effect <- x@int_med + x@pie
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nie"
  effect
}

#' @describeIn nde Method for InteractionMediationData (CDE + INTref)
#' @noRd
S7::method(nde, InteractionMediationData) <- function(x, ...) {
  effect <- x@cde + x@int_ref
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nde"
  effect
}

#' @describeIn te Method for InteractionMediationData (CDE + INTref + INTmed + PIE)
#' @noRd
S7::method(te, InteractionMediationData) <- function(x, ...) {
  effect <- x@cde + x@int_ref + x@int_med + x@pie
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "te"
  effect
}

#' @describeIn pm Method for InteractionMediationData (NIE / TE)
#' @noRd
S7::method(pm, InteractionMediationData) <- function(x, ...) {
  indirect <- x@int_med + x@pie
  total <- x@cde + x@int_ref + indirect

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

#' @describeIn paths Method for InteractionMediationData (a, b, c_prime, theta3)
#' @noRd
S7::method(paths, InteractionMediationData) <- function(x, ...) {
  c(a = x@a_path, b = x@b_path, c_prime = x@c_prime, theta3 = x@interaction)
}

#' @describeIn decompose Method for InteractionMediationData
#' @noRd
S7::method(decompose, InteractionMediationData) <- function(x, ...) {
  indirect <- x@int_med + x@pie
  direct <- x@cde + x@int_ref
  c(cde = x@cde, int_ref = x@int_ref, int_med = x@int_med, pie = x@pie,
    nde = direct, nie = indirect, total = direct + indirect)
}


# --- Methods for JointMediationData ---

# Wrap a stored joint effect as a mediation_effect.
.joint_effect <- function(value, type) {
  class(value) <- c("mediation_effect", "numeric")
  attr(value, "type") <- type
  value
}

#' Joint Effects at a Given Parameter Vector
#'
#' @description
#' Recomputes the joint CDE, NDE, NIE and total effect of a
#' [JointMediationData] object from a named parameter vector, holding the
#' object's structure, reference levels (`m_star`) and sample covariate means
#' fixed. With the default `estimates = object@estimates` it returns the stored
#' effects. Its main use is as the statistic of a parametric bootstrap: the
#' draws [bootstrap_mediation()] passes to `statistic_fn` are named like
#' `@estimates`, and the NDE needs the prefixed intercept and covariate rows
#' (`m1_`, ..., `y_`) and the covariate means, not only the path aliases.
#'
#' @param object A [JointMediationData] object.
#' @param estimates Named numeric vector containing every prefixed source row
#'   of `object@estimates` (`m1_...`, `y_...`); alias rows are ignored. A
#'   missing source row is an error, not a zero.
#' @return Named numeric vector: `cde`, `nde`, `nie`, `te`.
#' @examples
#' d <- mediation_demo
#' fit <- extract_mediation(
#'   lm(mediator1 ~ treatment + covariate1 + covariate2, d),
#'   model_y = lm(outcome_int ~ treatment * mediator1 + mediator2 +
#'                  covariate1 + covariate2, d),
#'   treatment = "treatment", mediator = c("mediator1", "mediator2"),
#'   mediator_models = list(lm(mediator2 ~ treatment + mediator1 +
#'                               covariate1 + covariate2, d))
#' )
#' joint_effects(fit)
#'
#' # Parametric bootstrap of the joint NIE
#' boot <- bootstrap_mediation(
#'   function(theta) joint_effects(fit, theta)[["nie"]],
#'   method = "parametric", mediation_data = fit, n_boot = 500, seed = 1
#' )
#' boot@ci_lower
#' boot@ci_upper
#' @export
joint_effects <- function(object, estimates = object@estimates) {
  if (!S7::S7_inherits(object, JointMediationData)) {
    stop("`object` must be a JointMediationData object.", call. = FALSE)
  }
  checkmate::assert_numeric(estimates, any.missing = FALSE, names = "unique",
                            .var.name = "estimates")
  .assert_joint_source_rows(object)
  src <- grep("^(m[0-9]+|y)_", names(object@estimates), value = TRUE)
  absent <- setdiff(src, names(estimates))
  if (length(absent) > 0L) {
    stop("`estimates` must contain every source row of `object@estimates`; ",
         "missing: ", paste(absent, collapse = ", "), ".", call. = FALSE)
  }
  pp <- .joint_parts(object, estimates)
  ints <- object@interactions
  nie <- sum(pp$w * pp$big_b1)
  nde <- pp$theta1 + sum(pp$t3[ints] * pp$mu0[match(ints, object@mediators)])
  cde <- pp$theta1 + sum(pp$t3[ints] * object@m_star[ints])
  c(cde = cde, nde = nde, nie = nie, te = nde + nie)
}

#' @describeIn nie Method for JointMediationData (joint NIE through all
#'   mediators and every path among them)
#' @noRd
S7::method(nie, JointMediationData) <- function(x, ...) {
  .joint_effect(x@nie, "nie")
}

#' @describeIn nde Method for JointMediationData
#' @noRd
S7::method(nde, JointMediationData) <- function(x, ...) {
  .joint_effect(x@nde, "nde")
}

#' @describeIn te Method for JointMediationData (NDE + NIE)
#' @noRd
S7::method(te, JointMediationData) <- function(x, ...) {
  .joint_effect(x@total_effect, "te")
}

#' @describeIn pm Method for JointMediationData (NIE / TE)
#' @noRd
S7::method(pm, JointMediationData) <- function(x, ...) {
  if (abs(x@total_effect) < .Machine$double.eps) {
    warning("Total effect is approximately zero; proportion mediated is undefined.",
            call. = FALSE)
    return(NA_real_)
  }
  .joint_effect(x@nie / x@total_effect, "pm")
}

#' @describeIn paths Method for JointMediationData (raw path coefficients:
#'   a1..aK, dij, b1..bK, theta3_<mediator>, c_prime)
#' @noRd
S7::method(paths, JointMediationData) <- function(x, ...) {
  est <- x@estimates
  groups <- c("^a[0-9]+$", "^d[0-9]+$", "^b[0-9]+$", "^theta3_.+$", "^c_prime$")
  est[unlist(lapply(groups, grep, x = names(est)))]
}

#' @describeIn decompose Method for JointMediationData (CDE, NDE, NIE, total)
#' @noRd
S7::method(decompose, JointMediationData) <- function(x, ...) {
  c(cde = x@cde, nde = x@nde, nie = x@nie, total = x@total_effect)
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
#' @return Invisibly returns `x` (the `mediation_effect` object). Called for
#'   its side effect of printing a formatted effect summary to the console.
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
