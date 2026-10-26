# Native SEM engine: user entry point.
#
# `fit_sem()` fits model syntax to raw data by maximum likelihood with the
# engine in R/sem-*.R and returns a `SEMFit`. `.sem_as_semfit()` is the one place
# that turns the engine's plain list into the S7 object.

#' Fit a Structural Equation Model by Maximum Likelihood
#'
#' @description
#' Fits a model written in lavaan-style syntax to raw data with medfit's native
#' maximum-likelihood engine, and returns a [SEMFit] object. The engine handles
#' observed and latent variables, user labels, fixed values, starts and bounds,
#' equality and inequality constraints (`==`, `<`, `>`, linear or nonlinear), and defined
#' parameters (`:=`) with delta-method standard errors.
#'
#' @param model Character: model syntax. Lines may use `~` (regression),
#'   `=~` (latent variable), `~~` (variance or covariance), `label*variable`
#'   modifiers, `start()`, `lower()` and `upper()`, and the constraint
#'   operators `==`, `<`, `>` and `:=`. An intercept is written `y ~ 1` (alone or with other terms, as
#'   in `y ~ 1 + x`) and turns on the mean structure. A product of two observed variables is written
#'   `x:m` on the right side of a regression (canonical name `m:x`); `?"medfit-syntax"` lists the
#'   supported class and each limit.
#' @param data A data frame with the model's observed variables. Numeric columns are used as is; a
#'   factor, character or logical column named on a regression's right side is expanded to 0/1 dummies
#'   (`?"medfit-syntax"` lists the rules and limits). Rows with missing values in those columns are dropped once
#'   (listwise deletion) and counted in `n_dropped`.
#' @param information Character: `"observed"` (default) or `"expected"`
#'   information for the standard errors. `"expected"` is an error for a model with a product term
#'   that has an endogenous factor (the product is a function of another variable, so the expected
#'   information gives wrong standard errors); use the default with `se_type = "sandwich"`.
#' @param n_starts Positive integer or `NULL`: number of optimizer starts
#'   tried before the fit is declared failed (`NULL` uses 5). Retries use
#'   perturbed starts drawn under a fixed seed and never change the caller's
#'   random number stream; with 3 or more starts the last attempt is the model's
#'   own moment-based start, so a start in a bad basin does not end the fit.
#'   With a nonlinear constraint, which can leave several
#'   local optima, every start is tried and the best accepted one is kept (a
#'   warning says when the accepted starts disagree); otherwise the first
#'   accepted start is used.
#' @param control List: options passed to the optimizer (`nloptr`).
#' @param weights Optional numeric vector of non-negative case weights,
#'   one per row of `data` (`NULL`, the default, fits unweighted). The fit is
#'   weighted maximum likelihood on the weighted mean and covariance; the scale
#'   of the weights does not matter. Rows dropped for missing values drop their
#'   weights with them. Use with `se_type = "sandwich"`.
#' @param se_type Character: `"model"` (default) takes the covariance of the
#'   estimates from the inverse information; `"sandwich"` uses the robust
#'   sandwich covariance \eqn{A^{-1} B A^{-1}}{A^-1 B A^-1} with casewise scores
#'   (HC0-type: it equals `sandwich::vcovHC(type = "HC0")` per equation and
#'   lavaan's robust standard errors with `sampling.weights`, and is smaller
#'   than the HC3 default of the glm route by a factor that shrinks like
#'   \eqn{1/n}{1/n}). Model-based standard errors are not valid under weights.
#' @param meanstructure Logical or `NULL`. `NULL` (default) fits a mean structure when the model writes
#'   an intercept (`y ~ 1`, free or fixed); `TRUE` fits one regardless; `FALSE` fits covariances only and
#'   errors if an intercept is written. With a mean structure every observed variable whose intercept is
#'   not written has a free one, so a model with only free intercepts has the same estimates and
#'   standard errors as the covariance-only fit. A latent variable's mean is fixed at 0.
#'   A model with a product term (`y ~ x + m + x:m`) always fits the mean structure (it needs the mediator
#'   intercept for the four-way decomposition), so with a product `meanstructure = FALSE` is an error.
#'   Left unset, with no `~1` and no product in the model, it warns once per session that the default becomes `TRUE`
#'   in medfit 0.15.0; `options(medfit.native_defaults = "0.15")` uses `TRUE` now.
#' @param fixed_x `FALSE` (default), `TRUE`, or a character vector of exogenous observed variable names. The
#'   selected variables (`TRUE`: every exogenous observed variable, product columns included) have their mean (with
#'   a mean structure), variance and the exogenous covariances the model contains fixed at the sample moments of
#'   the estimation sample (weighted when `weights` are given) and removed from estimation, as lavaan does with
#'   `fixed.x = TRUE`. The structural estimates, their standard errors, the degrees of freedom and the chi-square do
#'   not change; the parameter count and the log likelihood do: the log likelihood (and so AIC and BIC) is
#'   conditional on the fixed variables, and `glance()$fixed_x` lists them. Models whose `fixed_x` sets or data differ
#'   cannot be compared with [stats::anova()], [mbco_sem()], `AIC()` or `BIC()`. A (co)variance or intercept statement
#'   on a selected variable is an error (lavaan would silently keep it free). The fixed rows stay in the parameter table
#'   (`fixed_x` column, no standard error) but not in `coef()` or `vcov()`.
#'   Left unset, in a model with an exogenous observed variable, it warns once per session that the default becomes
#'   the exogenous observed variables in medfit 0.15.0; `options(medfit.native_defaults = "0.15")` uses that now:
#'   every exogenous observed variable (product and factor-dummy columns included) except those a `~~` or `~1`
#'   statement names, which are left free with a message of class `medfit_message_fixed_x_lenient` (an explicit
#'   `TRUE` errors there instead). `glance()$fixed_x` names the set the fit used.
#' @param sampling_weights `r lifecycle::badge("deprecated")` Renamed `weights`, the name
#'   [fit_mediation()] uses; the old name still works with a warning.
#'
#' @section Defaults are changing:
#' In medfit 0.15.0 the defaults become `fixed_x` = the exogenous observed variables (lavaan's `fixed.x = TRUE`) and
#' `meanstructure = TRUE`, so a default fit matches a default `lavaan::sem()` fit. 0.14.0 changes no result: it
#' warns once per session per argument (class `medfit_warning_default_change`) when an argument is left unset in a
#' model where its default will matter. Under the new defaults the parameter count, `logLik()`, `AIC()`, `BIC()` and
#' the names in `coef()`, `vcov()` and `tidy()` change; the structural estimates and their standard errors did not
#' change on the cases measured. Which random start a multi-start fit tries can change too (the retry seed follows the
#' parameter names). To keep today's results and silence the warning, pass both arguments, for example
#' `fixed_x = FALSE, meanstructure = NULL`. To fit with the 0.15.0 defaults now, set
#' `options(medfit.native_defaults = "0.15")`; variables a `~~` or `~1` statement names are then left free and named
#' in a message of class `medfit_message_fixed_x_lenient`.
#'
#' @return A [SEMFit] object. With a product term whose factor is a regression target (`x:m` with
#'   `m` regressed on `x`), `glance()` reports the chi-square, df and p-value as `NA` with a note, and
#'   `anova()` and [mbco_sem()] refuse; see [SEMFit-methods].
#'   `diagnostics$ledger` holds the versioned outcome ledger described below.
#'
#' @section Outcome ledger:
#' `diagnostics$ledger` is a list with `schema_version = 1L`. Each node has `id`, `parent_id`, the exact parsed
#' `constraints`, and `context` (the estimation `sample`, the model syntax and parameters, the likelihood `domain`,
#' the settings and `n_obs`). `enumeration` records `state` and the number of required children; `complete` means
#' every required restriction was attempted, not that any was globally optimized. `outcome` is `resolved` or
#' `unresolved`. Separate fields record `optimizer` (acceptance state, original status, decrement, retries and
#' optimum diagnostics), `likelihood` (availability and `f`), `feasibility` (`witness` or `unknown`), `covariance`
#' (`available`, `unavailable` or `not_retained`), `improper`, the retained `notices` (warnings and messages), the
#' original `condition` (class, message, call) and the recursive `children`. IDs are deterministic positions within
#' the call, not certificates of equivalent parameter spaces. No global optimum is asserted, and a failed branch is
#' unknown, never certified infeasible.
#'
#' A node whose constraints hold zero-product rows also has `branch_map`: `state`, `raw_count`, the parser
#' `factor_counts`, `unique_count` and `raw_to_canonical`, a structural restriction-set ID for each raw row. The IDs
#' collapse duplicate or permuted constraint rows, not arbitrary affine equivalence, and every raw row is still fitted
#' in its original order (ties go to the first). More than 64 raw combinations, duplicates included, is refused before
#' the grid is allocated, even when the unique count would be smaller; that node is `not_enumerated`, with an unknown
#' unique count and no raw mapping, and nothing is fitted or certified. Its message prints the count without scientific
#' notation, labels a count above \eqn{2^{53}}{2^53} as approximate (a double need not be an exact cardinality there)
#' and names an overflow; `raw_count` is `Inf` on overflow. If the map cannot be built while an error is recorded, its
#' `state` is `unavailable` with that condition, and the original error is not replaced. The map is rebuilt from the
#' node's constraints during validation, so a forged map is refused.
#'
#' The one proof of emptiness is the literal certificate `literal_zero_nonzero`: an explicit `label == 0` equality and
#' an explicit finite nonzero literal equality on the same parsed label (`a == 0` with `a == 1`). Its label, source
#' rows and values are kept in `certificate` and rebuilt from the node's own parsed parameters and constraints before
#' any inference uses it. A certified-empty branch is retained with `outcome = "excluded"`,
#' `feasibility = "certified_empty"` and an unavailable likelihood: it is not fitted and is not a successful fit. No
#' tolerance, solver status, numerical rank, bound, general affine contradiction or fixed value in the parameter
#' table is a proof, and a literal too small to represent (`1e-999`) is unknown.
#'
#' A zero-product fit returns only if at least one required branch resolves and every other branch resolves or is
#' certified empty. A direct fit whose own equalities contradict literally stops with `medfit_sem_infeasible`, and a
#' union whose every branch is certified empty with `medfit_sem_empty_union`; both are refinements of
#' `medfit_error_no_convergence` and carry the ledger. Otherwise it stops with a
#' `medfit_error_no_convergence` error, never a fit; the error carries the ledger of every required branch as
#' `$ledger` and, when a branch survived, `$best_survivor` (its `id` and discrepancy `f`, diagnostic only, never a
#' p-value). The union's own node does not aggregate its children's notices; inspect each child. The notices of a
#' failed call are in the ledger only; the error message keeps its text. A data or model error keeps its own class
#' and also carries `$ledger`. The estimation sample is stored once, on the root node; a descendant fitted on the
#' same rows carries only `context$sample_hash`. A fit made before the ledger existed must be refitted before
#' [mbco_sem()] can use it, which refuses it with a `medfit_error_ledger` error.
#'
#' @examples
#' \donttest{
#' fit <- fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
#'   data = mediation_demo, fixed_x = FALSE, meanstructure = NULL
#' )
#' fit@defined
#'
#' # A treatment-by-mediator product: the four-way decomposition
#' fit4 <- fit_sem(
#'   "mediator1 ~ treatment\noutcome_int ~ treatment + mediator1 + treatment:mediator1",
#'   data = mediation_demo, se_type = "sandwich"
#' )
#' decompose(extract_mediation(fit4, treatment = "treatment", mediator = "mediator1",
#'                             outcome = "outcome_int"))
#' }
#'
#' @seealso [SEMFit], [fit_mediation()]
#' @export
fit_sem <- function(model, data, information = c("observed", "expected"), n_starts = NULL,
                    control = list(), weights = NULL, se_type = c("model", "sandwich"),
                    meanstructure = NULL, fixed_x = FALSE, sampling_weights = lifecycle::deprecated()) {
  # 0.14.0 (E-14): missing() is only reliable before either argument is reassigned.
  fx_unset <- missing(fixed_x)
  ms_unset <- missing(meanstructure)
  if (lifecycle::is_present(sampling_weights)) {
    lifecycle::deprecate_warn("0.8.0", "fit_sem(sampling_weights)", "fit_sem(weights)")
    if (!is.null(weights)) {
      stop("pass `weights`, not both `weights` and the deprecated `sampling_weights`.", call. = FALSE)
    }
    weights <- sampling_weights
  }
  checkmate::assert_character(model, min.len = 1L, any.missing = FALSE, .var.name = "model")
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information)
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  checkmate::assert_list(control, .var.name = "control")
  checkmate::assert_flag(meanstructure, null.ok = TRUE, .var.name = "meanstructure")
  checkmate::assert(
    checkmate::check_flag(fixed_x),
    checkmate::check_character(fixed_x, any.missing = FALSE, min.len = 1L, unique = TRUE),
    .var.name = "fixed_x"
  )
  se_type <- match.arg(se_type)
  if (!is.null(weights) && se_type == "model") {
    .notify_ipw_model_se()
  }
  model <- paste(model, collapse = "\n")
  .native_defaults_opt_in() # a bad option value errors even when both settings are explicit
  if (fx_unset || ms_unset) {
    resolved <- .native_defaults_resolve(model, data, fixed_x, meanstructure, fx_unset, ms_unset)
    fixed_x <- resolved$fixed_x
    meanstructure <- resolved$meanstructure
  }
  fit <- .sem_fit_syntax(model, data, information, n_starts = if (is.null(n_starts)) 5L else n_starts,
                         control = control, weights = weights, se_type = se_type, meanstructure = meanstructure,
                         fixed_x = fixed_x)
  .sem_as_semfit(fit, model, match.call())
}

