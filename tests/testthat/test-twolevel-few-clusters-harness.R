# Few-clusters design study, tasks T1 to T3 (planning/PLAN-few-clusters-design-study-2026-11-16.md): the harness in
# tests/sim/twolevel-few-clusters-lib.R. T1: the between-level scale `s` and the implied ICCs match the section 4 table
# to 1e-3 (computed from the implied covariance matrices, not from the closed form), the unequal cluster sizes keep
# the mean and reach a CV near .5, seeds follow section 9, and the O8 likelihood oracle
# (helper-twolevel-likelihood.R) agrees with lavaan's logLik on three harness datasets. T2: on a planted dataset with
# a negative level-2 variance, the default fit (P0) ends below zero with a lavaan warning, the syntax floor (P1) ends
# at `eps` with no warning, and `bounds = "pos.var"` adds no bound to a two-level fit. Each check has a planted defect.

skip_if_not_installed("lavaan")
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
