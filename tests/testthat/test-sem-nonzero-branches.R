test_that("nonzero products classify only independent two-label equalities", {
  ram <- list(par_names = c("a", "b", "v"))
  cons <- data.frame(lhs = "-2*a*b", op = "==", rhs = "0.8")
  spec <- .sem_nonzero_product(cons, ram)
  expect_true(spec$supported)
  expect_equal(spec$ratio, -0.4)
  expect_identical(spec$labels, c("a", "b"))
  for (lhs in c("a*a", "a+b", "a*b*v")) {
    cons$lhs <- lhs
    expect_false(.sem_nonzero_product(cons, ram)$supported)
  }
})

.nz_data <- function() {
  set.seed(3)
  x <- stats::rnorm(180) + 2
  m <- 0.5 * x + stats::rnorm(180, sd = 0.8) + 1
  y <- 0.4 * m + 0.2 * x + stats::rnorm(180, sd = 0.7) - 1
  data.frame(X = x, M = m, Y = y)
}

test_that("both signs match an independently profiled Gaussian likelihood with weights and means", {
  data <- .nz_data()
  w <- seq(0.5, 1.5, length.out = nrow(data))
  centered <- sweep(as.matrix(data), 2L, colSums(w * as.matrix(data)) / sum(w))
  x <- centered[, "X"]
  m <- centered[, "M"]
  y <- centered[, "Y"]
  nll <- function(t, sign, q) {
    a <- sign * exp(t)
    b <- q / a
    cp <- sum(w * x * (y - b * m)) / sum(w * x^2)
    log(sum(w * (m - a * x)^2) / sum(w)) + log(sum(w * (y - b * m - cp * x)^2) / sum(w))
  }
  for (q in c(0.4, -0.4)) {
    model <- paste0("M ~ a*X\nY ~ b*M + cp*X\na*b == ", q)
    fit <- suppressWarnings(fit_sem(model, data, weights = w, fixed_x = FALSE, meanstructure = TRUE))
    evidence <- fit@internals$search_evidence
    for (i in 1:2) {
      sign <- c(1, -1)[i]
      # Independent one-dimensional profile. This finite interval is numerical support, not a global certificate.
      oracle <- stats::optimize(nll, c(-4, 4), sign = sign, q = q, tol = 1e-10)
      expect_equal(unname(evidence$branches[[i]]$theta[["a"]]), sign * exp(oracle$minimum), tolerance = 2e-5)
      expect_equal(prod(evidence$branches[[i]]$theta[c("a", "b")]), q, tolerance = 1e-6)
    }
    expect_identical(evidence$coverage, "charted")
    expect_null(evidence$globality)
    expect_match(paste(capture.output(print(fit)), collapse = "\n"), "not global optimality")
  }
})

test_that("coverage evidence detects omission, sign swaps, false emptiness and wrong objectives", {
  fit <- suppressWarnings(fit_sem("M ~ a*X\nY ~ b*M + cp*X\na*b == 0.4", .nz_data(),
                                  fixed_x = FALSE, meanstructure = FALSE))
  out <- c(list(theta = coef(fit), f = fit@f, data = fit@data, information = fit@information,
                se_type = fit@diagnostics$se_type), fit@internals)
  expect_true(.sem_validate_search(out))
  missing <- out
  missing$search_evidence$branches <- missing$search_evidence$branches[1]
  expect_error(.sem_validate_search(missing), class = "medfit_error_search_evidence")
  swapped <- out
  swapped$search_evidence$branches <- rev(swapped$search_evidence$branches)
  expect_error(.sem_validate_search(swapped), class = "medfit_error_search_evidence")
  empty <- out
  empty$search_evidence$branches[[1]]$state <- "proved_empty"
  expect_error(.sem_validate_search(empty), class = "medfit_error_search_evidence")
  wrong <- out
  wrong$f <- -1
  expect_error(.sem_validate_search(wrong), class = "medfit_error_search_evidence")
  old <- out
  old$search_evidence <- NULL
  expect_true(.sem_validate_search(old))
  expect_equal(out$search_evidence$attempt_counts$n_starts,
               sum(vapply(out$search_evidence$branches, function(b) b$optimum$n_starts, 0)))
})

