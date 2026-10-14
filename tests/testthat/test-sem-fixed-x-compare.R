# V7: comparisons across fixed sets or data are refused (spec S8, grill F-G7).

test_that("anova refuses different fixed sets and different data, and allows the same set", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  restricted <- fit_sem(paste0(fx_syntax, "\ncp == 0"), d, fixed_x = TRUE)
  expect_error(anova(fixed, free), "fixed_x|fixed set|conditional")
  expect_no_error(anova(fixed, restricted))
  d2 <- d
  d2$outcome <- d2$outcome + 1
  other <- fit_sem(paste0(fx_syntax, "\ncp == 0"), d2, fixed_x = TRUE)
  expect_error(anova(fixed, other), "different data")
})

test_that("mbco_sem refits with the fit's fixed set, so its statistic is unchanged", {
  d <- fx_data()
  free <- mbco_sem(fit_sem(fx_syntax, d), "a", "b")
  fixed <- mbco_sem(fit_sem(fx_syntax, d, fixed_x = TRUE), "a", "b")
  expect_equal(unname(fixed$statistic), unname(free$statistic), tolerance = 1e-5)
})

test_that("multi-fit AIC and BIC error across fixed sets or data and name the difference", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fx1 <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  fx2 <- fit_sem(paste0(fx_syntax, "\ncp == 0"), d, fixed_x = TRUE)
  expect_error(AIC(free, fx1), "treatment")
  expect_error(BIC(fx1, free), "fixed")
  d2 <- d
  d2$outcome <- d2$outcome + 1
  expect_error(AIC(fx1, fit_sem(fx_syntax, d2, fixed_x = TRUE)), "data")
  out <- AIC(fx1, fx2)
  expect_identical(nrow(out), 2L)
  expect_no_error(BIC(fx1, fx2))
  expect_no_error(AIC(fx1))
})

test_that("planted defect: AIC across fixed sets must not just return a number", {
  fx_skip_covr()
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  expect_error(AIC(fixed, free), "fixed")
  bad <- sem_mutate(.sem_check_comparable, "!all(vapply(sets[-1L], identical, logical(1), sets[[1L]]))", "FALSE")
  testthat::local_mocked_bindings(.sem_check_comparable = bad)
  expect_s3_class(AIC(fixed, free), "data.frame") # the defect: a ranking of incompatible likelihoods
})

test_that("OpenMx with the same exogenous moments held at their sample values gives the same structural fit", {
  skip_if_not_installed("OpenMx")
  suppressMessages(library(OpenMx))
  mxOption(NULL, "Number of Threads", 1)
  d <- fx_data()[c("treatment", "covariate1", "covariate2", "mediator1", "outcome")]
  n <- nrow(d)
  s <- stats::cov(d) * (n - 1) / n
  mu <- colMeans(d)
  vars <- names(d)
  fixed <- "treatment"
  # structural paths, with the same labels as the model text
  paths <- list(
    mxPath("treatment", "mediator1", values = 0.4, labels = "a"),
    mxPath(c("covariate1", "covariate2"), "mediator1", values = 0.1, labels = c("m_c1", "m_c2")),
    mxPath("mediator1", "outcome", values = 0.4, labels = "b"),
    mxPath("treatment", "outcome", values = 0.2, labels = "cp"),
    mxPath(c("covariate1", "covariate2"), "outcome", values = 0.1, labels = c("y_c1", "y_c2")),
    mxPath(c("mediator1", "outcome"), arrows = 2, values = 1, labels = c("vm", "vy"), lbound = 1e-6)
  )
  # exogenous moments: the selected variable's variance, covariances and mean fixed, the others free
  exo <- c("treatment", "covariate1", "covariate2")
  for (i in seq_along(exo)) {
    for (j in i:length(exo)) {
      is_fixed <- exo[i] %in% fixed || exo[j] %in% fixed
      paths[[length(paths) + 1L]] <- mxPath(exo[i], exo[j], arrows = 2, free = !is_fixed,
                                            values = s[exo[i], exo[j]])
    }
    paths[[length(paths) + 1L]] <- mxPath("one", exo[i], free = !(exo[i] %in% fixed), values = mu[[exo[i]]])
  }
  paths[[length(paths) + 1L]] <- mxPath("one", c("mediator1", "outcome"), values = 0.2, labels = c("i_m", "i_y"))
  mod <- mxModel("ref", type = "RAM", manifestVars = vars, mxData(d, type = "raw"), paths)
  old <- vapply(c("Optimality tolerance"), function(o) as.character(mxOption(NULL, o)), "")
  mxOption(NULL, "Optimality tolerance", 1e-12)
  on.exit(mxOption(NULL, "Optimality tolerance", old), add = TRUE)
  run <- mxRun(mod, silent = TRUE)
  fit <- fit_sem(fx_syntax, d, meanstructure = TRUE, fixed_x = fixed, information = "expected")
  est <- stats::coef(run)
  lab <- c("a", "b", "cp")
  expect_equal(unname(fit@theta[lab]), unname(est[lab]), tolerance = 1e-4)
  pt <- summary(run)$parameters
  se <- stats::setNames(pt$Std.Error, pt$name)
  expect_equal(unname(sqrt(diag(fit@vcov))[lab]), unname(se[lab]), tolerance = 1e-3)
})

test_that("AIC and BIC keep working for fits passed by value and for mixed classes when nothing is fixed", {
  d <- fx_data()
  a <- fit_sem(fx_syntax, d)
  b <- fit_sem(paste0(fx_syntax, "\ncp == 0"), d)
  out <- do.call(AIC, list(a, b))
  expect_identical(rownames(out), c("model1", "model2"))
  expect_identical(nrow(AIC(a, a)), 2L)
  expect_identical(nrow(AIC(a, stats::lm(outcome ~ treatment, d))), 2L)
  expect_error(AIC(fit_sem(fx_syntax, d, fixed_x = TRUE), stats::lm(outcome ~ treatment, d)), "another class")
})
