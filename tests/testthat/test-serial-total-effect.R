# te() / pm() for SerialMediationData sum every X -> Y path, not just the chain
# (SPEC-serial-total-effect-2026-09-24.md).

serial_te_data <- function(n = 500, seed = 1) {
  set.seed(seed)
  C <- stats::rnorm(n)
  X <- stats::rnorm(n)
  M1 <- 0.5 * X + 0.3 * C + stats::rnorm(n)
  M2 <- 0.4 * M1 + 0.6 * X + 0.2 * C + stats::rnorm(n)
  M3 <- 0.3 * M2 + 0.2 * M1 + 0.1 * X + stats::rnorm(n)
  Y <- 0.3 * M3 + 0.2 * M2 + 0.5 * M1 + 0.1 * X + 0.2 * C + stats::rnorm(n)
  data.frame(X, M1, M2, M3, Y, C)
}

serial_hand <- function(mediator_predictors, outcome_predictors, estimates) {
  SerialMediationData(
    a_path = 0.5, d_path = 0.4, b_path = 0.3, c_prime = 0.1,
    estimates = estimates, vcov = diag(length(estimates)) * 0.01,
    sigma_mediators = c(1, 1), sigma_y = 1,
    treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
    mediator_predictors = mediator_predictors,
    outcome_predictors = outcome_predictors,
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "test"
  )
}

test_that("serial te() equals the reduced-form X coefficient (k = 2 and k = 3)", {
  d <- serial_te_data()
  ref <- unname(stats::coef(stats::lm(Y ~ X + C, data = d))["X"])
  f1 <- stats::lm(M1 ~ X + C, data = d)
  f2 <- stats::lm(M2 ~ X + M1 + C, data = d)

  s2 <- extract_mediation(f1, model_y = stats::lm(Y ~ X + M1 + M2 + C, data = d),
                          mediator_models = list(f2), treatment = "X",
                          mediator = c("M1", "M2"))
  expect_equal(as.numeric(te(s2)), ref, tolerance = 1e-10)
  # the chain + c' alone is far from the total here
  expect_gt(abs(as.numeric(te(s2)) - (as.numeric(nie(s2)) + s2@c_prime)), 0.1)

  f3 <- stats::lm(M3 ~ X + M1 + M2 + C, data = d)
  s3 <- extract_mediation(f1, model_y = stats::lm(Y ~ X + M1 + M2 + M3 + C, data = d),
                          mediator_models = list(f2, f3), treatment = "X",
                          mediator = c("M1", "M2", "M3"))
  expect_equal(as.numeric(te(s3)), ref, tolerance = 1e-10)
  expect_true(all(c("a2", "a3", "d1_3", "b1", "b2") %in% names(s3@estimates)))
  expect_true(all(c("a2", "a3", "d1_3", "b1", "b2") %in% rownames(s3@vcov)))
})

test_that("serial effects are additive and pm() is total indirect over total", {
  d <- serial_te_data()
  s <- extract_mediation(stats::lm(M1 ~ X + C, data = d),
                         model_y = stats::lm(Y ~ X + M1 + M2 + C, data = d),
                         mediator_models = list(stats::lm(M2 ~ X + M1 + C, data = d)),
                         treatment = "X", mediator = c("M1", "M2"))
  tot <- as.numeric(te(s))
  expect_equal(as.numeric(nie(s, type = "total")) + as.numeric(nde(s)), tot)
  expect_equal(as.numeric(nie(s)), s@a_path * s@d_path * s@b_path)  # chain default
  expect_equal(as.numeric(pm(s)), (tot - s@c_prime) / tot)

  eff <- coef(s, type = "effects")
  expect_equal(unname(eff["indirect_total"] + eff["direct"]), unname(eff["total"]))

  td <- generics::tidy(s, type = "effects", conf.int = TRUE)
  expect_equal(td$term, c("nie", "nie_total", "nde", "te"))
  expect_true(all(is.finite(td$std.error)))
  gl <- generics::glance(s)
  expect_equal(gl$nie_total + gl$nde, gl$te)
})

test_that("absent skip paths are structural zeros", {
  d <- serial_te_data()
  s <- extract_mediation(stats::lm(M1 ~ X + C, data = d),
                         model_y = stats::lm(Y ~ X + M2 + C, data = d),
                         mediator_models = list(stats::lm(M2 ~ X + M1 + C, data = d)),
                         treatment = "X", mediator = c("M1", "M2"),
                         structure = "serial")
  expect_false("b1" %in% names(s@estimates))
  expect_equal(as.numeric(te(s)),
               s@a_path * s@d_path * s@b_path + s@estimates[["a2"]] * s@b_path +
                 s@c_prime)

  chain <- serial_hand(list("X", "M1"), c("X", "M2"),
                       c(a = 0.5, d1 = 0.4, b = 0.3, c_prime = 0.1))
  expect_equal(as.numeric(te(chain)), 0.5 * 0.4 * 0.3 + 0.1)
})

test_that("hand-built objects with skip coefficients use them", {
  s <- serial_hand(list("X", c("X", "M1")), c("X", "M1", "M2"),
                   c(a = 0.5, d1 = 0.4, b = 0.3, c_prime = 0.1, a2 = 0.2, b1 = 0.25))
  expect_equal(as.numeric(te(s)), 0.1 + 0.5 * 0.25 + 0.2 * 0.3 + 0.5 * 0.4 * 0.3)
})

test_that("te()/pm() return NA with a warning when a skip path is unrecorded", {
  s <- serial_hand(list("X", c("X", "M1")), c("X", "M1", "M2"),
                   c(a = 0.5, d1 = 0.4, b = 0.3, c_prime = 0.1))
  expect_warning(out <- te(s), "no coefficient 'a2'")
  expect_true(is.na(out))
  expect_warning(expect_true(is.na(pm(s))), "Total effect is unavailable")
  expect_equal(as.numeric(nie(s)), 0.5 * 0.4 * 0.3)  # chain still available

  no_preds <- serial_hand(list("X", "M1"), character(0), c(a = 0.5, d1 = 0.4, b = 0.3))
  expect_warning(expect_true(is.na(te(no_preds))), "not recorded")
})

test_that("lavaan serial te() matches lm with labeled skip paths", {
  skip_if_not_installed("lavaan")
  d <- serial_te_data()
  fit <- lavaan::sem("M1 ~ X + C
                      M2 ~ xa2*X + dd*M1 + C
                      Y ~ cp*X + xb1*M1 + M2 + C", data = d)
  sl <- extract_mediation(fit, treatment = "X", mediator = c("M1", "M2"), outcome = "Y")
  ref <- unname(stats::coef(stats::lm(Y ~ X + C, data = d))["X"])
  expect_equal(as.numeric(te(sl)), ref, tolerance = 1e-6)
  expect_true(all(c("a2", "b1") %in% rownames(sl@vcov)))
})
