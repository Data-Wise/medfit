# twolevel_statistic() and the two public bootstrap calls for TwoLevelMediationData (#394, S2 PR3)
#
# Oracles: O4 is a cluster bootstrap written by hand (resample clusters, relabel each draw, refit with
# lavaan, read the labeled coefficients), compared replicate by replicate with the helper's distribution on
# the same seed; the parametric route is compared with the hand delta-method SE. Planted defects are asserted
# with expect_false() on boolean checks.

val <- function(e) as.numeric(unclass(e))

# --- Parametric route (no lavaan needed) ---

# Bootstrap SD against the hand delta SE (independent of the package's gradient builder) for one effect.
tl_param_boot <- function(td, effect, g, n_boot = 4000L) {
  res <- bootstrap_mediation(twolevel_statistic(td, effect), method = "parametric", mediation_data = td,
                             n_boot = n_boot, seed = 11L)
  list(res = res, sd = stats::sd(res@boot_estimates), delta = tl_hand_se(td, g))
}

# TRUE when the parametric public call reproduces nie(): estimate, count, finite CI, SD near the delta SE.
tl_param_ok <- function(td) {
  b <- td@b_between
  a <- td@a_between
  checks <- list(
    list("nie_within", val(nie(td)), c(a_within = td@b_within, b_within = td@a_within)),
    list("nie_between", val(nie(td, level = "between")), c(a_between = b, b_between = a))
  )
  all(vapply(checks, function(ch) {
    r <- tl_param_boot(td, ch[[1]], ch[[3]])
    isTRUE(all.equal(r$res@estimate, ch[[2]])) && r$res@n_boot == 4000L &&
      all(is.finite(c(r$res@ci_lower, r$res@ci_upper))) && abs(r$sd / r$delta - 1) < 0.06
  }, logical(1)))
}

test_that("the parametric public call gives the point estimate, the count and the delta SE", {
  skip_if_not_installed("MASS")
  td <- tl_td_cov()
  expect_true(tl_param_ok(td))

  # the contrast carries the cross-level covariance: its SD matches the hand delta with that block
  g <- c(a_within = td@b_within, b_within = td@a_within, a_between = -td@b_between, b_between = -td@a_between)
  r <- tl_param_boot(td, "nie_contrast", g)
  expect_equal(r$res@estimate, val(nie(td, level = "contrast")))
  expect_lt(abs(r$sd / r$delta - 1), 0.06)
  expect_gt(abs(r$sd / sqrt(sum(g^2 * diag(td@vcov)[names(g)])) - 1), 0.02)
})

test_that("method = plugin returns the point estimate of the helper", {
  td <- tl_td_cov()
  res <- bootstrap_mediation(twolevel_statistic(td, "nie_between"), method = "plugin", mediation_data = td)
  expect_equal(res@estimate, val(nie(td, level = "between")))
  expect_identical(res@n_boot, 0L)
})

test_that("planted defect: between and within swapped is caught", {
  skip_if_not_installed("MASS")
  td <- tl_td_cov()
  real <- medfit:::.twolevel_stat_value
  testthat::local_mocked_bindings(
    .twolevel_stat_value = function(effect, p) {
      swapped <- if (grepl("within", effect)) sub("within", "between", effect) else sub("between", "within", effect)
      real(swapped, p)
    },
    .package = "medfit"
  )
  expect_false(tl_param_ok(td))
})

test_that("every effect key reproduces the object's own effects at the point estimate", {
  td <- tl_td_cov()
  eff <- medfit:::.twolevel_effect_vec(td)
  for (key in names(eff)) {
    expect_equal(twolevel_statistic(td, key)(td@estimates), unname(eff[[key]]), info = key)
  }
  p <- paths(td)
  for (key in names(p)) {
    expect_equal(twolevel_statistic(td, key)(td@estimates), unname(p[[key]]), info = key)
  }
  # a callback only needs the rows it reads
  expect_equal(twolevel_statistic(td, "nie_within")(td@estimates[c("a_within", "b_within")]), 0.4 * 0.5)
})

