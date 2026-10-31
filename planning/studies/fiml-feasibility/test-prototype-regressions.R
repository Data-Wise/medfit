# Run with testthat::test_file(..., stop_on_failure = TRUE), not package CI.
study_dir <- if (file.exists("prototype.R")) "." else "planning/studies/fiml-feasibility"
pkgload::load_all(file.path(study_dir, "../../.."), quiet = TRUE, export_all = FALSE)
prototype <- new.env(parent = globalenv())
sys.source(file.path(study_dir, "prototype.R"), envir = prototype)
sys.source(file.path(study_dir, "prototype-fixtures.R"), envir = prototype)
for (expr in parse(file.path(study_dir, "study.R"))) {
  if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
      identical(expr[[2]], as.name("generate"))) eval(expr, prototype)
}
expect_attempts <- function(error, message) {
  testthat::expect_s3_class(error, "error")
  testthat::expect_match(conditionMessage(error), message, fixed = TRUE)
  attempts <- error$attempts
  testthat::expect_s3_class(attempts, "data.frame")
  if (!is.data.frame(attempts)) return(invisible(NULL))
  testthat::expect_equal(nrow(attempts), 6L)
  testthat::expect_setequal(names(attempts), c("solver", "start", "first_status", "status",
                                            "accepted", "nll", "stationarity", "reason"))
  testthat::expect_setequal(paste(attempts$solver, attempts$start),
                           paste(rep(c("slsqp", "nlminb"), each = 3), rep(1:3, 2)))
  testthat::expect_true(all(is.finite(attempts$status)))
  testthat::expect_true(all(is.finite(attempts$nll)))
}

# Actual nonidentification, without a mocked numerical evaluator.
testthat::test_that("rank-deficient fits retain all solver/start records", {
  for (direct in c(TRUE, FALSE)) {
    dat <- prototype$generate(271L, "complete", direct)
    dat[1:150, 3] <- NA
    dat[151:300, 1:2] <- NA
    error <- tryCatch(prototype$prototype_fit(dat, direct), error = identity)
    testthat::expect_s3_class(error, "fiml_prototype_diagnostic")
    expect_attempts(error, "observed-pattern moment Jacobian is rank deficient")
  }
})

testthat::test_that("likelihood-spread diagnostics retain all attempts", {
  fit <- prototype$prototype_fit
  code <- paste(deparse(fit), collapse = "\n")
  old <- "if (spread > 1e-08)"
  testthat::expect_equal(lengths(regmatches(code, gregexpr(old, code, fixed = TRUE))), 1L)
  # Force this post-solver rejection after real solver attempts complete.
  fit <- eval(parse(text = sub(old, "if (TRUE)", code, fixed = TRUE)), prototype)
  error <- tryCatch(fit(prototype$generate(271L, "complete", TRUE)), error = identity)
  testthat::expect_s3_class(error, "fiml_prototype_diagnostic")
  expect_attempts(error, "accepted optimizer likelihoods disagree")
})

testthat::test_that("information diagnostics and Hessian errors preserve attempts", {
  for (failure in c("information", "perturbation", "unexpected")) {
    local <- new.env(parent = prototype)
    local$post_solver <- FALSE
    local$prototype_geometry <- function(theta, p) {
      local$post_solver <- TRUE
      prototype$prototype_geometry(theta, p)
    }
    local$prototype_hessian <- function(theta, p, multiplier = 1) {
      if (local$post_solver) {
        if (failure == "perturbation") prototype$prototype_diagnostic("invalid Hessian perturbation")
        if (failure == "unexpected") stop("injected numerical Hessian error")
        return(-diag(length(theta)))
      }
      prototype$prototype_hessian(theta, p, multiplier)
    }
    fit <- prototype$prototype_fit
    environment(fit) <- local
    error <- tryCatch(fit(prototype$generate(271L, "complete", TRUE)), error = identity)
    testthat::expect_s3_class(error, if (failure == "unexpected") "simpleError" else "fiml_prototype_diagnostic")
    message <- switch(failure,
      information = "unidentified or ill-conditioned observed information",
      perturbation = "invalid Hessian perturbation",
      unexpected = "injected numerical Hessian error")
    expect_attempts(error, message)
  }
})

testthat::test_that("near-singular fixtures match the independently generated SD 0.03 model", {
  for (direct in c(TRUE, FALSE)) {
    actual <- prototype$prototype_near_singular(prototype$generate, direct)
    set.seed(271L)
    X <- .8 + stats::rnorm(300, sd = 1.1)
    M <- -.4 + .5 * X + stats::rnorm(300, sd = .8)
    innovation <- stats::rnorm(300, sd = .03)
    Y <- .7 + .6 * M + (if (direct) .25 else 0) * X + innovation
    expected <- cbind(X, M, Y)
    expected[is.na(prototype$generate(271L, "nonmonotone_mcar", direct))] <- NA
    testthat::expect_identical(is.na(actual), is.na(expected))
    testthat::expect_equal(actual, expected, tolerance = 1e-13)
    observed <- !is.na(actual[, 3])
    residual <- actual[observed, 3] - .7 - .6 * M[observed] - (if (direct) .25 else 0) * X[observed]
    testthat::expect_equal(residual, innovation[observed], tolerance = 1e-13)
  }
})
