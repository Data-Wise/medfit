test_that("an indefinite reference covariance is rejected even with positive directional variance", {
  spec <- list(coefficient = 2, target = 1, labels = c("a", "b"))
  covariance <- matrix(c(1, 2, 2, 1), 2L, dimnames = list(c("a", "b"), c("a", "b")))
  # Positive diagonals and a positive gradient variance do not make a covariance positive semidefinite.
  expect_true(all(diag(covariance) >= 0))
  expect_equal(drop(crossprod(c(1, -1), covariance %*% c(1, -1))), -2)
  expect_equal(drop(crossprod(c(6, 4), covariance %*% c(6, 4))), 148)
  reference <- list(theta = c(a = 2, b = 3), vcov = covariance, context = "same")
  diagnostic <- .sem_reference_residual(c(a = 1, b = 0.5), spec, reference, context = "same")
  expect_identical(diagnostic$reason, "reference_covariance_invalid")
  expect_true(is.na(diagnostic$se_reference))
  expect_true(is.na(diagnostic$standardized))
})

test_that("accepted attempt evidence validates certified, single and disagreed statuses", {
  accepted <- function(f, source = "start") {
    list(accepted = TRUE, status = 1L, decrement = 0, f = f, source = source)
  }
  cases <- list(
    certified = list(attempts = list(accepted(0.4), accepted(0.2, "reference")),
                     starts = 1L, accepted = 1L, synthetic = 1L, spread = 0.2),
    single = list(attempts = list(accepted(0.2), list(accepted = FALSE, source = "start")),
                  starts = 2L, accepted = 1L, synthetic = 0L, spread = NA_real_),
    disagreed = list(attempts = list(accepted(0.2), accepted(0.4)),
                     starts = 2L, accepted = 2L, synthetic = 0L, spread = 0.2)
  )
  expect_gt(0.2, .sem_spread_tol)
  for (status in names(cases)) {
    case <- cases[[status]]
    branch <- list(f = 0.2, attempts = case$attempts,
                   gate = list(accepted = TRUE, status = 1L, decrement = 0),
                   optimum = list(n_starts = case$starts, n_accepted = case$accepted, best_of = TRUE,
                                  certified = status == "certified", spread = case$spread, status = status))
    evidence <- .sem_search_attempts(branch)
    expect_identical(evidence$counts, list(n_starts = case$starts, n_accepted = case$accepted,
                                           synthetic = case$synthetic))
    expect_identical(min(evidence$values), 0.2)
    branch$optimum$status <- "agreed"
    expect_error(.sem_search_attempts(branch), "branch\\$optimum\\$status")
  }
})
