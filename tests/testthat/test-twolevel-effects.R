# Effects of TwoLevelMediationData: nie/nde/te/pm per level, the contrast, paths, decompose (#394, S2 PR2)

val <- function(e) as.numeric(unclass(e))

test_that("nie() defaults to the within level and returns a mediation_effect", {
  td <- tl_td()
  e <- nie(td)
  expect_s3_class(e, "mediation_effect")
  expect_identical(attr(e, "type"), "nie")
  expect_equal(val(e), 0.4 * 0.5)
  expect_equal(val(nie(td, level = "within")), 0.4 * 0.5)
})

test_that("nie() between, contrast and both", {
  td <- tl_td()
  expect_equal(val(nie(td, level = "between")), 0.7 * 1.5)
  expect_equal(val(nie(td, level = "contrast")), 0.4 * 0.5 - 0.7 * 1.5)
  both <- nie(td, level = "both")
  expect_identical(names(both), c("within", "between"))
  expect_equal(unname(val(both)), c(0.2, 1.05))
  expect_s3_class(both, "mediation_effect")
})

test_that("printing a two-level effect names the level and both values", {
  td <- tl_td()
  expect_output(print(nie(td, level = "both")), "both levels: within = .*between = ")
  expect_output(print(nie(td, level = "contrast")), "within - between contrast")
  expect_output(print(nie(td)), "Natural Indirect Effect \\(NIE\\): 0.2")
})

test_that("nde, te and pm are per level; the contrast is a classed error", {
  td <- tl_td()
  expect_equal(val(nde(td)), 0.3)
  expect_equal(val(nde(td, level = "between")), -0.1)
  expect_equal(val(te(td)), 0.2 + 0.3)
  expect_equal(val(te(td, level = "between")), 1.05 - 0.1)
  expect_equal(val(pm(td)), 0.2 / 0.5)
  expect_equal(val(pm(td, level = "between")), 1.05 / 0.95)
  expect_equal(unname(val(te(td, level = "both"))), c(0.5, 0.95))
  for (f in list(nde, te, pm)) {
    expect_error(f(td, level = "contrast"), class = "medfit_error_twolevel_level")
  }
  expect_error(nie(td, level = "sideways"))
})

test_that("pm() warns and returns NA when a level's total effect is zero", {
  td <- tl_td(c_prime_within = -0.2, estimates = c(a_within = 0.4, b_within = 0.5, c_prime_within = -0.2,
                                                   a_between = 0.7, b_between = 1.5, c_prime_between = -0.1))
  expect_warning(p <- pm(td), "approximately zero")
  expect_true(is.na(val(p)))
})

test_that("a within-only object: between effects and the contrast are NA with a classed warning", {
  td <- tl_td(within_only = TRUE)
  expect_no_warning(w <- nie(td))
  expect_equal(val(w), 0.2)
  for (lv in c("between", "contrast")) {
    expect_warning(e <- nie(td, level = lv), class = "medfit_between_unidentified")
    expect_true(is.na(val(e)))
  }
  expect_warning(b <- nie(td, level = "both"), class = "medfit_between_unidentified")
  expect_equal(unname(val(b)), c(0.2, NA))
  expect_warning(d <- nde(td, level = "between"), class = "medfit_between_unidentified")
  expect_true(is.na(val(d)))
  expect_warning(p <- pm(td, level = "between"), class = "medfit_between_unidentified")
  expect_true(is.na(val(p)))
})

test_that("a constrained path makes only the contrast NA, with the constrained warning", {
  for (eq in list("a", "b", c("a", "b"))) {
    td <- tl_td(cross_level_equal = eq)
    expect_warning(e <- nie(td, level = "contrast"), class = "medfit_warning_twolevel_constrained")
    expect_true(is.na(val(e)))
    expect_no_warning(b <- nie(td, level = "between"))
    expect_equal(val(b), 1.05)
  }
  # an equated c' alone does not constrain the NIE contrast
  td <- tl_td(cross_level_equal = "c_prime")
  expect_no_warning(e <- nie(td, level = "contrast"))
  expect_false(is.na(val(e)))
})

test_that("paths() returns the six paths; between entries are NA when within-only", {
  p <- paths(tl_td())
  expect_identical(names(p), c("a_within", "b_within", "c_prime_within",
                               "a_between", "b_between", "c_prime_between"))
  expect_equal(unname(p), c(0.4, 0.5, 0.3, 0.7, 1.5, -0.1))
  q <- paths(tl_td(within_only = TRUE))
  expect_identical(names(q), names(p))
  expect_equal(unname(q), c(0.4, 0.5, 0.3, NA, NA, NA))
})

