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

test_that("planted defects: the larger diffLL or a wrong multiplier in the source misses the known answer", {
  # each mutation rebuilds mbco_sem() from its own source, so the mutated code runs
  d <- mbco_mem()
  fit <- fit_sem(mbco_mem_syntax, d)
  good <- unname(mbco_sem(fit, "a1", "b1")$statistic)
  expect_lt(abs(good - 0.083100), 1e-6)
  larger <- sem_mutate(mbco_sem, "min(diff_ll)", "max(diff_ll)")
  expect_gt(abs(unname(larger(fit, "a1", "b1")$statistic) - 0.083100), 1)
  fewer <- sem_mutate(mbco_sem, "n <- fit@n_obs", "n <- fit@n_obs - 1L")
  expect_gt(abs(unname(fewer(fit, "a1", "b1")$statistic) - 0.083100), 1e-6)
  doubled <- sem_mutate(mbco_sem, "n <- fit@n_obs", "n <- 2L * fit@n_obs")
  expect_gt(abs(unname(doubled(fit, "a1", "b1")$statistic) - 0.083100), 1e-6)
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
  expect_error(mbco_sem(fit, "a", "nope"), "'nope'.*labeled regression path")
  expect_error(mbco_sem(fit, "a", "a"), "different")
  expect_error(mbco_sem(fit, "a", 1), "string")
  w <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C", d, weights = rep(c(1, 2), 100), se_type = "sandwich")
  expect_error(mbco_sem(w, "a", "b"), "sampling weights")
})

test_that("a model that already has an inequality refits with the appended equality (inactive: same statistic)", {
  set.seed(11)
  d <- data.frame(X = stats::rnorm(300))
  d$M <- 0.5 * d$X + stats::rnorm(300)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(300)
  base <- "M ~ a*X\nY ~ b*M + cp*X"
  plain <- mbco_sem(fit_sem(base, d), "a", "b")
  with_ineq <- mbco_sem(fit_sem(paste0(base, "\nb + cp < 5"), d), "a", "b")
  expect_equal(unname(with_ineq$statistic), unname(plain$statistic), tolerance = 1e-5)
  expect_equal(with_ineq$tests$diff_ll, plain$tests$diff_ll, tolerance = 1e-5)
})

# --- Guards -------------------------------------------------------------------------------

guard_data <- function(n = 500, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = stats::rnorm(n))
  d$M <- 0.5 * d$X + stats::rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(n)
  d
}
guard_base <- "M ~ a*X\nY ~ b*M + cp*X"

test_that("a and b must be user-labeled free regression paths", {
  fit <- fit_sem(guard_base, guard_data())
  # the error names the labeled paths that are available, not every free parameter
  expect_error(mbco_sem(fit, "M ~ X", "b"), "labeled regression path.*a, b, cp")
  expect_error(mbco_sem(fit, "a", "M ~~ M"), "labeled regression path")
  # a variance, a loading and a covariance label are not regression paths either
  lat <- fit_sem("eta =~ m1 + l2*m2 + m3\neta ~ a*X\nY ~ b*eta + cp*X", {
    d <- guard_data()
    set.seed(3)
    d$m1 <- d$M + stats::rnorm(nrow(d))
    d$m2 <- 0.8 * d$M + stats::rnorm(nrow(d))
    d$m3 <- 0.7 * d$M + stats::rnorm(nrow(d))
    d
  })
  expect_error(mbco_sem(lat, "a", "l2"), "labeled regression path")
  expect_no_error(mbco_sem(lat, "a", "b"))
})

test_that("a full fit that did not converge is refused", {
  fit <- fit_sem(guard_base, guard_data())
  fit@converged <- FALSE
  expect_error(mbco_sem(fit, "a", "b"), "did not converge")
})

test_that("the refits inherit the fit's n_starts and control, and explicit arguments override them", {
  d <- guard_data()
  fit <- fit_sem(guard_base, d, n_starts = 3L, control = list(maxeval = 7000L))
  seen <- list()
  orig <- medfit:::.sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    seen[[length(seen) + 1L]] <<- list(...)
    orig(...)
  })
  mbco_sem(fit, "a", "b")
  expect_length(seen, 2L)
  for (call in seen) {
    expect_identical(call$n_starts, 3L)
    expect_identical(call$control, list(maxeval = 7000L))
  }
  seen <- list()
  mbco_sem(fit, "a", "b", n_starts = 2L, control = list())
  expect_identical(seen[[1L]]$n_starts, 2L)
  expect_identical(seen[[1L]]$control, list())
})

