# 0.15.0 flip of fit_sem()'s `fixed_x` and `meanstructure` defaults (plan T3; spec F-1 to F-4, E-13, E-14). An unset
# setting resolves to the new value unconditionally; an explicit value is never overwritten; the 0.14.x option is
# ignored (0.16.0 removed the obsolete note) and the default-change warning is gone.

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
  expect_no_warning(fit_sem(nd_syntax, nd_data()), class = "medfit_warning_default_change")
  expect_no_warning(
    fit_mediation(data = nd_data(), treatment = "treatment", mediator = "mediator1", engine = "native",
                  model = nd_syntax),
    class = "medfit_warning_default_change"
  )
  expect_false(exists(".warn_native_defaults_once", envir = asNamespace("medfit"), inherits = FALSE))
})

test_that("options(medfit.native_defaults) has no effect (F-3; the obsolete note was removed in 0.16.0)", {
  base <- fit_sem(nd_syntax, nd_data())
  for (val in list("0.15", "0.14", TRUE)) {
    withr::local_options(medfit.native_defaults = val)
    expect_no_message(fit <- fit_sem(nd_syntax, nd_data()))
    expect_equal(fit@theta, base@theta, tolerance = 1e-10)
  }
  # an explicit FALSE is preserved even with the option set
  withr::local_options(medfit.native_defaults = "0.15")
  fit <- suppressMessages(fit_sem(nd_syntax, nd_data(), fixed_x = FALSE, meanstructure = NULL))
  expect_identical(fit@internals$fixed_x, character())
  expect_false(fit@internals$ram$has_mean)
})

test_that("internal refits pass explicit settings and never warn", {
  fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment", nd_data(),
                 fixed_x = FALSE, meanstructure = NULL)
  w <- nd_catch(mbco_sem(fit, a = "a", b = "b"))
  expect_length(w$warnings, 0L)
})
