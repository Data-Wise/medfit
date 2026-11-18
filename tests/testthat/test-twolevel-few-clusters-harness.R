# Few-clusters design study, tasks T1 to T3 (planning/PLAN-few-clusters-design-study-2026-11-16.md): the harness in
# tests/sim/twolevel-few-clusters-lib.R. T1: the between-level scale `s` and the implied ICCs match the section 4 table
# to 1e-3 (computed from the implied covariance matrices, not from the closed form), the unequal cluster sizes keep
# the mean and reach a CV near .5, seeds follow section 9, and the O8 likelihood oracle
# (helper-twolevel-likelihood.R) agrees with lavaan's logLik on three harness datasets. T2: on a planted dataset with
# a negative level-2 variance, the default fit (P0) ends below zero with a lavaan warning, the syntax floor (P1) ends
# at `eps` with no warning, and `bounds = "pos.var"` adds no bound to a two-level fit. Each check has a planted defect.

skip_if_not_installed("lavaan")
# internal study harness: never run on CRAN, even if tests/sim were shipped (0.19.0 release decision R19-2)
skip_on_cran()
fc_lib <- test_path("..", "sim", "twolevel-few-clusters-lib.R")
skip_if_not(file.exists(fc_lib), "tests/sim is not shipped with the installed tests")
source(fc_lib, local = TRUE)

# section 4 table: target ICC_X, s and the implied ICC_M, each rounded to three decimals
fc_table <- data.frame(
  icc_x = c(.05, .10, .20, .40),
  s = c(.075, .159, .357, .952),
  icc_m = c(.039, .079, .161, .338)
)

# one expectation over every row and column (largest absolute gap), so a planted defect is one failure
fc_check_icc <- function(scale_fun) {
  gaps <- vapply(seq_len(nrow(fc_table)), function(i) {
    s <- scale_fun(fc_table$icc_x[i])
    icc <- fc_icc(fc_implied(s = s)) # nolint: object_usage_linter. (sourced from tests/sim)
    c(s - fc_table$s[i], icc[["X"]] - fc_table$icc_x[i], icc[["M"]] - fc_table$icc_m[i])
  }, numeric(3))
  testthat::expect_lt(max(abs(gaps)), 1e-3)
}

test_that("T1: s and the implied ICC_X and ICC_M match the section 4 table to 1e-3", {
  fc_check_icc(fc_scale)
  # the implied level covariances agree with the O8 helper's own path algebra
  imp <- fc_implied(s = fc_scale(.2), nie_b = .18)
  pop <- fc_population()
  w <- pop$within
  b <- pop$between
  expect_equal(imp$sw, tl_sigma(w$a, w$b, w$cp, w$vx, w$vm, w$vy), tolerance = 1e-12, ignore_attr = TRUE)
  expect_equal(imp$sb, fc_scale(.2) * tl_sigma(b$a, b$b, b$cp, b$vx, b$vm, b$vy),
               tolerance = 1e-12, ignore_attr = TRUE)
})

test_that("T1 planted defect: an s that omits the between variance .7 fails the ICC check", {
  expect_failure(fc_check_icc(function(icc) icc / (1 - icc)))
})

test_that("T1: truths are NIE_W = .20, NIE_B = .18 or 0, and the contrast is NIE_W - NIE_B", {
  expect_equal(fc_truth(.18)[["nie_within"]], .20)
  expect_equal(fc_truth(.18)[["nie_between"]], .18)
  expect_equal(fc_truth(.18)[["nie_contrast"]], .02)
  expect_equal(fc_truth(0)[["nie_between"]], 0)
  expect_equal(fc_truth(0)[["nie_contrast"]], .20)
  expect_equal(fc_truth(0)[["c_prime_between"]], .1)
  expect_error(fc_truth(.1), "nie_b")
})

test_that("T1: cluster sizes keep the total, stay at 2 or more, and the unequal design has CV near .5", {
  for (j in c(10, 20, 30, 50, 100)) {
    for (n in c(5, 20)) {
      eq <- fc_sizes(j, n, "equal")
      expect_identical(eq, rep(as.integer(n), j))
      un <- fc_sizes(j, n, "unequal")
      expect_length(un, j)
      expect_identical(sum(un), as.integer(j * n))
      expect_gte(min(un), 2L)
      cv <- stats::sd(un) / mean(un)
      expect_lt(abs(cv - .5), .05, label = sprintf("CV at J = %d, n = %d (%.3f)", j, n, cv))
      expect_identical(fc_sizes(j, n, "unequal"), un)
    }
  }
  expect_error(fc_sizes(10, 5, "skewed"))
})

test_that("T1: the grid has 120 cells with disjoint ids from 1001 and seeds cell_id * 1e5 + rep", {
  g <- fc_grid()
  expect_identical(nrow(g), 120L)
  expect_identical(anyDuplicated(g$cell_id), 0L)
  expect_identical(min(g$cell_id), 1001L)
  expect_setequal(unique(g$J), c(10, 20, 30, 50, 100))
  expect_setequal(unique(g$n), c(5, 20))
  expect_setequal(unique(g$icc_x), c(.05, .20, .40))
  expect_setequal(unique(g$balance), c("equal", "unequal"))
  expect_setequal(unique(g$nie_b), c(.18, 0))
  expect_identical(fc_seed(1001L, 7L), 100100007L)
})

test_that("T1: datasets are reproducible, leave the session RNG alone, and differ across replicates", {
  cell <- fc_grid()[1, ]
  kind_before <- RNGkind()
  set.seed(99)
  state_before <- .Random.seed
  d1 <- fc_simulate(cell, 1L)
  expect_identical(RNGkind(), kind_before)
  expect_identical(.Random.seed, state_before)
  expect_identical(fc_simulate(cell, 1L), d1)
  RNGkind("Mersenne-Twister")
  rm(".Random.seed", envir = globalenv())
  fc_simulate(cell, 1L)
  expect_identical(RNGkind()[1], "Mersenne-Twister")
  set.seed(99)
  expect_false(identical(fc_simulate(cell, 2L)$X, d1$X))
  expect_named(d1, c("id", "X", "M", "Y"))
  expect_identical(nrow(d1), as.integer(cell$J * cell$n))
  expect_identical(as.integer(table(d1$id)), fc_sizes(cell$J, cell$n, cell$balance))
})

test_that("T1: simulated data recover the section 4 ICC_X and the within and between a paths (ANOVA estimator)", {
  # independent of fc_implied()/fc_icc(): method-of-moments within and between covariances from the raw data, so a
  # generator that swaps the level-1 and level-2 draws (ICC_X .8 instead of .2) or mis-assigns cluster ids fails
  cell <- data.frame(cell_id = 990L, J = 1000, n = 20, icc_x = .20, balance = "unequal", nie_b = .18)
  d <- fc_simulate(cell, 1L)
  nj <- as.numeric(table(d$id))
  expect_identical(as.integer(nj), fc_sizes(1000, 20, "unequal")) # the unequal sizes reach the data
  big_n <- nrow(d)
  n0 <- (big_n - sum(nj^2) / big_n) / (length(nj) - 1)
  z <- as.matrix(d[, c("X", "M")])
  gm <- rowsum(z, d$id) / nj
  sw <- crossprod(z - gm[d$id, ]) / (big_n - length(nj))
  sb <- (crossprod(sweep(gm, 2, colMeans(z)) * sqrt(nj)) / (length(nj) - 1) - sw) / n0
  expect_lt(abs(sb[1, 1] / (sb[1, 1] + sw[1, 1]) - .20), .03)
  expect_lt(abs(sw[1, 2] / sw[1, 1] - .5), .03)
  expect_lt(abs(sb[1, 2] / sb[1, 1] - .3), .1)
})

