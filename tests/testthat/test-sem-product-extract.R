# Native four-way extraction (0.10.0 plan U7): `extract_mediation(<SEMFit>)` finds the treatment-by-mediator product
# written `x:m` or `m:x` (stored under the canonical `m:x`) and returns an InteractionMediationData through the
# shared worker; the oracles are in helper-four-way-oracle.R.

skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")

sep_syntax <- function(prod, covs = "c1") {
  paste0("m ~ ", paste(c("x", covs), collapse = " + "), "\ny ~ ", paste(c("x", "m", prod, covs), collapse = " + "))
}

sep_fit <- function(d, prod = "x:m", covs = "c1", ...) {
  suppressWarnings(fit_sem(sep_syntax(prod, covs), d, information = "observed", ...))
}

test_that("both spellings of the product give the same four-way object, under the canonical name", {
  d <- fwo_data(800, 5, "c1")
  a <- extract_mediation(sep_fit(d, "x:m"), treatment = "x", mediator = "m")
  b <- extract_mediation(sep_fit(d, "m:x"), treatment = "x", mediator = "m", interaction = "x:m",
                         decomposition = "four_way")
  expect_s3_class(a, "medfit::InteractionMediationData")
  expect_equal(a@total_effect, b@total_effect)
  expect_equal(a@estimates, b@estimates)
  expect_identical(a@source_package, "medfit")
  # canonical name `m:x`, never the spelling written
  expect_true("y~m:x" %in% names(a@estimates))
  expect_false("y~x:m" %in% names(a@estimates))
  expect_true("m:x" %in% a@outcome_predictors)
  expect_false("x:m" %in% a@outcome_predictors)
  # downstream effect and SE code works on the canonical name
  expect_true(all(is.finite(.effect_se(a, c("cde", "int_ref", "int_med", "pie", "nde", "nie", "te")))))
})

test_that("a lookup by the written spelling fails (planted defect)", {
  fx_skip_covr()
  d <- fwo_data(800, 6, "c1")
  fit <- sep_fit(d, "x:m")
  expect_s3_class(extract_mediation(fit, treatment = "x", mediator = "m", decomposition = "four_way"),
                  "medfit::InteractionMediationData")
  mutated <- sem_mutate(.sem_native_interaction, "canon %in% stored", "paste0(treatment, \":\", mediator) %in% stored")
  local_mocked_bindings(.sem_native_interaction = mutated)
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m", decomposition = "four_way"),
               "needs the treatment-by-mediator product")
})

test_that("native components and SEs equal the independent oracles, with and without covariates", {
  for (nm in names(fwo_cases)) {
    covs <- fwo_cases[[nm]]
    d <- fwo_data(2000, 41, covs)
    r <- fwo_route_native(d, covs, m_star = 0.4)
    h <- fwo_hand(d, covs, m_star = 0.4, vcov_type = "ml")
    lv <- fwo_lavaan_defined(d, covs, m_star = 0.4)
    expect_lt(max(abs(r$est - h$est)), fwo_tol_optimizer)
    expect_lt(fwo_rel_gap(r$se, h$se), fwo_tol_optimizer)
    expect_lt(fwo_rel_gap(r$se, lv$se), fwo_tol_optimizer)
  }
})

test_that("a model with a mediator covariate keeps its coefficient in the object", {
  d <- fwo_data(1000, 42, c("c1", "c2"))
  o <- extract_mediation(sep_fit(d, "m:x", c("c1", "c2")), treatment = "x", mediator = "m")
  expect_true(all(c("m_c1", "m_c2") %in% names(o@estimates)))
  expect_equal(unname(o@estimates["m_c1"]), unname(stats::coef(stats::lm(m ~ x + c1 + c2, d))["c1"]),
               tolerance = 1e-4)
})

test_that("weighted native components equal the glm route and the weighted closed form", {
  d <- fwo_data(1500, 43, "c1")
  r <- fwo_route_native(d, "c1", weights = d$w, m_star = 0.4)
  g <- suppressMessages(fwo_route_glm(d, "c1", weights = d$w, m_star = 0.4))
  h <- fwo_hand(d, "c1", weights = d$w, m_star = 0.4, vcov_type = "ml")
  expect_lt(max(abs(r$est - g$est)), fwo_tol_optimizer)
  expect_lt(max(abs(r$est - h$est)), fwo_tol_optimizer)
})

test_that("a native model without the product is refused with native wording", {
  d <- fwo_data(500, 44, "c1")
  fit <- suppressWarnings(fit_sem("m ~ x + c1\ny ~ x + m + c1", d))
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m", decomposition = "four_way"),
               "add `x:m` to it")
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m", interaction = "x:m"), "add `x:m` to it")
  msg <- tryCatch(extract_mediation(fit, treatment = "x", mediator = "m", decomposition = "four_way"),
                  error = conditionMessage)
  expect_false(grepl("lavaan", msg, fixed = TRUE))
  expect_s3_class(extract_mediation(fit, treatment = "x", mediator = "m"), "medfit::MediationData")
  expect_error(extract_mediation(sep_fit(d), treatment = "x", mediator = "m", interaction = "c1:m"),
               "not the product of the treatment")
  expect_error(extract_mediation(sep_fit(d), treatment = "x", mediator = "m", interaction = "xm"),
               "written with `:`")
})

test_that("a treatment product placed outside the outcome equation is rejected on the native route", {
  d <- fwo_data(600, 45, "c1")
  for (s in c("m ~ x + c1 + x:c1\ny ~ x + m + x:m + c1", "m ~ x + c1\ny ~ x + m + x:m + c1 + x:c1")) {
    fit <- suppressWarnings(fit_sem(s, d))
    expect_error(extract_mediation(fit, treatment = "x", mediator = "m"), "does not support the product")
  }
})

test_that("a product of the mediator or treatment with a covariate is refused, with or without x:m", {
  d <- fwo_data(600, 47, "c1")
  for (s in c("m ~ x + c1\ny ~ x + m + x:m + m:c1 + c1", "m ~ x + c1\ny ~ x + m + c1 + x:c1")) {
    fit <- suppressWarnings(fit_sem(s, d))
    expect_error(extract_mediation(fit, treatment = "x", mediator = "m"), "does not support the product")
  }
})

test_that("a partial decomposition value gets the native wording", {
  d <- fwo_data(500, 48, "c1")
  fit <- suppressWarnings(fit_sem("m ~ x + c1\ny ~ x + m + c1", d))
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m", decomposition = "four"), "add `x:m` to it")
})

test_that("fit_mediation(engine = \"native\") accepts a product term for the treatment and mediator", {
  d <- fwo_data(800, 46, "c1")
  o <- suppressWarnings(fit_mediation(engine = "native", model = sep_syntax("m:x"), data = d,
                                      treatment = "x", mediator = "m"))
  expect_s3_class(o, "medfit::InteractionMediationData")
  # a treatment that appears only inside the product is still a variable of the model
  # (this model has no a path, so the extraction itself stops, but not at the variable check)
  err <- tryCatch(suppressWarnings(fit_mediation(engine = "native", model = "m ~ c1\ny ~ m + x:m", data = d,
                                                 treatment = "x", mediator = "m")),
                  error = conditionMessage)
  expect_false(grepl("is not a variable", err, fixed = TRUE))
  expect_error(fit_mediation(engine = "native", model = sep_syntax("m:x"), data = d, treatment = "nope",
                             mediator = "m"), "is not a variable")
})
