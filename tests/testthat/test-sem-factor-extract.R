# T8: extraction with a factor covariate (F9, D9). The four-way decomposition from a native fit whose mediator and
# outcome equations carry a factor covariate equals the glm route with the same factor (component estimates) and the
# native fit with the hand-coded dummies (components and SEs). A factor treatment or mediator is refused by name.

fe_data <- function(n = 500L, seed = 51L) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  c1 <- rnorm(n)
  x <- rbinom(n, 1L, 0.5)
  m <- 0.5 * x + 0.4 * c1 + 0.5 * (g == "b") - 0.3 * (g == "c") + rnorm(n)
  y <- 0.3 * x + 0.4 * m + 0.25 * x * m + 0.3 * c1 + 0.4 * (g == "c") + rnorm(n)
  d <- data.frame(y = y, m = m, x = x, c1 = c1, g = g)
  list(factor = d, twin = transform(d, g_b = as.numeric(g == "b"), g_c = as.numeric(g == "c")))
}
fe_fit <- function(model, d, ...) suppressMessages(suppressWarnings(fit_sem(model, d, ...)))
fe_comp <- function(r) c(cde = r@cde, int_ref = r@int_ref, int_med = r@int_med, pie = r@pie)
fe_model <- "m ~ x + c1 + g\ny ~ x + m + x:m + c1 + g"
fe_twin_model <- "m ~ x + c1 + g_b + g_c\ny ~ x + m + x:m + c1 + g_b + g_c"

test_that("native four-way with a factor covariate equals the dummy-coded native fit: components and SEs", {
  d <- fe_data()
  r <- extract_mediation(fe_fit(fe_model, d$factor), treatment = "x", mediator = "m", decomposition = "four_way")
  rt <- extract_mediation(fe_fit(fe_twin_model, d$twin), treatment = "x", mediator = "m", decomposition = "four_way")
  expect_s7_class(r, InteractionMediationData)
  expect_true(all(is.finite(fe_comp(r))))
  expect_equal(fe_comp(r), fe_comp(rt), tolerance = 1e-8)
  tg <- generics::tidy(r)
  tt <- generics::tidy(rt)
  expect_true(all(is.finite(tg$std_error)))
  expect_equal(tg$estimate, tt$estimate, tolerance = 1e-8)
  expect_equal(tg$std_error, tt$std_error, tolerance = 1e-6)
})

test_that("native four-way with a factor covariate equals the glm route with the same factor (components)", {
  d <- fe_data()
  r <- extract_mediation(fe_fit(fe_model, d$factor), treatment = "x", mediator = "m", decomposition = "four_way")
  gl <- fit_mediation(y ~ x + m + x:m + c1 + g, m ~ x + c1 + g, d$factor, treatment = "x", mediator = "m")
  expect_true(all(is.finite(fe_comp(gl))))
  expect_equal(fe_comp(r), fe_comp(gl), tolerance = 1e-6)
})

test_that("a weighted native four-way with a factor covariate equals the weighted twin and the weighted glm route", {
  # the glm route's sandwich covariance needs the Suggests-only package
  skip_if_not_installed("sandwich")
  d <- fe_data()
  set.seed(6)
  w <- runif(nrow(d$factor), 0.5, 2)
  r <- extract_mediation(fe_fit(fe_model, d$factor, weights = w, se_type = "sandwich"),
                         treatment = "x", mediator = "m", decomposition = "four_way")
  rt <- extract_mediation(fe_fit(fe_twin_model, d$twin, weights = w, se_type = "sandwich"),
                          treatment = "x", mediator = "m", decomposition = "four_way")
  gl <- fit_mediation(y ~ x + m + x:m + c1 + g, m ~ x + c1 + g, d$factor, treatment = "x", mediator = "m",
                      weights = w, se_type = "sandwich")
  expect_equal(fe_comp(r), fe_comp(rt), tolerance = 1e-8)
  expect_equal(fe_comp(r), fe_comp(gl), tolerance = 1e-6)
})

test_that("a factor covariate that is only in the mediator equation still gives the glm route's components", {
  d <- fe_data()
  r <- extract_mediation(fe_fit("m ~ x + c1 + g\ny ~ x + m + x:m + c1", d$factor), treatment = "x", mediator = "m",
                         decomposition = "four_way")
  gl <- fit_mediation(y ~ x + m + x:m + c1, m ~ x + c1 + g, d$factor, treatment = "x", mediator = "m")
  expect_equal(fe_comp(r), fe_comp(gl), tolerance = 1e-6)
})

test_that("fit_mediation(engine = 'native') with a factor covariate returns the same four-way object as the twin", {
  d <- fe_data()
  f <- suppressMessages(suppressWarnings(fit_mediation(
    data = d$factor, treatment = "x", mediator = "m", engine = "native", model = fe_model
  )))
  ft <- extract_mediation(fe_fit(fe_twin_model, d$twin), treatment = "x", mediator = "m", decomposition = "four_way")
  expect_equal(fe_comp(f), fe_comp(ft), tolerance = 1e-8)
})

test_that("a factor named as the treatment or the mediator is refused by name, with the rule", {
  set.seed(2)
  n <- 300L
  d <- data.frame(x = rnorm(n), g = factor(sample(c("a", "b"), n, replace = TRUE)))
  d$m <- 0.5 * d$x + 0.5 * (d$g == "b") + rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * d$x + 0.4 * (d$g == "b") + rnorm(n)
  f <- fe_fit("m ~ x + g\ny ~ x + m + g", d)
  expect_error(extract_mediation(f, treatment = "g", mediator = "m"), "^`g` is a factor.*single numeric column")
  expect_error(extract_mediation(f, treatment = "x", mediator = "g"), "^`g` is a factor.*single numeric column")
  expect_error(extract_mediation(f, treatment = "g", mediator = "m"), "g_b")
})

test_that("a factor outcome keeps the numeric error", {
  d <- fe_data()$factor
  expect_error(fit_sem("g ~ x\ny ~ g + x", d), "must be numeric: g")
})

test_that("planted defect: dummies left out of the mediator equation change the components", {
  fx_skip_covr()
  d <- fe_data()
  r <- extract_mediation(fe_fit(fe_model, d$factor), treatment = "x", mediator = "m", decomposition = "four_way")
  r_no <- extract_mediation(fe_fit("m ~ x + c1\ny ~ x + m + x:m + c1 + g", d$factor), treatment = "x",
                            mediator = "m", decomposition = "four_way")
  expect_gt(max(abs(fe_comp(r) - fe_comp(r_no))), 1e-3)
})
