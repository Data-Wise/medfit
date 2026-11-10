# Q11: print() and summary() of a serial FIML object name the variant and the covariates.

test_that("serial FIML print and summary name the variant and the covariates", {
  skip_on_cran()
  d <- s3_data("mar", n = 240)
  for (v in c("saturated", "chain")) {
    fit <- fit_sem(s3_model(v, "free"), data = d, missing = "fiml", fixed_x = FALSE)
    z <- extract_mediation(fit, treatment = "X", mediator = c("M1", "M2"), outcome = "Y")
    want <- if (v == "chain") "pure chain \\(no shortcut paths\\); covariates: Z" else
      "saturated \\(both shortcut paths estimated\\); covariates: Z"
    expect_output(print(z), want)
    expect_output(print(summary(z)), want)
  }
})

test_that("a serial FIML object without covariates says none", {
  skip_on_cran()
  d <- s3_data("mar", n = 240)
  d$Z <- NULL
  m <- "M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y"
  fit <- fit_sem(m, data = d, missing = "fiml", fixed_x = FALSE)
  z <- extract_mediation(fit, treatment = "X", mediator = c("M1", "M2"), outcome = "Y")
  expect_output(print(z), "covariates: none")
})
