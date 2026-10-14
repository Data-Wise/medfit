# The existing four-way routes against the independent oracles (0.10.0 plan U8 preparation): the lavaan route
# (`extract_mediation()` of a lavaan fit, defects fixed by U0) and the glm route (`fit_mediation()`), with a
# covariate in the mediator equation in every model and one no-covariate model for the simple case. The same
# helpers take the native route (`fwo_route_native()`) in test-four-way-native-oracles.R.

skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")


test_that("lavaan route: estimates and SEs equal lavaan `:=` and the hand oracle at the ML scale", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 21, covs)
    for (ms in c(0, 0.7)) {
      r <- fwo_route_lavaan(d, covs, m_star = ms)
      lv <- fwo_lavaan_defined(d, covs, m_star = ms)
      h <- fwo_hand(d, covs, m_star = ms, vcov_type = "ml")
      expect_lt(max(abs(r$est - lv$est)), fwo_tol_optimizer)
      expect_lt(fwo_rel_gap(r$se, lv$se), fwo_tol_optimizer)
      expect_lt(fwo_rel_gap(r$se, h$se), fwo_tol_optimizer)
    }
  }
})

test_that("glm route: estimates equal the hand oracle, model SEs equal its OLS-scale SEs", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 22, covs)
    r <- fwo_route_glm(d, covs, m_star = 0.4)
    h <- fwo_hand(d, covs, m_star = 0.4, vcov_type = "ols")
    expect_lt(max(abs(r$est - h$est)), fwo_tol_arithmetic)
    expect_lt(fwo_rel_gap(r$se, h$se), fwo_tol_arithmetic)
  }
})

test_that("glm and lavaan SEs differ only by the n versus n - k scaling, within the derived bounds", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 23, covs)
    ratio <- fwo_route_glm(d, covs)$se / fwo_route_lavaan(d, covs)$se
    b <- fwo_scale_bounds(nrow(d), 2 + length(covs), 4 + length(covs))
    expect_gte(min(ratio), b[1] - fwo_tol_optimizer)
    expect_lte(max(ratio), b[2] + fwo_tol_optimizer)
  }
})

test_that("weighted: lavaan route SEs equal the stacked HC0 oracle and lavaan's weighted `:=`", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 24, covs)
    r <- fwo_route_lavaan(d, covs, d$w, m_star = 0.3)
    hj <- fwo_hand(d, covs, d$w, m_star = 0.3, vcov_type = "hc0_joint")
    lv <- fwo_lavaan_defined(d, covs, d$w, m_star = 0.3)
    expect_lt(fwo_rel_gap(r$se, hj$se), fwo_tol_optimizer)
    expect_lt(fwo_rel_gap(r$se, lv$se), fwo_tol_optimizer)
  }
})

test_that("weighted: glm route sandwich SEs equal the per-equation HC3 oracle", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 25, covs)
    r <- fwo_route_glm(d, covs, d$w, m_star = 0.3, se_type = "sandwich")
    h <- fwo_hand(d, covs, d$w, m_star = 0.3, vcov_type = "hc3_block")
    expect_lt(fwo_rel_gap(r$se, h$se), fwo_tol_arithmetic)
  }
})

test_that("weighted component parity (F5): lavaan route = glm route = closed-form oracle for all seven effects", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 26, covs)
    for (ms in c(0, 0.5)) {
      h <- fwo_hand(d, covs, d$w, m_star = ms, vcov_type = "hc0_joint")
      rl <- fwo_route_lavaan(d, covs, d$w, ms)
      rg <- fwo_route_glm(d, covs, d$w, ms, se_type = "sandwich")
      expect_lt(max(abs(rl$est - h$est)), fwo_tol_optimizer)
      expect_lt(max(abs(rg$est - h$est)), fwo_tol_arithmetic)
      expect_lt(max(abs(rl$est - rg$est)), fwo_tol_optimizer)
    }
  }
  # the fixture makes the weighted and plain covariate means differ, so INTref is not weight-blind
  d <- fwo_data(2000, 26, "c1")
  expect_gt(abs(fwo_route_glm(d, "c1", d$w, se_type = "sandwich")$est[["int_ref"]] -
                  fwo_route_glm(d, "c1")$est[["int_ref"]]), 0.05)
})

test_that("with two covariates the covariate gradient has one term per coefficient", {
  d <- fwo_data(2000, 27, c("c1", "c2"))
  h <- fwo_hand(d, c("c1", "c2"))
  expect_equal(unname(h$grad["int_ref", c("m:c1", "m:c2")]),
               unname(h$par[["y:xm"]] * h$cbar[c("c1", "c2")]), tolerance = fwo_tol_arithmetic)
})
