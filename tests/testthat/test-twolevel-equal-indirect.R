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

# --- #504 residual: with `n_starts = 1` no second start is compared, so a worse sign twin could be kept in silence. The
# twin certificate fits one start from each pair-sign twin of the kept optimum and keeps the lowest discrepancy ---

# a two-level mediation sample with chosen within and between a and b paths (opposite-sign indirect effects and
# near-zero paths are the stress family of #507 where a worse twin was kept)
tle_twin_data <- function(seed, J = 40, n = 6, aw = 0.5, bw = 0.4, ab = 0.5, bb = 0.4) {
  withr::local_seed(seed)
  id <- rep(seq_len(J), each = n)
  N <- J * n
  xb <- stats::rnorm(J)
  xw <- stats::rnorm(N)
  mb <- ab * xb + stats::rnorm(J)
  mw <- aw * xw + stats::rnorm(N)
  yb <- bb * mb + 0.2 * xb + stats::rnorm(J)
  yw <- bw * mw + 0.2 * xw + stats::rnorm(N)
  data.frame(cluster = id, X = xb[id] + xw, M = mb[id] + mw, Y = yb[id] + yw)
}

tle_twin_model <- "level: 1\n M ~ a_w*X\n Y ~ b_w*M + X\nlevel: 2\n M ~ a_b*X\n Y ~ b_b*M + X"

# cells where the constrained refit with one start ends at a worse twin without the certificate: the discrepancy of the
# kept fit is higher than the hand optimum's (LR 8.18 against 7.64, and 4.69 against 2.25)
tle_twin_cells <- list(
  list(data = function() tle_twin_data(209, 40, 6, 0.3, -0.4, 0.4, 0.4)),
  list(data = function() tle_twin_data(108, 15, 4, 0.5, 0.4, -0.4, 0.5))
)

test_that("with one start a worse sign twin is not kept: the statistic matches the hand optimum (#504)", {
  for (cell in tle_twin_cells) {
    data <- cell$data()
    fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
    res <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 1))
    hand <- tle_hand_dll(data)
    expect_false(res$unresolved)
    tle_check_oracle(res, hand)
    # the null fit satisfies the equality
    expect_equal(unname(res$indirect$null[["within"]]), unname(res$indirect$null[["between"]]), tolerance = 1e-6)
    # more starts reach the same optimum
    res30 <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 30))
    expect_lt(abs(unname(res$statistic) - unname(res30$statistic)), 1e-6)
  }
})

test_that("the certificate leaves the statistic unchanged where the kept fit was already the best (#504)", {
  model <- tle_twin_model
  # statistics of the \donttest family before the certificate (J = 40, n = 6, seeds 1 and 2)
  known <- c(`1` = 0.3006055823, `2` = 0.01452715782)
  for (s in names(known)) {
    data <- tle_issue504_data(as.integer(s))
    fit <- fit_sem(model, data, cluster = "cluster")
    for (ns in list(NULL, 1L)) {
      res <- twolevel_equal_indirect(fit, n_starts = ns)
      expect_equal(unname(res$statistic), unname(known[[s]]), tolerance = 1e-8, info = paste("seed", s, "starts", ns))
    }
  }
})

test_that("the start of a twin refit sets the written rows only and flips the chosen pair (#504)", {
  fit <- tle_fit()
  con <- "a_w*b_w == a_b*b_b"
  syntax <- paste0(fit@model, "\n", con)
  data <- fit@data
  data$cluster <- fit@internals$cluster_ids
  parsed <- .sem_twolevel_guard(syntax, data, "cluster", information = "observed", weights = NULL, se_type = "model",
                                missing = "listwise", fixed_x = FALSE, fx_unset = TRUE, meanstructure = TRUE,
                                ms_unset = TRUE)
  r <- .tle_refit(fit, con, 1L, list())$fit
  start <- unname(r$theta)
  start[match(c("a_w", "b_w"), r$ram$par_names)] <- -start[match(c("a_w", "b_w"), r$ram$par_names)]
  out <- .tle_start_parsed(parsed, r, start)$parameters
  # no row is added or removed, and only the start column changes
  expect_identical(nrow(out), nrow(parsed$parameters))
  expect_identical(out[setdiff(names(out), "start")], parsed$parameters[setdiff(names(out), "start")])
  # every written row carries the kept estimate, the within pair with its sign flipped
  by_label <- stats::setNames(out$start, out$label)
  expect_equal(unname(by_label[["a_w"]]), -unname(r$theta[["a_w"]]))
  expect_equal(unname(by_label[["b_w"]]), -unname(r$theta[["b_w"]]))
  expect_equal(unname(by_label[["a_b"]]), unname(r$theta[["a_b"]]))
  expect_equal(unname(by_label[["b_b"]]), unname(r$theta[["b_b"]]))
  expect_false(anyNA(out$start))
})

