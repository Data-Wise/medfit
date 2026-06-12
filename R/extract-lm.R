# S7 Method for Extracting Mediation Structure from lm/glm Models
#
# This file implements extract_mediation() methods for:
# - lm (linear models)
# - glm (generalized linear models)
#
# The extraction follows the simple mediation pattern:
#   X -> M -> Y  # nolint: commented_code_linter.
# where:
#   - Mediator model: M ~ X + covariates
#   - Outcome model: Y ~ X + M + covariates

# Define S7 class wrappers for lm and glm
# These are needed for S7 method dispatch on S3 classes
lm_class <- S7::new_S3_class("lm")
glm_class <- S7::new_S3_class("glm")


#' Extract Mediation Structure from lm Model
#'
#' @param object Fitted lm model. For simple mediation this is the mediator
#'   model (`M ~ X + covariates`); for serial mediation it is the first
#'   mediator model (`M1 ~ X + covariates`).
#' @param model_y Fitted lm or glm model for the outcome (`Y ~ X + M + covariates`,
#'   or `Y ~ X + Mk + covariates` for serial chains).
#' @param treatment Character: name of the treatment variable
#' @param mediator Character: name of the mediator variable for simple mediation
#'   (`X -> M -> Y`), OR an ordered character vector of length >= 2 for serial
#'   mediation (`X -> M1 -> M2 -> ... -> Y`). When a vector is supplied the
#'   method returns a [SerialMediationData] object instead of [MediationData].
#' @param mediator_models List of fitted lm/glm models for mediators 2..k (the
#'   `M2 ~ M1 + ...`, ..., `Mk ~ M(k-1) + ...` regressions), in chain order.
#'   Required and only used on the serial branch; must have length
#'   `length(mediator) - 1`.
#' @param outcome Character: name of the outcome variable (optional, auto-detected)
#' @param data Data frame: original data (optional, extracted from model if available)
#' @param ... Additional arguments (ignored)
#'
#' @return A [MediationData] object, or a [SerialMediationData] object when
#'   `mediator` is a character vector of length >= 2 (serial mediation).
#'
#' @details
#' This method extracts mediation structure from separately-fitted linear
#' models. For simple mediation it uses two models:
#' 1. Mediator model: `M ~ X + covariates`
#' 2. Outcome model: `Y ~ X + M + covariates`
#'
#' For serial mediation (`mediator` length >= 2) it uses `k + 1` models: the
#' first mediator model in `object`, mediators 2..k in `mediator_models`, and
#' the outcome model in `model_y`. See [SerialMediationData].
#'
#' The method extracts:
#' - Path coefficients (`a`, `b`, `c'`; plus `d1..d{k-1}` for serial chains)
#' - Combined parameter vector and variance-covariance matrix
#' - Residual standard deviations (for Gaussian models)
#' - Variable names and metadata
#'
#' ## Covariance contract and lm-vs-lavaan divergence
#'
#' The combined `vcov` is **block-diagonal across separately-fitted equations**:
#' coefficients from different regressions are independent by construction, so
#' `cov(a, b)`, `cov(a, d_i)`, `cov(d_i, b)` are all zero. The covariance
#' *within* the outcome equation is preserved, so `cov(b, c')` (and, in serial
#' chains, the joint covariance among outcome-equation terms) is non-zero.
#'
#' For the *same data*, a single lavaan `sem()` fit estimates all equations
#' jointly and yields the **full** (non-block-diagonal) covariance among chain
#' paths. Consequently the indirect-effect standard error / CI computed from an
#' lm chain will generally differ from (and is often tighter than) the lavaan
#' fit. This is correct given the different estimators, but downstream consumers
#' must be aware that the engine choice changes the CI for identical data.
#'
#' @examples
#' \dontrun{
#' # Simulate data
#' set.seed(123)
#' n <- 200
#' X <- rnorm(n)
#' M <- 0.5 * X + rnorm(n)
#' Y <- 0.3 * M + 0.2 * X + rnorm(n)
#' data <- data.frame(X = X, M = M, Y = Y)
#'
#' # Fit models
#' fit_m <- lm(M ~ X, data = data)
#' fit_y <- lm(Y ~ X + M, data = data)
#'
#' # Extract mediation structure
#' med_data <- extract_mediation(
#'   fit_m,
#'   model_y = fit_y,
#'   treatment = "X",
#'   mediator = "M"
#' )
#'
#' # Serial chain X -> M1 -> M2 -> Y
#' fit_m1 <- lm(M1 ~ X, data = data)
#' fit_m2 <- lm(M2 ~ M1, data = data)
#' fit_y2 <- lm(Y ~ M2 + X, data = data)
#' serial <- extract_mediation(
#'   fit_m1,
#'   model_y = fit_y2,
#'   treatment = "X",
#'   mediator = c("M1", "M2"),
#'   mediator_models = list(fit_m2)
#' )
#' }
#'
#' @noRd
S7::method(extract_mediation, lm_class) <- function(
    object,
    model_y,
    treatment,
    mediator,
    mediator_models = NULL,
    outcome = NULL,
    data = NULL,
    structure = c("auto", "serial", "parallel"),
    decomposition = c("auto", "four_way", "two_way"),
    m_star = 0,
    vcov_fun = stats::vcov,
    ...) {
  # Call internal extraction function
  .extract_mediation_lm_impl(
    model_m = object,
    model_y = model_y,
    treatment = treatment,
    mediator = mediator,
    mediator_models = mediator_models,
    outcome = outcome,
    data = data,
    structure = structure,
    decomposition = decomposition,
    m_star = m_star,
    vcov_fun = vcov_fun
  )
}


