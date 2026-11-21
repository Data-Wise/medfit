# IG3 T-B: twolevel_equal_indirect() is the likelihood-ratio test of equal indirect effects across the two levels of a
# native two-level fit, a_w * b_w == a_b * b_b, the free fit against the fit with that one nonlinear row (decisions in
# planning/specs/SCOPE-IG3-twolevel-tests-2026-11-19.md section 12). Oracle: the hand O8 likelihood maximized under the
# constraint (helper-twolevel-equal.R), never lavaan's nonlinear fit (it returned an inadmissible optimum with a
# spurious LR). The statistic is n_obs * (f_null - f_free), the scale of mbco_sem(); with f * n_obs = -2 logL it is
# 2 (logL_free - logL_null). Tolerance TL-4: 1e-6 absolute on the log-likelihood difference.

tle_fit <- function(data = tl_data_balanced()) fit_sem(tl_lavaan_model, data, cluster = "cluster")

# the hand log-likelihood difference (free minus constrained) on the same data
tle_hand_dll <- function(data, sign = 1) {
  free <- tl_o8_fit(data)
  null <- tl_o8_fit_equal(data, sign = sign, start_from = free)
  list(dll = free$loglik - null$loglik, free = free, null = null)
}

tle_check_oracle <- function(res, hand) {
  expect_lt(abs(unname(res$statistic) / 2 - hand$dll), 1e-6)
}

test_that("the statistic equals the hand O8 likelihood maximized under the constraint (TL-4)", {
  data <- tl_data_balanced()
  res <- twolevel_equal_indirect(tle_fit(data))
  hand <- tle_hand_dll(data)
  expect_false(res$unresolved)
  tle_check_oracle(res, hand)
  expect_equal(unname(res$p.value), stats::pchisq(unname(res$statistic), df = 1, lower.tail = FALSE),
               tolerance = 1e-12)
  expect_identical(unname(res$parameter), 1)
  # the null fit's two indirect effects are equal (to the hand optimum's value), and the hand optimum satisfies it
  expect_equal(unname(res$indirect$null[["within"]]), unname(res$indirect$null[["between"]]), tolerance = 1e-8)
  expect_equal(unname(res$indirect$null[["within"]]), unname(hand$null$indirect[["within"]]), tolerance = 1e-3)
})

test_that("a fixture with clearly different indirect effects gives a large statistic that the oracle matches", {
  data <- tl_simulate(rep(8, 60), seed = 3)
  data$M <- data$M + 0.8 * stats::ave(data$X, data$cluster) # strengthens the between a path only
  res <- twolevel_equal_indirect(tle_fit(data))
  hand <- tle_hand_dll(data)
  expect_false(res$unresolved)
  tle_check_oracle(res, hand)
  expect_gt(unname(res$statistic), 1)
})

test_that("the result carries the levels, the cluster count, the sample size and the estimates", {
  fit <- tle_fit()
  res <- twolevel_equal_indirect(fit)
  expect_s3_class(res, c("twolevel_equal_indirect", "htest"))
  expect_identical(res$level, c("within", "between"))
  expect_identical(res$n_clusters, 40L)
  expect_identical(res$n_obs, 240L)
  expect_named(res$statistic, "LR")
  expect_identical(res$data.name, "a_w * b_w == a_b * b_b")
  expect_equal(res$indirect$free[["within"]], unname(coef(fit)[["a_w"]] * coef(fit)[["b_w"]]))
  expect_equal(res$indirect$free[["between"]], unname(coef(fit)[["a_b"]] * coef(fit)[["b_b"]]))
  expect_false(res$unresolved)
  expect_null(res$boot)
  expect_output(print(res), "equal indirect effects", ignore.case = TRUE)
  # the package's own print method runs (print() is S7-dispatched, so it is registered in .onLoad), not print.htest
  expect_output(print(res), "Within vs between indirect effect", fixed = TRUE)
})

