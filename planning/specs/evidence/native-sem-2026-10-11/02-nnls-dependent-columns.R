# Fixture 2 (S1 finding, audit F5 / plan S25): the 04b non-negative least squares divides 0 by 0 on dependent columns.
#
# `nnls()` below is copied VERBATIM from ../native-sem-2026-10-08/04b-constraint-contract.R (the Lawson-Hanson loop with an
# absolute tolerance of 1e-12 and no step guard). A column that depends on the columns already in the active set enters
# when roundoff pushes its weight above the absolute tolerance, lm.fit() then pivots it out with a zero coefficient, and the
# step length x / (x - s) is 0 / 0. The result is NaN and the next test errors.
#
# Families (all seeded):
#   dup  - 6 x 5 matrix: three random columns, a copy of column 1, and column 2 + column 3, times a scale; b random times the scale.
#   mult - the layout kkt_general(signed = TRUE) built in 04b for active constraints: t(rbind(Jineq, Jeq, -Jeq)) where one
#          equality row is a sum of two others, times a scale. Every equality contributes a column and its negative, so the
#          matrix is rank deficient by construction.
# The scale stands for the units of the data: the absolute tolerance does not scale with it, roundoff does.
#
# Output: results/02-nnls-cases.csv (every case), results/02-nnls-fixture.csv (the smallest failing dup case at scale 1e4: A, b,
# and the reference solution from bounded least squares on the column-normalized problem, for the T7 port to be checked against).
# Run from this directory: Rscript 02-nnls-dependent-columns.R. Exits nonzero if an ASSERT fails.
failures <- 0L
assert <- function(label, ok) {
  cat(sprintf("ASSERT %-4s %s\n", if (isTRUE(ok)) "PASS" else "FAIL", label))
  if (!isTRUE(ok)) failures <<- failures + 1L
}

# ---- verbatim from 04b (lines 130-137 of 04b-constraint-contract.R) ----
nnls <- function(A, b, tol = 1e-12, maxit = 500) { n <- ncol(A); x <- numeric(n); P <- rep(FALSE, n); w <- as.vector(crossprod(A, b - A %*% x)); it <- 0
  ls_on <- function(P) { s <- numeric(n); if (any(P)) { cf <- lm.fit(A[, P, drop = FALSE], b)$coefficients; cf[is.na(cf)] <- 0; s[P] <- cf }; s }
  while (any(!P) && max(w[!P]) > tol && it < maxit) { it <- it + 1; j <- which(!P)[which.max(w[!P])]; P[j] <- TRUE
    repeat { s <- ls_on(P); if (all(s[P] > 0)) { x <- s; break }
      neg <- P & s <= 0; alpha <- min(x[neg] / (x[neg] - s[neg])); x <- x + alpha * (s - x); P <- P & x > tol; x[!P] <- 0 }
    w <- as.vector(crossprod(A, b - A %*% x)) }
  x }
# ---- end verbatim ----

# The same loop, instrumented only to record the numerator and denominator of the step length at the first non-finite step.
nnls_traced <- function(A, b, tol = 1e-12, maxit = 500) {
  n <- ncol(A); x <- numeric(n); P <- rep(FALSE, n); w <- as.vector(crossprod(A, b - A %*% x)); it <- 0
  seen <- NULL
  ls_on <- function(P) { s <- numeric(n); if (any(P)) { cf <- lm.fit(A[, P, drop = FALSE], b)$coefficients; cf[is.na(cf)] <- 0; s[P] <- cf }; s }
  while (any(!P) && max(w[!P]) > tol && it < maxit) {
    it <- it + 1; j <- which(!P)[which.max(w[!P])]; P[j] <- TRUE
    repeat {
      s <- ls_on(P); if (all(s[P] > 0)) { x <- s; break }
      neg <- P & s <= 0
      num <- x[neg]; den <- x[neg] - s[neg]
      if (is.null(seen) && any(num == 0 & den == 0)) seen <- list(column = which(neg)[which(num == 0 & den == 0)[1]], weight = w[j], num = 0, den = 0)
      alpha <- min(num / den); if (is.na(alpha)) return(list(x = NULL, zero_over_zero = seen))
      x <- x + alpha * (s - x); P <- P & x > tol; x[!P] <- 0
    }
    w <- as.vector(crossprod(A, b - A %*% x))
  }
  list(x = x, zero_over_zero = seen)
}