test_that("T1: the O8 likelihood oracle agrees with lavaan's logLik on three harness datasets", {
  g <- fc_grid()
  pick <- list(
    list(J = 30, n = 5, icc_x = .40, balance = "equal", nie_b = .18, rep = 1L),
    list(J = 50, n = 20, icc_x = .20, balance = "unequal", nie_b = .18, rep = 2L),
    list(J = 20, n = 20, icc_x = .40, balance = "unequal", nie_b = 0, rep = 3L)
  )
  for (p in pick) {
    cell <- g[g$J == p$J & g$n == p$n & g$icc_x == p$icc_x & g$balance == p$balance & g$nie_b == p$nie_b, ]
    expect_identical(nrow(cell), 1L)
    d <- fc_simulate(cell, p$rep)
    fit <- fc_fit(d, "p0")$fit
    expect_true(lavaan::lavInspect(fit, "converged"))
    hand <- tl_lavaan_to_hand(fit)
    lav <- as.numeric(lavaan::logLik(fit))
    st <- tl_stats(d, "id")
    tl_check_loglik(tl_loglik(st, hand$sw, hand$sb, hand$mu), lav)
    # planted defect: the cluster-mean covariance without the n_j weight must disagree
    expect_failure(tl_check_loglik(tl_loglik(st, hand$sw, hand$sb, hand$mu, defect = "nj_free"), lav))
  }
})

test_that("T2: the syntax floor binds a negative level-2 variance at eps; pos.var adds no bound", {
  d <- fc_planted_negative()
  eps <- 1e-3

  p0 <- fc_fit(d, "p0", eps)
  v0 <- fc_l2_var(p0$fit)
  expect_lt(v0[["Y"]], 0)
  expect_true(any(grepl("variances are negative", p0$lavaan_warnings, fixed = TRUE)))

  p1 <- fc_fit(d, "p1", eps)
  v1 <- fc_l2_var(p1$fit)
  expect_true(lavaan::lavInspect(p1$fit, "converged"))
  expect_lt(abs(v1[["Y"]] - eps), 1e-8)
  expect_true(all(v1 >= eps - 1e-10))
  expect_length(p1$lavaan_warnings, 0)
  expect_true(lavaan::lavInspect(p1$fit, "post.check"))

  pv <- suppressWarnings(lavaan::sem(fc_model(floor = FALSE), d, cluster = "id", fixed.x = FALSE,
                                     bounds = "pos.var"))
  expect_false("lower" %in% names(lavaan::parTable(pv)))
  expect_lt(fc_l2_var(pv)[["Y"]], 0)
})

test_that("T2: the row builder records the negative variance under P0 and the bound under P1", {
  d <- fc_planted_negative()
  r0 <- fc_analyze(d, "p0", eps = 1e-3, truth = fc_truth(.18))
  r1 <- fc_analyze(d, "p1", eps = 1e-3, truth = fc_truth(.18))
  expect_identical(nrow(r0), 1L)
  expect_true(r0$neg_l2_var)
  expect_false(r0$admissible)
  expect_gte(r0$n_lavaan_warn, 1L)
  expect_false(r1$neg_l2_var)
  expect_true(r1$at_bound)
  expect_true(r1$admissible)
  expect_identical(r1$n_lavaan_warn, 0L)
  expect_true(r1$warn_few_clusters)
  expect_true(is.finite(r1$est_nie_contrast))
  expect_equal(r1$est_nie_contrast, r1$est_nie_within - r1$est_nie_between, tolerance = 1e-10)
  expect_equal(r1$truth_nie_contrast, .02)
})

test_that("T1: MUTANT switches shift the truth or narrow the delta interval; unknown names error", {
  row <- data.frame(est_nie_within = .2, lo_nie_within = .1, hi_nie_within = .3, truth_nie_within = .2)
  expect_identical(fc_apply_mutant(row, ""), row)
  expect_equal(fc_apply_mutant(row, "truth")$truth_nie_within, .25)
  narrowed <- fc_apply_mutant(row, "narrow")
  expect_equal(narrowed$hi_nie_within - narrowed$lo_nie_within, .8 * .2)
  expect_equal(narrowed$est_nie_within, .2)
  expect_error(fc_apply_mutant(row, "wider"), "unknown mutant")
})

# --- T3: the three-effect cluster-bootstrap closure (one refit, three statistics) -------------------------------------

# Value of one callback on one resample, as bootstrap_mediation()'s cluster loop sees it: an error is NA, and a warning
# marks the replicate as failed (NA) and is recorded.
fc_t3_eval <- function(f, d, n) {
  warned <- FALSE
  v <- withCallingHandlers(
    tryCatch(f(d), error = function(e) rep(NA_real_, n)),
    warning = function(w) {
      warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  )
  if (warned) v[] <- NA_real_
  list(value = unname(v), warned = warned)
}

# One resample per seed: the dataset is replicate `seed` of a cell with `J` clusters (default 20), the clusters are
# drawn with set.seed(seed) exactly as bootstrap_mediation(cluster = ) draws them, and relabeled by the shipped helper.
fc_t3_cases <- function(seeds, J = 20) {
  g <- fc_grid() # nolint: object_usage_linter. (sourced from tests/sim)
  cell <- g[g$J == J & g$n == 5 & g$icc_x == .4 & g$balance == "equal" & g$nie_b == .18, ]
  lapply(seeds, function(s) {
    d <- fc_simulate(cell, s) # nolint: object_usage_linter.
    fit <- fc_fit(d, "p0")$fit # nolint: object_usage_linter.
    ids <- withr::with_seed(s, sample(unique(d$id), length(unique(d$id)), replace = TRUE))
    list(seed = s, data = d, fit = fit, resample = medfit:::.relabel_clusters(d, "id", ids))
  })
}

# The shipped side: three separate twolevel_statistic() callbacks, one refit each.
fc_t3_shipped <- function(cases) {
  out <- lapply(cases, function(cs) {
    r <- lapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
      fn <- twolevel_statistic(cs$fit, e, treatment = "X", mediator = "M", outcome = "Y") # nolint: object_usage_linter.
      fc_t3_eval(fn, cs$resample, 1L)
    })
    list(value = vapply(r, `[[`, numeric(1), "value"), warned = vapply(r, `[[`, logical(1), "warned"))
  })
  fc_t3_matrix(out, cases)
}

# The closure side: one refit returns all three.
fc_t3_closure <- function(cases, defect = "") {
  out <- lapply(cases, function(cs) {
    fn <- fc_boot_closure(cs$fit, data = cs$data, defect = defect) # nolint: object_usage_linter.
    r <- fc_t3_eval(fn, cs$resample, 3L)
    list(value = r$value, warned = rep(r$warned, 3L))
  })
  fc_t3_matrix(out, cases)
}

fc_t3_matrix <- function(out, cases) {
  dn <- list(paste0("seed", vapply(cases, `[[`, numeric(1), "seed")), fc_boot_effects) # nolint: object_usage_linter.
  list(
    value = matrix(unlist(lapply(out, `[[`, "value")), length(out), 3L, byrow = TRUE, dimnames = dn),
    warned = matrix(unlist(lapply(out, `[[`, "warned")), length(out), 3L, byrow = TRUE, dimnames = dn)
  )
}

# one expectation over the whole seeds x effects table, so a planted defect is one failure
fc_t3_check <- function(closure, shipped) {
  testthat::expect_identical(closure, shipped)
}

test_that("T3: the closure equals three runs of the shipped callback on 20 seeds, exactly; planted defects fail", {
  skip_on_cran()
  cases <- fc_t3_cases(1:20)
  shipped <- fc_t3_shipped(cases)
  # the comparison is not vacuous: most resamples give three finite values, and a resample is not the original data
  expect_gte(sum(stats::complete.cases(shipped$value)), 15L)
  expect_false(identical(cases[[1]]$resample$X, cases[[1]]$data$X))
  fc_t3_check(fc_t3_closure(cases), shipped)

  # planted defects on the first five seeds (enough to differ, and faster)
  first <- cases[1:5]
  sub <- lapply(shipped, function(m) m[1:5, , drop = FALSE])
  expect_failure(fc_t3_check(fc_t3_closure(first, "swap"), sub))
  expect_failure(fc_t3_check(fc_t3_closure(first, "sign"), sub))
  expect_failure(fc_t3_check(fc_t3_closure(first, "original"), sub))
})

