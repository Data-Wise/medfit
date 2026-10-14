# Methods and extraction with a mean structure (0.9.0 S6): intercept rows in coef/vcov/tidy/glance/confint/summary,
# extraction equal to the covariance-only effects, the four-way refusal.

meth_syntax <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"

test_that("intercept rows appear in coef, vcov, tidy, confint and summary, and carry the right standard errors", {
  d <- medfit::mediation_demo
  fit <- fit_sem(paste0(meth_syntax, "\noutcome ~ 1"), d)
  ints <- c("outcome~1", "mediator1~1", "treatment~1")
  expect_true(all(ints %in% names(coef(fit))))
  expect_true(all(ints %in% rownames(vcov(fit))))
  td <- tidy(fit)
  expect_setequal(td$term[td$op == "~1"], ints)
  expect_true(all(ints %in% rownames(confint(fit))))
  # the exogenous mean's SE is sd / sqrt(n) (ML denominator), the outcome intercept's the OLS value rescaled
  se <- stats::setNames(td$std_error, td$term)
  expect_equal(unname(se["treatment~1"]), sqrt(mean((d$treatment - mean(d$treatment))^2) / nrow(d)), tolerance = 1e-6)
  ols <- stats::lm(outcome ~ mediator1 + treatment, d)
  expect_equal(unname(se["outcome~1"]), unname(sqrt(stats::vcov(ols)[1L, 1L] * (nrow(d) - 3) / nrow(d))),
               tolerance = 1e-5)
  txt <- paste(utils::capture.output(print(summary(fit))), collapse = "\n")
  expect_identical(summary(fit)$coefficients$name[summary(fit)$coefficients$name == "outcome ~1"], "outcome ~1")
  expect_match(txt, "outcome ~1")
})

test_that("glance counts the intercepts as free parameters and logLik agrees", {
  d <- medfit::mediation_demo
  cov_only <- fit_sem(meth_syntax, d)
  sat <- fit_sem(paste0(meth_syntax, "\noutcome ~ 1"), d)
  expect_identical(glance(sat)$npar, glance(cov_only)$npar + 3L)
  expect_equal(glance(sat)$chisq, glance(cov_only)$chisq, tolerance = 1e-6)
  expect_equal(glance(sat)$df, glance(cov_only)$df)
  expect_equal(glance(sat)$AIC, glance(cov_only)$AIC, tolerance = 1e-6)
  fixed <- fit_sem(paste0(meth_syntax, "\noutcome ~ 0*1"), d)
  expect_identical(glance(fixed)$npar, glance(sat)$npar - 1L)
  expect_equal(glance(fixed)$df, 1)
})

test_that("extraction from a mean-structure fit equals the covariance-only effects, SEs included", {
  d <- medfit::mediation_demo
  args <- list(treatment = "treatment", mediator = "mediator1")
  e0 <- do.call(extract_mediation, c(list(fit_sem(meth_syntax, d)), args))
  e1 <- do.call(extract_mediation, c(list(fit_sem(paste0(meth_syntax, "\noutcome ~ 1"), d)), args))
  expect_equal(c(e1@a_path, e1@b_path, e1@c_prime), c(e0@a_path, e0@b_path, e0@c_prime), tolerance = 1e-6)
  expect_equal(unname(nie(e1)), unname(nie(e0)), tolerance = 1e-6)
  keep <- c("a", "b", "c_prime")
  expect_equal(e1@vcov[keep, keep], e0@vcov[keep, keep], tolerance = 1e-5)
  expect_equal(tidy(e1)$std_error[tidy(e1)$term == "indirect"], tidy(e0)$std_error[tidy(e0)$term == "indirect"],
               tolerance = 1e-5)
})

test_that("a precomputed product column cannot reach the four-way route through a mean-structure fit", {
  d <- medfit::mediation_demo
  d$xm <- d$treatment * d$mediator1
  fit <- fit_sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment + xm", d, meanstructure = TRUE)
  expect_error(extract_mediation(fit, treatment = "treatment", mediator = "mediator1", interaction = "xm"),
               "written with `:`")
})

test_that("OpenMx reaches the same optimum on a constrained-intercept model", {
  skip_if_not_installed("OpenMx")
  suppressMessages(library(OpenMx))
  mxOption(NULL, "Number of Threads", 1)
  set.seed(31)
  n <- 300
  x <- stats::rnorm(n)
  m <- 0.3 + 0.5 * x + stats::rnorm(n, sd = 0.8)
  y <- 0.3 + 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7)
  d <- data.frame(X = x, M = m, Y = y)
  syn <- "M ~ a*X + i_m*1\nY ~ b*M + cp*X + i_y*1\ni_m == i_y"
  fit <- fit_sem(syn, d)
  mod <- mxModel(
    "intercepts", type = "RAM", manifestVars = c("X", "M", "Y"), mxData(d, type = "raw"),
    mxPath("X", "M", values = 0.4, labels = "a"), mxPath("M", "Y", values = 0.4, labels = "b"),
    mxPath("X", "Y", values = 0.2, labels = "cp"),
    mxPath(c("X", "M", "Y"), arrows = 2, values = 1, labels = c("vx", "vm", "vy")),
    mxPath("one", c("X", "M", "Y"), values = 0.2, labels = c("mx", "i_m", "i_y")),
    mxConstraint(i_m == i_y, name = "tie")
  )
  run <- mxRun(mod, silent = TRUE)
  est <- run$output$estimate
  expect_equal(unname(fit@theta[c("a", "b", "cp", "i_m")]), unname(est[c("a", "b", "cp", "i_m")]), tolerance = 1e-4)
  expect_equal(unname(est["i_m"]), unname(est["i_y"]), tolerance = 1e-6)
  expect_equal(-2 * as.numeric(logLik(fit)), run$output$Minus2LogLikelihood, tolerance = 1e-6)
})

test_that("the worked example on the native model page holds: a fixed intercept moves cp and anova rejects it", {
  paths <- "mediator1 ~ a * treatment\noutcome ~ b * mediator1 + cp * treatment"
  free <- fit_sem(paste0(paths, "\noutcome ~ 1"), medfit::mediation_demo)
  zero <- fit_sem(paste0(paths, "\noutcome ~ 0*1"), medfit::mediation_demo)
  expect_equal(unname(free@theta["cp"]), 0.0406, tolerance = 1e-2)
  expect_equal(unname(zero@theta["cp"]), 0.2624, tolerance = 1e-3)
  tab <- anova(free, zero)
  expect_equal(unname(tab[2L, "Df diff"]), 1)
  expect_lt(unname(tab[2L, "Pr(>Chisq)"]), 0.01)
})
