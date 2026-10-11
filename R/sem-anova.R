# Native SEM engine: the likelihood-ratio test for nested fits, `anova()` on `SEMFit`.
#
# `anova(fit_restricted, fit_full)` compares two fits that were already made; it never refits, so it cannot
# seed a refit from another fit's estimates (the refit trap: starting a restricted fit from the full fit's
# estimates can stop at an infeasible point with diffLL 0, where a clean start gives the true value). The
# fits are measured on the same discrepancy `n_obs * f`, the quantity `mbco_sem()` differences per refit.
#
# Nesting is checked by parameter-table inclusion, a necessary condition and not a proof: both fits must
# use the same observed variables and rows, the restricted fit may free no parameter the other leaves out,
# and its degrees of freedom must be larger. Two models that pass but are not nested in substance (different
# latent structures with the same row labels) are the user's responsibility.

#' @noRd
S7::method(anova, SEMFit) <- function(object, ...) {
  dots <- list(...)
  exprs <- c(list(substitute(object)), as.list(substitute(list(...)))[-1L])
  models <- c(list(object), dots)
  nm <- names(models)
  if (is.null(nm)) {
    nm <- rep("", length(models))
  }
  unnamed <- is.na(nm) | !nzchar(nm)
  nm[unnamed] <- vapply(exprs[unnamed], function(e) paste(deparse(e), collapse = ""), character(1))
  names(models) <- nm
  .sem_anova(models)
}

.sem_anova <- function(models) {
  if (length(models) < 2L) {
    stop("anova() for a SEMFit needs at least two fits: the restricted model and the model it is nested in.",
         call. = FALSE)
  }
  ok <- vapply(models, function(m) S7::S7_inherits(m, SEMFit), logical(1))
  if (!all(ok)) {
    stop("every model passed to anova() must be a SEMFit from fit_sem(); not a SEMFit: ",
         paste(names(models)[!ok], collapse = ", "), call. = FALSE)
  }
  for (i in seq_along(models)) {
    m <- models[[i]]
    if (!is.null(m@internals$weights)) {
      stop(sprintf(paste0("'%s' was fitted with sampling weights: the weighted discrepancy is not a likelihood, ",
                          "so the difference of two of them is not chi-square."), names(models)[i]), call. = FALSE)
    }
    if (!isTRUE(m@converged)) {
      stop(sprintf("'%s' did not converge, so its discrepancy cannot be compared.", names(models)[i]), call. = FALSE)
    }
  }
  # Least restricted first (smallest df), the order lavaan's lavTestLRT() uses; each row is tested against the previous.
  df <- vapply(models, function(m) m@df, numeric(1))
  models <- models[order(df, seq_along(df))]
  df <- sort(df)
  .sem_anova_same_data(models)
  n <- models[[1L]]@n_obs
  rows <- vector("list", length(models))
  rows[[1L]] <- list(df = df[[1L]], chisq = n * models[[1L]]@f, chisq_diff = NA_real_, df_diff = NA_real_, p = NA_real_)
  for (i in seq_along(models)[-1L]) {
    full <- models[[i - 1L]]
    restricted <- models[[i]]
    label <- c(names(models)[i - 1L], names(models)[i])
    if (!(df[[i]] > df[[i - 1L]])) {
      stop(sprintf(paste0("'%s' and '%s' have the same degrees of freedom (%g): neither restricts the other, so ",
                          "there is no likelihood-ratio test."), label[1L], label[2L], df[[i]]), call. = FALSE)
    }
    tested <- .sem_anova_nested(full, restricted, label)
    diff <- n * (restricted@f - full@f)
    if (diff < -1e-6) {
      stop(sprintf(paste0("'%s' has a smaller discrepancy than '%s', which it restricts (difference %.3g): one of ",
                          "the two fits is not at its global optimum, so the statistic is not available."),
                   label[2L], label[1L], diff), call. = FALSE)
    }
    diff <- max(diff, 0)
    .sem_anova_warn_boundary(restricted, tested, label)
    ddf <- df[[i]] - df[[i - 1L]]
    rows[[i]] <- list(df = df[[i]], chisq = n * restricted@f, chisq_diff = diff, df_diff = ddf,
                      p = stats::pchisq(diff, df = ddf, lower.tail = FALSE))
  }
  tab <- data.frame(
    Df = vapply(rows, `[[`, numeric(1), "df"), Chisq = vapply(rows, `[[`, numeric(1), "chisq"),
    `Chisq diff` = vapply(rows, `[[`, numeric(1), "chisq_diff"), `Df diff` = vapply(rows, `[[`, numeric(1), "df_diff"),
    `Pr(>Chisq)` = vapply(rows, `[[`, numeric(1), "p"), row.names = names(models), check.names = FALSE
  )
  structure(tab, heading = c("Likelihood-ratio (chi-square difference) test for SEMFit models\n",
                             sprintf("n = %d; Chisq is n times the minimized discrepancy\n", n)),
            class = c("anova", "data.frame"))
}

