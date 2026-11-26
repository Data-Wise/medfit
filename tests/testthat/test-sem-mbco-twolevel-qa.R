skip_on_cran()  # long run: skipped on CRAN to keep the check short; runs in GitHub CI and with NOT_CRAN=true
skip_if_not_installed("lavaan")

# IG3 T-A independent QA: mbco_sem() on native two-level fits against lavaan two-level fits with each linear null
# (`p == 0`) fitted separately, never the product constraint (#320). TL-4 rule: 1e-6 absolute on each log-likelihood
# difference. The fixtures differ from the implementer's (unbalanced clusters, a cluster column with another name and
# character labels, an over-identified model, a k = 3 serial product), so a refit whose cluster ids are not aligned
# with the rows (which a balanced, contiguous fixture cannot detect) is caught.

tlq_lavaan_dll <- function(model, data, con, cl) {
  free <- suppressWarnings(lavaan::sem(model, data, cluster = cl, fixed.x = FALSE))
  null <- suppressWarnings(lavaan::sem(paste0(model, "\n", con), data, cluster = cl, fixed.x = FALSE))
  expect_true(lavaan::lavInspect(free, "converged") && lavaan::lavInspect(null, "converged"))
  as.numeric(lavaan::logLik(free)) - as.numeric(lavaan::logLik(null))
}

tlq_check <- function(model, data, paths, level, cl = "cluster") {
  fit <- suppressWarnings(fit_sem(model, data, cluster = cl))
  res <- mbco_sem(fit, paths = paths)
  expect_false(res$unresolved)
  expect_identical(res$level, level)
  expect_identical(res$n_clusters, length(unique(data[[cl]])))
  expect_identical(res$tests$constraint, paste(paths, "== 0"))
  ref <- vapply(paths, function(p) tlq_lavaan_dll(model, data, paste(p, "== 0"), cl), 0)
  expect_lt(max(abs(res$tests$diff_ll / 2 - ref)), 1e-6)
  expect_lt(abs(unname(res$statistic) / 2 - min(ref)), 1e-6)
  ref
}

test_that("two-level MBCO matches lavaan on unbalanced clusters with a renamed, character cluster column", {
  data <- tl_data_unbalanced()
  data$school <- paste0("s", 7L * data$cluster)
  data$cluster <- NULL
  within <- tlq_check(tl_lavaan_model, data, c("a_w", "b_w"), "within", "school")
  between <- tlq_check(tl_lavaan_model, data, c("a_b", "b_b"), "between", "school")
  # the minimum sits on the second branch within and on the first between, and the branches are far apart, so a
  # maximum or a fixed branch index is caught
  expect_gt(within[1L] - within[2L], 5)
  expect_gt(between[2L] - between[1L], 5)
})

test_that("two-level MBCO matches lavaan on an over-identified model and a k = 3 within-level serial product", {
  m3 <- "
level: 1
  M ~ a_w*X
  Y ~ b_w*M + cp_w*X
level: 2
  M ~ a_b*X
  Y ~ b_b*M
"
  d3 <- tl_simulate(rep(c(4, 7, 10), 15), seed = 77)
  tlq_check(m3, d3, c("a_w", "b_w"), "within")
  tlq_check(m3, d3, c("a_b", "b_b"), "between")

  withr::local_seed(5)
  j <- 35
  cl <- rep(seq_len(j), sample(3:9, j, TRUE))
  n <- length(cl)
  ub <- matrix(stats::rnorm(j * 4, sd = 0.6), j)
  x <- ub[cl, 1] + stats::rnorm(n)
  m1 <- 0.5 * x + ub[cl, 2] + stats::rnorm(n)
  m2 <- 0.2 * m1 + ub[cl, 3] + stats::rnorm(n)
  y <- 0.4 * m2 + 0.1 * x + ub[cl, 4] + stats::rnorm(n)
  d4 <- data.frame(cluster = cl, X = x, M1 = m1, M2 = m2, Y = y)
  m4 <- "
level: 1
  M1 ~ a*X
  M2 ~ d*M1
  Y ~ b*M2 + X
level: 2
  M1 ~ X
  M2 ~ M1
  Y ~ M2 + X
"
  ref <- tlq_check(m4, d4, c("a", "d", "b"), "within")
  # the minimum is the middle branch
  expect_identical(unname(which.min(ref)), 2L)
})

test_that("the inadmissible failed-null shape is accepted only under a two-level root", {
  fit <- fit_sem(tl_lavaan_model, tl_data_balanced(), cluster = "cluster")
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    r <- real(model, ...)
    if (!is.null(model) && endsWith(model, "\na_b == 0")) {
      r$improper <- "Y~~Y (level 2) = -0.2"
      r$admissibility <- list(level2 = FALSE)
      cnd <- rlang::error_cnd("medfit_error_twolevel_inadmissible", fit = r, improper = r$improper,
                              message = "the two-level solution is inadmissible: injected")
      cnd$ledger <- .sem_outcome(r$ledger$context, r$ledger$constraints, r, error = cnd)
      stop(cnd)
    }
    r
  })
  res <- suppressWarnings(mbco_sem(fit, "a_b", "b_b"))
  expect_true(res$unresolved)
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a_b", "b_b")))
  # the same ledger rewritten as single-level (no two-level marks, no admissibility records) except the inadmissible
  # null node: every other check passes, so only the two-level-root rule refuses it
  strip <- function(node) {
    node$context$twolevel <- NULL
    node$admissibility <- NULL
    node$children <- lapply(node$children, strip)
    node
  }
  single <- strip(res$ledger)
  bad <- vapply(single$children, function(ch) identical(ch$condition$class[1L], "medfit_error_twolevel_inadmissible"),
                TRUE)
  expect_identical(sum(bad), 1L)
  single$children[bad] <- lapply(res$ledger$children[bad], function(ch) {
    ch$context$twolevel <- NULL
    ch
  })
  expect_false(.sem_valid_mbco_outcome(single, c("a_b", "b_b")))
})
