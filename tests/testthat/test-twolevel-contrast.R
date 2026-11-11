# Contrast rule C-Q1 and numeric equality detection C-Q2 (#394, S2 follow-up).
#
# C-Q1: the within-minus-between NIE contrast a_w*b_w - a_b*b_b is returned unless BOTH a and b are
# equated across levels. C-Q2: a path is also recorded as equated when the estimated difference of its two
# alias rows and the variance of that difference are both effectively zero (never the correlation).
# Oracles: lavaan's own `:=` defined parameter (value and delta SE) and a hand delta method on lavaan's
# joint vcov, both independent of the adapter.

val <- function(e) as.numeric(unclass(e))

# lavaan `:=` contrast of a fit whose model is `model`, as c(est, se); `def` is the definition.
tl_defined_contrast <- function(model, def) {
  fit <- tl_fit(tl_sim(), paste0(model, "nc := ", def, "\n"))
  pe <- lavaan::parameterEstimates(fit)
  row <- pe[pe$op == ":=" & pe$lhs == "nc", ]
  c(est = row$est, se = row$se)
}

# Hand delta method on lavaan's own free-parameter vcov, by variable names and level: no adapter code.
tl_hand_contrast <- function(fit) {
  pt <- lavaan::parTable(fit)
  V <- lavaan::vcov(fit)
  pick <- function(level, lhs, rhs) {
    r <- pt[pt$op == "~" & pt$level == level & pt$lhs == lhs & pt$rhs == rhs, ]
    list(est = r$est, free = r$free)
  }
  aw <- pick(1, "M", "X"); bw <- pick(1, "Y", "M")
  ab <- pick(2, "M", "X"); bb <- pick(2, "Y", "M")
  # shared free indices add their gradient entries: d/d theta_k of aw*bw - ab*bb
  g <- numeric(nrow(V))
  g[aw$free] <- g[aw$free] + bw$est
  g[bw$free] <- g[bw$free] + aw$est
  g[ab$free] <- g[ab$free] - bb$est
  g[bb$free] <- g[bb$free] - ab$est
  c(est = aw$est * bw$est - ab$est * bb$est, se = sqrt(drop(t(g) %*% V %*% g)))
}

tl_contrast_row <- function(td) {
  t <- suppressWarnings(tidy(td, type = "effects"))
  unlist(t[t$term == "nie_contrast", c("estimate", "std_error")])
}

# --- C-Q1: the rule on hand-built objects --------------------------------------------------------------

test_that("the contrast is available unless both a and b are equated (C-Q1)", {
  expect_true(.twolevel_contrast_available(tl_td()))
  expect_true(.twolevel_contrast_available(tl_td(cross_level_equal = "a")))
  expect_true(.twolevel_contrast_available(tl_td(cross_level_equal = "b")))
  expect_true(.twolevel_contrast_available(tl_td(cross_level_equal = "c_prime")))
  expect_true(.twolevel_contrast_available(tl_td(cross_level_equal = c("a", "c_prime"))))
  expect_false(.twolevel_contrast_available(tl_td(cross_level_equal = c("a", "b"))))
  expect_false(.twolevel_contrast_available(tl_td(cross_level_equal = c("a", "b", "c_prime"))))
  expect_false(.twolevel_contrast_available(tl_td(within_only = TRUE)))
})

test_that("with one of a or b equated the contrast, its SE and the statistic are returned", {
  for (eq in c("a", "b")) {
    td <- tl_td_cov(cross_level_equal = eq)
    expect_no_warning(e <- nie(td, level = "contrast"))
    expect_equal(val(e), 0.2 - 1.05, info = eq)
    expect_no_warning(d <- decompose(td))
    expect_equal(d[["contrast"]], 0.2 - 1.05, info = eq)
    r <- tl_contrast_row(td)
    expect_equal(unname(r["estimate"]), 0.2 - 1.05, info = eq)
    g <- c(a_within = 0.5, b_within = 0.4, a_between = -1.5, b_between = -0.7)
    expect_equal(unname(r["std_error"]), tl_hand_se(td, g), tolerance = 1e-12, info = eq)
    expect_type(twolevel_statistic(td, "nie_contrast"), "closure")
  }
})

