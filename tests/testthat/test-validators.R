# S7 validator branch coverage.
#
# CLAUDE.md lists S7 validation as a critical path targeting 100%. Coverage
# showed 43 validator branches never reached: each is a `return("<message>")`
# in R/classes.R, so the message itself is the oracle -- no expected value is
# invented here.
#
# Each helper builds a valid construction and swaps in exactly one bad field,
# so a failure names the branch it came from rather than a whole argument list.

# --- Valid bases, one overridable field -----------------------------------

bad_md <- function(...) {
  args <- list(
    a_path = 0.5, b_path = 0.3, c_prime = 0.2,
    estimates = c(a = 0.5, b = 0.3, c_prime = 0.2), vcov = diag(3) * 0.01,
    sigma_m = NULL, sigma_y = NULL, family_m = NULL, family_y = NULL,
    treatment = "X", mediator = "M", outcome = "Y",
    mediator_predictors = "X", outcome_predictors = c("X", "M"),
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "stats"
  )
  ov <- list(...)
  args[names(ov)] <- ov
  do.call(MediationData, args)
}

bad_serial <- function(...) {
  args <- list(
    a_path = 0.4, d_path = 0.5, b_path = 0.3, c_prime = 0.2,
    estimates = c(a = 0.4, d = 0.5, b = 0.3, c_prime = 0.2),
    vcov = diag(4) * 0.01, sigma_mediators = NULL, sigma_y = NULL,
    treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
    mediator_predictors = list(M1 = "X", M2 = c("X", "M1")),
    outcome_predictors = c("X", "M1", "M2"),
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "medfit"
  )
  ov <- list(...)
  args[names(ov)] <- ov
  do.call(SerialMediationData, args)
}

bad_boot <- function(...) {
  args <- list(
    estimate = 0.15, ci_lower = 0.05, ci_upper = 0.25, ci_level = 0.95,
    boot_estimates = seq(0.05, 0.25, length.out = 100), n_boot = 100L,
    method = "parametric", call = NULL
  )
  ov <- list(...)
  args[names(ov)] <- ov
  do.call(BootstrapResult, args)
}

bad_parallel <- function(...) {
  args <- list(
    a_paths = c(0.4, 0.3), b_paths = c(0.5, 0.2), c_prime = 0.2,
    estimates = c(a1 = 0.4, a2 = 0.3, b1 = 0.5, b2 = 0.2, c_prime = 0.2),
    vcov = diag(5) * 0.01, sigma_mediators = NULL, sigma_y = NULL,
    treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
    mediator_predictors = list(M1 = "X", M2 = "X"),
    outcome_predictors = c("X", "M1", "M2"),
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "medfit"
  )
  ov <- list(...)
  args[names(ov)] <- ov
  do.call(ParallelMediationData, args)
}

bad_interaction <- function(...) {
  a <- 0.5
  b <- 0.4
  cp <- 0.3
  th3 <- 0.2
  ms <- 0
  args <- list(
    a_path = a, b_path = b, c_prime = cp, interaction = th3,
    cde = cp + th3 * ms, int_ref = th3 * (1 - ms),
    int_med = th3 * a, pie = b * a,
    nde = cp + th3 * ms + th3 * (1 - ms), nie = th3 * a + b * a,
    total_effect = cp + th3 * ms + th3 * (1 - ms) + th3 * a + b * a,
    m_star = ms,
    estimates = c(a = a, b = b, c_prime = cp, theta3 = th3, b0 = 1),
    vcov = diag(5) * 0.01, sigma_m = NULL, sigma_y = NULL,
    treatment = "X", mediator = "M", outcome = "Y",
    mediator_predictors = "X", outcome_predictors = c("X", "M", "X:M"),
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "medfit"
  )
  ov <- list(...)
  args[names(ov)] <- ov
  do.call(InteractionMediationData, args)
}

test_that("the valid bases these tests perturb are themselves valid", {
  # Without this, a typo in a base would make every expect_error() below pass
  # for the wrong reason.
  expect_s7_class(bad_md(), MediationData)
  expect_s7_class(bad_serial(), SerialMediationData)
  expect_s7_class(bad_boot(), BootstrapResult)
  expect_s7_class(bad_parallel(), ParallelMediationData)
  expect_s7_class(bad_interaction(), InteractionMediationData)
})

# --- MediationData ---------------------------------------------------------

test_that("MediationData validator rejects non-scalar paths", {
  expect_error(bad_md(b_path = c(0.3, 0.4)), "b_path must be a scalar")
  expect_error(bad_md(c_prime = c(0.2, 0.3)), "c_prime must be a scalar")
})

test_that("MediationData validator rejects a negative sigma_y", {
  expect_error(bad_md(sigma_y = -1), "sigma_y must be a non-negative")
})

test_that("MediationData validator rejects a list that is not a family", {
  # The property is typed `class_list | NULL`, so a character is caught by S7's
  # own type check; only a plain list reaches this validator branch.
  expect_error(bad_md(family_m = list(a = 1)), "family_m must be a stats")
  expect_error(bad_md(family_y = list(a = 1)), "family_y must be a stats")
})

test_that("MediationData validator rejects non-scalar variable names", {
  expect_error(bad_md(treatment = c("X", "Z")), "treatment must be a single")
  expect_error(bad_md(mediator = c("M", "M2")), "mediator must be a single")
  expect_error(bad_md(outcome = c("Y", "Y2")), "outcome must be a single")
})

test_that("MediationData validator rejects a non-scalar converged flag", {
  expect_error(bad_md(converged = c(TRUE, FALSE)), "converged must be a single")
})

