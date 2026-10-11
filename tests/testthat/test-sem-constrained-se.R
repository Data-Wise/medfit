# Native SEM engine: covariance under constraints and defined parameters (S15).
# Oracles: the collapsed shared-label model (an exact identity for `a == b`), the
# fixed-parameter model for `a == 0` and an active bound, lavaan's own standard
# errors for constraints and `:=`, and a hand delta method. Planted defect: the
# plain inverse information, without the projection, must fail the `a == b` row.

se_data <- function(n = 500, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = stats::rnorm(n))
  d$M <- 0.5 * d$X + stats::rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(n)
  d
}

se_base <- "M ~ a*X\nY ~ b*M + cp*X"

se_fit <- function(extra = "", model = se_base, information = "expected", data = se_data()) {
  .sem_fit_syntax(paste0(model, "\n", extra), data, information = information)
}

se_of <- function(fit) sqrt(diag(fit$vcov))

test_that("a == b gives the collapsed shared-label covariance, exactly", {
  for (info in c("expected", "observed")) {
    con <- se_fit("a == b", information = info)
    col <- se_fit(model = "M ~ a*X\nY ~ a*M + cp*X", information = info)
    # Estimates agree to the solver tolerance, so the covariances do to about 1e-6 relative.
    shared <- matrix(col$vcov["a", "a"], 2L, 2L, dimnames = list(c("a", "b"), c("a", "b")))
    expect_equal(con$vcov[c("a", "b"), c("a", "b")], shared, tolerance = 1e-5, info = info)
    rest <- setdiff(rownames(col$vcov), "a")
    expect_equal(con$vcov[rest, rest], col$vcov[rest, rest], tolerance = 1e-5, info = info)
    expect_equal(con$vcov["a", rest], col$vcov["a", rest], tolerance = 1e-5, info = info)
    expect_identical(con$active_constraints, "a == b")
  }
})

test_that("planted defect: the unprojected inverse information fails the a == b identity", {
  con <- se_fit("a == b")
  col <- se_fit(model = "M ~ a*X\nY ~ a*M + cp*X")
  plain <- solve(.sem_info_expected(con$theta, con$ram, .sem_sample(se_data()[, con$ram$obs], con$ram)))
  expect_gt(abs(plain["a", "a"] / col$vcov["a", "a"] - 1), 0.05)
  expect_lt(abs(con$vcov["a", "a"] / col$vcov["a", "a"] - 1), 1e-5)
  # the projected matrix is singular in the constrained direction a - b
  expect_lt(abs(sum(c(1, -1) * (con$vcov[c("a", "b"), c("a", "b")] %*% c(1, -1)))), 1e-10)
})

test_that("a == 0 matches the fixed-parameter model and pins the variance of a to zero", {
  con <- se_fit("a == 0")
  fixed <- se_fit(model = "M ~ 0*X\nY ~ b*M + cp*X")
  rest <- rownames(fixed$vcov)
  expect_equal(con$vcov[rest, rest], fixed$vcov, tolerance = 1e-5)
  expect_identical(con$vcov["a", ], stats::setNames(rep(0, nrow(con$vcov)), rownames(con$vcov)))
})

test_that("an active bound is projected out like a fixed value", {
  bound <- .sem_fit_syntax("M ~ a*X\nY ~ lower(0.6)*M + cp*X", se_data(), information = "expected")
  fixed <- .sem_fit_syntax("M ~ a*X\nY ~ 0.6*M + cp*X", se_data(), information = "expected")
  expect_true("Y ~ M" %in% bound$active_bounds)
  rest <- rownames(fixed$vcov)
  expect_equal(bound$vcov[rest, rest], fixed$vcov, tolerance = 1e-5)
  expect_equal(unname(bound$vcov["Y ~ M", ]), rep(0, nrow(bound$vcov)))
})

test_that("an inequality enters the covariance only when it is active", {
  free <- se_fit()
  # unconstrained a - b = 0.128 > 0, so `a > b` is slack and `a < b` binds
  slack <- se_fit("a > b")
  bind <- se_fit("a < b")
  eq <- se_fit("a == b")
  expect_equal(slack$vcov, free$vcov, tolerance = 1e-6)
  expect_identical(slack$active_constraints, character())
  expect_equal(bind$vcov, eq$vcov, tolerance = 1e-5)
  expect_identical(bind$active_constraints, "a < b")
})

test_that("constrained standard errors equal lavaan's", {
  skip_if_not_installed("lavaan")
  d <- se_data()
  pick <- c(a = "M ~ X", b = "Y ~ M", cp = "Y ~ X")
  for (extra in c("a == b", "a == 0.4", "a + b == 1")) {
    fit <- se_fit(extra, data = d)
    lav <- suppressWarnings(lavaan::sem(paste0(se_base, "\n", extra), d, fixed.x = FALSE, information = "expected"))
    pe <- lavaan::parameterEstimates(lav)
    key <- paste(pe$lhs, pe$op, pe$rhs)
    se <- pe$se[match(unname(pick), key)]
    expect_equal(unname(se_of(fit)[names(pick)]), se, tolerance = 1e-5, info = extra)
  }
})

test_that("defined parameters match lavaan's := rows and the hand delta method", {
  skip_if_not_installed("lavaan")
  d <- se_data()
  fit <- se_fit("ab := a*b\ntot := a*b + cp\ndiff := a - b", data = d)
  lav <- suppressWarnings(lavaan::sem(paste0(se_base, "\nab := a*b\ntot := a*b + cp\ndiff := a - b"), d,
                                      fixed.x = FALSE, information = "expected"))
  pe <- lavaan::parameterEstimates(lav)
  ref <- pe[pe$op == ":=", ]
  expect_identical(fit$defined$name, c("ab", "tot", "diff"))
  expect_equal(fit$defined$est, ref$est[match(fit$defined$name, ref$lhs)], tolerance = 1e-6)
  expect_equal(fit$defined$se, ref$se[match(fit$defined$name, ref$lhs)], tolerance = 1e-5)
  a <- fit$theta[["a"]]
  b <- fit$theta[["b"]]
  v <- fit$vcov[c("a", "b"), c("a", "b")]
  expect_equal(fit$defined$se[1L], sqrt(b^2 * v[1, 1] + a^2 * v[2, 2] + 2 * a * b * v[1, 2]), tolerance = 1e-8)
})

test_that("defined parameters use the projected covariance under a constraint", {
  fit <- se_fit("a == b\nab := a*b")
  a <- fit$theta[["a"]]
  v <- fit$vcov["a", "a"]
  # b = a on the constraint, so ab = a^2 and se = 2 |a| se(a)
  expect_equal(fit$defined$se, 2 * abs(a) * sqrt(v), tolerance = 1e-6)
  expect_equal(fit$defined$est, a^2, tolerance = 1e-8)
})

test_that("a model with only := rows fits unconstrained and reports the definition", {
  fit <- se_fit("ab := a*b")
  free <- se_fit()
  expect_equal(fit$theta, free$theta, tolerance = 1e-8)
  expect_equal(fit$vcov, free$vcov, tolerance = 1e-8)
  expect_identical(nrow(fit$defined), 1L)
  expect_identical(nrow(free$defined), 0L)
})

test_that("a constraint a == b and a defined parameter naming a non-parameter error by name", {
  expect_error(se_fit("ab := a*zzz"), "zzz")
})