test_that("with both a and b equated the contrast is NA with the constrained warning and error", {
  td <- tl_td_cov(cross_level_equal = c("a", "b"))
  expect_warning(e <- nie(td, level = "contrast"), class = "medfit_warning_twolevel_constrained")
  expect_true(is.na(val(e)))
  expect_warning(d <- decompose(td), class = "medfit_warning_twolevel_constrained")
  expect_true(is.na(d[["contrast"]]))
  expect_warning(t_c <- tidy(td, type = "effects"), class = "medfit_warning_twolevel_constrained")
  expect_true(is.na(t_c$estimate[t_c$term == "nie_contrast"]))
  expect_true(is.na(t_c$std_error[t_c$term == "nie_contrast"]))
  expect_error(twolevel_statistic(td, "nie_contrast"), class = "medfit_error_twolevel_constrained")
  out <- paste(utils::capture.output(print(td)), collapse = "\n")
  expect_match(out, "NA (constrained)", fixed = TRUE)
  one <- paste(utils::capture.output(print(tl_td(cross_level_equal = "a"))), collapse = "\n")
  expect_no_match(one, "NA (constrained)", fixed = TRUE)
})

test_that("planted defect: the rule reverted to 'either equated' is caught", {
  testthat::local_mocked_bindings(
    .twolevel_contrast_available = function(x) {
      isTRUE(x@between_identified) && !any(c("a", "b") %in% x@cross_level_equal)
    },
    .package = "medfit"
  )
  expect_false(.twolevel_contrast_available(tl_td(cross_level_equal = "a")))
  # which is exactly what the tests above assert to be TRUE: the defect makes them fail
  td <- tl_td_cov(cross_level_equal = "a")
  expect_true(is.na(suppressWarnings(val(nie(td, level = "contrast")))))
})

# --- C-Q1: real fits against lavaan's := and a hand delta method ------------------------------------------

test_that("only a equated: contrast and delta SE equal lavaan's := and the hand delta method (1e-4)", {
  skip_if_not_installed("lavaan")
  model_a <- tl_model(within = "a*X", between = "a*X")
  ora <- tl_defined_contrast(model_a, "a*b - a*b2")
  fit <- tl_fixture("shared_label")
  td <- tl_extract(fit)
  expect_identical(td@cross_level_equal, "a")
  row <- tl_contrast_row(td)
  expect_equal(unname(row["estimate"]), unname(ora["est"]), tolerance = 1e-4)
  expect_equal(unname(row["std_error"]), unname(ora["se"]), tolerance = 1e-4)
  hand <- tl_hand_contrast(fit)
  expect_equal(unname(row["estimate"]), unname(hand["est"]), tolerance = 1e-4)
  expect_equal(unname(row["std_error"]), unname(hand["se"]), tolerance = 1e-4)
  # a * (b_within - b_between), and a finite positive SE
  expect_equal(unname(row["estimate"]), td@a_within * (td@b_within - td@b_between), tolerance = 1e-8)
  expect_gt(unname(row["std_error"]), 0)
  expect_no_warning(e <- nie(td, level = "contrast"))
  expect_equal(val(e), unname(ora["est"]), tolerance = 1e-4)
})

test_that("only b equated (a separate fit): contrast and delta SE equal lavaan's := and the hand delta", {
  skip_if_not_installed("lavaan")
  ora <- tl_defined_contrast(tl_model_b_shared(), "a*b - a2*b")
  fit <- tl_fixture("shared_b")
  td <- tl_extract(fit)
  expect_identical(td@cross_level_equal, "b")
  row <- tl_contrast_row(td)
  expect_equal(unname(row["estimate"]), unname(ora["est"]), tolerance = 1e-4)
  expect_equal(unname(row["std_error"]), unname(ora["se"]), tolerance = 1e-4)
  hand <- tl_hand_contrast(fit)
  expect_equal(unname(row["estimate"]), unname(hand["est"]), tolerance = 1e-4)
  expect_equal(unname(row["std_error"]), unname(hand["se"]), tolerance = 1e-4)
  expect_equal(unname(row["estimate"]), (td@a_within - td@a_between) * td@b_within, tolerance = 1e-8)
  expect_gt(unname(row["std_error"]), 0)
  # the gradient is not the a-only one: swapping the two oracles' roles must not agree with this SE
  expect_false(isTRUE(all.equal(unname(row["std_error"]), unname(tl_contrast_row(tl_extract(tl_fixture("shared_label")))["std_error"]),
                                tolerance = 1e-3)))
})

