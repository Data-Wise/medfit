# T3: a modifier on a factor term (F4, D1). A label or fixed value names one coefficient, and a factor expands to
# several, so it is an error; a modifier on a single dummy is allowed.

fr_data <- function(n = 120L) {
  set.seed(3)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  x <- rnorm(n)
  data.frame(y = x + 0.5 * (g == "b") + rnorm(n), x = x, g = g)
}

test_that("a label on a factor term is an error that names the dummies and the fix", {
  expect_error(fit_sem("y ~ x + b*g", fr_data()), "`b\\*g`.*g_b, g_c.*label one, e.g. `b\\*g_b`")
})

test_that("a fixed value on a factor term is an error", {
  expect_error(fit_sem("y ~ x + 0.5*g", fr_data()), "`0.5\\*g`.*g_b, g_c")
})

test_that("start values and bounds on a factor term are errors too", {
  expect_error(fit_sem("y ~ x + start(0.1)*g", fr_data()), "`g`.*name several coefficients")
})

test_that("a label on one dummy fits, equals the hand-coded twin, and the label is usable", {
  d <- transform(fr_data(), g_b = as.numeric(g == "b"), g_c = as.numeric(g == "c"))
  f <- fit_sem("y ~ x + b*g_b + g_c\nd := 2*b", d)
  expect_true("b" %in% f@table$label)
  expect_equal(f@defined$est, 2 * f@table$est[f@table$label == "b"], tolerance = 1e-10)
})

test_that("an unlabeled factor term still fits", {
  expect_s7_class(fit_sem("y ~ x + g", fr_data()), SEMFit)
})

test_that("a model can name one dummy of a factor column (`b*g_b`), so a single dummy can carry a label", {
  d <- fr_data()
  twin <- transform(d, g_b = as.numeric(g == "b"), g_c = as.numeric(g == "c"))
  f <- fit_sem("y ~ x + b*g_b + g_c\nd := 2*b", d)
  f2 <- fit_sem("y ~ x + b*g_b + g_c\nd := 2*b", twin)
  expect_equal(unname(f@table$est), unname(f2@table$est), tolerance = 1e-8)
  expect_equal(unname(f@table$se), unname(f2@table$se), tolerance = 1e-6)
  expect_equal(f@defined$est, 2 * f@table$est[f@table$label == "b"], tolerance = 1e-10)
  # naming only g_b builds only that dummy: the other level is simply not in the model
  f3 <- fit_sem("y ~ x + g_b", d)
  expect_equal(f3@table$rhs[f3@table$op == "~"], c("x", "g_b"))
  expect_false("g_c" %in% f3@internals$ram$obs)
})

test_that("naming the reference level's dummy is an error; a bare name is not guessed", {
  expect_error(fit_sem("y ~ x + g_a", fr_data()), "`g_a` is the reference level of `g`")
  expect_error(fit_sem("y ~ x + g_zzz", fr_data()), "not columns of `data`: g_zzz")
})

test_that("a bare factor expands to every non-reference dummy, once", {
  f <- fit_sem("y ~ x + g", fr_data())
  expect_equal(f@table$rhs[f@table$op == "~"], c("x", "g_b", "g_c"))
})

test_that("a constraint naming the factor says it expands to dummies; the label route on one dummy works", {
  d <- fr_data()
  expect_error(fit_sem("y ~ x + g\ng == 0", d), "`g` is a categorical column.*g_b, g_c.*`b\\*g_b`.*`b == 0`")
  expect_error(fit_sem("y ~ x + g\nd := 2*g", d), "`g` is a categorical column")
  # the route the message names: label one dummy, constrain the label
  f <- fit_sem("y ~ x + g + b*g_b\nb == 0", d)
  est_b <- f@table$est[f@table$op == "~" & f@table$rhs == "g_b"]
  expect_length(est_b, 1L)
  expect_equal(unname(est_b), 0, tolerance = 1e-6)
  # a name that is not a column keeps the generic message
  expect_error(fit_sem("y ~ x + g\nzz == 0", d), "unknown parameter label 'zz'")
})

test_that("rule 8 refuses a factor product that uses the equation's own outcome (g:y in the y equation)", {
  d <- fr_data()
  expect_error(fit_sem("y ~ x + g:y", d), "product 'g_b:y' uses 'y'.*rule 8")
  # positive control: the same product on another variable is accepted
  expect_no_error(suppressWarnings(fit_sem("y ~ x + g:x", d)))
})
