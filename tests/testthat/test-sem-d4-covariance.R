# Independent Gaussian likelihood with a*b = 0.4 and a negative: a = -exp(t), b = 0.4/a.
.d4_jacobian <- function(f, p) {
  h <- 1e-5 * pmax(1, abs(p))
  sapply(seq_along(p), function(i) {
    up <- dn <- p
    up[i] <- up[i] + h[i]
    dn[i] <- dn[i] - h[i]
    (f(up) - f(dn)) / (2 * h[i])
  })
}

test_that("weighted mean-structure covariance matches an independent constrained likelihood", {
  set.seed(3)
  n <- 300
  x <- stats::rnorm(n) + 2
  m <- 0.5 * x + stats::rnorm(n, sd = 0.8) + 1
  y <- 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7) - 1
  data <- data.frame(X = x, M = m, Y = y)
  w <- seq(0.5, 1.5, length.out = n)
  model <- "M ~ a*X\nY ~ b*M + cp*X\na < 0\nb < 0\na*b == 0.4"
  fit <- suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = TRUE, weights = w,
                                  se_type = "sandwich"))
  th <- coef(fit)
  expected_names <- c("a", "b", "cp", "M~~M", "Y~~Y", "X~~X", "M~1", "X~1", "Y~1")
  expect_setequal(names(th), expected_names)
  expect_length(th, length(expected_names))
  expect_identical(names(th), expected_names)
  expect_identical(dimnames(vcov(fit)), list(expected_names, expected_names))
  p <- c(log(-th[["a"]]), th[["cp"]], log(th[["M~~M"]]), log(th[["Y~~Y"]]), log(th[["X~~X"]]),
         th[["M~1"]], th[["X~1"]], th[["Y~1"]])
  unpack <- function(p) c(a = -exp(p[1]), b = 0.4 / (-exp(p[1])), cp = p[2], exp(p[3:5]), p[6:8])
  case <- function(p) {
    q <- unpack(p)
    w * ((x - q[8])^2 / (2 * q[6]) + log(q[6]) / 2 +
           (m - q[7] - q[1] * x)^2 / (2 * q[4]) + log(q[4]) / 2 +
           (y - q[9] - q[2] * m - q[3] * x)^2 / (2 * q[5]) + log(q[5]) / 2)
  }
  independent <- stats::optim(p + seq(-0.01, 0.01, length.out = length(p)), function(p) sum(case(p)),
                              method = "BFGS", control = list(reltol = 1e-12, maxit = 2000))
  expect_identical(independent$convergence, 0L)
  expect_equal(unname(unpack(independent$par)), unname(th), tolerance = 2e-5)
  j <- .d4_jacobian(unpack, p)
  h <- stats::optimHess(p, function(p) sum(case(p)))
  inv <- solve(h)
  score <- .d4_jacobian(case, p)
  oracle <- j %*% inv %*% t(j)
  oracle_sand <- j %*% inv %*% crossprod(score) %*% inv %*% t(j)
  expect_equal(unname(vcov(fit)), unname(oracle_sand), tolerance = 2e-5)
  model_fit <- suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = TRUE, weights = w))
  expect_equal(unname(vcov(model_fit)), unname(oracle), tolerance = 2e-5)
  moments <- function(p) {
    q <- unpack(p)
    t <- rbind(c(1, 0, 0), c(q[1], 1, 0), c(q[2] * q[1] + q[3], q[2], 1))
    sigma <- t %*% diag(q[c(6, 4, 5)]) %*% t(t)
    mu <- c(q[8], q[7] + q[1] * q[8], q[9] + q[2] * (q[7] + q[1] * q[8]) + q[3] * q[8])
    c(mu, as.vector(sigma))
  }
  mm <- moments(p)
  dm <- .d4_jacobian(moments, p)
  si <- solve(matrix(mm[4:12], 3, 3))
  fisher <- matrix(0, length(p), length(p))
  for (i in seq_along(p)) for (k in seq_along(p)) {
    fisher[i, k] <- n * (drop(crossprod(dm[1:3, i], si %*% dm[1:3, k])) +
                           sum(diag(si %*% matrix(dm[4:12, i], 3, 3) %*% si %*% matrix(dm[4:12, k], 3, 3))) / 2)
  }
  expected_fit <- suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = TRUE, weights = w,
                                           information = "expected"))
  expect_equal(unname(vcov(expected_fit)), unname(j %*% solve(fisher) %*% t(j)), tolerance = 2e-5)
  expected_sand <- suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = TRUE, weights = w,
                                            information = "expected", se_type = "sandwich"))
  fisher_inv <- solve(fisher)
  expect_equal(unname(vcov(expected_sand)),
               unname(j %*% fisher_inv %*% crossprod(score) %*% fisher_inv %*% t(j)), tolerance = 2e-5)
  # Equation order is irrelevant; compare every named row after restoring its order.
  reordered_model <- "Y ~ b*M + cp*X\nM ~ a*X\na < 0\nb < 0\na*b == 0.4"
  reordered <- suppressWarnings(fit_sem(reordered_model, data, fixed_x = FALSE, meanstructure = TRUE,
                                        weights = w, se_type = "sandwich"))
  expect_setequal(names(coef(reordered)), expected_names)
  expect_length(coef(reordered), length(expected_names))
  expect_equal(coef(reordered)[expected_names], th, tolerance = 2e-5)
  expect_equal(vcov(reordered)[expected_names, expected_names], vcov(fit), tolerance = 2e-5)
  # Substituting observed for expected information must miss the Fisher oracle.
  local({
    local_mocked_bindings(.sem_info_expected = .sem_info_observed)
    wrong <- tryCatch(suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = TRUE, weights = w,
                                               information = "expected")), error = identity)
    expect_s3_class(wrong, "medfit_sem_covariance_error")
    expect_identical(wrong$ledger$post_fit$condition$kind, "information_not_pd")
  })
  # The oracle has a nonzero curvature contribution: removing it must be detected.
  real <- .sem_lagrangian_hessian
  local_mocked_bindings(.sem_lagrangian_hessian = function(hx, ...) {
    if (any(vapply(sys.calls(), function(cl) identical(cl[[1L]], quote(.sem_vcov)), TRUE))) hx else real(hx, ...)
  })
  mutant <- tryCatch(suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = TRUE, weights = w)),
                     error = identity)
  expect_s3_class(mutant, "medfit_sem_covariance_error")
  expect_identical(mutant$ledger$post_fit$condition$kind, "information_not_pd")
})


