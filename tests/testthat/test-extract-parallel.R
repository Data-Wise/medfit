# Tests for the lm/glm parallel-mediation extractor + structure detection + confint

# Simulate X -> {M1, M2(, M3)} -> Y with correlated mediators (via shared X) so
# the jointly-estimated b_j have a real covariance to check.
sim_parallel <- function(n = 1500, seed = 11, k = 2) {
  set.seed(seed)
  X <- rnorm(n)
  if (k == 2) {
    M1 <- 0.5 * X + rnorm(n)
    M2 <- 0.4 * X + rnorm(n)
    Y  <- 0.6 * M1 + 0.3 * M2 + 0.2 * X + rnorm(n)
    data.frame(X, M1, M2, Y)
  } else {
    M1 <- 0.5 * X + rnorm(n)
    M2 <- 0.4 * X + rnorm(n)
    M3 <- 0.3 * X + rnorm(n)
    Y  <- 0.6 * M1 + 0.3 * M2 + 0.2 * M3 + 0.2 * X + rnorm(n)
    data.frame(X, M1, M2, M3, Y)
  }
}

fit_parallel <- function(d, structure = "parallel") {
  extract_mediation(
    lm(M1 ~ X, d),
    model_y = lm(Y ~ X + M1 + M2, d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(lm(M2 ~ X, d)),
    structure = structure
  )
}

test_that("lm parallel extractor returns ParallelMediationData with recovered paths", {
  d <- sim_parallel()
  mu <- fit_parallel(d)
  expect_s3_class(mu, "medfit::ParallelMediationData")
  expect_equal(unname(mu@a_paths[1]), unname(coef(lm(M1 ~ X, d))["X"]))
  expect_equal(unname(mu@a_paths[2]), unname(coef(lm(M2 ~ X, d))["X"]))
  cy <- coef(lm(Y ~ X + M1 + M2, d))
  expect_equal(unname(mu@b_paths), unname(cy[c("M1", "M2")]))
  expect_equal(unname(mu@c_prime), unname(cy["X"]))
  # nie equals sum(a_j b_j)
  expect_equal(as.numeric(nie(mu)), sum(mu@a_paths * mu@b_paths))
})

test_that("vcov naming contract: b_j jointly estimated, a_j independent", {
  d <- sim_parallel()
  mu <- fit_parallel(d)
  vc <- mu@vcov
  expect_true(all(c("a1", "b1", "a2", "b2", "c_prime") %in% rownames(vc)))
  # b1, b2, c' share the outcome equation -> non-zero covariance
  expect_true(abs(vc["b1", "b2"]) > 0)
  expect_true(abs(vc["b1", "c_prime"]) > 0)
  # a_j come from separate mediator regressions -> zero cross-covariance
  expect_equal(vc["a1", "a2"], 0)
  expect_equal(vc["a1", "b1"], 0)
  expect_equal(vc["a1", "b2"], 0)
  expect_equal(vc["a2", "b1"], 0)
})

test_that("scales to 3 parallel mediators", {
  d <- sim_parallel(k = 3)
  mu <- extract_mediation(
    lm(M1 ~ X, d), model_y = lm(Y ~ X + M1 + M2 + M3, d),
    treatment = "X", mediator = c("M1", "M2", "M3"),
    mediator_models = list(lm(M2 ~ X, d), lm(M3 ~ X, d)),
    structure = "parallel"
  )
  expect_length(mu@a_paths, 3)
  expect_identical(names(paths(mu)),
                   c("a1", "b1", "a2", "b2", "a3", "b3", "c_prime"))
  expect_equal(as.numeric(nie(mu)), sum(mu@a_paths * mu@b_paths))
})

test_that("structure='auto' classifies parallel vs serial, errors on ambiguous", {
  d <- sim_parallel()
  # parallel fits -> parallel
  mu_par <- extract_mediation(
    lm(M1 ~ X, d), model_y = lm(Y ~ X + M1 + M2, d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(lm(M2 ~ X, d))
  )
  expect_s3_class(mu_par, "medfit::ParallelMediationData")

  # serial fits (M2 ~ M1) -> serial
  set.seed(3)
  n <- 800
  X <- rnorm(n)
  M1 <- 0.5 * X + rnorm(n)
  M2 <- 0.6 * M1 + rnorm(n)
  Y <- 0.7 * M2 + 0.2 * X + rnorm(n)
  ds <- data.frame(X, M1, M2, Y)
  mu_ser <- extract_mediation(
    lm(M1 ~ X, ds), model_y = lm(Y ~ M2 + X, ds),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(lm(M2 ~ M1, ds))
  )
  expect_s3_class(mu_ser, "medfit::SerialMediationData")

  # Mixed structure (a chain edge M2~M1 but M3~X) is NOT confidently parallel,
  # so "auto" conservatively defers to serial; the serial worker then emits its
  # specific validation error (predecessor M2 missing from the M3 model).
  set.seed(5)
  n <- 800
  X <- rnorm(n)
  M1 <- 0.5 * X + rnorm(n)
  M2 <- 0.6 * M1 + rnorm(n)
  M3 <- 0.3 * X + rnorm(n)
  Y <- 0.4 * M2 + 0.3 * M3 + 0.2 * X + rnorm(n)
  dm <- data.frame(X, M1, M2, M3, Y)
  expect_error(
    extract_mediation(
      lm(M1 ~ X, dm), model_y = lm(Y ~ X + M2 + M3, dm),
      treatment = "X", mediator = c("M1", "M2", "M3"),
      mediator_models = list(lm(M2 ~ M1, dm), lm(M3 ~ X, dm))
    ),
    "Predecessor mediator"
  )
})

test_that("explicit structure overrides detection and validation is directed", {
  d <- sim_parallel()
  # wrong mediator_models order -> directed error
  expect_error(
    extract_mediation(
      lm(M1 ~ X, d), model_y = lm(Y ~ X + M1 + M2, d),
      treatment = "X", mediator = c("M1", "M2"),
      mediator_models = list(lm(M1 ~ X, d)),  # response M1, not M2
      structure = "parallel"
    ),
    "must be the model for mediator 2"
  )
})

test_that("glm Gaussian outcome works; binomial -> sigma_y NULL", {
  d <- sim_parallel()
  d$Yb <- as.integer(d$Y > stats::median(d$Y))
  mu <- extract_mediation(
    glm(M1 ~ X, family = gaussian(), data = d),
    model_y = glm(Yb ~ X + M1 + M2, family = binomial(), data = d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(glm(M2 ~ X, family = gaussian(), data = d)),
    structure = "parallel"
  )
  expect_s3_class(mu, "medfit::ParallelMediationData")
  expect_null(mu@sigma_y)
  expect_true(mu@converged)
})

test_that("confint paths: shape, names, brackets point estimates", {
  d <- sim_parallel()
  mu <- fit_parallel(d)
  ci <- confint(mu, parm = "paths")
  expect_identical(rownames(ci), c("a1", "b1", "a2", "b2", "c_prime"))
  expect_equal(ncol(ci), 2L)
  p <- paths(mu)
  expect_true(all(ci[, 1] <= p & p <= ci[, 2]))
})

test_that("confint effects uses full delta method (differs from naive sum)", {
  d <- sim_parallel()
  mu <- fit_parallel(d)
  ci <- suppressWarnings(confint(mu, parm = "effects"))
  expect_identical(rownames(ci), c("indirect", "direct", "total"))

  # Reconstruct se_nie via g' Sigma g and compare to the naive per-mediator sum.
  a <- mu@a_paths
  b <- mu@b_paths
  idx <- as.vector(rbind(paste0("a", 1:2), paste0("b", 1:2)))
  g <- as.vector(rbind(b, a))
  var_full <- as.numeric(t(g) %*% mu@vcov[idx, idx] %*% g)
  var_naive <- sum(b^2 * diag(mu@vcov)[paste0("a", 1:2)] +
                     a^2 * diag(mu@vcov)[paste0("b", 1:2)])
  # full includes 2*a1*a2*cov(b1,b2); should differ when cov(b1,b2) != 0
  expect_false(isTRUE(all.equal(var_full, var_naive)))
  # CI width for indirect matches the full-delta se
  half <- (ci["indirect", 2] - ci["indirect", 1]) / 2
  expect_equal(half, stats::qnorm(0.975) * sqrt(var_full), tolerance = 1e-6)
})

test_that("confint method='boot' directs to bootstrap_mediation", {
  d <- sim_parallel()
  mu <- fit_parallel(d)
  expect_error(confint(mu, method = "boot"), "bootstrap_mediation")
})

test_that("delta-method CI has ~nominal coverage (Monte Carlo)", {
  truth <- 0.5 * 0.6 + 0.4 * 0.3  # a1 b1 + a2 b2 = 0.42
  reps <- 300
  covered <- vapply(seq_len(reps), function(r) {
    d <- sim_parallel(n = 800, seed = 1000 + r)
    mu <- fit_parallel(d)
    ci <- suppressWarnings(confint(mu, parm = "effects"))
    ci["indirect", 1] <= truth && truth <= ci["indirect", 2]
  }, logical(1))
  # Expect coverage near 0.95; allow Monte Carlo slack.
  expect_gt(mean(covered), 0.90)
})
