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

test_that("the sandwich with a mean structure equals HC0 for the intercept and slopes of each equation", {
  d <- medfit::mediation_demo
  fit <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), d, se_type = "sandwich")
  hc <- function(form, nm) {
    m <- stats::lm(form, d)
    x <- stats::model.matrix(m)
    r <- stats::resid(m)
    bread <- solve(crossprod(x))
    v <- bread %*% crossprod(x * r) %*% bread
    stats::setNames(sqrt(diag(v)), nm)
  }
  se <- sqrt(diag(fit@vcov))
  o <- hc(outcome ~ mediator1 + treatment, c("outcome ~1 ", "b", "cp"))
  expect_equal(unname(se[c("b", "cp")]), unname(o[c("b", "cp")]), tolerance = 1e-6)
  expect_equal(unname(se["outcome~1"]), unname(o[1L]), tolerance = 1e-6)
  expect_false(isTRUE(all.equal(se, sqrt(diag(fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), d)@vcov)))))
})

test_that("weighted sandwich with means: unit weights equal the unweighted sandwich, scale of weights is irrelevant", {
  d <- medfit::mediation_demo
  syn <- paste0(mean_syntax, "\noutcome ~ 1")
  a <- fit_sem(syn, d, se_type = "sandwich")
  b <- fit_sem(syn, d, se_type = "sandwich", weights = rep(3, nrow(d)))
  expect_equal(a@vcov, b@vcov, tolerance = 1e-8)
  set.seed(1)
  w <- stats::runif(nrow(d), 0.5, 2)
  w1 <- fit_sem(syn, d, se_type = "sandwich", weights = w)
  w2 <- fit_sem(syn, d, se_type = "sandwich", weights = 10 * w)
  expect_equal(w1@vcov, w2@vcov, tolerance = 1e-8)
  # weighted least squares oracle for the outcome intercept
  m <- stats::lm(outcome ~ mediator1 + treatment, d, weights = w)
  expect_equal(unname(w1@theta["b"]), unname(stats::coef(m)["mediator1"]), tolerance = 1e-6)
  x <- stats::model.matrix(m)
  r <- stats::resid(m)
  bread <- solve(crossprod(x * sqrt(w)))
  v <- bread %*% crossprod(x * w * r) %*% bread
  expect_equal(unname(sqrt(diag(w1@vcov))["b"]), unname(sqrt(diag(v))["mediator1"]), tolerance = 1e-6)
})

test_that("planted defect: scores without the mean part give the wrong sandwich", {
  fit <- fit_sem(paste0(mean_syntax, "\noutcome ~ 1"), mediation_demo, se_type = "sandwich")
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  good <- .sem_scores(fit@theta, ram, smp)
  expect_lt(max(abs(colSums(good))), 1e-4)
  broken <- sem_mutate(.sem_scores, "sc <- sc + drop(z %*% dmu[, k])", "sc <- sc")
  expect_gt(max(abs(broken(fit@theta, ram, smp) - good)), 0.1)
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
  no_a <- sem_mutate(.sem_dmu, "out[, ram$k_a[i]] <- out[, ram$k_a[i]] + bo[, r] * (bm[cc] - shift)", "NULL")
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

test_that("anova compares a covariance-only fit with a fixed intercept: one degree of freedom, both argument orders", {
  cov_only <- fit_sem(mean_syntax, mediation_demo)
  restricted <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  expect_equal(restricted@df - cov_only@df, 1)
  a1 <- anova(cov_only, restricted)
  a2 <- anova(restricted, cov_only)
  expect_equal(unname(a1[2L, "Df diff"]), 1)
  expect_equal(unname(a1[2L, "Chisq diff"]), unname(a2[2L, "Chisq diff"]))
  # oracle: the other equations are untouched, so the statistic is n log(RSS0 / RSS1) for the outcome regression
  d <- medfit::mediation_demo
  rss1 <- sum(stats::resid(stats::lm(outcome ~ mediator1 + treatment, d))^2)
  rss0 <- sum(stats::resid(stats::lm(outcome ~ 0 + mediator1 + treatment, d))^2)
  expect_equal(unname(a1[2L, "Chisq diff"]), nrow(d) * log(rss0 / rss1), tolerance = 1e-5)
  skip_if_not_installed("lavaan")
  lav <- lavaan::sem(paste0(mean_syntax, "\noutcome ~ 0*1"), d, meanstructure = TRUE, fixed.x = FALSE)
  full <- lavaan::sem(mean_syntax, d, meanstructure = TRUE, fixed.x = FALSE)
  expect_equal(unname(a1[2L, "Chisq diff"]), lavaan::lavTestLRT(full, lav)[2L, "Chisq diff"], tolerance = 1e-5)
})

test_that("anova keeps its checks across mean-structure status", {
  cov_only <- fit_sem(mean_syntax, mediation_demo)
  all_free <- fit_sem(mean_syntax, mediation_demo, meanstructure = TRUE)
  expect_error(anova(cov_only, all_free), "same degrees of freedom")
  restricted <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  both <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1\nmediator1 ~ 0*1"), mediation_demo)
  expect_no_error(anova(restricted, both))
  expect_no_error(anova(all_free, restricted))
  expect_no_error(anova(cov_only, restricted, both))
})

test_that("planted defect: without the implicit intercepts the tested parameter set misses the restricted intercept", {
  cov_only <- fit_sem(mean_syntax, mediation_demo)
  restricted <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  expect_identical(.sem_anova_nested(cov_only, restricted, c("full", "restricted")), "outcome ~1 ")
  broken <- sem_mutate(.sem_anova_table, "isTRUE(ram$has_mean)", "TRUE")
  expect_identical(nrow(broken(cov_only)), nrow(cov_only@table))
  expect_gt(nrow(.sem_anova_table(cov_only)), nrow(cov_only@table))
})

test_that("intended change from 0.8.0: a fixed `y ~ 0*1` is a restriction, one degree of freedom, not a dropped row", {
  without <- fit_sem(mean_syntax, mediation_demo)
  fixed <- fit_sem(paste0(mean_syntax, "\noutcome ~ 0*1"), mediation_demo)
  # 0.8.0 dropped the row and returned the covariance-only fit (same df and statistic); 0.9.0 tests it
  expect_identical(without@df, 0)
  expect_identical(fixed@df, 1)
  expect_gt(fixed@f, without@f)
  expect_identical(unname(fixed@theta[names(without@theta)]) |> length(), length(without@theta))
})

test_that("an intercept and a path may share a label (G12), and the shared value is estimated once", {
  fit <- fit_sem("outcome ~ s*1 + s*treatment\nmediator1 ~ treatment", mediation_demo)
  expect_true(fit@converged)
  tab <- fit@table
  rows <- tab[tab$lhs == "outcome" & tab$op %in% c("~1", "~"), ]
  expect_equal(rows$est[rows$op == "~1"], rows$est[rows$op == "~"], tolerance = 1e-8)
  free <- fit_sem("outcome ~ 1 + treatment\nmediator1 ~ treatment", mediation_demo)
  expect_equal(length(fit@theta), length(free@theta) - 1L)
  expect_gt(unname(fit@f), unname(free@f) - 1e-10)
})
