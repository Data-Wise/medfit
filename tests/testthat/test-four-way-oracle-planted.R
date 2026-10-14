# Planted defects (0.10.0 plan U8): every oracle must FAIL when its reference is deliberately wrong, and must catch the
# live defects of the code under test (the F1 SE gradient and the F5 weighted means, fixed by U0 and restored here by
# mutation). A comparison that cannot fail proves nothing. `testthat::expect_failure()` inverts an expectation.

skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")

same <- function(a, b) testthat::expect_lt(fwo_rel_gap(a, b), fwo_tol_optimizer) # nolint: object_usage_linter.

test_that("planted: dropping the covariate term from the hand delta method fails against lavaan `:=`", {
  d <- fwo_data(2000, 31, "c1")
  lv <- fwo_lavaan_defined(d, "c1", m_star = 0.7)
  expect_failure(same(fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml", defect = "no_cov_term")$se, lv$se))
  # and by a wide margin: this is the F1 defect, not rounding
  expect_gt(fwo_rel_gap(fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml", defect = "no_cov_term")$se, lv$se), 0.05)
})

test_that("planted: dropping the covariate term from lavaan's `:=` fails against the hand oracle", {
  d <- fwo_data(2000, 32, "c1")
  h <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml")
  bad <- fwo_lavaan_defined(d, "c1", m_star = 0.7, defect = "no_cov_term")
  expect_failure(same(bad$se, h$se))
  expect_failure(expect_lt(max(abs(bad$est - h$est)), fwo_tol_optimizer)) # the estimate of INTref moves too
})

test_that("planted: unweighted covariate means fail the weighted parity (hand and `:=` references)", {
  d <- fwo_data(2000, 33, "c1")
  route <- fwo_route_lavaan(d, "c1", d$w, 0.3)
  bad_h <- fwo_hand(d, "c1", d$w, 0.3, vcov_type = "hc0_joint", defect = "unweighted_means")
  expect_failure(expect_lt(max(abs(route$est - bad_h$est)), fwo_tol_optimizer))
  bad_l <- fwo_lavaan_defined(d, "c1", d$w, 0.3, defect = "unweighted_means")
  expect_failure(expect_lt(max(abs(route$est - bad_l$est)), fwo_tol_optimizer))
  expect_failure(same(route$se, bad_l$se))
})

test_that("planted: ignoring m_star fails against the route at m_star = 0.7", {
  d <- fwo_data(2000, 34, "c1")
  route <- fwo_route_lavaan(d, "c1", m_star = 0.7)
  bad <- fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml", defect = "wrong_mstar")
  expect_failure(expect_lt(max(abs(route$est - bad$est)), fwo_tol_optimizer))
  expect_failure(same(route$se, bad$se))
})

test_that("planted: the per-equation HC0 (no cross-equation blocks) is a wrong reference for a joint sandwich", {
  d <- fwo_data(2000, 35, "c1")
  route <- fwo_route_lavaan(d, "c1", d$w)
  expect_failure(same(route$se, fwo_hand(d, "c1", d$w, vcov_type = "hc0_block")$se))
})

test_that("planted: HC0 is a wrong reference for the glm route's HC3; the OLS scale for the ML scale", {
  d <- fwo_data(2000, 36, "c1")
  r <- fwo_route_glm(d, "c1", d$w, se_type = "sandwich")
  expect_failure(expect_lt(fwo_rel_gap(r$se, fwo_hand(d, "c1", d$w, vcov_type = "hc0_block")$se), fwo_tol_arithmetic))
  rl <- fwo_route_lavaan(d, "c1")
  expect_failure(same(rl$se, fwo_hand(d, "c1", vcov_type = "ols")$se))
})

test_that("the oracles catch the live F1 defect when it is restored in the code under test", {
  fx_skip_covr()
  d <- fwo_data(2000, 37, "c1")
  mutated <- sem_mutate(.effect_gradients_interaction, "cov_grad[pn] <- t3 * cm", "cov_grad[pn] <- 0")
  clean <- fwo_route_lavaan(d, "c1", m_star = 0.7)
  lv <- fwo_lavaan_defined(d, "c1", m_star = 0.7)
  same(clean$se, lv$se)
  local_mocked_bindings(.effect_gradients_interaction = mutated)
  bad <- fwo_route_lavaan(d, "c1", m_star = 0.7)
  expect_failure(same(bad$se, lv$se))
  expect_failure(same(bad$se, fwo_hand(d, "c1", m_star = 0.7, vcov_type = "ml")$se))
  expect_gt(fwo_rel_gap(bad$se, lv$se), 0.02)
})

test_that("the oracles catch the live F5 defect (unweighted means in the lavaan worker) when it is restored", {
  fx_skip_covr()
  d <- fwo_data(2000, 38, "c1")
  mutated <- sem_mutate(.extract_interaction_mediation_lavaan, "else sum(data[[cv]] * w)/sum(w)",
                        "else mean(data[[cv]])")
  h <- fwo_hand(d, "c1", d$w, vcov_type = "hc0_joint")
  same(fwo_route_lavaan(d, "c1", d$w)$se, h$se)
  local_mocked_bindings(.extract_interaction_mediation_lavaan = mutated)
  bad <- fwo_route_lavaan(d, "c1", d$w)
  expect_failure(expect_lt(max(abs(bad$est - h$est)), fwo_tol_optimizer))
  expect_failure(expect_lt(max(abs(bad$est - fwo_lavaan_defined(d, "c1", d$w)$est)), fwo_tol_optimizer))
})

test_that("the glm route's unweighted means (F5 on that route) are caught by the closed-form oracle", {
  fx_skip_covr()
  d <- fwo_data(2000, 39, "c1")
  mutated <- sem_mutate(.interaction_covariate_means, "sum(mm[, cv] * w)/sum(w)", "mean(mm[, cv])")
  h <- fwo_hand(d, "c1", d$w, vcov_type = "hc3_block")
  expect_lt(max(abs(fwo_route_glm(d, "c1", d$w, se_type = "sandwich")$est - h$est)), fwo_tol_arithmetic)
  local_mocked_bindings(.interaction_covariate_means = mutated)
  bad <- fwo_route_glm(d, "c1", d$w, se_type = "sandwich")
  expect_failure(expect_lt(max(abs(bad$est - h$est)), fwo_tol_arithmetic))
})

test_that("the known-answer runs fail for a planted wrong reference and pass for the true one", {
  truth <- fwo_kat_truth()
  design <- fwo_kat_design(400, 7, "c1", FALSE)
  reps <- 300
  tol <- fwo_kat_tolerance(reps)
  good <- fwo_kat_run(fwo_route_hand("ml"), design, truth, 0.7, reps)
  expect_lt(max(abs(good$bias_z)), tol$z)
  expect_lt(max(abs(good$se_ratio - 1)), tol$se)
  # the oracle with the covariate term dropped over-states the SEs of INTref, NDE and TE
  bad <- fwo_kat_run(fwo_route_hand("ml", "no_cov_term"), design, truth, 0.7, reps)
  expect_failure(expect_lt(max(abs(bad$se_ratio - 1)), tol$se))
  # a wrong reference level in the oracle moves the estimates away from the truth
  worse <- fwo_kat_run(fwo_route_hand("ml", "wrong_mstar"), design, truth, 0.7, reps)
  expect_failure(expect_lt(max(abs(worse$bias_z)), tol$z))
  # weighted: unweighted means in the oracle bias INTref (the weights depend on the covariate)
  wd <- fwo_kat_design(400, 8, "c1", TRUE)
  expect_lt(max(abs(fwo_kat_run(fwo_route_hand("hc0_joint"), wd, truth, 0.3, reps)$bias_z)), tol$z)
  unw <- fwo_kat_run(fwo_route_hand("hc0_joint", "unweighted_means"), wd, truth, 0.3, reps)
  expect_failure(expect_lt(max(abs(unw$bias_z)), tol$z))
})