test_that("planted defect: without the twin step the one-start statistic misses the hand optimum (#504)", {
  data <- tle_twin_cells[[1]]$data()
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  hand <- tle_hand_dll(data)
  # the defect: the certificate returns the kept fit
  testthat::local_mocked_bindings(.tle_twin_certificate = function(r, ...) r)
  res <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 1))
  expect_failure(tle_check_oracle(res, hand))
  expect_gt(unname(res$statistic) / 2 - hand$dll, 0.1)
})

test_that("planted defect: a twin step that never flips a sign is caught as well (#504)", {
  data <- tle_twin_cells[[1]]$data()
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  hand <- tle_hand_dll(data)
  # the defect: the twin start keeps the kept signs, so every twin refit returns to the kept optimum
  bad_fn <- sem_mutate(medfit:::.tle_twin_certificate, "start[flip] <- -start[flip]", "start[flip] <- start[flip]")
  testthat::local_mocked_bindings(.tle_twin_certificate = bad_fn)
  res <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 1))
  expect_failure(tle_check_oracle(res, hand))
})

# --- #504 independent QA additions: a between-pair twin, the twin edge cases, the bootstrap, the #507 warning rule ---

test_that("a worse twin that only the between-pair flip repairs is not kept with one start (#504)", {
  # J = 60, n = 4: the kept one-start fit ends 16 LR units above the optimum; only the between pair flip repairs it
  data <- tle_twin_data(10280, 60, 4, 0.5, 0.6, -0.5, 0.6)
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  res <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 1))
  expect_false(res$unresolved)
  tle_check_oracle(res, tle_hand_dll(data))
  res30 <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 30))
  expect_lt(abs(unname(res$statistic) - unname(res30$statistic)), 1e-6)
})

# the constrained refits of `twolevel_equal_indirect()` seen through `.sem_fit_syntax()`: call 1 is the kept fit, the
# later calls are the twin refits; `edit(call_number, fit)` changes what a call returns
tle_with_twin_mock <- function(fit, edit, n_starts = 1L, improper = NULL, vcov_fail = FALSE) {
  real <- .sem_fit_syntax
  real_vcov <- .sem_vcov
  st <- new.env()
  st$calls <- 0L
  st$in_twin <- FALSE
  wrapped <- function(...) {
    st$calls <- st$calls + 1L
    st$in_twin <- st$calls >= 2L
    on.exit(st$in_twin <- FALSE)
    edit(st$calls, real(...))
  }
  imp <- function(theta, tl) if (st$in_twin && !is.null(improper)) improper else NULL
  # the covariance stage fails on the twin refits only
  vc <- function(...) {
    if (st$in_twin && vcov_fail) {
      stop(.sem_covariance_diagnostic("information_not_pd", "injected twin: information is not positive definite"))
    }
    real_vcov(...)
  }
  res <- suppressWarnings(testthat::with_mocked_bindings(
    twolevel_equal_indirect(fit, n_starts = n_starts),
    .sem_fit_syntax = wrapped, .sem_improper_ml2 = imp, .sem_vcov = vc
  ))
  list(res = res, calls = st$calls)
}

test_that("a pair with a zero is not flipped: 0, 1 or 3 twin refits for 2, 1 or 0 zero-free pairs (#504)", {
  fit <- tle_fit()
  zero <- function(idx) {
    function(i, r) {
      if (i == 1L && length(idx)) r$theta[match(c("a_w", "b_w", "a_b", "b_b")[idx], r$ram$par_names)] <- 0
      r
    }
  }
  expect_identical(tle_with_twin_mock(fit, zero(c(1, 3)))$calls, 1L)
  expect_identical(tle_with_twin_mock(fit, zero(1))$calls, 2L)
  expect_identical(tle_with_twin_mock(fit, zero(NULL))$calls, 4L)
})

