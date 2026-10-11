# Native SEM engine: zero-product constraints solved as linear branches (T14).
# `a*b == 0` is `a == 0` or `b == 0`: one linear refit per factor, smallest discrepancy wins. Oracles: the
# MBCO known answers on RMediation's `memory_exp` (OpenMx diffLL 221.045546 for the a1 branch, 0.083100 for
# the b1 branch) and a brute force over the single-factor fits. Planted defects: the larger branch taken, a
# branch warm-started from the full fit's estimates.

mem_data <- function() {
  path <- testthat::test_path("fixtures", "memory_exp.rds")
  if (!file.exists(path)) testthat::skip("tests/testthat/fixtures/memory_exp.rds is not present")
  readRDS(path)
}
mem_syn <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

# Three mediators in parallel on the bundled data.
tri_syn <- paste0(
  "mediator1 ~ a1*treatment\nmediator2 ~ a2*treatment\nmediator3 ~ a3*treatment\n",
  "outcome ~ b1*mediator1 + b2*mediator2 + b3*mediator3 + treatment"
)

# Smallest discrepancy over the single-factor linear fits, by brute force.
branch_min <- function(syntax, factors, data, extra = "") {
  f <- vapply(factors, function(k) fit_sem(paste0(syntax, extra, "\n", k, " == 0"), data)@f, numeric(1))
  list(f = f, best = factors[which.min(f)])
}

test_that("a1*b1 == 0 on memory_exp gives the minimum branch, 0.083100, not the nonlinear 221.05", {
  d <- mem_data()
  full <- fit_sem(mem_syn, d)
  for (con in c("a1*b1 == 0", "b1*a1 == 0", "0 == a1 * b1")) {
    fit <- fit_sem(paste0(mem_syn, "\n", con), d)
    expect_lt(abs(nrow(d) * (fit@f - full@f) - 0.083100), 1e-6, label = con)
    expect_identical(fit@internals$branch, "b1 == 0")
    expect_identical(fit@diagnostics$active_constraints, "b1 == 0")
  }
  expect_gt(abs(221.045546 - 0.083100), 1e-6)
  # the winning branch fixes one parameter, so it has one more df than the full model
  expect_equal(fit@df, full@df + 1)
})

test_that("a defined name for the product, and a repeated factor, follow the same route", {
  d <- mem_data()
  full <- fit_sem(mem_syn, d)
  via_def <- fit_sem(paste0(mem_syn, "\nab := a1*b1\nab == 0"), d)
  expect_equal(nrow(d) * (via_def@f - full@f), 0.083100, tolerance = 1e-5)
  expect_identical(via_def@internals$branch, "b1 == 0")
  # a*a == 0 is a == 0: a single branch
  sq <- fit_sem(paste0(mem_syn, "\nb1*b1 == 0"), d)
  expect_identical(sq@internals$branch, "b1 == 0")
})

test_that("a product of three factors returns the minimum of the three branches", {
  fit <- fit_sem(paste0(tri_syn, "\nb1*b2*b3 == 0"), mediation_demo)
  ref <- branch_min(tri_syn, c("b1", "b2", "b3"), mediation_demo)
  expect_equal(fit@f, min(ref$f), tolerance = 1e-10)
  expect_identical(fit@internals$branch, paste(ref$best, "== 0"))
  expect_gt(max(ref$f) - min(ref$f), 1e-6)
})

test_that("two factors near zero (a vanishing Jacobian) still give the minimum branch", {
  set.seed(5)
  n <- 300
  x <- stats::rnorm(n)
  m1 <- 0.5 * x + stats::rnorm(n)
  m2 <- 0.4 * x + stats::rnorm(n)
  m3 <- 0.3 * x + stats::rnorm(n)
  y <- 0.001 * m1 - 0.002 * m2 + 0.5 * m3 + 0.2 * x + stats::rnorm(n)
  d <- data.frame(treatment = x, mediator1 = m1, mediator2 = m2, mediator3 = m3, outcome = y)
  fit <- fit_sem(paste0(tri_syn, "\nb1*b2*b3 == 0"), d)
  ref <- branch_min(tri_syn, c("b1", "b2", "b3"), d)
  expect_equal(fit@f, min(ref$f), tolerance = 1e-10)
  expect_true(fit@internals$branch %in% c("b1 == 0", "b2 == 0"))
  # the branch it did not take is the one whose factor is far from zero
  expect_gt(max(ref$f) - min(ref$f), 1e-3)
})

