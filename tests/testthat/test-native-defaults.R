# 0.15.0 flip of fit_sem()'s `fixed_x` and `meanstructure` defaults (plan T3; spec F-1 to F-4, E-13, E-14). An unset
# setting resolves to the new value unconditionally; an explicit value is never overwritten; the 0.14.x option is
# ignored with an obsolete note and the default-change warning is gone. The suite helper marks the obsolete note as
# shown; tests that exercise it reset the state locally and the helper's deferred restore puts it back.

nd_syntax <- "mediator1 ~ treatment\noutcome ~ mediator1 + treatment"
nd_data <- function() medfit::mediation_demo

# Warnings of the retired default-change class raised by `expr`, with the value.
nd_catch <- function(expr) {
  got <- list()
  value <- withCallingHandlers(expr, medfit_warning_default_change = function(w) {
    got[[length(got) + 1L]] <<- w
    invokeRestart("muffleWarning")
  })
  list(value = value, warnings = got)
}

test_that("the formals carry the 0.15.0 defaults (F-1)", {
  expect_identical(formals(fit_sem)$meanstructure, TRUE)
  expect_identical(formals(fit_sem)$fixed_x, TRUE)
})

test_that("unset settings resolve to the new values and never warn (F-1, F-4)", {
  local_native_defaults_unshown()
  w <- nd_catch(fit_sem(nd_syntax, nd_data()))
  expect_length(w$warnings, 0L)
  # unset fixed_x is the explicit subset (E-13), not a bare TRUE
  expect_identical(w$value@internals$fixed_x, "treatment")
  expect_true(w$value@internals$ram$has_mean)
  ref <- fit_sem(nd_syntax, nd_data(), fixed_x = TRUE, meanstructure = TRUE)
  expect_equal(w$value@theta, ref@theta, tolerance = 1e-10)
  # still silent on every later call
  expect_length(nd_catch(fit_sem(nd_syntax, nd_data()))$warnings, 0L)
  # no observed exogenous variable: fixed_x resolves to none
  w <- nd_catch(fit_sem("outcome ~~ mediator1", nd_data()))
  expect_identical(w$value@internals$fixed_x, character())
  expect_true(w$value@internals$ram$has_mean)
})

test_that("an explicit FALSE or NULL is preserved, alone or with the other setting unset (F-2)", {
  local_native_defaults_unshown()
  w <- nd_catch(fit_sem(nd_syntax, nd_data(), fixed_x = FALSE, meanstructure = NULL))
  expect_length(w$warnings, 0L)
  expect_identical(w$value@internals$fixed_x, character())
  expect_false(w$value@internals$ram$has_mean)
  # one explicit, one unset: the explicit one is kept, only the unset one resolves (planted defect: a resolver that
  # overwrites an explicit FALSE or NULL)
  w <- fit_sem(nd_syntax, nd_data(), meanstructure = FALSE)
  expect_false(w@internals$ram$has_mean)
  expect_identical(w@internals$fixed_x, "treatment")
  w <- fit_sem(nd_syntax, nd_data(), meanstructure = NULL)
  expect_false(w@internals$ram$has_mean)
  expect_identical(w@internals$fixed_x, "treatment")
  w <- fit_sem(nd_syntax, nd_data(), fixed_x = FALSE)
  expect_identical(w@internals$fixed_x, character())
  expect_true(w@internals$ram$has_mean)
  # explicit values other than the old defaults are kept too
  w <- fit_sem(nd_syntax, nd_data(), fixed_x = "treatment", meanstructure = FALSE)
  expect_identical(w@internals$fixed_x, "treatment")
  expect_false(w@internals$ram$has_mean)
})

test_that("the resolver itself keeps explicit values (F-2, unit)", {
  got <- .native_defaults_resolve(nd_syntax, nd_data(), FALSE, NULL, FALSE, FALSE)
  expect_identical(got, list(fixed_x = FALSE, meanstructure = NULL))
  got <- .native_defaults_resolve(nd_syntax, nd_data(), FALSE, NULL, TRUE, FALSE)
  expect_identical(got, list(fixed_x = "treatment", meanstructure = NULL))
  got <- .native_defaults_resolve(nd_syntax, nd_data(), TRUE, TRUE, FALSE, TRUE)
  expect_identical(got, list(fixed_x = TRUE, meanstructure = TRUE))
})

test_that("explicit fixed_x = TRUE keeps its error on a ~~ or ~1 statement on an exogenous variable (F-2)", {
  syn <- "mediator1 ~ treatment + covariate1\noutcome ~ mediator1 + treatment\ntreatment ~~ treatment"
  expect_error(fit_sem(syn, nd_data(), fixed_x = TRUE), "has a statement on them (treatment ~~ treatment)",
               fixed = TRUE)
  syn1 <- sub("treatment ~~ treatment", "treatment ~ 1", syn, fixed = TRUE)
  expect_error(fit_sem(syn1, nd_data(), fixed_x = TRUE), "treatment", fixed = TRUE)
  # the unset default does not error: it leaves the touched variable free
  fit <- suppressMessages(fit_sem(syn, nd_data()))
  expect_identical(fit@internals$fixed_x, "covariate1")
})

test_that("the old default-change warning cannot fire, whatever the state (F-4)", {
  local_native_defaults_unshown()
  expect_no_warning(fit_sem(nd_syntax, nd_data()), class = "medfit_warning_default_change")
  expect_no_warning(
    fit_mediation(data = nd_data(), treatment = "treatment", mediator = "mediator1", engine = "native",
                  model = nd_syntax),
    class = "medfit_warning_default_change"
  )
  expect_false(exists(".warn_native_defaults_once", envir = asNamespace("medfit"), inherits = FALSE))
})

