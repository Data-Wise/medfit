# Observed intercepts end to end (0.9.0 S1): the combined syntax `y ~ 1 + x`, the tri-state `meanstructure`,
# saturated-mean equivalence with the covariance-only fit, and always-on oracles for the intercept SEs.

mean_syntax <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"

test_that("y ~ 1 + x parses to the same rows as two statements, in either order", {
  two <- .sem_parse("y ~ 1\ny ~ x")$parameters
  expect_equal(.sem_parse("y ~ 1 + x")$parameters[, c("lhs", "op", "rhs")], two[, c("lhs", "op", "rhs")])
  last <- .sem_parse("y ~ x + 1")$parameters
  expect_setequal(paste(last$lhs, last$op, last$rhs), paste(two$lhs, two$op, two$rhs))
  mod <- .sem_parse("y ~ a*1 + b*x")$parameters
  expect_identical(mod$label[mod$op == "~1"], "a")
  expect_identical(mod$label[mod$op == "~"], "b")
  fixed <- .sem_parse("y ~ 0*1 + x")$parameters
  expect_equal(fixed$fixed[fixed$op == "~1"], 0)
  both <- .sem_parse("y1, y2 ~ 1 + x")$parameters
  expect_identical(sum(both$op == "~1"), 2L)
})

test_that("a saturated mean structure reproduces the covariance-only fit", {
  cov_only <- fit_sem(mean_syntax, mediation_demo)
  one <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo)
  all_on <- fit_sem(mean_syntax, mediation_demo, meanstructure = TRUE)
  for (fit in list(one, all_on)) {
    expect_identical(length(fit@theta), length(cov_only@theta) + 3L) # three observed variables
    expect_equal(fit@df, cov_only@df)
    expect_equal(fit@f, cov_only@f, tolerance = 1e-6)
    keep <- names(cov_only@theta)
    expect_equal(fit@theta[keep], cov_only@theta, tolerance = 1e-6)
    expect_equal(sqrt(diag(fit@vcov))[keep], sqrt(diag(cov_only@vcov)), tolerance = 1e-6)
  }
  expect_identical(sum(one@table$op == "~1"), 3L)
})

test_that("intercept and mean SEs match an independent OLS oracle", {
  fit <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo)
  est <- fit@theta
  se <- sqrt(diag(fit@vcov))
  n <- nrow(mediation_demo)
  # ML intercept SE = OLS SE * sqrt((n - k) / n) for an observed recursive model (k = coefficients incl. intercept)
  ols_y <- stats::lm(outcome ~ mediator1 + treatment, mediation_demo)
  ols_m <- stats::lm(mediator1 ~ treatment, mediation_demo)
  expect_equal(unname(est["outcome~1"]), unname(stats::coef(ols_y)[1]), tolerance = 1e-5)
  expect_equal(unname(se["outcome~1"]), summary(ols_y)$coefficients[1, 2] * sqrt((n - 3) / n), tolerance = 1e-4)
  expect_equal(unname(se["mediator1~1"]), summary(ols_m)$coefficients[1, 2] * sqrt((n - 2) / n), tolerance = 1e-4)
  # the exogenous mean: SE = sd_ML / sqrt(n)
  x <- mediation_demo$treatment
  expect_equal(unname(est["treatment~1"]), mean(x), tolerance = 1e-6)
  expect_equal(unname(se["treatment~1"]), sqrt(mean((x - mean(x))^2) / n), tolerance = 1e-4)
})

test_that("meanstructure is tri-state: NULL follows the syntax, TRUE saturates, FALSE refuses an intercept", {
  expect_false(fit_sem(mean_syntax, mediation_demo)@internals$ram$has_mean)
  expect_true(fit_sem(mean_syntax, mediation_demo, meanstructure = TRUE)@internals$ram$has_mean)
  expect_true(fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)@internals$ram$has_mean)
  expect_error(fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo, meanstructure = FALSE),
               "meanstructure = FALSE.*writes an intercept")
  expect_error(fit_sem(mean_syntax, mediation_demo, meanstructure = "yes"), "meanstructure")
})

test_that("the combined intercept form fits like the separate statement", {
  sep <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo)
  comb <- fit_sem("mediator1 ~ a*treatment\noutcome ~ 1 + b*mediator1 + cp*treatment", mediation_demo)
  expect_equal(comb@theta[names(sep@theta)], sep@theta, tolerance = 1e-6)
})