test_that("a twin refit that errors or does not converge is skipped and leaves the kept fit (#504)", {
  data <- tle_twin_cells[[1]]$data()
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  # the kept one-start statistic with every twin refit forced to fail
  fail <- function(i, r) if (i >= 2L) stop(.sem_no_convergence("injected twin failure")) else r
  got <- tle_with_twin_mock(fit, fail)$res
  hand <- tle_hand_dll(data)
  expect_false(got$unresolved)
  # the kept (worse) twin stands: the statistic is above the hand optimum, and finite
  expect_gt(unname(got$statistic) / 2 - hand$dll, 0.1)
})

test_that("an inadmissible twin below the kept fit makes the result unresolved; a worse one is ignored (#504)", {
  # the kept fit is a worse twin and the better twin ends inadmissible (the engine's own check fires on the twin refits
  # only): unresolved with the classed warning, as with more starts, never the kept fit's number
  data <- tle_twin_cells[[1]]$data()
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  inadm <- tle_with_twin_mock(fit, function(i, r) r, improper = "negative variance: injected twin")$res
  tle_expect_unresolved(inadm)
  expect_match(inadm$note, "injected twin", fixed = TRUE)
  real <- .sem_fit_syntax
  calls <- 0L
  expect_warning(
    testthat::with_mocked_bindings(
      twolevel_equal_indirect(fit, n_starts = 1),
      .sem_fit_syntax = function(...) {
        calls <<- calls + 1L
        real(...)
      },
      .sem_improper_ml2 = function(theta, tl) if (calls >= 2L) "negative variance: injected twin"
    ),
    class = "medfit_warning_twolevel_inadmissible"
  )
  # the kept fit is already the best (the twins end higher): an inadmissible twin leaves the kept statistic
  fit2 <- tle_fit()
  plain <- tle_with_twin_mock(fit2, function(i, r) r)$res
  worse <- tle_with_twin_mock(fit2, function(i, r) r, improper = "negative variance: injected twin")$res
  expect_false(worse$unresolved)
  expect_identical(unname(worse$statistic), unname(plain$statistic))
})

test_that("a twin is adopted only when it beats the kept discrepancy by more than the spread tolerance (#504)", {
  fit <- tle_fit()
  kept_f <- NULL
  # a twin lower by 1e-9 (below .sem_spread_tol) is not adopted: the statistic is the kept fit's
  below <- function(i, r) {
    if (i == 1L) kept_f <<- r$f else r$f <- kept_f - 1e-9
    r
  }
  got <- tle_with_twin_mock(fit, below)$res
  expect_identical(unname(got$statistic), unname(fit@n_obs * (kept_f - fit@f)))
  # a twin lower by 1e-5 (above the tolerance) is adopted: the statistic drops by n * 1e-5
  above <- function(i, r) {
    if (i == 1L) kept_f <<- r$f else r$f <- kept_f - 1e-5
    r
  }
  got2 <- tle_with_twin_mock(fit, above)$res
  expect_equal(unname(got2$statistic), unname(got$statistic) - fit@n_obs * 1e-5, tolerance = 1e-9)
})

test_that("the starts-disagree warning is dropped for a pair twin only; any other disagreement still warns (#507)", {
  fit <- tle_fit()
  real <- .sem_fit_syntax
  paths <- c("a_w", "b_w", "a_b", "b_b")
  disagree <- function(flip) {
    calls <- 0L
    function(...) {
      calls <<- calls + 1L
      r <- real(...)
      if (calls == 1L) {
        th <- r$theta
        i <- match(paths, r$ram$par_names)
        th[i[flip]] <- -th[i[flip]]
        r$attempts <- c(r$attempts, list(list(accepted = TRUE, f = r$f + 0.5, theta = th)))
        warning("the starts disagree: injected", call. = FALSE)
      }
      r
    }
  }
  caught <- function(flip) {
    w <- character()
    withCallingHandlers(
      testthat::with_mocked_bindings(twolevel_equal_indirect(fit, n_starts = 5), .sem_fit_syntax = disagree(flip)),
      warning = function(x) {
        w <<- c(w, conditionMessage(x))
        invokeRestart("muffleWarning")
      }
    )
    any(grepl("injected", w))
  }
  expect_false(caught(1:2)) # a pair twin: explained
  expect_false(caught(1:4))
  expect_true(caught(integer())) # same signs, higher f: a genuine second optimum still warns
  expect_true(caught(c(1L, 3L))) # one element of each pair: not a pair twin, still warns
})

