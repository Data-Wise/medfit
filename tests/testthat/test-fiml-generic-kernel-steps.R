# FI-G0c steps S and E: variance indices, bounds, starts, the solver unit matrix, and the evaluation loops. Each
# change has a hand-written contract and planted defects (spec section 5).

test_that("FIML starts, bounds and variance indices equal the hand-written contract", {
  for (direct in c(TRUE, FALSE)) {
    p <- .sem_fiml_prepare(gk_data("all7"), direct = direct)
    nm <- p$ram$par_names
    variance <- c("vx", "vm", "vy")
    expect_identical(nm[.sem_fiml_variance_index(p$layout, nm)], variance)
    initial <- stats::setNames(c(rep(0, length(nm) - 6L), 1, 1, 1, 0, 0, 0), nm)
    k <- seq_along(nm)
    expect_identical(.sem_fiml_starts(p$layout, nm),
                     list(initial, initial + .12 * sin(k), initial - .15 * cos(k)))
    lower <- ifelse(nm %in% variance, 1e-10, -Inf)
    expect_identical(.sem_fiml_lower(p$layout, nm), unname(lower))
  }
})

test_that("the Hessian caps every variance step, and planted start/bound/cap defects are caught", {
  fx_skip_covr()
  d <- gk_data("all7")
  p <- .sem_fiml_prepare(d, direct = TRUE)
  th <- gk_theta(TRUE, 2L)[p$ram$par_names]
  th[c("vx", "vm", "vy")] <- c(4e-6, 5e-6, 6e-6)
  H <- .sem_fiml_hessian(th, p)
  expect_true(all(is.finite(H)))
  expect_equal(H, t(H), tolerance = 1e-12)
  # Without the cap on every variance a step overshoots zero and the perturbation is refused.
  nocap <- sem_mutate(.sem_fiml_variance_index, "match(layout$variances$par, par_names)",
                      "match(layout$variances$par[1], par_names)")
  expect_error(testthat::with_mocked_bindings(.sem_fiml_hessian(th, p), .sem_fiml_variance_index = nocap),
               "invalid Hessian perturbation")
  nm <- p$ram$par_names
  s1 <- sem_mutate(.sem_fiml_starts, "initial[layout$variances$par] <- 1", "initial[layout$variances$par] <- 0")
  expect_false(identical(s1(p$layout, nm), .sem_fiml_starts(p$layout, nm)))
  l1 <- sem_mutate(.sem_fiml_lower, "1e-10", "0")
  expect_false(identical(l1(p$layout, nm), .sem_fiml_lower(p$layout, nm)))
  # A wrong unit matrix for the solver changes (or breaks) the fit.
  good <- .sem_fiml_fit(d, direct = TRUE)
  f1 <- sem_mutate(.sem_fiml_fit, "diag(length(p$layout$vars))", "diag(2)")
  # The wrong-sized matrix leaves the solution unchanged but is signaled by the step-floor code with warnings.
  warned <- FALSE
  bad <- withCallingHandlers(tryCatch(f1(d, direct = TRUE), error = identity),
                             warning = function(w) {
                               warned <<- TRUE
                               invokeRestart("muffleWarning")
                             })
  expect_true(warned || inherits(bad, "error") || max(abs(bad$estimate - good$estimate)) > 1e-8 ||
                !identical(bad$attempts$status, good$attempts$status))
  # The good fit is warning-free.
  expect_no_warning(.sem_fiml_fit(d, direct = TRUE))
})