#' Extract Mediation Structure from glm Model
#'
#' @inheritParams extract_mediation
#' @noRd
S7::method(extract_mediation, glm_class) <- function(
    object,
    model_y,
    treatment,
    mediator,
    mediator_models = NULL,
    outcome = NULL,
    data = NULL,
    structure = c("auto", "serial", "parallel"),
    decomposition = c("auto", "four_way", "two_way"),
    m_star = 0,
    vcov_fun = stats::vcov,
    ...) {
  # Call internal extraction function
  .extract_mediation_lm_impl(
    model_m = object,
    model_y = model_y,
    treatment = treatment,
    mediator = mediator,
    mediator_models = mediator_models,
    outcome = outcome,
    data = data,
    structure = structure,
    decomposition = decomposition,
    m_star = m_star,
    vcov_fun = vcov_fun
  )
}


#' Internal Implementation for lm/glm Extraction
#'
#' @param model_m Fitted model for mediator
#' @param model_y Fitted model for outcome
#' @param treatment Treatment variable name
#' @param mediator Mediator variable name (scalar) or ordered mediator vector
#'   (length >= 2, serial mediation)
#' @param mediator_models List of fitted mediator models 2..k (serial only)
#' @param outcome Outcome variable name (auto-detected if NULL)
#' @param data Original data (extracted from model if NULL)
#'
#' @return MediationData object, or SerialMediationData when `mediator` is a
#'   vector of length >= 2
#' @keywords internal
.extract_mediation_lm_impl <- function(
    model_m,
    model_y,
    treatment,
    mediator,
    mediator_models = NULL,
    outcome = NULL,
    data = NULL,
    structure = c("auto", "serial", "parallel"),
    decomposition = c("auto", "four_way", "two_way"),
    m_star = 0,
    vcov_fun = stats::vcov) {

  structure <- match.arg(structure)
  decomposition <- match.arg(decomposition)

  # --- Multi-mediator: dispatch on mediator arity AND structure ---
  # The lm/glm S7 methods dispatch on object class only, so the simple-vs-
  # serial-vs-parallel decision is made here. When structure = "auto" (default)
  # and there are >= 2 mediators, infer serial vs parallel from the mediator
  # models' predictors. Branch BEFORE the scalar-mediator assertion below.
  if (length(mediator) >= 2L) {
    if (structure == "auto") {
      if (is.null(mediator_models)) {
        stop(paste0(
          "Multi-mediator extraction (length(mediator) >= 2) requires ",
          "'mediator_models'. Provide the M2..Mk models, or set ",
          "structure = 'serial' / 'parallel' explicitly."
        ), call. = FALSE)
      }
      med_models <- c(list(model_m), mediator_models)
      structure <- .classify_multimediator_structure(med_models, mediator, treatment, model_y)
    }
    if (structure == "serial") {
      return(.extract_serial_mediation_lm(
        object          = model_m,
        mediator_models = mediator_models,
        model_y         = model_y,
        treatment       = treatment,
        mediators       = mediator,
        outcome         = outcome,
        data            = data
      ))
    }
    return(.extract_parallel_mediation_lm(
      object          = model_m,
      mediator_models = mediator_models,
      model_y         = model_y,
      treatment       = treatment,
      mediators       = mediator,
      outcome         = outcome,
      data            = data
    ))
  }

  # --- Single mediator with treatment x mediator interaction (Extension B) ---
  # Detect an X:M product term in the outcome model. When present (and not
  # explicitly disabled via decomposition = "two_way"), route to the four-way
  # decomposition worker; otherwise fall through to the standard simple path so
  # the no-interaction behavior is unchanged.
  int_term <- .find_interaction_term(model_y, treatment, mediator)
  if (decomposition == "four_way" && is.na(int_term)) {
    stop(
      sprintf("decomposition = 'four_way' requires an interaction term ('%s:%s') in 'model_y'.",
              treatment, mediator),
      call. = FALSE
    )
  }
  if (decomposition != "two_way" && !is.na(int_term)) {
    return(.extract_interaction_mediation_lm(
      model_m = model_m, model_y = model_y, treatment = treatment,
      mediator = mediator, int_term = int_term, outcome = outcome,
      data = data, m_star = m_star
    ))
  }

  # --- Input Validation (using checkmate for fail-fast defensive programming) ---

  # Validate model_y is provided and is correct type
  checkmate::assert_multi_class(
    model_y,
    classes = c("lm", "glm"),
    .var.name = "model_y"
  )

  # Validate treatment and mediator are single character strings
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")

  # Validate outcome if provided
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")

  # Validate data if provided
  checkmate::assert_data_frame(data, null.ok = TRUE, .var.name = "data")

  # Get coefficient names from models
  coef_m <- stats::coef(model_m)
  coef_y <- stats::coef(model_y)

  # Check treatment exists in mediator model
  checkmate::assert_choice(
    treatment,
    choices = names(coef_m),
    .var.name = "treatment in mediator model"
  )

  # Check treatment exists in outcome model
  checkmate::assert_choice(
    treatment,
    choices = names(coef_y),
    .var.name = "treatment in outcome model"
  )

  # Check mediator exists in outcome model
  checkmate::assert_choice(
    mediator,
    choices = names(coef_y),
    .var.name = "mediator in outcome model"
  )

  # --- Extract Path Coefficients ---

  # a path: effect of X on M
  a_path <- unname(coef_m[treatment])

  # b path: effect of M on Y (controlling for X)
  b_path <- unname(coef_y[mediator])

  # c' path: direct effect of X on Y (controlling for M)
  c_prime <- unname(coef_y[treatment])

  # --- Determine Outcome Variable Name ---

  if (is.null(outcome)) {
    # Extract from model formula
    outcome <- .get_response_var(model_y)
  }

  # --- Extract Variance-Covariance Matrices ---

  # vcov_fun defaults to stats::vcov (model-based); pass sandwich::vcovHC for
  # heteroskedasticity-consistent SEs (used by IPW, se_type = "sandwich").
  vcov_m <- vcov_fun(model_m)
  vcov_y <- vcov_fun(model_y)

  # Create combined parameter vector with named elements
  # Structure: mediator model params, then outcome model params
  # Use prefixes to avoid name collisions
  names_m <- paste0("m_", names(coef_m))
  names_y <- paste0("y_", names(coef_y))

  estimates <- c(coef_m, coef_y)
  names(estimates) <- c(names_m, names_y)

  # Add convenient aliases for key paths
  estimates["a"] <- a_path
  estimates["b"] <- b_path
  estimates["c_prime"] <- c_prime

  # Build the block-diagonal SOURCE covariance of the two regressions. The
  # mediator and outcome equations are estimated separately, so their estimates
  # are independent by construction and the cross blocks are zero.
  n_m <- length(coef_m)
  n_y <- length(coef_y)
  n_src <- n_m + n_y

  vcov_src <- matrix(
    0,
    nrow = n_src, ncol = n_src,
    dimnames = list(c(names_m, names_y), c(names_m, names_y))
  )
  vcov_src[seq_len(n_m), seq_len(n_m)] <- vcov_m
  vcov_src[(n_m + 1):n_src, (n_m + 1):n_src] <- vcov_y

  # Map each alias to its source coefficient (by prefixed name) and expand with
  # FULL row/column copies via the shared helper. Copying the whole source
  # row/column -- not just the diagonal variance -- preserves cov(b, c_prime),
  # since b (y_mediator) and c_prime (y_treatment) share the outcome equation.
  # cov(a, b) stays 0 because a lives in the mediator block (block-diagonal).
  source_idx <- c(
    a = which(rownames(vcov_src) == paste0("m_", treatment)),
    b = which(rownames(vcov_src) == paste0("y_", mediator)),
    c_prime = which(rownames(vcov_src) == paste0("y_", treatment))
  )
  vcov_combined <- .expand_vcov_with_aliases(
    vcov_src,
    source_idx = source_idx,
    aliases_to_add = c("a", "b", "c_prime")
  )

  # --- Extract Residual Standard Deviations ---

  sigma_m <- .extract_sigma(model_m)
  sigma_y <- .extract_sigma(model_y)

  # --- Extract GLM Families ---
  # stats::family() works on both lm (returns gaussian) and glm fits.
  family_m <- stats::family(model_m)
  family_y <- stats::family(model_y)

  # --- Extract Data ---

  if (is.null(data)) {
    # Try to get data from model
    data <- tryCatch(
      stats::model.frame(model_m),
      error = function(e) NULL
    )
  }

  # Get sample size
  n_obs <- if (!is.null(data)) {
    nrow(data)
  } else {
    # Fall back to number of observations used in fitting
    length(stats::residuals(model_m))
  }

  # --- Get Predictor Names ---

  mediator_predictors <- names(coef_m)[-1]  # Exclude intercept
  outcome_predictors <- names(coef_y)[-1]   # Exclude intercept

  # --- Determine Source Package ---

  source_package <- if (inherits(model_m, "glm")) {
    "stats::glm"
  } else {
    "stats::lm"
  }

  # --- Check Convergence ---

  # For lm, always converged; for glm, check convergence
  converged <- if (inherits(model_m, "glm")) {
    model_m$converged && model_y$converged
  } else {
    TRUE
  }

  # --- Create MediationData Object ---

  MediationData(
    a_path = a_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_combined,
    sigma_m = sigma_m,
    sigma_y = sigma_y,
    family_m = family_m,
    family_y = family_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = source_package
  )
}