test_that("the statistic is invariant to cluster labels, row order and the order of the factors in a product", {
  data <- tl_data_balanced()
  base <- twolevel_equal_indirect(tle_fit(data))
  relabeled <- data
  ids <- withr::with_seed(3, sample(1000:9999, 40))
  relabeled$cluster <- paste0("c", ids[data$cluster])
  reordered <- withr::with_seed(4, data[sample(nrow(data)), ])
  for (d in list(relabeled, reordered)) {
    expect_lt(abs(unname(twolevel_equal_indirect(tle_fit(d))$statistic) - unname(base$statistic)), 1e-6)
  }
  # which side of the equality is written first, and the order inside a product: the same fit
  forms <- c("a_b*b_b == a_w*b_w", "b_w*a_w == b_b*a_b", "a_w*b_w - a_b*b_b == 0")
  f_base <- fit_sem(paste(tl_lavaan_model, "a_w*b_w == a_b*b_b", sep = "\n"), data, cluster = "cluster")
  for (con in forms[1:2]) {
    f <- fit_sem(paste(tl_lavaan_model, con, sep = "\n"), data, cluster = "cluster")
    expect_lt(abs(unname(f@f * f@n_obs - f_base@f * f_base@n_obs)), 1e-6)
  }
  # the free fit's own statistic against the constrained fit written either way round
  expect_lt(abs(unname(base$statistic) - (f_base@f - tle_fit(data)@f) * f_base@n_obs), 1e-6)
})

test_that("rows dropped listwise keep the cluster ids aligned", {
  data <- tl_data_balanced()
  data$M[c(3, 50, 121)] <- NA
  data$Y[c(7, 200)] <- NA
  res <- twolevel_equal_indirect(tle_fit(data))
  expect_identical(res$n_obs, 235L)
  complete <- data[stats::complete.cases(data), ]
  tle_check_oracle(res, tle_hand_dll(complete))
})