test_that("T3: below the ICC floor the closure blanks NIE_B and the contrast only, as the shipped callback does", {
  skip_on_cran()
  cases <- fc_t3_cases(1:3)
  # the shipped callbacks are built first: twolevel_statistic() reads the floor when it extracts the original fit,
  # and the refit reads it again on every call
  callbacks <- lapply(cases, function(cs) {
    lapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
      twolevel_statistic(cs$fit, e, treatment = "X", mediator = "M", outcome = "Y")
    })
  })
  withr::local_options(medfit.between_icc_error = .99)
  shipped <- fc_t3_matrix(lapply(seq_along(cases), function(i) {
    r <- lapply(callbacks[[i]], fc_t3_eval, d = cases[[i]]$resample, n = 1L)
    list(value = vapply(r, `[[`, numeric(1), "value"), warned = vapply(r, `[[`, logical(1), "warned"))
  }), cases)
  expect_true(all(is.finite(shipped$value[, "nie_within"])))
  expect_true(all(is.na(shipped$value[, c("nie_between", "nie_contrast")])))
  fc_t3_check(fc_t3_closure(cases), shipped)
  expect_failure(fc_t3_check(fc_t3_closure(cases, "gate_all"), shipped))
})

test_that("T3: the closure validates its defect switch and needs the original data for the 'original' mutant", {
  skip_on_cran()
  fit <- fc_fit(fc_planted_negative(), "p1")$fit # nolint: object_usage_linter.
  expect_error(fc_boot_closure(fit, defect = "wider"), "defect") # nolint: object_usage_linter.
  expect_error(fc_boot_closure(fit, defect = "original"), "data") # nolint: object_usage_linter.
})

# Per effect, what construction gives: "ok", or the class of the refusal. The shipped side builds each
# twolevel_statistic() callback; the closure side builds the closure once and reads its `refused` attribute.
fc_t3_class <- function(e) paste(class(e), collapse = "/")
fc_t3_refusals_shipped <- function(fit) {
  vapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
    r <- tryCatch(
      twolevel_statistic(fit, e, treatment = "X", mediator = "M", outcome = "Y"), # nolint: object_usage_linter.
      error = function(err) err
    )
    if (inherits(r, "error")) fc_t3_class(r) else "ok"
  }, character(1))
}
fc_t3_refusals_closure <- function(fit, defect = "") {
  fn <- tryCatch(fc_boot_closure(fit, defect = defect), error = function(err) err) # nolint: object_usage_linter.
  if (inherits(fn, "error")) return(stats::setNames(rep(fc_t3_class(fn), 3L), fc_boot_effects)) # nolint
  refused <- attr(fn, "refused")
  vapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
    if (is.null(refused[[e]])) "ok" else fc_t3_class(refused[[e]])
  }, character(1))
}

test_that("T3: the closure refuses at build time per effect exactly as the shipped constructor (J = 10, seeds 7, 13)", {
  skip_on_cran()
  cases <- fc_t3_cases(c(7, 13), J = 10)
  shipped <- lapply(cases, function(cs) fc_t3_refusals_shipped(cs$fit))
  closure <- lapply(cases, function(cs) fc_t3_refusals_closure(cs$fit))
  # seed 7: the between level is not identified; seed 13: the original fit is unusable, every effect refused
  expect_identical(shipped[[1]][["nie_within"]], "ok")
  expect_match(shipped[[1]][c("nie_between", "nie_contrast")], "medfit_between_unidentified")
  expect_match(shipped[[2]], "medfit_error_twolevel_unusable")
  expect_identical(closure, shipped)
  # where an effect builds, its value on the resample is the shipped one, and refused effects come back NA
  within <- twolevel_statistic(cases[[1]]$fit, "nie_within", treatment = "X", mediator = "M", outcome = "Y")
  v <- fc_t3_eval(fc_boot_closure(cases[[1]]$fit), cases[[1]]$resample, 3L)$value # nolint: object_usage_linter.
  expect_identical(v[1], fc_t3_eval(within, cases[[1]]$resample, 1L)$value)
  expect_true(all(is.na(v[2:3])))
  # built at the default floor, evaluated with the refit ICC gate off: the resample's between effects are finite,
  # so only the build-time mask makes them NA
  masked <- fc_boot_closure(cases[[1]]$fit)
  raw <- fc_boot_closure(cases[[1]]$fit, defect = "nobuild")
  withr::with_options(list(medfit.between_icc_error = -Inf), {
    v_off <- fc_t3_eval(masked, cases[[1]]$resample, 3L)$value # nolint: object_usage_linter.
    v_raw <- fc_t3_eval(raw, cases[[1]]$resample, 3L)$value # nolint: object_usage_linter.
  })
  expect_true(is.finite(v_raw[2]))
  expect_true(all(is.na(v_off[2:3])))
  expect_failure(expect_identical(lapply(cases, function(cs) fc_t3_refusals_closure(cs$fit, "nobuild")), shipped))
})

test_that("T3: the closure equals three runs of the shipped callback on the J = 10 seeds that build, exactly", {
  skip_on_cran()
  cases <- fc_t3_cases(setdiff(1:20, c(7, 13)), J = 10)
  shipped <- fc_t3_shipped(cases)
  expect_gte(sum(stats::complete.cases(shipped$value)), 12L)
  fc_t3_check(fc_t3_closure(cases), shipped)
})

# --- T4: coverage aggregator, band call, planted mutants and the X x 10 rescale ---------------------------------------

# Hand-built rows for nie_within (truth .2): group 1 has 16 covering intervals, 2 missing and 2 that miss, so the
# unconditional coverage is 16 / 20 = .8 (16 / 18 if the missing intervals were dropped); group 2 covers 10 of 10.
fc_t4_rows <- function() {
  lo <- c(rep(.1, 16), NA, NA, .25, .05, rep(.1, 10))
  hi <- c(rep(.3, 16), NA, NA, .35, .15, rep(.3, 10))
  data.frame(cell_id = rep(c(1L, 2L), c(20, 10)), arm = "p0", est_nie_within = .2, lo_nie_within = lo,
             hi_nie_within = hi, truth_nie_within = .2, stringsAsFactors = FALSE)
}

fc_t4_check_coverage <- function(coverage_fun) {
  cv <- coverage_fun(fc_t4_rows())
  testthat::expect_equal(
    cv[, c("cell_id", "estimand", "R", "coverage", "mcse")],
    data.frame(cell_id = 1:2, estimand = "nie_within", R = c(20L, 10L), coverage = c(.8, 1),
               mcse = c(sqrt(.8 * .2 / 20), 0), stringsAsFactors = FALSE),
    ignore_attr = TRUE
  )
}

test_that("T4: coverage counts a missing interval as a miss, with R and MCSE sqrt(p (1 - p) / R) per group", {
  fc_t4_check_coverage(fc_coverage) # nolint: object_usage_linter. (sourced from tests/sim)
  # per-dataset indicators: TRUE, a missing interval FALSE, never NA
  ind <- fc_covered(fc_t4_rows())$nie_within # nolint: object_usage_linter.
  expect_identical(ind, c(rep(TRUE, 16), FALSE, FALSE, FALSE, FALSE, rep(TRUE, 10)))
  expect_error(fc_coverage(fc_t4_rows(), by = "cell"), "by") # nolint: object_usage_linter.
})

test_that("T4 planted defect: an aggregator that drops the missing intervals fails the coverage check", {
  dropping <- function(rows) fc_coverage(rows[!is.na(rows$lo_nie_within), ]) # nolint: object_usage_linter.
  expect_failure(fc_t4_check_coverage(dropping))
})

