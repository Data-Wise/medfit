# Native SEM engine: SEMFit methods (S18). The print and summary snapshots use a
# hand-built object, so they do not depend on the optimizer or the platform.
# Oracles: lavaan's logLik() on the same model and data; the object's own fields
# for the accessors. Planted defect: an unprojected covariance must change the
# summary's standard errors under an active constraint.

hand_semfit <- function() {
  theta <- c(a = 0.5, b = 0.4, `Y~X` = 0.2, `M~~M` = 0.8, `Y~~Y` = 0.7, `X~~X` = 1)
  vc <- diag(c(0.0025, 0.0016, 0.0009, 0.01, 0.008, 0.012))
  dimnames(vc) <- list(names(theta), names(theta))
  tab <- data.frame(
    lhs = c("M", "Y", "Y", "M", "Y", "X"), op = c("~", "~", "~", "~~", "~~", "~~"),
    rhs = c("X", "M", "X", "M", "Y", "X"), label = c("a", "b", "", "", "", ""),
    free = TRUE, est = unname(theta), se = sqrt(diag(vc)), stringsAsFactors = FALSE
  )
  dat <- data.frame(X = seq(-1, 1, length.out = 20), M = 0, Y = 0)
  SEMFit(
    theta = theta, vcov = vc, table = tab,
    defined = data.frame(name = "ab", expr = "a*b", est = 0.2, se = 0.0316, stringsAsFactors = FALSE),
    f = 0.0123, n_obs = 20L, n_dropped = 2L, df = 1, information = "observed", converged = TRUE,
    data = dat, model = "M ~ a*X\nY ~ b*M + X\nab := a*b",
    diagnostics = list(status = 4L, decrement = 2.5e-8, retries = 0L, active_bounds = "M~~M",
                       active_constraints = character(), improper = character(), sign_check = "ok"),
    internals = list(), call = NULL
  )
}

test_that("print and summary of a hand-built SEMFit are stable", {
  fit <- hand_semfit()
  expect_snapshot(print(fit))
  expect_snapshot(print(summary(fit)))
})

test_that("coef, vcov and nobs read the object", {
  fit <- hand_semfit()
  expect_identical(coef(fit), fit@theta)
  expect_identical(vcov(fit), fit@vcov)
  expect_identical(nobs(fit), 20L)
})

test_that("summary reports z and two-sided p from the estimates and standard errors", {
  s <- summary(hand_semfit())
  expect_s3_class(s, "summary_SEMFit")
  expect_equal(s$coefficients$z, s$coefficients$est / s$coefficients$se)
  expect_equal(s$coefficients$p, 2 * stats::pnorm(-abs(s$coefficients$z)))
  expect_identical(s$coefficients$name[1:2], c("a", "b"))
  expect_identical(s$n_dropped, 2L)
})

test_that("logLik equals lavaan's and counts the free means in df", {
  skip_if_not_installed("lavaan")
  dat <- sem_sim(sem_model_observed(), n = 400, seed = 3)
  syntax <- "M ~ X + C\nY ~ M + X + C"
  fit <- fit_sem(syntax, dat)
  lav <- suppressWarnings(lavaan::sem(syntax, dat, fixed.x = FALSE))
  expect_equal(as.numeric(logLik(fit)), as.numeric(lavaan::logLik(lav)), tolerance = 1e-8)
  expect_identical(attr(logLik(fit), "nobs"), 400L)
  expect_equal(attr(logLik(fit), "df"), length(fit@theta) + 4)
  expect_s3_class(logLik(fit), "logLik")
})

test_that("planted defect: an unprojected covariance changes the standard errors under a constraint", {
  dat <- sem_sim(sem_model_observed(), n = 400, seed = 3)
  fit <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C\na == b", dat)
  smp <- .sem_sample(fit@data, fit@internals$ram)
  plain <- solve(.sem_info_observed(fit@theta, fit@internals$ram, smp))
  se_plain <- sqrt(diag(plain))[["a"]]
  se_summary <- summary(fit)$coefficients$se[summary(fit)$coefficients$name == "a"]
  expect_gt(abs(se_plain / se_summary - 1), 0.05)
  expect_equal(se_summary, sqrt(fit@vcov["a", "a"]))
})

