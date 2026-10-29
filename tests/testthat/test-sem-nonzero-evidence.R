.ev_out <- function() {
  set.seed(3)
  x <- stats::rnorm(180)
  m <- 0.5 * x + stats::rnorm(180, sd = 0.8)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(180, sd = 0.7)
  fit <- suppressWarnings(fit_sem("M ~ a*X\nY ~ b*M + cp*X\na*b == .4", data.frame(X = x, M = m, Y = y),
                                  fixed_x = FALSE, meanstructure = FALSE))
  c(list(theta = coef(fit), f = fit@f, data = fit@data, information = fit@information,
         se_type = fit@diagnostics$se_type, optimum = fit@diagnostics$optimum), fit@internals)
}

test_that("a forged original domain cannot prove a feasible branch empty", {
  out <- .ev_out()
  expect_true(.sem_validate_search(out))
  out$search_evidence$original_bounds$lower[1] <- 0
  box <- .sem_sign_bounds(out$search_evidence$spec, out$search_evidence$original_bounds$lower,
                          out$search_evidence$original_bounds$upper, -1)
  out$search_evidence$branches[[2]] <- list(sign = -1, signs = box$signs, lower = box$lower, upper = box$upper,
                                            state = "proved_empty", reason = "product_bound_contradiction")
  expect_error(.sem_validate_search(out), class = "medfit_error_search_evidence")
})

test_that("supported charted evidence cannot be relabeled as a local fallback", {
  out <- .ev_out()
  out$search_evidence$coverage <- "local"
  out$search_evidence$branches <- NULL
  expect_error(.sem_validate_search(out), class = "medfit_error_search_evidence")
})

test_that("accepted branch gates, attempt evidence and parent counts are required", {
  out <- .ev_out()
  for (field in c("gate", "optimum")) {
    bad <- out
    bad$search_evidence$branches[[1]][[field]] <- NULL
    expect_error(.sem_validate_search(bad), class = "medfit_error_search_evidence")
  }
  out$search_evidence$attempt_counts$n_starts <- 999L
  expect_error(.sem_validate_search(out), class = "medfit_error_search_evidence")
})

test_that("every branch objective belongs to its exact ordered candidate", {
  out <- .ev_out()
  other <- 3L - out$search_evidence$selected
  bad <- out
  bad$search_evidence$branches[[other]]$theta[["cp"]] <- 1e9
  expect_error(.sem_validate_search(bad), class = "medfit_error_search_evidence")
  bad <- out
  bad$search_evidence$branches[[other]]$theta <- c(bad$search_evidence$branches[[other]]$theta, extra = 0)
  expect_error(.sem_validate_search(bad), class = "medfit_error_search_evidence")
})

test_that("multiple disjoint product equalities use the local fallback including aliases", {
  ram <- list(par_names = c("a", "b", "c", "d"))
  cons <- data.frame(lhs = c("a*b", "c*d"), op = "==", rhs = c(".4", ".5"))
  expect_false(.sem_nonzero_product(cons, ram)$supported)
  cons <- data.frame(lhs = c("p", "p", "c*d"), op = c(":=", "==", "=="), rhs = c("a*b", ".4", ".5"))
  expect_false(.sem_nonzero_product(cons, ram)$supported)
})

test_that("selected branch coefficients and the reported minimum belong to the same candidate", {
  out <- .ev_out()
  expect_true(.sem_validate_search(out))
  evidence <- out$search_evidence
  other <- 3L - evidence$selected
  expect_gt(evidence$branches[[other]]$f, out$f + 0.1)
  out$search_evidence$selected <- other
  out$theta <- evidence$branches[[other]]$theta
  expect_error(.sem_validate_search(out), class = "medfit_error_search_evidence")
})

test_that("either selected branch is valid when accepted discrepancies tie", {
  out <- .ev_out()
  # An even toy objective gives the two genuine feasible sign candidates exactly the same discrepancy.
  local_mocked_bindings(.sem_fml = function(...) 0.5)
  out$f <- 0.5
  for (i in 1:2) {
    branch <- out$search_evidence$branches[[i]]
    branch$f <- 0.5
    for (j in seq_along(branch$attempts)) {
      if (branch$attempts[[j]]$accepted) branch$attempts[[j]]$f <- 0.5
    }
    n <- sum(vapply(branch$attempts, `[[`, TRUE, "accepted"))
    branch$optimum$spread <- if (n > 1L) 0 else NA_real_
    branch$optimum$status <- if (branch$optimum$certified) "certified" else if (n > 1L) "agreed" else "single"
    out$search_evidence$branches[[i]] <- branch
  }
  out$optimum$spread <- 0
  out$optimum$status <- "agreed"
  for (i in 1:2) {
    out$search_evidence$selected <- i
    out$theta <- out$search_evidence$branches[[i]]$theta
    expect_true(.sem_validate_search(out))
  }
})
