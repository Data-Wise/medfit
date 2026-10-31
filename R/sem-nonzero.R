# Nonzero-product searches. Sign coverage is evidence about local solves, never global optimality.
.sem_nonzero_product <- function(constraints, ram) {
  no <- function(reason) list(supported = FALSE, reason = reason)
  rows <- which(constraints$op %in% c("==", "<", ">"))
  defs <- constraints[constraints$op == ":=", , drop = FALSE]
  defs <- .sem_defs(stats::setNames(defs$rhs, defs$lhs))
  products <- list()
  for (i in rows[constraints$op[rows] == "=="]) {
    lhs <- .sem_expr_subst(.sem_expr_parse(constraints$lhs[i]), defs)
    rhs <- .sem_expr_subst(.sem_expr_parse(constraints$rhs[i]), defs)
    value <- .sem_constant_value(rhs)
    if (!is.finite(value)) {
      value <- .sem_constant_value(lhs)
      lhs <- rhs
    }
    if (!is.finite(value) || value == 0) next
    labels <- .sem_product_factors(lhs)
    if (length(labels) != 2L || anyDuplicated(labels) || !all(labels %in% ram$par_names)) next
    coefficient <- .sem_expr_value(lhs, stats::setNames(rep(1, 2L), labels))
    ratio <- value / coefficient
    if (!is.finite(ratio) || ratio == 0) next
    used_elsewhere <- vapply(setdiff(rows, i), function(j) {
      tree <- .sem_expr_subst(.sem_expr_parse(paste0("(", constraints$lhs[j], ")-(",
                                                     constraints$rhs[j], ")")), defs)
      any(all.vars(tree) %in% labels)
    }, TRUE)
    if (any(used_elsewhere)) return(no("coupled_constraint"))
    products[[length(products) + 1L]] <- list(supported = TRUE, reason = "two_sign_branches", row = i,
                                              labels = labels, idx = match(labels, ram$par_names),
                                              coefficient = coefficient, target = value, ratio = ratio)
  }
  if (length(products) > 1L) return(no("multiple_product_equalities"))
  if (length(products)) return(products[[1L]])
  no("unsupported_constraint_shape")
}

.sem_reference_residual <- function(theta, spec, reference = NULL, context = NULL) {
  residual <- spec$coefficient * prod(theta[spec$labels]) - spec$target
  out <- list(schema_version = 1L, residual = unname(residual), se_reference = NA_real_,
              standardized = NA_real_, absolute = NA_real_, reason = "reference_covariance_unavailable")
  if (is.null(reference)) return(out)
  if (is.null(context) || !identical(reference$context, context)) {
    out$reason <- "reference_context_mismatch"
    return(out)
  }
  if (!is.numeric(reference$theta) || any(!is.finite(reference$theta)) ||
        !all(spec$labels %in% names(reference$theta)) ||
        !is.matrix(reference$vcov) || !identical(rownames(reference$vcov), names(reference$theta)) ||
        !identical(colnames(reference$vcov), names(reference$theta)) || any(!is.finite(reference$vcov)) ||
        !isTRUE(isSymmetric(reference$vcov))) {
    out$reason <- "reference_covariance_invalid"
    return(out)
  }
  covariance_scale <- max(abs(reference$vcov))
  if (covariance_scale > 0 &&
        min(eigen(reference$vcov / covariance_scale, symmetric = TRUE, only.values = TRUE)$values) < -1e-10) {
    out$reason <- "reference_covariance_invalid"
    return(out)
  }
  g <- stats::setNames(numeric(length(reference$theta)), names(reference$theta))
  g[spec$labels] <- spec$coefficient * rev(reference$theta[spec$labels])
  variance <- drop(crossprod(g, reference$vcov %*% g))
  if (!is.finite(variance) || variance <= 0) {
    out$reason <- "reference_directional_variance_invalid"
    return(out)
  }
  out$se_reference <- sqrt(variance)
  out$standardized <- out$residual / out$se_reference
  out$absolute <- abs(out$standardized)
  out$reason <- "available"
  out$reference <- reference[c("id", "context", "information", "se_type")]
  out
}

