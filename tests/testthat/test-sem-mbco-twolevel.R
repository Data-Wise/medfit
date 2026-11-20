skip_if_not_installed("lavaan")

# IG3 T-A: mbco_sem() on a native two-level fit tests the product null at one level (a_w * b_w = 0 within,
# a_b * b_b = 0 between). Each null is refit as a linear branch (a path set to 0) with the cluster routed into the
# refit; the statistic is the smallest branch LR. Oracle: lavaan two-level fits with each linear constraint separately
# (never the product constraint itself, #320), the LR being 2 x the log-likelihood difference; TL-4 rule, 1e-6
# absolute on the log-likelihood difference.

tlm_fit <- function(data = tl_data_balanced()) fit_sem(tl_lavaan_model, data, cluster = "cluster")

# lavaan's log-likelihood difference (free minus constrained) for one linear null, with its convergence flag.
tlm_lavaan_dll <- function(data, con) {
  free <- tl_fit_lavaan(data)
  null <- suppressWarnings(lavaan::sem(paste0(tl_lavaan_model, "\n", con), data, cluster = "cluster",
                                       fixed.x = FALSE))
  list(dll = as.numeric(lavaan::logLik(free)) - as.numeric(lavaan::logLik(null)),
       converged = lavaan::lavInspect(free, "converged") && lavaan::lavInspect(null, "converged"))
}

tlm_check_oracle <- function(res, data, paths) {
  dll <- numeric(length(paths))
  for (i in seq_along(paths)) {
    ref <- tlm_lavaan_dll(data, paste(paths[i], "== 0"))
    expect_true(ref$converged)
    dll[i] <- ref$dll
    expect_identical(res$tests$constraint[i], paste(paths[i], "== 0"))
    expect_lt(abs(res$tests$diff_ll[i] / 2 - ref$dll), 1e-6)
  }
  # the statistic is the smaller branch LR, never the larger
  expect_lt(abs(unname(res$statistic) / 2 - min(dll)), 1e-6)
  expect_equal(unname(res$p.value), stats::pchisq(unname(res$statistic), df = 1, lower.tail = FALSE),
               tolerance = 1e-12)
  invisible(dll)
}

test_that("within-level MBCO on a native two-level fit matches lavaan's branch refits", {
  data <- tl_data_balanced()
  res <- mbco_sem(tlm_fit(data), "a_w", "b_w")
  expect_s3_class(res, c("mbco_sem", "htest"))
  expect_false(res$unresolved)
  expect_identical(res$level, "within")
  expect_identical(res$n_clusters, 40L)
  expect_identical(res$n_obs, 240L)
  dll <- tlm_check_oracle(res, data, c("a_w", "b_w"))
  # the fixture separates the two branches, so a maximum in place of the minimum is caught
  expect_gt(abs(diff(dll)), 1)
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a_w", "b_w")))
})

test_that("between-level MBCO on a native two-level fit matches lavaan's branch refits", {
  data <- tl_data_balanced()
  res <- mbco_sem(tlm_fit(data), "a_b", "b_b")
  expect_false(res$unresolved)
  expect_identical(res$level, "between")
  expect_identical(res$n_clusters, 40L)
  dll <- tlm_check_oracle(res, data, c("a_b", "b_b"))
  expect_gt(abs(diff(dll)), 1)
  # the between statistic differs from the within one: a wrong level label is caught
  within <- mbco_sem(tlm_fit(data), "a_w", "b_w")
  expect_gt(abs(unname(within$statistic) - unname(res$statistic)), 1)
})