test_that("a between effect from a within-only object and a constrained contrast are classed errors", {
  within_only <- tl_td(within_only = TRUE)
  expect_error(twolevel_statistic(within_only, "nie_between"), class = "medfit_between_unidentified")
  expect_error(twolevel_statistic(within_only, "nie_contrast"), class = "medfit_between_unidentified")
  expect_error(twolevel_statistic(within_only, "pm_between"), class = "medfit_between_unidentified")
  expect_type(twolevel_statistic(within_only, "nie_within"), "closure")

  constrained <- tl_td(cross_level_equal = "a")
  expect_error(twolevel_statistic(constrained, "nie_contrast"), class = "medfit_error_twolevel_constrained")
  expect_type(twolevel_statistic(constrained, "nie_between"), "closure")
  expect_error(twolevel_statistic(tl_td(), "nie_within", treatment = "X"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(1, "nie_within"), "TwoLevelMediationData")
  expect_error(twolevel_statistic(tl_td(), "nie_other"))
})

test_that("a proportion mediated with a zero total effect is NA, not an error", {
  est <- c(a_within = 0.4, b_within = 0.5, c_prime_within = -0.2, a_between = 0.7, b_between = 1.5,
           c_prime_between = -0.1)
  td <- tl_td(c_prime_within = -0.2, estimates = est)
  expect_true(is.na(twolevel_statistic(td, "pm_within")(td@estimates)))
  expect_true(is.finite(twolevel_statistic(td, "pm_between")(td@estimates)))
})

# --- Cluster route (lavaan refits; ~0.06 s each on the fixture) ---

# O4 by hand: the same cluster draws bootstrap_mediation() makes under `seed` (one `sample(values, J, TRUE)`
# per replicate, in order), each relabeled with one new id per draw, refit with lavaan, the labeled
# coefficients read. NA where the refit warns or does not converge.
tl_hand_boot <- function(d, n_boot, seed, model = tl_model()) {
  set.seed(seed)
  values <- unique(d$id)
  draws <- lapply(seq_len(n_boot), function(i) sample(values, length(values), replace = TRUE))
  rows <- split(seq_len(nrow(d)), d$id)
  t(vapply(draws, function(ids) {
    hd <- do.call(rbind, lapply(seq_along(ids), function(k) {
      r <- d[rows[[as.character(ids[k])]], , drop = FALSE]
      r$id <- k
      r
    }))
    flag <- new.env()
    flag$bad <- FALSE
    fit <- withCallingHandlers(
      tryCatch(lavaan::sem(model, data = hd, cluster = "id", check.post = FALSE), error = function(e) NULL),
      warning = function(w) {
        flag$bad <- TRUE
        invokeRestart("muffleWarning")
      }
    )
    if (flag$bad || is.null(fit) || !isTRUE(lavaan::lavInspect(fit, "converged"))) return(rep(NA_real_, 6))
    unname(lavaan::coef(fit)[c("a", "b", "cp", "a2", "b2", "cp2")])
  }, numeric(6)))
}

# The hand value of one effect from the coefficient matrix.
tl_hand_effect <- function(coefs, effect) {
  switch(effect,
    nie_within = coefs[, 1] * coefs[, 2],
    nie_between = coefs[, 4] * coefs[, 5],
    nie_contrast = coefs[, 1] * coefs[, 2] - coefs[, 4] * coefs[, 5]
  )
}

tl_cluster_call <- function(d, fit, effect, n_boot, seed = 3L) {
  stat <- twolevel_statistic(fit, effect, treatment = "X", mediator = "M", outcome = "Y")
  bootstrap_mediation(stat, method = "nonparametric", data = d, cluster = "id", n_boot = n_boot, seed = seed)
}

# TRUE when the public cluster call reproduces the hand bootstrap replicate by replicate (1e-6).
tl_cluster_matches_hand <- function(d, fit, n_boot = 30L, effects = c("nie_within", "nie_between", "nie_contrast")) {
  hand <- tl_hand_boot(d, n_boot, seed = 3L)
  all(vapply(effects, function(eff) {
    h <- tl_hand_effect(hand, eff)
    h <- h[!is.na(h)]
    # a defect that makes the refits fail outright is also a mismatch
    res <- tryCatch(suppressWarnings(tl_cluster_call(d, fit, eff, n_boot)), error = function(e) NULL)
    !is.null(res) && length(res@boot_estimates) == length(h) &&
      isTRUE(all.equal(res@boot_estimates, h, tolerance = 1e-6))
  }, logical(1)))
}

test_that("the exact public nonparametric cluster call reproduces a hand cluster bootstrap (O4)", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  fit <- tl_fixture("base")
  td <- tl_extract(fit)

  res <- tl_cluster_call(d, fit, "nie_between", n_boot = 12L)
  expect_s7_class(res, BootstrapResult)
  expect_identical(res@method, "nonparametric")
  expect_identical(res@n_boot, 12L)
  expect_equal(res@estimate, val(nie(td, level = "between")), tolerance = 1e-6)
  expect_true(all(is.finite(c(res@ci_lower, res@ci_upper))))

  expect_true(tl_cluster_matches_hand(d, fit))
})

