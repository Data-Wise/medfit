# Native SEM RAM core: ML discrepancy, analytic gradient, sentinel (plan S3).
#
# Oracles: a central-difference gradient computed here; closed-form lm()
# coefficients on a saturated path model; lavaan's fmin (half the ML
# discrepancy) at lavaan's own estimates. Each planted defect rebuilds an
# internal function with one change and must make its check fail.

test_that("analytic gradient matches a central difference on all four structures", {
  for (nm in names(sem_models())) {
    mod <- sem_models()[[nm]]
    smp <- .sem_sample(sem_sim(mod, 300, 11), mod$ram)
    # Away from the optimum, so every gradient entry is nonzero.
    theta <- mod$theta * 1.15 + 0.03
    g_fd <- sem_fd_grad(function(x) .sem_fml(x, mod$ram, smp), theta)
    g_an <- .sem_grad(theta, mod$ram, smp)
    expect_lt(max(abs(g_an - g_fd)), 1e-8, label = paste("max gradient difference,", nm))
    expect_gt(max(abs(g_an)), 1e-3, label = paste("gradient is nonzero,", nm))
  }
})

test_that("a shared label gives one parameter and an accumulated gradient", {
  a <- sem_rows(list("Y", "X1", "b"), list("Y", "X2", "b"))
  s <- sem_rows(list("X1", "X1"), list("X2", "X2"), list("X1", "X2"), list("Y", "Y"))
  ram <- .sem_ram(c("X1", "X2", "Y"), c("X1", "X2", "Y"), a, s)
  expect_equal(ram$q, 5)
  expect_identical(ram$par_names[1], "b")
  set.seed(2)
  d <- as.data.frame(MASS::mvrnorm(200, c(0, 0, 0), diag(3) + .3))
  names(d) <- c("X1", "X2", "Y")
  smp <- .sem_sample(d, ram)
  theta <- c(.4, 1.1, 1.2, .2, .9)
  g_fd <- sem_fd_grad(function(x) .sem_fml(x, ram, smp), theta)
  expect_lt(max(abs(.sem_grad(theta, ram, smp) - g_fd)), 1e-8)
})

test_that("a saturated observed path model reproduces lm() coefficients and RSS/n", {
  mod <- sem_model_observed()
  d <- sem_sim(mod, 250, 5)
  smp <- .sem_sample(d, mod$ram)
  fit <- stats::nlminb(sem_start(mod$ram),
                       function(x) .sem_fml(x, mod$ram, smp),
                       function(x) .sem_grad(x, mod$ram, smp),
                       control = list(rel.tol = 1e-14, x.tol = 1e-12, iter.max = 500))
  est <- stats::setNames(fit$par, mod$ram$par_names)
  m <- stats::lm(M ~ X + C, d)
  y <- stats::lm(Y ~ M + X + C, d)
  expect_equal(unname(est[c("M ~ X", "M ~ C")]), unname(stats::coef(m)[c("X", "C")]), tolerance = 1e-8)
  expect_equal(unname(est[c("Y ~ M", "Y ~ X", "Y ~ C")]), unname(stats::coef(y)[c("M", "X", "C")]), tolerance = 1e-8)
  expect_equal(unname(est["M ~~ M"]), sum(stats::resid(m)^2) / nrow(d), tolerance = 1e-8)
  expect_equal(unname(est["Y ~~ Y"]), sum(stats::resid(y)^2) / nrow(d), tolerance = 1e-8)
  expect_lt(fit$objective, 1e-10)
})

test_that(".sem_fml equals twice lavaan's fmin at lavaan's estimates", {
  skip_if_not_installed("lavaan")
  for (nm in names(sem_models())) {
    mod <- sem_models()[[nm]]
    d <- sem_sim(mod, 400, 21)
    fit <- suppressWarnings(lavaan::sem(sem_lavaan_text(nm), d, fixed.x = FALSE))
    lav <- lavaan::coef(fit)
    # lavaan names a symmetric pair in its own order, so match on the sorted pair.
    norm <- function(x) {
      vapply(strsplit(x, "~~", fixed = TRUE), function(p) {
        if (length(p) == 2) paste(sort(p), collapse = "~~") else p
      }, character(1))
    }
    lname <- norm(sem_lavaan_names(mod$ram$par_names, mod$loadings))
    theta <- unname(lav[match(lname, norm(names(lav)))])
    expect_false(anyNA(theta), label = paste("parameter names map to lavaan,", nm))
    smp <- .sem_sample(d, mod$ram)
    expect_equal(.sem_fml(theta, mod$ram, smp),
                 2 * unname(lavaan::fitMeasures(fit, "fmin")), tolerance = 1e-8, label = nm)
  }
})