fc_t4_check_band <- function(band_fun) {
  testthat::expect_identical(
    band_fun(c(.95, .90, .93, .99, .974), rep(.005, 5)),
    c("inside", "outside", "ambiguous", "outside", "ambiguous")
  )
}

test_that("T4: the band call is inside, outside, or ambiguous within 2 MCSE of an edge", {
  fc_t4_check_band(fc_band) # nolint: object_usage_linter.
  expect_identical(fc_band(c(.925, .975), c(0, 0)), c("outside", "outside")) # nolint: object_usage_linter.
  expect_error(fc_band(.95, c(.01, .01)), "mcse") # nolint: object_usage_linter.
})

test_that("T4 planted defect: a band call without the MCSE margin fails the band check", {
  no_margin <- function(coverage, mcse) fc_band(coverage, mcse, k_mcse = 0) # nolint: object_usage_linter.
  expect_failure(fc_t4_check_band(no_margin))
})

# 1000 deterministic delta intervals with exactly calibrated quantiles: est = truth + q se, q = qnorm(ppoints(1000)),
# interval est -/+ 1.96 se, so the baseline covers 950 of 1000 (inside the band by 3.6 MCSE).
fc_t4_calibrated <- function() {
  q <- stats::qnorm(stats::ppoints(1000))
  se <- .05
  est <- .2 + q * se
  data.frame(cell_id = 1L, arm = "p0", est_nie_within = est, se_nie_within = se,
             lo_nie_within = est - 1.96 * se, hi_nie_within = est + 1.96 * se, truth_nie_within = .2)
}

fc_t4_check_mutants <- function(mutant_fun) {
  rows <- fc_t4_calibrated()
  calls <- vapply(c("truth", "narrow"), function(m) {
    fc_coverage(mutant_fun(rows, m))$band # nolint: object_usage_linter.
  }, character(1))
  testthat::expect_identical(unname(calls), c("outside", "outside"))
}

test_that("T4: both planted mutants move a calibrated coverage of .95 outside the band", {
  base <- fc_coverage(fc_t4_calibrated()) # nolint: object_usage_linter.
  expect_identical(base$coverage, .95)
  expect_identical(base$band, "inside")
  fc_t4_check_mutants(fc_apply_mutant) # nolint: object_usage_linter.
})

test_that("T4 planted defect: a 'narrow' mutant that leaves the interval alone fails the mutant check", {
  lazy <- function(row, mutant) {
    if (mutant == "narrow") row else fc_apply_mutant(row, mutant) # nolint: object_usage_linter.
  }
  expect_failure(fc_t4_check_mutants(lazy))
})

test_that("T4: truths divide by k under the X rescale; fc_rescale_x() scales X only", {
  expect_equal(fc_truth(.18, scale_x = 10), fc_truth(.18) / 10) # nolint: object_usage_linter.
  expect_equal(fc_truth(0, scale_x = 10)[["nie_contrast"]], .02) # nolint: object_usage_linter.
  d <- data.frame(id = 1:2, X = c(1, -2), M = 3:4, Y = 5:6)
  expect_identical(fc_rescale_x(d, 10), transform(d, X = c(10, -20))) # nolint: object_usage_linter.
  expect_error(fc_rescale_x(d, 0), "k") # nolint: object_usage_linter.
})

# Rescale identity on three seeds of a J = 50 cell: same coverage indicators and status flags, and k est' = est to
# 1e-3 SE (lavaan's optimizer stops near 1e-4 SE on this cell).
fc_t4_rescale_rows <- function(truth_fun) {
  g <- fc_grid() # nolint: object_usage_linter.
  cell <- g[g$J == 50 & g$n == 5 & g$icc_x == .4 & g$balance == "equal" & g$nie_b == .18, ]
  rows <- lapply(1:3, function(r) {
    d <- fc_simulate(cell, r) # nolint: object_usage_linter.
    o <- fc_analyze(d, "p0", truth = fc_truth(cell$nie_b)) # nolint: object_usage_linter.
    s <- fc_analyze(fc_rescale_x(d, 10), "p0", truth = truth_fun(cell$nie_b)) # nolint: object_usage_linter.
    list(o = cbind(cell_id = cell$cell_id, rep = r, o), s = cbind(cell_id = cell$cell_id, rep = r, s))
  })
  list(o = do.call(rbind, lapply(rows, `[[`, "o")), s = do.call(rbind, lapply(rows, `[[`, "s")))
}

fc_t4_check_rescale <- function(rows) {
  cmp <- fc_rescale_compare(rows$o, rows$s, 10) # nolint: object_usage_linter.
  testthat::expect_true(all(cmp$indicators_same) && all(cmp$flags_same) && all(cmp$max_gap_se < 1e-3))
}

test_that("T4: X x 10 leaves every coverage indicator and flag unchanged and scales estimates by 1/10", {
  skip_on_cran()
  rows <- fc_t4_rescale_rows(function(nie_b) fc_truth(nie_b, scale_x = 10)) # nolint: object_usage_linter.
  fc_t4_check_rescale(rows)
  # planted defect on the same fits: truths left on the original scale flip the indicators
  rows$s[grep("^truth_", names(rows$s))] <- rows$s[grep("^truth_", names(rows$s))] * 10
  expect_failure(fc_t4_check_rescale(rows))
})

test_that("T4: the rescale comparison marks datasets converged and admissible with no adapter error in both runs", {
  skip_on_cran()
  rows <- fc_t4_rescale_rows(function(nie_b) fc_truth(nie_b, scale_x = 10)) # nolint: object_usage_linter.
  expect_identical(fc_rescale_compare(rows$o, rows$s, 10)$clean_both, rep(TRUE, 3)) # nolint: object_usage_linter.
  rows$s$admissible[2] <- FALSE
  rows$o$converged[3] <- FALSE
  cmp <- fc_rescale_compare(rows$o, rows$s, 10) # nolint: object_usage_linter.
  expect_identical(cmp$clean_both, c(TRUE, FALSE, FALSE))
})

# --- T4 (second design): baseline-paired mutant criterion and the SE-scaled truth shift ----------------------------

# Paired runs for nie_within (truth .2), 410 datasets in cell 1 and 400 in cell 2. Cell 1: datasets 1 to 5 have no
# interval in either run, 6 to 8 did not converge, 9 and 10 lose their interval in the mutant run only; these ten are
# dropped from both, leaving R = 400. Of those, the baseline covers 380 and the mutant 368 (12 of the covered
# datasets miss), so coverage drops by .03; the paired MCSE is sd(d) / 20 = .0085 (caught at 3 MCSE), while the
# unpaired sqrt(.95 .05 / 400 + .92 .08 / 400) = .0174 would not catch it. Cell 2: the mutant covers all 400 the
# baseline covers 380 of, a gain, never a catch.
fc_t4_paired_runs <- function() {
  cover <- c(.1, .3)
  miss <- c(.25, .35)
  mk <- function(cell, ok) {
    lo <- ifelse(ok, cover[1], miss[1])
    hi <- ifelse(ok, cover[2], miss[2])
    data.frame(cell_id = cell, rep = seq_along(ok), arm = "p0", converged = TRUE, adapter_error = NA_character_,
               truth_nie_within = .2, est_nie_within = .2, lo_nie_within = lo, hi_nie_within = hi,
               stringsAsFactors = FALSE)
  }
  b1 <- mk(1L, c(rep(TRUE, 10), rep(TRUE, 380), rep(FALSE, 20)))
  b1[1:5, c("lo_nie_within", "hi_nie_within")] <- NA
  b1$converged[6:8] <- FALSE
  m1 <- b1
  m1[9:10, c("lo_nie_within", "hi_nie_within")] <- NA
  m1[11:22, c("lo_nie_within", "hi_nie_within")] <- as.list(miss)
  b2 <- mk(2L, c(rep(TRUE, 380), rep(FALSE, 20)))
  m2 <- mk(2L, rep(TRUE, 400))
  list(base = rbind(b1, b2), mut = rbind(m1, m2))
}

