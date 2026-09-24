# S7 Generic Functions for medfit
#
# This file defines the core S7 generics:
# - extract_mediation(): Extract mediation structure from fitted models
# - bootstrap_mediation(): Perform bootstrap inference

#' Extract Mediation Structure from Fitted Models
#'
#' @description
#' Generic function to extract mediation structure (a, b, c' paths and
#' variance-covariance matrices) from fitted models. This function provides
#' a unified interface for extracting mediation information from various
#' model types (lm, glm, lavaan, lmer, brms, etc.).
#'
#' @param object Fitted model object (lm, glm, lavaan, etc.)
#' @param ... Additional arguments passed to methods. Common arguments include:
#'   - `treatment`: Character string specifying treatment variable name
#'   - `mediator`: Character string specifying mediator variable name
#'   - Method-specific arguments (see individual method documentation)
#'
#' @return A [MediationData] object containing:
#'   - Path coefficients (a, b, c')
#'   - Full parameter vector and variance-covariance matrix
#'   - Residual variances (for Gaussian models)
#'   - Variable names and metadata
#'   - Original data (if available)
#'
#' @details
#' The `extract_mediation()` generic provides methods for different model types:
#'
#' - **lm/glm**: Extract from linear and generalized linear models
#' - **lavaan**: Extract from structural equation models
#' - **lmerMod**: Extract from mixed-effects models (future)
#' - **brmsfit**: Extract from Bayesian models (future)
#'
#' Note: OpenMx extraction is planned for a future release.
#'
#' All methods return a standardized [MediationData] object that can be used
#' with other medfit functions and dependent packages (probmed, RMediation,
#' medrobust).
#'
#' @examples
#' \donttest{
#' # Extract the mediation structure from fitted lm models, using the
#' # simulated mediation_demo data bundled with medfit
#' fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2,
#'             data = mediation_demo)
#' fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'             data = mediation_demo)
#' med_data <- extract_mediation(fit_m, model_y = fit_y,
#'                               treatment = "treatment", mediator = "mediator1")
#' }
#'
#' @seealso [MediationData], [fit_mediation()], [bootstrap_mediation()]
#' @export
extract_mediation <- S7::new_generic(
  "extract_mediation",
  dispatch_args = "object"
)


#' Perform Bootstrap Inference for Mediation Statistics
#'
#' @description
#' Conduct bootstrap inference to compute confidence intervals for
#' mediation statistics. Supports parametric, nonparametric, and
#' plugin methods.
#'
#' @param statistic_fn Function that computes the statistic of interest.
#'   - For parametric bootstrap: receives parameter vector, returns scalar
#'   - For nonparametric bootstrap: receives data frame, returns scalar
#'   - For plugin: receives parameter vector, returns scalar
#' @param method Character string: bootstrap method. Options:
#'   - `"parametric"`: Sample from multivariate normal (fast, assumes normality)
#'   - `"nonparametric"`: Resample data and refit (robust, slower)
#'   - `"plugin"`: Point estimate only, no CI (fastest)
#' @param mediation_data [MediationData] object (required for parametric/plugin)
#' @param data Data frame (required for nonparametric bootstrap)
#' @param n_boot Integer: number of bootstrap samples (default: 1000)
#' @param ci_level Numeric: confidence level between 0 and 1 (default: 0.95)
#' @param parallel Logical: use parallel processing? (default: FALSE)
#' @param ncores Integer: number of cores for parallel processing.
#'   If NULL, uses `detectCores() - 1`
#' @param seed Integer: random seed for reproducibility (optional but recommended)
#' @param ... Additional arguments (reserved for future use)
#'
#' @return A [BootstrapResult] object containing:
#'   - Point estimate
#'   - Confidence interval bounds
#'   - Bootstrap distribution (for parametric and nonparametric)
#'   - Method used
#'
#' @details
#' ## Bootstrap Methods
#'
#' **Parametric Bootstrap** (`method = "parametric"`):
#' - Samples parameter vectors from \eqn{N(\hat{\theta}, \hat{\Sigma})}{N(theta-hat, Sigma-hat)}
#' - Fast and efficient
#' - Assumes asymptotic normality of parameters
#' - Recommended for most applications with n > 50
#'
#' **Nonparametric Bootstrap** (`method = "nonparametric"`):
#' - Resamples observations with replacement
#' - Refits models for each bootstrap sample
#' - More robust, no normality assumption
#' - Computationally intensive
#' - Use when normality is questionable or n is small
#'
#' **Plugin Estimator** (`method = "plugin"`):
#' - Computes point estimate only
#' - No confidence interval
#' - Fastest method
#' - Use for quick checks or when CI not needed
#'
#' ## Parallel Processing
#'
#' Set `parallel = TRUE` to use multiple cores:
#' - Automatically detects available cores
#' - Falls back to sequential if parallel fails
#' - Seed handling ensures reproducibility
#'
#' ## Reproducibility
#'
#' Always set a seed for reproducible results:
#' ```r
#' bootstrap_mediation(..., seed = 12345)
#' ```
#'
#' @examples
#' \dontrun{
#' # Parametric bootstrap for indirect effect
#' result <- bootstrap_mediation(
#'   statistic_fn = function(theta) theta["a"] * theta["b"],
#'   method = "parametric",
#'   mediation_data = med_data,
#'   n_boot = 5000,
#'   ci_level = 0.95,
#'   seed = 12345
#' )
#'
#' # Nonparametric bootstrap with parallel processing
#' result <- bootstrap_mediation(
#'   statistic_fn = function(data) {
#'     # Refit models and compute statistic
#'     # ...
#'   },
#'   method = "nonparametric",
#'   data = mydata,
#'   n_boot = 5000,
#'   parallel = TRUE,
#'   seed = 12345
#' )
#'
#' # Plugin estimator (no CI)
#' result <- bootstrap_mediation(
#'   statistic_fn = function(theta) theta["a"] * theta["b"],
#'   method = "plugin",
#'   mediation_data = med_data
#' )
#' }
#'
#' @seealso [BootstrapResult], [MediationData], [extract_mediation()]
#' @export
bootstrap_mediation <- function(statistic_fn,
                                method = c("parametric", "nonparametric", "plugin"),
                                mediation_data = NULL,
                                data = NULL,
                                n_boot = 1000,
                                ci_level = 0.95,
                                parallel = FALSE,
                                ncores = NULL,
                                seed = NULL,
                                ...) {
  # This is a regular function, not an S7 generic
  # Implementation will be in bootstrap.R
  stop("bootstrap_mediation() not yet implemented. See planning/medfit-roadmap.md")
}