test_that("reference residual uses the reference gradient without any optimizer or covariance calls", {
  spec <- list(coefficient = 2, target = 1, labels = c("a", "b"))
  theta <- c(a = 1, b = 0.5)
  reference <- list(theta = c(a = 2, b = 3), vcov = diag(c(0.04, 0.09)), context = "sample-and-settings")
  dimnames(reference$vcov) <- list(c("a", "b"), c("a", "b"))
  local_mocked_bindings(.sem_optimize = function(...) stop("extra optimizer call"),
                        .sem_vcov = function(...) stop("extra covariance call"))
  diagnostic <- .sem_reference_residual(theta, spec, reference, context = "sample-and-settings")
  oracle_se <- sqrt(6^2 * 0.04 + 4^2 * 0.09)
  expect_equal(diagnostic$se_reference, oracle_se)
  expect_equal(diagnostic$standardized, 0)
  expect_identical(diagnostic$reason, "available")
  expect_gt(abs(oracle_se - sqrt(1^2 * 0.04 + 2^2 * 0.09)), 0.1)
  reference$vcov[, ] <- 0
  expect_identical(.sem_reference_residual(theta, spec, reference, context = "sample-and-settings")$reason,
                   "reference_directional_variance_invalid")
  expect_true(is.na(.sem_reference_residual(theta, spec)$standardized))
  reference$vcov[1, 1] <- NA_real_
  bad <- .sem_reference_residual(theta, spec, reference, context = "sample-and-settings")
  expect_identical(bad$reason, "reference_covariance_invalid")
  expect_identical(.sem_reference_residual(theta, spec, reference, context = "different")$reason,
                   "reference_context_mismatch")
})

test_that("a failed required branch is not a survivor-only fit", {
  real <- .sem_optimize
  local_mocked_bindings(.sem_optimize = function(ram, smp, start, lb, ub, ...) {
    if (ub[match("a", ram$par_names)] == 0) stop("planted negative-branch failure")
    real(ram, smp, start, lb, ub, ...)
  })
  error <- tryCatch(suppressWarnings(fit_sem("M ~ a*X\nY ~ b*M + cp*X\na*b == 0.4", .nz_data(),
                                             fixed_x = FALSE, meanstructure = FALSE)), error = identity)
  expect_s3_class(error, "medfit_error_no_convergence")
  expect_identical(error$search_evidence$coverage, "unresolved")
  expect_identical(error$search_evidence$branches[[2]]$state, "unresolved")
  expect_match(conditionMessage(error$search_evidence$branches[[2]]$condition), "planted")
})

test_that("sign-bound exclusions are syntactic and fallback classification is conservative", {
  spec <- list(idx = 1:2, ratio = 0.4)
  expect_true(.sem_sign_bounds(spec, c(0, -Inf), c(Inf, Inf), -1)$empty)
  expect_false(.sem_sign_bounds(spec, c(0, -Inf), c(Inf, Inf), 1)$empty)
  expect_true(.sem_sign_bounds(spec, c(0, -Inf), c(0, Inf), 1)$empty)
  ram <- list(par_names = c("a", "b", "cp"))
  cons <- data.frame(lhs = c("a*b", "a"), op = c("==", "<"), rhs = c("0.4", "0"))
  expect_identical(.sem_nonzero_product(cons, ram)$reason, "coupled_constraint")
  cons <- data.frame(lhs = c("p", "p"), op = c(":=", "=="), rhs = c("-2*a*b", "0.8"))
  expect_equal(.sem_nonzero_product(cons, ram)$ratio, -0.4)
})

test_that("nonzero sign branches have independent fits and honest stored coverage", {
  set.seed(3)
  x <- stats::rnorm(300)
  m <- 0.5 * x + stats::rnorm(300, sd = 0.8)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(300, sd = 0.7)
  data <- data.frame(X = x, M = m, Y = y)
  fit <- suppressWarnings(fit_sem("M ~ a*X\nY ~ b*M + cp*X\na*b == 0.4", data,
                                  fixed_x = FALSE, meanstructure = FALSE))
  evidence <- fit@internals$search_evidence
  expect_identical(evidence$coverage, "charted")
  expect_identical(vapply(evidence$branches, `[[`, "", "state"), c("accepted", "accepted"))
  expect_gt(evidence$branches[[1]]$theta[["a"]], 0)
  expect_lt(evidence$branches[[2]]$theta[["a"]], 0)
  expect_equal(fit@f, min(vapply(evidence$branches, `[[`, 0, "f")))
  expect_true(is.na(evidence$diagnostic$se_reference))
  expect_identical(evidence$diagnostic$reason, "reference_covariance_unavailable")
  expect_identical(fit@diagnostics$ledger$schema_version, 1L)
  expect_length(fit@diagnostics$ledger$children, 0)
})

test_that("independent nuisance constraints do not disable sign coverage", {
  ram <- list(par_names = c("a", "b", "cp"))
  cons <- data.frame(lhs = c("a*b", "cp"), op = c("==", ">"), rhs = c("0.4", "0"))
  expect_true(.sem_nonzero_product(cons, ram)$supported)
})


