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

# Independent conditional-normal likelihood with the solver floor treated as a fixed variance.
# Solve the standardized row for a; all derivatives below are in log-variance/log-b coordinates.
.d4_floor_oracle <- function(fit, data, q, information, se_type) {
  th <- coef(fit)
  n <- nrow(data)
  x <- data$X - mean(data$X)
  m <- data$M - mean(data$M)
  y <- data$Y - mean(data$Y)
  floor_y <- 1e-4 * mean(y^2)
  p <- c(log(th[["Vm"]]), log(th[["b"]]), th[["cp"]], log(th[["X~~X"]]))
  unpack <- function(p) {
    vm <- exp(p[1])
    b <- exp(p[2])
    c(a = q * sqrt(2 * (b^2 * vm + floor_y)) / b, cp = p[3], b = b,
      Vm = vm, Vy = floor_y, "X~~X" = exp(p[4]))
  }
  case <- function(p) {
    z <- unpack(p)
    x^2 / (2 * z[6]) + log(z[6]) / 2 + (m - z[1] * x)^2 / (2 * z[4]) + log(z[4]) / 2 +
      (y - z[2] * x - z[3] * m)^2 / (2 * z[5]) + log(z[5]) / 2
  }
  j <- numDeriv::jacobian(unpack, p)
  if (information == "observed") {
    info <- numDeriv::hessian(function(p) sum(case(p)), p)
  } else {
    g <- function(i) j[i, , drop = FALSE]
    info <- n * (th[6] / th[4] * crossprod(g(1)) + crossprod(g(4)) / (2 * th[4]^2) +
                   (th[4] + th[1]^2 * th[6]) / th[5] * crossprod(g(3)) +
                   th[6] / th[5] * crossprod(g(2)) +
                   th[1] * th[6] / th[5] * (crossprod(g(3), g(2)) + crossprod(g(2), g(3))) +
                   crossprod(g(6)) / (2 * th[6]^2))
  }
  bread <- solve(info)
  v <- if (se_type == "model") {
    j %*% bread %*% t(j)
  } else {
    scores <- numDeriv::jacobian(case, p)
    j %*% bread %*% crossprod(scores) %*% bread %*% t(j)
  }
  dimnames(v) <- list(names(unpack(p)), names(unpack(p)))
  v
}

test_that("an active solver variance floor is pinned in the covariance at extreme scales", {
  skip_if_not_installed("numDeriv")
  set.seed(7)
  n <- 250
  x <- stats::rbinom(n, 1, 0.5)
  m <- 1e3 * stats::rnorm(n)
  y <- 0.3 * x + 1e-3 * m + 1e-3 * stats::rnorm(n)
  data <- data.frame(X = x, M = m, Y = y)
  ma <- stats::lm(m ~ x)
  ya <- stats::lm(y ~ x + m)
  a <- unname(stats::coef(ma)[2])
  b <- unname(stats::coef(ya)[3])
  vm <- mean(stats::residuals(ma)^2)
  vy <- mean(stats::residuals(ya)^2)
  q <- a * b / sqrt(2 * (b^2 * vm + vy))
  model <- paste0("M ~ a*X\nY ~ cp*X + b*M\nM ~~ Vm*M\nY ~~ Vy*Y\n",
                  "a*b/sqrt(2*(b^2*Vm+Vy)) == ", format(q, digits = 17))
  fit <- suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = NULL))
  expect_true("Vy" %in% fit@diagnostics$active_bounds)
  expect_identical(unname(vcov(fit)["Vy", ]), rep(0, length(coef(fit))))
  expect_identical(unname(vcov(fit)[, "Vy"]), rep(0, length(coef(fit))))
  for (info in c("observed", "expected")) for (se in c("model", "sandwich")) {
    other <- suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = NULL,
                                      information = info, se_type = se))
    expect_true("Vy" %in% other@diagnostics$active_bounds)
    expected_names <- c("a", "cp", "b", "Vm", "Vy", "X~~X")
    oracle <- .d4_floor_oracle(other, data, q, info, se)
    expect_setequal(names(coef(other)), expected_names)
    expect_length(coef(other), length(expected_names))
    expect_identical(dimnames(vcov(other)), list(expected_names, expected_names))
    expect_identical(dimnames(oracle), list(expected_names, expected_names))
    expect_identical(unname(vcov(other)["Vy", ]), rep(0, length(expected_names)))
    expect_identical(unname(vcov(other)[, "Vy"]), rep(0, length(expected_names)))
    free <- setdiff(expected_names, "Vy")
    scale <- sqrt(diag(oracle)[free])
    # Normalize each covariance by its marginal SDs; Vm and b differ by 18 variance orders.
    gap <- max(abs((vcov(other)[free, free] - oracle[free, free]) / outer(scale, scale)))
    expect_lt(gap, if (info == "observed") 3e-4 else 1e-7)
    expect_true(all(is.finite(vcov(other))))
  }
  branch_model <- paste0("M ~ a*X\nY ~ cp*X + b*M\nM ~~ Vm*M\nY ~~ Vy*Y\n",
                         "a*b/sqrt(2*(b^2*Vm+Vy)) == 0\na*b == 0")
  branch <- suppressWarnings(fit_sem(branch_model, data, fixed_x = FALSE, meanstructure = NULL))
  expect_identical(branch@diagnostics$ledger$branch_map$raw_count, 2L)
  expect_true("Vy" %in% branch@diagnostics$active_bounds)
  expect_identical(unname(vcov(branch)["Vy", ]), rep(0, length(coef(branch))))
  for (info in c("observed", "expected")) for (se in c("model", "sandwich")) {
    other <- suppressWarnings(fit_sem(branch_model, data, fixed_x = FALSE, meanstructure = NULL,
                                      information = info, se_type = se))
    oracle <- .d4_floor_oracle(other, data, 0, info, se)
    expect_setequal(names(coef(other)), c("a", "cp", "b", "Vm", "Vy", "X~~X"))
    expect_length(coef(other), 6L)
    expect_identical(dimnames(vcov(other)), dimnames(oracle))
    for (pinned in c("a", "Vy")) {
      expect_identical(unname(vcov(other)[pinned, ]), rep(0, 6))
      expect_identical(unname(vcov(other)[, pinned]), rep(0, 6))
    }
    free <- setdiff(names(coef(other)), c("a", "Vy"))
    scale <- sqrt(diag(oracle)[free])
    expect_lt(max(abs((vcov(other)[free, free] - oracle[free, free]) / outer(scale, scale))), 3e-4)
    expect_true(all(is.finite(vcov(other))))
  }
  reversed <- sub("M ~ a*X\nY ~ cp*X + b*M", "Y ~ cp*X + b*M\nM ~ a*X", model, fixed = TRUE)
  expect_false(identical(reversed, model))
  reordered <- suppressWarnings(fit_sem(reversed, data, fixed_x = FALSE, meanstructure = NULL))
  expect_setequal(names(coef(reordered)), names(coef(fit)))
  expect_length(coef(reordered), length(coef(fit)))
  expect_equal(vcov(reordered)[names(coef(fit)), names(coef(fit))], vcov(fit), tolerance = 1e-6)
  free <- setdiff(names(coef(fit)), "Vy")
  scale <- sqrt(diag(vcov(fit))[free])
  expect_lt(max(abs((vcov(reordered)[free, free] - vcov(fit)[free, free]) / outer(scale, scale))), 3e-4)
  # Dropping the optimizer's floor from the covariance active set revives the diagnosed failure.
  optimize <- .sem_optimize
  local_mocked_bindings(.sem_optimize = function(...) {
    out <- optimize(...)
    out$effective_lower[] <- -Inf
    out
  })
  mutant <- tryCatch(suppressWarnings(fit_sem(model, data, fixed_x = FALSE, meanstructure = NULL)), error = identity)
  expect_s3_class(mutant, "medfit_sem_covariance_error")
  expect_identical(mutant$ledger$post_fit$condition$kind, "information_not_pd")
})