test_that("a latent mediator fits with its default mean rows (G7 case A)", {
  syn <- "eta =~ mediator1 + mediator2 + mediator3\neta ~ a*treatment\noutcome ~ b*eta + cp*treatment"
  cov_only <- fit_sem(syn, mediation_demo)
  fit <- fit_sem(syn, mediation_demo, meanstructure = TRUE)
  expect_equal(fit@df, cov_only@df)
  expect_equal(fit@f, cov_only@f, tolerance = 1e-5)
  expect_false(any(fit@table$op == "~1" & fit@table$lhs == "eta"))
  expect_true(all(c("mediator1", "mediator2", "mediator3", "outcome", "treatment") %in%
                    fit@table$lhs[fit@table$op == "~1"]))
})

test_that("a restricted intercept is a restriction: df counts it", {
  fit <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  expect_identical(fit@df, 1)
  expect_gt(fit@f, 0)
})

test_that("the lavaan oracle agrees on the saturated mean structure and a restricted intercept", {
  skip_if_not_installed("lavaan")
  lv <- function(extra) {
    lavaan::sem(paste0(mean_syntax, "\n", extra), mediation_demo, meanstructure = TRUE, fixed.x = FALSE)
  }
  fit <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo)
  ref <- lv("")
  expect_equal(as.numeric(logLik(fit)), as.numeric(lavaan::logLik(ref)), tolerance = 1e-6)
  restricted <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  ref0 <- lv("outcome ~ 0*1")
  expect_equal(restricted@df, unname(lavaan::fitMeasures(ref0, "df")))
  expect_equal(unname(restricted@f * nrow(mediation_demo)), unname(lavaan::fitMeasures(ref0, "chisq")),
               tolerance = 1e-4)
})

test_that("the sandwich is refused with a mean structure until it is implemented", {
  expect_error(fit_sem(mean_syntax, mediation_demo, meanstructure = TRUE, weights = rep(1, nrow(mediation_demo)),
                       se_type = "sandwich"), "not implemented yet")
})

test_that("planted defect: an information without dmu/dA gives wrong intercept SEs the OLS oracle catches", {
  fit <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  theta <- fit@theta
  sigma_inv <- chol2inv(chol(.sem_implied(ram, theta)))
  se_of <- function(dmu_fn) {
    dmu <- dmu_fn(theta, ram)
    good <- .sem_dmu(theta, ram)
    info <- .sem_info_expected(theta, ram, smp) - smp$n * crossprod(good, sigma_inv %*% good) +
      smp$n * crossprod(dmu, sigma_inv %*% dmu)
    sqrt(diag(solve(info)))[["outcome~1"]]
  }
  ols <- stats::lm(outcome ~ mediator1 + treatment, mediation_demo)
  oracle <- summary(ols)$coefficients[1, 2] * sqrt((nrow(mediation_demo) - 3) / nrow(mediation_demo))
  expect_equal(se_of(.sem_dmu), oracle, tolerance = 1e-3)
  no_a <- sem_mutate(.sem_dmu, "out[, ram$k_a[i]] <- out[, ram$k_a[i]] + bo[, r] * bm[cc]", "NULL")
  expect_gt(abs(se_of(no_a) / oracle - 1), 0.05)
})

test_that("logLik counts the means once: a saturated mean structure has the covariance-only AIC and BIC", {
  cov_only <- fit_sem(mean_syntax, mediation_demo)
  sat <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo)
  expect_equal(attr(logLik(sat), "df"), attr(logLik(cov_only), "df"))
  expect_equal(as.numeric(logLik(sat)), as.numeric(logLik(cov_only)), tolerance = 1e-6)
  expect_equal(AIC(sat), AIC(cov_only), tolerance = 1e-6)
  expect_equal(BIC(sat), BIC(cov_only), tolerance = 1e-6)
  # a fixed intercept is not a parameter
  restricted <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  expect_equal(attr(logLik(restricted), "df"), length(restricted@theta))
  expect_equal(attr(logLik(sat), "df") - attr(logLik(restricted), "df"), 1)
})

test_that("planted defect: adding p to a mean-structure fit double counts the means", {
  sat <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo)
  broken <- sem_mutate(.sem_loglik_df, "p * !isTRUE(object@internals$ram$has_mean)", "p")
  expect_equal(broken(sat, 3L) - .sem_loglik_df(sat, 3L), 3)
})

test_that("anova refuses to compare a mean structure with a covariance-only fit until that is implemented", {
  cov_only <- fit_sem(mean_syntax, mediation_demo)
  restricted <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  expect_error(anova(cov_only, restricted), "mean structure")
  expect_error(anova(restricted, cov_only), "mean structure")
  both <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1\nmediator1 ~ 0*1"), mediation_demo)
  expect_no_error(anova(restricted, both))
})