.sem_as_semfit <- function(fit, model, call = NULL) {
  .sem_require_outcome(fit, model)
  tab <- fit$table
  free <- !is.na(fit$par_map)
  est <- ifelse(free, fit$theta[pmax(fit$par_map, 1L)], tab$fixed)
  se <- ifelse(free, sqrt(diag(fit$vcov))[pmax(fit$par_map, 1L)], NA_real_)
  table <- data.frame(
    lhs = tab$lhs, op = tab$op, rhs = tab$rhs, label = tab$label, free = free,
    est = unname(est), se = unname(se), fixed_x = tab$fixed_x, stringsAsFactors = FALSE
  )
  SEMFit(
    theta = fit$theta, vcov = fit$vcov, table = table, defined = fit$defined, f = fit$f,
    n_obs = fit$n_obs, n_dropped = fit$n_dropped, df = fit$df, information = fit$information,
    converged = fit$converged, data = fit$data, model = model,
    diagnostics = fit[c("status", "decrement", "retries", "active_bounds", "active_constraints", "improper",
                        "sign_check", "se_type", "optimum", "ledger")],
    internals = fit[c("ram", "par_map", "constraints", "partable", "weights", "eq_rank", "n_starts", "control",
                      "branch", "fixed_x", "factors")],
    call = call
  )
}