test_that("MBCO on a two-level fit is invariant to cluster labels, row order and argument order", {
  data <- tl_data_balanced()
  base <- mbco_sem(tlm_fit(data), "a_w", "b_w")
  base_b <- mbco_sem(tlm_fit(data), "a_b", "b_b")
  relabeled <- data
  withr::with_seed(3, {
    ids <- sample(1000:9999, 40)
  })
  relabeled$cluster <- paste0("c", ids[data$cluster])
  reordered <- withr::with_seed(4, data[sample(nrow(data)), ])
  for (d in list(relabeled, reordered)) {
    res <- mbco_sem(tlm_fit(d), "a_w", "b_w")
    expect_lt(abs(unname(res$statistic) - unname(base$statistic)), 1e-6)
    res_b <- mbco_sem(tlm_fit(d), "a_b", "b_b")
    expect_lt(abs(unname(res_b$statistic) - unname(base_b$statistic)), 1e-6)
  }
  swapped <- mbco_sem(tlm_fit(data), "b_w", "a_w")
  expect_lt(abs(unname(swapped$statistic) - unname(base$statistic)), 1e-6)
  expect_identical(swapped$tests$constraint, c("b_w == 0", "a_w == 0"))
})

test_that("rows dropped listwise keep the cluster ids aligned in the two-level refits", {
  data <- tl_data_balanced()
  data$M[c(3, 50, 121)] <- NA
  data$Y[c(7, 200)] <- NA
  res <- mbco_sem(tlm_fit(data), "a_w", "b_w")
  expect_identical(res$n_obs, 235L)
  expect_false(res$unresolved)
  tlm_check_oracle(res, data, c("a_w", "b_w"))
  res_b <- mbco_sem(tlm_fit(data), "a_b", "b_b")
  tlm_check_oracle(res_b, data, c("a_b", "b_b"))
})

test_that("a product of a within and a between path is refused with a classed error", {
  fit <- tlm_fit()
  err <- expect_error(mbco_sem(fit, "a_w", "b_b"), class = "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "one level", fixed = TRUE)
  expect_error(mbco_sem(fit, paths = c("a_b", "b_w")), class = "medfit_error_twolevel_unsupported")
})

test_that("a branch refit that fails leaves the two-level MBCO result unresolved, never a number", {
  fit <- tlm_fit()
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    if (!is.null(model) && endsWith(model, "\nb_w == 0")) {
      stop(.sem_no_convergence("injected null failure"))
    }
    real(model, ...)
  })
  expect_warning(res <- mbco_sem(fit, "a_w", "b_w"), "injected null failure")
  expect_true(res$unresolved)
  expect_true(is.na(res$statistic))
  expect_true(is.na(res$p.value))
  expect_identical(res$tests$converged, c(TRUE, FALSE))
  expect_identical(res$ledger$outcome, "unresolved")
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a_w", "b_w")))
})

test_that("a two-level null refit that fails in the engine keeps a valid ledger and an unresolved result", {
  # the failure is raised inside the pipeline, so `.sem_fit_syntax()` builds the failed node's ledger from its entry
  # context (the gates' 16 non-converged size-study reps took this path and were refused as a malformed ledger)
  fit <- tlm_fit()
  real <- .sem_fit_pipeline
  testthat::local_mocked_bindings(.sem_fit_pipeline = function(model, ...) {
    if (!is.null(model) && endsWith(model, "\na_w == 0")) {
      stop(.sem_no_convergence("injected engine failure"))
    }
    real(model, ...)
  })
  expect_warning(res <- mbco_sem(fit, "a_w", "b_w"), "injected engine failure")
  expect_true(res$unresolved)
  expect_true(is.na(res$statistic))
  expect_identical(res$tests$converged, c(FALSE, TRUE))
  expect_identical(res$ledger$outcome, "unresolved")
  failed <- res$ledger$children[[2L]]
  expect_identical(failed$id, "mbco/null:1")
  expect_identical(failed$condition$class[1L], "medfit_error_no_convergence")
  # the failed node holds the fit's rows (no cluster column, as a resolved node) and the two-level mark
  expect_identical(failed$context[["sample"]] %||% res$ledger$context[["sample"]], fit@data)
  expect_true(isTRUE(failed$context$twolevel))
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a_w", "b_w")))
})