test_that("custom path labels are routed to the right levels", {
  model <- sub("a_w", "aw", sub("b_w", "bw", sub("a_b", "ab", sub("b_b", "bb", tl_lavaan_model))))
  data <- tl_data_balanced()
  fit <- fit_sem(model, data, cluster = "cluster")
  res <- twolevel_equal_indirect(fit, "aw", "bw", "ab", "bb")
  expect_lt(abs(unname(res$statistic) - unname(twolevel_equal_indirect(tle_fit(data))$statistic)), 1e-6)
  # a within pair in the between slots is refused: wrong level paths
  err <- expect_error(twolevel_equal_indirect(fit, "ab", "bb", "aw", "bw"), class = "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "level", fixed = TRUE)
  expect_error(twolevel_equal_indirect(fit, "aw", "nope", "ab", "bb"), "not a labeled regression path")
  expect_error(twolevel_equal_indirect(fit, "aw", "bw", "aw", "bb"), "different")
})

test_that("a single-level fit, a fit that already has the nonlinear row and bad arguments are refused", {
  single <- fit_sem("M ~ a*X\nY ~ b*M + X", mediation_demo[c("treatment", "mediator1", "outcome")] |>
                      stats::setNames(c("X", "M", "Y")), fixed_x = FALSE)
  expect_error(twolevel_equal_indirect(single), class = "medfit_error_twolevel_required")
  expect_error(twolevel_equal_indirect("not a fit"), "SEMFit")
  nl <- fit_sem(paste(tl_lavaan_model, "a_w*b_w == a_b*b_b", sep = "\n"), tl_data_balanced(), cluster = "cluster")
  expect_error(twolevel_equal_indirect(nl), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_equal_indirect(tle_fit(), n_boot = -1), "n_boot")
  expect_error(twolevel_equal_indirect(tle_fit(), a_within = 1), "a_within")
})

test_that("a fit with a linear constraint is tested against the same constraint plus the equality", {
  data <- tl_data_balanced()
  fit <- fit_sem(paste(tl_lavaan_model, "cp_w == cp_b", sep = "\n"), data, cluster = "cluster")
  res <- twolevel_equal_indirect(fit)
  null <- fit_sem(paste(tl_lavaan_model, "cp_w == cp_b", "a_w*b_w == a_b*b_b", sep = "\n"), data, cluster = "cluster")
  expect_false(res$unresolved)
  expect_lt(abs(unname(res$statistic) - (null@f - fit@f) * fit@n_obs), 1e-6)
})

# --- planted defects: each wrong statistic must fail the oracle check, so the check can fail ---

test_that("planted defect: the sign of one product flipped is caught by the oracle", {
  data <- tl_data_balanced()
  hand <- tle_hand_dll(data)
  # the guard admits only the equality of two products, so the flipped row goes straight to the engine
  syntax <- paste(tl_lavaan_model, "a_w*b_w == -a_b*b_b", sep = "\n")
  flipped <- .sem_fit_syntax(syntax, data, "observed", parsed = .sem_resolve_levels(.sem_parse(syntax), "cluster"),
                             meanstructure = TRUE, fixed_x = FALSE, cluster = "cluster")
  bad <- list(statistic = c(LR = (flipped$f - tle_fit(data)@f) * flipped$n_obs))
  expect_failure(tle_check_oracle(bad, hand))
  # and the hand oracle for the flipped null agrees with the engine for the flipped null (the oracle itself is sound)
  hand_flip <- tle_hand_dll(data, sign = -1)
  expect_lt(abs(unname(bad$statistic) / 2 - hand_flip$dll), 1e-5)
})

test_that("planted defect: a statistic from the wrong level paths is caught by the oracle", {
  data <- tl_data_balanced()
  hand <- tle_hand_dll(data)
  # within-level paths on both sides: a_w*b_w == a_w*b_w is no constraint; the cross pairing a_w*b_b == a_b*b_w is a
  # different surface and a different LR
  # (the guard refuses this pairing, so it goes straight to the engine)
  syntax <- paste(tl_lavaan_model, "a_w*b_b == a_b*b_w", sep = "\n")
  wrong <- .sem_fit_syntax(syntax, data, "observed", parsed = .sem_resolve_levels(.sem_parse(syntax), "cluster"),
                           meanstructure = TRUE, fixed_x = FALSE, cluster = "cluster")
  bad <- list(statistic = c(LR = (wrong$f - tle_fit(data)@f) * wrong$n_obs))
  expect_failure(tle_check_oracle(bad, hand))
})

test_that("planted defect: the oracle rejects a likelihood-free statistic (a constant) and a one-sided scale", {
  data <- tl_data_balanced()
  hand <- tle_hand_dll(data)
  res <- twolevel_equal_indirect(tle_fit(data))
  expect_failure(tle_check_oracle(list(statistic = c(LR = 0)), hand))
  expect_failure(tle_check_oracle(list(statistic = c(LR = unname(res$statistic) * 2)), hand))
})

# --- fault injection: an inadmissible or failed constrained refit is unresolved, never an LR ---

tle_expect_unresolved <- function(res) {
  expect_true(res$unresolved)
  expect_true(is.na(res$statistic))
  expect_true(is.na(res$p.value))
  expect_true(nzchar(res$note))
}

test_that("a null refit that ends at an inadmissible solution is unresolved with a classed warning", {
  fit <- tle_fit()
  testthat::local_mocked_bindings(.sem_improper_ml2 = function(theta, tl) {
    "negative variance: injected level-2 variance"
  })
  expect_warning(res <- twolevel_equal_indirect(fit), class = "medfit_warning_twolevel_inadmissible")
  tle_expect_unresolved(res)
  expect_match(res$note, "injected level-2 variance", fixed = TRUE)
})

test_that("a negative level-1 variance at the null refit is unresolved as well", {
  fit <- tle_fit()
  testthat::local_mocked_bindings(.sem_improper_ml2 = function(theta, tl) {
    "negative variance: injected level-1 variance"
  })
  expect_warning(res <- twolevel_equal_indirect(fit), "inadmissible")
  tle_expect_unresolved(res)
})

test_that("a null refit whose covariance is not positive definite is unresolved, not an LR", {
  fit <- tle_fit()
  testthat::local_mocked_bindings(.sem_vcov = function(theta, ...) {
    stop(.sem_covariance_diagnostic("information_not_pd", "injected: information matrix is not positive definite"))
  })
  expect_warning(res <- twolevel_equal_indirect(fit))
  tle_expect_unresolved(res)
})

test_that("a null refit that does not converge is unresolved with a warning", {
  fit <- tle_fit()
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    if (!is.null(model) && grepl("a_w*b_w == a_b*b_b", model, fixed = TRUE)) {
      stop(.sem_no_convergence("injected null failure"))
    }
    real(model, ...)
  })
  expect_warning(res <- twolevel_equal_indirect(fit), "injected null failure")
  tle_expect_unresolved(res)
})

test_that("a constrained refit that beats the free fit is unresolved, not a negative LR", {
  fit <- tle_fit()
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    out <- real(model, ...)
    if (!is.null(model) && grepl("a_w*b_w == a_b*b_b", model, fixed = TRUE)) out$f <- out$f - 1
    out
  })
  expect_warning(res <- twolevel_equal_indirect(fit), "free fit")
  tle_expect_unresolved(res)
})

