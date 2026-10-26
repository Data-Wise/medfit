# QA oracle for the MBCO root ledger validator: genuine results are never refused (the reference is the same call on
# origin/dev, which has no validator), and forged roots are refused. Planted defects: see the QA report.

qa_data <- function(n = 500, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = stats::rnorm(n))
  d$M <- 0.5 * d$X + stats::rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(n)
  d
}
qa_base <- "M ~ a*X\nY ~ b*M + cp*X"
qa_fit <- function(syntax = qa_base, ...) suppressMessages(fit_sem(syntax, qa_data(), n_starts = 1L, ...))

test_that("genuine MBCO results are never refused by the root validator", {
  cases <- list(
    plain = function() mbco_sem(qa_fit(), "a", "b"),
    kpath = function() mbco_sem(qa_fit(), paths = c("a", "b", "cp")),
    inequality = function() mbco_sem(qa_fit(paste0(qa_base, "\nb + cp < 5")), "a", "b"),
    equality = function() mbco_sem(qa_fit(paste0(qa_base, "\nb == cp")), "a", "b"),
    boundary = function() mbco_sem(qa_fit(paste0(qa_base, "\na > 0")), "a", "b"),
    fixed_x_true = function() mbco_sem(qa_fit(fixed_x = TRUE), "a", "b"),
    fixed_x_false = function() mbco_sem(qa_fit(fixed_x = FALSE), "a", "b"),
    meanstructure = function() mbco_sem(qa_fit(meanstructure = TRUE), "a", "b"),
    expected_information = function() mbco_sem(qa_fit(information = "expected"), "a", "b"),
    override = function() mbco_sem(qa_fit(), "a", "b", n_starts = 2L, control = list())
  )
  for (nm in names(cases)) {
    res <- tryCatch(suppressWarnings(cases[[nm]]()), error = function(e) e)
    expect_s3_class(res, "mbco_sem")
  }
})

test_that("a sandwich fit's MBCO result (null refits are model-based) is not refused", {
  # the nulls are refit with se_type = "model" while the root records "sandwich"; both are genuine
  res <- tryCatch(suppressWarnings(mbco_sem(qa_fit(se_type = "sandwich"), "a", "b")), error = function(e) e)
  expect_s3_class(res, "mbco_sem")
})

test_that("an unresolved null (outside the parameter space) is returned, not refused", {
  res <- suppressWarnings(mbco_sem(qa_fit(paste0(qa_base, "\na > 0.3")), "a", "b"))
  expect_true(is.na(res$statistic))
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a", "b")))
})

test_that("forged roots are refused: ids, branch map, domain and parent of each null", {
  fit <- qa_fit()
  res <- mbco_sem(fit, "a", "b")
  root <- res$ledger
  paths <- c("a", "b")
  expect_true(.sem_valid_mbco_outcome(root, paths))
  forged <- root
  forged$branch_map <- "forged"
  expect_false(.sem_valid_mbco_outcome(forged, paths))
  forged <- root
  forged$children[[3L]]$parent_id <- "elsewhere"
  expect_false(.sem_valid_mbco_outcome(forged, paths))
  forged <- root
  forged$children[[3L]]$context$domain$weights <- 1
  expect_false(.sem_valid_mbco_outcome(forged, paths))
  forged <- root
  forged$children[[2L]]$context$domain$meanstructure <- TRUE
  expect_false(.sem_valid_mbco_outcome(forged, paths))
})

test_that("forged failed nulls are refused where the validator claims to check them", {
  fit <- qa_fit(paste0(qa_base, "\na > 0.3"))
  res <- suppressWarnings(mbco_sem(fit, "a", "b"))
  root <- res$ledger
  paths <- c("a", "b")
  expect_identical(root$children[[2L]]$outcome, "unresolved")
  expect_true(.sem_valid_mbco_outcome(root, paths))
  for (edit in list(
    function(l) {
      l$children[[2L]]$id <- "mbco/null:2"
      l
    },
    function(l) {
      l$children[[2L]]$parent_id <- "elsewhere"
      l
    },
    function(l) {
      l$children[[2L]]$schema_version <- 2L
      l
    },
    function(l) {
      l$children[[2L]]$constraints$lhs <- "b"
      l
    },
    function(l) {
      l$children[[2L]]$context$sample_hash <- "forged"
      l
    },
    function(l) {
      l$children[[2L]]$context$domain$weights <- stats::runif(500)
      l
    },
    function(l) {
      l$children[[2L]]$context$domain$information <- "expected"
      l
    },
    function(l) {
      l$children[[2L]]$context$domain$fixed_x <- "X"
      l
    },
    function(l) {
      l$outcome <- "resolved"
      l
    }
  )) {
    expect_false(.sem_valid_mbco_outcome(edit(root), paths))
  }
})

