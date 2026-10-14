# The oracles' own validity (0.10.0 plan U8 preparation): the hand-written delta method against lavaan's own `:=`
# parameters and against sandwich. Nothing here calls `extract_mediation()`; the routes are compared in
# test-four-way-oracle-routes.R. Tolerances and their derivations: helper-four-way-oracle.R.

skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")



test_that("the analytic gradients equal central differences of the effects", {
  for (covs in fwo_cases) {
    h <- fwo_hand(fwo_data(300, 2, covs), covs, m_star = 0.4)
    f <- function(par) fwo_effects(par, covs, h$cbar, 0.4)[fwo_keys]
    num <- t(vapply(seq_along(h$par), function(i) {
      e <- replace(numeric(length(h$par)), i, 1e-5)
      (f(h$par + e) - f(h$par - e)) / 2e-5
    }, numeric(length(fwo_keys))))
    expect_equal(unname(t(num)), unname(h$grad), tolerance = 1e-7)
  }
})

test_that("the stacked HC0 has sandwich::vcovHC(HC0) per equation as its diagonal blocks", {
  d <- fwo_data(500, 3)
  for (w in list(NULL, d$w)) {
    eq <- fwo_fit_eqs(d, "c1", w)
    vj <- fwo_hc0_joint(eq$m, eq$y)
    km <- length(stats::coef(eq$m))
    expect_equal(unname(vj[seq_len(km), seq_len(km)]), unname(sandwich::vcovHC(eq$m, "HC0")),
                 tolerance = fwo_tol_arithmetic)
    expect_equal(unname(vj[-seq_len(km), -seq_len(km)]), unname(sandwich::vcovHC(eq$y, "HC0")),
                 tolerance = fwo_tol_arithmetic)
    # and the cross block is real: it is not zero in a sample
    expect_gt(max(abs(vj[seq_len(km), -seq_len(km)])), 0)
  }
})

test_that("hand estimates and ML-scaled SEs equal lavaan's own `:=` (unweighted)", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 11, covs)
    for (ms in c(0, 0.7)) {
      h <- fwo_hand(d, covs, m_star = ms, vcov_type = "ml")
      lv <- fwo_lavaan_defined(d, covs, m_star = ms)
      expect_lt(max(abs(h$est - lv$est)), fwo_tol_optimizer)
      expect_lt(fwo_rel_gap(h$se, lv$se), fwo_tol_optimizer)
    }
  }
})

test_that("OLS-scale SEs differ from ML-scale only by the n versus n - k factor, within the derived bounds", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 12, covs)
    ratio <- fwo_hand(d, covs, vcov_type = "ols")$se / fwo_hand(d, covs, vcov_type = "ml")$se
    b <- fwo_scale_bounds(nrow(d), 2 + length(covs), 4 + length(covs))
    expect_gte(min(ratio), b[1] - 1e-12)
    expect_lte(max(ratio), b[2] + 1e-12)
  }
  # the ratio is exactly the bound for an effect that lives in one equation: CDE is all in the outcome equation
  d <- fwo_data(2000, 12, "c1")
  r <- fwo_hand(d, "c1", vcov_type = "ols")$se / fwo_hand(d, "c1", vcov_type = "ml")$se
  expect_equal(unname(r[["cde"]]), sqrt(2000 / (2000 - 5)), tolerance = 1e-12)
})

test_that("hand stacked-HC0 SEs equal lavaan's sampling-weights `:=`; per-equation HC0 does not", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 13, covs)
    lv <- fwo_lavaan_defined(d, covs, d$w)
    hj <- fwo_hand(d, covs, d$w, vcov_type = "hc0_joint")
    hb <- fwo_hand(d, covs, d$w, vcov_type = "hc0_block")
    expect_lt(max(abs(hj$est - lv$est)), fwo_tol_optimizer)
    expect_lt(fwo_rel_gap(hj$se, lv$se), fwo_tol_optimizer)
    # the cross-equation blocks are a first-order feature of the sample sandwich (about 1% to 3% here)
    expect_gt(fwo_rel_gap(hb$se, lv$se), 1e-3)
  }
})

test_that("the covariate means are weighted, and the weighted and plain means differ in the fixture", {
  d <- fwo_data(2000, 14)
  h <- fwo_hand(d, "c1", d$w)
  expect_equal(unname(h$cbar), stats::weighted.mean(d$c1, d$w))
  hu <- fwo_hand(d, "c1", d$w, defect = "unweighted_means")
  expect_equal(unname(hu$cbar), mean(d$c1))
  expect_gt(abs(h$est[["int_ref"]] - hu$est[["int_ref"]]), 0.05)
  hand <- unname(h$par[["y:xm"]] * (h$par[["m:(Intercept)"]] + h$par[["m:c1"]] * stats::weighted.mean(d$c1, d$w)))
  expect_equal(unname(h$est[["int_ref"]]), hand, tolerance = fwo_tol_arithmetic)
})

test_that("a no-covariate model keeps the simple case: INTref = theta3 (b0 - m_star)", {
  d <- fwo_data(1000, 15, character(0))
  h <- fwo_hand(d, character(0), m_star = 0.5)
  expect_equal(unname(h$est[["int_ref"]]),
               unname(h$par[["y:xm"]] * (h$par[["m:(Intercept)"]] - 0.5)), tolerance = fwo_tol_arithmetic)
  expect_false(any(grepl("^m:c", names(h$par))))
})
