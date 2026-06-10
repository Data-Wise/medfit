# S7 Method for Extracting Mediation Structure from lavaan Models
#
# This file implements extract_mediation() method for lavaan SEM models.
#
# The extraction supports simple mediation patterns:
#   X -> M -> Y  # nolint: commented_code_linter.
# where the lavaan model typically specifies:
#   M ~ a*X      # nolint: commented_code_linter.
#   Y ~ b*M + cp*X  # nolint: commented_code_linter.
#
# Note: This method is registered dynamically in zzz.R when lavaan is available

#' Extract Mediation Structure from lavaan Model
#'
#' Internal function for extracting mediation structure from lavaan models.
#' This function is registered as an S7 method in `.onLoad()` when lavaan
#' is available.
#'
#' @param object Fitted lavaan model object
#' @param treatment Character: name of the treatment variable
#' @param mediator Character: name of the mediator variable for simple
#'   mediation (X -> M -> Y), OR an ordered character vector of length >= 2 for
#'   serial mediation (X -> M1 -> M2 -> ... -> Y). When a vector is supplied the
#'   function returns a [SerialMediationData] object instead of [MediationData].
#' @param outcome Character: name of the outcome variable (optional, auto-detected)
#' @param a_label Character: label for the a path in lavaan model (default: "a")
#' @param b_label Character: label for the b path in lavaan model (default: "b")
#' @param cp_label Character: label for the c' path in lavaan model (default: "cp")
#' @param standardized Logical: extract standardized coefficients? (default: FALSE)
#' @param ... Additional arguments (ignored)
#'
#' @return A [MediationData] object, or a [SerialMediationData] object when
#'   `mediator` is a character vector of length >= 2 (serial mediation).
#'
#' @details
#' This method extracts mediation structure from a fitted lavaan SEM model.
#' The lavaan model should specify labeled paths for the mediation structure.
#'
#' ## Typical lavaan Model Specification
#'
#' ```
#' model <- "
#'   # Mediator model
#'   M ~ a*X
#'
#'   # Outcome model
#'   Y ~ b*M + cp*X
#'
#'   # Indirect and total effects (optional)
#'   indirect := a*b
#'   total := cp + a*b
#' "
#' ```
#'
#' ## Path Labels
#'
#' By default, the function looks for paths labeled:
#' - `a`: Treatment -> Mediator path
#' - `b`: Mediator -> Outcome path
#' - `cp`: Treatment -> Outcome (direct effect) path
#'
#' You can customize these labels using the `a_label`, `b_label`, and
#' `cp_label` arguments.
#'
#' ## Alternative: Unlabeled Paths
#'
#' If paths are not labeled, the function will attempt to identify them
#' by variable names. This requires specifying `treatment`, `mediator`,
#' and `outcome` arguments.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("lavaan", quietly = TRUE)) {
#'   # Simulate a simple mediation data set (X -> M -> Y)
#'   set.seed(123)
#'   n <- 200
#'   X <- rnorm(n)
#'   M <- 0.5 * X + rnorm(n)
#'   Y <- 0.3 * M + 0.2 * X + rnorm(n)
#'   dat <- data.frame(X = X, M = M, Y = Y)
#'
#'   # Fit a labeled lavaan mediation model
#'   model <- "
#'     M ~ a*X
#'     Y ~ b*M + cp*X
#'   "
#'   fit <- lavaan::sem(model, data = dat)
#'
#'   # Extract the mediation structure (dispatches to the lavaan method)
#'   med_data <- extract_mediation(
#'     fit,
#'     treatment = "X",
#'     mediator = "M",
#'     outcome = "Y"
#'   )
#' }
#' }
#'
#' @keywords internal
extract_mediation_lavaan <- function(object,
                                     treatment,
                                     mediator,
                                     outcome = NULL,
                                     a_label = "a",
                                     b_label = "b",
                                     cp_label = "cp",
                                     standardized = FALSE,
                                     ...) {

  # --- Check lavaan is available ---
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("Package 'lavaan' is required for this method but is not installed.",
         call. = FALSE)
  }

  # --- Input Validation (using checkmate for fail-fast defensive programming) ---

  checkmate::assert_string(treatment, .var.name = "treatment")
  # `mediator` may be a scalar (simple X -> M -> Y) or an ordered character
  # vector of length >= 2 (serial X -> M1 -> M2 -> ... -> Y). The arity selects
  # both the extraction path and the return type (MediationData for a scalar,
  # SerialMediationData for a vector).
  checkmate::assert_character(mediator, min.len = 1, any.missing = FALSE,
                              .var.name = "mediator")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
  checkmate::assert_flag(standardized, .var.name = "standardized")

  # --- Serial mediation: dispatch on mediator arity -------------------------
  # The lavaan S7 method dispatches on object class only, so the simple-vs-
  # serial decision is made here from the number of mediators supplied.
  if (length(mediator) > 1L) {
    return(.extract_serial_mediation_lavaan(
      object,
      treatment    = treatment,
      mediators    = mediator,
      outcome      = outcome,
      standardized = standardized,
      ...
    ))
  }

  # --- Simple mediation (scalar mediator): path-label args apply ------------
  checkmate::assert_string(a_label, .var.name = "a_label")
  checkmate::assert_string(b_label, .var.name = "b_label")
  checkmate::assert_string(cp_label, .var.name = "cp_label")

  # --- Extract Parameter Estimates ---

  # Get parameter estimates table
  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
    est_col <- "est.std"
  } else {
    param_table <- lavaan::parameterEstimates(object)
    est_col <- "est"
  }

  # --- Try to Extract Paths by Label First ---

  # Look for labeled paths
  a_row <- param_table[param_table$label == a_label, ]
  b_row <- param_table[param_table$label == b_label, ]
  cp_row <- param_table[param_table$label == cp_label, ]

  paths_found_by_label <- nrow(a_row) == 1 && nrow(b_row) == 1 && nrow(cp_row) == 1

  if (paths_found_by_label) {
    # Extract from labeled paths
    a_path <- a_row[[est_col]]
    b_path <- b_row[[est_col]]
    c_prime <- cp_row[[est_col]]

    # Auto-detect outcome if not provided
    if (is.null(outcome)) {
      outcome <- b_row$lhs[1]
    }
  } else {
    # Fall back to extracting by variable names
    # Find a path: mediator ~ treatment
    a_row <- param_table[param_table$lhs == mediator &
                           param_table$op == "~" &
                           param_table$rhs == treatment, ]

    if (nrow(a_row) == 0) {
      stop(sprintf(
        "Could not find a path (treatment -> mediator). Expected '%s ~ %s'",
        mediator, treatment
      ), call. = FALSE)
    }

    a_path <- a_row[[est_col]][1]

    # Auto-detect outcome if not provided
    if (is.null(outcome)) {
      # Find equations where mediator is a predictor
      mediator_effects <- param_table[param_table$op == "~" &
                                        param_table$rhs == mediator, ]
      if (nrow(mediator_effects) > 0) {
        outcome <- mediator_effects$lhs[1]
      } else {
        stop("Could not auto-detect outcome variable. Please specify 'outcome' argument.",
             call. = FALSE)
      }
    }

    # Find b path: outcome ~ mediator
    b_row <- param_table[param_table$lhs == outcome &
                           param_table$op == "~" &
                           param_table$rhs == mediator, ]

    if (nrow(b_row) == 0) {
      stop(sprintf(
        "Could not find b path (mediator -> outcome). Expected '%s ~ %s'",
        outcome, mediator
      ), call. = FALSE)
    }

    b_path <- b_row[[est_col]][1]

    # Find c' path: outcome ~ treatment
    cp_row <- param_table[param_table$lhs == outcome &
                            param_table$op == "~" &
                            param_table$rhs == treatment, ]

    if (nrow(cp_row) == 0) {
      # c' might be zero (full mediation) or not in model
      # Set to 0 if not found
      c_prime <- 0
      warning("Direct effect (c' path) not found in model. Setting to 0.",
              call. = FALSE)
    } else {
      c_prime <- cp_row[[est_col]][1]
    }
  }

  # --- Extract All Parameters and Variance-Covariance Matrix ---

  # Get all free parameter estimates
  all_coef <- lavaan::coef(object)

  # Get variance-covariance matrix
  vcov_mat <- lavaan::vcov(object)

  # Create estimates vector with named elements
  estimates <- all_coef

  # Add convenient aliases for key paths (only if not already present)
  # Track which aliases we're adding (not overwriting)
  aliases_to_add <- character(0)
  if (!("a" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "a")
  }
  if (!("b" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "b")
  }
  if (!("c_prime" %in% names(estimates))) {
    aliases_to_add <- c(aliases_to_add, "c_prime")
  }

  # Add aliases
  estimates["a"] <- a_path
  estimates["b"] <- b_path
  estimates["c_prime"] <- c_prime

  # --- Resolve each alias to its source parameter in the original vcov ---
  #
  # lavaan names free parameters either by their label (e.g. "a", "b", "cp")
  # or, when no label resolves to that name, by the variable-name form
  # ("M~X", "Y~M", "Y~X"). To be robust across labeled / unlabeled / custom-
  # label models we try BOTH forms for each path.
  #
  # Mapping the alias to a source *index* lets us copy the FULL covariance
  # structure (variances AND off-diagonal covariances), not just the diagonal
  # variance. This is essential: in single-equation SEM the a/b/c' paths are
  # estimated jointly and their pairwise covariances are non-zero.
  orig_names <- names(all_coef)

  resolve_source_idx <- function(label, var_name) {
    for (nm in c(label, var_name)) {
      if (!is.null(nm) && nm %in% orig_names) {
        return(which(orig_names == nm)[1])
      }
    }
    NA_integer_
  }

  source_idx <- c(
    a = resolve_source_idx(a_label, paste0(mediator, "~", treatment)),
    b = resolve_source_idx(b_label, paste0(outcome, "~", mediator)),
    c_prime = resolve_source_idx(cp_label, paste0(outcome, "~", treatment))
  )

  # Expand vcov so each NEW alias carries the FULL covariance row/column of its
  # source parameter (preserving off-diagonals such as cov(a, b), which are
  # non-zero in single-equation SEM). Shared with the lm/glm extractor so the
  # two engines cannot drift in how they assemble the alias block.
  vcov_expanded <- .expand_vcov_with_aliases(
    vcov_mat,
    source_idx = source_idx,
    aliases_to_add = aliases_to_add
  )

  # --- Extract Residual Variances ---

  # In lavaan, error variances are estimated parameters
  # Look for variance of mediator and outcome residuals

  sigma_m <- NULL
  sigma_y <- NULL

  # Mediator residual variance
  m_var_row <- param_table[param_table$lhs == mediator &
                             param_table$op == "~~" &
                             param_table$rhs == mediator, ]
  if (nrow(m_var_row) > 0) {
    m_var <- m_var_row[[est_col]][1]
    if (m_var > 0) {
      sigma_m <- sqrt(m_var)
    }
  }

  # Outcome residual variance
  y_var_row <- param_table[param_table$lhs == outcome &
                             param_table$op == "~~" &
                             param_table$rhs == outcome, ]
  if (nrow(y_var_row) > 0) {
    y_var <- y_var_row[[est_col]][1]
    if (y_var > 0) {
      sigma_y <- sqrt(y_var)
    }
  }

  # --- Get Data ---

  # Try to get data from lavaan object
  data <- tryCatch({
    d <- lavaan::lavInspect(object, "data")
    # lavaan may return a matrix; convert to data.frame if possible
    if (is.matrix(d)) {
      as.data.frame(d)
    } else if (is.data.frame(d)) {
      d
    } else {
      # If it's something else (like numeric), return NULL
      NULL
    }
  }, error = function(e) {
    NULL
  })

  # Get sample size
  n_obs <- lavaan::lavInspect(object, "nobs")
  if (length(n_obs) > 1) {
    # Multiple groups - use total
    n_obs <- sum(n_obs)
  }

  # --- Get Predictor Names ---

  # Mediator predictors: variables that predict the mediator
  m_predictors <- param_table[param_table$lhs == mediator &
                                param_table$op == "~", "rhs"]

  # Outcome predictors: variables that predict the outcome
  y_predictors <- param_table[param_table$lhs == outcome &
                                param_table$op == "~", "rhs"]

  # --- Check Convergence ---

  converged <- lavaan::lavInspect(object, "converged")

  # --- Create MediationData Object ---

  MediationData(
    a_path = a_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_expanded,
    sigma_m = sigma_m,
    sigma_y = sigma_y,
    treatment = treatment,
    mediator = mediator,
    outcome = outcome,
    mediator_predictors = m_predictors,
    outcome_predictors = y_predictors,
    data = data,
    n_obs = as.integer(n_obs),
    converged = converged,
    source_package = "lavaan"
  )
}