fc_t4_check_paired <- function(catch_fun) {
  runs <- fc_t4_paired_runs()
  pc <- catch_fun(runs$base, runs$mut)
  d <- c(rep(1, 12), rep(0, 388))
  d2 <- c(rep(-1, 20), rep(0, 380))
  testthat::expect_equal(
    pc[, c("cell_id", "estimand", "R", "cov_base", "cov_mut", "drop", "mcse", "caught")],
    data.frame(cell_id = 1:2, estimand = "nie_within", R = c(400L, 400L), cov_base = c(.95, .95),
               cov_mut = c(.92, 1), drop = c(.03, -.05), mcse = c(stats::sd(d), stats::sd(d2)) / 20,
               caught = c(TRUE, FALSE), stringsAsFactors = FALSE),
    ignore_attr = TRUE
  )
}

test_that("T4: a mutant is caught when coverage drops by more than 3 paired MCSE over datasets valid in both runs", {
  fc_t4_check_paired(fc_paired_catch) # nolint: object_usage_linter.
  runs <- fc_t4_paired_runs()
  expect_error(fc_paired_catch(runs$base, runs$mut[-1, ]), "same datasets") # nolint: object_usage_linter.
})

# Two cells whose median SEs are .1 (one SE missing) and .5: the truth mutant moves their truths by .2 and 1.
fc_t4_shift_rows <- function() {
  data.frame(cell_id = rep(1:2, c(4, 2)), rep = c(1:4, 1:2), arm = "p0", truth_nie_within = .2,
             est_nie_within = .2, se_nie_within = c(.1, .1, .3, NA, .5, .5), lo_nie_within = 0,
             hi_nie_within = .3, mutant = "", stringsAsFactors = FALSE)
}

fc_t4_check_shift <- function(mutate_fun) {
  testthat::expect_equal(mutate_fun(fc_t4_shift_rows())$truth_nie_within, .2 + rep(c(.2, 1), c(4, 2)))
}

# The narrow mutant cuts each half-width by 50% about the estimate: the rows' interval [0, .3] about .2 becomes
# [.1, .25], with the estimate and the truth left alone.
fc_t4_check_narrow <- function(mutate_fun) {
  cols <- c("est_nie_within", "truth_nie_within", "lo_nie_within", "hi_nie_within")
  testthat::expect_equal(mutate_fun(fc_t4_shift_rows())[cols],
                         data.frame(est_nie_within = .2, truth_nie_within = .2, lo_nie_within = rep(.1, 6),
                                    hi_nie_within = .25))
}

test_that("T4: the truth mutant shifts each truth by 2 x the cell's median SE; narrow cuts each half-width by 50%", {
  rows <- fc_t4_shift_rows()
  sh <- fc_mutant_shift(rows) # nolint: object_usage_linter.
  expect_equal(sh$shift, c(.2, 1))
  fc_t4_check_shift(function(r) fc_mutate_runs(r, "truth")) # nolint: object_usage_linter.
  tm <- fc_mutate_runs(rows, "truth") # nolint: object_usage_linter.
  expect_identical(tm$mutant, rep("truth", 6))
  expect_identical(tm[setdiff(names(tm), c("truth_nie_within", "mutant"))],
                   rows[setdiff(names(rows), c("truth_nie_within", "mutant"))])
  fc_t4_check_narrow(function(r) fc_mutate_runs(r, "narrow")) # nolint: object_usage_linter.
  nm <- fc_mutate_runs(rows, "narrow") # nolint: object_usage_linter.
  ref <- fc_apply_mutant(rows, "narrow", narrow = .5) # nolint: object_usage_linter.
  expect_equal(nm[names(nm) != "mutant"], ref[names(ref) != "mutant"])
  expect_identical(nm$mutant, rep("narrow", 6))
  expect_error(fc_mutate_runs(rows, "wide"), "mutant") # nolint: object_usage_linter.
})

test_that("T4: both redesigned mutants are caught on calibrated intervals", {
  rows <- cbind(fc_t4_calibrated(), rep = 1:1000, converged = TRUE, adapter_error = NA_character_)
  for (m in c("truth", "narrow")) {
    pc <- fc_paired_catch(rows, fc_mutate_runs(rows, m)) # nolint: object_usage_linter.
    expect_true(pc$caught, label = m)
  }
})

test_that("T4: planted defects in the paired criterion and the shift are caught", {
  # Unpaired MCSE: sqrt(p_b (1 - p_b) / R + p_m (1 - p_m) / R) ignores the shared seeds and misses the .03 drop.
  unpaired <- function(base, mut) {
    pc <- fc_paired_catch(base, mut) # nolint: object_usage_linter.
    pc$mcse <- sqrt(pc$cov_base * (1 - pc$cov_base) / pc$R + pc$cov_mut * (1 - pc$cov_mut) / pc$R)
    pc$caught <- pc$drop > 3 * pc$mcse
    pc
  }
  expect_failure(fc_t4_check_paired(unpaired))
  # Wrong sign: d = I_mut - I_base flags the coverage gain in cell 2 and misses the loss in cell 1.
  wrong_sign <- function(base, mut) {
    pc <- fc_paired_catch(base, mut) # nolint: object_usage_linter.
    pc$drop <- -pc$drop
    pc$cov_mut <- 2 * pc$cov_base - pc$cov_mut
    pc$caught <- pc$drop > 3 * pc$mcse
    pc
  }
  expect_failure(fc_t4_check_paired(wrong_sign))
  # No drop rule: datasets without an interval in the mutant run count as misses there, so R is 403, not 400.
  no_drop <- function(base, mut) {
    pc <- fc_paired_catch(base, mut) # nolint: object_usage_linter.
    pc$R[1] <- sum(!is.na(base$lo_nie_within[base$cell_id == 1]) & base$converged[base$cell_id == 1])
    pc
  }
  expect_failure(fc_t4_check_paired(no_drop))
  # Shift not scaled: the fixed +.05 of the first attempt.
  expect_failure(fc_t4_check_shift(function(r) fc_apply_mutant(r, "truth"))) # nolint: object_usage_linter.
  # Shift from the median SE over all cells (.3), not per cell.
  expect_failure(fc_t4_check_shift(function(r) fc_mutate_runs(r, "truth", by = "arm"))) # nolint: object_usage_linter.
  # Wrong sign of the shift.
  minus <- function(r) {
    out <- fc_mutate_runs(r, "truth") # nolint: object_usage_linter.
    out$truth_nie_within <- 2 * r$truth_nie_within - out$truth_nie_within
    out
  }
  expect_failure(fc_t4_check_shift(minus))
  # Narrow factor left at the second attempt's .8 (20% cut), or at 1 (no cut).
  expect_failure(fc_t4_check_narrow(function(r) fc_apply_mutant(r, "narrow"))) # nolint: object_usage_linter.
  narrow_at <- function(f) function(r) fc_mutate_runs(r, "narrow", narrow = f) # nolint: object_usage_linter.
  expect_failure(fc_t4_check_narrow(narrow_at(.8)))
  expect_failure(fc_t4_check_narrow(narrow_at(1)))
})

# T5 (pilot): the Monte Carlo arm, the three-effect cluster bootstrap and the RNG streams they draw from. Each arm is
# compared with the shipped bootstrap_mediation() under the same RNG state; each check has a planted defect.
fc_t5_case <- function(cell_id = 1022, rep = 1) {
  g <- fc_grid() # nolint: object_usage_linter. (sourced from tests/sim)
  cell <- g[g$cell_id == cell_id, ]
  d <- fc_simulate(cell, rep) # nolint: object_usage_linter.
  fit <- fc_fit(d, "p0")$fit # nolint: object_usage_linter.
  obj <- suppressWarnings(extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"))
  list(cell = cell, rep = rep, data = d, fit = fit, obj = obj)
}

# The shipped parametric (MC) bootstrap per effect, each effect started from the same RNG state.
fc_t5_shipped_mc <- function(obj, stream, n_boot) {
  vapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
    stat <- twolevel_statistic(obj, e) # nolint: object_usage_linter.
    r <- fc_with_stream(stream, bootstrap_mediation( # nolint: object_usage_linter.
      stat, method = "parametric", mediation_data = obj, n_boot = n_boot
    ))
    c(r@ci_lower, r@ci_upper)
  }, numeric(2))
}

