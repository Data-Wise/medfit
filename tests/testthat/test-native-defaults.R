# 0.14.0 default-change warning and opt-in (plan T5; spec R-2, R-3, R-11a, E-9, E-14). The suite's helper marks
# both warnings as shown; every test here resets the state locally and the helper's deferred restore puts it back.

nd_syntax <- "mediator1 ~ treatment\noutcome ~ mediator1 + treatment"
nd_data <- function() medfit::mediation_demo

# Warnings of the default-change class raised by `expr`, with the value.
nd_catch <- function(expr) {
  got <- list()
  value <- withCallingHandlers(expr, medfit_warning_default_change = function(w) {
    got[[length(got) + 1L]] <<- w
    invokeRestart("muffleWarning")
  })
  list(value = value, warnings = got)
}

test_that("unset settings keep the old values and warn once per argument per session", {
  local_native_defaults_unshown()
  first <- nd_catch(fit_sem(nd_syntax, nd_data()))
  expect_length(first$warnings, 2L)
  expect_true(all(vapply(first$warnings, inherits, TRUE, "medfit_warning_default_change")))
  msgs <- vapply(first$warnings, conditionMessage, "")
  expect_true(any(grepl("fixed_x", msgs, fixed = TRUE)))
  expect_true(any(grepl("meanstructure", msgs, fixed = TRUE)))
  expect_true(all(grepl("0.15.0", msgs, fixed = TRUE)))
  expect_true(all(grepl("medfit.native_defaults", msgs, fixed = TRUE)))
  expect_true(all(grepl("logLik", msgs, fixed = TRUE)))
  # old values kept
  expect_identical(first$value@internals$fixed_x, character())
  expect_false(first$value@internals$ram$has_mean)
  second <- nd_catch(fit_sem(nd_syntax, nd_data()))
  expect_length(second$warnings, 0L)
})

test_that("a muffled warning still consumes the once-per-session state (T5a setup chunks)", {
  local_native_defaults_unshown()
  # The exact handler the articles' native-defaults-setup chunk uses.
  invisible(withCallingHandlers(
    fit_sem(nd_syntax, nd_data()),
    medfit_warning_default_change = function(w) invokeRestart("muffleWarning")
  ))
  expect_no_warning(fit_sem(nd_syntax, nd_data()), class = "medfit_warning_default_change")
})

test_that("an error from a handler still leaves the state consumed", {
  local_native_defaults_unshown()
  expect_error(withCallingHandlers(
    fit_sem(nd_syntax, nd_data()),
    medfit_warning_default_change = function(w) stop("handler stopped")
  ), "handler stopped")
  # the handler stopped at the first warning (fixed_x): that one is consumed, meanstructure is still to come
  w <- nd_catch(fit_sem(nd_syntax, nd_data()))
  expect_length(w$warnings, 1L)
  expect_match(conditionMessage(w$warnings[[1L]]), "meanstructure", fixed = TRUE)
})

test_that("each argument is tracked on its own", {
  local_native_defaults_unshown()
  w <- nd_catch(fit_sem(nd_syntax, nd_data(), meanstructure = NULL))
  expect_length(w$warnings, 1L)
  expect_match(conditionMessage(w$warnings[[1L]]), "fixed_x", fixed = TRUE)
  w <- nd_catch(fit_sem(nd_syntax, nd_data(), fixed_x = FALSE))
  expect_length(w$warnings, 1L)
  expect_match(conditionMessage(w$warnings[[1L]]), "meanstructure", fixed = TRUE)
  w <- nd_catch(fit_sem(nd_syntax, nd_data()))
  expect_length(w$warnings, 0L)
})

test_that("explicit values never warn and are kept", {
  local_native_defaults_unshown()
  for (args in list(
    list(fixed_x = FALSE, meanstructure = NULL),
    list(fixed_x = TRUE, meanstructure = TRUE),
    list(fixed_x = "treatment", meanstructure = FALSE)
  )) {
    w <- nd_catch(do.call(fit_sem, c(list(nd_syntax, nd_data()), args)))
    expect_length(w$warnings, 0L)
  }
  w <- nd_catch(fit_sem(nd_syntax, nd_data(), fixed_x = TRUE, meanstructure = TRUE))
  expect_identical(w$value@internals$fixed_x, "treatment")
  expect_true(w$value@internals$ram$has_mean)
  # state untouched by explicit calls: the next unset call still warns
  expect_length(nd_catch(fit_sem(nd_syntax, nd_data()))$warnings, 2L)
})

