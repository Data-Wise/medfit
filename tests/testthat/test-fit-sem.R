# Native SEM engine: entry points and extraction (S16, S17).
# Oracles: the lavaan extraction route on the same data (a_path, b_path, c_prime,
# alias rows of @estimates and @vcov), the glm route for an observed Gaussian
# model, and `.effect_se()` on the extracted object for the `:=` standard error.
# Planted defect: coefficient names without lavaan's `lhs op rhs` convention leave
# the alias covariance rows unresolved.

ex_syntax <- c(
  observed = "M ~ X + C\nY ~ M + X + C",
  latent = "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X",
  parallel = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2",
  serial = "M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + M1 + X"
)

ex_lavaan <- function(syntax, data) {
  suppressWarnings(lavaan::sem(syntax, data, fixed.x = FALSE, information = "observed"))
}

# Two extractions agree on every estimate and covariance row they share, and
# share the same rows.
expect_same_extraction <- function(nat, lav, info) {
  testthat::expect_setequal(names(nat@estimates), names(lav@estimates))
  common <- names(lav@estimates)
  testthat::expect_equal(nat@estimates[common], lav@estimates[common], tolerance = 1e-6, info = info)
  testthat::expect_equal(nat@vcov[common, common], lav@vcov[common, common], tolerance = 1e-5, info = info)
}

test_that("fit_sem returns a SEMFit with the table, covariance and diagnostics", {
  dat <- sem_sim(sem_model_observed(), n = 400, seed = 5)
  fit <- fit_sem("M ~ a*X + C\nY ~ b*M + X + C\nab := a*b", dat)
  expect_s7_class(fit, SEMFit)
  expect_identical(fit@n_obs, 400L)
  expect_identical(fit@n_dropped, 0L)
  expect_identical(fit@information, "observed")
  expect_true(fit@converged)
  expect_identical(rownames(fit@vcov), names(fit@theta))
  expect_true(all(c("lhs", "op", "rhs", "label", "free", "est", "se") %in% names(fit@table)))
  expect_identical(fit@defined$name, "ab")
  expect_equal(fit@defined$est, fit@theta[["a"]] * fit@theta[["b"]], tolerance = 1e-10)
  # table rows carry the estimate and standard error of the parameter they map to
  a_row <- fit@table[fit@table$label == "a", ]
  expect_equal(a_row$est, fit@theta[["a"]])
  expect_equal(a_row$se, sqrt(fit@vcov["a", "a"]))
  # the same numbers as the internal pipeline
  ref <- .sem_fit_syntax("M ~ a*X + C\nY ~ b*M + X + C\nab := a*b", dat)
  expect_identical(fit@theta, ref$theta)
  expect_identical(fit@vcov, ref$vcov)
  expect_identical(fit_sem("M ~ X\nY ~ M + X", dat, information = "expected")@information, "expected")
})

test_that("fit_sem validates its arguments", {
  dat <- sem_sim(sem_model_observed(), n = 100, seed = 5)
  expect_error(fit_sem(1, dat), "model")
  expect_error(fit_sem("Y ~ X", "not data"), "data")
  expect_error(fit_sem("Y ~ X", dat, n_starts = 0), "n_starts")
  expect_error(fit_sem("Y ~ X", dat, information = "sandwich"), "should be one of")
  expect_error(fit_sem("Y ~ X", dat, control = 1), "control")
  expect_error(fit_sem("Y ~ X + Zzz", dat), "not columns of `data`: Zzz")
})

test_that("the SEMFit validator rejects an inconsistent object", {
  dat <- sem_sim(sem_model_observed(), n = 100, seed = 5)
  fit <- fit_sem("M ~ X\nY ~ M + X", dat)
  expect_error(S7::set_props(fit, information = "sandwich"), "information")
  expect_error(S7::set_props(fit, vcov = diag(2)), "vcov")
  expect_error(S7::set_props(fit, n_obs = 5L), "n_obs rows")
})

