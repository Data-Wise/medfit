# Effect Extractor Generics and Methods
#
# This file defines S7 generics and methods for extracting mediation effects:
# - nie(): Natural Indirect Effect (a * b)
# - nde(): Natural Direct Effect (c')
# - te(): Total Effect (nie + nde; every X -> Y path for serial)
# - pm(): Proportion Mediated (nie / te)
# - paths(): All path coefficients

#' Extract Natural Indirect Effect (NIE)
#'
#' @description
#' Extract the natural indirect effect from a mediation analysis result.
#' The NIE represents the effect of treatment on outcome that operates
#' through the mediator(s).
#'
#' @param x A [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], [JointMediationData], or [BootstrapResult]
#'   object. For a `BootstrapResult`, `nie()` returns the bootstrapped point
#'   estimate (with a warning if the statistic was not an NIE).
#' @param ... Additional arguments passed to methods. For a
#'   `SerialMediationData`, `type = c("chain", "total")` selects the
#'   chain-specific (default) or the total indirect effect (see Details). For a
#'   `TwoLevelMediationData`, `level = c("within", "between", "contrast", "both")`
#'   selects the level (within is the default; the contrast, within minus
#'   between, is descriptive and exists for `nie()` only).
#'
#' @return A numeric scalar of class `mediation_effect` carrying a `type`
#'   attribute. For intervals use [confint()] or [bootstrap_mediation()].
#'
#' @details
#' The effects are for a unit contrast of the treatment. By class:
#' \itemize{
#'   \item `MediationData`: \eqn{NIE = a b}{NIE = a * b}.
#'   \item `SerialMediationData`: with `type = "chain"` (the default), the
#'     effect through the full chain only,
#'     \eqn{NIE = a \, d_1 \cdots d_{k-1} \, b}{NIE = a * d1 * ... * d(k-1) * b};
#'     with `type = "total"`, the total indirect effect, the sum over every
#'     treatment-to-outcome path through at least one mediator (including paths
#'     that skip a mediator, such as X -> M2 -> Y), which equals
#'     `te(x) - nde(x)`.
#'   \item `ParallelMediationData`: \eqn{NIE = \sum_j a_j b_j}{NIE = sum(a_j * b_j)}.
#'   \item `InteractionMediationData`: \eqn{NIE = INTmed + PIE =
#'     (\theta_2 + \theta_3) \beta_1}{NIE = INTmed + PIE = (t2 + t3) * b1}.
#'   \item `JointMediationData`: the joint NIE through all the mediators,
#'     \eqn{\sum_i (\theta_{2i} + \theta_{3i}) \beta^*_{1i}}{sum((t2i + t3i) * b1i*)}.
#' }
#' The "Methods and Formulas" article on the package website gives the full
#' formulas.
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
#' @seealso [nde()], [te()], [pm()], [paths()], [decompose()]
#' @export
nie <- S7::new_generic("nie", "x")


#' Extract Natural Direct Effect (NDE)
#'
#' @description
#' Extract the natural direct effect from a mediation analysis result.
#' The NDE represents the effect of treatment on outcome that does NOT
#' operate through the mediator(s).
#'
#' @param x A [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], or [JointMediationData] object.
#' @param ... Additional arguments passed to methods. For a `TwoLevelMediationData`,
#'   `level = c("within", "between", "both")` selects the level (within by default).
#'
#' @return A numeric scalar of class `mediation_effect` carrying a `type`
#'   attribute.
#'
#' @details
#' Without a treatment-by-mediator product (`MediationData`,
#' `SerialMediationData`, `ParallelMediationData`) the NDE is the direct-path
#' coefficient, \eqn{NDE = c'}{NDE = c'}. With a product it also depends on the
#' mediator's mean under no treatment:
#' \itemize{
#'   \item `InteractionMediationData`: \eqn{NDE = CDE + INTref =
#'     \theta_1 + \theta_3 E[M \mid X = 0, \bar c]}{NDE = CDE + INTref = t1 + t3 * E[M | X = 0, cbar]}.
#'   \item `JointMediationData`: \eqn{NDE = \theta_1 + \sum_i \theta_{3i}
#'     \mu^*_{0i}}{NDE = t1 + sum(t3i * mu0i*)}, with \eqn{\mu^*_{0i}}{mu0i*}
#'     the mean of mediator \eqn{i} under no treatment at the covariate means.
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
#' nde(med_data)
#'
#' @seealso [nie()], [te()], [pm()], [paths()], [decompose()]
#' @export
nde <- S7::new_generic("nde", "x")