fc_t5_check_mc <- function(mc_fun, cs, n_boot = 200L) {
  st <- fc_streams(fc_seed(cs$cell$cell_id, cs$rep)) # nolint: object_usage_linter.
  got <- mc_fun(cs$obj, n_boot = n_boot, stream = st$mc)
  want <- fc_t5_shipped_mc(cs$obj, st$mc, n_boot)
  testthat::expect_identical(unname(rbind(got$lo, got$hi)), unname(want))
}

fc_t5_check_streams <- function(streams_fun) {
  withr::local_seed(99)
  rng <- function() get(".Random.seed", envir = globalenv())
  before <- rng()
  seed <- fc_seed(1022, 1) # nolint: object_usage_linter. (sourced from tests/sim)
  st <- streams_fun(seed)
  data_state <- fc_with_seed(seed, "L'Ecuyer-CMRG", rng()) # nolint: object_usage_linter.
  testthat::expect_identical(
    list(session = rng(), distinct = length(unique(list(data_state, st$mc, st$boot))), mc = st$mc, boot = st$boot),
    list(session = before, distinct = 3L, mc = parallel::nextRNGStream(data_state),
         boot = parallel::nextRNGStream(parallel::nextRNGStream(data_state)))
  )
}

test_that("T5: the RNG streams differ from the dataset seed and from each other, and leave the session RNG alone", {
  fc_t5_check_streams(fc_streams) # nolint: object_usage_linter.
  # planted defect: the MC arm drawing from the dataset's own stream
  same <- function(seed) {
    s <- fc_with_seed(seed, "L'Ecuyer-CMRG", get(".Random.seed", envir = globalenv())) # nolint: object_usage_linter.
    list(mc = s, boot = parallel::nextRNGStream(s))
  }
  expect_failure(fc_t5_check_streams(same))
})

test_that("T5: the MC arm equals the shipped parametric bootstrap per effect from the same stream", {
  cs <- fc_t5_case()
  expect_true(cs$obj@between_identified)
  fc_t5_check_mc(fc_mc, cs) # nolint: object_usage_linter.
  # planted defect: the stream not reset between effects (the second and third effects draw on)
  drift <- function(obj, n_boot, stream) {
    out <- fc_with_stream(stream, {
      v <- lapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
        bootstrap_mediation(twolevel_statistic(obj, e), method = "parametric", mediation_data = obj, n_boot = n_boot)
      })
      v
    })
    list(lo = vapply(out, function(r) r@ci_lower, numeric(1)), hi = vapply(out, function(r) r@ci_upper, numeric(1)),
         err = rep(NA_character_, 3L))
  }
  expect_failure(fc_t5_check_mc(drift, cs))
})

test_that("T5: the MC arm records a refused effect instead of stopping", {
  withr::local_options(medfit.between_icc_error = .9)
  cs <- fc_t5_case()
  obj <- cs$obj
  expect_false(obj@between_identified)
  st <- fc_streams(fc_seed(1022, 1)) # nolint: object_usage_linter.
  got <- fc_mc(obj, n_boot = 50L, stream = st$mc) # nolint: object_usage_linter.
  expect_true(is.finite(got$lo[["nie_within"]]))
  expect_true(all(is.na(got$lo[c("nie_between", "nie_contrast")])))
  expect_match(got$err[["nie_between"]], "needs the between level")
  expect_true(is.na(got$err[["nie_within"]]))
})

# The shipped cluster bootstrap per effect under set.seed(seed): interval, kept count and the kept estimates.
fc_t5_shipped_boot <- function(cs, n_boot, seed) {
  lapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
    fn <- twolevel_statistic(cs$fit, e, treatment = "X", mediator = "M", outcome = "Y") # nolint: object_usage_linter.
    r <- tryCatch(suppressWarnings(bootstrap_mediation(fn, method = "nonparametric", data = cs$data, cluster = "id",
                                                       n_boot = n_boot, seed = seed)),
                  error = function(err) err)
    if (inherits(r, "error")) return(list(ci = c(NA_real_, NA_real_), kept = NA_integer_, est = NULL))
    list(ci = c(r@ci_lower, r@ci_upper), kept = r@n_boot, est = r@boot_estimates)
  })
}

fc_t5_check_boot <- function(boot_fun, cs, n_boot = 20L, seed = 7L) {
  got <- withr::with_seed(seed, boot_fun(cs$fit, cs$data, n_boot = n_boot))
  want <- fc_t5_shipped_boot(cs, n_boot, seed)
  mine <- lapply(fc_boot_effects, function(e) { # nolint: object_usage_linter.
    list(ci = c(got$lo[[e]], got$hi[[e]]), kept = got$kept[[e]], est = got$est[[e]])
  })
  testthat::expect_identical(mine, want)
}

test_that("T5: the three-effect cluster bootstrap equals three shipped cluster bootstraps under the same seed", {
  skip_on_cran()
  cs <- fc_t5_case()
  fc_t5_check_boot(fc_cluster_boot, cs) # nolint: object_usage_linter.
  # planted defect: the clusters drawn without replacement
  no_repl <- fc_cluster_boot # nolint: object_usage_linter.
  environment(no_repl) <- list2env(
    list(sample = function(x, size, replace = FALSE, prob = NULL) base::sample(x, size, replace = FALSE)),
    parent = environment(fc_cluster_boot) # nolint: object_usage_linter.
  )
  expect_failure(fc_t5_check_boot(no_repl, cs))
})

test_that("T5: fewer than 10 kept replicates gives an NA interval with a reason, where the shipped one stops", {
  skip_on_cran()
  cs <- fc_t5_case()
  got <- withr::with_seed(7L, fc_cluster_boot(cs$fit, cs$data, n_boot = 5L)) # nolint: object_usage_linter.
  expect_true(all(is.na(c(got$lo, got$hi))))
  expect_true(all(grepl("fewer than 10", got$err)))
  fn <- twolevel_statistic(cs$fit, "nie_within", treatment = "X", mediator = "M", outcome = "Y")
  expect_error(suppressWarnings(bootstrap_mediation(fn, method = "nonparametric", data = cs$data, cluster = "id",
                                                    n_boot = 5L, seed = 7L)), "Too many bootstrap samples failed")
  # planted defect: a threshold of 5 keeps the five replicates and reports an interval
  boot5 <- function() fc_cluster_boot(cs$fit, cs$data, n_boot = 5L, min_kept = 5L) # nolint: object_usage_linter.
  five <- withr::with_seed(7L, boot5())
  expect_failure(expect_true(all(is.na(five$lo))))
})

test_that("T5: the row builder adds the ICC columns and, when asked, the MC and bootstrap columns", {
  skip_on_cran()
  cell <- fc_grid()[fc_grid()$cell_id == 1022, ] # nolint: object_usage_linter.
  base <- fc_row(cell, 1, "p0") # nolint: object_usage_linter.
  expect_false(any(grepl("^(mc|bt)_", names(base))))
  expect_equal(base$icc_x_shipped, base$icc_x_lav, tolerance = 1e-3)
  expect_equal(base$icc_m_shipped, base$icc_m_lav, tolerance = 1e-3)
  r <- fc_row(cell, 1, "p0", mc_b = 50L, boot_b = 12L) # nolint: object_usage_linter.
  expect_identical(r[names(base)][setdiff(names(base), "fit_time")], base[setdiff(names(base), "fit_time")])
  for (e in fc_boot_effects) { # nolint: object_usage_linter.
    expect_true(all(c(paste0("mc_lo_", e), paste0("mc_hi_", e), paste0("bt_lo_", e), paste0("bt_kept_", e),
                      paste0("bt_err_", e)) %in% names(r)))
  }
  cs <- fc_t5_case()
  st <- fc_streams(fc_seed(1022, 1)) # nolint: object_usage_linter.
  mc <- fc_mc(cs$obj, n_boot = 50L, stream = st$mc) # nolint: object_usage_linter.
  expect_identical(r$mc_lo_nie_between, mc$lo[["nie_between"]])
  bt <- fc_with_stream(st$boot, fc_cluster_boot(cs$fit, cs$data, n_boot = 12L)) # nolint: object_usage_linter.
  expect_identical(r$bt_hi_nie_contrast, bt$hi[["nie_contrast"]])
})