test_that("extraction from a native fit equals the lavaan route for the four structures", {
  skip_if_not_installed("lavaan")
  mods <- sem_models()
  for (nm in names(ex_syntax)) {
    dat <- sem_sim(mods[[nm]], n = 500, seed = 3)
    nat_fit <- fit_sem(ex_syntax[[nm]], dat)
    lav_fit <- ex_lavaan(ex_syntax[[nm]], dat)
    args <- switch(nm,
      observed = list(treatment = "X", mediator = "M"),
      latent = list(treatment = "X", mediator = "eta"),
      parallel = list(treatment = "X", mediator = c("M1", "M2"), structure = "parallel"),
      serial = list(treatment = "X", mediator = c("M1", "M2"))
    )
    nat <- do.call(extract_mediation, c(list(nat_fit), args))
    lav <- do.call(extract_mediation, c(list(lav_fit), args))
    expect_identical(class(nat), class(lav), info = nm)
    expect_identical(nat@source_package, "medfit")
    expect_same_extraction(nat, lav, nm)
    if (nm %in% c("observed", "latent")) {
      expect_equal(c(nat@a_path, nat@b_path, nat@c_prime), c(lav@a_path, lav@b_path, lav@c_prime),
                   tolerance = 1e-6, info = nm)
    }
  }
})

test_that("the four-way route needs the mediator intercept, so a native fit says so", {
  set.seed(8)
  n <- 300
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.3 * m + 0.2 * x + 0.15 * x * m + stats::rnorm(n)
  dat <- data.frame(X = x, M = m, Y = y, XM = x * m)
  fit <- fit_sem("M ~ X\nY ~ M + X + XM", dat)
  expect_error(
    extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y", interaction = "XM"),
    "needs the mediator intercept.*does not estimate in this version"
  )
  expect_no_error(
    extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y", decomposition = "two_way")
  )
})

test_that("the := indirect-effect SE equals .effect_se() on the extracted object", {
  dat <- sem_sim(sem_model_observed(), n = 500, seed = 3)
  fit <- fit_sem("M ~ a*X + C\nY ~ b*M + cp*X + C\nab := a*b", dat)
  med <- extract_mediation(fit, treatment = "X", mediator = "M")
  # two independent routes: central differences on the labels, analytic gradient on the aliases
  expect_equal(fit@defined$se, unname(.effect_se(med, "nie")), tolerance = 1e-6)
  expect_equal(fit@defined$est, as.numeric(nie(med)), tolerance = 1e-10)
})

test_that("a native fit extracts without lavaan (alias rows and names come from the fit alone)", {
  dat <- sem_sim(sem_model_observed(), n = 300, seed = 5)
  fit <- fit_sem("M ~ a*X + C\nY ~ b*M + cp*X + C", dat)
  med <- extract_mediation(fit, treatment = "X", mediator = "M")
  expect_equal(med@a_path, fit@theta[["a"]])
  expect_equal(med@b_path, fit@theta[["b"]])
  expect_equal(med@vcov["a", "a"], fit@vcov["a", "a"])
  expect_equal(med@vcov["a", "b"], fit@vcov["a", "b"])
  expect_true(all(c("m_X", "y_M", "y_X") %in% names(med@estimates)))
  expect_equal(unname(med@estimates[c("m_X", "y_M", "y_X")]), unname(med@estimates[c("a", "b", "c_prime")]))
  expect_error(extract_mediation(fit, treatment = "X", mediator = "M", standardized = TRUE),
               "standardized estimates are not supported")
})

