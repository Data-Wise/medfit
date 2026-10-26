# Native SEM engine: standard errors from the information matrix.
#
# Internal. The covariance of the estimates is the inverse of the information
# for the log likelihood, observed or expected (spec Q4); both are scaled by n.
# A singular information matrix (an unidentified model) gives an NA covariance
# and one warning, never an error in the middle of a fit.

# Smallest reciprocal condition number of the Jacobi-scaled information that
# still counts as identified. Healthy K10 structures sit at 0.06 to 0.3; an
# unidentified model gives 4e-17 (expected) and about 1e-11 (observed, where the
# central difference limits the rank to about 1e-10). Provisional until S6.
.sem_info_singular_tol <- 1e-8

# `se_type = "sandwich"` replaces the bread-only inverse A^-1 by A^-1 B A^-1 with B from `.sem_scores()`
# (robust to the weights and to misspecified normality; projected the same way, Z (Z'AZ)^-1 Z'BZ (Z'AZ)^-1 Z').
# `cons` (from `.sem_constraint_rows()`) and the bounds `lb`, `ub` enter as the
# active set at `theta`: the covariance is projected onto the directions that keep
# every active equality, active inequality (as an equality) and active bound,
# V = Z (Z' I Z)^-1 Z' with Z the null-space basis from `.sem_active_set()` (spec
# Q5). With nothing active Z spans everything and the plain inverse is used, so an
# unconstrained fit is unchanged. A pinned coordinate gets zero variance.
.sem_vcov <- function(theta, ram, smp, information = c("observed", "expected"), cons = NULL,
                      lb = rep(-Inf, ram$q), ub = rep(Inf, ram$q), se_type = c("model", "sandwich")) {
  information <- match.arg(information)
  se_type <- match.arg(se_type)
  ctr <- .sem_center_map(ram, smp)
  # With a mean structure the information is built, inverted and checked in the centered coordinates (see
  # `.sem_center_map()`) and mapped back exactly: V = T V_phi T', since I = T^-T I_phi T^-1.
  info <- if (information == "observed") {
    .sem_info_observed(theta, ram, smp, ctr)
  } else {
    .sem_info_expected(theta, ram, smp, ctr)
  }
  tmat <- if (is.null(ctr)) NULL else ctr$t
  act <- .sem_active_set(theta, ram, smp, lb, ub, if (is.null(cons)) .sem_no_cons(ram$q) else cons)
  pinned <- !all(act$free) || any(act$active_row)
  z <- if (pinned) act$z_theta else NULL
  meat <- if (se_type == "sandwich") crossprod(.sem_scores(theta, ram, smp))
  vc <- if (is.null(z)) {
    bread <- .sem_invert_info(info)
    if (!is.null(bread) && !is.null(tmat)) bread <- tmat %*% bread %*% t(tmat)
    if (is.null(bread) || is.null(meat)) bread else bread %*% meat %*% bread
  } else if (ncol(z) == 0L) {
    matrix(0, ram$q, ram$q)
  } else {
    zc <- z
    if (!is.null(tmat)) {
      # an orthonormal basis of the same subspace in the centered coordinates: the basis from the active set is in
      # theta units, where a tangent along a path also moves its intercept by the mean, and that inflates the
      # condition number of Z' I Z by the square of mean/sd
      pinned_rows <- rowSums(z != 0) == 0
      zc <- qr.Q(qr(solve(tmat, z)))[, seq_len(ncol(z)), drop = FALSE]
      z <- tmat %*% zc
      # a coordinate the active set pins has an exactly zero row; the round trip leaves roundoff there (a 1e-18 SE
      # and a z-statistic in `tidy()`), so restore the exact zero. Only structural zeros: a tiny nonzero share of a
      # free direction is real variance and stays.
      z[pinned_rows, ] <- 0
    }
    bread <- .sem_invert_info(crossprod(zc, info %*% zc))
    if (is.null(bread)) {
      NULL
    } else if (is.null(meat)) {
      z %*% bread %*% t(z)
    } else {
      z %*% bread %*% crossprod(z, meat %*% z) %*% bread %*% t(z)
    }
  }
  if (is.null(vc)) {
    warning("information matrix is singular; the model may not be identified", call. = FALSE)
    vc <- matrix(NA_real_, ram$q, ram$q)
  }
  dimnames(vc) <- list(ram$par_names, ram$par_names)
  (vc + t(vc)) / 2
}

# Inverse of an information matrix, or NULL when it is not finite or singular
# (Jacobi-scaled reciprocal condition number at or below `.sem_info_singular_tol`).
.sem_invert_info <- function(info) {
  d <- if (all(is.finite(info))) 1 / sqrt(diag(info)) else NA_real_
  if (all(is.finite(d)) && rcond(info * outer(d, d)) > .sem_info_singular_tol) {
    tryCatch(solve(info), error = function(e) NULL)
  }
}

# Defined parameters (`:=`): value and delta-method standard error at the
# estimates. Each definition has its other definitions substituted, is evaluated
# at the labelled free parameters, and differentiated by central differences with
# step eps^(1/3) * max(|x|, 1), SE = sqrt(g' V g). `V` is the covariance of the
# estimates (projected when constraints are active). A definition that uses no
# parameter has zero SE.
.sem_defined <- function(constraints, theta, vcov) {
  d <- constraints[constraints$op == ":=", , drop = FALSE]
  out <- data.frame(name = d$lhs, expr = d$rhs, est = rep(NA_real_, nrow(d)), se = rep(NA_real_, nrow(d)),
                    stringsAsFactors = FALSE)
  if (!nrow(d)) {
    return(out)
  }
  defs <- .sem_defs(stats::setNames(d$rhs, d$lhs))
  for (i in seq_len(nrow(d))) {
    tree <- .sem_expr_subst(defs[[i]], defs)
    labels <- all.vars(tree)
    unknown <- setdiff(labels, names(theta))
    if (length(unknown)) {
      stop("defined parameter '", d$lhs[i], "' refers to '", unknown[1L], "', which is not a free parameter",
           call. = FALSE)
    }
    x <- theta[labels]
    out$est[i] <- .sem_expr_value(tree, x, d$rhs[i])
    if (!length(labels)) {
      out$se[i] <- 0
      next
    }
    g <- vapply(seq_along(labels), function(k) {
      h <- .Machine$double.eps^(1 / 3) * max(abs(x[[k]]), 1)
      up <- dn <- x
      up[[k]] <- x[[k]] + h
      dn[[k]] <- x[[k]] - h
      (.sem_expr_value(tree, up, d$rhs[i]) - .sem_expr_value(tree, dn, d$rhs[i])) / (2 * h)
    }, numeric(1))
    if (is.null(vcov)) next # validation-only pass (values and gradients), not an invented covariance
    v <- vcov[labels, labels, drop = FALSE]
    out$se[i] <- if (anyNA(v)) NA_real_ else sqrt(max(0, as.numeric(crossprod(g, v %*% g))))
  }
  out
}