#' Extract Total Effect (TE)
#'
#' @description
#' Extract the total effect from a mediation analysis result: the sum of the
#' indirect and direct effects.
#'
#' @param x A [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], or [JointMediationData] object.
#' @param ... Additional arguments passed to methods. For a `TwoLevelMediationData`,
#'   `level = c("within", "between", "both")` selects the level (within by default).
#'
#' @return A numeric scalar of class `mediation_effect` carrying a `type`
#'   attribute.
#'
#' @details
#' \deqn{TE = NIE + NDE}{TE = NIE + NDE}
#'
#' For a [SerialMediationData] object the total effect is the sum over
#' every directed X-to-Y path in the fitted models: the direct path, the full
#' chain, and every path that skips a mediator (for two mediators,
#' \eqn{c' + a_1 b_1 + a_2 b_2 + a_1 d_{21} b_2}{c' + a1*b1 + a2*b2 + a1*d21*b2}).
#' With the same covariates in every equation and linear models this equals
#' the treatment coefficient of the outcome regressed on the treatment and
#' covariates alone. A path missing from its model counts as zero; when a path
#' is in a model but its coefficient was not recorded (a hand-built object),
#' `te()` returns `NA` with a warning. For glm fits with a non-identity link
#' the sum of path products is on the linear-predictor scale, as for
#' [MediationData].
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
#' @seealso [nie()], [nde()], [pm()], [paths()], [decompose()]
#' @export
te <- S7::new_generic("te", "x")


#' Extract Proportion Mediated (PM)
#'
#' @description
#' Extract the proportion of the total effect that is mediated (operates
#' through the mediator(s)).
#'
#' @param x A [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], or [JointMediationData] object.
#' @param ... Additional arguments passed to methods. For a `TwoLevelMediationData`,
#'   `level = c("within", "between", "both")` selects the level (within by default).
#'
#' @return A numeric scalar of class `mediation_effect`, usually between 0 and
#'   1 (negative or greater than 1 in cases of suppression effects), or
#'   `NA` with a warning when the total effect is numerically zero.
#'
#' @details
#' \deqn{PM = \frac{NIE}{TE} = \frac{NIE}{NIE + NDE}}{PM = NIE / TE = NIE / (NIE + NDE)}
#'
#' For serial mediation (SerialMediationData) the numerator is the total
#' indirect effect, `nie(x, type = "total")`, and the denominator the full
#' total effect from [te()].
#'
#' The proportion mediated can be:
#' \itemize{
#'   \item Between 0 and 1: Normal mediation
#'   \item Greater than 1: Suppression (direct and indirect effects have
#'     opposite signs)
#'   \item Negative: Inconsistent mediation
#' }
#'
#' The ratio has no delta-method standard error in medfit; bootstrap it with
#' [bootstrap_mediation()] for supported objects. `pm()` and bootstrap inference
#' refuse data extracted from bounded FIML fits; see [fit_sem()].
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
#' @param x A [MediationData], [SerialMediationData], [ParallelMediationData],
#'   [InteractionMediationData], or [JointMediationData] object.
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
#'   \item `d` (two mediators) or `d21`, `d32`, ...: Mediator-to-mediator paths
#'   \item `b`: Last mediator -> Outcome
#'   \item `c_prime`: Direct effect
#' }
#'
#' For parallel mediation (ParallelMediationData): `a1`, `b1`, `a2`, `b2`,
#' ..., `c_prime`.
#'
#' For InteractionMediationData: `a`, `b`, `c_prime`, and `theta3` (the
#' treatment-by-mediator coefficient).
#'
#' For JointMediationData: the raw coefficients `a1..aK`, `dij`, `b1..bK`,
#' `theta3_<mediator>`, and `c_prime`. The `a` paths here are the raw
#' coefficients, not the propagated `a*` values used by the effects.
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


