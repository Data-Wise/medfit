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
#' The constrained surface has sign twins: flipping the signs of the within pair \eqn{(a_w, b_w)}{(a_w, b_w)}, the
#' between pair \eqn{(a_b, b_b)}{(a_b, b_b)} or both leaves the equality satisfied, at a worse likelihood. The
#' optimizer's "the starts disagree" warning is not raised when every disagreeing accepted start is such a twin of the
#' kept fit; the lowest-discrepancy start is kept. Any other disagreement among the starts, and every other
#' optimizer warning, is signaled as usual.
#'
#' After the refit the pair-sign twins of the kept fit are tried as well (a twin certificate): each flip of a pair
#' with no zero is fitted once from the kept estimates with that flip, and the lowest discrepancy is kept. It is a local
#' search of up to three single-start solves, not a proof of a global optimum: a twin refit that fails is skipped, and
#' the search runs at every `n_starts`, so a worse twin is not kept with `n_starts = 1`, where no second start is
#' compared. It changes the statistic only when a twin ends lower. A twin that ends at an inadmissible solution (a
#' level-2 variance on its boundary) or with a covariance matrix that is not positive definite, below the kept
#' discrepancy, makes the result unresolved, as it does with more starts. When the better optimum has a level-2
#' variance on its boundary the result is therefore unresolved or, with `n_starts = 1` in very small samples (about 12
#' clusters), a non-global optimum, as before the certificate.
#' The row allows eight sign patterns; flipping pairs together reaches the four of the kept fit's orbit. The other
#' orbit does hold local optima: a per-elimination oracle found local optima in both orbits in 30 of 35 small cells
#' (closest gap 0.02 LR). The kept orbit still won every time that was tested (no win from the other orbit in 84 stress
#' cells, 114 QA cells with an all-orthant oracle and 715 constrained fits from signed starts), so the coverage of the
#' other orbit rests on the free-fit-pattern and all-positive default starts: evidence, not a proof. The pair flip is
#' a symmetry of the constraint, not of the likelihood, so the twins are separate local optima. Cost: a call takes
#' about 3 to 4 times as long at `n_starts = 1`, about twice at the default and about 1.3 times at 30 starts; a
#' bootstrap replicate costs about 2.5 times the engine fits.
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
#'   constrained fit), `unresolved`, `note`, `near_singular`, `twin`, and `boot` (`NULL`, or a list with `statistic`,
#'   `p.value`, `n_boot`, `n_valid` and `n_dropped` when `n_boot > 0`). `twin` records what the twin certificate did,
#'   for resolved and unresolved results: `tried` (a twin refit was attempted), `replaced` (a twin replaced the kept
#'   fit), `flipped` (read from the signs of the adopted fit's four path estimates against the kept fit's, not from
#'   the start that produced it: `"within"` or `"between"` when both paths of that pair changed sign, `"other"` once
#'   for any other sign change, including a path that reaches or leaves zero, and empty when no sign changed, as when
#'   the twin is another optimum in the kept fit's sign pattern), `f_gain` (the kept discrepancy minus the adopted
#'   one, 0 if none; the statistic drops by `n_obs * f_gain`) and `unresolved` (a better inadmissible or
#'   covariance-stage twin made the result unresolved). `print()` does not show it.
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' id <- rep(1:40, each = 6)
#' x <- stats::rnorm(40)[id] + stats::rnorm(240)
#' m <- 0.5 * x + stats::rnorm(40)[id] + stats::rnorm(240)
#' y <- 0.4 * m + 0.2 * x + stats::rnorm(40)[id] + stats::rnorm(240)
#' d <- data.frame(cluster = id, X = x, M = m, Y = y)
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
  res <- .tle_refit(fit, con, n_starts, control, twin_paths = paths)
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
  null_est <- if (is.null(res$fit)) {
    c(within = NA_real_, between = NA_real_)
  } else {
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
      twin = res$twin,
      boot = NULL
    ),
    class = c("twolevel_equal_indirect", "htest")
  )
  if (n_boot > 0L && !unresolved) {
    out$boot <- .tle_bootstrap(fit, res$fit, con, n_starts, control, as.integer(n_boot), seed, stat, twin_paths = paths)
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
.tle_refit <- function(fit, con, n_starts, control, data = NULL, model = fit@model, twin_paths = NULL) {
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
  # The warnings are held until the fit is known: the optimizer's "starts disagree" warning is dropped when every
  # disagreeing start is a sign twin of the kept optimum (#504); any other warning is signalled again unchanged.
  held <- list()
  r <- withCallingHandlers(
    tryCatch(
      .sem_fit_syntax(syntax, refit_data, fit@information, n_starts = n_starts, control = control,
                      se_type = "model", parsed = parsed, meanstructure = TRUE, fixed_x = FALSE,
                      factors = fit@internals$factors, cluster = cluster),
      error = function(e) e
    ),
    warning = function(w) {
      held[[length(held) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  .tle_resignal(held, r, twin_paths)
  # the twin certificate (#504): one start from each pair-sign twin of the kept optimum, so a worse twin is not kept
  # even when no start visited the better one (`n_starts = 1`); a better twin replaces the kept fit
  twin <- .tle_twin_record()
  if (!inherits(r, "error") && !is.null(twin_paths)) {
    r <- .tle_twin_certificate(r, parsed, syntax, refit_data, fit, control, cluster, twin_paths)
    twin <- attr(r, "twin") %||% twin
    attr(r, "twin") <- NULL
  }
  res <- .tle_resolve_null(r, con)
  res$twin <- twin
  res
}

# What the twin certificate did (the `twin` element of the result): `tried` is whether a twin refit was attempted,
# `replaced` whether a twin replaced the kept fit, `flipped` the pairs ("within", "between") that twin flipped, `f_gain`
# the kept discrepancy minus the adopted one (0 when none), `unresolved` whether a better inadmissible or
# covariance-stage twin made the result unresolved.
.tle_twin_record <- function(tried = FALSE, replaced = FALSE, flipped = character(), f_gain = 0, unresolved = FALSE) {
  list(tried = tried, replaced = replaced, flipped = flipped, f_gain = f_gain, unresolved = unresolved)
}

# The discrepancy of a twin refit that ended in an error the result treats as unresolved (an inadmissible solution or a
# covariance that is not positive definite): the condition carries the fit, so a better one can be told from a worse
# one. NULL for any other error (a refit that did not converge has no discrepancy to compare).
.tle_twin_error_f <- function(e) {
  if (inherits(e, "medfit_error_twolevel_inadmissible")) {
    e$fit$f
  } else if (inherits(e, "medfit_sem_covariance_error")) {
    e$partial$f
  }
}

# Signals the held warnings of the fit `r` again, unchanged, except the optimizer's "starts disagree" warning when every
# disagreeing accepted start of `r` is a sign twin of its kept optimum (#504, `.tle_twin_explained()`).
.tle_resignal <- function(held, r, twin_paths) {
  explained <- !inherits(r, "error") && !is.null(twin_paths) &&
    .tle_twin_explained(r$attempts, unname(r$theta), r$f, match(twin_paths, r$ram$par_names))
  for (w in held) {
    if (!(explained && grepl("^the starts disagree", conditionMessage(w)))) {
      warning(w)
    }
  }
}

# The twin certificate of the constrained refit `r` (#504): the pair-sign twins of the kept optimum (each level's pair
# (a, b) flipped together, as `.tle_twin_explained()` defines a twin; a pair with a zero is not flipped) are each fitted
# once, from the kept estimates with that flip, and the lowest discrepancy is kept. The twins share the row
# a_w*b_w == a_b*b_b with the kept optimum, so a twin that ends lower is a better optimum of the same constrained
# model. It is a local search of up to three single-start solves, not a proof of a global optimum. A twin refit that
# errors or does not converge is skipped; a twin that does not beat the kept discrepancy by more than the spread
# tolerance leaves the kept fit unchanged, so the statistic is unchanged wherever the kept fit was already the best.
# A twin that ends inadmissible (a boundary variance) or with a covariance that is not positive definite, at a
# discrepancy below the best accepted fit, makes the refit unresolved, as such a start does with more starts: its
# condition is returned in place of a fit. The returned object carries the record of what was done (attribute `twin`).
# The warnings of an adopted twin are signalled through the same twin filter as the kept fit's; those of a rejected
# twin are dropped.
# The start is the kept estimates of the rows the user wrote (regressions and any written covariance or intercept); the
# engine's default start is kept for the rows it completes (variances, level-2 means).
.tle_twin_certificate <- function(r, parsed, syntax, data, fit, control, cluster, twin_paths) {
  idx <- match(twin_paths, r$ram$par_names)
  theta <- unname(r$theta)
  if (anyNA(idx) || length(idx) != 4L) {
    attr(r, "twin") <- .tle_twin_record()
    return(r)
  }
  pairs <- Filter(function(p) all(theta[p] != 0), list(within = idx[1:2], between = idx[3:4]))
  best <- r
  best_w <- list()
  replaced <- FALSE
  bad <- NULL
  bad_f <- Inf
  tried <- FALSE
  for (mask in seq_len(2L^length(pairs) - 1L)) {
    pick <- bitwAnd(mask, 2L^(seq_along(pairs) - 1L)) > 0L
    flip <- unlist(pairs[pick], use.names = FALSE)
    start <- theta
    start[flip] <- -start[flip]
    held <- list()
    tried <- TRUE
    twin <- withCallingHandlers(
      tryCatch(
        .sem_fit_syntax(syntax, data, fit@information, n_starts = 1L, control = control, se_type = "model",
                        parsed = .tle_start_parsed(parsed, r, start), meanstructure = TRUE, fixed_x = FALSE,
                        factors = fit@internals$factors, cluster = cluster),
        error = function(e) e
      ),
      warning = function(w) {
        held[[length(held) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    )
    if (inherits(twin, "error")) {
      f_bad <- .tle_twin_error_f(twin)
      if (!is.null(f_bad) && f_bad < bad_f) {
        bad <- twin
        bad_f <- f_bad
      }
    } else if (twin$f < best$f - .sem_spread_tol) {
      best <- twin
      best_w <- held
      replaced <- TRUE
    }
  }
  if (!is.null(bad) && bad_f < best$f - .sem_spread_tol) {
    attr(bad, "twin") <- .tle_twin_record(tried = TRUE, unresolved = TRUE)
    return(bad)
  }
  .tle_resignal(best_w, best, twin_paths)
  flipped <- if (replaced) {
    .tle_flipped(theta[idx], unname(best$theta)[match(twin_paths, best$ram$par_names)])
  } else {
    character()
  }
  attr(best, "twin") <- .tle_twin_record(tried = tried, replaced = replaced, flipped = flipped, f_gain = r$f - best$f)
  best
}

# The sign changes between the kept fit and the adopted twin at the four path estimates `kept` and `adopted` (a_within,
# b_within, a_between, b_between), read from the fits and not from the start that produced the twin (a start with one
# pair flipped can end at the other pair's twin): "within" or "between" when both elements of that pair changed sign,
# and "other" once when an element changed sign (or reached or left zero) outside a whole-pair flip. Empty when the
# signs are the same (the twin is another optimum in the kept fit's orthant).
.tle_flipped <- function(kept, adopted) {
  changed <- sign(kept) != sign(adopted)
  whole <- c(within = all(changed[1:2]), between = all(changed[3:4]))
  partial <- c(changed[1:2], changed[3:4])[!rep(whole, each = 2L)]
  c(names(whole)[whole], if (any(partial)) "other")
}

# `parsed` with the start value of every row the user wrote set to the matching entry of `start` (a theta vector of the
# fit `r`): the rows are matched by lhs, op, rhs and level, a covariance in either order. Rows are never added, so the
# completed model is the one `parsed` already describes; a fixed row keeps its value.
.tle_start_parsed <- function(parsed, r, start) {
  p <- parsed$parameters
  key <- function(lhs, op, rhs, level) {
    paste(ifelse(op == "~~" & lhs > rhs, rhs, lhs), op, ifelse(op == "~~" & lhs > rhs, lhs, rhs), level)
  }
  tab <- r$table
  tab_key <- key(tab$lhs, tab$op, tab$rhs, tab$level)
  hit <- match(key(p$lhs, p$op, p$rhs, p$level), tab_key)
  ok <- !is.na(hit) & is.na(p$fixed)
  ok[ok] <- !is.na(r$par_map[hit[ok]])
  p$start[ok] <- start[r$par_map[hit[ok]]]
  parsed$parameters <- p
  parsed
}

# Whether every accepted start that missed the kept optimum (discrepancy `f`, estimate `theta`) is a sign twin of it
# (#504). `idx` holds the positions of a_within, b_within, a_between, b_between. The row a_w*b_w == a_b*b_b is
# unchanged when a level's pair (a, b) changes sign together, so the constrained surface has up to four optima that
# differ in the two pair signs: a disagreeing start is explained when its signs are the kept optimum's with one or
# both pairs flipped. A disagreement with the kept optimum's own signs, with a mixed sign pattern or with a zero
# among the four paths is a genuine second optimum and is not explained.
.tle_twin_explained <- function(attempts, theta, f, idx) {
  if (anyNA(idx) || length(idx) != 4L) {
    return(FALSE)
  }
  kept <- sign(theta[idx])
  for (a in attempts) {
    if (!isTRUE(a$accepted) || abs(a$f - f) <= .sem_spread_tol) {
      next
    }
    sg <- sign(a$theta[idx])
    if (anyNA(sg) || any(sg == 0) || any(kept == 0)) {
      return(FALSE)
    }
    rel <- sg * kept
    pair_ok <- rel[1L] == rel[2L] && rel[3L] == rel[4L]
    if (!pair_ok || all(rel == 1)) {
      return(FALSE)
    }
  }
  TRUE
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
.tle_bootstrap <- function(fit, null_fit, con, n_starts, control, n_boot, seed, observed, twin_paths = NULL) {
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
    free <- tryCatch(
      suppressWarnings(suppressMessages(
        fit_sem(fit@model, d, cluster = cluster, n_starts = n_starts, control = control)
      )),
      error = function(e) NULL
    )
    if (is.null(free)) {
      return(NA_real_)
    }
    res <- tryCatch(
      suppressWarnings(suppressMessages(.tle_refit(free, con, n_starts, control, twin_paths = twin_paths))),
      error = function(e) list(failure = "error")
    )
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
