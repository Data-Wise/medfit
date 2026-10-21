# The "engines compared" table on the Models page (vignettes/articles/models.qmd) says which engine refuses which
# argument. Each refusal it states is triggered here, so the table cannot drift from the code.

root_path <- function(...) testthat::test_path("..", "..", ...)

demo <- mediation_demo
w <- rep(1, nrow(demo))
fm <- function(...) {
  fit_mediation(formula_y = outcome ~ treatment + mediator1, formula_m = mediator1 ~ treatment,
                treatment = "treatment", mediator = "mediator1", data = demo, ...)
}

test_that("engines that take no weights refuse them", {
  expect_error(fm(engine = "lmer", cluster = "covariate1", weights = w), "does not support `weights`")
  expect_error(fm(engine = "regmedint", weights = w), "does not support `weights`")
})

test_that("engines that take no sandwich covariance refuse it", {
  expect_error(fm(engine = "lmer", cluster = "covariate1", se_type = "sandwich"), "not \"sandwich\"")
  expect_error(fm(engine = "regmedint", se_type = "sandwich"), "supports se_type = \"model\" only")
})

test_that("lmer and native refuse a family", {
  expect_error(fm(engine = "lmer", cluster = "covariate1", family_y = stats::binomial()), "Gaussian")
  expect_error(
    fit_mediation(model = "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment", data = demo,
                  treatment = "treatment", mediator = "mediator1", engine = "native", family_y = stats::binomial()),
    "Gaussian"
  )
})

test_that("the glm engine takes weights and the sandwich covariance", {
  skip_if_not_installed("sandwich")
  fit <- fm(weights = w, se_type = "sandwich")
  expect_true(S7::S7_inherits(fit, MediationData))
})

test_that("the Models page lists all four engines and each stated refusal", {
  p <- root_path("vignettes", "articles", "models.qmd")
  skip_if_not(file.exists(p), "vignettes are not available (installed or built package)")
  txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
  for (e in c("`glm`", "`regmedint`", "`lmer`", "`native`")) {
    expect_true(grepl(e, txt, fixed = TRUE), info = e)
  }
  expect_true(grepl("The `fit_mediation()` engines compared", txt, fixed = TRUE))
})