# The same observed variables and the same rows, so the discrepancies are on one scale.
.sem_anova_same_data <- function(models) {
  obs <- lapply(models, function(m) sort(m@internals$ram$obs))
  if (!all(vapply(obs[-1L], identical, logical(1), obs[[1L]]))) {
    stop("the models must use the same observed variables: ",
         paste(sprintf("%s (%s)", names(models), vapply(obs, paste, character(1), collapse = ", ")), collapse = "; "),
         call. = FALSE)
  }
  n <- vapply(models, function(m) m@n_obs, integer(1))
  if (length(unique(n)) != 1L) {
    rows <- paste(sprintf("%s: %d", names(models), n), collapse = ", ")
    stop("the models were fitted to different numbers of rows (", rows, "), so their discrepancies are not comparable.",
         call. = FALSE)
  }
  first <- models[[1L]]@data[, obs[[1L]], drop = FALSE]
  for (i in seq_along(models)[-1L]) {
    other <- models[[i]]@data[, obs[[1L]], drop = FALSE]
    if (!isTRUE(all.equal(unname(as.matrix(first)), unname(as.matrix(other)), tolerance = 1e-12))) {
      stop(sprintf("'%s' and '%s' were fitted to different data.", names(models)[1L], names(models)[i]), call. = FALSE)
    }
  }
  invisible(TRUE)
}

# Parameter-table inclusion. `restricted` must free no parameter that `full` leaves out; returns the tested
# parameters: those `full` frees and `restricted` does not, and those in the equality constraints `restricted`
# adds, named as in the parameter vectors.
.sem_anova_nested <- function(full, restricted, label) {
  key <- function(m) {
    tab <- m@table
    paste(tab$lhs, tab$op, tab$rhs)[tab$free]
  }
  extra <- setdiff(key(restricted), key(full))
  if (length(extra)) {
    stop(sprintf(paste0("'%s' is not nested in '%s': it frees parameters the other model does not (%s). ",
                        "Fit the restricted model by constraining or fixing parameters of the larger one."),
                 label[2L], label[1L], paste(extra, collapse = ", ")), call. = FALSE)
  }
  dropped <- setdiff(key(full), key(restricted))
  tab <- full@table
  dropped_labels <- ifelse(nzchar(tab$label) & !is.na(tab$label), tab$label, paste(tab$lhs, tab$op, tab$rhs))[
    paste(tab$lhs, tab$op, tab$rhs) %in% dropped & tab$free
  ]
  c(dropped_labels, .sem_anova_added(full, restricted))
}

# Parameters in the equality constraints that `restricted` has and `full` does not.
.sem_anova_added <- function(full, restricted) {
  text <- function(m) {
    cons <- m@internals$constraints
    if (is.null(cons)) {
      return(character())
    }
    paste(cons$lhs, cons$op, cons$rhs)[cons$op == "=="]
  }
  added <- setdiff(text(restricted), text(full))
  if (!length(added)) {
    return(character())
  }
  cons <- restricted@internals$constraints
  # the `:=` rows stay: an added equality may be written on a defined parameter (`s := a + b` with `s == 0.5`)
  keep <- cons[cons$op == ":=" | (cons$op == "==" & paste(cons$lhs, cons$op, cons$rhs) %in% added), , drop = FALSE]
  rows <- .sem_constraint_rows(keep, restricted@internals$ram)
  idx <- which(colSums(abs(rows$eq$A)) > 0)
  restricted@internals$ram$par_names[idx]
}

# The null on the boundary of the parameter space: an active bound or inequality on a tested parameter at the
# restricted fit (where the null holds) makes the statistic a mixture of chi-squares. Warns as `mbco_sem()` does.
# Only the restricted fit matters: a bound that binds the less restricted fit leaves a null in the interior of
# the parameter space alone (`a < 0.2` with the null `a == 0`), and the statistic stays chi-square.
.sem_anova_warn_boundary <- function(restricted, tested, label) {
  state <- list(active_bounds = restricted@diagnostics$active_bounds, constraints = restricted@internals$constraints,
                ram = restricted@internals$ram, theta = restricted@theta)
  active <- .sem_boundary_active(state, tested)
  if (length(active)) {
    warning(sprintf(paste0("%s is active at '%s': the null lies on the boundary of the parameter space, so the ",
                           "statistic is a mixture of chi-squares, not chi-square(df), and its p-value is not valid."),
                    paste(active, collapse = " and "), label[2L]), call. = FALSE)
  }
  invisible(NULL)
}