#' Decomposition of a Mediation Effect
#'
#' @description
#' Return the components of the total effect for an object whose outcome model
#' has treatment-by-mediator products.
#'
#' For an [InteractionMediationData] object this is VanderWeele's (2014)
#' four-way decomposition: controlled direct effect (CDE), reference
#' interaction (INTref), mediated interaction (INTmed), and pure indirect
#' effect (PIE), together with the derived natural direct and indirect effects
#' and the total effect. For a [JointMediationData] object it is the CDE and
#' the joint natural direct and indirect effects (VanderWeele and Vansteelandt
#' 2014).
#'
#' @param x An [InteractionMediationData] or [JointMediationData] object.
#' @param ... Additional arguments (ignored).
#'
#' @return A named numeric vector: `c(cde, int_ref, int_med, pie, nde, nie,
#'   total)` for `InteractionMediationData`, `c(cde, nde, nie, total)` for
#'   `JointMediationData`.
#'
#' @details
#' For a 0/1 treatment, outcome model
#' \eqn{Y = \theta_0 + \theta_1 X + \theta_2 M + \theta_3 X M + \dots}{Y = t0 + t1*X + t2*M + t3*X*M + ...},
#' mediator model \eqn{M = \beta_0 + \beta_1 X + \dots}{M = b0 + b1*X + ...},
#' and reference mediator level \eqn{m^*}{m*}:
#' \deqn{CDE = \theta_1 + \theta_3 m^*}{CDE = t1 + t3 * m*}
#' \deqn{INTref = \theta_3 (E[M \mid X = 0, \bar c] - m^*)}{INTref = t3 * (E[M | X = 0, cbar] - m*)}
#' \deqn{INTmed = \theta_3 \beta_1}{INTmed = t3 * b1}
#' \deqn{PIE = \theta_2 \beta_1}{PIE = t2 * b1}
#' with \eqn{NDE = CDE + INTref}{NDE = CDE + INTref},
#' \eqn{NIE = INTmed + PIE}{NIE = INTmed + PIE}, and
#' \eqn{TE = NDE + NIE}{TE = NDE + NIE}. \eqn{E[M \mid X = 0, \bar c]}{E[M | X = 0, cbar]}
#' is the mediator model's prediction at no treatment and the covariate means.
#'
#' @references
#' VanderWeele, T. J. (2014). A unification of mediation and interaction: A
#' 4-way decomposition. *Epidemiology*, 25(5), 749--761.
#'
#' VanderWeele, T. J., & Vansteelandt, S. (2014). Mediation analysis with
#' multiple mediators. *Epidemiologic Methods*, 2(1), 95--115.
#' \doi{10.1515/em-2012-0010}
#'
#' @examples
#' \donttest{
#' fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2,
#'             data = mediation_demo)
#' fit_y <- lm(outcome ~ treatment * mediator1 + covariate1 + covariate2,
#'             data = mediation_demo)
#' med_int <- extract_mediation(fit_m, model_y = fit_y,
#'                              treatment = "treatment", mediator = "mediator1")
#' decompose(med_int)
#' }
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
  .sem_fiml_refuse(x, "pm()")
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
S7::method(nie, SerialMediationData) <- function(x, type = c("chain", "total"), ...) {
  type <- match.arg(type)
  effect <- if (identical(type, "chain")) {
    x@a_path * prod(x@d_path) * x@b_path
  } else {
    .serial_total_effect(x) - x@c_prime
  }
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "nie"
  attr(effect, "nie_type") <- type
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
  effect <- .serial_total_effect(x)
  class(effect) <- c("mediation_effect", "numeric")
  attr(effect, "type") <- "te"
  effect
}

#' @describeIn pm Method for SerialMediationData
#' @noRd
S7::method(pm, SerialMediationData) <- function(x, ...) {
  .sem_fiml_refuse(x, "pm()")
  .serial_pm_from_total(.serial_total_effect(x), x@c_prime)
}

