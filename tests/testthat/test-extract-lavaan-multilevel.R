# S0 guard (#394): extract_mediation() on a multi-level lavaan fit must refuse, not silently
# return the within-level block with N = total rows.

.ml_model <- paste(
  "level: 1",
  "  y1 ~ cp*x1 + b*y2",
  "  y2 ~ a*x1",
  "level: 2",
  "  y1 ~ cp2*x1 + b2*y2",
  "  y2 ~ a2*x1",
  sep = "\n"
)
.sl_model <- "y1 ~ cp*x1 + b*y2\n y2 ~ a*x1"

test_that("a two-level lavaan fit is refused with a classed error", {
  skip_if_not_installed("lavaan")
  fit <- suppressWarnings(lavaan::sem(.ml_model, lavaan::Demo.twolevel, cluster = "cluster"))
  err <- tryCatch(
    extract_mediation(fit, treatment = "x1", mediator = "y2", outcome = "y1"),
    error = function(e) e
  )
  expect_s3_class(err, "medfit_error_lavaan_multilevel")
  expect_match(conditionMessage(err), "two levels", fixed = TRUE)
  expect_match(conditionMessage(err), "within level", fixed = TRUE)
  expect_match(conditionMessage(err), "#394", fixed = TRUE)
  expect_match(conditionMessage(err), "single-level", fixed = TRUE)
})

test_that("a single-level lavaan fit still extracts as before", {
  skip_if_not_installed("lavaan")
  fit <- lavaan::sem(.sl_model, lavaan::Demo.twolevel)
  res <- extract_mediation(fit, treatment = "x1", mediator = "y2", outcome = "y1")
  expect_s3_class(res, "medfit::MediationData")
  pe <- lavaan::parameterEstimates(fit)
  expect_equal(unname(res@a_path), pe$est[pe$label == "a"])
  expect_equal(unname(res@b_path), pe$est[pe$label == "b"])
  expect_equal(unname(res@c_prime), pe$est[pe$label == "cp"])
  expect_equal(res@n_obs, nrow(lavaan::Demo.twolevel))
})

test_that("the level check falls back to the parameter table and never blocks on its own failure", {
  expect_false(.lavaan_is_multilevel(structure(list(), class = "not_lavaan")))
})
