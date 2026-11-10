# Between-level identification (S1-Q1) and the degenerate fixtures: within-only results with classed conditions.
# (#394, slice S2, PR1)

skip_if_not_installed("lavaan")

test_that("a cluster-mean centered treatment gives a within-only result and a classed warning", {
  r <- tl_unidentified("x_centered")
  expect_s3_class(r$warning, "medfit_between_unidentified")
  expect_match(conditionMessage(r$warning), "treatment", fixed = TRUE)
  expect_true(tl_within_only_ok(r$td))
  expect_lt(r$td@icc[["X"]], 0.01)
  # the within paths are the ordinary within estimates
  expect_equal(r$td@a_within, tl_lm_within(tl_sim(x_mode = "centered"))[["a"]], tolerance = 1e-3)
})

test_that("a within-randomized treatment gives a within-only result", {
  r <- tl_unidentified("x_randomized")
  expect_s3_class(r$warning, "medfit_between_unidentified")
  expect_true(tl_within_only_ok(r$td))
})

test_that("a mediator below the ICC threshold gives a within-only result that names the mediator", {
  fit <- tl_fixture("base")
  tl_mock_tiny_mediator_icc()
  w <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_between_unidentified")
  expect_s3_class(w, "medfit_between_unidentified")
  expect_match(conditionMessage(w), "mediator", fixed = TRUE)
  expect_false(grepl("treatment", conditionMessage(w), fixed = TRUE))
  td <- tl_extract(fit)
  expect_true(tl_within_only_ok(td))
  expect_lt(td@icc[["M"]], 0.01)
})

test_that("a mediator with no between variance fails to converge and is an error, not a partial result", {
  fit <- tl_fixture("m_centered")
  expect_false(lavaan::lavInspect(fit, "converged"))
  err <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_error_twolevel_unusable")
  expect_s3_class(err, "medfit_error_twolevel_unusable")
})

test_that("planted defect: ICC thresholds applied to the swapped variables are caught", {
  fit <- tl_fixture("base")
  tl_mock_tiny_mediator_icc(wrap = function(icc) {
    names(icc)[match(c("X", "M"), names(icc))] <- c("M", "X")
    icc
  })
  w <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_between_unidentified")
  expect_false(grepl("mediator", conditionMessage(w), fixed = TRUE))
})

test_that("planted defect: admissibility from post.check alone is caught", {
  fit <- tl_fixture("x_centered")
  expect_true(lavaan::lavInspect(fit, "post.check"))
  testthat::local_mocked_bindings(
    .twolevel_identification = function(fit, ...) {
      list(icc = medfit:::.twolevel_icc(fit), identified = isTRUE(lavaan::lavInspect(fit, "post.check")),
           weak = FALSE, reasons = character(0))
    },
    .package = "medfit"
  )
  td <- tl_extract(fit)
  expect_false(tl_within_only_ok(td))
})

test_that("a treatment with a between SD of 0.05 passes post.check but is flagged weak", {
  fit <- tl_fixture("x_small_between")
  expect_true(lavaan::lavInspect(fit, "post.check"))
  w <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_warning_between_weak")
  expect_s3_class(w, "medfit_warning_between_weak")
  td <- tl_extract(fit)
  expect_true(td@between_identified)
  expect_gte(td@icc[["X"]], 0.01)
  expect_lt(td@icc[["X"]], 0.05)
  # the between SE is large: post.check alone would have called this fit fine
  expect_gt(td@parameter_table$se[4], 0.5)
})

test_that("the ICC band edges follow the options", {
  fit <- tl_fixture("x_small_between")
  withr::local_options(medfit.between_icc_warn = 0.001)
  expect_null(tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_warning_between_weak"))
  withr::local_options(medfit.between_icc_error = 0.5)
  expect_s3_class(
    tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_between_unidentified"),
    "medfit_between_unidentified"
  )
})

test_that("ICCs are reported for X, M and Y from the implied moments", {
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  imp <- lavaan::lavInspect(fit, "implied")
  want <- diag(imp[[2]]$cov) / (diag(imp[[2]]$cov) + diag(imp[[1]]$cov))
  expect_equal(td@icc[c("X", "M", "Y")], want[c("X", "M", "Y")], tolerance = 1e-10)
})

test_that("an identified fit raises no unidentified or weak-ICC warning", {
  fit <- tl_fixture("base")
  expect_null(tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_between_unidentified"))
  expect_null(tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_warning_between_weak"))
})

test_that("a non-converged fit with no vcov is an error, not a silent partial result", {
  d <- tl_sim()
  fit <- suppressWarnings(lavaan::sem(tl_model(), d, cluster = "id", control = list(iter.max = 3)))
  expect_false(lavaan::lavInspect(fit, "converged"))
  err <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_error_twolevel_unusable")
  expect_s3_class(err, "medfit_error_twolevel_unusable")
})

test_that("a non-converged fit with a usable within block is within-only", {
  fit <- tl_fixture("base")
  testthat::local_mocked_bindings(.twolevel_converged = function(fit) FALSE, .package = "medfit")
  td <- tl_extract(fit)
  expect_true(tl_within_only_ok(td))
  expect_false(td@converged)
})

test_that("a non-converged fit whose within block is not usable is an error", {
  fit <- tl_fixture("base")
  testthat::local_mocked_bindings(
    .twolevel_converged = function(fit) FALSE,
    .twolevel_read_vcov = function(fit) {
      v <- lavaan::vcov(fit)
      v[1, 1] <- NA_real_
      v
    },
    .package = "medfit"
  )
  err <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_error_twolevel_unusable")
  expect_s3_class(err, "medfit_error_twolevel_unusable")
})

test_that("a non-positive-definite between block makes the between level unidentified", {
  fit <- tl_fixture("base")
  testthat::local_mocked_bindings(
    .twolevel_read_vcov = function(fit) {
      v <- lavaan::vcov(fit)
      v[8, 8] <- -1
      v
    },
    .package = "medfit"
  )
  w <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_between_unidentified")
  expect_s3_class(w, "medfit_between_unidentified")
  expect_true(tl_within_only_ok(tl_extract(fit)))
})

test_that("fewer than 50 clusters warns and never errors", {
  fit <- tl_fixture("j20")
  w <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_warning_twolevel_few_clusters")
  expect_s3_class(w, "medfit_warning_twolevel_few_clusters")
  expect_match(conditionMessage(w), "20", fixed = TRUE)
  td <- tl_extract(fit)
  expect_equal(td@n_clusters, 20L)
})

test_that("the cluster-count threshold follows the option", {
  fit <- tl_fixture("j20")
  withr::local_options(medfit.twolevel_min_clusters = 10)
  expect_null(tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_warning_twolevel_few_clusters"))
})

test_that("100 clusters does not trigger the small-J warning", {
  fit <- tl_fixture("base")
  expect_null(tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_warning_twolevel_few_clusters"))
})
