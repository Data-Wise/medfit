# Opt-in covariate-mean variance for the four-way effects (`options(medfit.covariate_mean_variance = TRUE)`).
# INTref, NDE and TE contain the estimated covariate mean, whose derivative is theta3 * gamma; the default delta-method
# SEs hold it fixed (conditional on the observed covariates). Oracles: the closed form (theta3 * gamma)^2 Var(c) / n
# from hand OLS, and a nonparametric bootstrap on data where the term is material.

cmv_data <- function(n = 300, seed = 5, gamma = 1.2) {
  set.seed(seed)
  d <- data.frame(x = rbinom(n, 1, 0.5), c1 = rnorm(n, 1, 2))
  d$m <- 0.3 + 0.5 * d$x + gamma * d$c1 + rnorm(n)
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.8 * d$x * d$m + 0.5 * d$c1 + rnorm(n)
  d$w <- runif(n, 0.5, 2) * exp(0.2 * d$c1)
  d
}

cmv_fit <- function(d, weights = NULL) {
  suppressMessages(fit_mediation(y ~ x + m + x:m + c1, m ~ x + c1, d, treatment = "x", mediator = "m",
                                 weights = weights))
}

cmv_se <- function(fit, on) {
  withr::local_options(medfit.covariate_mean_variance = if (on) TRUE else NULL)
  medfit:::.effect_se(fit, c("cde", "int_ref", "int_med", "pie", "nde", "nie", "te"))
}

test_that("the default is conditional, and the option adds exactly the closed-form term to INTref, NDE and TE", {
  d <- cmv_data()
  fit <- cmv_fit(d)
  off <- cmv_se(fit, FALSE)
  on <- cmv_se(fit, TRUE)
  t3 <- coef(lm(y ~ x + m + x:m + c1, d))[["x:m"]]
  g <- coef(lm(m ~ x + c1, d))[["c1"]]
  extra <- (t3 * g)^2 * mean((d$c1 - mean(d$c1))^2) / nrow(d)
  for (k in c("int_ref", "nde", "te")) expect_equal(on[[k]]^2 - off[[k]]^2, extra, tolerance = 1e-8)
  # components that do not contain the covariate mean do not move
  for (k in c("cde", "int_med", "pie", "nie")) expect_equal(on[[k]], off[[k]])
  expect_true(all(on >= off))
})

test_that("planted: without the term the option changes nothing", {
  fx_skip_covr()
  d <- cmv_data()
  fit <- cmv_fit(d)
  mutated <- sem_mutate(.cov_mean_variance, "sum(w^2 * (z - z_bar)^2)/sum(w)^2", "0")
  local_mocked_bindings(.cov_mean_variance = mutated)
  expect_equal(cmv_se(fit, TRUE), cmv_se(fit, FALSE))
})

test_that("with the term, the SEs track a nonparametric bootstrap where the conditional SE does not", {
  d <- cmv_data()
  fit <- cmv_fit(d)
  set.seed(9)
  boot <- replicate(250, {
    f <- cmv_fit(d[sample(nrow(d), nrow(d), TRUE), ])
    c(f@int_ref, f@nde, f@total_effect)
  })
  boot_sd <- apply(boot, 1, stats::sd)
  on <- cmv_se(fit, TRUE)[c("int_ref", "nde", "te")]
  off <- cmv_se(fit, FALSE)[c("int_ref", "nde", "te")]
  expect_lt(max(abs(on / boot_sd - 1)), 0.12)
  # the conditional SE of INTref is far below the bootstrap SE here, so the check can fail
  expect_gt(boot_sd[[1]] / off[[1]] - 1, 0.25)
})

test_that("case weights use the weighted-mean variance", {
  d <- cmv_data()
  fit <- cmv_fit(d, weights = d$w)
  on <- cmv_se(fit, TRUE)
  off <- cmv_se(fit, FALSE)
  t3 <- fit@interaction
  g <- fit@estimates[["m_c1"]]
  z <- t3 * g * d$c1
  z_bar <- sum(d$w * z) / sum(d$w)
  extra <- sum(d$w^2 * (z - z_bar)^2) / sum(d$w)^2
  expect_equal(on[["int_ref"]]^2 - off[["int_ref"]]^2, extra, tolerance = 1e-8)
})

test_that("a model with no covariate in the mediator equation is unchanged", {
  d <- cmv_data()
  fit <- suppressMessages(fit_mediation(y ~ x + m + x:m, m ~ x, d, treatment = "x", mediator = "m"))
  expect_equal(cmv_se(fit, TRUE), cmv_se(fit, FALSE))
})

test_that("tidy() and confint() honor the option", {
  d <- cmv_data()
  fit <- cmv_fit(d)
  off <- generics::tidy(fit, type = "components")
  withr::local_options(medfit.covariate_mean_variance = TRUE)
  on <- generics::tidy(fit, type = "components")
  expect_gt(on$std_error[on$term == "int_ref"], off$std_error[off$term == "int_ref"])
  expect_equal(on$std_error[on$term == "cde"], off$std_error[off$term == "cde"])
  ci <- suppressMessages(stats::confint(fit, parm = "components"))
  expect_gt(ci["int_ref", 2] - ci["int_ref", 1], 2 * stats::qnorm(0.975) * off$std_error[off$term == "int_ref"])
})

test_that("the native and lavaan routes add the same term as the glm route", {
  skip_if_not_installed("lavaan")
  d <- cmv_data()
  glm_fit <- cmv_fit(d)
  extra_glm <- cmv_se(glm_fit, TRUE)[["int_ref"]]^2 - cmv_se(glm_fit, FALSE)[["int_ref"]]^2
  native <- suppressWarnings(fit_sem("m ~ x + c1\ny ~ x + m + x:m + c1", d, se_type = "sandwich"))
  nat <- extract_mediation(native, treatment = "x", mediator = "m", decomposition = "four_way")
  extra_nat <- cmv_se(nat, TRUE)[["int_ref"]]^2 - cmv_se(nat, FALSE)[["int_ref"]]^2
  expect_equal(extra_nat, extra_glm, tolerance = 1e-6)
  lv <- suppressWarnings(lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1", transform(d, xm = x * m),
                                     meanstructure = TRUE))
  lav <- extract_mediation(lv, treatment = "x", mediator = "m", interaction = "xm")
  extra_lav <- cmv_se(lav, TRUE)[["int_ref"]]^2 - cmv_se(lav, FALSE)[["int_ref"]]^2
  expect_equal(extra_lav, extra_glm, tolerance = 1e-6)
})