test_that("planted defect: accepting an inadmissible optimum would give a number, the unresolved check refuses it", {
  fit <- tle_fit()
  # the defect: the inadmissible branch returns the kept evidence fit's LR instead of an unresolved result
  bad_fn <- sem_mutate(
    medfit:::.tle_resolve_null,
    "inadmissible <- inherits(err, \"medfit_error_twolevel_inadmissible\")",
    "inadmissible <- FALSE; if (inherits(err, \"medfit_error_twolevel_inadmissible\")) return(list(fit = err$fit))"
  )
  testthat::local_mocked_bindings(.sem_improper_ml2 = function(theta, tl) "negative variance: injected")
  testthat::local_mocked_bindings(.tle_resolve_null = bad_fn, .mbco_warn_level2_boundary = function(...) NULL)
  res <- suppressWarnings(twolevel_equal_indirect(fit))
  expect_failure(expect_true(res$unresolved))
  expect_false(is.na(res$statistic))
})

test_that("a level-2 variance near zero at the null warns that the boundary law may apply", {
  fit <- tle_fit()
  testthat::local_mocked_bindings(.mbco_level2_near_zero = function(refit, threshold = 0.01) "Y")
  expect_warning(res <- twolevel_equal_indirect(fit), "near zero")
  expect_false(res$unresolved)
})

test_that("all four paths near zero warns about the singular point", {
  # no mediation at either level, real cluster variation: every path is 0 and the null sits at the singular point
  data <- withr::with_seed(5, {
    cl <- rep(1:40, each = 6)
    u <- matrix(stats::rnorm(40 * 3, sd = 0.8), ncol = 3)[cl, ]
    z <- u + matrix(stats::rnorm(240 * 3), ncol = 3)
    data.frame(cluster = cl, X = z[, 1], M = z[, 2], Y = z[, 3])
  })
  fit <- suppressWarnings(tle_fit(data))
  expect_warning(res <- twolevel_equal_indirect(fit), class = "medfit_warning_twolevel_equal_singular")
  expect_true(res$near_singular)
  # a fit with clear effects does not warn about it
  expect_false(suppressWarnings(twolevel_equal_indirect(tle_fit()))$near_singular)
})

# --- parametric bootstrap for calibration at small J ---

test_that("the parametric bootstrap p-value is reproducible, in (0, 1] and counts the usable replications", {
  data <- tl_simulate(rep(5, 20), seed = 8)
  fit <- tle_fit(data)
  r1 <- suppressWarnings(twolevel_equal_indirect(fit, n_boot = 6, seed = 1))
  r2 <- suppressWarnings(twolevel_equal_indirect(fit, n_boot = 6, seed = 1))
  expect_identical(r1$boot$statistic, r2$boot$statistic)
  expect_identical(r1$boot$p.value, r2$boot$p.value)
  expect_gt(r1$boot$p.value, 0)
  expect_lte(r1$boot$p.value, 1)
  expect_identical(r1$boot$n_boot, 6L)
  expect_lte(r1$boot$n_valid, 6L)
  expect_identical(r1$boot$n_dropped, 6L - r1$boot$n_valid)
  expect_output(print(r1), "conditional on admissible refits", fixed = TRUE)
  exceed <- sum(r1$boot$statistic >= unname(r1$statistic), na.rm = TRUE)
  expect_equal(r1$boot$p.value, (1 + exceed) / (r1$boot$n_valid + 1))
  # the asymptotic p-value is still reported
  expect_equal(unname(r1$p.value), stats::pchisq(unname(r1$statistic), 1, lower.tail = FALSE), tolerance = 1e-12)
})

# --- the contrast stays descriptive ---

test_that("nie(level = 'contrast') and tidy() carry no p-value for the contrast; the docs say the test is separate", {
  td <- suppressWarnings(extract_mediation(tle_fit(), treatment = "X", mediator = "M", outcome = "Y"))
  expect_false(grepl("p-value|p =|p\\.value", paste(utils::capture.output(print(nie(td, level = "contrast"))),
                                                    collapse = " "), ignore.case = TRUE))
  tid <- suppressWarnings(tidy(td, type = "effects"))
  expect_true("nie_contrast" %in% tid$term)
  expect_false(any(c("p.value", "statistic", "p_value") %in% names(tid)))
  src_file <- test_path("..", "..", "R", "sem-twolevel-equal-indirect.R")
  skip_if_not(file.exists(src_file), "R/ sources are not shipped with the installed tests")
  src <- paste(readLines(src_file), collapse = "\n")
  expect_match(src, "never reported by `nie()`", fixed = TRUE)
})

test_that("the contrast carries no p-value under any name: tidy columns, glance columns and nie() attributes", {
  td <- suppressWarnings(extract_mediation(tle_fit(), treatment = "X", mediator = "M", outcome = "Y"))
  tid <- suppressWarnings(tidy(td, type = "effects", conf_int = TRUE))
  expect_identical(names(tid), c("term", "estimate", "std_error", "conf_low", "conf_high"))
  expect_false(any(grepl("^p|stat|signif|pval", names(suppressWarnings(glance(td))), ignore.case = TRUE)))
  contrast <- nie(td, level = "contrast")
  expect_identical(sort(names(attributes(contrast))), c("class", "level", "type"))
})

