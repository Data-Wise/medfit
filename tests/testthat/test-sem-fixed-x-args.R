# V1: the fixed_x argument, its validation and its errors (spec S1, S5, S9).

test_that("fixed_x = FALSE is the default and changes nothing", {
  d <- fx_data()
  base <- fit_sem(fx_syntax, d)
  off <- fit_sem(fx_syntax, d, fixed_x = FALSE)
  expect_identical(off@internals$fixed_x, character())
  expect_equal(off@theta, base@theta, tolerance = 0)
  expect_equal(off@f, base@f, tolerance = 0)
  expect_false(any(off@table$fixed_x))
})

test_that("TRUE selects every exogenous observed variable and names select a subset", {
  d <- fx_data()
  expect_setequal(fit_sem(fx_syntax, d, fixed_x = TRUE)@internals$fixed_x, fx_exo)
  expect_identical(fit_sem(fx_syntax, d, fixed_x = "covariate1")@internals$fixed_x, "covariate1")
  expect_setequal(fit_sem(fx_syntax, d, fixed_x = c("treatment", "covariate2"))@internals$fixed_x,
                  c("treatment", "covariate2"))
})

test_that("bad arguments error, naming the problem", {
  d <- fx_data()
  expect_error(fit_sem(fx_syntax, d, fixed_x = "outcome"), "not exogenous observed variables.*outcome")
  expect_error(fit_sem(fx_syntax, d, fixed_x = "mediator1"), "not exogenous observed variables.*mediator1")
  expect_error(fit_sem(fx_syntax, d, fixed_x = "nope"), "not exogenous observed variables.*nope")
  expect_error(fit_sem(fx_syntax, d, fixed_x = NA), "fixed_x")
  expect_error(fit_sem(fx_syntax, d, fixed_x = c("treatment", "treatment")), "fixed_x")
  expect_error(fit_sem(fx_syntax, d, fixed_x = character()), "fixed_x")
  expect_error(fit_sem(fx_syntax, d, fixed_x = 1), "fixed_x")
})

test_that("a user statement on a selected variable errors, naming the term (S5)", {
  d <- fx_data()
  expect_error(fit_sem(paste0(fx_syntax, "\ntreatment ~~ v*treatment"), d, fixed_x = TRUE),
               "treatment ~~ treatment")
  expect_error(fit_sem(paste0(fx_syntax, "\ncovariate1 ~~ covariate2"), d, fixed_x = c("covariate1")),
               "covariate1 ~~ covariate2")
  expect_error(fit_sem(paste0(fx_syntax, "\ncovariate1 ~ 1"), d, fixed_x = "covariate1"), "covariate1 ~1")
  expect_error(fit_sem(paste0(fx_syntax, "\ntreatment ~~ v*treatment\nv == 1"), d, fixed_x = "treatment"),
               "treatment ~~ treatment")
  # the same statements are fine when the variable is not selected
  expect_no_error(fit_sem(paste0(fx_syntax, "\ncovariate1 ~~ covariate2"), d, fixed_x = "treatment"))
  expect_no_error(fit_sem(paste0(fx_syntax, "\ntreatment ~~ v*treatment"), d, fixed_x = FALSE))
})

test_that("a user-fixed value stays a restriction and is not flagged fixed_x", {
  d <- fx_data()
  fit <- fit_sem(paste0(fx_syntax, "\ncovariate1 ~~ 0*covariate2"), d, fixed_x = "treatment")
  tab <- fit@table
  user <- tab[tab$lhs == "covariate1" & tab$rhs == "covariate2" & tab$op == "~~", ]
  expect_false(user$fixed_x)
  expect_equal(user$est, 0)
  tv <- tab[tab$lhs == "treatment" & tab$op == "~~" & tab$rhs == "treatment", ]
  expect_true(tv$fixed_x)
})
