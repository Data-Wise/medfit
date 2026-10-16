# Scale robustness of the mean structure (0.9.0 S2, GRILL G9): with distant means (mean/sd of 100 or more) the
# gate and the information are built in centered coordinates, so the fit is accepted and the standard errors
# match an independent OLS oracle at any location.

scale_data <- function(mu, n = 300, seed = 3) {
  set.seed(seed)
  x <- stats::rnorm(n, mu, 1)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(n)
  data.frame(x = x, m = m, y = y)
}
scale_syntax <- "m ~ a*x\ny ~ b*m + cp*x\ny ~ 1"

# ML SE of an OLS coefficient: the OLS SE times sqrt((n - k) / n), k the number of coefficients of the equation.
ols_se <- function(formula, d) {
  fit <- stats::lm(formula, d)
  summary(fit)$coefficients[, 2] * sqrt((nrow(d) - length(stats::coef(fit))) / nrow(d))
}

test_that("fits are accepted with SEs equal to the OLS oracle from mean/sd 0 to 1e5", {
  for (mu in c(0, 1e2, 1e3, 1e5)) {
    d <- scale_data(mu)
    fit <- fit_sem(scale_syntax, d)
    se <- sqrt(diag(fit@vcov))
    expect_true(fit@converged, info = mu)
    expect_false(anyNA(fit@vcov), info = mu)
    om <- ols_se(m ~ x, d)
    oy <- ols_se(y ~ m + x, d)
    expect_equal(unname(se["a"]), unname(om["x"]), tolerance = 1e-3, info = paste("a", mu))
    expect_equal(unname(se["b"]), unname(oy["m"]), tolerance = 1e-3, info = paste("b", mu))
    expect_equal(unname(se["cp"]), unname(oy["x"]), tolerance = 1e-3, info = paste("cp", mu))
    expect_equal(unname(se["y~1"]), unname(oy["(Intercept)"]), tolerance = 1e-3, info = paste("y~1", mu))
    expect_equal(unname(fit@theta["b"]), unname(stats::coef(stats::lm(y ~ m + x, d))["m"]), tolerance = 1e-5,
                 info = mu)
  }
})

test_that("expected information gives the same standard errors at a distant mean", {
  d <- scale_data(1e3)
  obs <- fit_sem(scale_syntax, d)
  exp <- fit_sem(scale_syntax, d, information = "expected")
  expect_false(anyNA(exp@vcov))
  expect_equal(sqrt(diag(exp@vcov)), sqrt(diag(obs@vcov)), tolerance = 1e-3)
})

test_that("a restricted intercept is fitted at a moderate mean, where the restriction is well conditioned", {
  # Regressing through the origin on predictors with large means is nearly collinear whatever the coordinates, so
  # the distant-mean guarantee is for free intercepts; a fixed intercept is checked where it is identified.
  for (mu in c(0, 10)) {
    d <- scale_data(mu)
    fit <- fit_sem("m ~ a*x\ny ~ b*m + cp*x\ny ~ 0*1", d)
    expect_true(fit@converged, info = mu)
    expect_false(anyNA(fit@vcov), info = mu)
    expect_identical(fit@df, 1)
  }
})

test_that("the centered coordinates are an exact affine map", {
  d <- scale_data(50)
  fit <- fit_sem(scale_syntax, d)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  ctr <- .sem_center_map(ram, smp)
  phi <- .sem_to_phi(fit@theta, ctr)
  expect_equal(as.vector(ctr$t %*% phi + ctr$c0), unname(fit@theta), tolerance = 1e-10)
  # at the optimum the centered intercepts are about zero, not about the data mean
  expect_lt(max(abs(phi[ram$k_m])), 0.2)
  # the centered Hessian maps back to the plain one, H_theta = T^-T H_phi T^-1 (at moderate scale, where both are
  # accurate)
  h_phi <- .sem_hess_f_phi(fit@theta, ram, smp, ctr)
  h <- .sem_hess_f(fit@theta, ram, smp)
  tinv <- solve(ctr$t)
  expect_lt(max(abs(crossprod(tinv, h_phi %*% tinv) - h)) / max(abs(h)), 1e-4)
  expect_null(.sem_center_map(.sem_ram(c("x", "m"), c("x", "m"), sem_rows(list("m", "x")),
                                       sem_rows(list("x", "x"), list("m", "m"))), smp))
})

test_that("planted defect: a gate without the centered Hessian rejects a fit at mean/sd 100", {
  d <- scale_data(100)
  plain <- sem_mutate(.sem_gate, "ctr <- .sem_center_map(ram, smp)", "ctr <- NULL")
  fit <- fit_sem(scale_syntax, d)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  ok <- .sem_gate(fit@theta, 1L, ram, smp, rep(-Inf, ram$q), rep(Inf, ram$q))
  bad <- plain(fit@theta, 1L, ram, smp, rep(-Inf, ram$q), rep(Inf, ram$q))
  expect_true(ok$accepted)
  expect_false(bad$accepted)
  expect_match(bad$reason, "nearly singular")
})

test_that("planted defect: an information without the centered path columns turns SEs to NA at mean/sd 5000", {
  d <- scale_data(5e3)
  fit <- fit_sem(scale_syntax, d)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  plain <- .sem_info_observed(fit@theta, ram, smp)
  expect_null(.sem_invert_info(plain))
  ctr <- .sem_center_map(ram, smp)
  expect_false(is.null(.sem_invert_info(.sem_info_observed(fit@theta, ram, smp, ctr))))
})
