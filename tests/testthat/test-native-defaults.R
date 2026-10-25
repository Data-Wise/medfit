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

nd_touched <- "mediator1 ~ treatment + covariate1\noutcome ~ mediator1 + treatment\ntreatment ~~ treatment"

# The lenience notes (class medfit_message_fixed_x_lenient) raised by `expr`, with the value.
nd_notes <- function(expr) {
  got <- list()
  value <- withCallingHandlers(expr, medfit_message_fixed_x_lenient = function(m) {
    got[[length(got) + 1L]] <<- m
    invokeRestart("muffleMessage")
  })
  list(value = value, notes = got)
}

# Data with a product and a three-level factor (T6, E-11).
nd_pf_data <- function() {
  set.seed(61)
  n <- 300
  x <- stats::rnorm(n)
  cv <- stats::rnorm(n)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  m <- 0.5 * x + cv + stats::rnorm(n)
  y <- 0.3 * m + 0.2 * x + 0.1 * x * m + stats::rnorm(n)
  data.frame(x = x, cv = cv, g = g, m = m, y = y)
}

test_that("the opt-in fixes the exogenous variables without a statement and leaves the rest free with a note (T6)", {
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  got <- nd_notes(fit_sem(nd_touched, nd_data()))
  fit <- got$value
  expect_identical(fit@internals$fixed_x, "covariate1")
  expect_identical(glance(fit)$fixed_x, "covariate1")
  expect_length(got$notes, 1L)
  expect_identical(got$notes[[1L]]$variables, "treatment")
  expect_match(conditionMessage(got$notes[[1L]]), "treatment", fixed = TRUE)
  # the same fit as the explicit subset, which raises no note
  ref <- nd_notes(fit_sem(nd_touched, nd_data(), fixed_x = "covariate1", meanstructure = TRUE))
  expect_length(ref$notes, 0L)
  expect_equal(fit@theta, ref$value@theta, tolerance = 1e-10)
  expect_equal(as.numeric(logLik(fit)), as.numeric(logLik(ref$value)), tolerance = 1e-10)
  # a note on every fit, not once per session
  expect_length(nd_notes(fit_sem(nd_touched, nd_data()))$notes, 1L)
  # an explicit TRUE keeps today's error
  expect_error(fit_sem(nd_touched, nd_data(), fixed_x = TRUE), "has a statement on them (treatment ~~ treatment)",
               fixed = TRUE)
  # no note when nothing is left free, and the suite state is untouched by a note
  expect_length(nd_notes(fit_sem(nd_syntax, nd_data()))$notes, 0L)
  # every exogenous variable touched: the default is FALSE, not an empty subset
  got <- nd_notes(fit_sem(paste0(nd_syntax, "\ntreatment ~~ treatment"), nd_data()))
  expect_identical(got$value@internals$fixed_x, character())
  expect_identical(glance(got$value)$fixed_x, "")
  expect_length(got$notes, 1L)
  # a `~1` statement counts too
  got <- nd_notes(fit_sem(sub("treatment ~~ treatment", "treatment ~ 1", nd_touched, fixed = TRUE), nd_data()))
  expect_identical(got$value@internals$fixed_x, "covariate1")
  expect_identical(got$notes[[1L]]$variables, "treatment")
})

test_that("without the opt-in no note is raised for a statement on an exogenous variable", {
  local_native_defaults_unshown()
  got <- nd_notes(suppressWarnings(fit_sem(nd_touched, nd_data())))
  expect_length(got$notes, 0L)
  expect_identical(got$value@internals$fixed_x, character())
})

test_that("the opt-in subset includes product and factor-dummy columns (E-11)", {
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  d <- nd_pf_data()
  prod <- "m ~ x + cv\ny ~ m + x + x:m + cv"
  fit <- suppressWarnings(fit_sem(prod, d))
  expect_identical(fit@internals$fixed_x, c("x", "cv", "m:x"))
  ref <- suppressWarnings(fit_sem(prod, d, fixed_x = TRUE, meanstructure = TRUE))
  expect_identical(fit@internals$fixed_x, ref@internals$fixed_x)
  fac <- "m ~ x + g\ny ~ m + x + g"
  fit <- fit_sem(fac, d)
  expect_identical(fit@internals$fixed_x, c("x", "g_b", "g_c"))
  expect_identical(glance(fit)$fixed_x, "x, g_b, g_c")
  # a touched variable leaves the product and the dummies fixed
  got <- nd_notes(fit_sem(paste0(fac, "\nx ~~ x"), d))
  expect_identical(got$value@internals$fixed_x, c("g_b", "g_c"))
  expect_identical(got$notes[[1L]]$variables, "x")
  got <- nd_notes(suppressWarnings(fit_sem(paste0(prod, "\ncv ~ 1"), d)))
  expect_identical(got$value@internals$fixed_x, c("x", "m:x"))
  expect_identical(got$notes[[1L]]$variables, "cv")
})

test_that("refits see the resolved subset (T2 sites)", {
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  syn <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + treatment\ntreatment ~~ treatment"
  fit <- suppressMessages(fit_sem(syn, nd_data()))
  ref <- fit_sem(syn, nd_data(), fixed_x = "covariate1", meanstructure = TRUE)
  got <- nd_notes(mbco_sem(fit, a = "a", b = "b"))
  expect_length(got$notes, 0L)
  expect_equal(got$value$statistic, mbco_sem(ref, a = "a", b = "b")$statistic, tolerance = 1e-8)
  # anova() accepts the explicit-subset fit as having the same fixed set
  nested <- fit_sem(paste0(syn, "\na == b"), nd_data(), fixed_x = "covariate1", meanstructure = TRUE)
  expect_no_error(anova(fit, nested))
})

test_that("the MBCO and zero-product refits of an opt-in fit receive the resolved subset (QA, T6)", {
  # the MBCO statistic does not depend on fixed_x, so the check above cannot see a refit that drops the subset
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  syn <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + treatment\ntreatment ~~ treatment"
  branch <- suppressMessages(fit_sem(paste0(syn, "\na*b == 0"), nd_data()))
  expect_identical(branch@internals$fixed_x, "covariate1")
  fit <- suppressMessages(fit_sem(syn, nd_data()))
  seen <- list()
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    seen[[length(seen) + 1L]] <<- list(...)$fixed_x
    stop("stop after capturing")
  })
  try(mbco_sem(fit, a = "a", b = "b"), silent = TRUE)
  expect_true(length(seen) > 0L && all(vapply(seen, identical, TRUE, "covariate1")))
})

test_that("fit_mediation(engine = \"native\") and fit_sem() give the same fixed set under the opt-in (T7)", {
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  seen <- NULL
  orig <- medfit:::.sem_as_semfit
  local_mocked_bindings(.sem_as_semfit = function(fit, model, call = NULL) {
    seen <<- fit$fixed_x
    orig(fit, model, call)
  })
  a <- nd_notes(fit_mediation(data = nd_data(), treatment = "treatment", mediator = "mediator1",
                              engine = "native", model = nd_touched))
  expect_identical(seen, "covariate1")
  b <- nd_notes(fit_sem(nd_touched, nd_data()))
  expect_identical(b$value@internals$fixed_x, seen)
  expect_identical(a$notes[[1L]]$variables, b$notes[[1L]]$variables)
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
