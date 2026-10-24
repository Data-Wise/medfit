# T7 + Codex review of T3: a bare factor with an explicit labeled dummy, and refits (`mbco_sem()`, the zero-product
# branch fits) of a fit that was built from a factor column.

fr2_data <- function(n = 250L, seed = 8L) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  x <- rnorm(n)
  m <- 0.5 * x + 0.5 * (g == "b") + rnorm(n)
  y <- 0.4 * m + 0.2 * x + 0.3 * (g == "c") + rnorm(n)
  d <- data.frame(y = y, m = m, x = x, g = g)
  list(factor = d, twin = transform(d, g_b = as.numeric(g == "b"), g_c = as.numeric(g == "c")))
}
fr2_model <- "m ~ a*x + g\ny ~ b*m + cp*x + g"
fr2_twin <- "m ~ a*x + g_b + g_c\ny ~ b*m + cp*x + g_b + g_c"

test_that("a bare factor with an explicit labeled dummy emits each path once and keeps the label", {
  d <- fr2_data()
  f <- fit_sem("y ~ x + g + b*g_b", d$factor)
  rows <- f@table[f@table$op == "~", ]
  expect_equal(sum(rows$rhs == "g_b"), 1L)
  expect_equal(rows$label[rows$rhs == "g_b"], "b")
  expect_setequal(rows$rhs, c("x", "g_b", "g_c"))
  f2 <- fit_sem("y ~ x + b*g_b + g_c", d$twin)
  expect_equal(unname(sort(f@table$est)), unname(sort(f2@table$est)), tolerance = 1e-8)
})

test_that("the same holds when the explicit dummy comes first or in another equation", {
  d <- fr2_data()
  f <- fit_sem("y ~ x + b*g_b + g\nm ~ x + g", d$factor)
  expect_equal(sum(f@table$rhs == "g_b" & f@table$lhs == "y"), 1L)
  expect_equal(sum(f@table$rhs == "g_b" & f@table$lhs == "m"), 1L)
})

test_that("mbco_sem() refits a factor fit and equals the hand-coded twin", {
  d <- fr2_data()
  f <- fit_sem(fr2_model, d$factor)
  ft <- fit_sem(fr2_twin, d$twin)
  r <- mbco_sem(f, paths = c("a", "b"))
  rt <- mbco_sem(ft, paths = c("a", "b"))
  expect_true(is.finite(r$statistic))
  expect_equal(r$statistic, rt$statistic, tolerance = 1e-6)
  expect_equal(r$parameter, rt$parameter)
  expect_equal(r$p.value, rt$p.value, tolerance = 1e-6)
  expect_equal(r$tests$f, rt$tests$f, tolerance = 1e-8)
})

test_that("mbco_sem() refits a factor fit with fixed_x, naming the factor or one dummy", {
  d <- fr2_data()
  for (fx in list("g", "g_b", c("x", "g"), TRUE)) {
    f <- fit_sem(fr2_model, d$factor, fixed_x = fx)
    twin_fx <- if (is.character(fx)) unlist(lapply(fx, function(v) if (v == "g") c("g_b", "g_c") else v)) else fx
    ft <- fit_sem(fr2_twin, d$twin, fixed_x = twin_fx)
    r <- mbco_sem(f, paths = c("a", "b"))
    rt <- mbco_sem(ft, paths = c("a", "b"))
    expect_true(is.finite(r$statistic), info = paste(fx, collapse = ","))
    expect_equal(r$statistic, rt$statistic, tolerance = 1e-6, info = paste(fx, collapse = ","))
  }
})

test_that("a refit of a model with a partly named factor (only g_b) works", {
  d <- fr2_data()
  f <- fit_sem("m ~ a*x + g_b\ny ~ b*m + cp*x + g_b", d$factor)
  expect_silent(r <- mbco_sem(f, paths = c("a", "b")))
  expect_true(is.finite(r$statistic))
})

test_that("a zero-product constraint on a factor model (branch fits) equals the twin", {
  d <- fr2_data()
  f <- fit_sem(paste0(fr2_model, "\na*b == 0"), d$factor)
  ft <- fit_sem(paste0(fr2_twin, "\na*b == 0"), d$twin)
  expect_equal(unname(f@table$est), unname(ft@table$est), tolerance = 1e-6)
  expect_equal(as.numeric(logLik(f)), as.numeric(logLik(ft)), tolerance = 1e-8)
})

test_that("the fit stores the factor map and a refit does not need the factor column", {
  d <- fr2_data()
  f <- fit_sem(fr2_model, d$factor)
  expect_equal(f@internals$factors$g$dummies, c("g_b", "g_c"))
  expect_false("g" %in% names(f@data))
  fb <- fit_sem(paste0(fr2_model, "\na*b == 0"), d$factor)
  expect_equal(fb@internals$factors$g$dummies, c("g_b", "g_c"))
})

test_that("a stored map does not hide a missing dummy column", {
  d <- fr2_data()
  f <- fit_sem(fr2_model, d$factor)
  bad <- f@data[, setdiff(names(f@data), "g_c")]
  expect_error(.sem_fit_syntax(f@model, bad, factors = f@internals$factors), "g_c")
})

test_that("planted defect: an MBCO refit that drops the factor map is caught", {
  fx_skip_covr()
  d <- fr2_data()
  f <- fit_sem(fr2_model, d$factor, fixed_x = FALSE, meanstructure = NULL)
  bad <- sem_mutate(mbco_sem, "factors = fit@internals$factors", "factors = NULL")
  expect_error(bad(f, paths = c("a", "b")), "not columns of `data`: g")
})
