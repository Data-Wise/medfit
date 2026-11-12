# extract_mediation() on a two-level lavaan fit returns TwoLevelMediationData (#394, slice S2, PR1).
# Oracles: O1 (balanced saturated closed form), O2 (lm), O5 (fixed.x = FALSE), O6 (robust, FIML).
# Each oracle has a planted-defect test that must fail under the defect (spec section 8).

skip_if_not_installed("lavaan")

test_that("a two-level fit returns TwoLevelMediationData with the six paths (the flipped S0 test)", {
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  expect_true(S7::S7_inherits(td, TwoLevelMediationData))
  expect_identical(td@source, "lavaan")
  expect_identical(c(td@treatment, td@mediator, td@outcome, td@cluster), c("X", "M", "Y", "id"))
  expect_equal(td@n_obs, 500L)
  expect_equal(td@n_clusters, 100L)
  expect_equal(td@cluster_sizes, rep(5L, 100L))
  expect_true(td@between_identified)
  expect_true(td@converged)
  expect_true(td@admissible)
  expect_identical(td@between_parameterization, "latent")
  expect_identical(td@cross_level_equal, character(0))
  expect_identical(td@fixed_paths, character(0))
})

test_that("the paths and joint vcov are read by free-parameter index, never refit", {
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  lp <- tl_lavaan_paths(fit)
  expect_equal(unname(td@estimates), unname(lp), tolerance = 1e-12)
  expect_identical(names(td@estimates), names(lp))
  expect_equal(td@a_within, unname(lp["a_within"]), tolerance = 1e-12)
  V <- lavaan::vcov(fit)
  idx <- c(1, 2, 3, 6, 7, 8)
  expect_equal(unname(td@vcov), unname(V[idx, idx]), tolerance = 1e-12)
  expect_identical(dimnames(td@vcov), list(names(lp), names(lp)))
  expect_true(tl_index_set_ok(td, fit))
})

test_that("an unlabeled model is keyed to the right block at each level", {
  fit <- tl_fixture("unlabeled")
  td <- tl_extract(fit)
  base <- tl_extract(tl_fixture("base"))
  expect_equal(td@estimates, base@estimates, tolerance = 1e-6)
  expect_false(isTRUE(all.equal(td@a_within, td@a_between)))
  expect_true(tl_index_set_ok(td, fit))
  expect_equal(unname(td@vcov["a_within", "a_between"]),
               unname(lavaan::vcov(fit)[1, 6]), tolerance = 1e-12)
})

test_that("keying by position survives a shifted free-parameter index (fixed.x = FALSE)", {
  fit <- tl_fixture("fixed_x_false")
  pt <- lavaan::parTable(fit)
  expect_gt(pt$free[pt$level == 2 & pt$lhs == "M" & pt$rhs == "X"], 6)
  td <- tl_extract(fit)
  expect_true(tl_index_set_ok(td, fit))
  pe <- lavaan::parameterEstimates(fit)
  expect_equal(td@a_between, pe$est[pe$label == "a2"], tolerance = 1e-12)
})

test_that("the cross-level covariance is carried and non-zero", {
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  V <- lavaan::vcov(fit)
  expect_equal(unname(td@vcov["a_within", "a_between"]), unname(V[1, 6]), tolerance = 1e-12)
  expect_gt(abs(td@vcov["a_within", "a_between"]), 1e-6)
})

# --- O1, O2 -----------------------------------------------------------------------------------------------------

test_that("O1: both levels match the balanced saturated closed form", {
  d <- tl_sim()
  td <- tl_extract(tl_fixture("base"))
  expect_true(tl_o1_ok(td, d))
})

test_that("O2: within paths match lm on cluster-centered data", {
  d <- tl_sim()
  td <- tl_extract(tl_fixture("base"))
  ref <- tl_lm_within(d)
  se <- td@parameter_table$se[1:3]
  expect_lte(abs(td@a_within - ref[["a"]]), max(0.01 * se[1], 1e-4))
  expect_lte(abs(td@b_within - ref[["b"]]), max(0.01 * se[2], 1e-4))
  expect_lte(abs(td@c_prime_within - ref[["c_prime"]]), max(0.01 * se[3], 1e-4))
})