test_that("planted defect: coefficient names off lavaan's convention leave the alias covariance unresolved", {
  dat <- sem_sim(sem_model_observed(), n = 300, seed = 5)
  fit <- fit_sem("M ~ X + C\nY ~ M + X + C", dat)
  good <- .sem_accessors_native(fit)
  bad <- good
  spaced <- function(v) sub("(~+)", " \\1 ", v)
  bad$coef <- function() stats::setNames(good$coef(), spaced(names(good$coef())))
  bad$vcov <- function() {
    vc <- good$vcov()
    dimnames(vc) <- list(spaced(rownames(vc)), spaced(colnames(vc)))
    vc
  }
  ok <- extract_mediation_lavaan(good, treatment = "X", mediator = "M")
  broken <- suppressWarnings(extract_mediation_lavaan(bad, treatment = "X", mediator = "M"))
  expect_false(anyNA(ok@vcov["a", ]))
  expect_true(anyNA(broken@vcov["a", ]) || !isTRUE(all.equal(ok@vcov["a", "a"], broken@vcov["a", "a"])))
})

test_that("fit_mediation(engine = 'native') equals the glm route on the paths of an observed model", {
  nat <- fit_mediation(
    model = "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + treatment + covariate1",
    data = mediation_demo, treatment = "treatment", mediator = "mediator1", engine = "native"
  )
  glm <- fit_mediation(outcome ~ treatment + mediator1 + covariate1, mediator1 ~ treatment + covariate1,
                       mediation_demo, "treatment", "mediator1")
  expect_s7_class(nat, MediationData)
  expect_equal(c(nat@a_path, nat@b_path, nat@c_prime), c(glm@a_path, glm@b_path, glm@c_prime), tolerance = 1e-6)
  expect_identical(nat@source_package, "medfit")
  # engine_args reach the fit
  exp <- fit_mediation(
    model = "mediator1 ~ treatment\noutcome ~ mediator1 + treatment", data = mediation_demo,
    treatment = "treatment", mediator = "mediator1", engine = "native",
    engine_args = list(information = "expected")
  )
  expect_s7_class(exp, MediationData)
})

test_that("fit_mediation(engine = 'native') takes a latent mediator that is not a column", {
  dat <- sem_sim(sem_model_latent(), n = 400, seed = 3)
  med <- fit_mediation(model = ex_syntax[["latent"]], data = dat, treatment = "X", mediator = "eta",
                       engine = "native")
  expect_s7_class(med, MediationData)
  expect_identical(med@mediator, "eta")
})

test_that("every native-route guard names its cause", {
  dat <- sem_sim(sem_model_observed(), n = 100, seed = 5)
  mod <- "M ~ X\nY ~ M + X"
  call_native <- function(...) {
    fit_mediation(data = dat, treatment = "X", mediator = "M", engine = "native", ...)
  }
  expect_error(call_native(), "needs `model`")
  expect_error(fit_mediation(Y ~ X + M, M ~ X, dat, "X", "M", engine = "native", model = mod),
               "takes `model =`, not formulas")
  expect_error(call_native(model = mod, weights = rep(1, 100)), "`weights` is not supported by engine = \"native\"")
  expect_error(call_native(model = mod, se_type = "sandwich"), "se_type = \"sandwich\" is not supported")
  expect_error(call_native(model = mod, se_type = "kr"), "only used with engine = \"lmer\"")
  expect_error(call_native(model = mod, cluster = "C"), "`cluster` is only used with engine = \"lmer\"")
  expect_error(call_native(model = mod, family_y = stats::binomial()), "Gaussian")
  expect_error(call_native(model = mod, engine_args = list(bogus = 1)), "unknown `engine_args`.*bogus")
  expect_error(call_native(model = mod, zzz = 1), "unused arguments for engine = \"native\": zzz")
  expect_error(fit_mediation(data = dat, treatment = "X", mediator = "Q", engine = "native", model = mod),
               "'Q' is not a variable in `model`")
  expect_error(fit_mediation(Y ~ X + M, M ~ X, dat, "X", "M", model = mod),
               "`model` is only used with engine = \"native\"")
  # no planning ids in user-facing text
  msgs <- c(
    tryCatch(call_native(model = mod, weights = rep(1, 100)), error = conditionMessage),
    tryCatch(call_native(model = mod, se_type = "sandwich"), error = conditionMessage)
  )
  expect_false(any(grepl("\\b(S[0-9]+|N[0-9]+|PR [0-9]+)\\b", msgs)))
})