gen <- list(
  dup = function(sc) { A <- matrix(rnorm(6 * 3), 6); list(A = cbind(A, A[, 1], A[, 2] + A[, 3]) * sc, b = rnorm(6) * sc) },
  mult = function(sc) { q <- 4; J <- matrix(rnorm(2 * q), 2); Jc <- matrix(rnorm(2 * q), 2); Je <- rbind(J, J[1, ] + J[2, ])
    list(A = t(rbind(Jc, Je, -Je)) * sc, b = rnorm(q) * sc) }
)
scales <- c(1, 1e2, 1e4, 1e6)
seeds <- 1:500
rows <- list()
first_bad <- list()
for (fam in names(gen)) for (sc in scales) for (sd in seeds) {
  set.seed(sd)
  d <- gen[[fam]](sc)
  r <- tryCatch(nnls(d$A, d$b), error = function(e) e)
  out <- if (inherits(r, "error")) "error" else if (any(!is.finite(r))) "nonfinite" else "ok"
  rank <- qr(scale(d$A, center = FALSE, scale = sqrt(colSums(d$A^2))))$rank
  rows[[length(rows) + 1L]] <- data.frame(family = fam, scale = sc, seed = sd, rank = rank, ncol = ncol(d$A), outcome = out)
  if (out != "ok" && is.null(first_bad[[paste(fam, sc)]])) first_bad[[paste(fam, sc)]] <- list(family = fam, scale = sc, seed = sd, d = d)
}
R <- do.call(rbind, rows)
utils::write.csv(R, "results/02-nnls-cases.csv", row.names = FALSE)
tab <- do.call(rbind, lapply(split(R, list(R$family, R$scale), drop = TRUE), function(d) {
  data.frame(family = d$family[1], scale = d$scale[1], cases = nrow(d), ncol = d$ncol[1], rank = max(d$rank), failed = sum(d$outcome != "ok"))
}))
rownames(tab) <- NULL
cat("old nnls() on rank-deficient problems (failed = error or non-finite result):\n")
print(tab, row.names = FALSE)

assert("every problem is rank deficient (rank < number of columns)", all(R$rank < R$ncol))
assert("control: no failure at scale 1 in either family", all(R$outcome[R$scale == 1] == "ok"))
fam_fail <- tapply(R$outcome != "ok", list(R$family, R$scale), sum)
assert(sprintf("defect reproduces: dup family fails in %d of 500 cases at scale 1e4", fam_fail["dup", "10000"]), fam_fail["dup", "10000"] > 0)

# the mechanism is 0 / 0: replay the first failing dup case at 1e4 with the instrumented copy
bad <- first_bad[["dup 10000"]]
set.seed(bad$seed)
d <- gen$dup(bad$scale)
tr <- nnls_traced(d$A, d$b)
assert(sprintf("mechanism is 0/0: seed %d scale 1e4, column %s entered with weight %.2e (absolute tol 1e-12) and its step was 0/0",
               bad$seed, if (is.null(tr$zero_over_zero)) "NA" else tr$zero_over_zero$column,
               if (is.null(tr$zero_over_zero)) NA_real_ else tr$zero_over_zero$weight),
       !is.null(tr$zero_over_zero) && is.null(tr$x) && tr$zero_over_zero$weight > 1e-12)

# the fixture for the T7 port: smallest failing dup case at 1e4, with a reference answer from bounded least squares
An <- scale(d$A, center = FALSE, scale = sqrt(colSums(d$A^2)))
bn <- d$b / sqrt(sum(d$b^2))
ref <- optim(rep(0.1, ncol(An)), function(p) sum((An %*% p - bn)^2), function(p) as.vector(2 * crossprod(An, An %*% p - bn)),
             method = "L-BFGS-B", lower = 0, control = list(factr = 10, pgtol = 0))
fx <- data.frame(d$A, b = d$b)
names(fx) <- c(paste0("A", seq_len(ncol(d$A))), "b")
fx$ref_x_normalized <- c(ref$par, rep(NA, nrow(fx) - ncol(d$A)))
fx$ref_residual_normalized <- c(ref$value, rep(NA, nrow(fx) - 1))
utils::write.csv(fx, "results/02-nnls-fixture.csv", row.names = FALSE)
cat(sprintf("fixture: dup seed %d scale %g; reference solution on the normalized problem: x = (%s), squared residual %.3e\n",
            bad$seed, bad$scale, paste(signif(ref$par, 4), collapse = ", "), ref$value))
assert("the reference solution is non-negative and finite", all(is.finite(ref$par)) && all(ref$par >= 0))

cat(sprintf("\nR %s\n", getRversion()))
if (failures > 0L) {
  cat(sprintf("\nFAILED: %d assertion(s)\n", failures))
  quit(status = 1)
}
cat("\nall assertions passed\n")