test_that("both a and b equated (labels): the contrast is NA and the statistic raises the classed error", {
  skip_if_not_installed("lavaan")
  td <- tl_extract(tl_fixture("shared_ab"))
  expect_identical(td@cross_level_equal, c("a", "b"))
  expect_warning(e <- nie(td, level = "contrast"), class = "medfit_warning_twolevel_constrained")
  expect_true(is.na(val(e)))
  expect_error(twolevel_statistic(td, "nie_contrast"), class = "medfit_error_twolevel_constrained")
  expect_true(is.finite(val(nie(td, level = "between"))))
})

# --- C-Q2: the pair criterion on synthetic covariances -----------------------------------------------------

# A 2x2 covariance of (w, b) with the given SDs and correlation.
tl_pair_V <- function(sd_w, sd_b, r) matrix(c(sd_w^2, r * sd_w * sd_b, r * sd_w * sd_b, sd_b^2), 2L)

# Every case the criterion must get right: a list of (est, V, want). Returns TRUE when `fn` is right on all.
tl_pair_cases <- function() {
  list(
    list(name = "identical", est = c(0.5, 0.5), V = tl_pair_V(0.05, 0.05, 1), want = TRUE),
    list(name = "identical, solver noise 1e-8", est = c(0.5, 0.5 + 9e-9), V = tl_pair_V(0.05, 0.05, 1), want = TRUE),
    list(name = "identical, large scale", est = c(500, 500 + 9e-6), V = tl_pair_V(50, 50, 1), want = TRUE),
    list(name = "correlation -1, unequal", est = c(0.5, -0.5), V = tl_pair_V(0.05, 0.05, -1), want = FALSE),
    list(name = "proportional, correlation +1, unequal", est = c(0.5, 1.0), V = tl_pair_V(0.05, 0.10, 1), want = FALSE),
    list(name = "r just inside 1 - 1e-8, nonzero difference", est = c(0.5, 0.51),
         V = tl_pair_V(0.05, 0.05, 1 - 1e-9), want = FALSE),
    list(name = "r = 1 - 1e-12, difference 0.01", est = c(0.5, 0.51), V = tl_pair_V(0.05, 0.05, 1 - 1e-12), want = FALSE),
    list(name = "r = 1, difference 1e-3 (tolerance 1e-2 would flag it)", est = c(0.5, 0.501),
         V = tl_pair_V(0.05, 0.05, 1), want = FALSE),
    list(name = "equal estimates, independent (a free difference)", est = c(0.5, 0.5),
         V = tl_pair_V(0.05, 0.05, 0), want = FALSE),
    list(name = "equal estimates, correlation 0.99", est = c(0.5, 0.5), V = tl_pair_V(0.05, 0.05, 0.99), want = FALSE)
  )
}

# TRUE when `fn(est, V)` returns the wanted verdict on every case; the failing names are attached.
tl_pair_cases_ok <- function(fn) {
  res <- vapply(tl_pair_cases(), function(k) identical(isTRUE(fn(k$est, k$V)), k$want), logical(1))
  structure(all(res), failed = vapply(tl_pair_cases(), `[[`, "", "name")[!res])
}

test_that("the pair criterion flags only a zero difference with a zero-variance difference", {
  ok <- tl_pair_cases_ok(.twolevel_pair_equal)
  expect_true(ok, info = paste(attr(ok, "failed"), collapse = "; "))
})

