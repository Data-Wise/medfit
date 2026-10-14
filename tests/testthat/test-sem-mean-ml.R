# Mean structure in the RAM core (0.9.0 S1): intercepts as the `m` vector, the mean term of F, its gradient
# and the additive mean term of the information (GRILL G1).

mean_model <- function() {
  # X -> M -> Y with the direct path, intercepts on M and Y, the exogenous mean of X free
  sem_model_obs <- .sem_ram(
    vars = c("X", "M", "Y"), obs = c("X", "M", "Y"),
    a = sem_rows(list("M", "X"), list("Y", "M"), list("Y", "X")), # nolint: object_usage_linter.
    s = sem_rows(list("X", "X"), list("M", "M"), list("Y", "Y")), # nolint: object_usage_linter.
    m = data.frame(row = c("X", "M", "Y"), label = "", value = NA_real_, name = c("X~1", "M~1", "Y~1"),
                   stringsAsFactors = FALSE)
  )
  sem_obs_data <- function(n = 300, seed = 11) {
    set.seed(seed)
    x <- stats::rnorm(n, 2, 1)
    m <- 1 + 0.5 * x + stats::rnorm(n, 0, 0.9)
    y <- -1 + 0.4 * m + 0.2 * x + stats::rnorm(n, 0, 0.8)
    data.frame(X = x, M = m, Y = y)
  }
  list(ram = sem_model_obs, data = sem_obs_data())
}

test_that("the RAM carries the intercept vector and the flag", {
  mm <- mean_model()
  expect_true(mm$ram$has_mean)
  expect_equal(mm$ram$q, 3 + 3 + 3)
  expect_true(all(c("X~1", "M~1", "Y~1") %in% mm$ram$par_names))
  cov_only <- .sem_ram(c("X", "M"), c("X", "M"), sem_rows(list("M", "X")), sem_rows(list("X", "X"), list("M", "M")))
  expect_false(cov_only$has_mean)
})

test_that("the analytic gradient with a mean structure equals central differences off the optimum", {
  mm <- mean_model()
  smp <- .sem_sample(mm$data, mm$ram)
  expect_true(smp$has_mean)
  theta <- stats::setNames(c(0.3, 0.2, 0.1, 1.1, 0.9, 0.8, 0.4, -0.2, 0.5), mm$ram$par_names)
  # at this theta d = xbar - mu is far from zero, where a gradient missing dmu/dA is visible
  d <- smp$xbar - .sem_implied_mean(mm$ram, theta)
  expect_gt(max(abs(d)), 0.5)
  analytic <- .sem_grad(theta, mm$ram, smp)
  fd <- sem_fd_grad(function(th) .sem_fml(th, mm$ram, smp), theta)
  expect_lt(max(abs(analytic - fd)), 1e-5)
})

test_that("the expected information is n/2 times the Hessian of F at exact-fit moments", {
  mm <- mean_model()
  theta <- stats::setNames(c(0.5, 0.4, 0.2, 1, 0.8, 0.7, 2, 0, -1.4), mm$ram$par_names)
  sigma <- .sem_implied(mm$ram, theta)
  mu <- .sem_implied_mean(mm$ram, theta)
  smp <- list(s = sigma, n = 300L, p = 3L, logdet = .sem_logdet(sigma), has_mean = TRUE, xbar = unname(mu))
  info <- .sem_info_expected(theta, mm$ram, smp)
  hess <- .sem_hess_f(theta, mm$ram, smp)
  expect_lt(max(abs(info - smp$n / 2 * hess)) / max(abs(info)), 1e-6)
})

test_that("planted defect: dropping dmu/dA from the mean term makes the gradient wrong", {
  mm <- mean_model()
  smp <- .sem_sample(mm$data, mm$ram)
  theta <- stats::setNames(c(0.3, 0.2, 0.1, 1.1, 0.9, 0.8, 0.4, -0.2, 0.5), mm$ram$par_names)
  broken <- sem_mutate(.sem_eval, "vals[seq_along(ram$pos_a)] - 2 * sbo[r] * bm[cc]", "vals[seq_along(ram$pos_a)]")
  g <- broken(theta, mm$ram, smp, deriv = TRUE)$g
  fd <- sem_fd_grad(function(th) .sem_fml(th, mm$ram, smp), theta)
  expect_gt(max(abs(g - fd)), 1e-3)
})

test_that("planted defect: an information without the mean term is wrong", {
  mm <- mean_model()
  theta <- stats::setNames(c(0.5, 0.4, 0.2, 1, 0.8, 0.7, 2, 0, -1.4), mm$ram$par_names)
  sigma <- .sem_implied(mm$ram, theta)
  smp <- list(s = sigma, n = 300L, p = 3L, logdet = .sem_logdet(sigma), has_mean = TRUE,
              xbar = unname(.sem_implied_mean(mm$ram, theta)))
  no_mean <- sem_mutate(.sem_info_expected, "info <- info + smp$n * crossprod(dmu, sigma_inv %*% dmu)", "NULL")
  expect_gt(max(abs(no_mean(theta, mm$ram, smp) - .sem_info_expected(theta, mm$ram, smp))), 1)
})