test_that("the nonlinear gate Hessian uses the independently parameterized Gaussian likelihood", {
  skip_if_not_installed("numDeriv")
  expressions <- parse(test_path("..", "sim", "sem-nonlinear-gate.R"))
  target <- Filter(function(e) {
    is.call(e) && identical(e[[1]], quote(`<-`)) && identical(e[[2]], quote(reparam))
  }, expressions)
  expect_length(target, 1L)
  oracle_env <- new.env(parent = environment())
  eval(target[[1]], envir = oracle_env)
  set.seed(1)
  n <- 300
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n, sd = 0.8)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7)
  data <- data.frame(X = x, M = m, Y = y)
  fit <- fit_sem("M ~ a*X\nY ~ b*M + cp*X\ncp == a*b", data, fixed_x = FALSE, meanstructure = NULL)
  th <- coef(fit)
  ram <- fit@internals$ram
  smp <- .sem_sample(data, ram)
  solved <- list(target = "cp", fn = function(th) th[["a"]] * th[["b"]])
  ref <- oracle_env$reparam(th, ram, smp, solved)
  p <- c(th[["a"]], th[["b"]], log(th[["M~~M"]]), log(th[["Y~~Y"]]), log(th[["X~~X"]]))
  unpack <- function(p) {
    c(a = p[1], b = p[2], cp = p[1] * p[2],
      "M~~M" = exp(p[3]), "Y~~Y" = exp(p[4]), "X~~X" = exp(p[5]))
  }
  x <- x - mean(x)
  m <- m - mean(m)
  y <- y - mean(y)
  nll <- function(p) {
    z <- unpack(p)
    sum(x^2) / (2 * z[6]) + n * log(z[6]) / 2 +
      sum((m - z[1] * x)^2) / (2 * z[4]) + n * log(z[4]) / 2 +
      sum((y - z[2] * m - z[3] * x)^2) / (2 * z[5]) + n * log(z[5]) / 2
  }
  independent <- stats::optim(p, nll, method = "BFGS", control = list(reltol = 1e-13, maxit = 2000))
  j <- numDeriv::jacobian(unpack, independent$par)
  v <- j %*% solve(numDeriv::hessian(nll, independent$par)) %*% t(j)
  expected_names <- c("a", "b", "cp", "M~~M", "Y~~Y", "X~~X")
  for (values in list(th, ref$theta, ref$se, unpack(independent$par))) {
    expect_setequal(names(values), expected_names)
    expect_length(values, length(expected_names))
    expect_identical(names(values), expected_names)
  }
  expect_identical(independent$convergence, 0L)
  expect_equal(ref$theta, unpack(independent$par), tolerance = 1e-5)
  expect_lt(max(abs(ref$se / sqrt(diag(v)) - 1)), 2e-5)
  # G' I G omits curvature from solving cp=a*b and must miss this independent SE oracle.
  wrong <- sem_mutate(oracle_env$reparam, "hessian <- stats::optimHess(opt$par, nll)",
                      "hessian <- crossprod(g, .sem_info_observed(unname(th2), ram, smp) %*% g)")
  ambient <- wrong(th, ram, smp, solved)
  expect_gt(max(abs(ambient$se / sqrt(diag(v)) - 1)), 1e-3)
})