test_that("a non-positive-definite implied covariance gives the sentinel and a finite gradient", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 3), mod$ram)
  bad <- mod$theta
  bad["X ~~ X"] <- -0.5
  expect_identical(.sem_fml(bad, mod$ram, smp), 1e10)
  g <- expect_no_error(.sem_grad(bad, mod$ram, smp))
  expect_true(all(is.finite(g)))
  expect_length(g, mod$ram$q)
  expect_identical(g, numeric(mod$ram$q))
  # An exactly singular implied covariance (zero variance) is also unusable.
  zero <- mod$theta
  zero["X ~~ X"] <- 0
  zero["X ~~ C"] <- 0
  expect_identical(.sem_fml(zero, mod$ram, smp), 1e10)
})

test_that("a singular I - A gives the sentinel instead of an error", {
  a <- sem_rows(list("M", "Y", "g"), list("Y", "M", "h"))
  s <- sem_rows(list("M", "M"), list("Y", "Y"))
  ram <- .sem_ram(c("M", "Y"), c("M", "Y"), a, s)
  smp <- .sem_sample(data.frame(M = c(1, 2, 3, 5), Y = c(2, 1, 4, 3)), ram)
  # g * h = 1 makes I - A singular.
  expect_identical(.sem_fml(c(1, 1, 1, 1), ram, smp), 1e10)
})

test_that("a singular sample covariance errors by name", {
  mod <- sem_model_observed()
  d <- as.data.frame(matrix(rnorm(12), 3, 4, dimnames = list(NULL, c("X", "C", "M", "Y"))))
  expect_error(.sem_sample(d, mod$ram), "sample covariance matrix is singular \\(n = 3, p = 4\\)")
  d2 <- sem_sim(mod, 50, 1)
  d2$C <- d2$X
  expect_error(.sem_sample(d2, mod$ram), "sample covariance matrix is singular \\(n = 50, p = 4\\)")
})

test_that("the sample covariance uses divisor n", {
  mod <- sem_model_observed()
  d <- sem_sim(mod, 40, 4)
  smp <- .sem_sample(d, mod$ram)
  expect_equal(unname(smp$s["X", "X"]), sum((d$X - mean(d$X))^2) / 40, tolerance = 1e-12)
})

test_that("planted defects are caught", {
  mod <- sem_model_observed()
  d <- sem_sim(mod, 300, 11)
  smp <- .sem_sample(d, mod$ram)
  theta <- mod$theta * 1.15 + 0.03
  g_fd <- sem_fd_grad(function(x) .sem_fml(x, mod$ram, smp), theta)
  gap <- function(grad_fn) {
    max(abs(grad_fn(theta, mod$ram, smp) - g_fd))
  }
  expect_lt(gap(.sem_grad), 1e-8)

  # (1) Drop the factor 2 on symmetric S entries: the gradient check fails.
  bad_eval <- sem_mutate(.sem_eval, "ram$s_weight * g_s[ram$pos_s]", "g_s[ram$pos_s]")
  bad_grad <- function(theta, ram, smp) {
    local_mocked_bindings(.sem_eval = bad_eval)
    .sem_grad(theta, ram, smp)
  }
  expect_gt(gap(bad_grad), 1e-3)

  # (2) Divisor n - 1 for S: the variance known-answer fails by (n - 1) / n.
  bad_sample <- sem_mutate(.sem_sample, "stats::cov(x) * (n - 1)/n", "stats::cov(x)")
  s_bad <- bad_sample(d, mod$ram)
  expect_equal(unname(s_bad$s["X", "X"] / smp$s["X", "X"]), 300 / 299, tolerance = 1e-12)

  # (3) Return Inf instead of the sentinel: a non-finite objective reaches the optimizer.
  local({
    local_mocked_bindings(.sem_sentinel = Inf)
    bad <- mod$theta
    bad["X ~~ X"] <- -0.5
    expect_false(is.finite(.sem_fml(bad, mod$ram, smp)))
  })
  bad <- mod$theta
  bad["X ~~ X"] <- -0.5
  expect_true(is.finite(.sem_fml(bad, mod$ram, smp)))

  # (4) Remove the positive-definiteness guard: an indefinite start now errors.
  no_guard <- sem_mutate(.sem_eval, "<= .sem_pd_floor", "<= -Inf")
  expect_error(no_guard(bad, mod$ram, smp, deriv = TRUE), "leading minor")
  expect_no_error(.sem_eval(bad, mod$ram, smp, deriv = TRUE))
})
