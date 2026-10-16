# Edge cases of the native four-way route (`fit_sem()` with `x:m`, then `extract_mediation()`) that the main oracle
# files do not use: a continuous treatment, missing values in the factors and the covariate (listwise deletion must
# also drive the covariate mean), a 0/1 dummy covariate, and a factor covariate (refused, not silently dropped). The
# oracle is the per-equation OLS hand delta method and lavaan's own `:=` (helper-four-way-oracle.R).

skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")

edge_close <- function(r, h) {
  testthat::expect_lt(max(abs(r$est - h$est)), fwo_tol_optimizer) # nolint: object_usage_linter.
  testthat::expect_lt(fwo_rel_gap(r$se, h$se), fwo_tol_optimizer) # nolint: object_usage_linter.
}

test_that("a continuous treatment: native equals the hand OLS oracle and lavaan `:=` (m_star 0 and 0.7)", {
  d <- fwo_data(2000, 61, "c1")
  set.seed(61)
  d$x <- rnorm(nrow(d))
  d$m <- 0.3 + 0.5 * d$x + 0.8 * d$c1 + rnorm(nrow(d))
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.3 * d$x * d$m + 0.5 * d$c1 + rnorm(nrow(d))
  d$xm <- d$x * d$m
  for (ms in c(0, 0.7)) {
    r <- fwo_route_native(d, "c1", m_star = ms)
    edge_close(r, fwo_hand(d, "c1", m_star = ms, vcov_type = "ml"))
    edge_close(r, fwo_lavaan_defined(d, "c1", m_star = ms))
  }
  # control: the oracle with the wrong reference level cannot match
  bad <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml", defect = "wrong_mstar")
  expect_failure(expect_lt(max(abs(fwo_route_native(d, "c1", m_star = 0.7)$est - bad$est)), fwo_tol_optimizer))
})

test_that("missing values in x, m, y and the covariate: listwise deletion also drives the covariate mean", {
  d <- fwo_data(2000, 62, "c1")
  # missingness that depends on the covariate, so the complete-case mean differs from the observed-covariate mean
  set.seed(62)
  d$c1[d$c1 < 1.5 & runif(nrow(d)) < 0.9] <- NA
  d$m[d$c1 > 2.2 & !is.na(d$c1) & runif(nrow(d)) < 0.7] <- NA
  d$y[sample(nrow(d), 60)] <- NA
  d$x[sample(nrow(d), 40)] <- NA
  d$xm <- d$x * d$m
  cc <- stats::na.omit(d[c("x", "c1", "m", "y", "xm")])
  expect_lt(nrow(cc), nrow(d) - 100L)
  expect_gt(abs(mean(cc$c1) - mean(d$c1, na.rm = TRUE)), 0.01)
  r <- fwo_route_native(d, "c1")
  edge_close(r, fwo_hand(cc, "c1", vcov_type = "ml"))
  edge_close(r, fwo_lavaan_defined(cc, "c1"))
  # the same fit on the complete cases is identical
  edge_close(r, fwo_route_native(cc, "c1"))
  # planted defect: a covariate mean taken over the rows that were dropped changes int_ref, so the oracle fails
  h_all <- fwo_hand(cc, "c1", vcov_type = "ml")
  h_all$est[["int_ref"]] <- h_all$est[["int_ref"]] + h_all$par[["y:xm"]] * h_all$par[["m:c1"]] *
    (mean(d$c1, na.rm = TRUE) - mean(cc$c1))
  expect_failure(expect_lt(max(abs(r$est - h_all$est)), fwo_tol_optimizer))
})

test_that("a 0/1 dummy covariate in the mediator equation enters through its proportion", {
  d <- fwo_data(2000, 63, "c1")
  set.seed(63)
  d$c1 <- rbinom(nrow(d), 1, 0.3)
  d$m <- 0.3 + 0.5 * d$x + 0.8 * d$c1 + rnorm(nrow(d))
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.3 * d$x * d$m + 0.5 * d$c1 + rnorm(nrow(d))
  d$xm <- d$x * d$m
  r <- fwo_route_native(d, "c1")
  h <- fwo_hand(d, "c1", vcov_type = "ml")
  edge_close(r, h)
  edge_close(r, fwo_lavaan_defined(d, "c1"))
  expect_equal(unname(h$cbar), mean(d$c1))
  # planted defect: centering the dummy at 0.5 instead of its proportion moves int_ref
  moved <- fwo_effects(h$par, "c1", 0.5)
  expect_gt(abs(moved[["int_ref"]] - r$est[["int_ref"]]), 1e-3)
})

test_that("a factor covariate in the mediator equation fits as its dummy-coded twin does", {
  d <- fwo_data(1500, 64, "c1")
  d$g <- factor(ifelse(d$c1 > 2, "hi", "lo"), levels = c("lo", "hi"))
  d$gd <- as.numeric(d$g == "hi")
  d$m <- d$m + 0.7 * d$gd
  d$y <- d$y + 0.4 * d$gd
  d$xm <- d$x * d$m
  f <- suppressWarnings(fit_sem("m ~ x + g\ny ~ x + m + x:m + g", d))
  f_twin <- suppressWarnings(fit_sem("m ~ x + gd\ny ~ x + m + x:m + gd", d))
  expect_equal(unname(f@table$est), unname(f_twin@table$est), tolerance = 1e-8)
  r <- fwo_route_native(d, "gd")
  edge_close(r, fwo_hand(d, "gd", vcov_type = "ml"))
  edge_close(r, fwo_lavaan_defined(d, "gd"))
})
