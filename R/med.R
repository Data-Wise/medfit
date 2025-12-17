# ADHD-Friendly Entry Points
#
# This file provides simplified entry points for mediation analysis:
# - med(): Simple one-function interface for mediation
# - quick(): Instant one-line summary of results

#' Simple Mediation Analysis
#'
#' @description
#' A simplified entry point for mediation analysis. Specify the data and
#' variable names, and get results with minimal configuration.
#'
#' This is the recommended starting point for most mediation analyses.
#' For more control over model specifications, use [fit_mediation()] directly.
#'
#' @param data A data frame containing all variables
#' @param treatment Character: name of treatment (exposure) variable
#' @param mediator Character: name of mediator variable
#' @param outcome Character: name of outcome variable
#' @param covariates Character vector: names of covariates to include
#'   (optional, default: none)
#' @param boot Logical: compute bootstrap confidence intervals?
#'   (default: FALSE for speed)
#' @param n_boot Integer: number of bootstrap samples (default: 1000)
#' @param seed Integer: random seed for reproducibility (optional)
#' @param ... Additional arguments passed to [fit_mediation()]
#'
#' @return A MediationData object with mediation results
#'
#' @details
#' `med()` is designed to be the simplest way to run a mediation analysis.
#' It constructs the model formulas automatically from variable names.
#'
#' ## Default Behavior
#'
#' - Fits Gaussian (continuous) mediator and outcome models
#' - No covariates unless specified
#' - No bootstrap unless requested (use `boot = TRUE`)
#'
#' ## Accessing Results
#'
#' After running `med()`, use:
#' - `nie(result)`: Natural indirect effect
#' - `nde(result)`: Natural direct effect
#' - `te(result)`: Total effect
#' - `pm(result)`: Proportion mediated
#' - `quick(result)`: One-line summary
#' - `summary(result)`: Detailed summary
#'
#' @examples
#' # Generate example data
#' set.seed(123)
#' n <- 200
#' mydata <- data.frame(
#'   treatment = rnorm(n),
#'   covariate = rnorm(n)
#' )
#' mydata$mediator <- 0.5 * mydata$treatment + 0.2 * mydata$covariate + rnorm(n)
#' mydata$outcome <- 0.3 * mydata$treatment + 0.4 * mydata$mediator +
#'                   0.1 * mydata$covariate + rnorm(n)
#'
#' # Simple mediation (no covariates)
#' result <- med(
#'   data = mydata,
#'   treatment = "treatment",
#'   mediator = "mediator",
#'   outcome = "outcome"
#' )
#' print(result)
#'
#' # With covariates
#' result_cov <- med(
#'   data = mydata,
#'   treatment = "treatment",
#'   mediator = "mediator",
#'   outcome = "outcome",
#'   covariates = "covariate"
#' )
#'
#' # Quick summary
#' quick(result)
#'
#' \donttest{
#' # With bootstrap CI (slower)
#' result_boot <- med(
#'   data = mydata,
#'   treatment = "treatment",
#'   mediator = "mediator",
#'   outcome = "outcome",
#'   boot = TRUE,
#'   n_boot = 1000,
#'   seed = 42
#' )
#' }
#'
#' @seealso [fit_mediation()] for full control, [quick()] for instant summary,
#'   [nie()], [nde()], [te()], [pm()] for extracting effects
#' @export
med <- function(data,
                treatment,
                mediator,
                outcome,
                covariates = NULL,
                boot = FALSE,
                n_boot = 1000L,
                seed = NULL,
                ...) {
  # --- Input Validation ---
  checkmate::assert_data_frame(data, min.rows = 1, .var.name = "data")
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_string(outcome, .var.name = "outcome")
  checkmate::assert_character(covariates, null.ok = TRUE, .var.name = "covariates")
  checkmate::assert_flag(boot, .var.name = "boot")
  checkmate::assert_count(n_boot, positive = TRUE, .var.name = "n_boot")
  checkmate::assert_int(seed, null.ok = TRUE, .var.name = "seed")

  # Check variables exist in data
  checkmate::assert_choice(treatment, names(data),
                           .var.name = "treatment (must be in data)")
  checkmate::assert_choice(mediator, names(data),
                           .var.name = "mediator (must be in data)")
  checkmate::assert_choice(outcome, names(data),
                           .var.name = "outcome (must be in data)")

  if (!is.null(covariates)) {
    checkmate::assert_subset(covariates, names(data),
                             .var.name = "covariates (must all be in data)")
  }

  # --- Build Formulas ---
  # Mediator model: M ~ X + covariates
  if (is.null(covariates)) {
    formula_m <- stats::as.formula(paste(mediator, "~", treatment))
    formula_y <- stats::as.formula(paste(outcome, "~", treatment, "+", mediator))
  } else {
    cov_string <- paste(covariates, collapse = " + ")
    formula_m <- stats::as.formula(
      paste(mediator, "~", treatment, "+", cov_string)
    )
    formula_y <- stats::as.formula(
      paste(outcome, "~", treatment, "+", mediator, "+", cov_string)
    )
  }

  # --- Fit Model ---
  result <- fit_mediation(
    formula_y = formula_y,
    formula_m = formula_m,
    data = data,
    treatment = treatment,
    mediator = mediator,
    ...
  )

  # --- Bootstrap if requested ---
  if (boot) {
    # Define indirect effect function
    indirect_fn <- function(theta) {
      # Find a and b parameters
      a_name <- paste0("m_", treatment)
      b_name <- paste0("y_", mediator)

      if (a_name %in% names(theta) && b_name %in% names(theta)) {
        theta[a_name] * theta[b_name]
      } else {
        # Fallback: use a and b names directly
        theta["a"] * theta["b"]
      }
    }

    boot_result <- bootstrap_mediation(
      statistic_fn = indirect_fn,
      method = "parametric",
      mediation_data = result,
      n_boot = as.integer(n_boot),
      ci_level = 0.95,
      seed = seed
    )

    # Attach bootstrap result as attribute
    attr(result, "bootstrap") <- boot_result
  }

  result
}


