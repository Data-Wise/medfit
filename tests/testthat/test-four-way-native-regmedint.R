# regmedint against the glm route and the native route for the linear four-way decomposition (0.10.0 plan U8).
# regmedint is an independent implementation of the VanderWeele closed forms, so its own reported estimates and SEs are
# a third reference (it is not routed through any medfit code here: `regmedint::regmedint()` is called directly).
#
# Expected relations, derived rather than guessed (plan F11): in the rule-9 class (recursive model, no residual
# covariances, linear mediator and outcome) the native engine's coefficients equal equation-wise OLS and its
# model-based SEs equal the OLS delta-method SEs at the ML scale, i.e. with the residual variance divided by n instead
# of n - k. regmedint's SEs are the OLS delta method (the glm route's). So
#   estimates: regmedint = glm route = native, apart from the optimizer's accuracy (1e-6);
#   SEs: regmedint = glm route up to floating-point arithmetic (1e-8); regmedint / native lies in
#        [sqrt(n / (n - k_m)), sqrt(n / (n - k_y))] (helper `fwo_scale_bounds()`), and exactly the outcome-equation
#        bound sqrt(n / (n - k_y)) for the CDE, which is a function of the outcome equation alone.
# regmedint names: cde = CDE, pnde = NDE, pnie = PIE, tnie = NIE, te = TE (INTref and INTmed are not reported).

skip_if_not_installed("regmedint")
skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")

fw_regmedint <- function(d, covs, m_star) {
  fit <- suppressWarnings(regmedint::regmedint(
    data = d, yvar = "y", avar = "x", mvar = "m", cvar = if (length(covs)) covs else NULL, a0 = 0, a1 = 1,
    m_cde = m_star, c_cond = if (length(covs)) unname(colMeans(d[covs])) else NULL,
    mreg = "linear", yreg = "linear", interaction = TRUE
  ))
  est <- stats::coef(fit)
  se <- sqrt(diag(unclass(stats::vcov(fit))))
  map <- c(cde = "cde", pie = "pnie", nde = "pnde", nie = "tnie", te = "te")
  list(est = stats::setNames(unname(est[map]), names(map)), se = stats::setNames(unname(se[map]), names(map)))
}

test_that("regmedint equals the glm route, the hand OLS oracle, and the native route up to the derived scale", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 71, covs)
    for (ms in c(0, 0.6)) {
      rm <- fw_regmedint(d, covs, ms)
      rg <- fwo_route_glm(d, covs, m_star = ms)
      rn <- fwo_route_native(d, covs, m_star = ms)
      h <- fwo_hand(d, covs, m_star = ms, vcov_type = "ols")
      keys <- names(rm$est)
      expect_lt(max(abs(rm$est - h$est[keys])), fwo_tol_arithmetic)
      expect_lt(fwo_rel_gap(rm$se, h$se[keys]), fwo_tol_arithmetic)
      expect_lt(max(abs(rm$est - rg$est[keys])), fwo_tol_arithmetic)
      expect_lt(fwo_rel_gap(rm$se, rg$se[keys]), fwo_tol_arithmetic)
      expect_lt(max(abs(rm$est - rn$est[keys])), fwo_tol_optimizer)
      ratio <- rm$se / rn$se[keys]
      b <- fwo_scale_bounds(nrow(d), 2 + length(covs), 4 + length(covs))
      expect_gte(min(ratio), b[1] - fwo_tol_optimizer)
      expect_lte(max(ratio), b[2] + fwo_tol_optimizer)
      expect_equal(unname(ratio[["cde"]]), unname(b[2]), tolerance = fwo_tol_optimizer)
    }
  }
})

test_that("planted: the ratio test rejects a route with the wrong scale and a route with a wrong estimate", {
  d <- fwo_data(2000, 72, "c1")
  rm <- fw_regmedint(d, "c1", 0.6)
  rn <- fwo_route_native(d, "c1", m_star = 0.6)
  keys <- names(rm$est)
  b <- fwo_scale_bounds(nrow(d), 3, 5)
  n <- nrow(d)
  # a native route whose SEs were already on the OLS scale (the n - k correction applied twice) gives ratio 1 for the
  # CDE, below the derived outcome-equation bound sqrt(n / (n - 5)): the exact-ratio and the lower-bound checks fail
  se_ols_scale <- rn$se[keys] * sqrt(n / (n - 5))
  expect_failure(expect_equal(unname((rm$se / se_ols_scale)[["cde"]]), unname(b[2]), tolerance = fwo_tol_optimizer))
  expect_failure(expect_gte(min(rm$se / se_ols_scale), b[1] - fwo_tol_optimizer))
  # the CDE ratio is the outcome-equation bound, not the mediator-equation bound
  expect_failure(expect_equal(unname((rm$se / rn$se[keys])[["cde"]]), unname(b[1]), tolerance = fwo_tol_optimizer))
  # a wrong reference level moves every estimate that depends on it
  rbad <- fw_regmedint(d, "c1", 0)
  expect_failure(expect_lt(max(abs(rbad$est - rn$est[keys])), fwo_tol_optimizer))
})