test_that("planted defect: a contrast p-value attached to nie() or tidy() under a new name is caught", {
  td <- suppressWarnings(extract_mediation(tle_fit(), treatment = "X", mediator = "M", outcome = "Y"))
  contrast <- nie(td, level = "contrast")
  attr(contrast, "p.value") <- 0.03
  expect_failure(expect_identical(sort(names(attributes(contrast))), c("class", "level", "type")))
  tid <- suppressWarnings(tidy(td, type = "effects", conf_int = TRUE))
  tid$pval <- 0.03
  expect_failure(expect_identical(names(tid), c("term", "estimate", "std_error", "conf_low", "conf_high")))
})

test_that("planted defect: a contrast p-value in the docs-consistency check is caught", {
  has_p <- function(x) any(grepl("p.value", names(x), fixed = TRUE))
  expect_true(has_p(data.frame(estimate = 1, p.value = 0.5)))
  expect_false(has_p(data.frame(estimate = 1)))
})

# --- #504: the constrained surface a_w*b_w == a_b*b_b has sign-twin local optima (a pair (a, b) -> (-a, -b) keeps the
# row), so some starts end at a genuine twin with a higher discrepancy; the spread warning is dropped only then ---

tle_collect_warnings <- function(expr) {
  w <- character()
  val <- withCallingHandlers(expr, warning = function(x) {
    w <<- c(w, conditionMessage(x))
    invokeRestart("muffleWarning")
  })
  list(value = val, warnings = w)
}

tle_issue504_data <- function(s) {
  set.seed(s)
  id <- rep(1:40, each = 6)
  x <- stats::rnorm(40)[id] + stats::rnorm(240)
  m <- 0.5 * x + stats::rnorm(40)[id] + stats::rnorm(240)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(40)[id] + stats::rnorm(240)
  data.frame(cluster = id, X = x, M = m, Y = y)
}

test_that("ordinary two-level data gives no 'starts disagree' warning and the statistic matches the oracle (#504)", {
  model <- "level: 1\n M ~ a_w*X\n Y ~ b_w*M + X\nlevel: 2\n M ~ a_b*X\n Y ~ b_b*M + X"
  for (s in 1:12) {
    data <- tle_issue504_data(s)
    got <- tle_collect_warnings(twolevel_equal_indirect(fit_sem(model, data, cluster = "cluster")))
    expect_false(any(grepl("starts disagree", got$warnings)), info = paste("seed", s))
    expect_false(got$value$unresolved, info = paste("seed", s))
    if (s <= 3L) {
      hand <- tle_hand_dll(data)
      tle_check_oracle(got$value, hand)
    }
  }
})

test_that("the twin explanation: a sign twin is explained, a non-twin disagreement is not (#504)", {
  idx <- 1:4 # a_w, b_w, a_b, b_b
  kept <- c(0.5, 0.4, 0.37, 0.59, 1)
  att <- function(f, th) list(accepted = TRUE, f = f, theta = th)
  twin <- att(9.836, c(0.5, 0.4, -0.43, -0.38, 1))
  twin_w <- att(9.9, c(-0.5, -0.4, 0.37, 0.59, 1))
  twin_both <- att(9.95, c(-0.5, -0.4, -0.43, -0.38, 1))
  same_pattern <- att(9.9, c(0.5, 0.4, 0.37, 0.59, 2)) # same signs, higher f: a real local optimum
  mixed <- att(9.9, c(0.5, -0.4, 0.37, -0.59, 1)) # product signs flipped: not a pair twin
  agree <- att(9.675, kept)
  expl <- function(...) .tle_twin_explained(list(agree, ...), kept, 9.675, idx)
  expect_true(expl())
  expect_true(expl(twin))
  expect_true(expl(twin, twin_w, twin_both))
  # planted defects: each non-twin disagreement must still count as unexplained
  expect_false(expl(same_pattern))
  expect_false(expl(twin, same_pattern))
  expect_false(expl(mixed))
  expect_false(expl(att(9.9, c(0, 0.4, -0.43, -0.38, 1)))) # a zero sign is not evidence of a twin
  # a rejected attempt is ignored
  expect_true(.tle_twin_explained(list(agree, list(accepted = FALSE, f = Inf, theta = NULL), twin), kept, 9.675, idx))
})
