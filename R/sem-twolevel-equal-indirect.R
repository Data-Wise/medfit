# Native SEM engine: the likelihood-ratio test of equal indirect effects across the two levels of a two-level fit
# (IG3 T-B, planning/specs/SCOPE-IG3-twolevel-tests-2026-11-19.md). The free fit against the fit with the one
# nonlinear row `a_w*b_w == a_b*b_b`, which the two-level guard admits (`.sem_equal_products_only()`) and the existing
# nonlinear gate solves (SLSQP rows `cons$nl`, Lagrangian Hessian, polish, acceptance gate).

#' Test equal indirect effects across the two levels of a native two-level fit
#'
#' `r lifecycle::badge("experimental")`
#' Likelihood-ratio test of the null that the within-level and the between-level indirect effects are equal,
#' \eqn{a_w b_w = a_b b_b}{a_w * b_w = a_b * b_b}, for a native two-level fit from [fit_sem()] with `cluster =`. The
#' statistic is the free fit's likelihood against the fit with that one nonlinear equality. It is a separate test: the
#' descriptive within-minus-between contrast of `nie(level = "contrast")` is never reported by `nie()` with a p-value,
#' and there is no Wald test of it here.
#'
#' @param object A [SEMFit] from [fit_sem()] with `cluster =` (a two-level model).
#' @param a_within,b_within The labels of the within-level (level 1) `a` and `b` regression paths.
#' @param a_between,b_between The labels of the between-level (level 2) `a` and `b` regression paths.
#' @param n_starts,control Optimizer settings for the constrained refit; `NULL` keeps the fit's own.
#' @param n_boot Number of parametric bootstrap replications of the statistic (default 0, none). Each replication
#'   draws clustered data of the same cluster sizes from the constrained fit, refits both models and keeps the
#'   statistic; replications that do not resolve (an inadmissible, non-positive-definite or non-converged refit) are
#'   dropped, so the bootstrap p-value is conditional on admissible refits, and the number dropped is reported
#'   (`boot$n_dropped`). The bootstrap p-value is `(1 + #{LR* >= LR}) / (n_valid + 1)`; use it at a small number of
#'   clusters, where the between-level asymptotics are poor.
#' @param seed Optional integer seed for the bootstrap; the caller's random number state is restored.
#'
#' @details
#' The null `a_w b_w = a_b b_b` is a smooth surface except where all four paths are 0, where it is singular. Away
#' from that point the likelihood-ratio statistic is referred to chi-square(1), an asymptotic law in the number of
#' clusters `J` (the between-level paths rest on `J` clusters). Near it, and when a level-2 variance is near the
#' boundary, the chi-square(1) law may not hold; no closed-form law is claimed. The function warns when all four
#' free-fit paths are within two standard errors of 0 (class `medfit_warning_twolevel_equal_singular`) and when a
#' level-2 variance at the constrained fit is below 1% of its implied between plus within variance.
#'
#' The guard admits the equality of any two a-then-b chains with the same x, m and y at levels 1 and 2, so a serial
#' `a*d` or `d*b` chain of the same shape is admitted too; only the `a*b` indirect effect of a single mediator has an
#' oracle and a gate here.
#'
#' The constrained fit is never trusted blindly: if it ends at an inadmissible solution (a negative variance at either
#' level, a covariance matrix that is not positive definite, class `medfit_warning_twolevel_inadmissible`), does not
#' converge, or has a lower discrepancy than the free fit, the result is **unresolved** (`statistic` and `p.value`
#' `NA`, `unresolved = TRUE`, the reason in `note`) with a warning, never a likelihood-ratio number. If the fit
#' already carries a nonlinear constraint, or the four paths are not the level-1 and level-2 regressions, the call is
#' refused with class `medfit_error_twolevel_unsupported`; a single-level fit is `medfit_error_twolevel_required`.
#'
#' @return An object of class `c("twolevel_equal_indirect", "htest")`: `statistic` (`LR`, the scale of
#'   [mbco_sem()]), `parameter` (`df = 1`), `p.value` (chi-square(1)), `method`, `data.name`, `n_obs`,
#'   `n_clusters`, `level` (`c("within", "between")`), `indirect` (the two indirect effects of the free fit and of the
#'   constrained fit), `unresolved`, `note`, `near_singular`, and `boot` (`NULL`, or a list with `statistic`,
#'   `p.value`, `n_boot`, `n_valid` and `n_dropped` when `n_boot > 0`).
#'
#' @examples
#' \donttest{
#' d <- data.frame(
#'   cluster = rep(1:30, each = 6), X = rnorm(180), M = rnorm(180), Y = rnorm(180)
#' )
#' fit <- fit_sem(
#'   "level: 1\n M ~ a_w*X\n Y ~ b_w*M + X\nlevel: 2\n M ~ a_b*X\n Y ~ b_b*M + X",
#'   data = d, cluster = "cluster"
#' )
#' twolevel_equal_indirect(fit)
#' }
#'
#' @seealso [mbco_sem()], [fit_sem()], [nie()]
#' @export
twolevel_equal_indirect <- function(object, a_within = "a_w", b_within = "b_w", a_between = "a_b", b_between = "b_b",
                                    n_starts = NULL, control = NULL, n_boot = 0L, seed = NULL) {
  if (!S7::S7_inherits(object, SEMFit)) {
    stop("`object` must be a SEMFit from fit_sem().", call. = FALSE)
  }
  checkmate::assert_string(a_within, min.chars = 1L, .var.name = "a_within")
  checkmate::assert_string(b_within, min.chars = 1L, .var.name = "b_within")
  checkmate::assert_string(a_between, min.chars = 1L, .var.name = "a_between")
  checkmate::assert_string(b_between, min.chars = 1L, .var.name = "b_between")
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  checkmate::assert_count(n_boot, .var.name = "n_boot")
  checkmate::assert_count(seed, null.ok = TRUE, .var.name = "seed")
  fit <- object
  .sem_fiml_refuse(fit, "twolevel_equal_indirect()")
  if (!isTRUE(fit@internals$ram$twolevel)) {
    .twolevel_abort("twolevel_equal_indirect() needs a two-level fit: fit_sem(model with `level:` blocks, cluster = )",
                    "medfit_error_twolevel_required")
  }
  if (!is.null(fit@internals$weights)) {
    stop("twolevel_equal_indirect() is not available for a fit with sampling weights.", call. = FALSE)
  }
  if (!isTRUE(fit@converged)) {
    stop("the fit did not converge, so the statistic is not available: it is the reference the constrained fit is ",
         "measured against.", call. = FALSE)
  }
  if (.sem_has_nonlinear_constraint(fit@internals$constraints)) {
    .twolevel_abort(paste0("twolevel_equal_indirect() needs a fit without a nonlinear constraint (the fit already ",
                           "carries one, such as `a_w*b_w == a_b*b_b`); it is the free fit the equality is tested ",
                           "against"), "medfit_error_twolevel_unsupported")
  }
  paths <- c(a_within, b_within, a_between, b_between)
  tab <- fit@table
  known <- unique(tab$label[tab$free & tab$op == "~" & !is.na(tab$label) & nzchar(tab$label)])
  for (nm in paths) {
    if (!(nm %in% known)) {
      stop(sprintf("'%s' is not a labeled regression path of the fit (labeled regression paths: %s)", nm,
                   if (length(known)) paste(known, collapse = ", ") else "none"), call. = FALSE)
    }
  }
  if (anyDuplicated(paths)) {
    stop("`a_within`, `b_within`, `a_between` and `b_between` must be four different parameters.", call. = FALSE)
  }
  if (!identical(.mbco_twolevel_level(tab, paths[1:2]), "within") ||
        !identical(.mbco_twolevel_level(tab, paths[3:4]), "between")) {
    .twolevel_abort(paste0("twolevel_equal_indirect() compares the within indirect effect (level 1: `a_within`, ",
                           "`b_within`) with the between one (level 2: `a_between`, `b_between`); got the paths at ",
                           "other levels"), "medfit_error_twolevel_unsupported")
  }
  resolved_control <- .sem_resolve_control(control, n_starts, !missing(n_starts) && !is.null(n_starts),
                                           "listwise", null_ok = TRUE)
  n_starts <- resolved_control$n_starts %||% fit@internals$n_starts %||% 5L
  control <- resolved_control$control %||% fit@internals$control %||% list()
  con <- sprintf("%s*%s == %s*%s", a_within, b_within, a_between, b_between)
  est <- stats::coef(fit)
  free_ind <- c(within = est[[a_within]] * est[[b_within]], between = est[[a_between]] * est[[b_between]])
  near_singular <- .tle_near_singular(fit, paths)
  if (near_singular) {
    rlang::warn(paste0("all four paths are within two standard errors of 0: the null a_w*b_w == a_b*b_b is near its ",
                       "singular point (all four paths 0), where the likelihood-ratio statistic is not ",
                       "chi-square(1) and its p-value may not be valid."),
                class = "medfit_warning_twolevel_equal_singular")
  }
  res <- .tle_refit(fit, con, n_starts, control)
  unresolved <- !is.null(res$failure)
  n <- fit@n_obs
  stat <- NA_real_
  note <- ""
  if (unresolved) {
    note <- res$failure
  } else {
    stat <- n * (res$fit$f - fit@f)
    # a refit that beats the free fit by more than rounding is not a nested null: no LR (the free fit is not the
    # global optimum, or the refit is not the constrained model)
    if (stat < -1e-6) {
      unresolved <- TRUE
      note <- sprintf(paste0("the constrained fit has a lower discrepancy than the free fit (by %.3g), so the ",
                             "free fit is not the maximum the test compares against."), -stat)
      stat <- NA_real_
    } else {
      stat <- max(stat, 0)
      .mbco_warn_level2_boundary(res$fit, con)
    }
  }
  if (unresolved) {
    rlang::warn(paste0(note, "\nThe likelihood-ratio statistic is not available (NA)."),
                class = if (isTRUE(res$inadmissible)) "medfit_warning_twolevel_inadmissible" else NULL)
  }
  null_est <- if (is.null(res$fit)) c(within = NA_real_, between = NA_real_) else {
    th <- stats::setNames(res$fit$theta[match(paths, res$fit$ram$par_names)], paths)
    c(within = th[[a_within]] * th[[b_within]], between = th[[a_between]] * th[[b_between]])
  }
  out <- structure(
    list(
      statistic = c(LR = stat),
      parameter = c(df = 1),
      p.value = if (unresolved) NA_real_ else stats::pchisq(stat, df = 1, lower.tail = FALSE),
      method = "Likelihood-ratio test of equal indirect effects across the two levels",
      data.name = sprintf("%s * %s == %s * %s", a_within, b_within, a_between, b_between),
      n_obs = n,
      n_clusters = length(unique(fit@internals$cluster_ids)),
      level = c("within", "between"),
      indirect = list(free = free_ind, null = null_est),
      unresolved = unresolved,
      note = note,
      near_singular = near_singular,
      boot = NULL
    ),
    class = c("twolevel_equal_indirect", "htest")
  )
  if (n_boot > 0L && !unresolved) {
    out$boot <- .tle_bootstrap(fit, res$fit, con, n_starts, control, as.integer(n_boot), seed, stat)
  }
  out
}

