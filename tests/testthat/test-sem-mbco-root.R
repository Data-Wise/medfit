# The MBCO root ledger is validated before mbco_sem() returns: the full fit and one null per tested path, rebuilt.

mbco_root_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

mbco_root_fit <- function(...) {
  data <- readRDS(testthat::test_path("fixtures", "memory_exp.rds"))
  suppressMessages(fit_sem(mbco_root_model, data, n_starts = 1L, ...))
}

test_that("a resolved ordinary MBCO root validates, and mutated roots do not", {
  fit <- mbco_root_fit()
  res <- mbco_sem(fit, "a2", "cp", n_starts = 1L)
  root <- res$ledger
  paths <- c("a2", "cp")
  expect_length(root$children, 3L)
  # the generic validator cannot take a root whose children are not zero-product branches
  expect_false(.sem_valid_outcome(root))
  expect_true(.sem_valid_mbco_outcome(root, paths))

  dropped <- root
  dropped$children <- root$children[-3L]
  expect_false(.sem_valid_mbco_outcome(dropped, paths))
  extra <- root
  extra$children[[4L]] <- root$children[[3L]]
  expect_false(.sem_valid_mbco_outcome(extra, paths))
  swapped <- root
  swapped$children[2:3] <- root$children[3:2]
  expect_false(.sem_valid_mbco_outcome(swapped, paths))
  expect_false(.sem_valid_mbco_outcome(root, rev(paths)))
  altered <- root
  altered$children[[2L]]$constraints$rhs <- "1"
  expect_false(.sem_valid_mbco_outcome(altered, paths))
  other <- root
  other$children[[3L]]$context$sample_hash <- "forged"
  expect_false(.sem_valid_mbco_outcome(other, paths))
  own <- root
  own$children[[3L]]$context[["sample"]] <- root$context[["sample"]][-1L, ]
  expect_false(.sem_valid_mbco_outcome(own, paths))
  renamed <- root
  renamed$id <- "fit"
  expect_false(.sem_valid_mbco_outcome(renamed, paths))
  badnull <- root
  badnull$children[[2L]]$id <- "mbco/null:9"
  expect_false(.sem_valid_mbco_outcome(badnull, paths))
  badlik <- root
  badlik$likelihood$f <- root$likelihood$f + 1
  expect_false(.sem_valid_mbco_outcome(badlik, paths))
  badout <- root
  badout$children[[2L]]$outcome <- "unresolved"
  expect_false(.sem_valid_mbco_outcome(badout, paths))
})

test_that("mbco_sem() refuses a root that does not validate, with the ledger error class", {
  fit <- mbco_root_fit()
  testthat::local_mocked_bindings(.sem_valid_mbco_outcome = function(...) FALSE)
  expect_error(mbco_sem(fit, "a2", "cp", n_starts = 1L), "malformed MBCO outcome ledger",
               class = "medfit_error_ledger")
})

test_that("an unresolved MBCO root validates", {
  fit <- mbco_root_fit()
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    if (!is.null(model) && endsWith(model, "\na2 == 0")) {
      stop(.sem_no_convergence("injected null failure"))
    }
    real(model, ...)
  })
  res <- suppressWarnings(mbco_sem(fit, "a2", "cp", n_starts = 1L))
  expect_true(res$unresolved)
  expect_identical(res$ledger$outcome, "unresolved")
  expect_identical(res$ledger$children[[2L]]$outcome, "unresolved")
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a2", "cp")))
  forged <- res$ledger
  forged$outcome <- "resolved"
  expect_false(.sem_valid_mbco_outcome(forged, c("a2", "cp")))
  # a failed null on other rows is not the null that was asked for
  other <- res$ledger
  other$children[[2L]]$context$sample_hash <- "forged"
  expect_false(.sem_valid_mbco_outcome(other, c("a2", "cp")))
  moved <- res$ledger
  moved$children[[2L]]$constraints$lhs <- "cp"
  expect_false(.sem_valid_mbco_outcome(moved, c("a2", "cp")))
})

test_that("a retained covariance-failed null validates", {
  fit <- mbco_root_fit(information = "expected")
  vcov <- .sem_vcov
  calls <- 0L
  testthat::local_mocked_bindings(.sem_vcov = function(...) {
    calls <<- calls + 1L
    if (calls == 1L) stop("injected null covariance failure")
    vcov(...)
  })
  expect_warning(res <- mbco_sem(fit, "a1", "b1"), "likelihood retained")
  node <- res$ledger$children[[2L]]
  expect_identical(node$covariance, "failed")
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a1", "b1")))
  forged <- res$ledger
  forged$children[[2L]]$post_fit <- NULL
  expect_false(.sem_valid_mbco_outcome(forged, c("a1", "b1")))
})

