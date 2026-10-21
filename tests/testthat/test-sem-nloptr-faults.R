fault_setup <- function() {
  mod <- sem_model_observed() # nolint: object_usage_linter.
  smp <- .sem_sample(sem_sim(mod, 180L, 41L), mod$ram) # nolint: object_usage_linter.
  start <- .sem_default_start(mod$ram, smp)
  good <- .sem_optimize(mod$ram, smp, start, n_starts = 1L)
  list(ram = mod$ram, smp = smp, start = start, good = good,
       u = .sem_step_floor(mod$ram, smp))
}

fault_result <- function(s, status = 4L, solution = s$good$theta, objective = s$good$f) {
  list(solution = unname(solution / s$u), status = status, objective = objective)
}

test_that("non-success nloptr statuses are refused with their code", {
  s <- fault_setup()
  for (status in c(-1L, -2L, -3L, 2L, 5L, 6L)) {
    testthat::local_mocked_bindings(
      .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
        fault_result(s, status)
      }
    )
    expect_error(.sem_optimize(s$ram, s$smp, s$start, n_starts = 1L),
                 paste0("no start converged.*status ", status), info = status)
  }
})

test_that("xtol status 4 accepts only the gated optimum", {
  s <- fault_setup()
  testthat::local_mocked_bindings(
    .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
      fault_result(s)
    }
  )
  fit <- .sem_optimize(s$ram, s$smp, s$start, n_starts = 1L)
  expect_equal(fit$theta, s$good$theta, tolerance = 1e-6)
  expect_identical(fit$status, 4L)
})

test_that("nonfinite solver coordinates never become a returned fit", {
  s <- fault_setup()
  for (value in c(NaN, Inf)) {
    bad <- s$good$theta
    bad[1L] <- value
    testthat::local_mocked_bindings(
      .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
        fault_result(s, solution = bad)
      }
    )
    expect_error(.sem_optimize(s$ram, s$smp, s$start, n_starts = 1L), info = value)
  }
})

test_that("a failed first solver call retries and flags the accepted second start", {
  s <- fault_setup()
  calls <- 0L
  testthat::local_mocked_bindings(
    .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
      calls <<- calls + 1L
      if (calls == 1L) stop("injected wrapper failure")
      fault_result(s)
    }
  )
  expect_warning(fit <- .sem_optimize(s$ram, s$smp, s$start, n_starts = 2L),
                 "first start was not accepted.*nloptr error")
  expect_equal(calls, 2L)
  expect_equal(fit$theta, s$good$theta, tolerance = 1e-6)
  expect_equal(fit$retries, 1L)
})

test_that("a thrown wrapper error with no retry budget is refused", {
  s <- fault_setup()
  testthat::local_mocked_bindings(
    .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
      stop("injected wrapper failure")
    }
  )
  expect_error(.sem_optimize(s$ram, s$smp, s$start, n_starts = 1L),
               "no start converged.*nloptr error: injected wrapper failure")
})

test_that("out-of-bounds and false-objective results record current behavior", {
  s <- fault_setup()
  lb <- rep(-Inf, s$ram$q)
  k <- match("Y~M", s$ram$par_names)
  lb[k] <- s$good$theta[k] + 0.1
  testthat::local_mocked_bindings(
    .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
      fault_result(s)
    }
  )
  # BUG? The gate accepts an optimum below a stated lower bound: active-bound logic
  # checks the gradient sign but does not check primal box feasibility.
  outside <- .sem_optimize(s$ram, s$smp, s$start, lb = lb, n_starts = 1L)
  expect_lt(outside$theta[k], lb[k])
  # BUG? The gate trusts the wrapper objective without recomputing F(theta).
  testthat::local_mocked_bindings(
    .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
      fault_result(s, objective = s$good$f + 10)
    }
  )
  wrong <- .sem_optimize(s$ram, s$smp, s$start, n_starts = 1L)
  expect_equal(wrong$f, s$good$f + 10)
  expect_gt(abs(wrong$f - .sem_fml(wrong$theta, s$ram, s$smp)), 1)
})