.sem_sign_bounds <- function(spec, lb, ub, sign) {
  signs <- c(sign, sign * sign(spec$ratio))
  for (j in seq_along(spec$idx)) {
    k <- spec$idx[j]
    if (signs[j] > 0) lb[k] <- max(lb[k], 0) else ub[k] <- min(ub[k], 0)
  }
  empty <- any(lb > ub) || any(vapply(seq_along(spec$idx), function(j) {
    k <- spec$idx[j]
    if (signs[j] > 0) ub[k] <= 0 else lb[k] >= 0
  }, TRUE))
  if (!empty) {
    lo <- ifelse(signs > 0, lb[spec$idx], -ub[spec$idx])
    hi <- ifelse(signs > 0, ub[spec$idx], -lb[spec$idx])
    log_ratio <- log(abs(spec$ratio))
    log_lo <- sum(log(lo))
    log_hi <- sum(log(hi))
    margin <- 16 * .Machine$double.eps * max(1, abs(log_ratio))
    empty <- log_ratio < log_lo - margin || log_ratio > log_hi + margin
  }
  list(lower = lb, upper = ub, signs = signs, empty = empty)
}

.sem_optimize_signs <- function(ram, smp, start, lb, ub, n_starts, control, constraints, spec) {
  branches <- vector("list", 2L)
  fits <- vector("list", 2L)
  for (i in 1:2) {
    sign <- c(1, -1)[i]
    box <- .sem_sign_bounds(spec, lb, ub, sign)
    record <- list(sign = sign, signs = box$signs, lower = box$lower, upper = box$upper)
    if (box$empty) {
      branches[[i]] <- c(record, list(state = "proved_empty", reason = "product_bound_contradiction"))
      next
    }
    initial <- start
    initial[spec$idx[1L]] <- sign * max(abs(start[spec$idx[1L]]), sqrt(abs(spec$ratio)))
    initial[spec$idx[2L]] <- spec$ratio / initial[spec$idx[1L]]
    captured <- .sem_capture_outcome(.sem_optimize(ram, smp, initial, box$lower, box$upper,
                                                   n_starts, control, constraints = constraints))
    if (!is.null(captured$error)) {
      branches[[i]] <- c(record, list(state = "unresolved", condition = captured$error,
                                      notices = captured$notices))
      next
    }
    fit <- captured$value
    fits[[i]] <- fit
    branches[[i]] <- c(record, list(state = "accepted", theta = fit$theta, f = fit$f,
                                    optimum = fit$optimum, notices = captured$notices,
                                    gate = list(accepted = TRUE, status = fit$status, decrement = fit$decrement),
                                    effective_lower = fit$effective_lower,
                                    attempts = lapply(seq_along(fit$attempts), function(j) {
                                      c(fit$attempts[[j]][c("accepted", "status", "decrement", "f")],
                                        list(source = if (j <= fit$optimum$n_starts) "start" else "reference"))
                                    })))
  }
  states <- vapply(branches, `[[`, "", "state")
  evidence <- list(schema_version = 1L, spec = spec, original_bounds = list(lower = lb, upper = ub),
                   coverage = if (any(states == "unresolved") || all(states == "proved_empty")) {
                     "unresolved"
                   } else {
                     "charted"
                   }, reason = "two_sign_branches", branches = branches)
  if (evidence$coverage == "unresolved") {
    err <- structure(list(message = "nonzero-product search incomplete: a required sign branch is unresolved or empty",
                          call = NULL, search_evidence = evidence),
                     class = c("medfit_error_no_convergence", "error", "condition"))
    stop(err)
  }
  accepted <- which(states == "accepted")
  win <- accepted[which.min(vapply(fits[accepted], `[[`, 0, "f"))]
  fit <- fits[[win]]
  for (b in branches[accepted]) .sem_replay_notices(b$notices)
  evidence$selected <- win
  evidence$attempt_counts <- list(
    n_starts = sum(vapply(fits[accepted], function(f) f$optimum$n_starts, 0L)),
    n_accepted = sum(vapply(fits[accepted], function(f) f$optimum$n_accepted, 0L)),
    synthetic = sum(vapply(fits[accepted], function(f) length(f$attempts) - f$optimum$n_starts, 0L))
  )
  fvals <- unlist(lapply(fits[accepted], function(f) {
    vapply(Filter(function(a) isTRUE(a$accepted), f$attempts), `[[`, 0, "f")
  }))
  spread <- if (length(fvals) > 1L) diff(range(fvals)) else NA_real_
  fit$optimum <- list(n_starts = evidence$attempt_counts$n_starts,
                      n_accepted = evidence$attempt_counts$n_accepted, best_of = TRUE,
                      # Branch-specific feasible references do not provide a whole-domain lower bound.
                      certified = FALSE, spread = spread,
                      status = if (length(fvals) == 1L) {
                        "single"
                      } else if (spread > .sem_spread_tol) {
                        "disagreed"
                      } else {
                        "agreed"
                      })
  if (is.finite(spread) && spread > .sem_spread_tol) {
    warning("the sign-branch starts disagree; the lowest accepted discrepancy was kept, not a global certificate",
            call. = FALSE)
  }
  fit$search_evidence <- evidence
  fit
}

