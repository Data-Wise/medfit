# T2: a factor covariate fits exactly as its hand-coded dummies do (the pre-pass is wired into the fit).

fp_data <- function(n = 300L, seed = 5L) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  x <- rnorm(n)
  m <- 0.5 * x + 0.4 * (g == "b") - 0.3 * (g == "c") + rnorm(n)
  y <- 0.4 * m + 0.2 * x + 0.5 * (g == "b") + 0.2 * (g == "c") + rnorm(n)
  d <- data.frame(y = y, m = m, x = x, g = g)
  twin <- d
  twin$g_b <- as.numeric(d$g == "b")
  twin$g_c <- as.numeric(d$g == "c")
  list(factor = d, twin = twin)
}
fp_model <- "m ~ a*x + g\ny ~ b*m + cp*x + g\nind := a*b"
fp_twin_model <- "m ~ a*x + g_b + g_c\ny ~ b*m + cp*x + g_b + g_c\nind := a*b"

test_that("a factor covariate equals the hand-coded dummies: estimates, SEs, logLik", {
  d <- fp_data()
  f1 <- fit_sem(fp_model, d$factor)
  f2 <- fit_sem(fp_twin_model, d$twin)
  expect_equal(f1@table$rhs, f2@table$rhs)
  expect_equal(f1@table$est, f2@table$est, tolerance = 1e-8)
  expect_equal(f1@table$se, f2@table$se, tolerance = 1e-6)
  expect_equal(as.numeric(logLik(f1)), as.numeric(logLik(f2)), tolerance = 1e-8)
  expect_equal(f1@df, f2@df)
  expect_equal(f1@n_obs, f2@n_obs)
})

test_that("the completed table and the RAM hold the dummies, not the factor", {
  f <- fit_sem(fp_model, fp_data()$factor)
  expect_true(all(c("g_b", "g_c") %in% f@internals$ram$obs))
  expect_false("g" %in% f@internals$ram$obs)
  expect_false("g" %in% c(f@table$lhs, f@table$rhs))
  expect_false("g" %in% names(f@data))
})

test_that("a factor covariate matches lavaan on the hand-coded twin", {
  skip_if_not_installed("lavaan")
  d <- fp_data()
  f <- fit_sem(fp_model, d$factor)
  l <- lavaan::sem(fp_twin_model, d$twin, meanstructure = TRUE, fixed.x = FALSE)
  pe <- lavaan::parameterEstimates(l)
  reg <- pe[pe$op == "~", ]
  est <- f@table[f@table$op == "~", ]
  expect_equal(unname(est$est), unname(reg$est), tolerance = 1e-5)
  expect_equal(unname(est$se), unname(reg$se), tolerance = 1e-3)
})

test_that("a character column fits the same as the equivalent factor", {
  d <- fp_data()
  ch <- d$factor
  ch$g <- as.character(ch$g)
  f1 <- fit_sem(fp_model, d$factor)
  f2 <- fit_sem(fp_model, ch)
  expect_equal(f1@table$est, f2@table$est, tolerance = 1e-10)
})

test_that("a model with no factor is unchanged by the pre-pass (same fit as before)", {
  d <- fp_data()$factor
  f <- fit_sem("m ~ a*x\ny ~ b*m + cp*x", d)
  expect_false(any(grepl("^g", f@table$rhs)))
  expect_equal(f@n_obs, nrow(d))
})