test_that("options(medfit.native_defaults) is ignored with a classed obsolete note, once per session (F-3)", {
  local_native_defaults_unshown()
  base <- fit_sem(nd_syntax, nd_data())
  for (val in list("0.15", "0.14", TRUE)) {
    local_native_defaults_unshown()
    withr::local_options(medfit.native_defaults = val)
    notes <- list()
    fit <- withCallingHandlers(fit_sem(nd_syntax, nd_data()), medfit_message_option_obsolete = function(m) {
      notes[[length(notes) + 1L]] <<- m
      invokeRestart("muffleMessage")
    })
    expect_length(notes, 1L)
    expect_match(conditionMessage(notes[[1L]]), "medfit.native_defaults", fixed = TRUE)
    expect_match(conditionMessage(notes[[1L]]), "0.16.0", fixed = TRUE)
    # ignored: the fit is the unset-default fit, never an error and never a different value
    expect_equal(fit@theta, base@theta, tolerance = 1e-10)
    # once per session
    expect_no_message(fit_sem(nd_syntax, nd_data()), class = "medfit_message_option_obsolete")
  }
  # an unset option raises nothing
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = NULL)
  expect_no_message(fit_sem(nd_syntax, nd_data()), class = "medfit_message_option_obsolete")
  # an explicit FALSE is preserved even with the option set
  local_native_defaults_unshown()
  withr::local_options(medfit.native_defaults = "0.15")
  fit <- suppressMessages(fit_sem(nd_syntax, nd_data(), fixed_x = FALSE, meanstructure = NULL))
  expect_identical(fit@internals$fixed_x, character())
  expect_false(fit@internals$ram$has_mean)
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

test_that("the default fixes the exogenous variables without a statement and leaves the rest free with a note (T6)", {
  local_native_defaults_unshown()
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

test_that("an explicit fixed_x = FALSE raises no note for a statement on an exogenous variable", {
  local_native_defaults_unshown()
  got <- nd_notes(fit_sem(nd_touched, nd_data(), fixed_x = FALSE))
  expect_length(got$notes, 0L)
  expect_identical(got$value@internals$fixed_x, character())
})

test_that("the default subset includes product and factor-dummy columns (E-11)", {
  local_native_defaults_unshown()
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

test_that("a statement on a factor name gives the fit's own error and no lenient note (QA O1)", {
  local_native_defaults_unshown()
  d <- nd_pf_data()
  notes <- list()
  expect_error(
    withCallingHandlers(fit_sem("m ~ x + g\ny ~ m + x + g\ng ~~ g", d),
                        medfit_message_fixed_x_lenient = function(m) {
                          notes[[length(notes) + 1L]] <<- m
                          invokeRestart("muffleMessage")
                        }),
    "model variables must be numeric: g", fixed = TRUE
  )
  expect_length(notes, 0L)
})

test_that("the resolver keeps meanstructure = TRUE when the fixed_x default cannot be computed (QA O2)", {
  local_native_defaults_unshown()
  local_mocked_bindings(.sem_default_fixed_x = function(parameters, data) stop("expansion failed"))
  got <- .native_defaults_resolve(nd_syntax, nd_data(), FALSE, NULL, TRUE, TRUE)
  expect_identical(got$meanstructure, TRUE)
  expect_identical(got$fixed_x, FALSE)
  # the same when the syntax cannot be classified: the fit reports it with its own message
  got <- .native_defaults_resolve("not a model", nd_data(), TRUE, TRUE, TRUE, TRUE)
  expect_identical(got$meanstructure, TRUE)
  expect_identical(got$fixed_x, FALSE)
})

test_that("refits see the resolved subset (T2 sites)", {
  local_native_defaults_unshown()
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

test_that("the MBCO and zero-product refits of a default fit receive the resolved subset (QA, T6)", {
  # the MBCO statistic does not depend on fixed_x, so the check above cannot see a refit that drops the subset
  local_native_defaults_unshown()
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

test_that("fit_mediation(engine = \"native\") and fit_sem() give the same fixed set by default (T7)", {
  local_native_defaults_unshown()
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

test_that("fit_mediation(engine = \"native\") takes the new defaults and honors engine_args (F-1, F-2)", {
  local_native_defaults_unshown()
  fit_med <- function(...) {
    fit_mediation(data = nd_data(), treatment = "treatment", mediator = "mediator1", engine = "native",
                  model = nd_syntax, ...)
  }
  seen <- NULL
  orig <- medfit:::.sem_as_semfit
  local_mocked_bindings(.sem_as_semfit = function(fit, model, call = NULL) {
    seen <<- list(fixed_x = fit$fixed_x, has_mean = fit$ram$has_mean)
    orig(fit, model, call)
  })
  w <- nd_catch(fit_med())
  expect_length(w$warnings, 0L)
  expect_identical(seen, list(fixed_x = "treatment", has_mean = TRUE))
  fit_med(engine_args = list(fixed_x = FALSE, meanstructure = NULL))
  expect_identical(seen, list(fixed_x = character(), has_mean = FALSE))
  fit_med(engine_args = list(meanstructure = FALSE))
  expect_identical(seen, list(fixed_x = "treatment", has_mean = FALSE))
  fit_med(engine_args = list(fixed_x = FALSE))
  expect_identical(seen, list(fixed_x = character(), has_mean = TRUE))
})

test_that("internal refits pass explicit settings and never warn", {
  local_native_defaults_unshown()
  fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment", nd_data(),
                 fixed_x = FALSE, meanstructure = NULL)
  w <- nd_catch(mbco_sem(fit, a = "a", b = "b"))
  expect_length(w$warnings, 0L)
})

test_that("the suite helper leaves the obsolete-option note marked as shown", {
  expect_true(all(.native_defaults_state()))
})
