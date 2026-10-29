# Nonzero-product searches. Sign coverage is evidence about local solves, never global optimality.
.sem_nonzero_product <- function(constraints, ram) {
  no <- function(reason) list(supported = FALSE, reason = reason)
  rows <- which(constraints$op %in% c("==", "<", ">"))
  defs <- constraints[constraints$op == ":=", , drop = FALSE]
  defs <- .sem_defs(stats::setNames(defs$rhs, defs$lhs))
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
    return(list(supported = TRUE, reason = "two_sign_branches", row = i, labels = labels,
                idx = match(labels, ram$par_names), coefficient = coefficient, target = value, ratio = ratio))
  }
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
  if (min(eigen(reference$vcov, symmetric = TRUE, only.values = TRUE)$values) <
        -1e-10 * max(1, max(abs(reference$vcov)))) {
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
                                    gate = list(status = fit$status, decrement = fit$decrement)))
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

.sem_search_context <- function(out) {
  rlang::hash(list(data = out$data, weights = out$weights, constraints = out$constraints,
                   parameters = out$ram, fixed_x = out$fixed_x,
                   has_mean = out$ram$has_mean, information = out$information, se_type = out$se_type))
}

.sem_validate_search <- function(out) {
  e <- out$search_evidence
  if (is.null(e)) return(invisible(TRUE))
  valid <- tryCatch({
    stopifnot(identical(e$schema_version, 1L), identical(e$context, .sem_search_context(out)))
    if (e$coverage == "local") return(invisible(TRUE))
    spec <- .sem_nonzero_product(out$constraints, out$ram)
    stopifnot(identical(spec, e$spec), length(e$branches) == 2L, e$coverage == "charted")
    for (i in 1:2) {
      branch <- e$branches[[i]]
      box <- .sem_sign_bounds(spec, e$original_bounds$lower, e$original_bounds$upper, c(1, -1)[i])
      stopifnot(identical(branch$sign, c(1, -1)[i]), identical(branch$signs, box$signs),
                identical(branch$lower, box$lower), identical(branch$upper, box$upper))
      if (branch$state == "proved_empty") {
        stopifnot(box$empty, identical(branch$reason, "product_bound_contradiction"))
      } else {
        stopifnot(branch$state == "accepted", !box$empty, is.finite(branch$f),
                  all(branch$theta[spec$labels] * box$signs > 0),
                  all(branch$theta >= box$lower), all(branch$theta <= box$upper),
                  abs(prod(branch$theta[spec$labels]) - spec$ratio) <= 1e-5 * max(1, abs(spec$ratio)))
      }
    }
    accepted <- which(vapply(e$branches, function(b) b$state == "accepted", TRUE))
    stopifnot(length(accepted) > 0, e$selected %in% accepted,
              identical(out$theta, e$branches[[e$selected]]$theta),
              identical(out$f, min(vapply(e$branches[accepted], `[[`, 0, "f"))))
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
                se_type = fit@diagnostics$se_type), fit@internals)
  .sem_validate_search(out)
}