test_that("planted defect: a correlation-only rule is caught by the not-flagged cases", {
  corr_only <- function(est, V) abs(V[1, 2] / sqrt(V[1, 1] * V[2, 2])) >= 1 - 1e-8
  ok <- tl_pair_cases_ok(corr_only)
  expect_false(ok)
  expect_true(all(c("correlation -1, unequal", "proportional, correlation +1, unequal") %in% attr(ok, "failed")))
})

test_that("planted defect: a difference tolerance of 1e-2 is caught", {
  loose <- function(est, V) abs(est[1] - est[2]) <= 1e-2 && (V[1, 1] + V[2, 2] - 2 * V[1, 2]) <= 1e-10 * (V[1, 1] + V[2, 2])
  ok <- tl_pair_cases_ok(loose)
  expect_false(ok)
  expect_true("r = 1, difference 1e-3 (tolerance 1e-2 would flag it)" %in% attr(ok, "failed"))
})

test_that("the tolerances are documented defaults and can be read through options", {
  expect_equal(.twolevel_option("equal_diff"), 1e-6)
  expect_equal(.twolevel_option("equal_var"), 1e-10)
  withr::local_options(medfit.twolevel_equal_diff = 1e-2)
  expect_equal(.twolevel_option("equal_diff"), 1e-2)
})

# --- C-Q2: real fits, every detection route agrees ---------------------------------------------------------

test_that("an algebraic equality lavaan keeps as two parameters is flagged by the numeric route alone", {
  skip_if_not_installed("lavaan")
  expect_identical(tl_extract(tl_fixture("nl_a"))@cross_level_equal, "a")
  expect_identical(tl_extract(tl_fixture("nl_b"))@cross_level_equal, "b")
  expect_identical(tl_extract(tl_fixture("nl_ab"))@cross_level_equal, c("a", "b"))
  # the nonlinear fit has distinct free indices: neither label route can see it
  pt <- lavaan::parTable(tl_fixture("nl_a"))
  idx <- pt$free[pt$op == "~" & pt$lhs == "M" & pt$rhs == "X" & pt$level %in% 1:2]
  expect_length(unique(idx), 2L)
})

test_that("all detection routes agree on the label, index, == and algebraic forms of a equated", {
  skip_if_not_installed("lavaan")
  for (fx in c("shared_label", "equal_rows", "nl_a")) {
    fit <- tl_fixture(fx)
    td <- tl_extract(fit)
    pt <- lavaan::parTable(fit)
    key <- .twolevel_key_rows(pt, "X", "M", "Y")
    numeric_only <- .twolevel_numeric_equal(key, td@vcov)
    expect_identical(numeric_only, "a", info = fx)
    expect_identical(td@cross_level_equal, "a", info = fx)
  }
  base <- tl_extract(tl_fixture("base"))
  key <- .twolevel_key_rows(lavaan::parTable(tl_fixture("base")), "X", "M", "Y")
  expect_identical(.twolevel_numeric_equal(key, base@vcov), character(0))
})

test_that("with a algebraically equated the contrast is returned; with a and b both, it is NA", {
  skip_if_not_installed("lavaan")
  td_a <- tl_extract(tl_fixture("nl_a"))
  expect_no_warning(e <- nie(td_a, level = "contrast"))
  expect_equal(val(e), td_a@a_within * (td_a@b_within - td_a@b_between), tolerance = 1e-6)
  td_ab <- tl_extract(tl_fixture("nl_ab"))
  expect_warning(e2 <- nie(td_ab, level = "contrast"), class = "medfit_warning_twolevel_constrained")
  expect_true(is.na(val(e2)))
  expect_error(twolevel_statistic(td_ab, "nie_contrast"), class = "medfit_error_twolevel_constrained")
})

test_that("planted defect: dropping the numeric route leaves an algebraic both-equated contrast looking free", {
  skip_if_not_installed("lavaan")
  testthat::local_mocked_bindings(.twolevel_numeric_equal = function(key, V) character(0), .package = "medfit")
  td <- tl_extract(tl_fixture("nl_ab"))
  expect_false(identical(td@cross_level_equal, c("a", "b")))
})
