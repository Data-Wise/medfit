# One spelling for a native fit's parameters: coef(), tidy(), the extraction accessors and lavaan's coefficient
# names agree (the label, else `lhs op rhs` without spaces), and the renamed arguments keep their old names.

naming_syntax <- c(
  observed = "mediator1 ~ treatment\noutcome ~ mediator1 + treatment",
  labeled = "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b"
)

test_that("coef() uses lavaan's names on the observed, labeled and latent structures", {
  skip_if_not_installed("lavaan")
  for (nm in names(naming_syntax)) {
    fit <- fit_sem(naming_syntax[[nm]], mediation_demo)
    lav <- suppressWarnings(lavaan::sem(naming_syntax[[nm]], mediation_demo, fixed.x = FALSE))
    expect_setequal(names(coef(fit)), names(lavaan::coef(lav)))
  }
  ldat <- sem_sim(sem_models()$latent, n = 400, seed = 3)
  fit <- fit_sem(sem_lavaan_text("latent"), ldat)
  lav <- suppressWarnings(lavaan::sem(sem_lavaan_text("latent"), ldat, fixed.x = FALSE))
  expect_setequal(names(coef(fit)), names(lavaan::coef(lav)))
  expect_true(all(c("eta=~m2", "eta=~m3") %in% names(coef(fit))))
  expect_false(any(grepl(" ", names(coef(fit)))))
})

test_that("tidy(), the accessors and vcov() carry the same names as coef()", {
  fit <- fit_sem(sem_lavaan_text("latent"), sem_sim(sem_models()$latent, n = 400, seed = 3))
  td <- tidy(fit)
  expect_identical(td$term, names(coef(fit)))
  expect_identical(td$op[td$term == "eta=~m2"], "=~")
  expect_identical(td$op[td$term == "Y~eta"], "~")
  expect_identical(td$op[td$term == "m1~~m1"], "~~")
  acc <- .sem_accessors_native(fit)
  expect_identical(names(acc$coef()), names(coef(fit)))
  expect_identical(colnames(acc$vcov()), names(coef(fit)))
  expect_identical(rownames(vcov(fit)), names(coef(fit)))
})

test_that("a label replaces the default name everywhere", {
  fit <- fit_sem(naming_syntax[["labeled"]], mediation_demo)
  expect_true(all(c("a", "b") %in% names(coef(fit))))
  expect_false(any(c("mediator1~treatment", "outcome~mediator1") %in% names(coef(fit))))
  expect_identical(names(.sem_accessors_native(fit)$coef()), names(coef(fit)))
})

test_that("a planted spaced default name is caught by the name checks", {
  fit <- fit_sem(naming_syntax[["observed"]], mediation_demo)
  bad <- names(coef(fit))
  bad[1L] <- sub("~", " ~ ", bad[1L], fixed = TRUE)
  expect_true(any(grepl(" ", bad)))
  expect_false(any(grepl(" ", names(coef(fit)))))
})

test_that("fit_sem(sampling_weights =) still works and warns; weights = is the name", {
  rlang::local_options(lifecycle_verbosity = "warning")
  w <- seq_len(nrow(mediation_demo)) %% 3 + 1
  new <- fit_sem(naming_syntax[["observed"]], mediation_demo, weights = w, se_type = "sandwich")
  expect_warning(
    old <- fit_sem(naming_syntax[["observed"]], mediation_demo, sampling_weights = w, se_type = "sandwich"),
    "sampling_weights"
  )
  expect_equal(coef(old), coef(new))
  expect_equal(vcov(old), vcov(new))
  expect_error(
    suppressWarnings(fit_sem(naming_syntax[["observed"]], mediation_demo, weights = w, sampling_weights = w)),
    "not both"
  )
})

test_that("fit_mediation(engine = 'native', weights =) passes the weights to fit_sem()", {
  w <- seq_len(nrow(mediation_demo)) %% 3 + 1
  syntax <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment"
  via_med <- fit_mediation(model = syntax, data = mediation_demo, treatment = "treatment", mediator = "mediator1",
                           engine = "native", weights = w, se_type = "sandwich")
  direct <- fit_sem(syntax, mediation_demo, weights = w, se_type = "sandwich")
  expect_equal(unname(via_med@estimates[c("a", "b")]), unname(coef(direct)[c("a", "b")]))
})

test_that("mbco_sem(object =) is the name; fit = still works with a warning in every call form", {
  rlang::local_options(lifecycle_verbosity = "warning")
  fit <- fit_sem(naming_syntax[["labeled"]], mediation_demo)
  ref <- mbco_sem(fit, "a", "b")
  expect_equal(mbco_sem(object = fit, a = "a", b = "b")$statistic, ref$statistic)
  expect_warning(named <- mbco_sem(fit = fit, a = "a", b = "b"), "`fit` argument of `mbco_sem\\(\\)`")
  expect_equal(named$statistic, ref$statistic)
  # the two names after a named `fit =` land in the first slots and are shifted back
  expect_warning(shifted <- mbco_sem(fit = fit, "a", "b"), "`fit` argument of `mbco_sem\\(\\)`")
  expect_equal(shifted$statistic, ref$statistic)
  expect_error(mbco_sem("not a fit", "a", "b"), "`object` must be a SEMFit")
})