#' Locate a treatment-by-mediator interaction term in an outcome model
#'
#' Returns the coefficient name of the `X:M` product term in `model_y`, trying
#' both orderings (`treatment:mediator` and `mediator:treatment`, since the
#' formula order determines which `lm()`/`glm()` emits). Returns `NA_character_`
#' when no interaction term is present.
#'
#' @keywords internal
.find_interaction_term <- function(model_y, treatment, mediator) {
  nms <- names(stats::coef(model_y))
  cand <- c(paste0(treatment, ":", mediator), paste0(mediator, ":", treatment))
  hit <- cand[cand %in% nms]
  if (length(hit) >= 1L) hit[1] else NA_character_
}


#' Extract Treatment-Mediator Interaction Structure from lm/glm Models
#'
#' @description
#' Internal worker for the four-way (VanderWeele 2014) branch of the lm/glm
#' [extract_mediation()] method. Invoked by [.extract_mediation_lm_impl()] when a
#' single mediator's outcome model carries an `X:M` term. Builds an
#' `InteractionMediationData` object for continuous `Y` and `M` with binary
#' treatment (0 -> 1) and reference mediator level `m_star`.
#'
#' @details
#' With mediator model \eqn{M = \beta_0 + \beta_1 X + \beta_2^\top C}{M = b0 + b1*X + b2'C}
#' and outcome model
#' \eqn{Y = \theta_0 + \theta_1 X + \theta_2 M + \theta_3 XM + \dots}{Y = t0 + t1*X + t2*M + t3*XM + ...}
#' the components are CDE = \eqn{\theta_1 + \theta_3 m^*}{t1 + t3*m*},
#' INTref = \eqn{\theta_3 (E[M\mid X=0] - m^*)}{t3*(E[M|X=0] - m*)},
#' INTmed = \eqn{\theta_3 \beta_1}{t3*b1}, PIE = \eqn{\theta_2 \beta_1}{t2*b1},
#' where \eqn{E[M\mid X=0]}{E[M|X=0]} evaluates covariates at their sample means.
#' The combined `vcov` is block-diagonal across the two separately-fitted
#' equations and named with the aliases `a`, `b`, `c_prime`, `theta3`, `b0`.
#'
#' @param int_term Character: the interaction coefficient name in `model_y`
#'   (from [.find_interaction_term()]).
#' @param m_star Numeric scalar reference mediator level.
#' @inheritParams .extract_serial_mediation_lm
#' @return An `InteractionMediationData` object.
#' @keywords internal
.extract_interaction_mediation_lm <- function( # nolint: object_length_linter.
    model_m,
    model_y,
    treatment,
    mediator,
    int_term,
    outcome = NULL,
    data = NULL,
    m_star = 0) {

  # --- Input validation ---
  checkmate::assert_multi_class(model_m, c("lm", "glm"), .var.name = "object")
  checkmate::assert_multi_class(model_y, c("lm", "glm"), .var.name = "model_y")
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_number(m_star, .var.name = "m_star")

  # MVP: continuous (Gaussian) mediator and outcome only -- the linear four-way
  # formulas do not hold for non-Gaussian links (binary/survival Y are a planned
  # extension, see the interaction spec).
  non_gaussian <- function(m) {
    inherits(m, "glm") && !identical(stats::family(m)$family, "gaussian")
  }
  if (non_gaussian(model_m) || non_gaussian(model_y)) {
    stop(paste0("Four-way decomposition currently supports continuous (Gaussian) ",
                "mediator and outcome only; non-Gaussian models are not yet supported."),
         call. = FALSE)
  }

  coef_m <- stats::coef(model_m)
  coef_y <- stats::coef(model_y)
  if (!treatment %in% names(coef_m)) {
    stop(sprintf("Treatment '%s' is not a predictor in the mediator model.", treatment),
         call. = FALSE)
  }
  if (!mediator %in% names(coef_y)) {
    stop(sprintf("Mediator '%s' is not a predictor in 'model_y'.", mediator),
         call. = FALSE)
  }
  if (!treatment %in% names(coef_y)) {
    stop(sprintf("Treatment '%s' is not a predictor in 'model_y'.", treatment),
         call. = FALSE)
  }

  # --- Coefficients (VanderWeele notation) ---
  beta0  <- if ("(Intercept)" %in% names(coef_m)) unname(coef_m[["(Intercept)"]]) else 0
  beta1  <- unname(coef_m[treatment])   # a path (X -> M)
  theta1 <- unname(coef_y[treatment])   # c' (X -> Y main effect)
  theta2 <- unname(coef_y[mediator])    # b  (M -> Y main effect)
  theta3 <- unname(coef_y[int_term])    # X x M interaction

  if (is.null(outcome)) outcome <- .get_response_var(model_y)
  if (is.null(data)) {
    data <- tryCatch(stats::model.frame(model_m), error = function(e) NULL)
  }

  # --- Reference prediction E[M | X = 0]: covariates at their sample means ---
  m_covs <- setdiff(names(coef_m), c("(Intercept)", treatment))
  m_ref <- beta0
  if (length(m_covs) > 0 && !is.null(data)) {
    for (cv in m_covs) {
      if (cv %in% names(data) && is.numeric(data[[cv]])) {
        m_ref <- m_ref + unname(coef_m[[cv]]) * mean(data[[cv]], na.rm = TRUE)
      }
    }
  }

  # --- Four-way components (continuous Y, M; binary X) ---
  cde     <- theta1 + theta3 * m_star
  int_med <- theta3 * beta1
  pie     <- theta2 * beta1
  int_ref <- theta3 * (m_ref - m_star)
  nde   <- cde + int_ref
  nie   <- int_med + pie
  total <- nde + nie

  # --- Combined estimates + block-diagonal source vcov ---
  names_m <- paste0("m_", names(coef_m))
  names_y <- paste0("y_", names(coef_y))
  estimates <- c(coef_m, coef_y)
  names(estimates) <- c(names_m, names_y)

  n_m <- length(coef_m)
  n_y <- length(coef_y)
  n_src <- n_m + n_y
  vcov_src <- matrix(0, n_src, n_src,
                     dimnames = list(c(names_m, names_y), c(names_m, names_y)))
  vcov_src[seq_len(n_m), seq_len(n_m)] <- stats::vcov(model_m)
  vcov_src[(n_m + 1):n_src, (n_m + 1):n_src] <- stats::vcov(model_y)

  # Aliases a/b/c_prime/theta3 (+ b0 for the INTref intercept term).
  alias_src <- c(
    a = paste0("m_", treatment),
    b = paste0("y_", mediator),
    c_prime = paste0("y_", treatment),
    theta3 = paste0("y_", int_term)
  )
  alias_val <- c(a = beta1, b = theta2, c_prime = theta1, theta3 = theta3)
  if ("(Intercept)" %in% names(coef_m)) {
    alias_src["b0"] <- "m_(Intercept)"
    alias_val["b0"] <- beta0
  }
  resolve <- function(nm) {
    w <- which(rownames(vcov_src) == nm)
    if (length(w)) w[1] else NA_integer_
  }
  source_idx <- vapply(alias_src, resolve, integer(1))
  for (al in names(alias_val)) estimates[al] <- alias_val[[al]]
  vcov_combined <- .expand_vcov_with_aliases(
    vcov_src, source_idx = source_idx, aliases_to_add = names(alias_src)
  )

  # --- Metadata ---
  sigma_m <- .extract_sigma(model_m)
  sigma_y <- .extract_sigma(model_y)
  n_obs <- if (!is.null(data)) nrow(data) else length(stats::residuals(model_m))
  mediator_predictors <- names(coef_m)[names(coef_m) != "(Intercept)"]
  outcome_predictors <- names(coef_y)[names(coef_y) != "(Intercept)"]
  is_glm <- inherits(model_m, "glm") || inherits(model_y, "glm")
  source_package <- if (is_glm) "stats::glm" else "stats::lm"
  converged <- (if (inherits(model_m, "glm")) isTRUE(model_m$converged) else TRUE) &&
    (if (inherits(model_y, "glm")) isTRUE(model_y$converged) else TRUE)

  InteractionMediationData(
    a_path = beta1, b_path = theta2, c_prime = theta1, interaction = theta3,
    cde = cde, int_ref = int_ref, int_med = int_med, pie = pie,
    nde = nde, nie = nie, total_effect = total, m_star = m_star,
    estimates = estimates, vcov = vcov_combined,
    sigma_m = sigma_m, sigma_y = sigma_y,
    treatment = treatment, mediator = mediator, outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data, n_obs = as.integer(n_obs),
    converged = converged, source_package = source_package
  )
}