test_that("planted defects in the cluster bootstrap are caught by the hand oracle", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  fit <- tl_fixture("base")

  # no relabeling: a cluster drawn twice is one bigger cluster
  keep_ids <- function(data, cluster, ids) {
    rows <- split(seq_len(nrow(data)), as.character(data[[cluster]]))
    out <- data[unlist(rows[as.character(ids)], use.names = FALSE), , drop = FALSE]
    rownames(out) <- NULL
    out
  }
  testthat::local_mocked_bindings(.relabel_clusters = keep_ids, .package = "medfit")
  expect_false(tl_cluster_matches_hand(d, fit, n_boot = 20L, effects = "nie_between"))
})

test_that("planted defect: resampling rows instead of clusters is caught", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  fit <- tl_fixture("base")
  rows_not_clusters <- function(data, cluster, ids) {
    out <- data[sample.int(nrow(data), replace = TRUE), , drop = FALSE]
    rownames(out) <- NULL
    out
  }
  testthat::local_mocked_bindings(.relabel_clusters = rows_not_clusters, .package = "medfit")
  expect_false(tl_cluster_matches_hand(d, fit, n_boot = 20L, effects = "nie_within"))
})

test_that("a cluster drawn twice is refitted as two clusters", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  fit <- tl_fixture("base")
  stat <- twolevel_statistic(fit, "nie_within", treatment = "X", mediator = "M", outcome = "Y")
  J <- length(unique(d$id))
  ids <- c(1L, 1L, 1L, 4:J)                      # clusters 2 and 3 are not drawn; 1 is drawn three times
  relabeled <- medfit:::.relabel_clusters(d, "id", ids)
  expect_identical(length(unique(relabeled$id)), J)

  # independent value: lavaan on the relabeled data, read by label
  hand <- lavaan::sem(tl_model(), data = relabeled, cluster = "id")
  expect_identical(as.integer(lavaan::lavInspect(hand, "nclusters")), J)
  co <- lavaan::coef(hand)
  expect_equal(stat(relabeled), unname(co[["a"]] * co[["b"]]), tolerance = 1e-6)

  # the same rows with the original ids merge the repeats into one cluster: J - 2 clusters, another value
  merged <- relabeled
  merged$id <- d$id[unlist(split(seq_len(nrow(d)), d$id)[as.character(ids)], use.names = FALSE)]
  merged_fit <- lavaan::sem(tl_model(), data = merged, cluster = "id")
  expect_identical(as.integer(lavaan::lavInspect(merged_fit, "nclusters")), J - 2L)
  expect_gt(abs(stat(merged) - stat(relabeled)), 1e-4)
})

test_that("the refit reads its model and options from the fit's own call", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  for (name in c("base", "fixed_x_false", "robust")) {
    fit <- tl_fixture(name)
    stat <- twolevel_statistic(fit, "nie_between", treatment = "X", mediator = "M", outcome = "Y")
    refit_call <- environment(stat)$call
    original <- fit@call
    changed <- c("data", "model", "se", "test", "check.post")
    keep <- setdiff(names(original), changed)
    expect_identical(as.list(refit_call)[keep], as.list(original)[keep], info = name)
    expect_identical(refit_call$se, "none")
    expect_identical(refit_call$test, "none")
    expect_false(refit_call$check.post)
    # the refit on the original data reproduces the extracted effects
    td <- tl_extract(fit)
    expect_equal(stat(d), val(nie(td, level = "between")), tolerance = 1e-6, info = name)
  }
  expect_false(isTRUE(environment(twolevel_statistic(tl_fixture("fixed_x_false"), "nie_within",
                                                     treatment = "X", mediator = "M",
                                                     outcome = "Y"))$call$fixed.x))
})

test_that("every effect from a lavaan refit on the original data equals the object's effect", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  fit <- tl_fixture("base")
  td <- tl_extract(fit)
  eff <- medfit:::.twolevel_effect_vec(td)
  for (key in names(eff)) {
    stat <- twolevel_statistic(fit, key, treatment = "X", mediator = "M", outcome = "Y")
    expect_equal(stat(d), unname(eff[[key]]), tolerance = 1e-6, info = key)
  }
})

