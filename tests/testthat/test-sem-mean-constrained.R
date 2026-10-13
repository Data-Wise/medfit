# Constraints, MBCO and re-fits with a mean structure (0.9.0 S5).

con_base <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\noutcome ~ i1*1\nmediator1 ~ i2*1"

# the demo data moved far from zero: same model, intercepts change, everything else must not
far_data <- function(shift, scale = 1) {
  d <- mediation_demo
  d$outcome <- d$outcome * scale + shift
  d$mediator1 <- d$mediator1 * scale + shift
  d
}

test_that("linear intercept constraints hold exactly and match lavaan", {
  fit <- fit_sem(paste0(con_base, "\ni1 == i2"), mediation_demo)
  expect_equal(unname(fit@theta["i1"]), unname(fit@theta["i2"]), tolerance = 1e-9)
  expect_equal(fit@df, 1)
  fixed <- fit_sem(paste0(con_base, "\ni1 == 0.5"), mediation_demo)
  expect_equal(unname(fixed@theta["i1"]), 0.5, tolerance = 1e-9)
  skip_if_not_installed("lavaan")
  lav <- lavaan::sem(paste0(con_base, "\ni1 == i2"), mediation_demo, meanstructure = TRUE, fixed.x = FALSE)
  expect_equal(fit@f * fit@n_obs, unname(lavaan::fitMeasures(lav, "chisq")), tolerance = 1e-5)
  expect_equal(unname(fit@theta[c("a", "b", "cp", "i1")]), unname(lavaan::coef(lav)[c("a", "b", "cp", "i1")]),
               tolerance = 1e-4)
})

test_that("a nonlinear constraint with free intercepts is invariant to the location of the data", {
  near <- fit_sem(paste0(con_base, "\ncp == a*b"), mediation_demo)
  far <- fit_sem(paste0(con_base, "\ncp == a*b"), far_data(1e4))
  keep <- c("a", "b", "cp")
  expect_true(far@converged)
  expect_equal(far@theta[keep], near@theta[keep], tolerance = 1e-6)
  expect_equal(far@f, near@f, tolerance = 1e-8)
  expect_false(anyNA(far@vcov))
  expect_equal(sqrt(diag(far@vcov))[keep], sqrt(diag(near@vcov))[keep], tolerance = 1e-5)
  # the intercepts moved by the shift through the paths: i = mean - A mean
  expect_equal(unname(far@theta["i2"]), unname(near@theta["i2"] + 1e4 * (1 - near@theta["a"] * 0)), tolerance = 1e-3)
})

test_that("an active bound on an intercept equals the fixed-intercept regression (bound in theta units)", {
  bounded <- fit_sem(paste0(con_base, "\ni1 > 0.4"), mediation_demo)
  expect_equal(unname(bounded@theta["i1"]), 0.4, tolerance = 1e-8)
  d <- mediation_demo
  ols <- stats::lm(I(outcome - 0.4) ~ 0 + mediator1 + treatment, d)
  expect_equal(unname(bounded@theta[c("b", "cp")]), unname(stats::coef(ols)), tolerance = 1e-5)
  se <- sqrt(diag(bounded@vcov))
  ols_se <- sqrt(diag(stats::vcov(ols)) * (nrow(d) - 2) / nrow(d))
  expect_equal(unname(se[c("b", "cp")]), unname(ols_se), tolerance = 1e-4)
  slack <- fit_sem(paste0(con_base, "\ni1 > -5"), mediation_demo)
  expect_equal(unname(slack@theta["i1"]), unname(fit_sem(con_base, mediation_demo)@theta["i1"]), tolerance = 1e-6)
  zero <- fit_sem(paste0(con_base, "\na*b == 0"), mediation_demo)
  expect_true(zero@converged)
  expect_gt(zero@f, 0)
})