test_that("O2: between paths approximate lm on cluster means when clusters are large", {
  d <- tl_cached("d_large", tl_sim(J = 60L, n = 400L))
  fit <- tl_cached("fit_large", tl_fit(d))
  td <- tl_extract(fit)
  ref <- tl_lm_between(d)
  se <- td@parameter_table$se[4:6]
  expect_lte(abs(td@a_between - ref[["a"]]), 0.1 * se[1])
  expect_lte(abs(td@b_between - ref[["b"]]), 0.1 * se[2])
  expect_lte(abs(td@c_prime_between - ref[["c_prime"]]), 0.1 * se[3])
})

# --- Planted defects (section 8): each must make an oracle assertion fail ---------------------------------------

test_that("planted defect: levels swapped is caught by O1", {
  fit <- tl_fixture("base")
  real <- medfit:::.twolevel_key_rows
  testthat::local_mocked_bindings(
    .twolevel_key_rows = function(pt, ...) {
      pt$level <- 3L - pt$level
      real(pt, ...)
    },
    .package = "medfit"
  )
  td <- tl_extract(fit)
  expect_false(tl_o1_ok(td, tl_sim()))
})

test_that("planted defect: the first block taken for both levels is caught by O1", {
  fit <- tl_fixture("unlabeled")
  real <- medfit:::.twolevel_key_rows
  testthat::local_mocked_bindings(
    .twolevel_key_rows = function(pt, ...) {
      keep <- pt[pt$level == 1L, ]
      twin <- keep
      twin$level <- 2L
      twin$free <- twin$free + 5L
      real(rbind(keep, twin), ...)
    },
    .package = "medfit"
  )
  td <- tryCatch(tl_extract(fit), error = function(e) NULL)
  expect_false(is.null(td))
  expect_false(tl_o1_ok(td, tl_sim()))
})

test_that("planted defect: between rows matched with the wrong suffix are caught by the index-set test", {
  fit <- tl_fixture("base")
  real <- medfit:::.twolevel_key_rows
  testthat::local_mocked_bindings(
    .twolevel_key_rows = function(pt, ...) {
      keyed <- real(pt, ...)
      keyed$free[4:6] <- keyed$free[1:3]
      keyed
    },
    .package = "medfit"
  )
  td <- tl_extract(fit)
  expect_false(tl_index_set_ok(td, fit))
})

test_that("planted defect: a dropped cross-level block is caught by the direct covariance assertion", {
  fit <- tl_fixture("base")
  real <- medfit:::.twolevel_subvcov
  testthat::local_mocked_bindings(
    .twolevel_subvcov = function(...) {
      v <- real(...)
      v[1:3, 4:6] <- 0
      v[4:6, 1:3] <- 0
      v
    },
    .package = "medfit"
  )
  td <- tl_extract(fit)
  expect_false(isTRUE(all.equal(unname(td@vcov["a_within", "a_between"]),
                                unname(lavaan::vcov(fit)[1, 6]), tolerance = 1e-12)))
})

# --- Cross-level equality (S1-Q3) -------------------------------------------------------------------------------

test_that("a label shared across levels is detected as an equated path", {
  fit <- tl_fixture("shared_label")
  td <- tl_extract(fit)
  expect_identical(td@cross_level_equal, "a")
  expect_equal(td@a_within, td@a_between, tolerance = 1e-8)
  # the equated pair repeats one row and column: correlation 1
  expect_equal(unname(td@vcov["a_within", "a_between"]), unname(td@vcov["a_within", "a_within"]),
               tolerance = 1e-8)
})

test_that("a `==` row between labels is detected as an equated path", {
  fit <- tl_fixture("equal_rows")
  td <- tl_extract(fit)
  expect_identical(td@cross_level_equal, "a")
})

test_that("an unconstrained fit reports no equated paths", {
  expect_identical(tl_extract(tl_fixture("base"))@cross_level_equal, character(0))
})

test_that("planted defect: a shared label read as a free parameter is caught", {
  fit <- tl_fixture("shared_label")
  testthat::local_mocked_bindings(.twolevel_cross_equal = function(...) character(0), .package = "medfit")
  td <- tl_extract(fit)
  expect_false(identical(td@cross_level_equal, "a"))
})

# --- Fixed rows -------------------------------------------------------------------------------------------------

