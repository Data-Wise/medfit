# Native SEM engine: MBCO, the minimum of two likelihood-ratio tests (S22).
# Oracles: the S19 known answers on RMediation's `memory_exp` (OpenMx diffLL 221.045546 for a1 == 0 and
# 0.083100 for b1 == 0; 0.060332 for the Rd example as written) and lavaan >= 0.7-3 constrained fits on a
# latent-mediator model. Planted defects: the larger diffLL instead of the minimum, and the wrong multiplier.

mbco_mem <- function() {
  path <- testthat::test_path("fixtures", "memory_exp.rds")
  if (!file.exists(path)) testthat::skip("tests/testthat/fixtures/memory_exp.rds is not present")
  readRDS(path)
}

mbco_mem_syntax <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
# The Rd example of RMediation::mbco() as written: `a1` labels the direct path (see test-sem-parity.R).
mbco_mem_shifted <- "repetition ~ a2*x\nimagery ~ cp*x\nrecall ~ a1*x + b1*repetition + b2*imagery"

# The two memory_exp calls are shared by the known-answer and defect tests (one MBCO fit each).
mbco_mem_res <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      d <- mbco_mem()
      cache <<- list(
        right = mbco_sem(fit_sem(mbco_mem_syntax, d), "a1", "b1"),
        shifted = mbco_sem(fit_sem(mbco_mem_shifted, d), "a1", "b1")
      )
    }
    cache
  }
})

test_that("MBCO known answer: both diffLL values, the minimum as the statistic, df = 1", {
  res <- mbco_mem_res()$right
  # OpenMx's six printed decimals: an absolute 1e-6 (measured 3e-8 and 4e-7, test-sem-parity.R)
  expect_lt(abs(res$tests$diff_ll[res$tests$constraint == "a1 == 0"] - 221.045546), 1e-6)
  expect_lt(abs(res$tests$diff_ll[res$tests$constraint == "b1 == 0"] - 0.083100), 1e-6)
  expect_lt(abs(unname(res$statistic) - 0.083100), 1e-6)
  expect_identical(unname(res$parameter), 1)
  expect_equal(res$p.value, stats::pchisq(unname(res$statistic), df = 1, lower.tail = FALSE))
  expect_gt(res$p.value, 0.7)
})

test_that("MBCO on the RMediation example as written equals mxCompare's 0.060332", {
  res <- mbco_mem_res()$shifted
  expect_lt(abs(unname(res$statistic) - 0.060332), 1e-6)
})

test_that("planted defects: the larger diffLL or a wrong multiplier misses the known answer", {
  res <- mbco_mem_res()$right
  stat <- unname(res$statistic)
  # reporting the larger diffLL (the nonlinear a1*b1 solve's value) is 221.05, not 0.0831
  expect_gt(abs(max(res$tests$diff_ll) - 0.083100), 1)
  expect_identical(stat, min(res$tests$diff_ll))
  expect_lt(stat, max(res$tests$diff_ll) - 1)
  # n - 1 or 2 n as the multiplier moves the b1 value by more than the tolerance
  f_b1 <- res$tests$diff_ll[res$tests$constraint == "b1 == 0"] / res$n_obs
  expect_gt(abs((res$n_obs - 1) * f_b1 - 0.083100), 1e-6)
  expect_gt(abs(2 * res$n_obs * f_b1 - 0.083100), 1e-6)
})

test_that("the result prints as an htest and carries both refits' discrepancy", {
  res <- mbco_mem_res()$right
  expect_s3_class(res, c("mbco_sem", "htest"))
  out <- paste(utils::capture.output(print(res)), collapse = "\n")
  expect_match(out, "MBCO", fixed = TRUE)
  expect_match(out, "df = 1", fixed = TRUE)
  expect_named(res$tests, c("constraint", "f", "diff_ll", "converged"))
  expect_true(all(res$tests$converged))
  expect_identical(res$n_obs, 369L)
})

test_that("a latent-mediator model matches lavaan's constrained fits", {
  skip_if_not_installed("lavaan", "0.7-3")
  d <- sem_sim(sem_model_latent(), 500, 21)
  model <- "eta =~ m1 + m2 + m3\neta ~ a*X\nY ~ b*eta + cp*X"
  fit <- fit_sem(model, d)
  res <- mbco_sem(fit, "a", "b")
  chisq <- function(extra) {
    lavaan::fitMeasures(lavaan::sem(paste0(model, "\n", extra), data = d, fixed.x = FALSE), "chisq")[[1L]]
  }
  full <- chisq("")
  # tolerance: the two optimizers each stop near 1e-8 on the objective; pinned at 1e-5 on the statistic
  expect_equal(res$tests$diff_ll[1L], chisq("a == 0") - full, tolerance = 1e-5)
  expect_equal(res$tests$diff_ll[2L], chisq("b == 0") - full, tolerance = 1e-5)
  expect_equal(unname(res$statistic), min(res$tests$diff_ll))
})

test_that("inputs the test cannot honor error by name", {
  d <- sem_sim(sem_model_observed(), 200, 5)
  fit <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C", d)
  expect_error(mbco_sem(list(), "a", "b"), "SEMFit")
  expect_error(mbco_sem(fit, "a", "nope"), "'nope'.*free")
  expect_error(mbco_sem(fit, "a", "a"), "different")
  expect_error(mbco_sem(fit, "a", 1), "string")
  w <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C", d, sampling_weights = rep(c(1, 2), 100), se_type = "sandwich")
  expect_error(mbco_sem(w, "a", "b"), "sampling weights")
})