# Reconstruct the actual user domain from the canonical completed parameter table, not the sidecar.
.sem_search_domain <- function(out) {
  names <- out$ram$par_names
  stopifnot(!anyDuplicated(names), length(names) == out$ram$q,
            nrow(out$partable) == length(out$par_map))
  bound <- function(column, default) {
    values <- vapply(seq_along(names), function(k) {
      x <- unique(out$partable[[column]][which(out$par_map == k)])
      x <- x[!is.na(x)]
      stopifnot(length(x) <= 1L)
      if (length(x)) x else default
    }, 0)
    stats::setNames(values, names)
  }
  list(lower = bound("lower", -Inf), upper = bound("upper", Inf))
}

.sem_search_context <- function(out) {
  rlang::hash(list(data = out$data, weights = out$weights, constraints = out$constraints,
                   parameters = out$ram, domain = .sem_search_domain(out), fixed_x = out$fixed_x,
                   has_mean = out$ram$has_mean, information = out$information, se_type = out$se_type,
                   n_starts = out$n_starts, control = out$control))
}

.sem_search_attempts <- function(branch) {
  attempts <- branch$attempts
  stopifnot(is.list(attempts), length(attempts) > 0L, is.list(branch$optimum), is.list(branch$gate))
  for (a in attempts) {
    stopifnot(is.logical(a$accepted), length(a$accepted) == 1L, !is.na(a$accepted),
              length(a$source) == 1L, a$source %in% c("start", "reference"))
    if (a$accepted) {
      stopifnot(length(a$f) == 1L, is.finite(a$f), length(a$status) == 1L, a$status %in% .sem_ok_status,
                length(a$decrement) == 1L, is.finite(a$decrement),
                a$decrement >= 0, a$decrement <= .sem_stat_tol)
    }
  }
  source <- vapply(attempts, `[[`, "", "source")
  accepted <- vapply(attempts, `[[`, TRUE, "accepted")
  counts <- list(n_starts = sum(source == "start"), n_accepted = sum(accepted & source == "start"),
                 synthetic = sum(source == "reference"))
  values <- vapply(attempts[accepted], `[[`, 0, "f")
  stopifnot(length(values) > 0L, counts$n_starts > 0L, counts$synthetic <= 1L,
            identical(branch$optimum$n_starts, counts$n_starts),
            identical(branch$optimum$n_accepted, counts$n_accepted), isTRUE(branch$optimum$best_of),
            is.logical(branch$optimum$certified), length(branch$optimum$certified) == 1L,
            !is.na(branch$optimum$certified), identical(branch$f, min(values)),
            isTRUE(branch$gate$accepted))
  spread <- if (length(values) > 1L) diff(range(values)) else NA_real_
  status <- if (branch$optimum$certified) {
    "certified"
  } else if (length(values) == 1L) {
    "single"
  } else if (spread > .sem_spread_tol) {
    "disagreed"
  } else {
    "agreed"
  }
  stopifnot(identical(branch$optimum$spread, spread), identical(branch$optimum$status, status),
            any(vapply(attempts[accepted], function(a) {
              identical(a$f, branch$f) && identical(a$status, branch$gate$status) &&
                identical(a$decrement, branch$gate$decrement)
            }, TRUE)))
  list(counts = counts, values = values)
}

