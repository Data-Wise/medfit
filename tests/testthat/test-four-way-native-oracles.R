# The native route against the independent oracles (0.10.0 plan U8, Checkpoint B): `fit_sem()` with the `:` product term
# and `extract_mediation()` of the SEMFit, compared with lavaan's own `:=` parameters, the per-equation OLS hand
# delta method (ML-scaled model SEs; stacked-score HC0 under weights), and the glm route. The oracles and their
# derived tolerances are in helper-four-way-oracle.R; every model has a mediator covariate except the `none` case.
# Planted defects: each oracle's `defect` argument must fail against the native route, and the defects of the shared
# four-way worker (F1 SE gradient, F5 weighted means) must be caught when restored by mutation.

skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")

test_that("the `:` term parses in this build, so none of the native cases below is skipped", {
  expect_true(fwo_native_available())
})

test_that("native, unweighted: estimates and ML-scale SEs equal lavaan `:=` and the hand oracle", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 51, covs)
    for (ms in c(0, 0.7)) {
      r <- fwo_route_native(d, covs, m_star = ms)
      lv <- fwo_lavaan_defined(d, covs, m_star = ms)
      h <- fwo_hand(d, covs, m_star = ms, vcov_type = "ml")
      expect_lt(max(abs(r$est - lv$est)), fwo_tol_optimizer)
      expect_lt(fwo_rel_gap(r$se, lv$se), fwo_tol_optimizer)
      expect_lt(max(abs(r$est - h$est)), fwo_tol_optimizer)
      expect_lt(fwo_rel_gap(r$se, h$se), fwo_tol_optimizer)
    }
  }
})

test_that("native equals the lavaan route and the glm route in components; SEs differ from glm by the n - k scale", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 52, covs)
    rn <- fwo_route_native(d, covs, m_star = 0.4)
    rg <- fwo_route_glm(d, covs, m_star = 0.4)
    rl <- fwo_route_lavaan(d, covs, m_star = 0.4)
    expect_lt(max(abs(rn$est - rg$est)), fwo_tol_optimizer)
    expect_lt(max(abs(rn$est - rl$est)), fwo_tol_optimizer)
    expect_lt(fwo_rel_gap(rn$se, rl$se), fwo_tol_optimizer)
    ratio <- rg$se / rn$se
    b <- fwo_scale_bounds(nrow(d), 2 + length(covs), 4 + length(covs))
    expect_gte(min(ratio), b[1] - fwo_tol_optimizer)
    expect_lte(max(ratio), b[2] + fwo_tol_optimizer)
    # CDE lives in the outcome equation alone: its ratio is exactly the outcome-equation bound
    expect_equal(unname(ratio[["cde"]]), unname(b[2]), tolerance = fwo_tol_optimizer)
  }
})

test_that("native, weighted: sandwich SEs equal the stacked-score HC0 oracle and lavaan's weighted `:=`", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 53, covs)
    r <- fwo_route_native(d, covs, d$w, m_star = 0.3, se_type = "sandwich")
    hj <- fwo_hand(d, covs, d$w, m_star = 0.3, vcov_type = "hc0_joint")
    lv <- fwo_lavaan_defined(d, covs, d$w, m_star = 0.3)
    expect_lt(max(abs(r$est - hj$est)), fwo_tol_optimizer)
    expect_lt(fwo_rel_gap(r$se, hj$se), fwo_tol_optimizer)
    expect_lt(fwo_rel_gap(r$se, lv$se), fwo_tol_optimizer)
  }
})

test_that("native, weighted component parity (F5): native = glm route = lavaan route = closed form, all seven", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 54, covs)
    for (ms in c(0, 0.5)) {
      h <- fwo_hand(d, covs, d$w, m_star = ms, vcov_type = "hc0_joint")
      rn <- fwo_route_native(d, covs, d$w, ms, se_type = "sandwich")
      rg <- fwo_route_glm(d, covs, d$w, ms, se_type = "sandwich")
      rl <- fwo_route_lavaan(d, covs, d$w, ms)
      expect_lt(max(abs(rn$est - h$est)), fwo_tol_optimizer)
      expect_lt(max(abs(rn$est - rg$est)), fwo_tol_optimizer)
      expect_lt(max(abs(rn$est - rl$est)), fwo_tol_optimizer)
    }
  }
  # the covariate-dependent weights make INTref weight-sensitive, so a weight-blind route cannot pass
  d <- fwo_data(2000, 26, "c1")
  expect_gt(abs(fwo_route_native(d, "c1", d$w, se_type = "sandwich")$est[["int_ref"]] -
                  fwo_route_native(d, "c1")$est[["int_ref"]]), 0.05)
})

test_that("native sandwich (stacked HC0) and glm sandwich (per-equation HC3) each match their own oracle only", {
  # the two sandwiches are different estimators (HC0 stacked-score against HC3 per equation), so they are not equal;
  # the stacked HC0 oracle is the reference for native, the per-equation HC3 oracle for glm
  d <- fwo_data(2000, 55, "c1")
  rn <- fwo_route_native(d, "c1", d$w, se_type = "sandwich")
  rg <- fwo_route_glm(d, "c1", d$w, se_type = "sandwich")
  expect_lt(fwo_rel_gap(rg$se, fwo_hand(d, "c1", d$w, vcov_type = "hc3_block")$se), fwo_tol_arithmetic)
  expect_lt(fwo_rel_gap(rn$se, fwo_hand(d, "c1", d$w, vcov_type = "hc0_joint")$se), fwo_tol_optimizer)
  expect_gt(fwo_rel_gap(rn$se, rg$se), 1e-3)
})