#' @export
print.twolevel_equal_indirect <- function(x, ...) {
  NextMethod()
  cat("\nWithin vs between indirect effect: free fit ", format(x$indirect$free[["within"]], digits = 4), " vs ",
      format(x$indirect$free[["between"]], digits = 4), "; clusters = ", x$n_clusters, "\n", sep = "")
  if (x$unresolved) {
    cat("Unresolved: ", x$note, "\n", sep = "")
  }
  if (!is.null(x$boot)) {
    cat("Parametric bootstrap p-value: ", format(x$boot$p.value, digits = 4), " (", x$boot$n_valid, " of ",
        x$boot$n_boot, " replications resolved; ", x$boot$n_dropped,
        " dropped, so the p-value is conditional on admissible refits)\n", sep = "")
  }
  invisible(x)
}

# The constrained refit of a two-level fit with the equality row `con` added: the same sample (the fit's rows with
# their cluster ids), the fit's own optimizer settings, parsed with the levels resolved as `fit_sem()` parses the fit.
# Returns `list(fit =)` for a refit the engine accepted, or `list(failure =, inadmissible =)` for one that did not
# (the solution is inadmissible, the covariance is not positive definite, or the optimizer did not converge): an
# unresolved row, never a likelihood. A model or data error still stops.
.tle_refit <- function(fit, con, n_starts, control, data = NULL, model = fit@model) {
  cluster <- fit@internals$cluster
  refit_data <- if (is.null(data)) {
    d <- fit@data
    d[[cluster]] <- fit@internals$cluster_ids
    d
  } else {
    data
  }
  syntax <- paste0(model, "\n", con)
  parsed <- .sem_twolevel_guard(syntax, refit_data, cluster, information = fit@information, weights = NULL,
                                se_type = "model", missing = "listwise", fixed_x = FALSE, fx_unset = TRUE,
                                meanstructure = TRUE, ms_unset = TRUE)
  r <- tryCatch(
    .sem_fit_syntax(syntax, refit_data, fit@information, n_starts = n_starts, control = control,
                    se_type = "model", parsed = parsed, meanstructure = TRUE, fixed_x = FALSE,
                    factors = fit@internals$factors, cluster = cluster),
    error = function(e) e
  )
  .tle_resolve_null(r, con)
}

