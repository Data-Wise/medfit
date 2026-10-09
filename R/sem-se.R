# Native SEM engine: standard errors from the information matrix.
#
# Internal. The covariance of the estimates is the inverse of the information
# for the log likelihood, observed or expected (spec Q4); both are scaled by n.
# A singular information matrix (an unidentified model) gives an NA covariance
# and one warning, never an error in the middle of a fit.

.sem_info_singular_tol <- 1e-12

.sem_vcov <- function(theta, ram, smp, information = c("observed", "expected")) {
  information <- match.arg(information)
  info <- if (information == "observed") {
    .sem_info_observed(theta, ram, smp)
  } else {
    .sem_info_expected(theta, ram, smp)
  }
  vc <- if (all(is.finite(info)) && rcond(info) > .sem_info_singular_tol) {
    tryCatch(solve(info), error = function(e) NULL)
  }
  if (is.null(vc)) {
    warning("information matrix is singular; the model may not be identified", call. = FALSE)
    vc <- matrix(NA_real_, ram$q, ram$q)
  }
  dimnames(vc) <- list(ram$par_names, ram$par_names)
  (vc + t(vc)) / 2
}
