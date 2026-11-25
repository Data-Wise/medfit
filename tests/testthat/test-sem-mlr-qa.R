# Independent oracle QA for estimator = "MLR" (P1a): models the implementer did not use, and planted defects inside
# the engine (not only on the oracle side). Oracle: lavaan estimator = "MLR", 1e-5 (scaled chi-square relative).

qa_mlr_data <- function(n = 350, seed = 77) {
  set.seed(seed)
  c1 <- stats::rnorm(n)
  c2 <- stats::rexp(n) - 1
  x <- 0.3 * c1 + stats::rchisq(n, 3) - 3
  m1 <- 0.5 * x + 0.2 * c1 + (stats::rexp(n) - 1)
  m2 <- 0.3 * x + 0.3 * m1 + (stats::rchisq(n, 2) - 2) / 2
  m3 <- 0.4 * m2 + 0.1 * c2 + stats::rt(n, 5)
  y <- 0.3 * m3 + 0.2 * m1 + 0.1 * x + 0.2 * c1 + (stats::rexp(n) - 1) * (1 + 0.4 * abs(x))
  data.frame(x, m1, m2, m3, y, c1, c2)
}

qa_mlr_models <- list(
  serial = "m1 ~ x + c1\nm2 ~ m1 + x\nm3 ~ m2 + c2\ny ~ m3 + m1 + x + c1",
  parallel = "m1 ~ a1*x + c1\nm2 ~ a2*x + c1\ny ~ b1*m1 + b2*m2 + x + c1"
)

# max discrepancy of factor, relative scaled statistic, p-value, estimates, SEs against lavaan's MLR
qa_mlr_gap <- function(model, d, fx, ms, inf = "observed", fit = NULL) {
  if (is.null(fit)) fit <- fit_sem(model, d, estimator = "MLR", fixed_x = fx, meanstructure = ms, information = inf)
  ref <- suppressWarnings(lavaan::sem(model, d, estimator = "MLR", fixed.x = fx, meanstructure = ms, information = inf))
  g <- generics::glance(fit)
  fm <- lavaan::fitMeasures(ref, c("chisq.scaled", "chisq.scaling.factor", "pvalue.scaled"))
  keep <- !duplicated(names(lavaan::coef(ref)))
  est <- lavaan::coef(ref)[keep]
  se <- sqrt(diag(lavaan::vcov(ref)))[keep]
  max(abs(g$scaling_factor - fm[["chisq.scaling.factor"]]),
      abs(g$chisq_scaled - fm[["chisq.scaled"]]) / max(1, fm[["chisq.scaled"]]),
      abs(g$p_value_scaled - fm[["pvalue.scaled"]]),
      abs(coef(fit)[names(est)] - est), abs(sqrt(diag(vcov(fit)))[names(se)] - se))
}

test_that("QA: serial and parallel mediation with covariates equal lavaan's MLR (fixed_x, intercepts, information)", {
  skip_if_not_installed("lavaan")
  d <- qa_mlr_data()
  for (nm in names(qa_mlr_models)) {
    for (fx in c(TRUE, FALSE)) {
      for (ms in c(TRUE, FALSE)) {
        for (inf in c("observed", "expected")) {
          expect_lt(qa_mlr_gap(qa_mlr_models[[nm]], d, fx, ms, inf), 1e-5,
                    label = sprintf("%s fixed_x=%s meanstructure=%s information=%s", nm, fx, ms, inf))
        }
      }
    }
  }
})

test_that("QA planted defects inside the engine fail the lavaan comparison", {
  skip_if_not_installed("lavaan")
  d <- qa_mlr_data()
  m <- qa_mlr_models$serial
  expect_lt(qa_mlr_gap(m, d, TRUE, TRUE), 1e-5)
  gap_with <- function(binding, fn) {
    testthat::local_mocked_bindings(.package = "medfit", .env = environment(), !!binding := fn)
    qa_mlr_gap(m, d, TRUE, TRUE)
  }
  # (1) the fixed exogenous moments are not removed from A1 and B1
  f1 <- sem_mutate(medfit:::.sem_mlr_trace_h1, "keep_cov <- !(idx[, 1L] %in% fixed & idx[, 2L] %in% fixed)",
                   "keep_cov <- rep(TRUE, nrow(idx))")
  # (2) the mean rows are kept for the fixed exogenous variables
  f2 <- sem_mutate(medfit:::.sem_mlr_trace_h1, "keep <- c(!(seq_len(p) %in% fixed), keep_cov)",
                   "keep <- c(rep(TRUE, p), keep_cov)")
  # (3) the robust (sandwich) covariance where the model-based one belongs
  f3 <- sem_mutate(medfit:::.sem_mlr_record, "model_fit@vcov", "fit@vcov")
  # (4) the factor divided by df + 1
  f4 <- sem_mutate(medfit:::.sem_mlr_record, "sfac <- (h1 - h0)/df", "sfac <- (h1 - h0)/(df + 1)")
  expect_gt(gap_with(".sem_mlr_trace_h1", f1), 1e-4)
  expect_gt(gap_with(".sem_mlr_trace_h1", f2), 1e-4)
  expect_gt(gap_with(".sem_mlr_record", f3), 1e-4)
  expect_gt(gap_with(".sem_mlr_record", f4), 1e-4)
})

test_that("QA: a linear inequality row is refused with the constraints class; an inactive single bound is not", {
  set.seed(1)
  n <- 300
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  d <- data.frame(x = x, m = m, y = 0.3 * m + stats::rnorm(n))
  expect_error(fit_sem("m ~ a*x\ny ~ b*m + x\na - b > 0.1", d, estimator = "MLR"), class = "medfit_error_mlr_constraints")
  expect_error(fit_sem("m ~ a*x\ny ~ b*m + x\na > 0.1", d, estimator = "MLR"), NA)
})
