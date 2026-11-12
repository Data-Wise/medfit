# Stage-0 release guard: every non-NULL source_fit is refused while unadmitted.
test_that("source_fit is refused before any other check, draw or callback", {
  set.seed(7L)
  before <- .Random.seed
  for (m in c("parametric", "nonparametric")) {
    expect_error(
      bootstrap_mediation(source_fit = 1, effect = "nie", method = m),
      class = "medfit_error_fiml_inference_unavailable"
    )
  }
  expect_error(bootstrap_mediation(source_fit = list()), class = "medfit_error_fiml_inference_unavailable")
  expect_error(
    bootstrap_mediation(stop("callback forced"), source_fit = 1, effect = "nie"),
    class = "medfit_error_fiml_inference_unavailable"
  )
  expect_identical(.Random.seed, before)
})

test_that("guard has no option or environment bypass", {
  withr::local_options(medfit.fiml_inference = TRUE, medfit.source_fit = TRUE)
  withr::local_envvar(MEDFIT_FIML_INFERENCE = "true")
  expect_false(.fiml_source_inference_admitted())
  expect_error(bootstrap_mediation(source_fit = 1, effect = "nie", method = "parametric"),
               class = "medfit_error_fiml_inference_unavailable")
})

test_that("calls without source_fit keep their contracts", {
  expect_error(bootstrap_mediation(effect = "nie"), "source_fit")
  expect_error(bootstrap_mediation(function(x) 1, method = "plugin"), "mediation_data")
})

test_that("the guard refuses a real accepted FIML fit", {
  source(testthat::test_path("helper-fiml-bootstrap.R"), local = TRUE)
  fit <- fit_sem(fb_model(TRUE), fb_fixture("mar", TRUE), missing = "fiml", fixed_x = FALSE)
  for (m in c("parametric", "nonparametric")) {
    expect_error(bootstrap_mediation(source_fit = fit, effect = "nie", method = m, n_boot = 5L),
                 class = "medfit_error_fiml_inference_unavailable")
  }
})