test_that("bounds on either factor prove product ranges empty without optimizer calls", {
  spec <- list(idx = 1:2, ratio = 10)
  expect_true(.sem_sign_bounds(spec, c(1, 1), c(2, 2), 1)$empty)
  expect_true(.sem_sign_bounds(spec, c(-2, -2), c(-1, -1), -1)$empty)
  spec$ratio <- 1e-200
  expect_false(.sem_sign_bounds(spec, c(0, 0), c(Inf, Inf), 1)$empty)
  spec$ratio <- 1e200
  expect_false(.sem_sign_bounds(spec, c(-Inf, -Inf), c(0, 0), -1)$empty)
  local_mocked_bindings(.sem_optimize = function(...) stop("must not optimize proved empty branches"))
  error <- tryCatch(.sem_optimize_signs(NULL, NULL, c(1, 1), c(1, 1), c(2, 2), 5L,
                                        list(), NULL, spec), error = identity)
  expect_s3_class(error, "medfit_error_no_convergence")
  expect_identical(vapply(error$search_evidence$branches, `[[`, "", "state"),
                   c("proved_empty", "proved_empty"))
})


test_that("units and finite coefficient scaling preserve the constrained likelihood", {
  d <- .nz_data()
  model <- "M ~ a*X\nY ~ b*M + cp*X\na*b == 0.4"
  baseline <- suppressWarnings(fit_sem(model, d, fixed_x = FALSE, meanstructure = TRUE))
  for (coefficient in c(-2, 1e-3, 1e3)) {
    scaled <- sub("a*b == 0.4", paste0(coefficient, "*a*b == ", coefficient * 0.4), model, fixed = TRUE)
    other <- suppressWarnings(fit_sem(scaled, d, fixed_x = FALSE, meanstructure = TRUE))
    expect_equal(coef(other), coef(baseline), tolerance = 1e-6)
    expect_equal(other@f, baseline@f, tolerance = 1e-8)
  }
  d$M <- 2 * d$M
  units <- suppressWarnings(fit_sem(model, d, fixed_x = FALSE, meanstructure = TRUE))
  expect_equal(coef(units)[["a"]] / 2, coef(baseline)[["a"]], tolerance = 1e-5)
  expect_equal(2 * coef(units)[["b"]], coef(baseline)[["b"]], tolerance = 1e-5)
  expect_equal(units@f, baseline@f, tolerance = 1e-8)
})

test_that("charted multimodal branch solves do not become a global certificate", {
  # f'(t)=(t-1)(t-2)(t-4): 1 and 4 are local minima, and 4 is better.
  objective <- function(t) t^4 / 4 - 7 * t^3 / 3 + 7 * t^2 - 8 * t
  expect_lt(objective(4), objective(1))
  spec <- list(idx = 1:2, ratio = 0.4, labels = c("a", "b"))
  local_mocked_bindings(.sem_optimize = function(ram, smp, start, lb, ub, ...) {
    theta <- c(a = sign(start[1]), b = 0.4 * sign(start[1]))
    list(theta = theta, f = objective(1), status = 4L, decrement = 0,
         optimum = list(n_starts = 5L, n_accepted = 1L, certified = TRUE),
         attempts = c(list(list(accepted = TRUE, f = objective(1))),
                      rep(list(list(accepted = FALSE, f = objective(1))), 4L)))
  })
  out <- .sem_optimize_signs(NULL, NULL, c(a = 1, b = 0.4), rep(-Inf, 2), rep(Inf, 2),
                             5L, list(), NULL, spec)
  expect_identical(out$search_evidence$coverage, "charted")
  expect_false(out$optimum$certified)
  expect_identical(out$optimum$status, "agreed")
  expect_equal(out$f, objective(1))
  expect_null(out$search_evidence$globality)
})


test_that("supported product row values and derivatives use coefficient-independent units", {
  ram <- list(q = 3L, par_names = c("a", "b", "cp"))
  theta <- c(a = 0.8, b = 0.5, cp = 0.2)
  for (coefficient in c(-2, 1e-100, 1e-3, 1, 1e100)) {
    cons <- data.frame(lhs = paste0(coefficient, "*a*b"), op = "==", rhs = as.character(coefficient * 0.4))
    rows <- .sem_constraint_rows(cons, ram)
    expect_equal(rows$nl$value(theta), 0, tolerance = 1e-15)
    expect_equal(unname(rows$nl$jac(theta, rep(1, 3))), matrix(c(0.5, 0.8, 0), 1L), tolerance = 1e-8)
    expect_equal(rows$nl$hess(theta, rep(1, 3))[[1]][1, 2], 1, tolerance = 1e-5)
    expect_identical(rows$nl$text, paste(cons$lhs, "==", cons$rhs))
  }
})


test_that("unrepresentable nonzero product ratios remain unsupported", {
  ram <- list(par_names = c("a", "b"))
  for (values in list(c(1e-300, 1e300), c(1e300, 1e-300))) {
    cons <- data.frame(lhs = paste0(values[1L], "*a*b"), op = "==", rhs = as.character(values[2L]))
    expect_false(.sem_nonzero_product(cons, ram)$supported)
  }
})
