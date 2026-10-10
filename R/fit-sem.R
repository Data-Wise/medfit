# Native SEM engine: user entry point.
#
# `fit_sem()` fits model syntax to raw data by maximum likelihood with the
# engine in R/sem-*.R and returns a `SEMFit`. `.sem_as_semfit()` is the one place
# that turns the engine's plain list into the S7 object.

#' Fit a Structural Equation Model by Maximum Likelihood
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Fits a model written in lavaan-style syntax to raw data with medfit's native
#' maximum-likelihood engine, and returns a [SEMFit] object. The engine handles
#' observed and latent variables, user labels, fixed values, starts and bounds,
#' linear equality and inequality constraints (`==`, `<`, `>`), and defined
#' parameters (`:=`) with delta-method standard errors.
#'
#' @param model Character: model syntax. Lines may use `~` (regression),
#'   `=~` (latent variable), `~~` (variance or covariance), `label*variable`
#'   modifiers, `start()`, `lower()` and `upper()`, and the constraint
#'   operators `==`, `<`, `>` and `:=`. Mean structures are not supported.
#' @param data A data frame with the model's observed variables as numeric
#'   columns. Rows with missing values in those columns are dropped once
#'   (listwise deletion) and counted in `n_dropped`.
#' @param information Character: `"observed"` (default) or `"expected"`
#'   information for the standard errors.
#' @param n_starts Positive integer or `NULL`: number of optimizer starts
#'   tried before the fit is declared failed (`NULL` uses 5). Retries use
#'   perturbed starts drawn under a fixed seed and never change the caller's
#'   random number stream.
#' @param control List: options passed to the optimizer (`nloptr`).
#'
#' @return A [SEMFit] object.
#'
#' @examples
#' \donttest{
#' fit <- fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
#'   data = mediation_demo
#' )
#' fit@defined
#' }
#'
#' @seealso [SEMFit], [fit_mediation()]
#' @export
fit_sem <- function(model, data, information = c("observed", "expected"), n_starts = NULL,
                    control = list()) {
  checkmate::assert_character(model, min.len = 1L, any.missing = FALSE, .var.name = "model")
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information)
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  checkmate::assert_list(control, .var.name = "control")
  model <- paste(model, collapse = "\n")
  fit <- .sem_fit_syntax(model, data, information, n_starts = if (is.null(n_starts)) 5L else n_starts,
                         control = control)
  .sem_as_semfit(fit, model, match.call())
}

.sem_as_semfit <- function(fit, model, call = NULL) {
  tab <- fit$table
  free <- !is.na(fit$par_map)
  est <- ifelse(free, fit$theta[pmax(fit$par_map, 1L)], tab$fixed)
  se <- ifelse(free, sqrt(diag(fit$vcov))[pmax(fit$par_map, 1L)], NA_real_)
  table <- data.frame(
    lhs = tab$lhs, op = tab$op, rhs = tab$rhs, label = tab$label, free = free,
    est = unname(est), se = unname(se), stringsAsFactors = FALSE
  )
  SEMFit(
    theta = fit$theta, vcov = fit$vcov, table = table, defined = fit$defined, f = fit$f,
    n_obs = fit$n_obs, n_dropped = fit$n_dropped, df = fit$df, information = fit$information,
    converged = fit$converged, data = fit$data, model = model,
    diagnostics = fit[c("status", "decrement", "retries", "active_bounds", "active_constraints", "improper",
                        "sign_check")],
    internals = fit[c("ram", "par_map", "constraints", "partable")],
    call = call
  )
}

# `fit_mediation(engine = "native")`: fit the syntax with the native engine, then
# extract the mediation structure through the shared workers. Reached before the
# formula validation of the other engines, since the native route takes `model`,
# not formulas, and a latent mediator is not a column of `data`. Every argument
# the engine cannot honor errors, never silently ignored.
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
    stop("`weights` is not supported by engine = \"native\" in this version.", call. = FALSE)
  }
  if (se_type == "sandwich") {
    stop("se_type = \"sandwich\" is not supported by engine = \"native\" in this version.", call. = FALSE)
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
  fit_args <- c("information", "n_starts", "control")
  extract_args <- c("outcome", "structure", "decomposition", "interaction", "a_label", "b_label", "cp_label")
  unknown <- setdiff(names(engine_args), c(fit_args, extract_args))
  if (length(unknown)) {
    stop("unknown `engine_args` for engine = \"native\": ", paste(unknown, collapse = ", "),
         ". Recognized: ", paste(c(fit_args, extract_args), collapse = ", "), ".", call. = FALSE)
  }
  syntax <- paste(model, collapse = "\n")
  vars <- unique(unlist(.sem_parse(syntax)$parameters[c("lhs", "rhs")]))
  for (nm in c(treatment = treatment, mediator = mediator)) {
    if (!(nm %in% vars)) {
      stop(sprintf("'%s' is not a variable in `model`", nm), call. = FALSE)
    }
  }
  fit <- do.call(fit_sem, c(list(model = syntax, data = data), engine_args[intersect(names(engine_args), fit_args)]))
  extract_call <- c(
    list(object = fit, treatment = treatment, mediator = mediator),
    engine_args[intersect(names(engine_args), extract_args)],
    if (given$m_star) list(m_star = m_star)
  )
  do.call(extract_mediation, extract_call)
}
