# T4: `fixed_x` with a factor covariate at fit level (F6). The oracle is the hand-coded twin with the same
# dummies fixed; every comparison also asserts a finite, non-NULL value, so a vacuous equality cannot pass.

fxf_data <- function(n = 240L, seed = 14L, na_frac = 0) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  x <- rnorm(n)
  m <- 0.5 * x + 0.5 * (g == "b") + rnorm(n)
  y <- 0.4 * m + 0.2 * x + 0.3 * (g == "c") + rnorm(n)
  d <- data.frame(y = y, m = m, x = x, g = g)
  if (na_frac > 0) {
    d$g[sample(n, round(na_frac * n))] <- NA
  }
  twin <- transform(d, g_b = as.numeric(g == "b"), g_c = as.numeric(g == "c"))
  list(factor = d, twin = twin)
}
fxf_model <- "m ~ a*x + g\ny ~ b*m + cp*x + g"
fxf_twin <- "m ~ a*x + g_b + g_c\ny ~ b*m + cp*x + g_b + g_c"

fxf_same <- function(f, ft, info = NULL) {
  testthat::expect_true(all(is.finite(f@table$est)), info = info)
  testthat::expect_true(is.finite(as.numeric(logLik(f))), info = info)
  testthat::expect_equal(f@table$fixed_x, ft@table$fixed_x, info = info)
  testthat::expect_equal(unname(f@table$est), unname(ft@table$est), tolerance = 1e-8, info = info)
  testthat::expect_equal(unname(f@table$se), unname(ft@table$se), tolerance = 1e-6, info = info)
  testthat::expect_equal(as.numeric(logLik(f)), as.numeric(logLik(ft)), tolerance = 1e-8, info = info)
  testthat::expect_equal(f@df, ft@df, info = info)
  testthat::expect_equal(length(f@theta), length(ft@theta), info = info)
}

# The fixed ~~ rows must be the ML moments of the rows the fit used, computed in base R (independent of the engine).
fxf_moment_gap <- function(f, used) {
  fixed <- f@table[f@table$fixed_x %in% TRUE & f@table$op == "~~", ]
  testthat::expect_gt(nrow(fixed), 0L)
  n <- nrow(used)
  s <- stats::cov(used) * (n - 1) / n
  max(abs(fixed$est - mapply(function(a, b) s[a, b], fixed$lhs, fixed$rhs)))
}

test_that("fixed_x names a factor, a mix, a dummy, or TRUE: each equals the twin with the same dummies fixed", {
  d <- fxf_data()
  cases <- list(
    list(fx = "g", twin = c("g_b", "g_c")),
    list(fx = c("x", "g"), twin = c("x", "g_b", "g_c")),
    list(fx = "g_b", twin = "g_b"),
    list(fx = TRUE, twin = TRUE)
  )
  for (cs in cases) {
    f <- fit_sem(fxf_model, d$factor, fixed_x = cs$fx)
    ft <- fit_sem(fxf_twin, d$twin, fixed_x = cs$twin)
    fxf_same(f, ft, info = paste(format(cs$fx), collapse = ","))
  }
})

test_that("fixing a factor removes parameters: fewer than the free fit, as for hand-coded dummies", {
  d <- fxf_data()
  free <- fit_sem(fxf_model, d$factor, fixed_x = FALSE, meanstructure = NULL)
  fixed <- fit_sem(fxf_model, d$factor, fixed_x = "g", meanstructure = NULL)
  expect_lt(length(fixed@theta), length(free@theta))
  expect_equal(fixed@df, free@df)
})

test_that("glance() lists the dummies as the fixed variables", {
  f <- fit_sem(fxf_model, fxf_data()$factor, fixed_x = "g")
  gl <- generics::glance(f)
  expect_identical(gl$fixed_x, "g_b, g_c")
  ft <- fit_sem(fxf_twin, fxf_data()$twin, fixed_x = c("g_b", "g_c"))
  expect_identical(gl$fixed_x, generics::glance(ft)$fixed_x)
})

test_that("the fixed moments are those of the rows the fit uses", {
  d <- fxf_data(na_frac = 0.1)
  keep <- stats::complete.cases(d$twin[, c("y", "m", "x", "g_b", "g_c")]) & !is.na(d$factor$g)
  twin_kept <- d$twin[keep, ]
  expect_lt(sum(keep), nrow(d$factor))
  f <- suppressMessages(fit_sem(fxf_model, d$factor, fixed_x = "g"))
  ft <- fit_sem(fxf_twin, twin_kept, fixed_x = c("g_b", "g_c"))
  expect_equal(f@n_obs, sum(keep))
  fxf_same(f, ft)
  used <- twin_kept[, c("x", "g_b", "g_c")]
  expect_lt(fxf_moment_gap(f, used), 1e-8)
})

test_that("an NA in the outcome (dummies finite) still gives the moments of the kept rows", {
  d <- fxf_data()
  set.seed(2)
  idx <- sample(nrow(d$factor), 30)
  d$factor$y[idx] <- NA
  d$twin$y[idx] <- NA
  used <- d$twin[stats::complete.cases(d$twin[, c("y", "m", "x")]), c("x", "g_b", "g_c")]
  f <- suppressMessages(fit_sem(fxf_model, d$factor, fixed_x = "g"))
  expect_equal(f@n_obs, nrow(used))
  expect_lt(fxf_moment_gap(f, used), 1e-8)
  full <- d$twin[, c("x", "g_b", "g_c")]
  expect_gt(abs(stats::cov(used)["g_b", "g_b"] - stats::cov(full)["g_b", "g_b"]), 0)
})

