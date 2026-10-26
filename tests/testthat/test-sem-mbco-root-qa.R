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
    function(l) { l$children[[2L]]$id <- "mbco/null:2"; l },
    function(l) { l$children[[2L]]$parent_id <- "elsewhere"; l },
    function(l) { l$children[[2L]]$schema_version <- 2L; l },
    function(l) { l$children[[2L]]$constraints$lhs <- "b"; l },
    function(l) { l$children[[2L]]$context$sample_hash <- "forged"; l },
    function(l) { l$children[[2L]]$context$domain$weights <- stats::runif(500); l },
    function(l) { l$children[[2L]]$context$domain$information <- "expected"; l },
    function(l) { l$children[[2L]]$context$domain$fixed_x <- "X"; l },
    function(l) { l$outcome <- "resolved"; l }
  )) {
    expect_false(.sem_valid_mbco_outcome(edit(root), paths))
  }
})