test_that("two zero-product rows give the cartesian product of branches", {
  syn <- paste0(
    "mediator1 ~ a1*treatment\nmediator2 ~ a2*treatment\n",
    "outcome ~ b1*mediator1 + b2*mediator2 + treatment"
  )
  fit <- fit_sem(paste0(syn, "\na1*b1 == 0\na2*b2 == 0"), mediation_demo)
  grid <- expand.grid(c("a1", "b1"), c("a2", "b2"), stringsAsFactors = FALSE)
  f <- vapply(seq_len(nrow(grid)), function(i) {
    fit_sem(paste0(syn, "\n", grid[i, 1], " == 0\n", grid[i, 2], " == 0"), mediation_demo)@f
  }, numeric(1))
  expect_equal(fit@f, min(f), tolerance = 1e-10)
  expect_identical(fit@internals$branch, paste(unlist(grid[which.min(f), ]), "== 0"))
  expect_equal(fit@df, fit_sem(syn, mediation_demo)@df + 2)
})

test_that("each branch starts from the default start, never from the full fit or another branch", {
  d <- mem_data()
  seen <- list()
  real <- .sem_optimize
  testthat::local_mocked_bindings(.sem_optimize = function(ram, smp, start, ...) {
    seen[[length(seen) + 1L]] <<- list(start = start, default = .sem_default_start(ram, smp))
    real(ram, smp, start, ...)
  })
  full <- fit_sem(mem_syn, d)
  seen <- list()
  fit_sem(paste0(mem_syn, "\na1*b1 == 0"), d)
  expect_length(seen, 2L)
  for (s in seen) {
    expect_equal(unname(s$start), unname(s$default))
    expect_gt(max(abs(unname(s$start) - unname(coef(full)))), 1e-3)
  }
})

test_that("planted defect: warm-starting a branch from the full fit is caught by the start check", {
  d <- mem_data()
  full <- fit_sem(mem_syn, d)
  real <- .sem_optimize
  starts <- list()
  testthat::local_mocked_bindings(.sem_optimize = function(ram, smp, start, ...) {
    start[] <- unname(coef(full))
    starts[[length(starts) + 1L]] <<- list(start = start, default = .sem_default_start(ram, smp))
    real(ram, smp, start, ...)
  })
  fit_sem(paste0(mem_syn, "\na1*b1 == 0"), d)
  # the clean-start check of the previous test fails for such a run
  clean <- vapply(starts, function(s) isTRUE(all.equal(unname(s$start), unname(s$default))), TRUE)
  expect_false(any(clean))
})

test_that("planted defect: taking the larger branch misses the known answer", {
  d <- mem_data()
  full <- fit_sem(mem_syn, d)
  larger <- sem_mutate(.sem_fit_branches, "which.min(", "which.max(")
  testthat::local_mocked_bindings(.sem_fit_branches = larger)
  fit <- fit_sem(paste0(mem_syn, "\na1*b1 == 0"), d)
  expect_gt(abs(nrow(d) * (fit@f - full@f) - 0.083100), 1)
  expect_equal(nrow(d) * (fit@f - full@f), 221.045546, tolerance = 1e-6)
})

test_that("branches that cannot all be fitted error by listing each", {
  expect_error(
    fit_sem(paste0(mem_syn, "\na1*b1 == 0\na1 == 1\nb1 == 1"), mem_data()),
    "no branch of the zero-product constraints converged.*a1 == 0.*b1 == 0"
  )
})

test_that("forms that are not zero products keep the nonlinear route; too many branches error", {
  d <- mem_data()
  fit <- fit_sem(paste0(mem_syn, "\na1*b1 == 0.01"), d)
  expect_identical(fit@internals$branch, character())
  set.seed(1)
  dat <- as.data.frame(matrix(stats::rnorm(60 * 15), 60, 15))
  names(dat) <- c("Y", paste0("V", 1:14))
  model <- paste0("Y ~ ", paste0("p", 1:14, "*V", 1:14, collapse = " + "), "\n",
                  paste0("p", seq(1, 13, 2), "*p", seq(2, 14, 2), " == 0", collapse = "\n"))
  expect_error(fit_sem(model, dat), "at most 64 are supported")
})