test_that("with the call's settings and table, a shifted null f or a uniform n_starts rewrite is refused", {
  res <- mbco_sem(qa_fit(), "a", "b")
  root <- res$ledger
  paths <- c("a", "b")
  st <- list(n_starts = root$children[[2L]]$context$settings$n_starts, control = list(), se_type = "model")
  tt <- list(f = res$tests$f, converged = res$tests$converged)
  expect_true(.sem_valid_mbco_outcome(root, paths, st, tt, "model"))
  shifted <- root
  shifted$children[[2L]]$likelihood$f <- shifted$children[[2L]]$likelihood$f + 1
  expect_false(.sem_valid_mbco_outcome(shifted, paths, st, tt, "model"))
  rewritten <- root
  for (i in 2:3) rewritten$children[[i]]$context$settings$n_starts <- 99L
  expect_false(.sem_valid_mbco_outcome(rewritten, paths, st, tt, "model"))
})

test_that("union-null shapes from the engine are accepted: resolved branches, an excluded branch, a failed-covariance branch", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  base <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
  fit <- function(extra, ...) suppressMessages(fit_sem(paste0(base, extra), data, n_starts = 1L, ...))
  res <- suppressWarnings(mbco_sem(fit("\nb1*b2 == 0"), "a1", "cp"))
  expect_true(all(vapply(res$ledger$children, function(k) length(k$children) == 2L, TRUE)))
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a1", "cp")))
  res <- suppressWarnings(mbco_sem(fit("\na1*cp == 0\nb1 == 1"), "a1", "a2"))
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a1", "a2")))
  f <- fit("\nb1*b2 == 0", information = "expected")
  vcov <- .sem_vcov
  calls <- 0L
  testthat::local_mocked_bindings(.sem_vcov = function(...) {
    calls <<- calls + 1L
    if (calls == 2L) stop("injected branch covariance failure")
    vcov(...)
  })
  res <- suppressWarnings(mbco_sem(f, "a1", "cp"))
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a1", "cp")))
})

test_that("an empty-union null is tied to the table and holds its branches in order", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  base <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
  empty <- tryCatch(fit_sem(paste0(base, "\na1*b1 == 0\na1 == 1\nb1 == 1"), data, n_starts = 1L), error = identity)
  fit <- suppressMessages(fit_sem(base, data, n_starts = 1L))
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) stop(empty))
  res <- suppressWarnings(mbco_sem(fit, paths = c("a1", "b1")))
  root <- res$ledger
  paths <- c("a1", "b1")
  st <- list(n_starts = 1L, control = list(), se_type = "model")
  tt <- list(f = res$tests$f, converged = res$tests$converged)
  expect_true(.sem_valid_mbco_outcome(root, paths, st, tt, fit@diagnostics$se_type))
  # the table says the null converged, or the root is called resolved: the empty node is refused
  expect_false(.sem_valid_mbco_outcome(root, paths, st, list(f = res$tests$f, converged = c(TRUE, TRUE)),
                                       fit@diagnostics$se_type))
  resolved <- root
  resolved$outcome <- "resolved"
  expect_false(.sem_valid_mbco_outcome(resolved, paths, st, tt, fit@diagnostics$se_type))
  # branches swapped (ids repaired): each branch must be the one its position names
  swapped <- root
  kids <- swapped$children[[2L]]$children
  swapped$children[[2L]]$children <- kids[2:1]
  swapped$children[[2L]]$children[[1L]]$id <- kids[[1L]]$id
  swapped$children[[2L]]$children[[2L]]$id <- kids[[2L]]$id
  expect_false(.sem_valid_mbco_outcome(swapped, paths))
  # a branch dropped with the enumeration repaired: the raw count of the zero products still requires both
  short <- root
  short$children[[2L]]$children <- short$children[[2L]]$children[1L]
  short$children[[2L]]$enumeration <- list(state = "complete", required = 1L)
  expect_false(.sem_valid_mbco_outcome(short, paths))
})