.tle_resolve_null <- function(r, con) {
  err <- if (inherits(r, "error")) r
  if (is.null(err)) {
    return(list(fit = r))
  }
  inadmissible <- inherits(err, "medfit_error_twolevel_inadmissible")
  covariance <- inherits(err, "medfit_sem_covariance_error")
  if (inadmissible) {
    reason <- paste(err$improper %||% conditionMessage(err), collapse = "; ")
    return(list(failure = sprintf("the refit with `%s` converged to an inadmissible solution (%s).", con, reason),
                inadmissible = TRUE))
  }
  if (covariance) {
    return(list(failure = sprintf(paste0("the refit with `%s` converged to a solution whose covariance matrix is ",
                                         "not positive definite (%s)."), con, conditionMessage(err)),
                inadmissible = TRUE))
  }
  if (inherits(err, "medfit_error_no_convergence")) {
    return(list(failure = sprintf("the refit with `%s` failed (%s).", con, conditionMessage(err)),
                inadmissible = FALSE))
  }
  stop(err)
}

# Whether all four paths of the free fit are within two standard errors of 0: the null is then near its singular point.
.tle_near_singular <- function(fit, paths) {
  est <- stats::coef(fit)[paths]
  v <- stats::vcov(fit)
  se <- sqrt(diag(v))[paths]
  !anyNA(est) && !anyNA(se) && all(abs(est) < 2 * se)
}