# --- SerialMediationData ---------------------------------------------------

test_that("SerialMediationData validator rejects non-scalar paths", {
  expect_error(bad_serial(b_path = c(0.3, 0.4)), "b_path must be a scalar")
  expect_error(bad_serial(c_prime = c(0.2, 0.3)), "c_prime must be a scalar")
})

test_that("SerialMediationData validator rejects malformed vcov", {
  expect_error(bad_serial(vcov = matrix(0.01, nrow = 4, ncol = 3)),
               "vcov must be a square")
  expect_error(bad_serial(estimates = c(a = 0.4, d = 0.5, b = 0.3)),
               "Number of estimates must match vcov")
})

test_that("SerialMediationData validator rejects negative residual scales", {
  expect_error(bad_serial(sigma_mediators = c(1, -1)),
               "sigma_mediators values must be non-negative")
  expect_error(bad_serial(sigma_y = -0.5), "sigma_y must be a non-negative")
})

test_that("SerialMediationData validator rejects non-scalar variable names", {
  expect_error(bad_serial(treatment = c("X", "Z")), "treatment must be a single")
  expect_error(bad_serial(outcome = c("Y", "Y2")), "outcome must be a single")
})

# NOTE: SerialMediationData's and ParallelMediationData's
# "mediator_predictors must be a list" branches are unreachable -- both
# properties are typed `S7::class_list`, so S7's own type check rejects a
# non-list before the validator runs. They are dead code, not missing coverage.

test_that("SerialMediationData validator rejects a non-positive n_obs", {
  expect_error(bad_serial(n_obs = 0L), "n_obs must be a positive integer")
})

test_that("SerialMediationData validator rejects data disagreeing with n_obs", {
  expect_error(
    bad_serial(data = data.frame(X = 1:5, M1 = 1:5, M2 = 1:5, Y = 1:5),
               n_obs = 100L),
    "rows in data must match n_obs"
  )
})

test_that("SerialMediationData validator rejects a non-scalar converged flag", {
  expect_error(bad_serial(converged = c(TRUE, FALSE)), "converged must be a single")
})

# --- BootstrapResult -------------------------------------------------------

test_that("BootstrapResult validator rejects non-scalar estimates and bounds", {
  expect_error(bad_boot(estimate = c(0.1, 0.2)), "estimate must be a scalar")
  expect_error(bad_boot(ci_lower = c(0.0, 0.1)), "ci_lower must be a scalar")
  expect_error(bad_boot(ci_upper = c(0.3, 0.4)), "ci_upper must be a scalar")
})

test_that("BootstrapResult validator rejects a non-scalar ci_level", {
  expect_error(bad_boot(ci_level = c(0.90, 0.95)), "ci_level must be a scalar")
})

test_that("BootstrapResult validator rejects a non-scalar method", {
  # Regression guard: the method scalar check must run before any
  # `self@method != "plugin"` branch, or a length-2 method raises R's
  # "the condition has length > 1" instead of this message.
  expect_error(bad_boot(method = c("parametric", "plugin")),
               "method must be a single character")
  expect_error(bad_boot(method = "bogus"), "method must be 'parametric'")
})

test_that("BootstrapResult validator constrains n_boot", {
  expect_error(bad_boot(n_boot = c(100L, 200L)), "n_boot must be a single integer")
  # Zero is allowed for the plugin method, which draws no resamples, so the
  # positivity branch is specific to the two resampling methods.
  expect_error(bad_boot(n_boot = 0L, method = "parametric"),
               "n_boot must be positive")
})

# --- ParallelMediationData -------------------------------------------------

test_that("ParallelMediationData validator rejects a b_paths arity mismatch", {
  expect_error(bad_parallel(b_paths = c(0.5, 0.2, 0.1)),
               "b_paths must have length 2")
})

test_that("ParallelMediationData validator rejects a non-scalar c_prime", {
  expect_error(bad_parallel(c_prime = c(0.2, 0.3)), "c_prime must be a scalar")
})

test_that("ParallelMediationData validator rejects negative sigma_mediators", {
  expect_error(bad_parallel(sigma_mediators = c(1, -1)),
               "sigma_mediators values must be non-negative")
})

test_that("ParallelMediationData validator rejects non-scalar variable names", {
  expect_error(bad_parallel(treatment = c("X", "Z")), "treatment must be a single")
  expect_error(bad_parallel(outcome = c("Y", "Y2")), "outcome must be a single")
})

test_that("ParallelMediationData validator rejects a predictor-map arity mismatch", {
  expect_error(bad_parallel(mediator_predictors = list(M1 = "X")),
               "mediator_predictors must have length 2")
})

# --- InteractionMediationData ----------------------------------------------

test_that("InteractionMediationData validator rejects a non-scalar component", {
  expect_error(bad_interaction(nde = c(0.4, 0.5)), "must be a scalar")
})

test_that("InteractionMediationData validator rejects an estimates/vcov mismatch", {
  expect_error(bad_interaction(vcov = diag(4) * 0.01),
               "Number of estimates must match vcov")
})

test_that("InteractionMediationData validator rejects non-scalar variable names", {
  expect_error(bad_interaction(treatment = c("X", "Z")),
               "must each be a single string")
})

test_that("InteractionMediationData validator rejects negative residual scales", {
  expect_error(bad_interaction(sigma_m = -1), "sigma_m must be a non-negative")
  expect_error(bad_interaction(sigma_y = -1), "sigma_y must be a non-negative")
})
