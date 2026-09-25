# Delta-method effect standard errors (SPEC-tidy-effect-se-2026-09-23.md)
#
# Regression pins were captured from dev (2f882a5) before the helper refactor.
# Every confint() number must survive the refactor unchanged, except the Simple
# TE interval, which the old formula computed without Cov(ab, c') (GRILL D2).

# Explicit binding so lintr's object_usage_linter sees the lazy-loaded data
mediation_demo <- medfit::mediation_demo

demo_formula <- function(lhs_rhs) {
  stats::as.formula(paste(lhs_rhs, "+ covariate1 + covariate2"))
}

demo_simple <- function() {
  extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1"), data = mediation_demo),
    treatment = "treatment", mediator = "mediator1"
  )
}

demo_parallel <- function() {
  extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1 + mediator3"),
                 data = mediation_demo),
    treatment = "treatment", mediator = c("mediator1", "mediator3"),
    mediator_models = list(lm(demo_formula("mediator3 ~ treatment"), data = mediation_demo))
  )
}

demo_interaction <- function() {
  extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome_int ~ treatment * mediator1"), data = mediation_demo),
    treatment = "treatment", mediator = "mediator1"
  )
}

demo_regmedint <- function() {
  fit_mediation(
    formula_y = demo_formula("outcome_int ~ treatment * mediator1"),
    formula_m = demo_formula("mediator1 ~ treatment"),
    data = mediation_demo, treatment = "treatment", mediator = "mediator1",
    engine = "regmedint"
  )
}

quiet_confint <- function(...) suppressWarnings(suppressMessages(confint(...)))

# Pinned values are column-major: all lower bounds, then all upper bounds.
expect_pinned_ci <- function(ci, rows, values) {
  expect_identical(rownames(ci), rows) # nolint: object_usage_linter.
  expect_equal(as.vector(ci), values, tolerance = 1e-10) # nolint: object_usage_linter.
}

# ==============================================================================
# Regression pins (T1)
# ==============================================================================

test_that("Simple confint() NIE and NDE intervals are unchanged", {
  ci <- quiet_confint(demo_simple(), parm = "effects")
  expect_identical(rownames(ci), c("nie", "nde", "te"))
  expect_equal(unname(ci["nie", ]), c(0.20635638474977949, 0.45918261323975096),
               tolerance = 1e-10)
  expect_equal(unname(ci["nde", ]), c(-0.0093614097508007699, 0.42095792516676489),
               tolerance = 1e-10)
})

test_that("Simple confint() TE SE includes Cov(ab, c') (GRILL D2)", {
  ci <- quiet_confint(demo_simple(), parm = "effects")
  te_se <- unname(ci["te", 2] - ci["te", 1]) / (2 * stats::qnorm(0.975))
  # Full delta-method gradient: 0.1194. The old formula gave 0.1273.
  expect_equal(te_se, 0.1194, tolerance = 5e-4 / 0.1194)
})

test_that("Parallel confint() effects are unchanged", {
  expect_pinned_ci(
    quiet_confint(demo_parallel(), parm = "effects"),
    c("indirect", "direct", "total"),
    c(0.29207642124965916, -0.10943170422557466, 0.30448060555360812,
      0.57270087554619786, 0.32178992083521207, 0.7726549078518864)
  )
})

test_that("Interaction (glm) confint() effects and components are unchanged", {
  med <- demo_interaction()
  expect_pinned_ci(
    quiet_confint(med, parm = "effects"),
    c("nde", "nie", "total"),
    c(0.026845486714029226, 0.39612312661770732, 0.61128241699995989,
      0.49065825829040755, 0.83810302010039461, 1.1404474747225786)
  )
  expect_pinned_ci(
    quiet_confint(med, parm = "components"),
    c("cde", "int_ref", "int_med", "pie"),
    c(-0.012427515752339385, -0.023784091779779783, 0.13266954660767988,
      0.19952256747799985, 0.44285307516846495, 0.1108622773680909,
      0.42152143721103291, 0.4805125954213893)
  )
})

test_that("Interaction (regmedint) confint() effects and components are unchanged", {
  skip_if_not_installed("regmedint")
  med <- demo_regmedint()
  expect_pinned_ci(
    quiet_confint(med, parm = "effects"),
    c("nde", "nie", "total"),
    c(0.026845486714029254, 0.39612312661770732, 0.61128241699995989,
      0.49065825829040749, 0.83810302010039461, 1.1404474747225786)
  )
  expect_pinned_ci(
    quiet_confint(med, parm = "components"),
    c("cde", "int_ref", "int_med", "pie"),
    c(-0.012427515752339385, -0.023784091779779762, 0.13266954660767988,
      0.19952256747799985, 0.44285307516846495, 0.11086227736809091,
      0.42152143721103291, 0.4805125954213893)
  )
})

