# extract_mediation() on lavaan fits with sampling weights.
#
# lavaan normalizes sampling weights to sum to N, so lavInspect(fit, "nobs")
# can read N - 1e-13 (e.g. 355.99999999999994 for N = 356). n_obs must be the
# rounded count, not the truncated one, or the MediationData validator rejects
# the object (rows of data != n_obs).

skip_if_not_installed("lavaan")

weighted_fit <- function(seed, n) {
  set.seed(seed)
  d <- data.frame(X = rnorm(n), C = rnorm(n))
  d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
  d$w <- runif(n, 0.5, 2)
  list(
    fit = lavaan::sem("M ~ a * X + C\nY ~ b * M + cp * X + C", d,
      sampling.weights = "w"
    ),
    n = n
  )
}

test_that("n_obs is the rounded sample size for weighted lavaan fits", {
  # Several draws: the floating-point error in the normalized weights depends on
  # the data, and at least one of these reads below N (checked below).
  below <- 0L
  for (seed in 1:12) {
    wf <- weighted_fit(seed, n = 300 + seed)
    nobs <- lavaan::lavInspect(wf$fit, "nobs")
    if (nobs < wf$n) below <- below + 1L
    med <- extract_mediation(wf$fit, treatment = "X", mediator = "M", outcome = "Y")
    expect_identical(med@n_obs, as.integer(wf$n), info = paste("seed", seed))
    expect_equal(nrow(med@data), wf$n, info = paste("seed", seed))
  }
  # Guard against the test passing for the wrong reason: if lavaan ever stops
  # producing a sub-N reading, this fixture no longer exercises the bug.
  skip_if(below == 0L, "lavaan did not produce a sub-N weighted nobs on these draws")
})