test_that("decompose() gives the three NIE numbers, labeled descriptive, no SE", {
  d <- decompose(tl_td())
  expect_identical(names(d), c("within", "between", "contrast"))
  expect_equal(as.numeric(d), c(0.2, 1.05, 0.2 - 1.05))
  expect_match(attr(d, "label"), "contrast is not a test")
  expect_warning(dc <- decompose(tl_td(cross_level_equal = "a")), class = "medfit_warning_twolevel_constrained")
  expect_true(is.na(dc[["contrast"]]))
  expect_warning(dw <- decompose(tl_td(within_only = TRUE)), class = "medfit_between_unidentified")
  expect_equal(as.numeric(dw), c(0.2, NA, NA))
})

test_that("real fits: equated paths give an NA contrast, a degenerate X a within-only object", {
  skip_if_not_installed("lavaan")
  for (fx in c("shared_label", "equal_rows")) {
    td <- tl_extract(tl_fixture(fx))
    expect_true("a" %in% td@cross_level_equal, info = fx)
    expect_warning(e <- nie(td, level = "contrast"), class = "medfit_warning_twolevel_constrained")
    expect_true(is.na(val(e)), info = fx)
    expect_warning(t_c <- tidy(td, type = "effects"), class = "medfit_warning_twolevel_constrained")
    expect_true(is.na(t_c$estimate[t_c$term == "nie_contrast"]))
    expect_true(is.finite(t_c$std_error[t_c$term == "nie_between"]))
  }
  w <- tl_extract(tl_fixture("x_centered"))
  expect_warning(e <- nie(w, level = "between"), class = "medfit_between_unidentified")
  expect_true(is.na(val(e)))
  expect_true(is.finite(val(nie(w))))
})

test_that("planted defect: a shared label read as a free contrast is caught", {
  skip_if_not_installed("lavaan")
  testthat::local_mocked_bindings(.twolevel_cross_equal = function(pt, key) character(0), .package = "medfit")
  td <- tl_extract(tl_fixture("shared_label"))
  # the defect leaves a contrast that is zero by constraint looking like an estimate
  expect_false(is.na(val(suppressWarnings(nie(td, level = "contrast")))))
  expect_false(identical(td@cross_level_equal, "a"))
})

test_that("effects of a lavaan fit match lavaan's own := definitions (O3, estimates)", {
  skip_if_not_installed("lavaan")
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  pe <- lavaan::parameterEstimates(fit)
  a <- pe$est[match(c("a", "b", "cp", "a2", "b2", "cp2"), pe$label)]
  expect_equal(val(nie(td)), a[1] * a[2], tolerance = 1e-12)
  expect_equal(val(nie(td, level = "between")), a[4] * a[5], tolerance = 1e-12)
  expect_equal(val(nie(td, level = "contrast")), a[1] * a[2] - a[4] * a[5], tolerance = 1e-12)
  expect_equal(val(te(td)), a[1] * a[2] + a[3], tolerance = 1e-12)
})


# --- Hardening 1: PM is defined only for a TE away from zero relative to the effect scale ---

# A valid object with a_within * b_within = 1 and the given within c'.
tl_td_pm <- function(cp) {
  est <- c(a_within = 1, b_within = 1, c_prime_within = cp, a_between = 0.7, b_between = 1.5,
           c_prime_between = -0.1)
  tl_td(a_within = 1, b_within = 1, c_prime_within = cp, estimates = est)
}

test_that("pm() uses a relative tolerance: TE near zero relative to NIE and NDE is undefined", {
  # a*b = 1, c' = -1 + 1e-9: TE = 1e-9 is above machine epsilon but far below sqrt(eps) * 1
  td_tiny <- tl_td_pm(-1 + 1e-9)
  expect_warning(p <- pm(td_tiny), "approximately zero")
  expect_true(is.na(val(p)))
  expect_true(is.na(val(tidy_pm <- twolevel_statistic(td_tiny, "pm_within")(td_tiny@estimates))))

  # c' = -1 + 1e-6: TE = 1e-6 is above the relative threshold, so PM is finite (about 1e6)
  td_ok <- tl_td_pm(-1 + 1e-6)
  expect_no_warning(p_ok <- pm(td_ok))
  expect_true(is.finite(val(p_ok)))
  expect_equal(val(p_ok), 1 / (1e-6), tolerance = 1e-6)
  expect_equal(twolevel_statistic(td_ok, "pm_within")(td_ok@estimates), val(p_ok))

  # an exact zero stays undefined, with the warning
  td_zero <- tl_td_pm(-1)
  expect_warning(p0 <- pm(td_zero), "approximately zero")
  expect_true(is.na(val(p0)))
  expect_true(is.na(twolevel_statistic(td_zero, "pm_within")(td_zero@estimates)))
})

test_that("the PM gradient and SE use the same relative rule", {
  td_tiny <- tl_td_pm(-1 + 1e-9)
  g <- .effect_gradients_twolevel(td_tiny)
  expect_true(all(is.na(g$pm_within)))
  td_ok <- tl_td_pm(-1 + 1e-6)
  expect_false(anyNA(.effect_gradients_twolevel(td_ok)$pm_within))
})