# `fit_mediation(engine = "native")`: fit the syntax with the native engine, then
# extract the mediation structure through the shared workers. Reached before the
# formula validation of the other engines, since the native route takes `model`,
# not formulas, and a latent mediator is not a column of `data`. Every argument
# the engine cannot honor errors, never silently ignored. `weights` and `se_type` pass to `fit_sem()`.
.fit_mediation_native <- function(model, data, treatment, mediator, given, weights, se_type, cluster,
                                  engine_args, m_star, dots) {
  if (given$formulas) {
    stop("engine = \"native\" takes `model =`, not formulas", call. = FALSE)
  }
  if (is.null(model)) {
    stop("engine = \"native\" needs `model`, the model syntax.", call. = FALSE)
  }
  checkmate::assert_character(model, min.len = 1L, any.missing = FALSE, .var.name = "model")
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_list(engine_args, names = "unique", .var.name = "engine_args")
  if (!is.null(weights)) {
    checkmate::assert_numeric(weights, len = nrow(data), lower = 0, any.missing = FALSE, .var.name = "weights")
  }
  if (se_type == "kr") {
    stop("se_type = \"kr\" (Kenward-Roger) is only used with engine = \"lmer\".", call. = FALSE)
  }
  if (!is.null(cluster)) {
    stop("`cluster` is only used with engine = \"lmer\".", call. = FALSE)
  }
  if (given$family) {
    stop("engine = \"native\" fits Gaussian models; `family_y` and `family_m` are not used.", call. = FALSE)
  }
  if (length(dots)) {
    stop("unused arguments for engine = \"native\": ", paste(names(dots), collapse = ", "), call. = FALSE)
  }
  fit_args <- c("information", "n_starts", "control", "meanstructure", "fixed_x")
  extract_args <- c("outcome", "structure", "decomposition", "interaction", "a_label", "b_label", "cp_label")
  unknown <- setdiff(names(engine_args), c(fit_args, extract_args))
  if (length(unknown)) {
    stop("unknown `engine_args` for engine = \"native\": ", paste(unknown, collapse = ", "),
         ". Recognized: ", paste(c(fit_args, extract_args), collapse = ", "), ".", call. = FALSE)
  }
  syntax <- paste(model, collapse = "\n")
  # A product term (`m:x`) names two variables; a treatment that only appears inside one is still in the model.
  vars <- unique(unlist(strsplit(unlist(.sem_parse(syntax)$parameters[c("lhs", "rhs")]), ":", fixed = TRUE)))
  for (nm in c(treatment = treatment, mediator = mediator)) {
    if (!(nm %in% vars)) {
      stop(sprintf("'%s' is not a variable in `model`", nm), call. = FALSE)
    }
  }
  fit <- do.call(
    fit_sem,
    c(list(model = syntax, data = data, weights = weights, se_type = se_type),
      engine_args[intersect(names(engine_args), fit_args)])
  )
  extract_call <- c(
    list(object = fit, treatment = treatment, mediator = mediator),
    engine_args[intersect(names(engine_args), extract_args)],
    if (given$m_star) list(m_star = m_star)
  )
  do.call(extract_mediation, extract_call)
}
