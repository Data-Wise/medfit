# estimator = "MLR" (P1a): the ML estimates, the sandwich standard errors and the Yuan-Bentler scaled chi-square, the
# test lavaan's estimator = "MLR" reports by default (test = "yuan.bentler.mplus"). Oracle: lavaan on complete data at
# 1e-5. The Satorra-Bentler (MLM) factor is a different number and must fail the same comparison.

# Skewed, heavy-tailed data, so that the scaling factor is far from 1 and a normal-theory shortcut shows.
mlr_data <- function(n = 400, seed = 20261125) {
  set.seed(seed)
  x <- stats::rexp(n) - 1
  m1 <- 0.5 * x + stats::rexp(n) - 1
  m2 <- 0.3 * x + 0.2 * m1 + (stats::rchisq(n, 2) - 2) / 2
  y <- 0.4 * m1 + 0.3 * m2 + 0.1 * x + (stats::rexp(n) - 1) * (1 + 0.5 * abs(x))
  data.frame(x = x, m1 = m1, m2 = m2, y = y, z = stats::rnorm(n))
}

mlr_models <- list(
  over = "m1 ~ x\nm2 ~ x\ny ~ m1 + m2",
  chain = "m1 ~ x\nm2 ~ m1 + x\ny ~ m2",
  cov = "m1 ~ x + z\nm2 ~ x\ny ~ m1 + m2 + z",
  equal = "m1 ~ a*x\nm2 ~ a*x\ny ~ m1 + m2"
)

mlr_lavaan <- function(model, d, fixed_x, meanstructure, information = "observed") {
  suppressWarnings(lavaan::sem(model, d, estimator = "MLR", fixed.x = fixed_x, meanstructure = meanstructure,
                               information = information))
}

# TRUE when the fit's scaled statistic, estimates and standard errors equal lavaan's at 1e-5. The scaled chi-square is
# compared on the relative scale (1e-5 times its size, at least 1): lavaan stops its optimizer about 1e-6 from the
# optimum in the parameters, which moves a scaled statistic near 24 by about 2e-5 while the scaling factor, the
# estimates and the standard errors still agree to 1e-5 absolute.
mlr_agrees <- function(fit, ref, tol = 1e-5) {
  g <- generics::glance(fit)
  fm <- lavaan::fitMeasures(ref, c("chisq", "df", "chisq.scaled", "chisq.scaling.factor", "pvalue.scaled"))
  # lavaan lists a shared label once per occurrence; the fit lists it once
  keep <- !duplicated(names(lavaan::coef(ref)))
  est_ref <- lavaan::coef(ref)[keep]
  se_ref <- sqrt(diag(lavaan::vcov(ref)))[keep]
  same_names <- setequal(names(coef(fit)), names(est_ref)) && length(est_ref) == length(coef(fit))
  est_ref <- est_ref[names(coef(fit))]
  se_ref <- se_ref[names(coef(fit))]
  same_names && isTRUE(all(abs(unname(coef(fit)) - unname(est_ref)) < tol)) &&
    isTRUE(all(abs(unname(sqrt(diag(vcov(fit)))) - unname(se_ref)) < tol)) &&
    abs(g$chisq - fm[["chisq"]]) < tol &&
    abs(g$chisq_scaled - fm[["chisq.scaled"]]) < tol * max(1, fm[["chisq.scaled"]]) &&
    abs(g$scaling_factor - fm[["chisq.scaling.factor"]]) < tol &&
    abs(g$p_value_scaled - fm[["pvalue.scaled"]]) < tol
}

test_that("MLR equals lavaan's MLR on skewed data across models, fixed_x and meanstructure (1e-5)", {
  skip_if_not_installed("lavaan")
  d <- mlr_data()
  for (nm in names(mlr_models)) {
    for (fx in c(TRUE, FALSE)) {
      for (ms in c(TRUE, FALSE)) {
        fit <- fit_sem(mlr_models[[nm]], d, estimator = "MLR", fixed_x = fx, meanstructure = ms)
        ref <- mlr_lavaan(mlr_models[[nm]], d, fx, ms)
        expect_true(mlr_agrees(fit, ref), info = sprintf("%s, fixed_x = %s, meanstructure = %s", nm, fx, ms))
      }
    }
  }
  # the factor is not trivially 1 on these data
  g <- generics::glance(fit_sem(mlr_models$over, d, estimator = "MLR"))
  expect_gt(abs(g$scaling_factor - 1), 0.05)
})

test_that("MLR with information = 'expected' equals lavaan's MLR with expected information", {
  skip_if_not_installed("lavaan")
  d <- mlr_data()
  fit <- fit_sem(mlr_models$over, d, estimator = "MLR", information = "expected")
  ref <- mlr_lavaan(mlr_models$over, d, TRUE, TRUE, information = "expected")
  expect_true(mlr_agrees(fit, ref))
})

