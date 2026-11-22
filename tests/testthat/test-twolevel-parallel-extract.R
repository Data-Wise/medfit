# IG5 T2: extraction of parallel mediators from a two-level lavaan fit (TwoLevelParallelMediationData).
# Oracle: lavaan's own coef() and vcov() read by parameter LABEL, independent of the adapter's free-index key.

skip_if_not_installed("lavaan")

test_that("paths and the 2(2k + 1) vcov block equal lavaan's, read by label", {
  fit <- tlp_fixture("base")
  td <- tlp_extract(fit)
  expect_true(S7::S7_inherits(td, TwoLevelParallelMediationData))
  expect_identical(td@mediators, c("M1", "M2"))
  expect_identical(names(td@estimates), names(tlp_lavaan_rows()))
  expect_identical(dim(td@vcov), c(10L, 10L))
  expect_true(td@between_identified)
  expect_true(tlp_oracle_ok(td, fit))
  expect_identical(names(td@a_within), c("M1", "M2"))
  expect_identical(names(td@b_between), c("M1", "M2"))
  # Cross-mediator and cross-level covariances are carried, not zeroed
  V <- lavaan::vcov(fit)
  expect_equal(td@vcov["a_M1_within", "a_M2_within"], V["a1", "a2"], tolerance = 1e-12)
  expect_gt(abs(td@vcov["a_M1_within", "a_M2_within"]), 1e-5)
  expect_equal(td@vcov["b_M1_within", "b_M1_between"], V["b1", "b1B"], tolerance = 1e-12)
})

test_that("an unlabeled two-mediator model gives the same object as the labeled one", {
  td <- tlp_extract(tlp_fixture("base"))
  tu <- tlp_extract(tlp_fixture("unlabeled"))
  expect_equal(tu@estimates, td@estimates, tolerance = 1e-8)
  expect_equal(tu@vcov, td@vcov, tolerance = 1e-8)
})

test_that("a planted swap of two mediators' b rows in the key is caught by the oracle", {
  fit <- tlp_fixture("base")
  real <- .twolevel_key_rows
  swapped <- function(pt, treatment, mediator, outcome) {
    key <- real(pt, treatment, mediator, outcome)
    for (lvl in c("within", "between")) {
      i <- match(paste0("b_", c("M1", "M2"), "_", lvl), key$path)
      key[i, c("free", "est", "label")] <- key[rev(i), c("free", "est", "label")]
    }
    key
  }
  expect_true(tlp_oracle_ok(tlp_extract(fit), fit))
  testthat::local_mocked_bindings(.twolevel_key_rows = swapped)
  expect_false(tlp_oracle_ok(tlp_extract(fit), fit))
})

test_that("k = 1 still returns TwoLevelMediationData with the one-mediator row names", {
  expect_identical(.twolevel_path_stems("M"), c("a", "b", "c_prime"))
  expect_identical(.twolevel_path_stems(c("M1", "M2")), c("a_M1", "a_M2", "b_M1", "b_M2", "c_prime"))
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  expect_true(S7::S7_inherits(td, TwoLevelMediationData))
  rows <- c(a_within = "a", b_within = "b", c_prime_within = "cp", a_between = "a2", b_between = "b2",
            c_prime_between = "cp2")
  expect_identical(names(td@estimates), names(rows))
  expect_equal(unname(td@estimates), unname(lavaan::coef(fit)[rows]), tolerance = 1e-12)
  expect_equal(unname(td@vcov), unname(lavaan::vcov(fit)[rows, rows]), tolerance = 1e-12)
  # A length-one mediator on the two-mediator fit is the one-mediator class (M2 enters only the fit)
  t1 <- tlp_extract(tlp_fixture("base"), mediator = "M1")
  expect_true(S7::S7_inherits(t1, TwoLevelMediationData))
  expect_equal(t1@b_within, unname(lavaan::coef(tlp_fixture("base"))[["b1"]]), tolerance = 1e-12)
})

test_that("permuting the mediators permutes the paths and the vcov", {
  td <- tlp_extract(tlp_fixture("base"))
  tp <- tlp_extract(tlp_fixture("base"), mediator = c("M2", "M1"))
  expect_identical(tp@mediators, c("M2", "M1"))
  expect_identical(tp@a_within[c("M1", "M2")], td@a_within)
  expect_identical(tp@b_between[c("M1", "M2")], td@b_between)
  nm <- names(td@estimates)
  expect_identical(tp@vcov[nm, nm], td@vcov)
})

test_that("D2: a low ICC in any mediator (not only the first) makes the object within-only", {
  fit <- tlp_fixture("base")
  real <- .twolevel_icc
  for (low in c("M2", "M1")) {
    testthat::local_mocked_bindings(.twolevel_icc = function(fit) {
      icc <- real(fit)
      icc[[low]] <- 0.001
      icc
    })
    w <- tl_catch(extract_mediation(fit, "X", c("M1", "M2"), "Y"), "medfit_between_unidentified")
    expect_s3_class(w, "medfit_between_unidentified")
    expect_match(conditionMessage(w), sprintf("the ICC of the mediator '%s'", low), fixed = TRUE)
    td <- tlp_extract(fit)
    expect_false(td@between_identified)
    expect_identical(td@a_between, c(M1 = NA_real_, M2 = NA_real_))
    expect_identical(td@b_between, c(M1 = NA_real_, M2 = NA_real_))
    expect_identical(names(td@estimates), names(tlp_lavaan_rows())[1:5])
    expect_identical(dim(td@vcov), c(5L, 5L))
    expect_identical(td@cross_level_equal, character(0))
  }
})