test_that("explicit n_starts and control overrides on the refits validate", {
  fit <- mbco_root_fit()
  res <- mbco_sem(fit, "a2", "cp", n_starts = 2L, control = list())
  expect_identical(res$ledger$children[[2L]]$context$settings$n_starts, 2L)
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a2", "cp")))
  mixed <- res$ledger
  mixed$children[[3L]]$context$settings$n_starts <- 7L
  expect_false(.sem_valid_mbco_outcome(mixed, c("a2", "cp")))
})

# --- tied to the call, and exact shapes for a failed null ----------------------------------------------------------

mbco_root_guard <- function() {
  set.seed(11)
  d <- data.frame(X = stats::rnorm(500))
  d$M <- 0.5 * d$X + stats::rnorm(500)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(500)
  d
}

test_that("a sandwich fit's MBCO result validates against the settings the refits used", {
  res <- suppressWarnings(mbco_sem(mbco_root_fit(se_type = "sandwich"), "a2", "cp", n_starts = 1L))
  root <- res$ledger
  expect_identical(root$context$settings$se_type, "sandwich")
  expect_identical(root$children[[2L]]$context$settings$se_type, "model")
  settings <- list(n_starts = 1L, control = list(), se_type = "model")
  expect_true(.sem_valid_mbco_outcome(root, c("a2", "cp"), settings = settings))
  # held to the call: other settings than the refits used are refused
  expect_false(.sem_valid_mbco_outcome(root, c("a2", "cp"), settings = replace(settings, "n_starts", 9L)))
  expect_false(.sem_valid_mbco_outcome(root, c("a2", "cp"), settings = replace(settings, "se_type", "sandwich")))
})

test_that("the ledger is tied to the returned table", {
  res <- mbco_sem(mbco_root_fit(), "a2", "cp", n_starts = 1L)
  root <- res$ledger
  paths <- c("a2", "cp")
  tests <- list(f = res$tests$f, converged = res$tests$converged)
  settings <- list(n_starts = 1L, control = list(), se_type = "model")
  expect_true(.sem_valid_mbco_outcome(root, paths, settings, tests))
  expect_false(.sem_valid_mbco_outcome(root, paths, settings, replace(tests, "f", list(tests$f + c(0, 1)))))
  expect_false(.sem_valid_mbco_outcome(root, paths, settings, replace(tests, "converged", list(c(TRUE, FALSE)))))
  moved <- root
  moved$children[[3L]]$likelihood$f <- moved$children[[3L]]$likelihood$f + 1
  expect_false(.sem_valid_mbco_outcome(moved, paths, settings, tests))
  # a null relabeled unresolved, with the root following, hides a resolved result from the table
  hidden <- root
  hidden$children[[2L]]$outcome <- "unresolved"
  hidden$outcome <- "unresolved"
  expect_false(.sem_valid_mbco_outcome(hidden, paths, settings, tests))
})

test_that("a failed null must have the exact shape of a failure, and nothing else is accepted", {
  fit <- suppressMessages(fit_sem("M ~ a*X\nY ~ b*M + cp*X\na > 0.3", mbco_root_guard()))
  res <- suppressWarnings(mbco_sem(fit, "a", "b"))
  root <- res$ledger
  paths <- c("a", "b")
  settings <- list(n_starts = 5L, control = list(), se_type = "model")
  tests <- list(f = res$tests$f, converged = res$tests$converged)
  check <- function(l) .sem_valid_mbco_outcome(l, paths, settings, tests)
  expect_identical(root$children[[2L]]$outcome, "unresolved")
  expect_true(check(root))
  edits <- list(
    syntax = function(n) replace(n, "context", list(replace(n$context, "model", list(list(syntax = "other"))))),
    n_obs = function(n) {
      n$context$n_obs <- 1L
      n
    },
    likelihood = function(n) {
      n$likelihood <- list(state = "available", f = 0)
      n
    },
    optimizer = function(n) {
      n$optimizer$state <- "accepted"
      n
    },
    feasibility = function(n) {
      n$feasibility <- "witness"
      n
    },
    covariance = function(n) {
      n$covariance <- "available"
      n
    },
    condition_removed = function(n) {
      n["condition"] <- list(NULL)
      n
    },
    children_garbage = function(n) {
      n$children <- list("junk")
      n
    },
    enumeration = function(n) {
      n$enumeration$required <- 5L
      n
    },
    notices = function(n) {
      n$notices <- NULL
      n
    },
    se_type = function(n) {
      n$context$settings$se_type <- c("model", "sandwich", "other")
      n
    },
    se_type_other = function(n) {
      n$context$settings$se_type <- "sandwich"
      n
    },
    id = function(n) {
      n$id <- "mbco/null:2"
      n
    },
    parent = function(n) {
      n$parent_id <- "elsewhere"
      n
    },
    domain = function(n) {
      n$context$domain$information <- "expected"
      n
    },
    parameters = function(n) {
      n$context$model$parameters <- data.frame(lhs = "a")
      n
    }
  )
  for (nm in names(edits)) {
    forged <- root
    forged$children[[2L]] <- edits[[nm]](root$children[[2L]])
    expect_false(check(forged), info = nm)
  }
  forged <- root
  forged$branch_map <- list(state = "forged")
  expect_false(check(forged))
})