test_that("inactive constraints preserve covariance and active inequality matches its tangent equality", {
  set.seed(3)
  x <- stats::rnorm(300)
  m <- 0.5 * x + stats::rnorm(300, sd = 0.8)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(300, sd = 0.7)
  data <- data.frame(X = x, M = m, Y = y)
  base <- "M ~ a*X\nY ~ b*M + cp*X"
  free <- fit_sem(base, data, fixed_x = FALSE)
  inactive <- fit_sem(paste(base, "a*b > -10", sep = "\n"), data, fixed_x = FALSE)
  expect_equal(coef(inactive), coef(free), tolerance = 1e-5)
  expect_equal(vcov(inactive), vcov(free), tolerance = 1e-5)
  boundary <- suppressWarnings(fit_sem(paste(base, "a*b > 0.4", sep = "\n"), data, fixed_x = FALSE))
  equality <- suppressWarnings(fit_sem(paste(base, "a > 0", "b > 0", "a*b == 0.4", sep = "\n"),
                                       data, fixed_x = FALSE))
  expect_gt(length(boundary@diagnostics$active_constraints), 0L)
  expect_equal(coef(boundary), coef(equality), tolerance = 1e-5)
  expect_equal(vcov(boundary), vcov(equality), tolerance = 1e-5)
  for (f in list(free, inactive, boundary, equality)) {
    expect_setequal(names(coef(f)), names(coef(free)))
    expect_length(coef(f), length(coef(free)))
    expect_identical(dimnames(vcov(f)), list(names(coef(f)), names(coef(f))))
  }
  # Removing the active set from covariance must destroy agreement with the equality tangent.
  real <- .sem_vcov
  local_mocked_bindings(.sem_vcov = function(theta, ram, smp, information, cons, lb, ub, se_type) {
    real(theta, ram, smp, information, NULL, lb, ub, se_type)
  })
  wrong <- suppressWarnings(fit_sem(paste(base, "a*b > 0.4", sep = "\n"), data, fixed_x = FALSE))
  expect_gt(max(abs(vcov(wrong) - vcov(equality))), 1e-4)
})
