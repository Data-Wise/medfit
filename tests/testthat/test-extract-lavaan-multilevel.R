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

test_that("a two-level lavaan fit returns TwoLevelMediationData (S0 refusal flipped by the S2 adapter)", {
  skip_if_not_installed("lavaan")
  fit <- suppressWarnings(lavaan::sem(.ml_model, lavaan::Demo.twolevel, cluster = "cluster"))
  # x1 in Demo.twolevel has no between-cluster variance (ICC 0.001): the result is within-only, with the
  # classed warning, and the within paths are lavaan's
  w <- NULL
  res <- withCallingHandlers(
    extract_mediation(fit, treatment = "x1", mediator = "y2", outcome = "y1"),
    warning = function(cnd) {
      if (inherits(cnd, "medfit_between_unidentified")) w <<- cnd
      invokeRestart("muffleWarning")
    }
  )
  expect_true(S7::S7_inherits(res, TwoLevelMediationData))
  expect_s3_class(w, "medfit_between_unidentified")
  expect_false(res@between_identified)
  pe <- lavaan::parameterEstimates(fit)
  expect_equal(unname(res@a_within), pe$est[pe$label == "a"])
  expect_equal(unname(res@b_within), pe$est[pe$label == "b"])
  expect_true(is.na(res@a_between))
  expect_equal(res@n_obs, nrow(lavaan::Demo.twolevel))
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

test_that("single-level fits with cluster-robust SEs and plain fits extract identically", {
  skip_if_not_installed("lavaan")
  plain <- lavaan::sem(.sl_model, lavaan::Demo.twolevel)
  clus <- lavaan::sem(.sl_model, lavaan::Demo.twolevel, cluster = "cluster")
  expect_false(.lavaan_is_multilevel(clus))
  r0 <- extract_mediation(plain, treatment = "x1", mediator = "y2", outcome = "y1")
  r1 <- extract_mediation(clus, treatment = "x1", mediator = "y2", outcome = "y1")
  expect_s3_class(r1, "medfit::MediationData")
  # lavaan adds intercepts under `cluster =`, so compare the mediation paths, not the whole vector
  expect_equal(r1@a_path, r0@a_path)
  expect_equal(r1@b_path, r0@b_path)
  expect_equal(r1@c_prime, r0@c_prime)
  expect_equal(r1@n_obs, r0@n_obs)
})

test_that("a multigroup lavaan fit is refused with a classed error", {
  skip_if_not_installed("lavaan")
  d <- lavaan::Demo.twolevel
  d$g <- as.integer(d$cluster) %% 2L
  fit <- lavaan::sem("y1 ~ x1 + y2\n y2 ~ x1", d, group = "g")
  err <- tryCatch(
    extract_mediation(fit, treatment = "x1", mediator = "y2", outcome = "y1"),
    error = function(e) e
  )
  expect_s3_class(err, "medfit_error_lavaan_multigroup")
  expect_match(conditionMessage(err), "more than one group", fixed = TRUE)
  expect_false(.lavaan_is_multigroup(structure(list(), class = "not_lavaan")))
})