# T6: the main delta and MC run (R = 1000) and P1 on its subset. The aggregation helpers live in
# tests/sim/twolevel-few-clusters-t6-lib.R; these checks run on synthetic rows, so they need no lavaan fit.
fc_t6_lib <- test_path("..", "sim", "twolevel-few-clusters-t6-lib.R")
source(fc_t6_lib, local = TRUE)
fc_t6_dir <- test_path("..", "..", "planning", "studies", "few-clusters")

# Synthetic per-dataset rows in the driver's layout: every fit clean, delta and MC intervals est -/+ 1.96 se.
fc_t6_rows <- function(cells = c(1001L, 1002L), reps = 4L, arms = c("p0"), seed = 1L) {
  g <- fc_grid() # nolint: object_usage_linter.
  jobs <- expand.grid(rep = seq_len(reps), arm = arms, cell_id = cells, stringsAsFactors = FALSE,
                      KEEP.OUT.ATTRS = FALSE)
  rows <- cbind(g[match(jobs$cell_id, g$cell_id), ], jobs[c("rep", "arm")])
  rownames(rows) <- NULL
  k <- nrow(rows)
  rows$lavaan_error <- NA_character_
  rows$adapter_error <- NA_character_
  rows$converged <- TRUE
  rows$between_identified <- TRUE
  rows$admissible <- TRUE
  rows$neg_l2_var <- FALSE
  rows$at_bound <- ifelse(rows$arm == "p1", FALSE, NA)
  rows$fit_time <- .5
  rows$mc_time <- .05
  withr::with_seed(seed, {
    for (e in fc_estimands) { # nolint: object_usage_linter.
      truth <- vapply(rows$nie_b, function(b) fc_truth(b)[[e]], numeric(1)) # nolint: object_usage_linter.
      se <- rep(.1, k)
      est <- truth + stats::rnorm(k, sd = .1)
      rows[[paste0("truth_", e)]] <- truth
      rows[[paste0("est_", e)]] <- est
      rows[[paste0("se_", e)]] <- se
      rows[[paste0("lo_", e)]] <- est - 1.96 * se
      rows[[paste0("hi_", e)]] <- est + 1.96 * se
    }
  })
  for (e in fc_boot_effects) { # nolint: object_usage_linter.
    rows[[paste0("mc_lo_", e)]] <- rows[[paste0("lo_", e)]]
    rows[[paste0("mc_hi_", e)]] <- rows[[paste0("hi_", e)]]
    rows[[paste0("mc_err_", e)]] <- NA_character_
  }
  rows
}

test_that("T6: the P1 subset is the T5 cells with an inadmissible rate above 10%, 49 cells, as committed", {
  t5 <- file.path(fc_t6_dir, "T5-cells.csv")
  p1 <- file.path(fc_t6_dir, "T6-p1-cells.csv")
  skip_if_not(file.exists(t5) && file.exists(p1), "planning/ is not shipped with the installed tests")
  cells <- utils::read.csv(t5, stringsAsFactors = FALSE)
  got <- fc_t6_p1_cells(cells) # nolint: object_usage_linter.
  expect_identical(nrow(got), 49L)
  expect_true(all(got$t5_inadmissible > .10))
  expect_true(all(cells$inadmissible[!cells$cell_id %in% got$cell_id] <= .10))
  committed <- utils::read.csv(p1, stringsAsFactors = FALSE)
  expect_identical(as.integer(committed$cell_id), as.integer(got$cell_id))
  expect_equal(committed$t5_inadmissible, got$t5_inadmissible)
  # planted defects: a cutoff that admits the .098 cell, and the negative-variance rate in place of the
  # inadmissible rate, each change the set
  expect_false(identical(fc_t6_p1_cells(cells, cutoff = .097)$cell_id, got$cell_id)) # nolint: object_usage_linter.
  wrong_col <- transform(cells, inadmissible = neg_l2_var)
  expect_false(identical(fc_t6_p1_cells(wrong_col)$cell_id, got$cell_id)) # nolint: object_usage_linter.
})

test_that("T6: the row check passes a complete run and errors on a short, duplicated or stray cell", {
  rows <- rbind(fc_t6_rows(c(1001L, 1002L), 4L, "p0"), fc_t6_rows(1001L, 4L, "p1"))
  cells <- c(1001L, 1002L)
  expect_invisible(fc_t6_check_rows(rows, reps = 4L, cells = cells, p1_cells = 1001L)) # nolint: object_usage_linter.
  # planted short cell: one P1 dataset missing
  short <- rows[!(rows$cell_id == 1001L & rows$arm == "p1" & rows$rep == 3L), ]
  expect_error(fc_t6_check_rows(short, 4L, cells, 1001L), "1001/p1.*3 rows") # nolint: object_usage_linter.
  # a duplicated replicate with the count still short of nothing: rep 2 twice, rep 4 missing
  dup <- rows
  dup$rep[dup$cell_id == 1002L & dup$rep == 4L] <- 2L
  expect_error(fc_t6_check_rows(dup, 4L, cells, 1001L), "1002/p0.*replicates") # nolint: object_usage_linter.
  # P1 rows in a cell outside the subset, and a missing cell
  stray <- rbind(rows, fc_t6_rows(1002L, 4L, "p1"))
  expect_error(fc_t6_check_rows(stray, 4L, cells, 1001L), "1002/p1") # nolint: object_usage_linter.
  expect_error(fc_t6_check_rows(rows, 4L, c(cells, 1003L), 1001L), "1003/p0") # nolint: object_usage_linter.
})

test_that("T6: the row check holds each cell to the launch's replicate range REP_START to REP_START + R - 1", {
  rows <- rbind(fc_t6_rows(c(1001L, 1002L), 4L, "p0"), fc_t6_rows(1001L, 4L, "p1"))
  cells <- c(1001L, 1002L)
  late <- rows
  late$rep <- late$rep + 500L
  expect_invisible(fc_t6_check_rows(late, 4L, cells, 1001L, rep_start = 501L)) # nolint: object_usage_linter.
  # planted wrong ranges: replicates 1 to 4 against a launch at 501, 501 to 504 against the default start, and a
  # range shifted by one
  expect_error(fc_t6_check_rows(rows, 4L, cells, 1001L, rep_start = 501L), "replicates 501 to 504") # nolint
  expect_error(fc_t6_check_rows(late, 4L, cells, 1001L), "replicates 1 to 4") # nolint: object_usage_linter.
  expect_error(fc_t6_check_rows(late, 4L, cells, 1001L, rep_start = 502L), "replicates 502 to 505") # nolint
  # the seed formula cell_id * 1e5 + rep needs the last replicate below 1e5
  expect_error(fc_t6_check_rows(late, 4L, cells, 1001L, rep_start = 99998L), "1e5") # nolint: object_usage_linter.
})