test_that("MLR keeps the ML estimates and chi-square; the sandwich is the default, se_type = 'model' kept", {
  d <- mlr_data()
  ml <- fit_sem(mlr_models$over, d)
  mlr <- fit_sem(mlr_models$over, d, estimator = "MLR")
  expect_identical(coef(mlr), coef(ml))
  expect_equal(vcov(mlr), vcov(fit_sem(mlr_models$over, d, se_type = "sandwich")), tolerance = 0)
  expect_equal(generics::glance(mlr)$chisq, generics::glance(ml)$chisq, tolerance = 0)
  explicit <- fit_sem(mlr_models$over, d, estimator = "MLR", se_type = "model")
  expect_equal(vcov(explicit), vcov(ml), tolerance = 0)
  expect_equal(generics::glance(explicit)$scaling_factor, generics::glance(mlr)$scaling_factor, tolerance = 1e-8)
})

test_that("planted defect: the Satorra-Bentler (MLM) factor fails the MLR oracle comparison", {
  skip_if_not_installed("lavaan")
  d <- mlr_data()
  fit <- fit_sem(mlr_models$over, d, estimator = "MLR")
  ref <- mlr_lavaan(mlr_models$over, d, TRUE, TRUE)
  expect_true(mlr_agrees(fit, ref))
  mlm <- suppressWarnings(lavaan::sem(mlr_models$over, d, estimator = "MLM", fixed.x = TRUE, meanstructure = TRUE))
  f_mlm <- lavaan::fitMeasures(mlm, "chisq.scaling.factor")[[1L]]
  g <- generics::glance(fit)
  expect_gt(abs(f_mlm - g$scaling_factor), 1e-3)
  # the same comparison, fed the MLM factor and its statistic in place of the fit's, rejects it
  fm <- lavaan::fitMeasures(ref, c("chisq.scaled", "chisq.scaling.factor"))
  planted <- c(chisq_scaled = g$chisq / f_mlm, scaling_factor = f_mlm)
  expect_false(abs(planted[["chisq_scaled"]] - fm[["chisq.scaled"]]) < 1e-5 * max(1, fm[["chisq.scaled"]]) &&
                 abs(planted[["scaling_factor"]] - fm[["chisq.scaling.factor"]]) < 1e-5)
})

test_that("planted defect: a normal-theory saturated trace inside the engine fails the oracle", {
  skip_if_not_installed("lavaan")
  d <- mlr_data()
  ref <- mlr_lavaan(mlr_models$over, d, TRUE, TRUE)
  # the number of saturated parameters: what the trace is when the fourth moments are the normal ones
  testthat::local_mocked_bindings(
    .sem_mlr_trace_h1 = function(x, has_mean, fixed = integer()) {
      p <- ncol(x)
      k <- length(fixed)
      (if (has_mean) p - k else 0) + p * (p + 1) / 2 - k * (k + 1) / 2
    }
  )
  planted <- fit_sem(mlr_models$over, d, estimator = "MLR")
  expect_false(mlr_agrees(planted, ref))
})

test_that("estimator = 'ML' is the default and adds nothing to the fit, glance() or tidy()", {
  d <- mlr_data()
  default <- fit_sem(mlr_models$over, d, se_type = "sandwich")
  explicit <- fit_sem(mlr_models$over, d, se_type = "sandwich", estimator = "ML")
  expect_identical(default@theta, explicit@theta)
  expect_identical(default@vcov, explicit@vcov)
  expect_identical(generics::glance(default), generics::glance(explicit))
  expect_identical(generics::tidy(default), generics::tidy(explicit))
  expect_false(any(c("chisq_scaled", "scaling_factor", "p_value_scaled") %in% names(generics::glance(explicit))))
  expect_null(explicit@diagnostics$estimator)
})

test_that("MLR with df = 0 reports the plain chi-square and an NA factor, as lavaan does", {
  skip_if_not_installed("lavaan")
  d <- mlr_data()
  m <- "m1 ~ x\ny ~ m1 + x"
  g <- generics::glance(fit_sem(m, d, estimator = "MLR"))
  fm <- lavaan::fitMeasures(mlr_lavaan(m, d, TRUE, TRUE), c("chisq.scaled", "chisq.scaling.factor"))
  expect_equal(g$chisq_scaled, fm[["chisq.scaled"]], tolerance = 1e-8)
  expect_true(is.na(g$scaling_factor) && is.na(fm[["chisq.scaling.factor"]]))
})

