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

.sem_vcov <- function(theta, ram, smp, information = c("observed", "expected")) {
  information <- match.arg(information)
  info <- if (information == "observed") {
    .sem_info_observed(theta, ram, smp)
  } else {
    .sem_info_expected(theta, ram, smp)
  }
  d <- if (all(is.finite(info))) 1 / sqrt(diag(info)) else NA_real_
  vc <- if (all(is.finite(d)) && rcond(info * outer(d, d)) > .sem_info_singular_tol) {
    tryCatch(solve(info), error = function(e) NULL)
  }
  if (is.null(vc)) {
    warning("information matrix is singular; the model may not be identified", call. = FALSE)
    vc <- matrix(NA_real_, ram$q, ram$q)
  }
  dimnames(vc) <- list(ram$par_names, ram$par_names)
  (vc + t(vc)) / 2
}
