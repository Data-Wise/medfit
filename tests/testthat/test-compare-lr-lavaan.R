# The lavaan adapter and the medfit reference of compare_lr() (#249 T2): real lavaan on the bundled data, plus the
# refusal of every construct outside the supported class.

skip_if_not_installed("lavaan")

model_txt <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
fit0 <- suppressWarnings(fit_sem(model_txt, mediation_demo))

test_that("the reference is the minimum branch LR with keyed estimates and an accepted flag", {
  ref <- medfit:::.lr_reference(fit0, c("a", "b"))
  mb <- suppressWarnings(mbco_sem(fit0, "a", "b"))
  expect_equal(ref$lr, min(mb$tests$diff_ll))
  expect_true(ref$accepted)
  expect_true(all(c("mediator1 ~ treatment", "outcome ~ mediator1", "outcome ~ treatment") %in% names(ref$est)))
  expect_equal(ref$fit, 0, tolerance = 1e-6) # saturated model: unrestricted discrepancy 0
})

test_that("lavaan fits the same unrestricted model: same parameter keys and discrepancy", {
  ref <- medfit:::.lr_reference(fit0, c("a", "b"))
  eng <- medfit:::.lr_engine_lavaan(fit0, c("a", "b"))
  expect_setequal(names(eng$est), names(ref$est))
  expect_equal(unname(eng$est[names(ref$est)]), unname(ref$est), tolerance = 1e-4)
  expect_equal(eng$fit, ref$fit, tolerance = 1e-6)
  expect_identical(vapply(eng$runs, function(r) r$start, ""), c("default", "zero"))
  expect_true(all(vapply(eng$runs, function(r) r$converged, NA)))
  expect_true(all(vapply(eng$runs, function(r) is.finite(r$residual_scale) && r$residual_scale > 0, NA)))
})

test_that("on a well-behaved model lavaan agrees with medfit, with no condition", {
  ref <- medfit:::.lr_reference(fit0, c("a", "b"))
  eng <- medfit:::.lr_engine_lavaan(fit0, c("a", "b"))
  out <- medfit:::.lr_assess(ref, list(eng))
  expect_identical(out$verdict, "agree")
  expect_length(out$conditions, 0L)
})

test_that("a reference below lavaan's statistic is flagged statistic_above_max (injected reference, real lavaan run)", {
  ref <- medfit:::.lr_reference(fit0, c("a", "b"))
  ref$lr <- ref$lr / 2
  eng <- medfit:::.lr_engine_lavaan(fit0, c("a", "b"))
  out <- medfit:::.lr_assess(ref, list(eng))
  expect_identical(out$verdict, "disagree")
  expect_true("medfit_warning_engine_statistic_above_max" %in% vapply(out$conditions, function(cnd) class(cnd)[1L], ""))
})

test_that("each construct outside the supported class is refused with its name", {
  d <- mediation_demo
  d$g <- factor(rep(c("u", "v"), length.out = nrow(d)))
  base <- model_txt
  refuse <- function(fit, what) {
    expect_error(medfit:::.lr_engine_lavaan(fit, c("a", "b")), what, fixed = TRUE)
  }
  refuse(suppressWarnings(fit_sem(paste0(base, "\nmediator1 ~ 1"), d)), "a mean structure")
  refuse(suppressWarnings(fit_sem(model_txt, d, weights = rep(1, nrow(d)))), "case weights")
  refuse(suppressWarnings(fit_sem(model_txt, d, fixed_x = TRUE)), "`fixed_x`")
  refuse(suppressWarnings(fit_sem(paste0(base, " + g"), d)), "factor covariates")
  refuse(suppressWarnings(fit_sem(paste0(base, "\nmediator1 ~ lower(0)*mediator2"), d)), "start, lower or upper")
  refuse(suppressWarnings(fit_sem(paste0(base, "\ncp == 0"), d)), "constraints in the model")
  refuse(suppressWarnings(fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + 0.5*treatment", d)),
         "fixed or shared parameters")
  refuse(suppressWarnings(fit_sem("mediator1 ~ a*treatment\noutcome ~ a*mediator1 + cp*treatment", d)),
         "fixed or shared parameters")
})
