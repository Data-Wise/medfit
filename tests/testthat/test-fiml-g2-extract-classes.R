# FI-G2: extract-level refusals of the parallel FIML extractor are classed conditions
# (`medfit_error_fiml_extract_unsupported`), with the message text unchanged.

test_that("parallel FIML extract refusals carry the classed condition", {
  set.seed(6122L)
  n <- 300L
  x <- stats::rnorm(n)
  m1 <- .9 * x + stats::rnorm(n, sd = .5)
  m2 <- .6 * x + stats::rnorm(n, sd = .5)
  d <- data.frame(X = x, M1 = m1, M2 = m2, Y = .7 * m1 + .3 * m2 + .25 * x + stats::rnorm(n))
  d[sample(n, 30L), "M1"] <- NA_real_
  f <- fit_sem("M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2", d, missing = "fiml", fixed_x = FALSE)
  refused <- list(
    wrong_treatment = list(treatment = "M1", mediator = c("M1", "M2")),
    one_mediator = list(treatment = "X", mediator = "M1"),
    wrong_mediator_set = list(treatment = "X", mediator = c("M1", "Y")),
    standardized = list(treatment = "X", mediator = c("M1", "M2"), standardized = TRUE),
    wrong_outcome = list(treatment = "X", mediator = c("M1", "M2"), outcome = "X"),
    serial = list(treatment = "X", mediator = c("M1", "M2"), structure = "serial")
  )
  for (nm in names(refused)) {
    expect_error(
      do.call(extract_mediation, c(list(f), refused[[nm]])),
      class = "medfit_error_fiml_extract_unsupported", info = nm
    )
    expect_error(do.call(extract_mediation, c(list(f), refused[[nm]])), "FIML extraction supports only", info = nm)
  }
  # an admitted call is unaffected
  expect_s3_class(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")), "medfit::FIMLParallelMediationData")
})