test_that("a fit with a missing-value drop and an active constraint reports both in the summary", {
  dat <- sem_sim(sem_model_observed(), n = 300, seed = 3)
  dat$M[c(2, 9)] <- NA
  expect_message(fit <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C\na == b", dat), "2 of 300 rows dropped")
  expect_identical(fit@n_dropped, 2L)
  expect_identical(fit@diagnostics$active_constraints, "a == b")
  out <- utils::capture.output(print(summary(fit)))
  expect_true(any(grepl("2 dropped for missing values", out)))
  expect_true(any(grepl("Active constraints: a == b", out, fixed = TRUE)))
})

# ---- tidy, glance and confint (0.8.0 T11) ----
# Oracles: lavaan (estimates, standard errors, z, p, Wald intervals, chi-square, df, log likelihood, AIC and BIC on
# the same model and data, fixed.x = FALSE with observed information), hand-worked normal quantiles, and the
# object's own fields. Planted defects: a one-sided p-value and a wrong interval level.

tg_syntax <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + covariate1\nab := a*b"
tg_fit <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) cache <<- fit_sem(tg_syntax, data = mediation_demo)
    cache
  }
})

tg_lavaan <- function() {
  lavaan::sem(tg_syntax, data = medfit::mediation_demo, fixed.x = FALSE, information = "observed",
              meanstructure = TRUE)
}

test_that("tidy() matches lavaan: estimate, standard error, z, p and the interval, defined parameters included", {
  skip_if_not_installed("lavaan")
  fit <- tg_fit()
  td <- generics::tidy(fit, conf_int = TRUE)
  pe <- lavaan::parameterEstimates(tg_lavaan(), ci = TRUE, level = 0.95)
  pe <- pe[pe$op %in% c("~", "~~", ":="), ]
  tab <- fit@table[!is.na(fit@internals$par_map), ]
  key_fit <- c(paste(tab$lhs, tab$op, tab$rhs), "ab := a*b")
  key_lav <- paste(pe$lhs, pe$op, ifelse(pe$op == ":=", "a*b", pe$rhs))
  expect_setequal(key_fit, key_lav)
  pe <- pe[match(key_fit, key_lav), ]
  expect_equal(td$estimate, pe$est, tolerance = 1e-6)
  expect_equal(td$std_error, pe$se, tolerance = 1e-6)
  expect_equal(td$statistic, pe$z, tolerance = 1e-6)
  expect_equal(td$conf_low, pe$ci.lower, tolerance = 1e-6)
  expect_equal(td$conf_high, pe$ci.upper, tolerance = 1e-6)
  expect_lt(max(abs(td$p_value - pe$pvalue)), 1e-8)
  expect_identical(td$term, c(names(coef(fit)), "ab"))
  expect_identical(td$op[c(1L, nrow(td) - 1L, nrow(td))], c("~", "~~", ":="))
})

test_that("tidy() columns, type, and the interval equal confint()", {
  fit <- tg_fit()
  td <- generics::tidy(fit)
  expect_named(td, c("term", "op", "estimate", "std_error", "statistic", "p_value"))
  expect_equal(td$statistic, td$estimate / td$std_error)
  expect_equal(td$p_value, 2 * stats::pnorm(-abs(td$statistic)))
  expect_identical(nrow(generics::tidy(fit, type = "parameters")), length(coef(fit)))
  expect_identical(generics::tidy(fit, type = "defined")$term, "ab")
  ci <- generics::tidy(fit, conf_int = TRUE, conf_level = 0.9)
  expect_equal(unname(as.matrix(ci[c("conf_low", "conf_high")])), unname(confint(fit, level = 0.9)))
  expect_error(generics::tidy(fit, conf_level = 2), "conf_level")
})

test_that("confint() selects by name or position, includes defined parameters, and rejects unknown names", {
  fit <- tg_fit()
  all <- confint(fit)
  expect_identical(rownames(all), c(names(coef(fit)), "ab"))
  expect_identical(colnames(all), c("2.5 %", "97.5 %"))
  expect_equal(all["a", ], coef(fit)[["a"]] + c(-1, 1) * stats::qnorm(0.975) * sqrt(vcov(fit)["a", "a"]),
               ignore_attr = TRUE)
  expect_equal(all["ab", ], fit@defined$est + c(-1, 1) * stats::qnorm(0.975) * fit@defined$se, ignore_attr = TRUE)
  expect_identical(rownames(confint(fit, "b")), "b")
  expect_identical(rownames(confint(fit, c(2, 1))), names(coef(fit))[c(2, 1)])
  expect_identical(colnames(confint(fit, level = 0.9)), c("5 %", "95 %"))
  expect_error(confint(fit, "nope"), "unknown parameter in `parm`: nope")
  expect_error(confint(fit, 99), "positions out of range: 99")
  expect_error(confint(fit, c(1, 99, 100)), "99, 100")
  expect_error(confint(fit, level = 1.5), "level")
})

test_that("a parameter pinned by a constraint has a point interval and no test", {
  fit <- fit_sem(paste0(tg_syntax, "\nb == 0"), mediation_demo)
  td <- generics::tidy(fit, conf_int = TRUE)
  row <- td[td$term == "b", ]
  expect_equal(row$estimate, 0, tolerance = 1e-8)
  expect_equal(row$std_error, 0, tolerance = 1e-8)
  expect_true(is.na(row$statistic) && is.na(row$p_value))
  expect_equal(row$conf_low, row$conf_high)
})