# ==============================================================================
# Oracle A: lavaan := defined-parameter SEs (T2)
# ==============================================================================
#
# lavaan's := SEs are delta-method SEs on the same joint vcov, so the helper
# must match them. Extraction and the oracle share one labeled fit, which also
# exercises the extractor's alias rows under custom path labels.

lavaan_defined_se <- function(labeled_fit, label) {
  pe <- lavaan::parameterEstimates(labeled_fit)
  pe$se[pe$label == label]
}

expect_lavaan_oracle <- function(labeled, treatment, mediator, outcome, data) {
  fit_l <- lavaan::sem(labeled, data = data)
  med <- extract_mediation(fit_l, treatment = treatment, mediator = mediator,
                           outcome = outcome)
  expect_equal( # nolint: object_usage_linter.
    unname(.effect_se(med, c("nie", "nde", "te"))),
    c(lavaan_defined_se(fit_l, "ind"), lavaan_defined_se(fit_l, "cp"),
      lavaan_defined_se(fit_l, "tot")),
    tolerance = 1e-6
  )
}

test_that("helper matches lavaan := SEs for simple mediation", {
  skip_if_not_installed("lavaan")
  expect_lavaan_oracle(
    "mediator1 ~ aa*treatment + covariate1 + covariate2
     outcome ~ cp*treatment + bb*mediator1 + covariate1 + covariate2
     ind := aa*bb
     tot := aa*bb + cp",
    "treatment", "mediator1", "outcome", mediation_demo
  )
})

# tot sums every X -> Y path (te() for serial is the full total effect)
test_that("helper matches lavaan := SEs for serial mediation (2 mediators)", {
  skip_if_not_installed("lavaan")
  expect_lavaan_oracle(
    "mediator1 ~ aa*treatment + covariate1 + covariate2
     mediator2 ~ dd*mediator1 + sa2*treatment + covariate1 + covariate2
     outcome ~ cp*treatment + sb1*mediator1 + bb*mediator2 + covariate1 + covariate2
     ind := aa*dd*bb
     tot := aa*dd*bb + aa*sb1 + sa2*bb + cp",
    "treatment", c("mediator1", "mediator2"), "outcome", mediation_demo
  )
})

serial3_data <- function() {
  set.seed(7)
  n <- 500
  X <- stats::rbinom(n, 1, 0.5)
  M1 <- 0.5 * X + stats::rnorm(n)
  M2 <- 0.4 * M1 + 0.2 * X + stats::rnorm(n)
  M3 <- 0.4 * M2 + 0.1 * X + stats::rnorm(n)
  Y <- 0.3 * M3 + 0.2 * M1 + 0.2 * X + stats::rnorm(n)
  data.frame(X, M1, M2, M3, Y)
}

test_that("helper matches lavaan := SEs for serial mediation (3 mediators)", {
  skip_if_not_installed("lavaan")
  expect_lavaan_oracle(
    "M1 ~ aa*X
     M2 ~ sa2*X + d1*M1
     M3 ~ sa3*X + s13*M1 + d2*M2
     Y ~ cp*X + sb1*M1 + sb2*M2 + bb*M3
     ind := aa*d1*d2*bb
     tot := cp + aa*sb1 + sa2*sb2 + sa3*bb + aa*d1*sb2 + aa*s13*bb +
            sa2*d2*bb + aa*d1*d2*bb",
    "X", c("M1", "M2", "M3"), "Y", serial3_data()
  )
})

test_that("helper matches lavaan := SEs for parallel mediation", {
  skip_if_not_installed("lavaan")
  expect_lavaan_oracle(
    "mediator1 ~ a1*treatment + covariate1 + covariate2
     mediator3 ~ a2*treatment + covariate1 + covariate2
     outcome ~ cp*treatment + b1*mediator1 + b2*mediator3 + covariate1 + covariate2
     ind := a1*b1 + a2*b2
     tot := a1*b1 + a2*b2 + cp",
    "treatment", c("mediator1", "mediator3"), "outcome", mediation_demo
  )
})

# ==============================================================================
# Oracle B: parametric bootstrap SDs (T2, T3)
# ==============================================================================

boot_sd <- function(med, statistic) {
  r <- bootstrap_mediation(statistic, method = "parametric",
                           mediation_data = med, n_boot = 20000, seed = 1)
  stats::sd(r@boot_estimates)
}