test_that("the parametric bootstrap applies the twin certificate to every replicate refit (#504)", {
  data <- tl_simulate(rep(5, 20), seed = 8)
  fit <- tle_fit(data)
  calls <- 0L
  real <- .tle_twin_certificate
  testthat::local_mocked_bindings(.tle_twin_certificate = function(r, ...) {
    calls <<- calls + 1L
    real(r, ...)
  })
  res <- suppressWarnings(twolevel_equal_indirect(fit, n_boot = 3, seed = 1))
  # the observed refit plus one per replicate whose free fit resolved
  expect_gte(calls, 1L + res$boot$n_valid)
  expect_gt(res$boot$n_valid, 0L)
})

test_that("an adopted twin's own sign-explained disagreement is silent; a non-twin disagreement still warns (#504)", {
  # a corrected one-start cell: the adopted twin's refit compares its supplied start with the engine's own start, which
  # disagrees by a sign twin; dev was silent here
  data <- tle_twin_cells[[1]]$data()
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  got <- tle_collect_warnings(twolevel_equal_indirect(fit, n_starts = 1))
  expect_false(any(grepl("starts disagree", got$warnings)))
  tle_check_oracle(got$value, tle_hand_dll(data))
  # injected into every twin refit (the adopted one among them), with the twin's own signs flipped or not
  real <- .sem_fit_syntax
  paths <- c("a_w", "b_w", "a_b", "b_b")
  disagree <- function(flip) {
    calls <- 0L
    function(...) {
      calls <<- calls + 1L
      r <- real(...)
      if (calls >= 2L) {
        th <- r$theta
        i <- match(paths, r$ram$par_names)
        th[i[flip]] <- -th[i[flip]]
        r$attempts <- c(r$attempts, list(list(accepted = TRUE, f = r$f + 0.5, theta = th)))
        warning("the starts disagree: injected twin refit", call. = FALSE)
      }
      r
    }
  }
  caught <- function(flip) {
    w <- character()
    withCallingHandlers(
      testthat::with_mocked_bindings(twolevel_equal_indirect(fit, n_starts = 1), .sem_fit_syntax = disagree(flip)),
      warning = function(x) {
        w <<- c(w, conditionMessage(x))
        invokeRestart("muffleWarning")
      }
    )
    any(grepl("injected twin refit", w))
  }
  expect_false(caught(1:2)) # a pair twin of the adopted fit: explained
  expect_false(caught(1:4))
  expect_true(caught(integer())) # same signs, higher f: a genuine second optimum still warns
  expect_true(caught(c(1L, 3L))) # one element of each pair: not a pair twin, still warns
})

test_that("a covariance-stage twin below the kept fit is unresolved; a worse or f-less one is skipped (#504)", {
  data <- tle_twin_cells[[1]]$data()
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  # the kept fit is a worse twin and every twin refit ends with a covariance that is not positive definite
  better <- tle_with_twin_mock(fit, function(i, r) r, vcov_fail = TRUE)$res
  tle_expect_unresolved(better)
  expect_match(better$note, "not positive definite", fixed = TRUE)
  expect_true(better$twin$unresolved)
  expect_false(better$twin$replaced)
  real <- .sem_fit_syntax
  real_vcov <- .sem_vcov
  calls <- 0L
  expect_warning(
    testthat::with_mocked_bindings(
      twolevel_equal_indirect(fit, n_starts = 1),
      .sem_fit_syntax = function(...) {
        calls <<- calls + 1L
        real(...)
      },
      .sem_vcov = function(...) {
        if (calls >= 2L) stop(.sem_covariance_diagnostic("information_not_pd", "injected twin"))
        real_vcov(...)
      }
    ),
    class = "medfit_warning_twolevel_inadmissible"
  )
  # the kept fit is already the best (the twins end higher): a covariance-stage twin leaves the kept statistic
  fit2 <- tle_fit()
  plain <- tle_with_twin_mock(fit2, function(i, r) r)$res
  worse <- tle_with_twin_mock(fit2, function(i, r) r, vcov_fail = TRUE)$res
  expect_false(worse$unresolved)
  expect_false(worse$twin$unresolved)
  expect_identical(unname(worse$statistic), unname(plain$statistic))
  # a covariance-stage failure that carries no discrepancy has nothing to compare: skipped
  st <- new.env()
  st$calls <- 0L
  res <- suppressWarnings(testthat::with_mocked_bindings(
    twolevel_equal_indirect(fit, n_starts = 1),
    .sem_fit_syntax = function(...) {
      st$calls <- st$calls + 1L
      tryCatch(real(...), medfit_sem_covariance_error = function(e) {
        e$partial$f <- NULL
        stop(e)
      })
    },
    .sem_vcov = function(...) {
      if (st$calls >= 2L) stop(.sem_covariance_diagnostic("information_not_pd", "injected twin"))
      real_vcov(...)
    }
  ))
  expect_false(res$unresolved)
  expect_false(res$twin$unresolved)
  # the statistic is the kept fit's, the one with the certificate disabled
  off <- suppressWarnings(testthat::with_mocked_bindings(
    twolevel_equal_indirect(fit, n_starts = 1), .tle_twin_certificate = function(r, ...) r
  ))
  expect_identical(unname(res$statistic), unname(off$statistic))
})

