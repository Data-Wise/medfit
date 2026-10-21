met_model <- "M ~ a*X\nY ~ b*M + cp*X"

met_data <- function() {
  mod <- sem_model_observed() # nolint: object_usage_linter.
  sem_sim(mod, 200L, 71L)[, c("X", "M", "Y")] # nolint: object_usage_linter.
}

met_fit <- function(data, model = met_model, n_starts = 1L) {
  parsed <- .sem_parse(model)
  ram <- .sem_to_ram(.sem_complete(parsed$parameters))$ram
  smp <- .sem_sample(data[, ram$obs], ram)
  cons <- .sem_constraint_rows(parsed$constraints, ram)
  .sem_optimize(ram, smp, .sem_default_start(ram, smp), n_starts = n_starts, constraints = cons)
}

met_equal <- function(x, y, tolerance = 1e-5) {
  testthat::expect_equal(x$theta[names(y$theta)], y$theta, tolerance = tolerance)
  testthat::expect_equal(x$f, y$f, tolerance = 1e-6)
}

test_that("unit changes transport natural-unit estimates and preserve discrepancy", {
  data <- met_data()
  base <- met_fit(data)
  for (variable in names(data)) {
    for (scale in c(1e-3, 1e3)) {
      changed <- data
      changed[[variable]] <- changed[[variable]] * scale
      fit <- met_fit(changed)
      want <- base$theta
      if (variable == "X") want["a"] <- want["a"] / scale
      if (variable == "X") want["cp"] <- want["cp"] / scale
      if (variable == "M") want["a"] <- want["a"] * scale
      if (variable == "M") want["b"] <- want["b"] / scale
      if (variable == "Y") want[c("b", "cp")] <- want[c("b", "cp")] * scale
      variance <- paste0(variable, "~~", variable)
      want[variance] <- want[variance] * scale^2
      expect_equal(fit$theta[names(want)], want,
                   tolerance = 1e-5, info = paste(variable, scale))
      expect_equal(fit$f, base$f, tolerance = 1e-6, info = paste(variable, scale))
    }
  }
})

test_that("row and syntax order preserve the observed mediation fit", {
  data <- met_data()
  base <- met_fit(data)
  set.seed(19)
  met_equal(met_fit(data[sample.int(nrow(data)), ]), base)
  met_equal(met_fit(data, "Y ~ cp*X + b*M\nM ~ a*X"), base)
})

test_that("unconstrained path estimates match independent OLS regressions", {
  data <- met_data()
  fit <- met_fit(data)
  a <- unname(stats::coef(stats::lm(M ~ X, data))["X"])
  bc <- stats::coef(stats::lm(Y ~ M + X, data))
  expect_equal(unname(fit$theta[c("a", "b", "cp")]),
               unname(c(a, bc[c("M", "X")])), tolerance = 1e-5)
})

test_that("redundant and algebraically equivalent linear equalities agree", {
  data <- met_data()
  base <- met_fit(data, paste(met_model, "a + b == 0.9", sep = "\n"))
  duplicate <- met_fit(data, paste(met_model, "a + b == 0.9", "2*a + 2*b == 1.8", sep = "\n"))
  equivalent <- met_fit(data, paste(met_model, "b == 0.9 - a", sep = "\n"))
  met_equal(duplicate, base)
  met_equal(equivalent, base)
})

test_that("alternate valid starts and larger start budgets reach the same accepted fit", {
  data <- met_data()
  parsed <- .sem_parse(met_model)
  ram <- .sem_to_ram(.sem_complete(parsed$parameters))$ram
  smp <- .sem_sample(data[, ram$obs], ram)
  start <- .sem_default_start(ram, smp)
  changed <- start
  changed[c("a", "b", "cp")] <- c(0.1, 0.8, -0.1)
  set.seed(23)
  first <- .sem_optimize(ram, smp, start, n_starts = 1L)
  set.seed(23)
  second <- .sem_optimize(ram, smp, changed, n_starts = 3L)
  expect_equal(second$theta, first$theta, tolerance = 1e-5)
})

test_that("planted defect: omitting natural-unit conversion breaks scaled fitting", {
  data <- met_data()
  changed <- data
  changed$Y <- changed$Y * 1e3
  base <- met_fit(data)
  expect_true(base$converged)
  testthat::local_mocked_bindings(
    .sem_solve_one = sem_mutate(.sem_solve_one,
                                "res$solution <- res$solution * u",
                                "res$solution <- res$solution")
  )
  expect_error(met_fit(changed), "no start converged")
})