test_that("helper matches parametric-bootstrap SDs for lm-extracted objects", {
  simple <- demo_simple()
  expect_equal(.effect_se(simple, "te")[["te"]],
               boot_sd(simple, function(t) unname(t["a"] * t["b"] + t["c_prime"])),
               tolerance = 0.03)

  serial <- extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1 + mediator2"),
                 data = mediation_demo),
    treatment = "treatment", mediator = c("mediator1", "mediator2"),
    mediator_models = list(lm(demo_formula("mediator2 ~ treatment + mediator1"),
                              data = mediation_demo))
  )
  expect_equal(.effect_se(serial, "nie")[["nie"]],
               boot_sd(serial, function(t) unname(t["a"] * t["d1"] * t["b"])),
               tolerance = 0.03)

  parallel <- demo_parallel()
  expect_equal(.effect_se(parallel, "te")[["te"]],
               boot_sd(parallel, function(t) {
                 unname(t["a1"] * t["b1"] + t["a2"] * t["b2"] + t["c_prime"])
               }),
               tolerance = 0.03)
})

test_that("helper matches parametric-bootstrap SDs for interaction components", {
  med <- demo_interaction()
  # NIE = INTmed + PIE = a * (theta3 + b); CDE at m_star = 0 is c'
  expect_equal(.effect_se(med, "nie")[["nie"]],
               boot_sd(med, function(t) unname(t["a"] * (t["theta3"] + t["b"]))),
               tolerance = 0.03)
  expect_equal(.effect_se(med, "int_med")[["int_med"]],
               boot_sd(med, function(t) unname(t["a"] * t["theta3"])),
               tolerance = 0.03)
})

# ==============================================================================
# Interaction helper reproduces the pinned confint() SEs (T3)
# ==============================================================================

ci_half_width_se <- function(ci) {
  unname(ci[, 2] - ci[, 1]) / (2 * stats::qnorm(0.975))
}

test_that("interaction helper SEs equal the pinned confint() SEs (glm engine)", {
  med <- demo_interaction()
  expect_equal(unname(.effect_se(med, c("nde", "nie", "te"))),
               ci_half_width_se(quiet_confint(med, parm = "effects")),
               tolerance = 1e-10)
  expect_equal(unname(.effect_se(med, c("cde", "int_ref", "int_med", "pie"))),
               ci_half_width_se(quiet_confint(med, parm = "components")),
               tolerance = 1e-10)
})

test_that("interaction helper SEs equal the pinned confint() SEs (regmedint engine)", {
  skip_if_not_installed("regmedint")
  med <- demo_regmedint()
  expect_equal(unname(.effect_se(med, c("nde", "nie", "te"))),
               ci_half_width_se(quiet_confint(med, parm = "effects")),
               tolerance = 1e-10)
  expect_equal(unname(.effect_se(med, c("cde", "int_ref", "int_med", "pie"))),
               ci_half_width_se(quiet_confint(med, parm = "components")),
               tolerance = 1e-10)
})

test_that(".effect_se() rejects keys the class does not provide", {
  expect_error(.effect_se(demo_simple(), "cde"), "terms")
  expect_error(.effect_se(demo_simple(), character(0)), "terms")
})

test_that("confint(parm = 'effects') works for lavaan-extracted MediationData", {
  skip_if_not_installed("lavaan")
  fit <- lavaan::sem(
    "mediator1 ~ treatment + covariate1 + covariate2
     outcome ~ treatment + mediator1 + covariate1 + covariate2",
    data = mediation_demo
  )
  med <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1",
                           outcome = "outcome")
  # Previously stopped: the method located a/b/c' by lm-style m_/y_ names
  ci <- quiet_confint(med, parm = "effects")
  expect_identical(rownames(ci), c("nie", "nde", "te"))
  expect_equal(ci_half_width_se(ci), unname(.effect_se(med, c("nie", "nde", "te"))),
               tolerance = 1e-12)
})

# ==============================================================================
# confint() for SerialMediationData (T5)
# ==============================================================================

demo_serial <- function() {
  extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1 + mediator2"),
                 data = mediation_demo),
    treatment = "treatment", mediator = c("mediator1", "mediator2"),
    mediator_models = list(lm(demo_formula("mediator2 ~ treatment + mediator1"),
                              data = mediation_demo))
  )
}

serial3_lm <- function() {
  d <- serial3_data()
  extract_mediation(
    lm(M1 ~ X, data = d), model_y = lm(Y ~ X + M1 + M2 + M3, data = d),
    treatment = "X", mediator = c("M1", "M2", "M3"),
    mediator_models = list(lm(M2 ~ X + M1, data = d), lm(M3 ~ X + M1 + M2, data = d))
  )
}