test_that("a fixed path row is accepted, listed and has variance zero", {
  d <- tl_sim()
  model <- "level: 1\n M ~ a*X\n Y ~ b*M + cp*X\nlevel: 2\n M ~ a2*X\n Y ~ b2*M + 0*X\n"
  fit <- tl_fit(d, model)
  td <- tl_extract(fit)
  expect_identical(td@fixed_paths, "c_prime_between")
  expect_equal(td@c_prime_between, 0)
  expect_equal(unname(td@vcov["c_prime_between", "c_prime_between"]), 0)
  expect_equal(unname(td@vcov["c_prime_between", "a_between"]), 0)
  expect_identical(td@parameter_table$free[6], 0L)
})

# --- Provenance and design (O6) ---------------------------------------------------------------------------------

test_that("provenance is read from the fit and the fit is never refit", {
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  expect_true(td@fixed_x)
  expect_identical(td@information, "observed")
  expect_identical(td@h1_information, "structured")
  expect_identical(td@se_type, "standard")
  expect_identical(td@estimator, "ML")
  expect_identical(td@missing, "listwise")
  expect_identical(td@lavaan_version, as.character(utils::packageVersion("lavaan")))
  expect_identical(td@call, paste(deparse(fit@call), collapse = " "))
  expect_identical(td@source_package, "lavaan")
})

test_that("O6: a robust-SE fit is read as given", {
  fit <- tl_fixture("robust")
  td <- tl_extract(fit)
  expect_identical(td@se_type, "robust.huber.white")
  V <- lavaan::vcov(fit)
  idx <- c(1, 2, 3, 6, 7, 8)
  expect_equal(unname(td@vcov), unname(V[idx, idx]), tolerance = 1e-12)
  plain <- tl_extract(tl_fixture("base"))
  se <- sqrt(diag(td@vcov))
  expect_true(all(abs(td@estimates - plain@estimates) <= pmax(0.01 * se, 1e-4)))
  expect_false(isTRUE(all.equal(unname(diag(td@vcov)), unname(diag(plain@vcov)))))
})

test_that("O6: a lavaan cluster-bootstrap covariance is read as given", {
  skip_on_cran()
  fit <- tl_fixture("bootstrap")
  td <- tl_extract(fit)
  expect_identical(td@se_type, "bootstrap")
  V <- lavaan::vcov(fit)
  idx <- c(1, 2, 3, 6, 7, 8)
  expect_equal(unname(td@vcov), unname(V[idx, idx]), tolerance = 1e-12)
  expect_true(td@between_identified)
})

test_that("O6: a FIML fit keeps all rows and its own estimates", {
  fit <- tl_fixture("fiml")
  td <- tl_extract(fit)
  # lavaan normalizes missing = "fiml" to "ml" in its options; the adapter stores what the fit holds
  expect_identical(td@missing, "ml")
  expect_equal(td@n_obs, 500L)
  expect_equal(td@n_clusters, 100L)
  lp <- tl_lavaan_paths(fit)
  se <- sqrt(diag(td@vcov))
  expect_true(all(abs(td@estimates - lp) <= pmax(0.01 * se, 1e-4)))
})

test_that("O6: unbalanced clusters report their sizes", {
  d <- tl_sim()[-c(1:2, 11:13), ]
  fit <- tl_cached("fit_unbal", tl_fit(d))
  td <- tl_extract(fit)
  expect_equal(td@n_obs, 495L)
  expect_equal(sum(td@cluster_sizes), 495L)
  expect_equal(td@cluster_sizes[1:3], c(3L, 5L, 2L))
})

test_that("O5: fixed.x = FALSE gives wider between SEs, same estimates, and the stored flag", {
  td_true <- tl_extract(tl_fixture("base"))
  fit_f <- tl_fixture("fixed_x_false")
  td_false <- tl_extract(fit_f)
  expect_true(td_true@fixed_x)
  expect_false(td_false@fixed_x)
  expect_true(all(abs(td_true@estimates - td_false@estimates) <= 5e-5))
  # against fixed.x = FALSE at the same information: the adapter reads lavaan's own SEs
  pe <- lavaan::parameterEstimates(fit_f)
  lav_se <- pe$se[match(c("a", "b", "cp", "a2", "b2", "cp2"), pe$label)]
  expect_equal(unname(sqrt(diag(td_false@vcov))), lav_se, tolerance = 1e-3)
  # against the default fit the between SEs are never wider and a_between is narrower (not a tolerance):
  # fixing the exogenous moments cannot widen a between SE. Here the a_between SE is about 1% narrower;
  # the 3-4% of the research fixture depends on its data-generating process.
  ratio <- sqrt(diag(td_true@vcov)) / sqrt(diag(td_false@vcov))
  expect_true(all(ratio[4:6] <= 1 + 1e-3 & ratio[4:6] > 0.94))
  expect_lt(ratio[["a_between"]], 0.995)
  expect_true(all(abs(ratio[1:3] - 1) < 1e-3))
})