#' Quick Summary of Mediation Results
#'
#' @description
#' Print a one-line summary of mediation results, perfect for quick checks
#' or ADHD-friendly workflows.
#'
#' @param x A MediationData object (or result from [med()])
#' @param digits Integer: number of significant digits (default: 3)
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#'
#' @details
#' Prints a compact one-line summary showing:
#' - NIE (Natural Indirect Effect) with CI if available
#' - NDE (Natural Direct Effect)
#' - Proportion Mediated (PM)
#'
#' If bootstrap results are available (from `med(..., boot = TRUE)`),
#' confidence intervals are shown for NIE.
#'
#' @examples
#' # Generate example data
#' set.seed(123)
#' n <- 100
#' mydata <- data.frame(X = rnorm(n))
#' mydata$M <- 0.5 * mydata$X + rnorm(n)
#' mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)
#'
#' result <- med(
#'   data = mydata,
#'   treatment = "X",
#'   mediator = "M",
#'   outcome = "Y"
#' )
#'
#' # One-line summary
#' quick(result)
#'
#' @seealso [med()], [nie()], [nde()], [pm()]
#' @export
quick <- function(x, digits = 3, ...) {
  # Handle S7 objects explicitly since UseMethod doesn't work with S7

  if (S7::S7_inherits(x, MediationData)) {
    return(.quick_mediation_data(x, digits, ...))
  }
  if (S7::S7_inherits(x, SerialMediationData)) {
    return(.quick_serial_mediation_data(x, digits, ...))
  }

  stop("quick() requires a MediationData or SerialMediationData object. ",
       "Use med() or fit_mediation() first.", call. = FALSE)
}


#' Internal quick implementation for MediationData
#' @noRd
.quick_mediation_data <- function(x, digits = 3, ...) {
  # Extract effects
  indirect <- as.numeric(nie(x))
  direct <- as.numeric(nde(x))
  prop_med <- as.numeric(pm(x))

  # Format values
  nie_str <- format(indirect, digits = digits)
  nde_str <- format(direct, digits = digits)
  pm_str <- format(prop_med * 100, digits = digits)

  # Check for bootstrap results
  boot_result <- attr(x, "bootstrap")

  if (!is.null(boot_result) && S7::S7_inherits(boot_result, BootstrapResult)) {
    # Format with CI
    ci_lower <- format(boot_result@ci_lower, digits = digits)
    ci_upper <- format(boot_result@ci_upper, digits = digits)
    ci_str <- paste0(" [", ci_lower, ", ", ci_upper, "]")
  } else {
    ci_str <- ""
  }

  # Print one-liner
  cat("NIE =", nie_str, ci_str,
      "| NDE =", nde_str,
      "| PM =", pm_str, "%\n")

  invisible(x)
}


#' Internal quick implementation for SerialMediationData
#' @noRd
.quick_serial_mediation_data <- function(x, digits = 3, ...) {
  # Extract effects
  indirect <- as.numeric(nie(x))
  direct <- as.numeric(nde(x))
  prop_med <- as.numeric(pm(x))
  n_mediators <- length(x@mediators)

  # Format values
  nie_str <- format(indirect, digits = digits)
  nde_str <- format(direct, digits = digits)
  pm_str <- format(prop_med * 100, digits = digits)

  # Check for bootstrap results
  boot_result <- attr(x, "bootstrap")

  if (!is.null(boot_result) && S7::S7_inherits(boot_result, BootstrapResult)) {
    ci_lower <- format(boot_result@ci_lower, digits = digits)
    ci_upper <- format(boot_result@ci_upper, digits = digits)
    ci_str <- paste0(" [", ci_lower, ", ", ci_upper, "]")
  } else {
    ci_str <- ""
  }

  # Print one-liner with mediator count
  cat("[", n_mediators, " mediators] ",
      "NIE =", nie_str, ci_str,
      "| NDE =", nde_str,
      "| PM =", pm_str, "%\n", sep = "")

  invisible(x)
}
