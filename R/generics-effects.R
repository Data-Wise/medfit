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
#' through the mediator.
#'
#' @param x A MediationData, SerialMediationData, or BootstrapResult object
#' @param ... Additional arguments passed to methods. For SerialMediationData,
#'   `type = c("chain", "total")` selects the chain-specific or the total
#'   indirect effect (see Details).
#'
#' @return A numeric value (or named vector for SerialMediationData) with
#'   optional attributes for confidence intervals if available
#'
#' @details
#' For simple mediation (MediationData):
#' \deqn{NIE = a \times b}
#'
#' For serial mediation (SerialMediationData), `type = "chain"` (the default)
#' gives the chain-specific indirect effect through every mediator in order,
#' \deqn{NIE_{chain} = a \times d_{21} \times d_{32} \times \ldots \times b}{NIE_chain = a * d21 * d32 * ... * b}
#' and `type = "total"` gives the total indirect effect, the sum over every
#' X-to-Y path through at least one mediator (including paths that skip a
#' mediator, such as X -> M2 -> Y), which equals `te(x) - nde(x)`.
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
#' For serial mediation (SerialMediationData) the total effect is the sum over
#' every directed X-to-Y path in the fitted models: the direct path, the full
#' chain, and every path that skips a mediator (for two mediators,
#' \eqn{c' + a_1 b_1 + a_2 b_2 + a_1 d_{21} b_2}{c' + a1*b1 + a2*b2 + a1*d21*b2}).
#' With the same covariates in every equation and linear models this equals
#' the treatment coefficient of the outcome regressed on the treatment and
#' covariates alone. A path missing from its model counts as zero; when a path
#' is in a model but its coefficient was not recorded (a hand-built object),
#' `te()` returns `NA` with a warning.
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

# Structural edges of a serial model: every regression path from X or an
# earlier mediator into a later mediator or Y. The chain edges keep their
# historical aliases (a, d1..d{k-1}, b); the edges that skip a link get
# a{j} (X -> Mj), d{i}_{j} (Mi -> Mj, j > i + 1) and b{i} (Mi -> Y, i < k).
.serial_edges <- function(k) {
  # Node indices: 0 = X, 1..k = mediators, k + 1 = Y.
  mm <- which(upper.tri(diag(k)), arr.ind = TRUE)  # (from = row, to = col)
  mm <- mm[order(mm[, 1L], mm[, 2L]), , drop = FALSE]
  adjacent <- mm[, 2L] == mm[, 1L] + 1L
  data.frame(
    from = c(rep(0L, k), mm[, 1L], seq_len(k), 0L),
    to = c(seq_len(k), mm[, 2L], rep(k + 1L, k), k + 1L),
    alias = c("a", if (k > 1L) paste0("a", seq(2L, k)),
              ifelse(adjacent, paste0("d", mm[, 1L]),
                     paste0("d", mm[, 1L], "_", mm[, 2L])),
              if (k > 1L) paste0("b", seq_len(k - 1L)), "b", "c_prime"),
    chain = c(TRUE, rep(FALSE, k - 1L), adjacent, rep(FALSE, k - 1L), TRUE, FALSE),
    stringsAsFactors = FALSE
  )
}


# Recursive path system of a SerialMediationData object.
#
# Returns list(edges, inv) where `edges` holds the edges present in the model
# (with their values) and `inv` is (I - B)^{-1} over the nodes (X, M1..Mk, Y),
# so the total effect of X on Y is inv[Y, X]. An edge is present when its
# source is a predictor of its target (from @mediator_predictors /
# @outcome_predictors); a skip edge absent from the model is a structural zero.
# Returns a character string (the reason) when a present skip edge has no
# stored coefficient, or the predictor bookkeeping is missing: guessing zero
# there would silently understate or overstate the total effect.
.serial_path_system <- function(x) {
  k <- length(x@mediators)
  nodes <- c(x@treatment, x@mediators)
  edges <- .serial_edges(k)
  chain_val <- c(a = x@a_path, stats::setNames(x@d_path, paste0("d", seq_len(k - 1L))),
                 b = x@b_path, c_prime = x@c_prime)

  preds <- x@mediator_predictors
  if (length(preds) < k || length(x@outcome_predictors) == 0L) {
    return("the mediator/outcome predictor lists are not recorded")
  }

  edges$value <- NA_real_
  keep <- logical(nrow(edges))
  for (r in seq_len(nrow(edges))) {
    al <- edges$alias[r]
    if (al %in% names(chain_val)) {
      edges$value[r] <- chain_val[[al]]
      keep[r] <- TRUE
      next
    }
    target_preds <- if (edges$to[r] > k) x@outcome_predictors else preds[[edges$to[r]]]
    if (!nodes[edges$from[r] + 1L] %in% target_preds) next
    val <- if (al %in% names(x@estimates)) unname(x@estimates[[al]]) else NA_real_
    if (is.na(val)) {
      return(sprintf("no coefficient '%s' (%s -> %s) is stored in @estimates",
                     al, nodes[edges$from[r] + 1L],
                     c(nodes, x@outcome)[edges$to[r] + 1L]))
    }
    edges$value[r] <- val
    keep[r] <- TRUE
  }
  edges <- edges[keep, , drop = FALSE]

  n <- k + 2L
  B <- matrix(0, n, n)
  B[cbind(edges$to + 1L, edges$from + 1L)] <- edges$value
  list(edges = edges, inv = solve(diag(n) - B))
}


# Total effect of X on Y (sum over all directed paths), or NA with a warning
# when the skip-path coefficients are unavailable.
.serial_total_effect <- function(x) {
  sys <- .serial_path_system(x)
  if (is.character(sys)) {
    warning("Total effect is unavailable for this SerialMediationData: ", sys,
            ". Use extract_mediation() so every path is recorded.", call. = FALSE)
    return(NA_real_)
  }
  k <- length(x@mediators)
  sys$inv[k + 2L, 1L]
}


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
  total <- .serial_total_effect(x)
  if (is.na(total)) return(NA_real_)

  if (abs(total) < .Machine$double.eps) {
    warning("Total effect is approximately zero; proportion mediated is undefined.",
            call. = FALSE)
    return(NA_real_)
  }

  prop <- (total - x@c_prime) / total
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