# --- Single-level, guards and refusals --------------------------------------------------------------------------

test_that("a single-level fit with cluster = still returns MediationData", {
  d <- tl_sim()
  fit <- lavaan::sem("M ~ a*X\n Y ~ b*M + cp*X", d, cluster = "id")
  expect_equal(as.integer(lavaan::lavInspect(fit, "nlevels")), 1L)
  res <- tl_extract(fit)
  expect_s3_class(res, "medfit::MediationData")
})

test_that("a three-level or unreadable level count keeps the multilevel error", {
  fit <- tl_fixture("base")
  testthat::local_mocked_bindings(.lavaan_nlevels = function(object) 3L, .package = "medfit")
  err <- tl_catch(extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"),
                  "medfit_error_lavaan_multilevel")
  expect_s3_class(err, "medfit_error_lavaan_multilevel")
  expect_match(conditionMessage(err), "more than two levels", fixed = TRUE)
})

test_that("a two-level multigroup fit keeps the multigroup error", {
  fit <- tl_fixture("base")
  testthat::local_mocked_bindings(.lavaan_is_multigroup = function(object) TRUE, .package = "medfit")
  err <- tl_catch(extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"),
                  "medfit_error_lavaan_multigroup")
  expect_s3_class(err, "medfit_error_lavaan_multigroup")
})

test_that("standardized = TRUE is refused with a classed error", {
  fit <- tl_fixture("base")
  err <- tl_catch(extract_mediation(fit, "X", "M", "Y", standardized = TRUE),
                  "medfit_error_twolevel_standardized")
  expect_s3_class(err, "medfit_error_twolevel_standardized")
  expect_match(conditionMessage(err), "standardized", fixed = TRUE)
})

test_that("a product term or interaction = is refused with a classed error", {
  fit <- tl_fixture("base")
  err <- tl_catch(extract_mediation(fit, "X", "M", "Y", interaction = "XM"),
                  "medfit_error_twolevel_product")
  expect_s3_class(err, "medfit_error_twolevel_product")
  d <- tl_sim()
  d$XM <- d$X * d$M
  prod_fit <- tl_fit(d, "level: 1\n M ~ X\n Y ~ M + X + X:M\nlevel: 2\n M ~ X\n Y ~ M + X\n")
  err2 <- tl_catch(extract_mediation(prod_fit, "X", "M", "Y"), "medfit_error_twolevel_product")
  expect_s3_class(err2, "medfit_error_twolevel_product")
})

test_that("more than one mediator is refused", {
  fit <- tl_fixture("base")
  err <- tl_catch(extract_mediation(fit, "X", c("M", "Y"), "Y"), "medfit_error_twolevel_unsupported")
  expect_s3_class(err, "medfit_error_twolevel_unsupported")
})

test_that("arguments that do not apply are refused when set", {
  fit <- tl_fixture("base")
  e1 <- tl_catch(extract_mediation(fit, "X", "M", "Y", decomposition = "four_way"),
                 "medfit_error_twolevel_unsupported")
  expect_s3_class(e1, "medfit_error_twolevel_unsupported")
  e2 <- tl_catch(extract_mediation(fit, "X", "M", "Y", structure = "serial"),
                 "medfit_error_twolevel_unsupported")
  expect_s3_class(e2, "medfit_error_twolevel_unsupported")
  e3 <- tl_catch(extract_mediation(fit, "X", "M", "Y", m_star = 1), "medfit_error_twolevel_unsupported")
  expect_s3_class(e3, "medfit_error_twolevel_unsupported")
})

test_that("unused dots are an error as elsewhere", {
  fit <- tl_fixture("base")
  expect_error(suppressWarnings(extract_mediation(fit, "X", "M", "Y", not_an_argument = 1)))
})