test_that("an inadmissible two-level null refit is an unresolved row with a classed warning, never a number", {
  fit <- tlm_fit()
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    r <- real(model, ...)
    if (!is.null(model) && endsWith(model, "\na_b == 0")) {
      # the real refit, declared inadmissible the way the fit route declares it: same optimum, a failed level
      r$improper <- "Y~~Y (level 2) = -0.2"
      r$admissibility <- list(level2 = FALSE)
      cnd <- rlang::error_cnd("medfit_error_twolevel_inadmissible", fit = r, improper = r$improper,
                              message = "the two-level solution is inadmissible: injected")
      cnd$ledger <- .sem_outcome(r$ledger$context, r$ledger$constraints, r, error = cnd)
      stop(cnd)
    }
    r
  })
  w <- NULL
  res <- withCallingHandlers(mbco_sem(fit, "a_b", "b_b"), medfit_warning_twolevel_inadmissible = function(cnd) {
    w <<- cnd
    invokeRestart("muffleWarning")
  })
  expect_s3_class(w, "medfit_warning_twolevel_inadmissible")
  expect_match(conditionMessage(w), "a_b == 0", fixed = TRUE)
  expect_match(conditionMessage(w), "Y~~Y (level 2) = -0.2", fixed = TRUE)
  expect_true(res$unresolved)
  expect_true(is.na(res$statistic))
  expect_true(is.na(res$p.value))
  # the admissible branch keeps its row, but the statistic is never its LR alone
  expect_identical(res$tests$converged, c(FALSE, TRUE))
  expect_true(is.na(res$tests$f[1L]))
  expect_true(is.finite(res$tests$diff_ll[2L]))
  expect_match(res$tests$note[1L], "inadmissible", fixed = TRUE)
  expect_identical(res$ledger$children[[2L]]$condition$class[1L], "medfit_error_twolevel_inadmissible")
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a_b", "b_b")))
})

test_that("the model page's within test is unresolved: its b_w == 0 refit is inadmissible", {
  set.seed(2026)
  j <- 100
  n <- 5
  id <- rep(seq_len(j), each = n)
  xb <- stats::rnorm(j)[id]
  xw <- stats::rnorm(j * n)
  x <- xb + xw
  m <- 0.4 * xw + 0.7 * xb + 0.5 * stats::rnorm(j)[id] + stats::rnorm(j * n)
  mbar <- stats::ave(m, id)
  y <- 0.3 * xw + 0.2 * xb + 0.5 * (m - mbar) + 0.9 * mbar + 0.5 * stats::rnorm(j)[id] + stats::rnorm(j * n)
  d <- data.frame(id = id, X = x, M = m, Y = y)
  model <- "
    level: 1
      M ~ a_w*X
      Y ~ b_w*M + X
    level: 2
      M ~ a_b*X
      Y ~ b_b*M + X
  "
  fit <- fit_sem(model, data = d, cluster = "id")
  expect_warning(res <- mbco_sem(fit, "a_w", "b_w"), class = "medfit_warning_twolevel_inadmissible")
  expect_true(res$unresolved)
  expect_true(is.na(res$statistic))
  expect_identical(res$tests$converged, c(TRUE, FALSE))
  expect_identical(res$ledger$outcome, "unresolved")
  node <- res$ledger$children[[3L]]
  expect_identical(node$id, "mbco/null:2")
  expect_identical(node$condition$class[1L], "medfit_error_twolevel_inadmissible")
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a_w", "b_w")))
  # the between test on the same data keeps its number
  between <- mbco_sem(fit, "a_b", "b_b")
  expect_false(between$unresolved)
  expect_equal(unname(between$statistic), 19.73, tolerance = 0.005 / 19.73)
  expect_identical(between$n_clusters, 100L)
})

# A fixture whose between-level residual variance of Y is small but positive: at the `a_w == 0` refit Y~~Y.l2 is about
# 0.16% of Y's implied between + within variance (six times below the 1% rule), so the null sits near a level-2
# variance boundary, where chi-square(1) is not the law.
tlm_small_between <- function() {
  withr::local_seed(6) # sd 0.2 below: the fit and every branch refit are admissible
  j <- 40
  cl <- rep(seq_len(j), each = 6)
  xb <- stats::rnorm(j)
  mb <- 0.5 * xb + stats::rnorm(j, sd = 0.6)
  yb <- 0.3 * mb + 0.2 * xb + stats::rnorm(j, sd = 0.2)
  x <- xb[cl] + stats::rnorm(length(cl))
  m <- mb[cl] + 0.4 * x + stats::rnorm(length(cl))
  y <- yb[cl] + 0.3 * m + 0.1 * x + stats::rnorm(length(cl))
  data.frame(cluster = cl, X = x, M = m, Y = y)
}