test_that("native information: observed is the default and is what the oracle matches; expected is refused", {
  d <- fwo_data(2000, 56, "c1")
  syn <- "m ~ x + c1\ny ~ x + m + x:m + c1"
  f_default <- suppressWarnings(fit_sem(syn, d))
  f_obs <- suppressWarnings(fit_sem(syn, d, information = "observed"))
  expect_equal(stats::vcov(f_default), stats::vcov(f_obs), tolerance = 1e-12)
  expect_error(suppressWarnings(fit_sem(syn, d, information = "expected")), "information = \"expected\"")
  # the OLS-scale SEs are a different (wrong for this route) reference: the planted scale defect must fail
  r <- fwo_route_native(d, "c1")
  expect_failure(expect_lt(fwo_rel_gap(r$se, fwo_hand(d, "c1", vcov_type = "ols")$se), fwo_tol_optimizer))
})

test_that("planted: every oracle defect fails against the native route", {
  d <- fwo_data(2000, 57, "c1")
  r <- fwo_route_native(d, "c1", m_star = 0.7)
  h <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml")
  expect_lt(fwo_rel_gap(r$se, h$se), fwo_tol_optimizer) # control: the true oracle passes
  bad <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml", defect = "no_cov_term")
  expect_failure(expect_lt(fwo_rel_gap(r$se, bad$se), fwo_tol_optimizer))
  expect_gt(fwo_rel_gap(r$se, bad$se), 0.02) # the F1 size, not rounding
  bad <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml", defect = "wrong_mstar")
  expect_failure(expect_lt(max(abs(r$est - bad$est)), fwo_tol_optimizer))
  bad_lv <- fwo_lavaan_defined(d, "c1", m_star = 0.7, defect = "no_cov_term")
  expect_failure(expect_lt(fwo_rel_gap(r$se, bad_lv$se), fwo_tol_optimizer))
  # weighted: unweighted means, and the per-equation HC0 without cross-equation blocks
  rw <- fwo_route_native(d, "c1", d$w, 0.3, se_type = "sandwich")
  bad_w <- fwo_hand(d, "c1", d$w, 0.3, vcov_type = "hc0_joint", defect = "unweighted_means")
  expect_failure(expect_lt(max(abs(rw$est - bad_w$est)), fwo_tol_optimizer))
  expect_failure(expect_lt(fwo_rel_gap(rw$se, fwo_hand(d, "c1", d$w, 0.3, vcov_type = "hc0_block")$se),
                           fwo_tol_optimizer))
  # model SEs under weights are not the sandwich: a route that forgets se_type = "sandwich" fails the weighted oracle
  rm <- fwo_route_native(d, "c1", d$w, 0.3, se_type = "model")
  expect_failure(expect_lt(fwo_rel_gap(rm$se, fwo_hand(d, "c1", d$w, 0.3, vcov_type = "hc0_joint")$se),
                           fwo_tol_optimizer))
})

test_that("the oracles catch the shared worker's F1 defect through the native route", {
  fx_skip_covr()
  d <- fwo_data(2000, 58, "c1")
  mutated <- sem_mutate(.effect_gradients_interaction, "cov_grad[pn] <- t3 * cm", "cov_grad[pn] <- 0")
  h <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml")
  expect_lt(fwo_rel_gap(fwo_route_native(d, "c1", m_star = 0.7)$se, h$se), fwo_tol_optimizer)
  local_mocked_bindings(.effect_gradients_interaction = mutated)
  bad <- fwo_route_native(d, "c1", m_star = 0.7)
  expect_failure(expect_lt(fwo_rel_gap(bad$se, h$se), fwo_tol_optimizer))
  expect_gt(fwo_rel_gap(bad$se, h$se), 0.02)
})

test_that("the oracles catch the shared worker's F5 defect (unweighted means) through the native route", {
  fx_skip_covr()
  d <- fwo_data(2000, 59, "c1")
  mutated <- sem_mutate(.extract_interaction_mediation_lavaan, "else sum(data[[cv]] * w)/sum(w)",
                        "else mean(data[[cv]])")
  h <- fwo_hand(d, "c1", d$w, vcov_type = "hc0_joint")
  expect_lt(max(abs(fwo_route_native(d, "c1", d$w, se_type = "sandwich")$est - h$est)), fwo_tol_optimizer)
  local_mocked_bindings(.extract_interaction_mediation_lavaan = mutated)
  bad <- fwo_route_native(d, "c1", d$w, se_type = "sandwich")
  expect_failure(expect_lt(max(abs(bad$est - h$est)), fwo_tol_optimizer))
  expect_gt(abs(bad$est[["int_ref"]] - h$est[["int_ref"]]), 0.05)
})

test_that("a product written in either order reaches the same four-way decomposition", {
  d <- fwo_data(1500, 60, "c1")
  a <- suppressWarnings(fit_sem("m ~ x + c1\ny ~ x + m + x:m + c1", d, information = "observed"))
  b <- suppressWarnings(fit_sem("m ~ x + c1\ny ~ x + m + m:x + c1", d, information = "observed"))
  expect_equal(fwo_out(extract_mediation(a, treatment = "x", mediator = "m"))$est,
               fwo_out(extract_mediation(b, treatment = "x", mediator = "m"))$est, tolerance = 1e-12)
})