.sem_validate_search <- function(out) {
  e <- out$search_evidence
  if (is.null(e)) return(invisible(TRUE))
  valid <- tryCatch({
    stopifnot(identical(e$schema_version, 1L), identical(e$context, .sem_search_context(out)))
    spec <- .sem_nonzero_product(out$constraints, out$ram)
    if (!spec$supported) {
      stopifnot(identical(e$coverage, "local"), identical(e$reason, spec$reason),
                is.null(e$branches), is.null(e$spec))
      return(invisible(TRUE))
    }
    domain <- .sem_search_domain(out)
    stopifnot(identical(e$spec, spec), identical(e$original_bounds, domain),
              identical(e$reason, spec$reason), length(e$branches) == 2L, identical(e$coverage, "charted"))
    smp <- .sem_sample(out$data, out$ram, out$weights)
    cons <- .sem_constraint_rows(out$constraints, out$ram)
    counts <- list(n_starts = 0L, n_accepted = 0L, synthetic = 0L)
    values <- numeric()
    for (i in 1:2) {
      branch <- e$branches[[i]]
      box <- .sem_sign_bounds(spec, domain$lower, domain$upper, c(1, -1)[i])
      stopifnot(identical(branch$sign, c(1, -1)[i]), identical(branch$signs, box$signs),
                identical(branch$lower, box$lower), identical(branch$upper, box$upper))
      if (branch$state == "proved_empty") {
        stopifnot(box$empty, identical(branch$reason, "product_bound_contradiction"))
      } else {
        theta <- branch$theta
        stopifnot(identical(branch$state, "accepted"), !box$empty, is.numeric(theta), is.null(dim(theta)),
                  identical(names(theta), out$ram$par_names), length(theta) == out$ram$q,
                  !anyDuplicated(names(theta)), all(is.finite(theta)))
        floors <- .sem_floor_ids(out$ram, smp, sort(unique(c(cons$nl$idx, cons$nli$idx))), box$upper)
        lower <- box$lower
        lower[floors] <- pmax(lower[floors], .sem_var_floor * .sem_step_floor(out$ram, smp)[floors])
        stopifnot(identical(branch$effective_lower, lower),
                  all(theta[spec$labels] * box$signs > 0), all(theta >= box$lower), all(theta <= box$upper),
                  abs(prod(theta[spec$labels]) - spec$ratio) <= 1e-5 * max(1, abs(spec$ratio)))
        actual <- .sem_fml(theta, out$ram, smp)
        stopifnot(length(branch$f) == 1L, is.finite(branch$f), is.finite(actual),
                  abs(actual - branch$f) <= 1e-8 * max(1, abs(actual), abs(branch$f)))
        attempt <- .sem_search_attempts(branch)
        counts <- Map(`+`, counts, attempt$counts)
        values <- c(values, attempt$values)
      }
    }
    accepted <- which(vapply(e$branches, function(b) b$state == "accepted", TRUE))
    stopifnot(length(accepted) > 0L, length(e$selected) == 1L, e$selected %in% accepted,
              identical(e$attempt_counts, counts), identical(names(out$theta), out$ram$par_names),
              identical(out$theta, e$branches[[e$selected]]$theta),
              identical(out$f, e$branches[[e$selected]]$f),
              identical(out$f, min(vapply(e$branches[accepted], `[[`, 0, "f"))))
    if (!is.null(out$optimum)) {
      spread <- if (length(values) > 1L) diff(range(values)) else NA_real_
      status <- if (length(values) == 1L) "single" else if (spread > .sem_spread_tol) "disagreed" else "agreed"
      stopifnot(identical(out$optimum$n_starts, counts$n_starts),
                identical(out$optimum$n_accepted, counts$n_accepted), isTRUE(out$optimum$best_of),
                identical(out$optimum$certified, FALSE), identical(out$optimum$spread, spread),
                identical(out$optimum$status, status))
    }
    TRUE
  }, error = function(err) FALSE)
  if (!isTRUE(valid)) {
    stop(structure(list(message = "invalid nonzero-product search evidence", call = NULL),
                   class = c("medfit_error_search_evidence", "error", "condition")))
  }
  invisible(TRUE)
}

.sem_validate_fit_search <- function(fit) {
  if (is.null(fit@internals$search_evidence)) return(invisible(TRUE))
  out <- c(list(theta = fit@theta, f = fit@f, data = fit@data, information = fit@information,
                se_type = fit@diagnostics$se_type, optimum = fit@diagnostics$optimum), fit@internals)
  .sem_validate_search(out)
}