test_that("glance() matches lavaan: chi-square, df, p, log likelihood, AIC, BIC and the parameter count", {
  skip_if_not_installed("lavaan")
  fit <- tg_fit()
  g <- generics::glance(fit)
  fm <- lavaan::fitMeasures(tg_lavaan(), c("chisq", "df", "pvalue", "logl", "aic", "bic", "npar"))
  expect_named(g, c("nobs", "npar", "df", "chisq", "p_value", "logLik", "AIC", "BIC"))
  expect_identical(g$nobs, 400L)
  expect_equal(g$chisq, unname(fm[["chisq"]]), tolerance = 1e-6)
  expect_equal(g$df, unname(fm[["df"]]))
  expect_equal(g$p_value, unname(fm[["pvalue"]]), tolerance = 1e-6)
  expect_equal(g$logLik, unname(fm[["logl"]]), tolerance = 1e-6)
  expect_equal(g$AIC, unname(fm[["aic"]]), tolerance = 1e-6)
  expect_equal(g$BIC, unname(fm[["bic"]]), tolerance = 1e-6)
  # lavaan counts the means with the free parameters; npar here is the covariance-structure parameters
  expect_equal(g$npar + length(fit@internals$ram$obs), unname(fm[["npar"]]))
})

test_that("glance() has no converged column; a saturated fit has df 0, chi-square 0 and no p-value", {
  g0 <- generics::glance(fit_sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment", mediation_demo))
  expect_false("converged" %in% names(g0))
  expect_identical(g0$df, 0)
  expect_equal(g0$chisq, 0)
  expect_true(is.na(g0$p_value))
  # every returned fit has converged = TRUE, which is why the column carries no information
  expect_true(tg_fit()@converged)
})

test_that("a weighted fit has a weighted discrepancy, not a likelihood: the likelihood columns are NA", {
  w <- fit_sem(tg_syntax, mediation_demo, weights = rep(1, nrow(mediation_demo)), se_type = "sandwich")
  g <- generics::glance(w)
  expect_identical(g$nobs, 400L)
  expect_true(all(is.na(g[c("chisq", "p_value", "logLik", "AIC", "BIC")])))
  expect_true(all(is.finite(unlist(g[c("npar", "df")]))))
})

test_that("tidy() and confint() of a hand-built SEMFit read the object", {
  fit <- hand_semfit()
  td <- generics::tidy(fit, conf_int = TRUE)
  expect_identical(td$term, c(names(fit@theta), "ab"))
  expect_identical(td$op, c("~", "~", "~", "~~", "~~", "~~", ":="))
  expect_equal(td$estimate, c(unname(fit@theta), 0.2))
  expect_equal(td$std_error[1:6], sqrt(diag(fit@vcov)), ignore_attr = TRUE)
  expect_equal(td$conf_low[1], 0.5 - stats::qnorm(0.975) * 0.05)
})

test_that("edge cases: no defined parameters, a shared label and a latent model", {
  f0 <- fit_sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment", mediation_demo)
  expect_identical(nrow(generics::tidy(f0, type = "defined")), 0L)
  expect_identical(nrow(generics::tidy(f0)), length(coef(f0)))
  expect_identical(dim(confint(f0)), c(length(coef(f0)), 2L))
  # one label on two paths is one parameter: one row, and the count and df follow
  shared <- fit_sem("mediator1 ~ a*treatment + a*covariate1\noutcome ~ mediator1 + treatment", mediation_demo)
  expect_identical(sum(generics::tidy(shared)$term == "a"), 1L)
  expect_identical(generics::glance(shared)$npar, length(coef(shared)))
  expect_equal(generics::glance(shared)$df, shared@df)
})

test_that("planted defects: a one-sided p-value and a wrong interval level are caught", {
  fit <- tg_fit()
  one_sided <- sem_mutate(.sem_wald, "2 * stats::pnorm(-abs(z))", "stats::pnorm(-abs(z))")
  se <- sqrt(diag(fit@vcov))
  expect_gt(max(abs(one_sided(fit@theta, se, 0.95)$p - .sem_wald(fit@theta, se, 0.95)$p)), 1e-6)
  wrong_level <- sem_mutate(.sem_wald, "q <- stats::qnorm(1 - a)", "q <- stats::qnorm(1 - a / 2)")
  expect_gt(abs(wrong_level(0, 1, 0.95)$high - stats::qnorm(0.975)), 0.1)
  expect_equal(.sem_wald(0, 1, 0.95)$high, stats::qnorm(0.975))
})