#' @describeIn paths Method for SerialMediationData
#' @noRd
S7::method(paths, SerialMediationData) <- function(x, ...) {
  if (S7::S7_inherits(x, FIMLSerialMediationData)) return(.sem_fiml_ser_paths(x))
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
  .sem_fiml_refuse(x, "pm()")
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


# --- Methods for ClusterMediationData ---

# Wrap a cluster effect as a mediation_effect.
.cluster_effect <- function(value, type) {
  class(value) <- c("mediation_effect", "numeric")
  attr(value, "type") <- type
  value
}

#' @describeIn nie Method for ClusterMediationData (a * b_between)
#' @noRd
S7::method(nie, ClusterMediationData) <- function(x, ...) {
  .cluster_effect(x@a_path * x@b_between, "nie")
}

#' @describeIn nde Method for ClusterMediationData
#' @noRd
S7::method(nde, ClusterMediationData) <- function(x, ...) {
  .cluster_effect(x@c_prime, "nde")
}

#' @describeIn te Method for ClusterMediationData (a * b_between + c')
#' @noRd
S7::method(te, ClusterMediationData) <- function(x, ...) {
  .cluster_effect(x@a_path * x@b_between + x@c_prime, "te")
}

#' @describeIn pm Method for ClusterMediationData (NIE / TE)
#' @noRd
S7::method(pm, ClusterMediationData) <- function(x, ...) {
  indirect <- x@a_path * x@b_between
  total <- indirect + x@c_prime
  if (abs(total) < .Machine$double.eps) {
    warning("Total effect is approximately zero; proportion mediated is undefined.",
            call. = FALSE)
    return(NA_real_)
  }
  .cluster_effect(indirect / total, "pm")
}

#' @describeIn paths Method for ClusterMediationData
#' @noRd
S7::method(paths, ClusterMediationData) <- function(x, ...) {
  c(a = x@a_path, b_within = x@b_within, b_between = x@b_between,
    c_prime = x@c_prime)
}

# The D-own gap |a (b_B - b_W)| / H, with H the harmonic mean cluster size: how
# far the large-cluster own effect a * b_W sits from the exact own effect.
.cluster_own_gap <- function(x) {
  h <- length(x@cluster_sizes) / sum(1 / x@cluster_sizes)
  abs(x@a_path * (x@b_between - x@b_within)) / h
}

#' @describeIn decompose Method for ClusterMediationData: the own-mediator,
#'   spillover and total indirect effects, labeled as the cluster-average
#'   large-cluster approximation. Warns (D11) when the D-own gap exceeds half
#'   the own effect's standard error.
#' @noRd
S7::method(decompose, ClusterMediationData) <- function(x, ...) {
  own_se <- .effect_se_or_na(x, "own")[[1]]
  gap <- .cluster_own_gap(x)
  if (!is.na(own_se) && gap > 0.5 * own_se) {
    fmt <- paste0(
      "The own-effect approximation a * b_within is off by about %.3g ",
      "(a * (b_between - b_within) / H, H = harmonic mean cluster size), ",
      "more than half its standard error (%.3g); with clusters this ",
      "small, read the own/spillover split with care."
    )
    msg <- sprintf(fmt, gap, own_se)
    warning(msg, call. = FALSE)
  }
  out <- c(own = x@a_path * x@b_within,
           spillover = x@a_path * (x@b_between - x@b_within),
           nie = x@a_path * x@b_between)
  attr(out, "label") <- "cluster-average, large-cluster approximation"
  out
}


# --- Methods for TwoLevelMediationData ---

# The effect keys in canonical order: per level nie, nde, te, pm, then the NIE contrast.
.twolevel_effect_keys <- c(
  "nie_within", "nde_within", "te_within", "pm_within",
  "nie_between", "nde_between", "te_between", "pm_between", "nie_contrast"
)

# PM = NIE / TE is defined only for a finite, nonzero TE that is not negligible next to the effects it sums:
# |TE| >= sqrt(eps) * max(|NIE|, |NDE|). The one place the rule lives; callers pass the level's NIE and NDE.
.twolevel_te_defined <- function(te, nie, nde) {
  is.finite(te) & te != 0 & abs(te) >= sqrt(.Machine$double.eps) * pmax(abs(nie), abs(nde))
}

# All effects as a named vector, with no condition signaled: NA where the between level is unidentified, where
# |TE| is below machine epsilon (PM) and for a contrast that is zero by constraint (both a and b equated).
.twolevel_effect_vec <- function(x) {
  per_level <- function(level) {
    a <- S7::prop(x, paste0("a_", level))
    b <- S7::prop(x, paste0("b_", level))
    cp <- S7::prop(x, paste0("c_prime_", level))
    te <- a * b + cp
    pm <- if (.twolevel_te_defined(te, a * b, cp)) a * b / te else NA_real_
    stats::setNames(c(a * b, cp, te, pm), paste0(c("nie", "nde", "te", "pm"), "_", level))
  }
  out <- c(per_level("within"), per_level("between"), nie_contrast = NA_real_)
  if (.twolevel_contrast_available(x)) out[["nie_contrast"]] <- out[["nie_within"]] - out[["nie_between"]]
  out[.twolevel_effect_keys]
}

# Signal why the requested effects are NA: the between level is unidentified (a within-only object), or the
# contrast is zero by constraint. Classed warnings, suppressible per class (PLAN Q2).
.twolevel_signal_na <- function(x, terms) {
  if (!isTRUE(x@between_identified) && any(grepl("between|contrast", terms))) {
    .twolevel_warn(
      paste0("The between level of this two-level fit is not identified (a within-only result), so the ",
             "between effects and the contrast are NA."),
      "medfit_between_unidentified"
    )
  } else if ("nie_contrast" %in% terms && !.twolevel_contrast_available(x)) {
    .twolevel_warn(
      paste0("The contrast NIE_within - NIE_between is NA: both a and b are equated across levels, so the ",
             "contrast is zero by constraint. The within and between effects are still reported."),
      "medfit_warning_twolevel_constrained"
    )
  }
  invisible(NULL)
}

# One effect type at the requested level(s) as a `mediation_effect`; `both` gives a length-2 named vector.
.twolevel_effect <- function(x, type, level) {
  if (identical(level, "contrast") && !identical(type, "nie")) {
    .twolevel_abort(
      sprintf("`level = \"contrast\"` is defined only for nie(); %s() has no first-class contrast. Use tidy().",
              type),
      "medfit_error_twolevel_level"
    )
  }
  levels <- switch(level, both = c("within", "between"), level)
  terms <- if (identical(level, "contrast")) "nie_contrast" else paste0(type, "_", levels)
  .twolevel_signal_na(x, terms)
  eff <- .twolevel_effect_vec(x)
  value <- eff[terms]
  if (identical(type, "pm")) {
    te <- eff[paste0("te_", levels)]
    nie_l <- eff[paste0("nie_", levels)]
    nde_l <- eff[paste0("nde_", levels)]
    if (any(is.finite(te) & !.twolevel_te_defined(te, nie_l, nde_l))) {
      warning("Total effect is approximately zero; proportion mediated is undefined.", call. = FALSE)
    }
  }
  names(value) <- if (identical(level, "both")) levels else NULL
  class(value) <- c("mediation_effect", "numeric")
  attr(value, "type") <- type
  attr(value, "level") <- level
  value
}

#' @describeIn nie Method for TwoLevelMediationData; `level` is `"within"` (default), `"between"`,
#'   `"contrast"` (within minus between, descriptive) or `"both"`
#' @noRd
S7::method(nie, TwoLevelMediationData) <- function(x, level = c("within", "between", "contrast", "both"),
                                                   ...) {
  .twolevel_effect(x, "nie", match.arg(level))
}

#' @describeIn nde Method for TwoLevelMediationData (c' at the level)
#' @noRd
S7::method(nde, TwoLevelMediationData) <- function(x, level = c("within", "between", "both", "contrast"),
                                                   ...) {
  .twolevel_effect(x, "nde", match.arg(level))
}

#' @describeIn te Method for TwoLevelMediationData (a * b + c' at the level)
#' @noRd
S7::method(te, TwoLevelMediationData) <- function(x, level = c("within", "between", "both", "contrast"),
                                                  ...) {
  .twolevel_effect(x, "te", match.arg(level))
}

#' @describeIn pm Method for TwoLevelMediationData (NIE / TE at the level)
#' @noRd
S7::method(pm, TwoLevelMediationData) <- function(x, level = c("within", "between", "both", "contrast"),
                                                  ...) {
  .twolevel_effect(x, "pm", match.arg(level))
}

#' @describeIn paths Method for TwoLevelMediationData (six paths; between entries `NA` when within-only)
#' @noRd
S7::method(paths, TwoLevelMediationData) <- function(x, ...) {
  c(a_within = x@a_within, b_within = x@b_within, c_prime_within = x@c_prime_within,
    a_between = x@a_between, b_between = x@b_between, c_prime_between = x@c_prime_between)
}

#' @describeIn decompose Method for TwoLevelMediationData: the within and between NIE and their contrast,
#'   without a standard error (descriptive; the contrast is not a test)
#' @noRd
S7::method(decompose, TwoLevelMediationData) <- function(x, ...) {
  .twolevel_signal_na(x, c("nie_between", "nie_contrast"))
  eff <- .twolevel_effect_vec(x)
  out <- c(within = eff[["nie_within"]], between = eff[["nie_between"]], contrast = eff[["nie_contrast"]])
  attr(out, "label") <- "descriptive; the contrast is not a test"
  out
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
#' @noRd
print_mediation_effect <- function(x, ...) {
  type <- attr(x, "type")
  type_label <- switch(type,
    nie = "Natural Indirect Effect (NIE)",
    nde = "Natural Direct Effect (NDE)",
    te = "Total Effect (TE)",
    pm = "Proportion Mediated (PM)",
    "Effect"
  )

  level <- attr(x, "level")
  if (!is.null(level) && !identical(level, "within")) {
    type_label <- paste0(
      type_label, ", ",
      switch(level, contrast = "within - between contrast", both = "both levels", paste(level, "level"))
    )
  }
  shown <- format(unclass(x), digits = 4)
  if (!is.null(names(x))) shown <- paste(paste0(names(x), " = ", shown), collapse = ", ")
  cat(type_label, ": ", shown, "\n", sep = "")
  invisible(x)
}