#' Extract Serial Mediation Structure from a lavaan Model
#'
#' Internal worker for the serial branch of [extract_mediation()] on lavaan
#' objects. It is invoked by [extract_mediation_lavaan()] when `mediator` is a
#' character vector of length >= 2, and returns a [SerialMediationData] object
#' describing the chain X -> M1 -> M2 -> ... -> Mk -> Y.
#'
#' @param object Fitted lavaan model object.
#' @param treatment Character scalar: treatment variable name.
#' @param mediators Character vector (length >= 2): mediator names in causal
#'   order (`M1 -> M2 -> ... -> Mk`).
#' @param outcome Character scalar, or `NULL` to auto-detect from the variable
#'   predicted by the last mediator.
#' @param standardized Logical: extract standardized coefficients?
#' @param ... Additional arguments (ignored).
#'
#' @return A [SerialMediationData] object.
#'
#' @details
#' Paths are located in the lavaan parameter table by variable name:
#' - `a`  : `M1 ~ X`
#' - `d_i`: `M_{i+1} ~ M_i` for `i = 1 .. k-1` (the `k - 1` inter-mediator paths)
#' - `b`  : `Y ~ Mk`
#' - `c'` : `Y ~ X` (defaults to 0 with a warning if absent -- full mediation)
#'
#' As in the simple-mediation extractor, named structural aliases
#' (`a`, `d1`, ..., `d{k-1}`, `b`, `c_prime`) are appended to `estimates` and
#' the variance-covariance matrix is expanded so that the FULL covariance
#' row/column of each source parameter is preserved. This lets downstream code
#' recover the true joint covariance of the chain (including off-diagonals)
#' via, for example, `vcov[c("a", "d1", "b"), c("a", "d1", "b")]` -- which is
#' required for serial indirect-effect standard errors.
#'
#' @keywords internal
.extract_serial_mediation_lavaan <- function( # nolint: object_length_linter.
    object,
    treatment,
    mediators,
    outcome = NULL,
    standardized = FALSE,
    ...) {

  # --- Input validation ---
  checkmate::assert_character(mediators, min.len = 2, unique = TRUE,
                              any.missing = FALSE, .var.name = "mediators")

  k <- length(mediators)

  # --- Parameter table & raw coefficient vector ---
  if (standardized) {
    param_table <- lavaan::standardizedSolution(object)
    est_col <- "est.std"
  } else {
    param_table <- lavaan::parameterEstimates(object)
    est_col <- "est"
  }
  all_coef <- lavaan::coef(object)
  vcov_mat <- lavaan::vcov(object)

  # Pull a single regression coefficient (`lhs ~ rhs`) from the parameter
  # table; return NA so callers decide whether the path is required.
  get_path <- function(lhs, rhs) {
    row <- param_table[param_table$lhs == lhs &
                         param_table$op == "~" &
                         param_table$rhs == rhs, ]
    if (nrow(row) == 0) return(NA_real_)
    row[[est_col]][1]
  }

  # --- Structural paths ---
  # Validate the chain links BEFORE outcome auto-detection so a missing link
  # reports the specific path (e.g. the a path), not a vague outcome error.

  # a path: treatment predicts the first mediator.
  a_path <- get_path(mediators[1], treatment)
  if (is.na(a_path)) {
    stop(sprintf("Could not find a path (%s ~ %s).", mediators[1], treatment),
         call. = FALSE)
  }

  # d paths: each mediator predicts the next; k - 1 links in chain order.
  d_path <- vapply(seq_len(k - 1L), function(i) {
    val <- get_path(mediators[i + 1L], mediators[i])
    if (is.na(val)) {
      stop(sprintf("Could not find d path (%s ~ %s).",
                   mediators[i + 1L], mediators[i]), call. = FALSE)
    }
    val
  }, numeric(1))

  # --- Auto-detect the outcome (variable predicted by the last mediator) ---
  if (is.null(outcome)) {
    is_pred <- param_table$op == "~" & param_table$rhs == mediators[k]
    # A well-formed serial chain has the last mediator point only at the
    # outcome; exclude any mediator-valued lhs defensively.
    last_med_effects <- param_table[is_pred & !param_table$lhs %in% mediators, ]
    if (nrow(last_med_effects) == 0) {
      stop(sprintf(
        paste0("Could not auto-detect outcome: no regression has '%s' as a ",
               "predictor. Please specify the 'outcome' argument."),
        mediators[k]
      ), call. = FALSE)
    }
    outcome <- last_med_effects$lhs[1]
  }
  checkmate::assert_string(outcome, .var.name = "outcome")

  # b path: last mediator predicts the outcome.
  b_path <- get_path(outcome, mediators[k])
  if (is.na(b_path)) {
    stop(sprintf("Could not find b path (%s ~ %s).", outcome, mediators[k]),
         call. = FALSE)
  }

  # c-prime path: direct treatment-to-outcome effect (may be absent).
  c_prime <- get_path(outcome, treatment)
  if (is.na(c_prime)) {
    c_prime <- 0
    warning("Direct effect (c-prime path) not found in model. Setting to 0.",
            call. = FALSE)
  }

  # --- Estimates + vcov with stable structural aliases ---
  # Mirror the simple-mediation extractor: expose named aliases
  # (a, d1..d{k-1}, b, c_prime) alongside lavaan's raw parameter vector, and
  # copy the FULL covariance row/column of each source parameter so the
  # off-diagonal covariances between chain paths are preserved.
  orig_names <- names(all_coef)

  resolve_source_idx <- function(var_name) {
    if (!is.null(var_name) && var_name %in% orig_names) {
      return(which(orig_names == var_name)[1])
    }
    NA_integer_
  }

  d_names <- paste0("d", seq_len(k - 1L))
  alias_var <- c(
    a = paste0(mediators[1], "~", treatment),
    stats::setNames(paste0(mediators[-1L], "~", mediators[-k]), d_names),
    b = paste0(outcome, "~", mediators[k]),
    c_prime = paste0(outcome, "~", treatment)
  )
  alias_val <- c(
    a = a_path,
    stats::setNames(d_path, d_names),
    b = b_path,
    c_prime = c_prime
  )

  estimates <- all_coef
  aliases_to_add <- names(alias_var)[!names(alias_var) %in% names(estimates)]
  for (al in names(alias_var)) estimates[al] <- alias_val[[al]]

  source_idx <- vapply(alias_var, resolve_source_idx, integer(1))

  # Same full-row/column alias expansion as the simple path and the lm/glm
  # extractor (shared helper), so the serial chain's off-diagonal covariances
  # -- needed for serial indirect-effect SEs -- are preserved.
  vcov_expanded <- .expand_vcov_with_aliases(
    vcov_mat,
    source_idx = source_idx,
    aliases_to_add = aliases_to_add
  )

  # --- Residual standard deviations (sqrt of estimated error variances) ---
  get_resid_sd <- function(v) {
    row <- param_table[param_table$lhs == v &
                         param_table$op == "~~" &
                         param_table$rhs == v, ]
    if (nrow(row) == 0) return(NA_real_)
    val <- row[[est_col]][1]
    if (is.na(val) || val < 0) return(NA_real_)
    sqrt(val)
  }
  sigma_mediators <- unname(vapply(mediators, get_resid_sd, numeric(1)))
  if (all(is.na(sigma_mediators))) sigma_mediators <- NULL
  sigma_y <- get_resid_sd(outcome)
  if (is.na(sigma_y)) sigma_y <- NULL

  # --- Predictor bookkeeping ---
  mediator_predictors <- lapply(mediators, function(m) {
    param_table[param_table$lhs == m & param_table$op == "~", "rhs"]
  })
  outcome_predictors <- param_table[param_table$lhs == outcome &
                                      param_table$op == "~", "rhs"]

  # --- Data, sample size, convergence ---
  data <- tryCatch({
    d <- lavaan::lavInspect(object, "data")
    if (is.matrix(d)) as.data.frame(d) else if (is.data.frame(d)) d else NULL
  }, error = function(e) NULL)

  n_obs <- lavaan::lavInspect(object, "nobs")
  if (length(n_obs) > 1) n_obs <- sum(n_obs)

  converged <- lavaan::lavInspect(object, "converged")

  # --- Assemble SerialMediationData ---
  SerialMediationData(
    a_path = a_path,
    d_path = d_path,
    b_path = b_path,
    c_prime = c_prime,
    estimates = estimates,
    vcov = vcov_expanded,
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
    source_package = "lavaan"
  )
}


#' Register lavaan Method for extract_mediation
#'
#' This function is called from `.onLoad()` to register the S7 method
#' for lavaan objects when the lavaan package is available.
#'
#' @keywords internal
.register_lavaan_method <- function() {
  if (requireNamespace("lavaan", quietly = TRUE)) {
    # Get the lavaan S4 class
    lavaan_class <- tryCatch({
      S7::as_class(methods::getClass("lavaan", where = asNamespace("lavaan")))
    }, error = function(e) {
      NULL
    })

    if (!is.null(lavaan_class)) {
      # Register the method
      S7::method(extract_mediation, lavaan_class) <- extract_mediation_lavaan
    }
  }
}
