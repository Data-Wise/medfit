# compare_lr() in OpenMx on fits with `fixed_x` (all, a named subset, a lenient subset) and a saturated mean structure
# (R-4, plan T4c; design in planning/specs/NOTE-compare-lr-fixed-set-2026-10-24.md, decision 2). The fit's fixed set
# is written as fixed paths at the sample moments; with a mean structure the model runs on raw data with a means path.

skip_if_not_installed("OpenMx")

ofs_base <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + cp*treatment + covariate1\n"
ofs_lenient <- paste0(ofs_base, "treatment ~~ treatment\n")

ofs_fit <- function(model, fixed_x, meanstructure = NULL) {
  suppressWarnings(fit_sem(model, medfit::mediation_demo, fixed_x = fixed_x, meanstructure = meanstructure))
}

ofs_cells <- list(
  "fixed_x = TRUE" = list(model = ofs_base, fixed_x = TRUE, ms = NULL),
  "named subset" = list(model = ofs_base, fixed_x = "covariate1", ms = NULL),
  "lenient subset" = list(model = ofs_lenient, fixed_x = "covariate1", ms = NULL),
  "meanstructure" = list(model = ofs_base, fixed_x = FALSE, ms = TRUE),
  "fixed_x = TRUE with means" = list(model = ofs_base, fixed_x = TRUE, ms = TRUE),
  "named subset with means" = list(model = ofs_base, fixed_x = "covariate1", ms = TRUE),
  "lenient subset with means" = list(model = ofs_lenient, fixed_x = "covariate1", ms = TRUE)
)

for (cell in names(ofs_cells)) {
  test_that(sprintf("compare_lr() in OpenMx matches medfit and lavaan on the product null: %s", cell), {
    spec <- ofs_cells[[cell]]
    fit <- ofs_fit(spec$model, spec$fixed_x, spec$ms)
    ref <- medfit:::.lr_reference(fit, c("a", "b"))
    eng <- medfit:::.lr_engine_openmx(fit, c("a", "b"))
    # same unrestricted model: parameter keys, estimates and discrepancy
    expect_setequal(names(eng$est), names(ref$est))
    expect_equal(unname(eng$est[names(ref$est)]), unname(ref$est), tolerance = 1e-4)
    expect_equal(eng$fit, ref$fit, tolerance = 1e-6)
    out <- suppressWarnings(compare_lr(fit, paths = c("a", "b"), engine = "openmx"))
    med_lr <- min(suppressWarnings(mbco_sem(fit, "a", "b"))$tests$diff_ll)
    expect_equal(out$reference$lr, med_lr, tolerance = 1e-6)
    expect_identical(out$runs$status[out$runs$start == "default"], "agree")
    expect_equal(out$runs$lr[out$runs$start == "default"], med_lr, tolerance = 1e-5)
    if (requireNamespace("lavaan", quietly = TRUE)) {
      lav <- compare_lr(fit, paths = c("a", "b"), engine = "lavaan")
      expect_equal(out$runs$lr[out$runs$start == "default"], lav$runs$lr[lav$runs$start == "default"],
                   tolerance = 1e-5)
    }
    # the zero start may drop the constraint (OpenMx#433); that is reported as evidence, never as an unexplained LR
    zero <- out$runs[out$runs$start == "zero", ]
    expect_true(zero$status %in% c("agree", "constraint_violated", "above_reference", "below_reference"))
  })
}

test_that("the fixed set becomes fixed paths at the sample moments, and means switch to raw data", {
  fit <- ofs_fit(ofs_base, "covariate1", TRUE)
  tab <- fit@table
  m <- medfit:::.lr_openmx_model(fit, paste0("p", seq_len(nrow(tab))), tab$est)
  n <- nrow(fit@data)
  v <- stats::var(fit@data$covariate1) * (n - 1) / n
  expect_false(m$S$free["covariate1", "covariate1"])
  expect_equal(m$S$values["covariate1", "covariate1"], v, tolerance = 1e-12)
  expect_true(m$S$free["treatment", "treatment"])
  expect_false(m$M$free[1L, "covariate1"])
  expect_equal(unname(m$M$values[1L, "covariate1"]), mean(fit@data$covariate1), tolerance = 1e-12)
  expect_true(m$M$free[1L, "outcome"])
  expect_identical(m$data$type, "raw")
  expect_identical(nrow(m$data$observed), n)
  no_means <- ofs_fit(ofs_base, "covariate1", NULL)
  m2 <- medfit:::.lr_openmx_model(no_means, paste0("p", seq_len(nrow(no_means@table))), no_means@table$est)
  expect_identical(m2$data$type, "cov")
})

test_that("a user-fixed intercept and case weights are still refused in OpenMx", {
  fixed_int <- ofs_fit(paste0(ofs_base, "outcome ~ 0*1\n"), FALSE)
  expect_error(compare_lr(fixed_int, c("a", "b"), engine = "openmx"), "fixed or constrained intercepts", fixed = TRUE)
  weighted <- suppressWarnings(fit_sem(ofs_base, medfit::mediation_demo,
                                       weights = rep(1, nrow(medfit::mediation_demo))))
  expect_error(compare_lr(weighted, c("a", "b"), engine = "openmx"), "case weights", fixed = TRUE)
  fixed_path <- ofs_fit("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + 0.5*treatment", "treatment")
  expect_error(compare_lr(fixed_path, c("a", "b"), engine = "openmx"), "fixed or shared parameters", fixed = TRUE)
})

test_that("planted defect: fixing the exogenous paths at N - 1 moments in the OpenMx builder is caught", {
  fx_skip_covr()
  fit <- ofs_fit(ofs_base, "covariate1", NULL)
  good <- medfit:::.lr_engine_openmx(fit, c("a", "b"))
  ref <- medfit:::.lr_reference(fit, c("a", "b"))
  expect_identical(medfit:::.lr_assess(ref, list(good))$runs$status[1L], "agree")
  # Freeing the fixed paths would not be a defect (the LR is conditional on the exogenous block and does not move);
  # fixing them at the N - 1 moments poses a different model, which the unrestricted precheck must catch.
  bad <- sem_mutate(medfit:::.lr_openmx_model, "else row$est", "else row$est * object@n_obs/(object@n_obs - 1)")
  testthat::local_mocked_bindings(.lr_openmx_model = bad)
  eng <- medfit:::.lr_engine_openmx(fit, c("a", "b"))
  out <- medfit:::.lr_assess(ref, list(eng))
  expect_false(identical(out$verdict, "agree"))
  expect_match(out$reason, "unrestricted discrepancy differs", fixed = TRUE)
})