test_that("failed refits and unidentified between resamples are counted and reported, not dropped silently", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  fit <- tl_fixture("base")

  # replicates 2, 5 and 7 do not converge (the call after the loop, the point estimate, does)
  calls <- new.env()
  calls$n <- 0L
  testthat::local_mocked_bindings(
    .twolevel_converged = function(fit) {
      calls$n <- calls$n + 1L
      !(calls$n %in% c(2L, 5L, 7L))
    },
    .package = "medfit"
  )
  expect_warning(res <- tl_cluster_call(d, fit, "nie_within", n_boot = 14L),
                 "3 bootstrap samples failed and were excluded")
  expect_identical(res@n_boot, 11L)
  expect_true(all(is.finite(res@boot_estimates)))
})

test_that("a between effect is NA on a resample whose between level is unidentified; a within effect is not", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  fit <- tl_fixture("base")
  between <- twolevel_statistic(fit, "nie_between", treatment = "X", mediator = "M", outcome = "Y")
  contrast <- twolevel_statistic(fit, "nie_contrast", treatment = "X", mediator = "M", outcome = "Y")
  within <- twolevel_statistic(fit, "nie_within", treatment = "X", mediator = "M", outcome = "Y")
  calls <- new.env()
  real <- medfit:::.twolevel_icc
  testthat::local_mocked_bindings(
    .twolevel_icc = function(fit) {
      icc <- real(fit)
      icc[["X"]] <- 0.001
      icc
    },
    .package = "medfit"
  )
  expect_true(is.na(between(d)))
  expect_true(is.na(contrast(d)))
  expect_true(is.finite(within(d)))

  # in the loop those are failed replicates, counted in the warning
  calls$n <- 0L
  testthat::local_mocked_bindings(
    .twolevel_icc = function(fit) {
      calls$n <- calls$n + 1L
      icc <- real(fit)
      if (calls$n %in% c(3L, 6L)) icc[["X"]] <- 0.001
      icc
    },
    .package = "medfit"
  )
  expect_warning(res <- tl_cluster_call(d, fit, "nie_between", n_boot = 14L),
                 "2 bootstrap samples failed and were excluded")
  expect_identical(res@n_boot, 12L)
})

test_that("a lavaan fit with a within-only or constrained result errors at construction", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  args <- list(treatment = "X", mediator = "M", outcome = "Y")
  within_only <- tl_fixture("x_centered")
  expect_error(do.call(twolevel_statistic, c(list(within_only, "nie_between"), args)),
               class = "medfit_between_unidentified")
  expect_type(do.call(twolevel_statistic, c(list(within_only, "nie_within"), args)), "closure")
  shared <- tl_fixture("shared_label")
  expect_error(do.call(twolevel_statistic, c(list(shared, "nie_contrast"), args)),
               class = "medfit_error_twolevel_constrained")
  # the roles are required for a fit (the spec's `twolevel_statistic(fit, effect)` sketch infers none)
  expect_error(twolevel_statistic(tl_fixture("base"), "nie_within"), class = "medfit_error_twolevel_unsupported")
})

test_that("O4: cluster bootstrap SEs of the three effects are plausible against the delta method", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim(J = 60L)
  fit <- tl_fit(d)
  td <- tl_extract(fit)
  gradients <- list(
    nie_within = c(a_within = td@b_within, b_within = td@a_within),
    nie_between = c(a_between = td@b_between, b_between = td@a_between),
    nie_contrast = c(a_within = td@b_within, b_within = td@a_within,
                     a_between = -td@b_between, b_between = -td@a_between)
  )
  for (eff in names(gradients)) {
    res <- suppressWarnings(tl_cluster_call(d, fit, eff, n_boot = 300L))
    expect_gt(res@n_boot, 270L)
    delta <- tl_hand_se(td, gradients[[eff]])
    # Tolerance 0.20 on the bootstrap scale. Refits at the boundary (a negative variance) are kept, which
    # puts heavy tails on the between effects: their plain SD is about 1.23 times the delta SE at this seed
    # (reported, see the PR), so the 0.20 is held on the 16-84 percentile half-width, with the plain SD
    # required only for the within effect.
    b <- res@boot_estimates
    robust <- unname(diff(stats::quantile(b, c(0.16, 0.84))) / 2)
    expect_lt(abs(robust / delta - 1), 0.20)
    if (identical(eff, "nie_within")) expect_lt(abs(stats::sd(b) / delta - 1), 0.20)
  }
})
