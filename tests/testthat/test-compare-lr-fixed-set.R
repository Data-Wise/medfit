# compare_lr() in lavaan on fits with `fixed_x` (all, a named subset, a lenient subset) and a saturated mean structure
# (R-4, plan T4b; design in planning/specs/NOTE-compare-lr-fixed-set-2026-10-24.md). The lavaan model is posed with
# fixed.x = FALSE and the fit's fixed set written as fixed rows at the sample moments, so lavaan's LR must equal its
# own logLik difference and medfit's deviance difference on the product null.

skip_if_not_installed("lavaan")

fs_base <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + cp*treatment + covariate1\n"
fs_lenient <- paste0(fs_base, "treatment ~~ treatment\n")

fs_fit <- function(model, fixed_x, meanstructure = NULL) {
  suppressWarnings(fit_sem(model, medfit::mediation_demo, fixed_x = fixed_x, meanstructure = meanstructure))
}

# lavaan's own LR on the product null, from the same model text the adapter writes: the minimum over the branch fits
# a == 0 and b == 0 (what medfit's reference is), as 2 * (logLik1 - logLik0).
fs_lavaan_branch_lr <- function(fit, writer = medfit:::.lr_lavaan_model) {
  spec <- writer(fit)
  one <- function(extra) {
    lavaan::lavaan(paste0(spec$model, extra), data = fit@data, fixed.x = FALSE, meanstructure = spec$meanstructure,
                   int.ov.free = spec$meanstructure, auto.var = TRUE, auto.cov.y = TRUE)
  }
  f1 <- one("")
  lr <- vapply(c("\na == 0", "\nb == 0"), function(r) unname(2 * (lavaan::logLik(f1) - lavaan::logLik(one(r)))), 0)
  min(lr)
}

fs_cells <- list(
  "fixed_x = TRUE" = list(model = fs_base, fixed_x = TRUE, ms = NULL),
  "named subset" = list(model = fs_base, fixed_x = "covariate1", ms = NULL),
  "lenient subset" = list(model = fs_lenient, fixed_x = "covariate1", ms = NULL),
  "meanstructure" = list(model = fs_base, fixed_x = FALSE, ms = TRUE),
  "fixed_x = TRUE with means" = list(model = fs_base, fixed_x = TRUE, ms = TRUE),
  "named subset with means" = list(model = fs_base, fixed_x = "covariate1", ms = TRUE),
  "lenient subset with means" = list(model = fs_lenient, fixed_x = "covariate1", ms = TRUE)
)

for (cell in names(fs_cells)) {
  test_that(sprintf("compare_lr() agrees with lavaan and medfit on the product null: %s", cell), {
    spec <- fs_cells[[cell]]
    fit <- fs_fit(spec$model, spec$fixed_x, spec$ms)
    out <- compare_lr(fit, paths = c("a", "b"), engine = "lavaan")
    expect_identical(out$verdict, "agree")
    med_lr <- min(suppressWarnings(mbco_sem(fit, "a", "b"))$tests$diff_ll)
    lav_lr <- fs_lavaan_branch_lr(fit)
    expect_equal(out$reference$lr, med_lr, tolerance = 1e-6)
    expect_equal(lav_lr, med_lr, tolerance = 1e-6)
    expect_equal(out$runs$lr[out$runs$start == "default"], med_lr, tolerance = 1e-6)
  })
}

test_that("the fixed set is written as fixed rows at the sample moments, with fixed.x off", {
  fit <- fs_fit(fs_base, "covariate1", TRUE)
  spec <- medfit:::.lr_lavaan_model(fit)
  expect_true(spec$meanstructure)
  n <- nrow(fit@data)
  v <- stats::var(fit@data$covariate1) * (n - 1) / n
  expect_match(spec$model, sprintf("covariate1 ~~ %s*covariate1", formatC(v, digits = 17, format = "g")),
               fixed = TRUE)
  expect_match(spec$model, "covariate1 ~ ", fixed = TRUE)
  expect_false(grepl("treatment ~~ [0-9.e+-]+\\*treatment", spec$model))
})

test_that("a user-fixed intercept and case weights are still refused", {
  fixed_int <- fs_fit(paste0(fs_base, "outcome ~ 0*1\n"), FALSE)
  expect_error(compare_lr(fixed_int, c("a", "b"), engine = "lavaan"), "fixed or constrained intercepts", fixed = TRUE)
  weighted <- suppressWarnings(fit_sem(fs_base, mediation_demo, weights = rep(1, nrow(mediation_demo))))
  expect_error(compare_lr(weighted, c("a", "b"), engine = "lavaan"), "case weights", fixed = TRUE)
})

test_that("a non-free row outside the fixed set is still refused", {
  fit <- fs_fit("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + 0.5*treatment", "treatment")
  expect_error(compare_lr(fit, c("a", "b"), engine = "lavaan"), "fixed or shared parameters", fixed = TRUE)
})

test_that("planted defect: posing the named subset with lavaan fixed.x = TRUE is caught", {
  fit <- fs_fit(fs_base, "covariate1", NULL)
  good <- compare_lr(fit, paths = c("a", "b"), engine = "lavaan")
  expect_identical(good$verdict, "agree")
  # The mutant hands lavaan fixed.x = TRUE and no fixed rows: lavaan then fixes treatment as well, a different model.
  bad <- sem_mutate(medfit:::.lr_lavaan_model, "fixed.x <- FALSE", "fixed.x <- TRUE")
  testthat::local_mocked_bindings(.lr_lavaan_model = bad)
  out <- suppressWarnings(compare_lr(fit, paths = c("a", "b"), engine = "lavaan"))
  expect_false(identical(out$verdict, "agree"))
})

test_that("independent oracle: lavaan's own fixed.x = TRUE and a hand-written subset model give the same LR", {
  # Not the package's writer: lavaan's fixed.x = TRUE for the all-fixed cell, and for the named subset a model text
  # written here with only covariate1's variance and mean fixed at the N-denominator moments (treatment ~~ covariate1
  # free). The product-null LR is conditional on the exogenous block, so all three must agree.
  lav_lr <- function(model, data, fixed.x, ms) {
    one <- function(extra) lavaan::sem(paste0(model, extra), data = data, fixed.x = fixed.x, meanstructure = ms)
    f1 <- one("")
    min(vapply(c("\na == 0", "\nb == 0"), function(r) unname(2 * (lavaan::logLik(f1) - lavaan::logLik(one(r)))), 0))
  }
  for (ms in list(NULL, TRUE)) {
    all_fit <- fs_fit(fs_base, TRUE, ms)
    out <- compare_lr(all_fit, paths = c("a", "b"), engine = "lavaan")
    expect_equal(out$reference$lr, lav_lr(fs_base, all_fit@data, TRUE, isTRUE(ms)), tolerance = 1e-6)
    sub_fit <- fs_fit(fs_base, "covariate1", ms)
    x <- sub_fit@data$covariate1
    v <- mean((x - mean(x))^2)
    hand <- paste0(fs_base, sprintf("covariate1 ~~ %.17g*covariate1\ntreatment ~~ covariate1\n", v),
                   if (isTRUE(ms)) sprintf("covariate1 ~ %.17g*1\n", mean(x)) else "")
    sub <- compare_lr(sub_fit, paths = c("a", "b"), engine = "lavaan")
    expect_equal(sub$runs$lr[sub$runs$start == "default"], lav_lr(hand, sub_fit@data, FALSE, isTRUE(ms)),
                 tolerance = 1e-6)
  }
})