test_that("no warning when the default does not matter for the model", {
  local_native_defaults_unshown()
  # mean structure already written, no observed exogenous variable
  w <- nd_catch(fit_sem("outcome ~~ mediator1\noutcome ~ 1\nmediator1 ~ 1", nd_data()))
  expect_length(w$warnings, 0L)
  # a product turns the mean structure on: only fixed_x can change
  # (the product's own model-test and SE warnings are not the subject here)
  w <- suppressWarnings(nd_catch(
    fit_sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment + mediator1:treatment", nd_data())
  ))
  expect_length(w$warnings, 1L)
  expect_match(conditionMessage(w$warnings[[1L]]), "fixed_x", fixed = TRUE)
})

test_that("option medfit.native_defaults = \"0.15\" resolves unset settings to the new values, silently", {
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  w <- nd_catch(fit_sem(nd_syntax, nd_data()))
  expect_length(w$warnings, 0L)
  expect_identical(w$value@internals$fixed_x, "treatment")
  expect_true(w$value@internals$ram$has_mean)
  ref <- fit_sem(nd_syntax, nd_data(), fixed_x = TRUE, meanstructure = TRUE)
  expect_equal(w$value@theta, ref@theta, tolerance = 1e-10)
  # explicit values still win under the opt-in
  w <- nd_catch(fit_sem(nd_syntax, nd_data(), fixed_x = FALSE, meanstructure = NULL))
  expect_identical(w$value@internals$fixed_x, character())
  expect_false(w$value@internals$ram$has_mean)
  # one explicit, one unset: the explicit one is kept, only the unset one resolves (QA planted defect)
  w <- nd_catch(fit_sem(nd_syntax, nd_data(), meanstructure = FALSE))
  expect_false(w$value@internals$ram$has_mean)
  expect_identical(w$value@internals$fixed_x, "treatment")
  w <- nd_catch(fit_sem(nd_syntax, nd_data(), fixed_x = FALSE))
  expect_identical(w$value@internals$fixed_x, character())
  expect_true(w$value@internals$ram$has_mean)
  # no observed exogenous variable: fixed_x resolves to none
  w <- nd_catch(fit_sem("outcome ~~ mediator1", nd_data()))
  expect_identical(w$value@internals$fixed_x, character())
})

test_that("the opt-in errors when a statement on an exogenous variable conflicts (T6 not yet landed)", {
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  expect_error(
    fit_sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment\ntreatment ~~ treatment", nd_data()),
    "medfit.native_defaults"
  )
  # an explicit fixed_x sidesteps it
  expect_no_error(fit_sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment\ntreatment ~~ treatment",
                          nd_data(), fixed_x = FALSE))
})

test_that("any other option value errors", {
  local_native_defaults_unshown()
  for (bad in list("0.14", "0.15.0", 0.15, TRUE, c("0.15", "0.15"))) {
    withr::with_options(list(medfit.native_defaults = bad), {
      expect_error(fit_sem(nd_syntax, nd_data()), "medfit.native_defaults", fixed = TRUE)
    })
  }
  # also with both settings explicit: a bad option is an error, never ignored
  withr::with_options(list(medfit.native_defaults = "yes"), {
    expect_error(fit_sem(nd_syntax, nd_data(), fixed_x = FALSE, meanstructure = NULL), "medfit.native_defaults")
  })
})

test_that("fit_mediation(engine = \"native\") warns like fit_sem() and honors engine_args", {
  local_native_defaults_unshown()
  w <- nd_catch(fit_mediation(data = nd_data(), treatment = "treatment", mediator = "mediator1",
                              engine = "native", model = nd_syntax))
  expect_length(w$warnings, 2L)
  local_native_defaults_unshown()
  w <- nd_catch(fit_mediation(data = nd_data(), treatment = "treatment", mediator = "mediator1",
                              engine = "native", model = nd_syntax,
                              engine_args = list(fixed_x = FALSE, meanstructure = NULL)))
  expect_length(w$warnings, 0L)
})

test_that("internal refits pass explicit settings and never warn", {
  local_native_defaults_unshown()
  fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment", nd_data(),
                 fixed_x = FALSE, meanstructure = NULL)
  w <- nd_catch(mbco_sem(fit, a = "a", b = "b"))
  expect_length(w$warnings, 0L)
  # state still unshown: the next unset fit warns
  expect_length(nd_catch(fit_sem(nd_syntax, nd_data()))$warnings, 2L)
})

test_that("the suite helper leaves both warnings marked as shown", {
  expect_true(all(.native_defaults_state()))
})