# Parametric bootstrap of the statistic: clustered data of the same sizes drawn from the constrained fit, both models
# refitted. A replication whose free or constrained fit does not resolve is dropped and counted in `n_valid`.
.tle_bootstrap <- function(fit, null_fit, con, n_starts, control, n_boot, seed, observed) {
  cluster <- fit@internals$cluster
  tl <- null_fit$ram
  mom <- .sem_twolevel_implied(tl, unname(null_fit$theta))
  vars <- c(tl$within, tl$between)
  sizes <- as.integer(table(fit@internals$cluster_ids))
  ids <- seq_along(sizes)
  one <- function() {
    u <- MASS::mvrnorm(length(sizes), mom$mu_b, mom$sigma_b)
    cl <- rep(ids, sizes)
    e <- MASS::mvrnorm(length(cl), rep(0, length(tl$within)), mom$sigma_w)
    z <- u[cl, , drop = FALSE]
    z[, seq_along(tl$within)] <- z[, seq_along(tl$within)] + e
    d <- as.data.frame(z)
    names(d) <- vars
    d[[cluster]] <- cl
    free <- tryCatch(suppressWarnings(suppressMessages(
      fit_sem(fit@model, d, cluster = cluster, n_starts = n_starts, control = control))), error = function(e) NULL)
    if (is.null(free)) {
      return(NA_real_)
    }
    res <- tryCatch(suppressWarnings(suppressMessages(.tle_refit(free, con, n_starts, control))),
                    error = function(e) list(failure = "error"))
    if (!is.null(res$failure)) {
      return(NA_real_)
    }
    stat <- free@n_obs * (res$fit$f - free@f)
    if (stat < -1e-6) NA_real_ else max(stat, 0)
  }
  draw <- function() vapply(seq_len(n_boot), function(i) one(), numeric(1))
  stats_b <- if (is.null(seed)) draw() else .sem_with_seed(seed, draw())
  ok <- !is.na(stats_b)
  list(
    statistic = stats_b, n_boot = n_boot, n_valid = sum(ok), n_dropped = sum(!ok),
    p.value = (1 + sum(stats_b[ok] >= observed)) / (sum(ok) + 1)
  )
}