test_that("a non-default path label is ignored with one warning", {
  fit <- tl_fixture("base")
  rlang::reset_warning_verbosity("medfit_twolevel_labels_ignored")
  w <- tl_catch(extract_mediation(fit, "X", "M", "Y", a_label = "alpha"),
                "medfit_warning_twolevel_labels_ignored")
  expect_s3_class(w, "medfit_warning_twolevel_labels_ignored")
  rlang::reset_warning_verbosity("medfit_twolevel_labels_ignored")
  td <- suppressWarnings(extract_mediation(fit, "X", "M", "Y", a_label = "alpha"))
  expect_equal(td@a_within, tl_extract(fit)@a_within)
})

test_that("a missing path at one level errors; the level is not assumed zero", {
  d <- tl_sim()
  fit <- tl_fit(d, "level: 1\n M ~ X\n Y ~ M + X\nlevel: 2\n M ~ X\n Y ~ M\n")
  err <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_error_twolevel_path_missing")
  expect_s3_class(err, "medfit_error_twolevel_path_missing")
  expect_match(conditionMessage(err), "between", fixed = TRUE)
})

test_that("a cluster-level treatment (2-1-1) is refused and points to engine = \"lmer\"", {
  d <- tl_sim()
  d$X <- stats::ave(d$X, d$id)
  fit <- tl_fit(d, "level: 1\n M ~ 1\n Y ~ M\nlevel: 2\n M ~ X\n Y ~ M + X\n")
  err <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_error_twolevel_unsupported")
  expect_s3_class(err, "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "engine = \"lmer\"", fixed = TRUE)
})

test_that("an outcome left NULL is found when it is the only other endogenous variable", {
  fit <- tl_fixture("base")
  td <- suppressWarnings(extract_mediation(fit, treatment = "X", mediator = "M"))
  expect_identical(td@outcome, "Y")
})

test_that("an inadmissible fit is flagged with a classed warning", {
  fit <- tl_fixture("base")
  expect_true(medfit:::.twolevel_admissible(fit))
  expect_false(suppressWarnings(medfit:::.twolevel_admissible(tl_fixture("m_centered"))))
  testthat::local_mocked_bindings(.twolevel_admissible = function(fit) FALSE, .package = "medfit")
  w <- tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_warning_twolevel_inadmissible")
  expect_s3_class(w, "medfit_warning_twolevel_inadmissible")
  expect_false(tl_extract(fit)@admissible)
})


# --- Hardening 2: provenance is read from the fit ---

test_that("lavaan_version is the version that made the fit, not the one installed at extraction time", {
  fit <- tl_fixture("base")
  expect_identical(tl_extract(fit)@lavaan_version, as.character(numeric_version(fit@version)))
  old <- fit
  old@version <- "0.6-1"
  expect_identical(tl_extract(old)@lavaan_version, "0.6.1")
  # planted defect: the installed version differs from the stored one, so reading it instead must be caught
  expect_false(identical(tl_extract(old)@lavaan_version, as.character(utils::packageVersion("lavaan"))))
  # an empty (or unparsable) slot falls back to the installed version; lavaan itself rejects such a fit
  # earlier in extraction, so the helper is tested directly
  blank <- fit
  blank@version <- character(0)
  expect_identical(medfit:::.twolevel_fit_version(blank), as.character(utils::packageVersion("lavaan")))
  blank@version <- "not a version"
  expect_identical(medfit:::.twolevel_fit_version(blank), as.character(utils::packageVersion("lavaan")))
})

# --- Hardening 3: only the expected inadmissibility is a FALSE; other errors propagate ---

test_that(".twolevel_admissible returns FALSE for an inadmissible fit and lets other errors propagate", {
  expect_false(suppressWarnings(medfit:::.twolevel_admissible(tl_fixture("m_centered"))))
  expect_true(medfit:::.twolevel_admissible(tl_fixture("base")))
  # not a lavaan object: the error is a defect of the caller, not an inadmissible fit
  expect_error(medfit:::.twolevel_admissible(1))
  # an unexpected failure inside lavaan propagates with its own message
  testthat::local_mocked_bindings(
    lavInspect = function(object, what, ...) stop("boom from lavaan"),
    .package = "lavaan"
  )
  expect_error(medfit:::.twolevel_admissible(tl_fixture("base")), "boom from lavaan")
})