test_that("the centered route is used only when every intercept is free and absent from the constraints", {
  fit <- fit_sem(paste0(con_base, "\ncp == a*b"), mediation_demo)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  lb <- rep(-Inf, ram$q)
  ub <- rep(Inf, ram$q)
  none <- rep(FALSE, ram$q)
  cons <- function(txt) .sem_parse(paste0(con_base, "\n", txt))$constraints
  expect_true(.sem_shift_ok(ram, smp, cons("cp == a*b"), lb, ub, none))
  expect_false(.sem_shift_ok(ram, smp, cons("i1 == i2"), lb, ub, none))
  broken <- sem_mutate(.sem_shift_ok, "!any(ram$par_names[ram$k_m] %in% used)", "TRUE")
  expect_true(broken(ram, smp, cons("i1 == i2"), lb, ub, none))
})

test_that("MBCO carries the mean structure into its refits", {
  syn <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
  flagged <- fit_sem(syn, mediation_demo, meanstructure = TRUE)
  seen <- NULL
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    seen <<- c(seen, list(list(...)$meanstructure))
    stop("stop after capturing")
  })
  try(mbco_sem(flagged, "a", "b"), silent = TRUE)
  expect_true(all(vapply(seen, isTRUE, TRUE)) && length(seen) > 0L)
  seen <- NULL
  try(mbco_sem(fit_sem(syn, mediation_demo), "a", "b"), silent = TRUE)
  expect_true(all(vapply(seen, is.null, TRUE)) && length(seen) > 0L)
})

test_that("fit_mediation(engine = 'native', engine_args = list(meanstructure = TRUE)) reaches the fit", {
  args <- list(model = "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment", data = mediation_demo,
               treatment = "treatment", mediator = "mediator1", engine = "native")
  off <- do.call(fit_mediation, args)
  on <- do.call(fit_mediation, c(args, list(engine_args = list(meanstructure = TRUE))))
  expect_equal(c(on@a_path, on@b_path, on@c_prime), c(off@a_path, off@b_path, off@c_prime), tolerance = 1e-6)
  fit <- do.call(fit_sem, list(model = args$model, data = mediation_demo, meanstructure = TRUE))
  expect_true(fit@internals$ram$has_mean)
})

test_that("zero-product branches keep the flag", {
  fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\na*b == 0", mediation_demo,
                 meanstructure = TRUE)
  expect_true(fit@internals$ram$has_mean)
  expect_gt(length(fit@theta), 6L)
})

test_that("an intercept equality converges at a location of 1e3 (centered projected gate) and is location-invariant", {
  syn <- "mediator1 ~ a*treatment + i2*1\noutcome ~ b*mediator1 + cp*treatment + i1*1\ni1 == i2"
  near <- fit_sem(syn, mediation_demo)
  far <- fit_sem(syn, far_data(1e3))
  expect_true(far@converged)
  expect_false(anyNA(far@vcov))
  expect_equal(unname(far@theta["i1"]), unname(far@theta["i2"]), tolerance = 1e-9)
  # moving both variables by 1e3 changes the model once the intercepts are equated, so compare the fit to lavaan
  skip_if_not_installed("lavaan")
  ref <- lavaan::sem(syn, far_data(1e3), meanstructure = TRUE, fixed.x = FALSE)
  expect_equal(unname(far@f * far@n_obs), unname(lavaan::fitMeasures(ref, "chisq")), tolerance = 1e-4)
  expect_equal(unname(far@theta[c("a", "b", "cp")]), unname(lavaan::coef(ref)[c("a", "b", "cp")]), tolerance = 1e-4)
})

test_that("planted defect: with no centered coordinates a nonlinear constraint at a location of 1e4 is rejected", {
  syn <- paste0(con_base, "\ncp == a*b")
  expect_true(fit_sem(syn, far_data(1e4))@converged)
  testthat::local_mocked_bindings(.sem_center_map = function(ram, smp) NULL, .sem_shift_ok = function(...) FALSE)
  expect_error(fit_sem(syn, far_data(1e4)), "no start converged")
})