test_that("the twin element records what the certificate did, for resolved and unresolved results (#504)", {
  # ordinary data: the kept fit is the best, nothing replaced
  ord <- twolevel_equal_indirect(tle_fit(), n_starts = 1)
  expect_named(ord$twin, c("tried", "replaced", "flipped", "f_gain", "unresolved"))
  expect_true(ord$twin$tried)
  expect_false(ord$twin$replaced)
  expect_identical(ord$twin$flipped, character())
  expect_identical(ord$twin$f_gain, 0)
  expect_false(ord$twin$unresolved)
  # a kept-worse-twin cell: the twin replaced the kept fit, and the gain is the discrepancy the statistic drops by
  data <- tle_twin_cells[[1]]$data()
  fit <- fit_sem(tle_twin_model, data, cluster = "cluster")
  got <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 1))
  testthat::local_mocked_bindings(.tle_twin_certificate = function(r, ...) r)
  kept <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 1))
  expect_true(got$twin$replaced)
  expect_gt(length(got$twin$flipped), 0L)
  expect_true(all(got$twin$flipped %in% c("within", "between")))
  expect_gt(got$twin$f_gain, 0)
  expect_equal(got$twin$f_gain * got$n_obs, unname(kept$statistic) - unname(got$statistic), tolerance = 1e-8)
  # the certificate disabled: the record says nothing was tried, and the statistic is the kept fit's
  expect_false(kept$twin$tried)
  expect_false(kept$twin$replaced)
})

test_that("the twin element is present when the result is unresolved (#504)", {
  # an inadmissible better twin (J = 15, n = 4, the q1 profile): unresolved, and the record says why
  data <- tle_twin_data(1001, 15, 4, 0.5, 0.4, -0.4, 0.5)
  fit <- suppressWarnings(fit_sem(tle_twin_model, data, cluster = "cluster"))
  res <- suppressWarnings(twolevel_equal_indirect(fit, n_starts = 1))
  tle_expect_unresolved(res)
  expect_true(res$twin$unresolved)
  expect_true(res$twin$tried)
  expect_false(res$twin$replaced)
  # the kept refit itself ends inadmissible: no certificate, the record is the empty one
  fit2 <- tle_fit()
  testthat::local_mocked_bindings(.sem_improper_ml2 = function(theta, tl) "negative variance: injected")
  res2 <- suppressWarnings(twolevel_equal_indirect(fit2))
  tle_expect_unresolved(res2)
  expect_identical(res2$twin, list(tried = FALSE, replaced = FALSE, flipped = character(), f_gain = 0,
                                   unresolved = FALSE))
})

test_that("the twin element does not change print() or the other elements (#504)", {
  res <- twolevel_equal_indirect(tle_fit())
  bare <- res
  bare$twin <- NULL
  expect_identical(utils::capture.output(print(res)), utils::capture.output(print(bare)))
  expect_false(any(grepl("twin", utils::capture.output(print(res)), ignore.case = TRUE)))
  expect_identical(setdiff(names(res), "twin"), setdiff(names(bare), "twin"))
})