#' Extract Serial Mediation Structure from lm/glm Models
#'
#' Internal worker for the serial branch of the lm/glm [extract_mediation()]
#' method. Invoked by [.extract_mediation_lm_impl()] when `mediator` is a
#' character vector of length >= 2. It assembles a [SerialMediationData] object
#' for the chain `X -> M1 -> M2 -> ... -> Mk -> Y` from `k + 1` separately
#' fitted regressions.
#'
#' @param object Fitted lm/glm for the first mediator (`M1 ~ X + ...`).
#' @param mediator_models List (length `k - 1`) of fitted lm/glm models for
#'   mediators 2..k (`M2 ~ M1 + ...`, ..., `Mk ~ M(k-1) + ...`), in chain order.
#' @param model_y Fitted lm/glm for the outcome (`Y ~ Mk + X + ...`).
#' @param treatment Character scalar: treatment variable name.
#' @param mediators Character vector (length >= 2): mediator names in causal
#'   order (`M1 -> M2 -> ... -> Mk`).
#' @param outcome Character scalar, or `NULL` to auto-detect from `model_y`.
#' @param data Data frame, or `NULL` to take the `object` model frame.
#'
#' @return A [SerialMediationData] object.
#'
#' @details
#' Path resolution: `a` = coefficient of `treatment` in `object`; `d_i` =
#' coefficient of `mediators[i]` in `mediator_models[[i]]` (the predecessor
#' mediator, read regardless of any additional covariates in that equation);
#' `b` = coefficient of `mediators[k]` in `model_y`; `c'` = coefficient of
#' `treatment` in `model_y` (0 with a warning if absent).
#'
#' The combined `vcov` is block-diagonal across the separately-fitted equations
#' (so `cov(a, d_i) = cov(d_i, b) = 0`) but preserves the within-`model_y`
#' covariance, so `cov(b, c')` is non-zero. See the `extract_mediation` lm
#' method docs for the lm-vs-lavaan covariance divergence this implies.
#'
#' @keywords internal
.extract_serial_mediation_lm <- function( # nolint: object_length_linter.
    object,
    mediator_models,
    model_y,
    treatment,
    mediators,
    outcome = NULL,
    data = NULL) {

  # --- Input validation ---
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_character(mediators, min.len = 2, unique = TRUE,
                              any.missing = FALSE, .var.name = "mediator")
  checkmate::assert_multi_class(object, c("lm", "glm"), .var.name = "object")
  checkmate::assert_multi_class(model_y, c("lm", "glm"), .var.name = "model_y")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
  checkmate::assert_data_frame(data, null.ok = TRUE, .var.name = "data")

  k <- length(mediators)

  # mediator_models is required on the serial branch: the M2..Mk regressions
  # have no other entry point. Fail with a directed message before the generic
  # checkmate type assertion (which would otherwise say only "not 'NULL'").
  if (is.null(mediator_models)) {
    msg <- paste0(
      "Serial mediation (length(mediator) >= 2) requires 'mediator_models': ",
      sprintf("a list of the %d mediator models (M2 ~ M1, ..., Mk ~ M(k-1)) in chain order.",
              k - 1L)
    )
    stop(msg, call. = FALSE)
  }

  # mediator_models must be a list of k - 1 fitted lm/glm models.
  checkmate::assert_list(mediator_models, len = k - 1L,
                         .var.name = "mediator_models")
  for (i in seq_along(mediator_models)) {
    checkmate::assert_multi_class(
      mediator_models[[i]], c("lm", "glm"),
      .var.name = sprintf("mediator_models[[%d]]", i)
    )
  }

  # Full ordered list of mediator models: object is the M1 model; mediator_models
  # hold the M2..Mk models. (length k)
  med_models <- c(list(object), mediator_models)

  # --- Order cross-check (Q2): informative stop() on any mismatch ---
  # (a) treatment predicts M1 in object, whose response must be M1.
  if (!treatment %in% names(stats::coef(object))) {
    stop(sprintf("Treatment '%s' is not a predictor in 'object' (the '%s' model).",
                 treatment, mediators[1]), call. = FALSE)
  }
  obj_resp <- .get_response_var(object)
  if (!identical(obj_resp, mediators[1])) {
    msg <- sprintf(
      "'object' must be the model for the first mediator ('%s'), but its response is '%s'.",
      mediators[1], obj_resp
    )
    stop(msg, call. = FALSE)
  }
  # (b) each mediator_models[[i]] regresses mediators[i+1] on mediators[i].
  for (i in seq_len(k - 1L)) {
    mod <- mediator_models[[i]]
    resp <- .get_response_var(mod)
    if (!identical(resp, mediators[i + 1L])) {
      msg <- paste0(
        sprintf("mediator_models[[%d]] must be the model for mediator %d ('%s'), ",
                i, i + 1L, mediators[i + 1L]),
        sprintf("but its response is '%s'. Check the order of 'mediator_models'.", resp)
      )
      stop(msg, call. = FALSE)
    }
    if (!mediators[i] %in% names(stats::coef(mod))) {
      msg <- sprintf(
        "Predecessor mediator '%s' is not a predictor in mediator_models[[%d]] (the '%s' model).",
        mediators[i], i, mediators[i + 1L]
      )
      stop(msg, call. = FALSE)
    }
  }
  # (c) last mediator predicts the response in model_y.
  if (!mediators[k] %in% names(stats::coef(model_y))) {
    stop(sprintf("Last mediator '%s' is not a predictor in 'model_y' (the outcome model).",
                 mediators[k]), call. = FALSE)
  }

  # --- Outcome name ---
  if (is.null(outcome)) outcome <- .get_response_var(model_y)

  # --- Path coefficients ---
  coef_y <- stats::coef(model_y)
  a_path <- unname(stats::coef(object)[treatment])
  d_path <- vapply(seq_len(k - 1L), function(i) {
    unname(stats::coef(mediator_models[[i]])[mediators[i]])
  }, numeric(1))
  b_path <- unname(coef_y[mediators[k]])
  # c' may be absent (full mediation) -> 0 with a warning.
  if (treatment %in% names(coef_y)) {
    c_prime <- unname(coef_y[treatment])
  } else {
    c_prime <- 0
    warning("Direct effect (c-prime path) not found in outcome model. Setting to 0.",
            call. = FALSE)
  }

  # --- Combined estimates with per-model prefixes (m1_, m2_, ..., mk_, y_) ---
  coef_list <- c(med_models, list(model_y))
  prefixes <- c(paste0("m", seq_len(k), "_"), "y_")
  named_coefs <- Map(function(mod, pre) {
    cf <- stats::coef(mod)
    stats::setNames(cf, paste0(pre, names(cf)))
  }, coef_list, prefixes)
  estimates <- unlist(unname(named_coefs))

  # Structural aliases (a, d1..d{k-1}, b, c_prime).
  d_names <- paste0("d", seq_len(k - 1L))
  alias_val <- c(
    a = a_path,
    stats::setNames(d_path, d_names),
    b = b_path,
    c_prime = c_prime
  )
  for (al in names(alias_val)) estimates[al] <- alias_val[[al]]

  # --- Block-diagonal source vcov of all k + 1 models ---
  vcov_list <- lapply(coef_list, stats::vcov)
  src_names <- unlist(Map(function(v, pre) paste0(pre, rownames(v)),
                          vcov_list, prefixes), use.names = FALSE)
  n_src <- length(src_names)
  vcov_src <- matrix(0, nrow = n_src, ncol = n_src,
                     dimnames = list(src_names, src_names))
  pos <- 0L
  for (v in vcov_list) {
    idx <- seq_len(nrow(v)) + pos
    vcov_src[idx, idx] <- v
    pos <- pos + nrow(v)
  }

  # --- Map aliases to source rows; expand with full row/column copies ---
  # a -> m1_<treatment>; d_i -> m{i+1}_<mediators[i]>; b -> y_<mediators[k]>;
  # c_prime -> y_<treatment>. Cross-model blocks are zero (separate equations),
  # so cov(a, d_i) = cov(d_i, b) = 0; cov(b, c_prime) survives (same y eqn).
  alias_src_name <- c(
    a = paste0("m1_", treatment),
    stats::setNames(
      paste0("m", seq_len(k - 1L) + 1L, "_", mediators[seq_len(k - 1L)]),
      d_names
    ),
    b = paste0("y_", mediators[k]),
    c_prime = paste0("y_", treatment)
  )
  resolve <- function(nm) {
    if (nm %in% src_names) which(src_names == nm)[1] else NA_integer_
  }
  source_idx <- vapply(alias_src_name, resolve, integer(1))

  vcov_combined <- .expand_vcov_with_aliases(
    vcov_src,
    source_idx = source_idx,
    aliases_to_add = names(alias_val)
  )

  # --- Residual standard deviations (Q3: per-mediator NA for non-Gaussian) ---
  sigma_mediators <- vapply(med_models, function(m) {
    s <- .extract_sigma(m)
    if (is.null(s)) NA_real_ else s
  }, numeric(1))
  if (all(is.na(sigma_mediators))) sigma_mediators <- NULL
  sigma_y <- .extract_sigma(model_y)  # NULL for non-Gaussian outcome

  # --- Predictor bookkeeping (exclude the intercept) ---
  drop_intercept <- function(nm) nm[nm != "(Intercept)"]
  mediator_predictors <- lapply(med_models,
                                function(m) drop_intercept(names(stats::coef(m))))
  outcome_predictors <- drop_intercept(names(coef_y))

  # --- Data, sample size, convergence ---
  if (is.null(data)) {
    data <- tryCatch(stats::model.frame(object), error = function(e) NULL)
  }
  n_obs <- if (!is.null(data)) nrow(data) else length(stats::residuals(object))

  all_models <- c(med_models, list(model_y))
  converged <- all(vapply(all_models, function(m) {
    if (inherits(m, "glm")) isTRUE(m$converged) else TRUE
  }, logical(1)))

  source_package <- if (any(vapply(all_models, inherits, logical(1), "glm"))) {
    "stats::glm"
  } else {
    "stats::lm"
  }

  # --- Assemble SerialMediationData ---
  SerialMediationData(
    a_path = a_path,
    d_path = d_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_combined,
    sigma_mediators = sigma_mediators,
    sigma_y = sigma_y,
    treatment = treatment,
    mediators = mediators,
    outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = source_package
  )
}


