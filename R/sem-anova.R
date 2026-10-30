# Native SEM engine: the likelihood-ratio test for nested fits, `anova()` on `SEMFit`.
#
# `anova(fit_restricted, fit_full)` compares two fits that were already made; it never refits, so it cannot
# seed a refit from another fit's estimates (the refit trap: starting a restricted fit from the full fit's
# estimates can stop at an infeasible point with diffLL 0, where a clean start gives the true value). The
# fits are measured on the same discrepancy `n_obs * f`, the quantity `mbco_sem()` differences per refit.
#
# Nesting is checked by parameter-table inclusion, a necessary condition and not a proof: both fits must
# use the same observed variables and rows, the restricted fit may free no parameter the other leaves out,
# nonzero fixed RAM rows must agree, and its degrees of freedom must be larger. Models that pass but are not nested
# in substance (different latent structures with the same row labels) are the user's responsibility.

#' @noRd
S7::method(anova, SEMFit) <- function(object, ...) {
  dots <- list(...)
  exprs <- c(list(substitute(object)), as.list(substitute(list(...)))[-1L])
  models <- c(list(object), dots)
  for (m in models) .sem_fiml_refuse(m, "anova()")
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
  .sem_check_modeltest(models, "anova()")
  .sem_check_comparable(models)
  # Least restricted first (smallest df), the order lavaan's lavTestLRT() uses; each row is tested against the previous.
  df <- vapply(models, function(m) m@df, numeric(1))
  models <- models[order(df, seq_along(df))]
  df <- sort(df)
  .sem_anova_same_data(models)
  n <- models[[1L]]@n_obs
  rows <- vector("list", length(models))
  rows[[1L]] <- list(df = df[[1L]], chisq = n * models[[1L]]@f, chisq_diff = NA_real_, df_diff = NA_real_, p = NA_real_,
                     p_valid = NA)
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
    p_valid <- .sem_anova_warn_boundary(restricted, tested, label)
    ddf <- df[[i]] - df[[i - 1L]]
    rows[[i]] <- list(df = df[[i]], chisq = n * restricted@f, chisq_diff = diff, df_diff = ddf,
                      p = stats::pchisq(diff, df = ddf, lower.tail = FALSE), p_valid = p_valid)
  }
  tab <- data.frame(
    Df = vapply(rows, `[[`, numeric(1), "df"), Chisq = vapply(rows, `[[`, numeric(1), "chisq"),
    `Chisq diff` = vapply(rows, `[[`, numeric(1), "chisq_diff"), `Df diff` = vapply(rows, `[[`, numeric(1), "df_diff"),
    `Pr(>Chisq)` = vapply(rows, `[[`, numeric(1), "p"), row.names = names(models), check.names = FALSE
  )
  structure(tab, heading = c("Likelihood-ratio (chi-square difference) test for SEMFit models\n",
                             sprintf("n = %d; Chisq is n times the minimized discrepancy\n", n)),
            p_valid = stats::setNames(vapply(rows, `[[`, logical(1), "p_valid"), names(models)),
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

# The parameter table, with the intercepts a covariance-only fit leaves implicit written out. A fit without a mean
# structure is the saturated-mean model: every observed variable has a free intercept, so a mean-structure fit that
# fixes or constrains one of them restricts it (`y ~ 0*1` is one degree of freedom), and a covariance-only fit
# never restricts a mean-structure fit that frees them all (equal degrees of freedom).
.sem_anova_table <- function(m) {
  tab <- m@table
  ram <- m@internals$ram
  if (isTRUE(ram$has_mean)) {
    return(tab)
  }
  extra <- tab[rep(1L, length(ram$obs)), , drop = FALSE]
  extra[] <- lapply(extra, function(col) if (is.character(col)) rep("", length(col)) else rep(NA, length(col)))
  extra$lhs <- ram$obs
  extra$op <- "~1"
  extra$free <- TRUE
  rbind(tab, extra)
}

# Parameter-table inclusion. `restricted` must free no parameter that `full` leaves out; returns the tested
# parameters: those `full` frees and `restricted` does not, and those in the equality constraints `restricted`
# adds, named as in the parameter vectors.
.sem_anova_nested <- function(full, restricted, label) {
  full_tab <- .sem_anova_table(full)
  restricted_tab <- .sem_anova_table(restricted)
  row_key <- function(tab) paste(tab$lhs, tab$op, tab$rhs)
  key <- function(tab) row_key(tab)[tab$free]
  extra <- setdiff(key(restricted_tab), key(full_tab))
  if (length(extra)) {
    stop(sprintf(paste0("'%s' is not nested in '%s': it frees parameters the other model does not (%s). ",
                        "Fit the restricted model by constraining or fixing parameters of the larger one."),
                 label[2L], label[1L], paste(extra, collapse = ", ")), call. = FALSE)
  }
  # A missing RAM row is fixed at zero. An explicit nonzero fixed row on only one side changes the model.
  missing_fixed <- function(a, b) row_key(a)[which(!a$free & a$est != 0 & !row_key(a) %in% row_key(b))]
  changed <- c(missing_fixed(restricted_tab, full_tab), missing_fixed(full_tab, restricted_tab))
  if (length(changed)) {
    stop(sprintf("'%s' is not nested in '%s': nonzero fixed parameters differ (%s).",
                 label[2L], label[1L], paste(changed, collapse = ", ")), call. = FALSE)
  }
  kept <- .sem_anova_kept(full, restricted)
  if (length(kept)) {
    stop(sprintf(paste0("'%s' is not nested in '%s': it does not keep %s. A restricted model must satisfy every ",
                        "constraint and fixed value of the larger one."),
                 label[2L], label[1L], paste(kept, collapse = "; ")), call. = FALSE)
  }
  dropped <- setdiff(key(full_tab), key(restricted_tab))
  tab <- full_tab
  dropped_labels <- ifelse(nzchar(tab$label) & !is.na(tab$label), tab$label, paste(tab$lhs, tab$op, tab$rhs))[
    paste(tab$lhs, tab$op, tab$rhs) %in% dropped & tab$free
  ]
  c(dropped_labels, .sem_anova_added(full, restricted))
}

# What `full` enforces that `restricted` does not keep: fixed values that differ, and constraints the restricted
# model does not imply. A linear equality `a'theta + b = 0` of `full` is implied when it is a combination of the
# restricted model's equalities and of its fixed values (restricted parameters pinned to a value, written in the
# parameter space of `full`); a nonlinear equality or an inequality must appear verbatim. Anything that cannot
# be established is reported, so no p-value rests on an unchecked nesting. Returns the texts not kept.
.sem_anova_kept <- function(full, restricted) {
  ptab <- function(m) {
    tab <- m@table
    name <- ifelse(nzchar(tab$label) & !is.na(tab$label), tab$label, paste0(tab$lhs, tab$op, tab$rhs))
    data.frame(key = paste(tab$lhs, tab$op, tab$rhs), name = name, free = tab$free, est = tab$est,
               stringsAsFactors = FALSE)
  }
  pf <- ptab(full)
  pr <- ptab(restricted)
  both <- merge(pf[!pf$free, c("key", "est")], pr[!pr$free, c("key", "est")], by = "key")
  moved <- both$key[abs(both$est.x - both$est.y) > 1e-8]
  out <- if (length(moved)) paste0("the fixed value of ", moved) else character()
  out <- c(out, .sem_anova_bounds_kept(full, restricted), .sem_anova_ties_kept(full, restricted))
  cf <- full@internals$constraints
  cf <- if (is.null(cf)) cf else cf[cf$op %in% c("==", "<", ">"), , drop = FALSE]
  if (is.null(cf) || !nrow(cf)) {
    return(out)
  }
  cr <- restricted@internals$constraints
  text <- function(cons) if (is.null(cons)) character() else paste(cons$lhs, cons$op, cons$rhs)
  rows_f <- .sem_constraint_rows(full@internals$constraints, full@internals$ram)
  verbatim <- c(rows_f$ineq$text, rows_f$nl$text, rows_f$nli$text)
  miss <- setdiff(verbatim, text(cr))
  out <- c(out, if (length(miss)) paste0("the constraint '", miss, "'"))
  if (!length(rows_f$eq$A)) {
    return(out)
  }
  pnames <- full@internals$ram$par_names
  # restricted knowledge in the parameter space of `full`: its linear equalities, and its fixed parameters
  know_a <- list()
  know_b <- numeric()
  rows_r <- if (is.null(cr)) NULL else .sem_constraint_rows(cr, restricted@internals$ram)
  unknown <- character()
  if (length(rows_r$eq$A)) {
    rn <- restricted@internals$ram$par_names
    for (i in seq_len(nrow(rows_r$eq$A))) {
      nz <- which(abs(rows_r$eq$A[i, ]) > 0)
      if (!all(rn[nz] %in% pnames)) {
        unknown <- c(unknown, rows_r$eq$text[i])
        next
      }
      v <- numeric(length(pnames))
      v[match(rn[nz], pnames)] <- rows_r$eq$A[i, nz]
      know_a[[length(know_a) + 1L]] <- v
      know_b <- c(know_b, rows_r$eq$b[i])
    }
  }
  rfree <- restricted@internals$ram$par_names
  for (p in setdiff(pnames, rfree)) {
    hit <- pr[pr$name == p & !pr$free, , drop = FALSE]
    if (nrow(hit)) {
      v <- numeric(length(pnames))
      v[match(p, pnames)] <- 1
      know_a[[length(know_a) + 1L]] <- v
      know_b <- c(know_b, -hit$est[1L])
    }
  }
  K <- if (length(know_a)) do.call(rbind, know_a) else matrix(0, 0L, length(pnames))
  for (i in seq_len(nrow(rows_f$eq$A))) {
    a <- rows_f$eq$A[i, ]
    ok <- FALSE
    if (nrow(K)) {
      lambda <- tryCatch(qr.solve(t(K), a), error = function(e) NULL)
      ok <- !is.null(lambda) && sqrt(sum((drop(t(K) %*% lambda) - a)^2)) < 1e-6 &&
        abs(sum(lambda * know_b) - rows_f$eq$b[i]) < 1e-6
    }
    if (!ok) {
      out <- c(out, paste0("the constraint '", rows_f$eq$text[i], "'"))
    }
  }
  out
}

# Equalities that repeated labels impose in `full` (`M ~ a*X`, `Y ~ a*M`: one parameter on two rows, which the
# parameter table collapses). The restricted model keeps a tie when its two rows are the same parameter, are
# fixed at equal values, or are equal by its own equality constraints (the row-space test used for constraints,
# in the restricted parameter space). A tied row the restricted model lacks cannot be established and is reported.
.sem_anova_ties_kept <- function(full, restricted) {
  describe <- function(m) {
    tab <- m@table
    name <- ifelse(nzchar(tab$label) & !is.na(tab$label), tab$label, paste0(tab$lhs, tab$op, tab$rhs))
    data.frame(key = paste(tab$lhs, tab$op, tab$rhs), name = name, label = ifelse(is.na(tab$label), "", tab$label),
               free = tab$free, est = tab$est, stringsAsFactors = FALSE)
  }
  pf <- describe(full)
  pr <- describe(restricted)
  groups <- split(pf$key[pf$free & nzchar(pf$label)], pf$label[pf$free & nzchar(pf$label)])
  groups <- groups[lengths(groups) > 1L]
  if (!length(groups)) {
    return(character())
  }
  cr <- restricted@internals$constraints
  rows_r <- if (is.null(cr)) NULL else .sem_constraint_rows(cr, restricted@internals$ram)
  rn <- restricted@internals$ram$par_names
  know <- if (length(rows_r$eq$A)) rows_r$eq$A else matrix(0, 0L, length(rn))
  know_b <- if (length(rows_r$eq$A)) rows_r$eq$b else numeric()
  vec <- function(j) {
    a <- numeric(length(rn))
    if (pr$free[j]) {
      a[match(pr$name[j], rn)] <- 1
      list(a = a, b = 0)
    } else {
      list(a = a, b = pr$est[j])
    }
  }
  out <- character()
  for (label in names(groups)) {
    keys <- groups[[label]]
    idx <- match(keys, pr$key)
    if (anyNA(idx)) {
      out <- c(out, paste0("the shared label '", label, "'"))
      next
    }
    for (k in idx[-1L]) {
      u <- vec(idx[1L])
      v <- vec(k)
      a <- u$a - v$a
      b <- u$b - v$b
      ok <- if (all(a == 0)) {
        abs(b) < 1e-8
      } else if (nrow(know)) {
        lambda <- tryCatch(qr.solve(t(know), a), error = function(e) NULL)
        !is.null(lambda) && sqrt(sum((drop(t(know) %*% lambda) - a)^2)) < 1e-6 && abs(sum(lambda * know_b) - b) < 1e-6
      } else {
        FALSE
      }
      if (!ok) {
        out <- c(out, paste0("the shared label '", label, "'"))
        break
      }
    }
  }
  unique(out)
}

# Bounds of `full` (`lower(0)*x`, and single-label inequalities such as `a > 0.1`, which the parser stores as
# bounds in the parameter table, not as constraint rows). A restricted model keeps a bound when its estimate or
# fixed value lies inside it and, for a parameter it leaves free, its own bound is at least as tight.
.sem_anova_bounds_kept <- function(full, restricted) {
  tab <- function(m) {
    pt <- m@internals$partable
    data.frame(key = paste(pt$lhs, pt$op, pt$rhs), free = m@table$free, est = m@table$est,
               lower = pt$lower, upper = pt$upper, stringsAsFactors = FALSE)
  }
  pf <- tab(full)
  pr <- tab(restricted)
  lo <- function(x) ifelse(is.na(x), -Inf, x)
  up <- function(x) ifelse(is.na(x), Inf, x)
  tol <- 1e-8
  out <- character()
  for (i in which(!is.na(pf$lower) | !is.na(pf$upper))) {
    j <- match(pf$key[i], pr$key)
    if (is.na(j)) {
      next
    }
    inside <- pr$est[j] >= lo(pf$lower[i]) - tol && pr$est[j] <= up(pf$upper[i]) + tol
    tight <- !pr$free[j] || (lo(pr$lower[j]) >= lo(pf$lower[i]) && up(pr$upper[j]) <= up(pf$upper[i]))
    if (!inside || !tight) {
      out <- c(out, paste0("the bound on ", pf$key[i]))
    }
  }
  out
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
# Returns whether the chi-square p-value is valid (FALSE when the null is on the boundary), so `anova()` can record
# it in the `p_valid` attribute; the warning stays.
.sem_anova_warn_boundary <- function(restricted, tested, label) {
  state <- list(active_bounds = restricted@diagnostics$active_bounds, constraints = restricted@internals$constraints,
                ram = restricted@internals$ram, theta = restricted@theta)
  active <- .sem_boundary_active(state, tested)
  if (length(active)) {
    warning(sprintf(paste0("%s is active at '%s': the null lies on the boundary of the parameter space, so the ",
                           "statistic is a mixture of chi-squares, not chi-square(df), and its p-value is not valid."),
                    paste(active, collapse = " and "), label[2L]), call. = FALSE)
  }
  length(active) == 0L
}

# Model-test validity for a product term (0.10.0 plan U6, amendment section 2a). The global chi-square of a model
# with a product is invalid in two cases, both read off the completed parameter table:
#   (i)  a factor of a product is itself a regression target (`m` in `x:m`): the product is a function of `m`, but the
#        model treats it as exogenous and so implies Cov(e_m, x:m) = 0, which the data violate;
#   (ii) the variance/covariance block of the exogenous observed variables (every product column included) is
#        restricted: a variance or covariance is fixed, labeled, bounded, or missing (the pairing rule of
#        `.sem_complete()` leaves a covariance out when either variable has a `~~` statement). The normal-theory test
#        is then miscalibrated for the non-normal product. A row flagged `fixed_x` is not a restriction: it sits at
#        its sample moment, which is the unrestricted ML value.
# Returns NULL when the model has no product or neither case holds; otherwise a list with the product names and one
# phrase per case. The result is stored in `fit@internals$ram$modeltest`, so a later `anova()`, `mbco_sem()` or
# `glance()` reads the verdict made at fit time.
.sem_product_modeltest <- function(tab) {
  prods <- unique(tab$rhs[tab$op == "~" & grepl(":", tab$rhs, fixed = TRUE)])
  if (!length(prods)) {
    return(NULL)
  }
  r <- .sem_roles(tab)
  # an indicator of a latent variable is generated by it, so it is endogenous too
  endo <- c(r$ov_y, r$lv_y, r$ind)
  endogenous <- character()
  for (nm in prods) {
    hit <- intersect(strsplit(nm, ":", fixed = TRUE)[[1L]], endo)
    if (length(hit)) {
      endogenous <- c(endogenous, sprintf("the product '%s' has an endogenous factor ('%s')", nm, hit[1L]))
    }
  }
  restricted <- .sem_exo_block_restriction(tab, r$ov_x)
  if (!length(endogenous) && !length(restricted)) {
    return(NULL)
  }
  list(products = prods, endogenous = endogenous, restricted = restricted)
}

# The first restriction found in the (co)variance block of the exogenous observed variables, as a phrase, or
# character(0). Reads every unordered pair, the diagonal included.
.sem_exo_block_restriction <- function(tab, ov_x) {
  cov_rows <- tab[tab$op == "~~", , drop = FALSE]
  fx <- if ("fixed_x" %in% names(tab)) cov_rows$fixed_x %in% TRUE else rep(FALSE, nrow(cov_rows))
  for (i in seq_along(ov_x)) {
    for (j in i:length(ov_x)) {
      a <- ov_x[i]
      b <- ov_x[j]
      term <- sprintf("%s ~~ %s", a, b)
      k <- which((cov_rows$lhs == a & cov_rows$rhs == b) | (cov_rows$lhs == b & cov_rows$rhs == a))[1L]
      if (is.na(k)) {
        return(paste0("the exogenous (co)variance '", term, "' is missing (the pairing rule leaves a covariance out ",
                      "once either variable has a '~~' statement)"))
      }
      if (fx[k]) {
        next
      }
      why <- if (!is.na(cov_rows$fixed[k])) {
        "fixed"
      } else if (!is.na(cov_rows$label[k]) && nzchar(cov_rows$label[k])) {
        "labeled"
      } else if (is.finite(cov_rows$lower[k]) || is.finite(cov_rows$upper[k])) {
        "bounded"
      }
      if (!is.null(why)) {
        return(sprintf("the exogenous (co)variance '%s' is %s", term, why))
      }
    }
  }
  character()
}

# The reason a verdict of `.sem_product_modeltest()` makes the model test unavailable (one phrase per cause, joined),
# or NULL when it is available. The one place the string is built: the fit-time warning, `glance()`, `summary()` and
# the refusals all quote it.
.sem_modeltest_text <- function(mt) {
  if (is.null(mt) || !(length(mt$endogenous) || length(mt$restricted))) {
    return(NULL)
  }
  paste(c(mt$endogenous, mt$restricted), collapse = "; ")
}

.sem_modeltest_reason <- function(fit) {
  if (.sem_fiml_is(fit)) return(.sem_fiml_modeltest_note())
  .sem_modeltest_text(fit@internals$ram$modeltest)
}

# Chi-square (n times the minimized discrepancy) of a fit: the internal accessor that bypasses the model-test NA
# policy. `glance()` calls it once its own checks (sampling weights, invalid model test) have passed; the gates in
# tests/sim and the population tests call it directly to read the statistic that `glance()` reports as NA for a model
# with a product of an endogenous variable, to show that it is far from chi-square there. It is not exported and not
# for analysis: for such a fit the number is not a valid test statistic. NA for a fit with sampling weights.
.sem_chisq <- function(fit) {
  if (!is.null(fit@internals$weights)) {
    return(NA_real_)
  }
  chisq <- fit@n_obs * fit@f
  if (chisq < 0 && chisq > -1e-8) chisq <- 0 # a saturated fit's roundoff
  chisq
}