test_that("Serial confint() paths use paths() names and the alias SEs", {
  for (med in list(demo_serial(), serial3_lm())) {
    ci <- confint(med)
    k <- length(med@d_path)
    expect_identical(rownames(ci), names(paths(med)))
    alias <- c("a", paste0("d", seq_len(k)), "b", "c_prime")
    expect_equal(ci_half_width_se(ci), unname(sqrt(diag(med@vcov)[alias])),
                 tolerance = 1e-12)
    expect_equal(unname(rowMeans(ci)), unname(paths(med)), tolerance = 1e-12)
  }
  expect_identical(rownames(confint(serial3_lm()))[2:3], c("d21", "d32"))
})

test_that("Serial confint() effects equal estimate +/- z * helper SE", {
  for (med in list(demo_serial(), serial3_lm())) {
    expect_warning(ci <- confint(med, parm = "effects", level = 0.90),
                   "Normal approximation")
    expect_identical(rownames(ci), c("nie", "nde", "te"))
    est <- c(unname(nie(med)), unname(nde(med)), unname(te(med)))
    half <- stats::qnorm(0.95) * unname(.effect_se(med, c("nie", "nde", "te")))
    expect_equal(unname(ci[, 1]), est - half, tolerance = 1e-12)
    expect_equal(unname(ci[, 2]), est + half, tolerance = 1e-12)
    expect_identical(colnames(ci), c("5 %", "95 %"))
  }
})

test_that("Serial confint() validates its arguments", {
  med <- demo_serial()
  expect_error(confint(med, parm = "components"), "parm")
  expect_error(confint(med, level = 2), "level")
  expect_error(confint(med, method = "boot"), "bootstrap_mediation")
})

# ==============================================================================
# tidy() through the helper (T6)
# ==============================================================================

all_demo_objects <- function() {
  list(simple = demo_simple(), serial = demo_serial(),
       parallel = demo_parallel(), interaction = demo_interaction())
}

tidy_rows <- function(tt, terms) tt[match(terms, tt$term), , drop = FALSE]

test_that("tidy() effect CIs equal confint(parm = 'effects') for all classes", {
  objs <- all_demo_objects()
  # confint() row names per class, in tidy()'s nie/nde/te order
  ci_rows <- list(simple = c("nie", "nde", "te"), serial = c("nie", "nde", "te"),
                  parallel = c("indirect", "direct", "total"),
                  interaction = c("nie", "nde", "total"))
  for (nm in names(objs)) {
    tt <- tidy_rows(generics::tidy(objs[[nm]], conf.int = TRUE), c("nie", "nde", "te"))
    ci <- quiet_confint(objs[[nm]], parm = "effects")[ci_rows[[nm]], , drop = FALSE]
    expect_equal(tt$conf.low, unname(ci[, 1]), tolerance = 1e-12, info = nm)
    expect_equal(tt$conf.high, unname(ci[, 2]), tolerance = 1e-12, info = nm)
  }
  comp <- c("cde", "int_ref", "int_med", "pie")
  tt <- tidy_rows(generics::tidy(objs$interaction, conf.int = TRUE), comp)
  ci <- quiet_confint(objs$interaction, parm = "components")
  expect_equal(tt$conf.low, unname(ci[comp, 1]), tolerance = 1e-12)
})

test_that("tidy() is silent and reports numeric SEs for every row", {
  for (obj in all_demo_objects()) {
    expect_silent(tt <- generics::tidy(obj))
    expect_silent(generics::tidy(obj, conf.int = TRUE))
    expect_true(is.numeric(tt$std.error))
    expect_false(anyNA(tt$std.error))
    expect_false("pm" %in% tt$term)
  }
})

test_that("tidy() serial path SEs use the vcov aliases", {
  med <- serial3_lm()
  tt <- generics::tidy(med, type = "paths")
  expect_identical(tt$term, names(paths(med)))
  expect_equal(tt$std.error,
               unname(sqrt(diag(med@vcov)[c("a", "d1", "d2", "b", "c_prime")])),
               tolerance = 1e-12)
})

test_that("tidy() gives SEs for lavaan-extracted MediationData", {
  skip_if_not_installed("lavaan")
  fit <- lavaan::sem(
    "mediator1 ~ treatment + covariate1 + covariate2
     outcome ~ treatment + mediator1 + covariate1 + covariate2",
    data = mediation_demo
  )
  med <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1",
                           outcome = "outcome")
  tt <- generics::tidy(med)
  expect_false(anyNA(tt$std.error))
})

test_that("glance() output is unchanged in shape", {
  g <- generics::glance(demo_simple())
  expect_named(g, c("nie", "nde", "te", "pm", "nobs", "converged"))
})