#' Classify a multi-mediator structure as serial or parallel
#'
#' Conservative, backward-compatible inference for `structure = "auto"`. Returns
#' `"parallel"` only on POSITIVE evidence of a parallel structure (no mediator is
#' regressed on another, and every mediator enters the outcome model); otherwise
#' defaults to `"serial"` (the historical default for vector `mediator`). It never
#' errors -- malformed inputs fall through to the chosen worker's own validation,
#' which emits specific, directed messages. Users can always set `structure`
#' explicitly to override.
#'
#' @param med_models Ordered list of the k mediator models (`med_models[[j]]` is
#'   intended to be the model for `mediators[j]`).
#' @param mediators Character vector of mediator names (length k).
#' @param treatment Treatment variable name.
#' @param model_y The outcome model.
#' @return `"serial"` or `"parallel"`.
#' @keywords internal
.classify_multimediator_structure <- function(med_models, mediators, treatment, model_y) {
  k <- length(mediators)
  # Model-count mismatch: defer to the serial worker's length validation.
  if (length(med_models) != k) return("serial")

  safe_names <- function(m) tryCatch(names(stats::coef(m)), error = function(e) character(0))
  preds <- lapply(med_models, safe_names)

  # Any mediator regressed on another mediator => chain-like => serial.
  has_med_pred <- any(vapply(seq_len(k), function(i) {
    any(setdiff(mediators, mediators[i]) %in% preds[[i]])
  }, logical(1)))
  if (has_med_pred) return("serial")

  # Positive parallel evidence: every mediator enters the single outcome model
  # (Y ~ X + M1 + ... + Mk). Serial outcome models carry only the last mediator.
  if (all(mediators %in% safe_names(model_y))) return("parallel")

  # Otherwise default to serial (historical behavior; the worker validates).
  "serial"
}