test_that("a factor and one of its own dummies in fixed_x name each dummy once", {
  d <- fxf_data()
  f <- fit_sem(fxf_model, d$factor, fixed_x = c("g", "g_b"))
  ft <- fit_sem(fxf_twin, d$twin, fixed_x = c("g_b", "g_c"))
  fxf_same(f, ft)
})

test_that("a factor on one equation's right side only fixes just the dummies that appear", {
  d <- fxf_data()
  f <- fit_sem("m ~ a*x + g\ny ~ b*m + cp*x", d$factor, fixed_x = "g")
  ft <- fit_sem("m ~ a*x + g_b + g_c\ny ~ b*m + cp*x", d$twin, fixed_x = c("g_b", "g_c"))
  fxf_same(f, ft)
  expect_true(all(c("g_b", "g_c") %in% f@internals$fixed_x))
})

test_that("the fixed ~~ rows of a full-data fit are the independent ML moments, pairs with x included", {
  d <- fxf_data()
  f <- fit_sem(fxf_model, d$factor, fixed_x = "g")
  # a fixed variable also fixes its pairs with the free exogenous variables (x ~~ g_b)
  expect_lt(fxf_moment_gap(f, d$twin[, c("x", "g_b", "g_c")]), 1e-8)
})

test_that("lavaan fixed.x = TRUE on the twin agrees on counts, chi-square and estimates", {
  skip_if_not_installed("lavaan")
  d <- fxf_data()
  f <- fit_sem(fxf_model, d$factor, fixed_x = TRUE)
  l <- lavaan::sem(fxf_twin, d$twin, meanstructure = TRUE, fixed.x = TRUE)
  expect_equal(f@df, as.numeric(lavaan::fitMeasures(l, "df")))
  reg <- lavaan::parameterEstimates(l)
  reg <- reg[reg$op == "~", ]
  est <- f@table[f@table$op == "~", ]
  expect_true(all(is.finite(est$est)))
  expect_equal(unname(est$est), unname(reg$est), tolerance = 1e-4)
})

test_that("a name that is not an exogenous variable of the model keeps its error", {
  d <- fxf_data()$factor
  expect_error(fit_sem(fxf_model, d, fixed_x = "zzz"), "not exogenous observed variables of the model: zzz$")
  expect_error(fit_sem(fxf_model, d, fixed_x = "m"), "not exogenous observed variables of the model: m$")
  # a factor that is on no regression's right side is not expanded, so it is not an exogenous model variable
  expect_error(fit_sem("y ~ x", d, fixed_x = "g"), "not exogenous observed variables of the model: g$")
})

test_that("planted defect: fixed_x names left as the factor are caught", {
  fx_skip_covr()
  bad <- sem_mutate(.sem_expand_fixed_x, "map[[v]]$dummies", "v")
  testthat::local_mocked_bindings(.sem_expand_fixed_x = bad)
  expect_error(fit_sem(fxf_model, fxf_data()$factor, fixed_x = "g"), "not exogenous observed variables.*g")
})

test_that("fit statistics equal lavaan on an over-identified model, free and fixed.x (npar, df, chi-square)", {
  skip_if_not_installed("lavaan")
  d <- fxf_data(n = 300L, seed = 21L)
  # no x -> y path, so df = 1 and the chi-square is not trivially zero (a saturated model would make it vacuous)
  mod_f <- "m ~ a*x + g\ny ~ b*m + g"
  mod_t <- "m ~ a*x + g_b + g_c\ny ~ b*m + g_b + g_c"
  for (fx in c(FALSE, TRUE)) {
    f <- fit_sem(mod_f, d$factor, fixed_x = fx, meanstructure = NULL)
    ft <- fit_sem(mod_t, d$twin, fixed_x = fx, meanstructure = NULL)
    # no mean structure on either side (medfit's has none without a `~1` row), so the parameter counts compare
    l <- lavaan::sem(mod_t, d$twin, meanstructure = FALSE, fixed.x = fx, information = "observed")
    ref <- lavaan::fitMeasures(l, c("npar", "df", "chisq"))
    gl <- generics::glance(f)
    info <- paste("fixed_x =", fx)
    expect_true(is.finite(gl$chisq) && gl$chisq > 0, info = info)
    expect_gt(gl$df, 0)
    expect_equal(gl$npar, unname(ref["npar"]), info = info)
    expect_equal(gl$df, unname(ref["df"]), info = info)
    expect_equal(gl$chisq, unname(ref["chisq"]), tolerance = 1e-5, info = info)
    # and the twin agrees with the factor fit on the same three numbers
    glt <- generics::glance(ft)
    expect_equal(c(gl$npar, gl$df, gl$chisq), c(glt$npar, glt$df, glt$chisq), tolerance = 1e-8, info = info)
  }
})

test_that("planted defect: a wrong dummy set changes the chi-square the lavaan comparison reads", {
  fx_skip_covr()
  skip_if_not_installed("lavaan")
  d <- fxf_data(n = 300L, seed = 21L)
  bad <- sem_mutate(.sem_row_expansion, "map[[sides]]$dummies", "map[[sides]]$dummies[1L]")
  testthat::local_mocked_bindings(.sem_row_expansion = bad)
  f <- fit_sem("m ~ a*x + g\ny ~ b*m + g", d$factor)
  l <- lavaan::sem("m ~ a*x + g_b + g_c\ny ~ b*m + g_b + g_c", d$twin, meanstructure = FALSE, fixed.x = FALSE,
                   information = "observed")
  expect_gt(abs(generics::glance(f)$chisq - lavaan::fitMeasures(l, "chisq")), 1e-3)
})