test_that("an inequality that holds the null on the boundary warns; an interior or inactive one does not", {
  d <- guard_data()
  # a > 0: the null a = 0 sits on the boundary, so the statistic is a mixture, not chi-square(1)
  on_edge <- fit_sem(paste0(guard_base, "\na > 0"), d)
  expect_warning(mbco_sem(on_edge, "a", "b"), "boundary")
  # a < 0.2: the null a = 0 is interior, so the usual chi-square(1) holds and nothing is said
  interior <- fit_sem(paste0(guard_base, "\na < 0.2"), d)
  expect_no_warning(res <- mbco_sem(interior, "a", "b"))
  expect_true(is.finite(res$statistic))
  # an inequality row that involves the tested parameter and is active at its null refit warns: at a = 0 the
  # row a - b > -0.3 binds b at 0.3 (the full fit has b - a < 0.3, so it is inactive there)
  row_fit <- fit_sem(paste0(guard_base, "\na - b > -0.3"), d)
  expect_warning(mbco_sem(row_fit, "a", "b"), "boundary")
  # an active row on another parameter (b + cp < 0.5 binds b at the a == 0 refit) is not about the null a = 0
  other <- fit_sem(paste0(guard_base, "\nb + cp < 0.5"), d)
  expect_no_warning(mbco_sem(other, "a", "b"))
  # b + cp < 5 is inactive at every refit
  inactive <- fit_sem(paste0(guard_base, "\nb + cp < 5"), d)
  expect_no_warning(mbco_sem(inactive, "a", "b"))
})

test_that("a null outside the region the model allows errors with a message about the constraint", {
  fit <- fit_sem(paste0(guard_base, "\na > 0.3"), guard_data())
  expect_error(mbco_sem(fit, "a", "b"), "`a == 0`.*constraint.*parameter space")
})

# --- A product of k paths (T17) ---------------------------------------------------------------------------
# The same test with k refits, one per path: the statistic is the smallest diffLL, referred to chi-square(1).
# Oracles: single-path constrained fits written out by hand, and the chi-square(1) tail at 4 (p = 0.0455).

mbco_serial_syntax <- paste0(
  "mediator1 ~ a*treatment\nmediator2 ~ d*mediator1 + treatment\n",
  "outcome ~ b*mediator2 + treatment"
)

test_that("k = 2 gives the same result through a and b, a vector in a, or paths", {
  f <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment", mediation_demo)
  ref <- mbco_sem(f, "a", "b")
  for (alt in list(mbco_sem(f, c("a", "b")), mbco_sem(f, paths = c("a", "b")))) {
    expect_identical(alt$statistic, ref$statistic)
    expect_identical(alt$p.value, ref$p.value)
    expect_identical(alt$tests, ref$tests)
    expect_identical(alt$data.name, ref$data.name)
    expect_identical(alt$method, ref$method)
  }
  expect_identical(ref$data.name, "a * b = 0")
  expect_identical(ref$method, "Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect")
})

test_that("a serial model returns the minimum of three diffLLs, each equal to a hand-written constrained fit", {
  f <- fit_sem(mbco_serial_syntax, mediation_demo)
  res <- mbco_sem(f, paths = c("a", "d", "b"))
  by_hand <- vapply(c("a", "d", "b"), function(p) {
    nrow(mediation_demo) * (fit_sem(paste0(mbco_serial_syntax, "\n", p, " == 0"), mediation_demo)@f - f@f)
  }, numeric(1))
  expect_identical(res$tests$constraint, c("a == 0", "d == 0", "b == 0"))
  expect_equal(res$tests$diff_ll, unname(by_hand), tolerance = 1e-8)
  expect_equal(unname(res$statistic), min(by_hand), tolerance = 1e-8)
  expect_equal(res$p.value, stats::pchisq(min(by_hand), df = 1, lower.tail = FALSE))
  expect_identical(res$data.name, "a * d * b = 0")
  expect_match(res$method, "Minimum-of-3")
  # the three refits differ, so a wrong pick (the largest) would change the statistic
  expect_gt(max(by_hand) - min(by_hand), 1)
})

test_that("planted defect: the degrees of freedom do not match the chi-square(1) oracle at statistic 4", {
  f <- fit_sem(mbco_serial_syntax, mediation_demo)
  real <- .sem_fit_syntax
  n <- f@n_obs
  # every refit is shifted so that diffLL is exactly 4
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    r <- real(...)
    r$f <- f@f + 4 / n
    r
  })
  res <- mbco_sem(f, paths = c("a", "d", "b"))
  expect_equal(unname(res$statistic), 4, tolerance = 1e-10)
  expect_equal(res$p.value, 0.0455003, tolerance = 1e-6)
  wrong <- sem_mutate(mbco_sem, "df = 1, lower.tail", "df = 2, lower.tail")
  expect_gt(abs(wrong(f, paths = c("a", "d", "b"))$p.value - 0.0455003), 0.05)
})

test_that("paths must be two or more different labeled regression paths, and not mixed with a and b", {
  f <- fit_sem(mbco_serial_syntax, mediation_demo)
  expect_error(mbco_sem(f, paths = "a"), "paths")
  expect_error(mbco_sem(f, paths = c("a", "a", "b")), "`paths` must be different parameters")
  expect_error(mbco_sem(f, paths = c("a", "zz")), "'zz' is not a labeled regression path")
  expect_error(mbco_sem(f, "a", "b", paths = c("a", "d")), "either `paths` or `a` and `b`")
  expect_error(mbco_sem(f), "give the paths")
  expect_error(mbco_sem(f, "a"), "paths")
})
