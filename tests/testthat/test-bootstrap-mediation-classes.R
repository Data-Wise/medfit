# Parametric / plugin bootstrap on the non-MediationData classes.
#
# SerialMediationData, ParallelMediationData, and InteractionMediationData do
# not inherit from MediationData, but each carries name-aligned @estimates and
# @vcov (including the path aliases), which is all the parametric sampler and
# the plugin estimator read.

sim_chain <- function(n = 300, seed = 1) {
  set.seed(seed)
  X <- rnorm(n)
  M1 <- 0.5 * X + rnorm(n)
  M2 <- 0.4 * M1 + rnorm(n)
  Y <- 0.3 * M2 + 0.2 * X + rnorm(n)
  data.frame(X, M1, M2, Y)
}

serial_fit <- function(d) {
  extract_mediation(
    lm(M1 ~ X, d),
    model_y = lm(Y ~ X + M1 + M2, d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(lm(M2 ~ X + M1, d))
  )
}

parallel_fit <- function(d) {
  extract_mediation(
    lm(M1 ~ X, d),
    model_y = lm(Y ~ X + M1 + M2, d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(lm(M2 ~ X, d)),
    structure = "parallel"
  )
}

interaction_fit <- function(n = 300, seed = 2) {
  set.seed(seed)
  X <- rbinom(n, 1, 0.5)
  M <- 0.4 + 0.5 * X + rnorm(n)
  Y <- 0.1 * X + 0.3 * M + 0.25 * X * M + rnorm(n)
  d <- data.frame(X, M, Y)
  extract_mediation(lm(M ~ X, d), model_y = lm(Y ~ X + M + X:M, d),
                    treatment = "X", mediator = "M", outcome = "Y")
}

serial_indirect <- function(theta) unname(theta["a"] * theta["d1"] * theta["b"])
parallel_indirect <- function(theta) {
  unname(theta["a1"] * theta["b1"] + theta["a2"] * theta["b2"])
}

# ------------------------------------------------------------------------------
# SerialMediationData
# ------------------------------------------------------------------------------

test_that("parametric bootstrap accepts SerialMediationData", {
  s <- serial_fit(sim_chain())
  r <- bootstrap_mediation(serial_indirect, method = "parametric",
                           mediation_data = s, n_boot = 500, seed = 7)
  expect_true(S7::S7_inherits(r, BootstrapResult))
  expect_equal(r@estimate, s@a_path * s@d_path * s@b_path)
  expect_length(r@boot_estimates, 500)
  expect_lt(r@ci_lower, r@estimate)
  expect_gt(r@ci_upper, r@estimate)

  r2 <- bootstrap_mediation(serial_indirect, method = "parametric",
                            mediation_data = s, n_boot = 500, seed = 7)
  expect_identical(r@boot_estimates, r2@boot_estimates)
})

test_that("serial alias columns are drawn jointly with their source coefficients", {
  # Positive control: the alias `a` duplicates `m1_X` in the vcov, so every
  # parametric draw must carry the same value in both columns.
  s <- serial_fit(sim_chain())
  r <- bootstrap_mediation(function(t) unname(t["a"] - t["m1_X"]),
                           method = "parametric", mediation_data = s,
                           n_boot = 200, seed = 3)
  expect_lt(max(abs(r@boot_estimates)), 1e-8)
  r_d <- bootstrap_mediation(function(t) unname(t["d1"] - t["m2_M1"]),
                             method = "parametric", mediation_data = s,
                             n_boot = 200, seed = 3)
  expect_lt(max(abs(r_d@boot_estimates)), 1e-8)
})

test_that("plugin method accepts SerialMediationData", {
  s <- serial_fit(sim_chain())
  r <- bootstrap_mediation(serial_indirect, method = "plugin", mediation_data = s)
  expect_equal(r@method, "plugin")
  expect_equal(r@estimate, s@a_path * s@d_path * s@b_path)
  expect_true(is.na(r@ci_lower))
})

# ------------------------------------------------------------------------------
# ParallelMediationData
# ------------------------------------------------------------------------------

test_that("parametric and plugin bootstrap accept ParallelMediationData", {
  p <- parallel_fit(sim_chain())
  r <- bootstrap_mediation(parallel_indirect, method = "parametric",
                           mediation_data = p, n_boot = 500, seed = 11)
  expect_equal(r@estimate, sum(p@a_paths * p@b_paths))
  expect_length(r@boot_estimates, 500)

  alias <- bootstrap_mediation(function(t) unname(t["a2"] - t["m2_X"]),
                               method = "parametric", mediation_data = p,
                               n_boot = 200, seed = 11)
  expect_lt(max(abs(alias@boot_estimates)), 1e-8)

  plug <- bootstrap_mediation(parallel_indirect, method = "plugin",
                              mediation_data = p)
  expect_equal(plug@estimate, r@estimate)
})

# ------------------------------------------------------------------------------
# InteractionMediationData
# ------------------------------------------------------------------------------

test_that("parametric bootstrap accepts InteractionMediationData", {
  imd <- interaction_fit()
  r <- bootstrap_mediation(function(t) unname(t["theta3"]),
                           method = "parametric", mediation_data = imd,
                           n_boot = 300, seed = 5)
  expect_equal(r@estimate, unname(imd@interaction))
  expect_length(r@boot_estimates, 300)
})

# ------------------------------------------------------------------------------
# Rejection of other objects
# ------------------------------------------------------------------------------

test_that("parametric and plugin still reject non-mediation objects", {
  not_med <- BootstrapResult(
    estimate = 0.1, ci_lower = NA_real_, ci_upper = NA_real_,
    ci_level = NA_real_, boot_estimates = numeric(0), n_boot = 0L,
    method = "plugin", call = NULL
  )
  expect_error(
    bootstrap_mediation(function(t) 1, method = "parametric",
                        mediation_data = not_med, n_boot = 10),
    "SerialMediationData"
  )
  expect_error(
    bootstrap_mediation(function(t) 1, method = "plugin",
                        mediation_data = list(estimates = 1)),
    "must be a MediationData"
  )
})