test_that("MLR on a latent-variable model equals lavaan's MLR", {
  skip_if_not_installed("lavaan")
  set.seed(7)
  n <- 500
  f <- stats::rexp(n) - 1
  d <- data.frame(y1 = f + stats::rexp(n) - 1, y2 = 0.8 * f + stats::rexp(n) - 1, y3 = 1.1 * f + stats::rexp(n) - 1,
                  x = stats::rnorm(n))
  d$y1 <- d$y1 + 0.3 * d$x
  m <- "f =~ y1 + y2 + y3\nf ~ x"
  expect_true(mlr_agrees(fit_sem(m, d, estimator = "MLR"), mlr_lavaan(m, d, TRUE, TRUE)))
})

test_that("an equality constraint is carried through the scaled statistic (lavaan oracle)", {
  skip_if_not_installed("lavaan")
  d <- mlr_data()
  fit <- fit_sem(mlr_models$equal, d, estimator = "MLR")
  expect_true(mlr_agrees(fit, mlr_lavaan(mlr_models$equal, d, TRUE, TRUE)))
})

test_that("fit_mediation(engine = 'sem') forwards the estimator through engine_args", {
  d <- mlr_data()
  m <- "m1 ~ x\ny ~ m1 + x"
  fm <- fit_mediation(model = m, data = d, treatment = "x", mediator = "m1", engine = "sem",
                      se_type = "sandwich", engine_args = list(estimator = "MLR", outcome = "y"))
  sw <- fit_mediation(model = m, data = d, treatment = "x", mediator = "m1", engine = "sem", se_type = "sandwich",
                      engine_args = list(outcome = "y"))
  expect_equal(fm@vcov, sw@vcov, tolerance = 0)
  expect_error(fit_mediation(model = m, data = d, treatment = "x", mediator = "m1", engine = "sem",
                             engine_args = list(estimator = "MLM", outcome = "y")), class = "medfit_error_estimator")
})

test_that("a product term that invalidates the model test leaves the scaled statistic NA with the note", {
  d <- mlr_data()
  d$xm <- d$x * d$m1
  m <- "m1 ~ x\ny ~ m1 + x + x:m1"
  g <- suppressWarnings(generics::glance(fit_sem(m, d, estimator = "MLR")))
  expect_true(all(is.na(c(g$chisq, g$chisq_scaled, g$scaling_factor, g$p_value_scaled))))
  expect_false(is.null(attr(g, "note")))
})

test_that("each MLR refusal is a classed error with its reason", {
  d <- mlr_data()
  m <- mlr_models$over
  expect_error(fit_sem(m, d, estimator = "MLM"), class = "medfit_error_estimator")
  expect_error(fit_sem(m, d, estimator = c("ML", "MLR", "x")), class = "medfit_error_estimator")
  expect_error(fit_sem(m, d, estimator = "MLR", weights = rep(1, nrow(d))), class = "medfit_error_mlr_weights")
  expect_error(fit_sem(m, d, estimator = "MLR", weights = rep(1, nrow(d))), "weights", fixed = TRUE)
  expect_error(fit_sem(m, d, estimator = "MLR", missing = "fiml"), class = "medfit_error_mlr_missing")
  expect_error(fit_sem(m, d, estimator = "MLR", missing = "fiml"), "fiml", fixed = TRUE)
  d$id <- rep(1:40, each = 10)
  expect_error(fit_sem("level: 1\nm1 ~ x\nlevel: 2\nm1 ~ z", d, estimator = "MLR", cluster = "id"),
               class = "medfit_error_mlr_twolevel")
  expect_error(fit_sem(m, d, estimator = "MLR", cluster = "id"), "two-level", fixed = TRUE)
  expect_error(fit_sem(paste0("m1 ~ a*x\ny ~ b*m1 + cp*x\n", "cp == a*b"), d, estimator = "MLR"),
               class = "medfit_error_mlr_constraints")
  expect_error(fit_sem("m1 ~ a*x\ny ~ b*m1 + x\na*b > 0.1", d, estimator = "MLR"),
               class = "medfit_error_mlr_constraints")
  expect_error(fit_sem("m1 ~ a*x\ny ~ b*m1 + x\na*b == 0", d, estimator = "MLR"),
               "linear equality", fixed = TRUE)
  # an estimate on a bound is refused after the fit, naming the parameter
  b <- data.frame(x = stats::rnorm(200))
  b$y <- 0.01 * b$x + stats::rnorm(200)
  expect_error(fit_sem("y ~ x\ny ~~ lower(1.5)*y", b, estimator = "MLR"), class = "medfit_error_mlr_bounds")
  expect_error(fit_sem("y ~ x\ny ~~ lower(1.5)*y", b, estimator = "MLR"), "y~~y", fixed = TRUE)
})
