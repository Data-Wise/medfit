# V5: the scale protection survives fixed_x (spec S10). Locations from mean/sd 0 to 1e5.

fx_far <- function(shift) {
  d <- fx_data()
  for (v in c("mediator1", "outcome", "covariate1", "covariate2")) d[[v]] <- d[[v]] + shift
  d
}

test_that("fixed_x = TRUE and a subset are accepted and location-invariant to mean/sd 1e5", {
  near <- fit_sem(fx_syntax, fx_data(), meanstructure = TRUE, fixed_x = TRUE)
  near_sub <- fit_sem(fx_syntax, fx_data(), meanstructure = TRUE, fixed_x = "covariate1")
  keep <- c("a", "b", "cp")
  for (shift in c(1e2, 1e3, 1e5)) {
    far <- fit_sem(fx_syntax, fx_far(shift), meanstructure = TRUE, fixed_x = TRUE)
    far_sub <- fit_sem(fx_syntax, fx_far(shift), meanstructure = TRUE, fixed_x = "covariate1")
    expect_true(far@converged && far_sub@converged, info = shift)
    expect_false(anyNA(far@vcov) || anyNA(far_sub@vcov), info = shift)
    expect_equal(far@theta[keep], near@theta[keep], tolerance = 1e-5, info = shift)
    expect_equal(far_sub@theta[keep], near_sub@theta[keep], tolerance = 1e-5, info = shift)
    expect_equal(sqrt(diag(far@vcov))[keep], sqrt(diag(near@vcov))[keep], tolerance = 1e-4, info = shift)
  }
})

test_that("the shifted route is still taken when intercept rows are fixed_x", {
  fit <- fit_sem(fx_syntax, fx_data(), meanstructure = TRUE, fixed_x = TRUE)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  none <- rep(FALSE, ram$q)
  expect_true(.sem_shift_ok(ram, smp, NULL, rep(-Inf, ram$q), rep(Inf, ram$q), none))
})