test_that("a failed null that is a zero-product union with a failed branch validates, and forgeries of it do not", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  full <- suppressMessages(fit_sem(paste(mbco_root_model, "a1*b1 == 0", sep = "\n"), data, n_starts = 1L))
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed) && parsed$constraints$lhs[1] == "a1") stop("nested blocked")
    real(..., parsed = parsed)
  })
  res <- suppressWarnings(mbco_sem(full, "a1", "b1"))
  root <- res$ledger
  paths <- c("a1", "b1")
  expect_length(root$children[[2L]]$children, 2L)
  expect_true(.sem_valid_mbco_outcome(root, paths))
  edits <- list(
    id = function(n) replace(n, "id", "mbco/null:2"),
    branch_id = function(n) {
      n$children[[1L]]$id <- "elsewhere"
      n
    },
    branch_constraint = function(n) {
      n$children[[1L]]$constraints$lhs[1L] <- "b1"
      n
    },
    dropped_branch = function(n) {
      n$children <- n$children[1L]
      n
    },
    likelihood = function(n) {
      n$likelihood$state <- "unavailable"
      n
    },
    all_resolved = function(n) {
      n$children[[1L]]$outcome <- "resolved"
      n$children[[2L]]$outcome <- "resolved"
      n
    }
  )
  for (nm in names(edits)) {
    forged <- root
    forged$children[[2L]] <- edits[[nm]](root$children[[2L]])
    expect_false(.sem_valid_mbco_outcome(forged, paths), info = nm)
  }
})

# --- every way a null node is built: the genuine shape is accepted -------------------------------------------------

test_that("the genuine shapes of a null node are accepted: certified empty, empty union, typed and plain failures", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  paths <- c("a1", "b1")
  # a null that is directly infeasible (a literal contradiction): an excluded node
  direct <- suppressMessages(fit_sem(paste(mbco_root_model, "a1 == 1", sep = "\n"), data, n_starts = 1L))
  res <- suppressWarnings(mbco_sem(direct, "a1", "b1"))
  expect_identical(res$ledger$children[[2L]]$outcome, "excluded")
  expect_true(.sem_valid_mbco_outcome(res$ledger, paths))
  # a union whose every branch is certified empty, from the engine and as the typed error a refit raises
  model <- paste(mbco_root_model, "a1*b1 == 0\na1 == 1", sep = "\n")
  union <- suppressMessages(fit_sem(model, data, n_starts = 1L))
  res <- suppressWarnings(mbco_sem(union, "a1", "b1"))
  expect_true(.sem_valid_mbco_outcome(res$ledger, paths))
  empty <- tryCatch(fit_sem(paste(mbco_root_model, "a1*b1 == 0\na1 == 1\nb1 == 1", sep = "\n"), data, n_starts = 1L),
                    error = identity)
  expect_s3_class(empty, "medfit_sem_empty_union")
  fit <- suppressMessages(fit_sem(mbco_root_model, data, n_starts = 1L))
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) stop(empty))
  res <- suppressWarnings(mbco_sem(fit, paths = paths))
  node <- res$ledger$children[[2L]]
  expect_null(node$condition)
  expect_true(all(vapply(node$children, .sem_valid_exclusion, TRUE)))
  expect_true(.sem_valid_mbco_outcome(res$ledger, paths))
  # a forged empty union: a certificate that does not hold, a likelihood, a condition, a dropped branch
  edits <- list(
    constraint = function(n) {
      n$children[[1L]]$constraints$rhs[2L] <- "2"
      n
    },
    certificate = function(n) {
      n$children[[1L]]$certificate <- NULL
      n
    },
    likelihood = function(n) {
      n$likelihood <- list(state = "available", f = 0)
      n
    },
    condition = function(n) {
      n$condition <- list(message = "x")
      n
    },
    dropped = function(n) {
      n$children <- n$children[1L]
      n
    },
    id = function(n) replace(n, "id", "mbco/null:2")
  )
  for (nm in names(edits)) {
    forged <- res$ledger
    forged$children[[2L]] <- edits[[nm]](node)
    expect_false(.sem_valid_mbco_outcome(forged, paths), info = nm)
  }
})