test_that("D2 on a real fit: a mediator below the ICC floor gives a within-only object", {
  fit <- tlp_fixture("low_icc_m2")
  tlp_mock_low_icc_m2()   # the h1 ICC of M2 on this fit is about .013, so M2 is set below the floor
  expect_lt(.twolevel_icc(fit)[["M2"]], 0.01)
  expect_gt(.twolevel_icc(fit)[["M1"]], 0.05)
  w <- tl_catch(extract_mediation(fit, "X", c("M1", "M2"), "Y"), "medfit_between_unidentified")
  expect_s3_class(w, "medfit_between_unidentified")
  expect_match(conditionMessage(w), "the ICC of the mediator 'M2'", fixed = TRUE)
  td <- tlp_extract(fit)
  expect_false(td@between_identified)
  expect_identical(td@a_between, c(M1 = NA_real_, M2 = NA_real_))
  rows <- names(tlp_lavaan_rows())[1:5]
  expect_identical(names(td@estimates), rows)
  expect_equal(unname(td@estimates), unname(lavaan::coef(fit)[tlp_lavaan_rows()[rows]]), tolerance = 1e-12)
})

test_that("D5: equality is found per mediator and the contrast is NA only when a_j and b_j are both equated", {
  sa <- tlp_extract(tlp_fixture("shared_a1"))
  expect_identical(sa@cross_level_equal, "a_M1")
  expect_identical(.twolevel_parallel_contrast_available(sa), c(M1 = TRUE, M2 = TRUE, total = TRUE))
  sab <- tlp_extract(tlp_fixture("shared_ab1"))
  expect_identical(sab@cross_level_equal, c("a_M1", "b_M1"))
  expect_identical(.twolevel_parallel_contrast_available(sab), c(M1 = FALSE, M2 = TRUE, total = TRUE))
  expect_identical(tlp_extract(tlp_fixture("equal_row_a1"))@cross_level_equal, "a_M1")
  expect_identical(tlp_extract(tlp_fixture("nl_b1"))@cross_level_equal, "b_M1")
  expect_identical(tlp_extract(tlp_fixture("base"))@cross_level_equal, character(0))
  all_eq <- S7::set_props(sab, cross_level_equal = c("a_M1", "b_M1", "a_M2", "b_M2"))
  expect_identical(.twolevel_parallel_contrast_available(all_eq), c(M1 = FALSE, M2 = FALSE, total = FALSE))
})

test_that("a serial model is refused at either level, naming the row", {
  for (lvl in c("within", "between")) {
    err <- tl_catch(extract_mediation(tlp_fixture(paste0("serial_", lvl)), "X", c("M1", "M2"), "Y"),
                    "medfit_error_twolevel_unsupported")
    expect_s3_class(err, "medfit_error_twolevel_unsupported")
    expect_match(conditionMessage(err), sprintf("'M2 ~ M1' at the %s level", lvl), fixed = TRUE)
  }
})

test_that("a variable listed in two roles, or a mediator listed twice, is refused", {
  fit <- tlp_fixture("base")
  cases <- list(
    list(med = c("M1", "X"), out = "Y", msg = "'X' is listed both as a mediator and as the treatment"),
    list(med = c("M1", "Y"), out = "Y", msg = "'Y' is listed both as a mediator and as the outcome"),
    list(med = c("M1", "M1"), out = "Y", msg = "The mediator 'M1' is listed more than once")
  )
  for (cs in cases) {
    err <- tl_catch(extract_mediation(fit, "X", cs$med, cs$out), "medfit_error_twolevel_unsupported")
    expect_s3_class(err, "medfit_error_twolevel_unsupported")
    expect_match(conditionMessage(err), cs$msg, fixed = TRUE)
  }
})

test_that("a covariate listed as a mediator is refused as not on a treatment -> mediator path", {
  err <- tl_catch(extract_mediation(tlp_fixture("covariate_w"), "X", c("M1", "W"), "Y"),
                  "medfit_error_twolevel_unsupported")
  expect_s3_class(err, "medfit_error_twolevel_unsupported")
  expect_identical(
    conditionMessage(err),
    paste0("'W' is listed as a mediator but is not regressed on the treatment (no 'W ~ X' row at the within ",
           "level); it predicts the mediator 'M1' ('M1 ~ W'). A mediator lies on a treatment -> mediator -> ",
           "outcome path; pass a covariate in the model, not as a mediator.")
  )
})

test_that("an undeclared mediator downstream of a declared one is accepted, as with one mediator (O7c)", {
  # origin/dev's one-mediator adapter accepts M2 ~ M1 with mediator = "M1"; k >= 2 is kept consistent
  fit <- tlp_fixture("undeclared_m2")
  expect_true(S7::S7_inherits(tlp_extract(fit, mediator = "M1"), TwoLevelMediationData))
  td <- tlp_extract(fit, mediator = c("M1", "M3"))
  expect_true(S7::S7_inherits(td, TwoLevelParallelMediationData))
  pe <- lavaan::parameterEstimates(fit)
  b_m1_w <- pe$est[pe$op == "~" & pe$lhs == "Y" & pe$rhs == "M1" & pe$level == 1]
  expect_equal(td@b_within[["M1"]], b_m1_w, tolerance = 1e-12)
})