test_that("T6: the aggregation refuses rows from mixed builds or another lavaan than the launch's", {
  rows <- fc_t6_rows(1001L, 4L, "p0")
  rows$medfit_version <- "0.18.0.9000"
  rows$lavaan_version <- "0.6.19"
  expect_invisible(fc_t6_check_versions(rows, medfit = "0.18.0.9000", lavaan = "0.6.19")) # nolint
  # planted defects: a row file from another medfit, one from another lavaan, a lavaan other than the one recorded at
  # launch, and a row file without the version columns
  mixed_m <- rows
  mixed_m$medfit_version[2] <- "0.7.0"
  expect_error(fc_t6_check_versions(mixed_m, "0.18.0.9000", "0.6.19"), "medfit_version.*2 values") # nolint
  mixed_l <- rows
  mixed_l$lavaan_version[3] <- "0.6.17"
  expect_error(fc_t6_check_versions(mixed_l, "0.18.0.9000", "0.6.19"), "lavaan_version.*2 values") # nolint
  expect_error(fc_t6_check_versions(rows, "0.18.0.9000", "0.6.17"), "lavaan_version.*0.6.19.*0.6.17") # nolint
  expect_error(fc_t6_check_versions(rows, "0.17.0", "0.6.19"), "medfit_version.*0.18.0.9000.*0.17.0") # nolint
  expect_error(fc_t6_check_versions(rows[setdiff(names(rows), "lavaan_version")], "0.18.0.9000", "0.6.19"), # nolint
               "lavaan_version")
})

test_that("T6: the launch manifest is read as text and a missing one or a missing key is an error", {
  f <- withr::local_tempfile()
  writeLines(c("sha=abc123", "rep_start=501", "mc_b=2000", "eps=1e-3", "medfit_version=0.18.0.9000",
               "lavaan_version=1.0"), f)
  man <- fc_t6_read_manifest(f) # nolint: object_usage_linter.
  expect_identical(man$rep_start, "501")
  expect_identical(man$lavaan_version, "1.0")
  expect_error(fc_t6_read_manifest(paste0(f, "-absent")), "no launch manifest") # nolint: object_usage_linter.
  writeLines(c("sha=abc123", "rep_start=501", "mc_b=2000", "eps=1e-3"), f)
  expect_error(fc_t6_read_manifest(f), "lacks medfit_version, lavaan_version") # nolint: object_usage_linter.
})

test_that("T6: failure categories partition the rows and the aggregation errors when they do not sum to R", {
  rows <- fc_t6_rows(1001L, 6L, "p0")
  rows$lavaan_error[1] <- "boom"
  rows[1, c("converged", "between_identified", "admissible")] <- NA
  rows$converged[2] <- FALSE
  rows$adapter_error[2] <- "lavaan did not converge"
  rows[2, c("between_identified", "admissible")] <- NA
  rows$adapter_error[3] <- "other refusal"
  rows[3, c("between_identified", "admissible")] <- NA
  rows$between_identified[4] <- FALSE
  rows$admissible[5] <- FALSE
  cnt <- fc_t6_status_counts(rows, reps = 6L) # nolint: object_usage_linter.
  expect_identical(unlist(cnt[1, fc_t6_status_levels]), stats::setNames(rep(1L, 6), fc_t6_status_levels)) # nolint
  # planted mis-summed cells: a row in no category (identified status lost) and a row in two (an adapter error on
  # an identified fit)
  gap <- rows
  gap$between_identified[6] <- NA
  expect_error(fc_t6_status_counts(gap, 6L), "1001/p0.*sum to 5") # nolint: object_usage_linter.
  both <- rows
  both$adapter_error[6] <- "late refusal"
  expect_error(fc_t6_status_counts(both, 6L), "1001/p0.*sum to 7") # nolint: object_usage_linter.
  # the top-level aggregation stops (not warns) on both
  expect_error(fc_t6_aggregate(gap, reps = 6L, cells = 1001L, p1_cells = integer(0)), "sum to") # nolint
  expect_error(fc_t6_aggregate(rows[-6, ], reps = 6L, cells = 1001L, p1_cells = integer(0)), "5 rows") # nolint
})

test_that("T6: MCSEs match a hand calculation, and the cell summary carries them", {
  expect_equal(fc_t6_mcse_prop(.95, 1000), 0.0068920243760451, tolerance = 1e-12) # nolint: object_usage_linter.
  # sd(c(1, 2, 3, 6)) = sqrt(14 / 3); divided by sqrt(4)
  expect_equal(fc_t6_mcse_mean(c(1, 2, 3, 6)), sqrt(14 / 3) / 2, tolerance = 1e-12) # nolint: object_usage_linter.
  expect_equal(fc_t6_mcse_mean(c(1, NA, 2, 3, 6)), sqrt(14 / 3) / 2, tolerance = 1e-12) # nolint
  # planted defects: the variance over R instead of its square root, and n - 1 in the mean's denominator
  expect_failure(expect_equal(sqrt(.95 * .05) / 1000, 0.0068920243760451, tolerance = 1e-12))
  expect_failure(expect_equal(stats::sd(c(1, 2, 3, 6)) / sqrt(3), sqrt(14 / 3) / 2, tolerance = 1e-12))

  rows <- fc_t6_rows(1001L, 120L, "p0")
  e <- "nie_within"
  # 30 of 120 intervals moved off the truth: coverage .75 at most, counted by hand
  rows[[paste0("lo_", e)]][1:30] <- rows[[paste0("truth_", e)]][1:30] + .5
  rows[[paste0("hi_", e)]][1:30] <- rows[[paste0("truth_", e)]][1:30] + .6
  truth <- rows[[paste0("truth_", e)]]
  hit <- rows[[paste0("lo_", e)]] <= truth & truth <= rows[[paste0("hi_", e)]]
  p <- mean(hit)
  s <- fc_t6_summary(rows) # nolint: object_usage_linter.
  r <- s[s$estimand == e & s$interval == "delta", ]
  expect_identical(nrow(r), 1L)
  expect_identical(r$R, 120L)
  expect_equal(r$coverage, p)
  expect_equal(r$coverage_mcse, sqrt(p * (1 - p) / 120))
  # the 30 planted misses plus any clean interval that misses high by chance, counted by hand
  miss_high <- mean(rows[[paste0("lo_", e)]] > rows[[paste0("truth_", e)]])
  expect_gte(miss_high, 30 / 120)
  expect_equal(r$miss_high, miss_high)
  err <- rows[[paste0("est_", e)]] - rows[[paste0("truth_", e)]]
  expect_equal(r$bias, mean(err))
  expect_equal(r$bias_mcse, stats::sd(err) / sqrt(120))
  expect_equal(r$ccov, p)
  expect_equal(r$ccov_mcse, sqrt(p * (1 - p) / 120))
  # conditional coverage needs 100 intervals: 99 gives NA
  s99 <- fc_t6_summary(rows[1:99, ]) # nolint: object_usage_linter.
  expect_true(is.na(s99$ccov[s99$estimand == e & s99$interval == "delta"]))
  # the MC rows exist for the three effects only
  expect_setequal(s$estimand[s$interval == "mc"], fc_boot_effects) # nolint: object_usage_linter.
})

test_that("T6: the P0/P1 comparison pairs datasets and reports the at-bound sensitivity coverage", {
  p0 <- fc_t6_rows(1001L, 10L, "p0")
  p1 <- fc_t6_rows(1001L, 10L, "p1")
  e <- "nie_between"
  p1[[paste0("lo_", e)]][1:2] <- p1[[paste0("truth_", e)]][1:2] + 1
  p1$at_bound[3:4] <- TRUE
  cmp <- fc_t6_parametrization(rbind(p0, p1), p1_cells = 1001L) # nolint: object_usage_linter.
  r <- cmp[cmp$estimand == e & cmp$interval == "delta", ]
  ind0 <- fc_covered(p0)[[e]] # nolint: object_usage_linter.
  ind1 <- fc_covered(p1)[[e]] # nolint: object_usage_linter.
  expect_equal(r$coverage_diff, mean(ind1) - mean(ind0))
  expect_equal(r$coverage_diff_mcse, stats::sd(ind1 - ind0) / sqrt(10))
  expect_equal(r$at_bound_p1, .2)
  expect_equal(r$sens_coverage_p1, mean(ind1 & !p1$at_bound))
})
