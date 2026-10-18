# The API freeze announced when the native engine lost its "experimental" label (NEWS, "Lifecycle"): exported
# signatures, `SEMFit` properties and the model-syntax grammar change only through a deprecation, and new syntax is
# added without changing what an existing name means (grill G3, 2026-10-17). The pins below are the contract: a name
# or argument order listed here may not move; ADDING (a property, a trailing argument, a statement) does not fail.
# Updating a pin is a deliberate act that needs a deprecation and a NEWS entry, so the failure message says so.

freeze_missing <- function(pinned, actual) setdiff(pinned, actual)
freeze_prefix_broken <- function(pinned, actual) !identical(utils::head(actual, length(pinned)), pinned)

pin_semfit_properties <- c("theta", "vcov", "table", "defined", "f", "n_obs", "n_dropped", "df", "information",
                           "converged", "data", "model", "diagnostics", "internals", "call")
pin_fit_sem_args <- c("model", "data", "information", "n_starts", "control", "weights", "se_type", "meanstructure",
                      "fixed_x", "sampling_weights")
pin_mbco_sem_args <- c("object", "a", "b", "n_starts", "control", "fit", "paths")

test_that("the SEMFit property names are pinned (additions allowed, removals and renames are not)", {
  expect_equal(freeze_missing(pin_semfit_properties, names(SEMFit@properties)), character(0),
               info = "a SEMFit property was removed or renamed: the freeze needs a deprecation and a NEWS entry")
})

test_that("fit_sem() and mbco_sem() keep their argument names and order (new arguments only at the end)", {
  expect_false(freeze_prefix_broken(pin_fit_sem_args, names(formals(fit_sem))),
               info = "fit_sem() arguments moved, were renamed or removed")
  expect_false(freeze_prefix_broken(pin_mbco_sem_args, names(formals(mbco_sem))),
               info = "mbco_sem() arguments moved, were renamed or removed")
})

test_that("the canonical product name is pinned: x:m and m:x are the one name 'm:x'", {
  expect_identical(.sem_product_name("x", "m"), "m:x")
  expect_identical(.sem_product_name("m", "x"), "m:x")
})

test_that("every statement kind of ?medfit-syntax still parses", {
  statements <- c(
    "f =~ y1 + y2 + y3",                       # measurement
    "m ~ a*x + start(0.3)*w",                  # label, starting value
    "y ~ b*m + 0.5*x + lower(0)*w + upper(1)*z + x:m", # label, fixed value, both bounds, product term
    "m ~~ y", "x ~~ x",                        # covariance, variance
    "y ~ 1",                                   # intercept
    "a == b", "a < 3", "b > 0",                # equality, both inequality spellings
    "ab := a*b"                                # defined parameter
  )
  model <- paste(statements, collapse = "\n")
  parsed <- .sem_parse(model)
  expect_named(parsed, c("parameters", "constraints"))
  expect_gt(nrow(parsed$parameters), 0)
  expect_gt(NROW(parsed$constraints), 0)
  expect_true(any(grepl("m:x", unlist(parsed$parameters), fixed = TRUE)),
              info = "the product term lost its canonical name 'm:x' in the parsed model")
})

test_that("planted defect: the pin checks fail when a name or an argument moves", {
  expect_identical(freeze_missing(pin_semfit_properties, setdiff(names(SEMFit@properties), "converged")), "converged")
  expect_true(freeze_prefix_broken(pin_fit_sem_args, rev(names(formals(fit_sem)))))
  expect_true(freeze_prefix_broken(pin_fit_sem_args, c("data", "model", names(formals(fit_sem))[-(1:2)])))
  expect_false(freeze_prefix_broken(pin_fit_sem_args, c(names(formals(fit_sem)), "a_new_argument")))
  expect_identical(freeze_missing(pin_semfit_properties, c(names(SEMFit@properties), "a_new_property")), character(0))
})
