# ---- reference calculations (no production helpers) ----------------------------------------------------------------

# Implied moments of a recursive model: mu = (I - B)^-1 nu, Sigma = (I - B)^-1 Psi (I - B)^-T.
gk_implied <- function(B, psi, nu) {
  A <- solve(diag(nrow(B)) - B)
  list(mu = drop(A %*% nu), sigma = A %*% diag(psi, length(psi)) %*% t(A))
}
# The three-variable adapter: theta is named a, b, [cp,] vx, vm, vy, ix, im, iy; variable order X, M, Y.
gk_theta_moments <- function(theta) {
  B <- matrix(0, 3, 3)
  B[2, 1] <- theta[["a"]]
  B[3, 2] <- theta[["b"]]
  if ("cp" %in% names(theta)) B[3, 1] <- theta[["cp"]]
  gk_implied(B, theta[c("vx", "vm", "vy")], theta[c("ix", "im", "iy")])
}
# Rowwise Gaussian NLL over observed subvectors; all-empty rows contribute exactly zero.
gk_row_nll <- function(d, mom) {
  sum(vapply(seq_len(nrow(d)), function(i) {
    j <- which(!is.na(d[i, ]))
    if (!length(j)) return(0)
    r <- as.numeric(d[i, j]) - mom$mu[j]
    S <- mom$sigma[j, j, drop = FALSE]
    .5 * (length(j) * log(2 * pi) + as.numeric(determinant(S, logarithm = TRUE)$modulus) +
            drop(t(r) %*% solve(S, r)))
  }, numeric(1)))
}
gk_center <- function(d) colMeans(d, na.rm = TRUE)
gk_scale <- function(d) apply(d, 2, stats::sd, na.rm = TRUE)
gk_standardize <- function(d) sweep(sweep(d, 2, gk_center(d)), 2, gk_scale(d), `/`)
# Standardized-coordinate NLL and the original-scale NLL it implies (moments mapped by mu = c + D mu_s).
gk_nll_std <- function(d, theta) gk_row_nll(gk_standardize(d), gk_theta_moments(theta))
gk_nll_original <- function(d, theta) {
  m <- gk_theta_moments(theta)
  s <- gk_scale(d)
  gk_row_nll(d, list(mu = gk_center(d) + s * m$mu, sigma = diag(s) %*% m$sigma %*% diag(s)))
}
# Recover structural parameters from moments by recursive regressions (inverse of gk_implied for X -> M -> Y).
gk_recover <- function(mom, direct) {
  S <- mom$sigma
  mu <- mom$mu
  a <- S[2, 1] / S[1, 1]
  if (direct) {
    coef <- solve(S[c(2, 1), c(2, 1)], S[c(2, 1), 3])
    b <- coef[[1]]
    cp <- coef[[2]]
    vy <- S[3, 3] - sum(coef * S[c(2, 1), 3])
  } else {
    b <- S[2, 3] / S[2, 2]
    cp <- 0
    vy <- S[3, 3] - b * S[2, 3]
  }
  q <- c(a = a, b = b, cp = cp, vx = S[1, 1], vm = S[2, 2] - a * S[2, 1], vy = vy,
         ix = mu[[1]], im = mu[[2]] - a * mu[[1]], iy = mu[[3]] - b * mu[[2]] - cp * mu[[1]])
  if (!direct) q <- q[names(q) != "cp"]
  q
}
# Central differences with Richardson extrapolation, independent of production derivatives.
gk_gradient <- function(f, theta) {
  vapply(seq_along(theta), function(k) {
    fo_richardson(lapply(.02 / 2^(0:3), function(h) {
      e <- theta * 0
      e[k] <- h
      (f(theta + e) - f(theta - e)) / (2 * h)
    }))
  }, numeric(1))
}


# ---- fixtures ------------------------------------------------------------------------------------------------------

gk_masks <- list(
  X = c(FALSE, TRUE, TRUE), M = c(TRUE, FALSE, TRUE), Y = c(TRUE, TRUE, FALSE),
  XM = c(FALSE, FALSE, TRUE), XY = c(FALSE, TRUE, FALSE), MY = c(TRUE, FALSE, FALSE),
  none = c(TRUE, TRUE, TRUE)
)
# kinds: complete, one-variable gaps, pairs, all seven non-empty patterns with empty rows, minimal (two rows per
# pattern) and a column observed exactly twice.
gk_data <- function(kind) {
  set.seed(4242L)
  n <- switch(kind, minimal = 14L, 61L)
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + .25 * x + stats::rnorm(n, sd = .9)
  d <- cbind(X = x, M = m, Y = y)
  hide <- function(rows, cols) d[rows, cols] <<- NA_real_ # nolint: assignment_linter.
  i <- seq_len(n)
  switch(kind,
    complete = NULL,
    x_gaps = hide(i %% 4L == 0L, "X"),
    m_gaps = hide(i %% 3L == 0L, "M"),
    y_gaps = hide(i %% 5L == 0L, "Y"),
    pairs = {
      hide(i %% 6L == 0L, c("X", "M"))
      hide(i %% 6L == 1L, c("M", "Y"))
      hide(i %% 6L == 2L, c("X", "Y"))
    },
    all7 = {
      nm <- c("X", "M", "Y")
      keep <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE), Y = c(FALSE, TRUE)))
      keep <- keep[-1L, , drop = FALSE]
      for (r in i) d[r, !keep[(r - 1L) %% 7L + 1L, ]] <- NA_real_
      d[c(10L, 33L), nm] <- NA_real_
    },
    minimal = {
      keep <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE), Y = c(FALSE, TRUE)))
      keep <- keep[-1L, , drop = FALSE]
      for (r in i) d[r, !keep[(r - 1L) %% 7L + 1L, ]] <- NA_real_
    },
    ytwo = {
      d[-c(3L, 40L), "Y"] <- NA_real_
      d[c(1L, 2L, 5L), "X"] <- NA_real_
    },
    stop("unknown kind")
  )
  d
}
gk_kinds <- c("complete", "x_gaps", "m_gaps", "y_gaps", "pairs", "all7", "minimal", "ytwo")
gk_theta <- function(direct, seed) {
  set.seed(seed)
  base <- c(a = .3, b = .4, cp = .2, vx = 1.1, vm = .8, vy = 1.2, ix = .1, im = -.1, iy = .05)
  out <- base + stats::runif(9, -.12, .12)
  names(out) <- names(base)
  if (!direct) out <- out[names(out) != "cp"]
  out
}