#' Extract Parallel Mediation Structure from lm/glm Models
#'
#' @description
#' Internal worker for parallel mediation (`X -> M_j -> Y`, independent
#' mediators). Mirrors [.extract_serial_mediation_lm()] but the mediator models
#' are NOT chained: `mediator_models[[j - 1]]` is the model for `mediators[j]`
#' regressed on the treatment (and covariates), in mediator-index order.
#'
#' @param object Model for the first mediator (`mediators[1] ~ treatment`).
#' @param mediator_models List of the remaining mediator models 2..k, in index
#'   order (each `mediators[j] ~ treatment (+ C)`).
#' @param model_y Outcome model (`Y ~ treatment + M1 + ... + Mk (+ C)`).
#' @param treatment,mediators,outcome,data See [.extract_serial_mediation_lm()].
#' @return A `ParallelMediationData` object.
#' @keywords internal
.extract_parallel_mediation_lm <- function( # nolint: object_length_linter.
    object,
    mediator_models,
    model_y,
    treatment,
    mediators,
    outcome = NULL,
    data = NULL) {

  # --- Input validation ---
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_character(mediators, min.len = 2, unique = TRUE,
                              any.missing = FALSE, .var.name = "mediator")
  checkmate::assert_multi_class(object, c("lm", "glm"), .var.name = "object")
  checkmate::assert_multi_class(model_y, c("lm", "glm"), .var.name = "model_y")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
  checkmate::assert_data_frame(data, null.ok = TRUE, .var.name = "data")

  k <- length(mediators)

  if (is.null(mediator_models)) {
    stop(sprintf(paste0(
      "Parallel mediation (length(mediator) >= 2) requires 'mediator_models': ",
      "a list of the %d remaining mediator models (M2 ~ %s, ..., Mk ~ %s) in ",
      "mediator-index order."
    ), k - 1L, treatment, treatment), call. = FALSE)
  }
  checkmate::assert_list(mediator_models, len = k - 1L,
                         .var.name = "mediator_models")
  for (i in seq_along(mediator_models)) {
    checkmate::assert_multi_class(
      mediator_models[[i]], c("lm", "glm"),
      .var.name = sprintf("mediator_models[[%d]]", i)
    )
  }

  # Full ordered list of mediator models: object is M1; mediator_models hold
  # M2..Mk, each regressed on the treatment (NOT on a predecessor mediator).
  med_models <- c(list(object), mediator_models)

  # --- Order / structure cross-check (directed stop() on any mismatch) ---
  for (j in seq_len(k)) {
    mod <- med_models[[j]]
    resp <- .get_response_var(mod)
    if (!identical(resp, mediators[j])) {
      msg <- if (j == 1L) {
        sprintf("'object' must be the model for mediator 1 ('%s'), but its response is '%s'.",
                mediators[1], resp)
      } else {
        sprintf(paste0("mediator_models[[%d]] must be the model for mediator %d ('%s'), ",
                       "but its response is '%s'. Check the order of 'mediator_models'."),
                j - 1L, j, mediators[j], resp)
      }
      stop(msg, call. = FALSE)
    }
    if (!treatment %in% names(stats::coef(mod))) {
      stop(sprintf("Treatment '%s' is not a predictor in the '%s' model.",
                   treatment, mediators[j]), call. = FALSE)
    }
  }
  # Each mediator must enter the outcome model.
  for (j in seq_len(k)) {
    if (!mediators[j] %in% names(stats::coef(model_y))) {
      stop(sprintf("Mediator '%s' is not a predictor in 'model_y' (the outcome model).",
                   mediators[j]), call. = FALSE)
    }
  }

  # --- Outcome name ---
  if (is.null(outcome)) outcome <- .get_response_var(model_y)

  # --- Path coefficients ---
  coef_y <- stats::coef(model_y)
  a_paths <- vapply(seq_len(k), function(j) {
    unname(stats::coef(med_models[[j]])[treatment])
  }, numeric(1))
  b_paths <- vapply(seq_len(k), function(j) {
    unname(coef_y[mediators[j]])
  }, numeric(1))
  if (treatment %in% names(coef_y)) {
    c_prime <- unname(coef_y[treatment])
  } else {
    c_prime <- 0
    warning("Direct effect (c-prime path) not found in outcome model. Setting to 0.",
            call. = FALSE)
  }

  # --- Combined estimates with per-model prefixes (m1_, ..., mk_, y_) ---
  coef_list <- c(med_models, list(model_y))
  prefixes <- c(paste0("m", seq_len(k), "_"), "y_")
  named_coefs <- Map(function(mod, pre) {
    cf <- stats::coef(mod)
    stats::setNames(cf, paste0(pre, names(cf)))
  }, coef_list, prefixes)
  estimates <- unlist(unname(named_coefs))

  # Structural aliases, interleaved a1, b1, ..., ak, bk, c_prime (matches paths()).
  alias_val <- numeric(0)
  for (j in seq_len(k)) {
    alias_val[paste0("a", j)] <- a_paths[j]
    alias_val[paste0("b", j)] <- b_paths[j]
  }
  alias_val["c_prime"] <- c_prime
  for (al in names(alias_val)) estimates[al] <- alias_val[[al]]

  # --- Block-diagonal source vcov of all k + 1 models ---
  vcov_list <- lapply(coef_list, stats::vcov)
  src_names <- unlist(Map(function(v, pre) paste0(pre, rownames(v)),
                          vcov_list, prefixes), use.names = FALSE)
  n_src <- length(src_names)
  vcov_src <- matrix(0, nrow = n_src, ncol = n_src,
                     dimnames = list(src_names, src_names))
  pos <- 0L
  for (v in vcov_list) {
    idx <- seq_len(nrow(v)) + pos
    vcov_src[idx, idx] <- v
    pos <- pos + nrow(v)
  }

  # --- Map aliases to source rows; expand with full row/column copies ---
  # a_j -> m{j}_<treatment> (separate mediator equations: cov(a_j, a_j') = 0);
  # b_j -> y_<mediators[j]> and c_prime -> y_<treatment> (one outcome equation:
  # cov(b_j, b_j') and cov(b_j, c') survive). cov(a_j, b_*) = 0 (cross-equation).
  alias_src_name <- character(0)
  for (j in seq_len(k)) {
    alias_src_name[paste0("a", j)] <- paste0("m", j, "_", treatment)
    alias_src_name[paste0("b", j)] <- paste0("y_", mediators[j])
  }
  alias_src_name["c_prime"] <- paste0("y_", treatment)
  resolve <- function(nm) {
    if (nm %in% src_names) which(src_names == nm)[1] else NA_integer_
  }
  source_idx <- vapply(alias_src_name, resolve, integer(1))

  vcov_combined <- .expand_vcov_with_aliases(
    vcov_src,
    source_idx = source_idx,
    aliases_to_add = names(alias_val)
  )

  # --- Residual standard deviations (per-mediator NA for non-Gaussian) ---
  sigma_mediators <- vapply(med_models, function(m) {
    s <- .extract_sigma(m)
    if (is.null(s)) NA_real_ else s
  }, numeric(1))
  if (all(is.na(sigma_mediators))) sigma_mediators <- NULL
  sigma_y <- .extract_sigma(model_y)

  # --- Predictor bookkeeping (exclude the intercept) ---
  drop_intercept <- function(nm) nm[nm != "(Intercept)"]
  mediator_predictors <- lapply(med_models,
                                function(m) drop_intercept(names(stats::coef(m))))
  outcome_predictors <- drop_intercept(names(coef_y))

  # --- Data, sample size, convergence ---
  if (is.null(data)) {
    data <- tryCatch(stats::model.frame(object), error = function(e) NULL)
  }
  n_obs <- if (!is.null(data)) nrow(data) else length(stats::residuals(object))

  all_models <- c(med_models, list(model_y))
  converged <- all(vapply(all_models, function(m) {
    if (inherits(m, "glm")) isTRUE(m$converged) else TRUE
  }, logical(1)))

  source_package <- if (any(vapply(all_models, inherits, logical(1), "glm"))) {
    "stats::glm"
  } else {
    "stats::lm"
  }

  # --- Assemble ParallelMediationData ---
  ParallelMediationData(
    a_paths = a_paths,
    b_paths = b_paths,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_combined,
    sigma_mediators = sigma_mediators,
    sigma_y = sigma_y,
    treatment = treatment,
    mediators = mediators,
    outcome = outcome,
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = source_package
  )
}


#' Extract Response Variable Name from Model
#'
#' @param model Fitted model object
#' @return Character string: response variable name
#' @keywords internal
.get_response_var <- function(model) {
  formula_obj <- stats::formula(model)
  response <- all.vars(formula_obj)[1]
  response
}


#' Extract Residual Standard Deviation from Model
#'
#' @param model Fitted model object
#' @return Numeric scalar or NULL
#' @keywords internal
.extract_sigma <- function(model) {
  if (inherits(model, "lm") && !inherits(model, "glm")) {
    # For lm, use sigma() or summary()$sigma
    return(stats::sigma(model))
  } else if (inherits(model, "glm")) {
    # For glm, check if Gaussian family
    if (model$family$family == "gaussian") {
      # For Gaussian GLM, sigma can be extracted
      return(sqrt(sum(stats::residuals(model, type = "pearson")^2) / model$df.residual))
    } else {
      # For non-Gaussian GLMs, sigma doesn't apply in the same way
      return(NULL)
    }
  }
  NULL
}