test_that("a near-zero level-2 variance at a null refit raises the boundary warning", {
  fit <- tlm_fit(tlm_small_between())
  expect_warning(res <- mbco_sem(fit, "a_w", "b_w"), "level-2 variance")
  expect_false(res$unresolved)
  warned <- vapply(res$ledger$children[-1L], function(n) {
    any(grepl("level-2 variance", vapply(n$notices$warnings, function(w) w$message, ""), fixed = TRUE))
  }, TRUE)
  expect_true(any(warned))
})

test_that("the level-2 boundary rule cuts at the threshold on the between + within (ICC) base", {
  fit <- tlm_fit(tlm_small_between())
  caught <- list()
  real <- .mbco_warn_level2_boundary
  testthat::local_mocked_bindings(.mbco_warn_level2_boundary = function(refit, con) {
    caught[[con]] <<- refit
    real(refit, con)
  })
  suppressWarnings(mbco_sem(fit, "a_w", "b_w"))
  r <- caught[["a_w == 0"]]
  # independent base: the implied level-2 and level-1 variances of Y, summed as the ICC denominator
  mom <- .sem_twolevel_implied(r$ram, unname(r$theta))
  row <- which(r$table$level == 2L & r$table$op == "~~" & r$table$lhs == "Y" & r$table$rhs == "Y")
  ratio <- r$theta[r$par_map[row]] / (mom$sigma_b["Y", "Y"] + mom$sigma_w["Y", "Y"])
  expect_lt(ratio, 0.01)
  expect_true("Y" %in% .mbco_level2_near_zero(r, threshold = ratio * 1.01))
  expect_false("Y" %in% .mbco_level2_near_zero(r, threshold = ratio * 0.99))
  # the default threshold is 1%
  expect_identical(.mbco_level2_near_zero(r), .mbco_level2_near_zero(r, threshold = 0.01))
})

test_that("no boundary warning when every level-2 variance is away from zero", {
  expect_no_warning(mbco_sem(tlm_fit(), "a_w", "b_w"))
  expect_no_warning(mbco_sem(tlm_fit(), "a_b", "b_b"))
})

test_that("a single-level MBCO result carries no two-level fields", {
  fit <- suppressWarnings(fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment",
                                  data = mediation_demo, fixed_x = FALSE))
  res <- mbco_sem(fit, "a", "b")
  expect_null(res$level)
  expect_null(res$n_clusters)
})

test_that("compare_lr() refuses a native two-level fit with a classed error (two-level compare_lr is deferred)", {
  err <- expect_error(compare_lr(tlm_fit(), c("a_w", "b_w")), class = "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "compare_lr()", fixed = TRUE)
  expect_no_match(conditionMessage(err), "not implemented yet", fixed = TRUE)
})

test_that("fits the two-level guard refuses never reach mbco_sem(): weights, fiml and products are classed errors", {
  data <- tl_data_balanced()
  expect_error(fit_sem(tl_lavaan_model, data, cluster = "cluster", weights = rep(1, nrow(data))),
               class = "medfit_error_twolevel_weights")
  expect_error(fit_sem(tl_lavaan_model, data, cluster = "cluster", missing = "fiml"),
               class = "medfit_error_twolevel_missing")
  expect_error(fit_sem(paste(tl_lavaan_model, "  Y ~ X:M", sep = "\n"), data, cluster = "cluster"),
               class = "medfit_error_twolevel_product")
  expect_error(fit_sem(paste(tl_lavaan_model, "a_w*b_w == 0", sep = "\n"), data, cluster = "cluster"),
               class = "medfit_error_twolevel_nonlinear")
})
