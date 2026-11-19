# S4a.2 (planning/PLAN-S4a-native-twolevel-core-2026-11-18.md): the per-size sufficient statistics and the two-level
# log-likelihood at a fixed theta. Oracles: the O8 hand likelihood `tl_loglik()` (1e-10, an arithmetic identity),
# lavaan's logLik() at its own implied moments without Z (TL-4, 1e-6 relative), the nested-fit difference with a
# between-only Z (TL-4, 1e-6 absolute), the stacked multivariate normal density with Z (1e-10) and the balanced closed
# form (1e-10). Planted defects (TL-7) run through the same checks under expect_failure(), each with the fixture
# condition that makes it visible asserted first. lavaan fits use the TL-3 convention (tln_fit_lavaan()).

tl_w <- c("X", "M", "Y")

# Moments over W (and Z) for given path values, written by hand from the paths, not through the RAM code.
tln_hand_moments <- function(w_par, b_par, alpha) {
  sw <- tl_sigma(w_par[["a"]], w_par[["b"]], w_par[["cp"]], w_par[["vx"]], w_par[["vm"]], w_par[["vy"]])
  sb <- tl_sigma(b_par[["a"]], b_par[["b"]], b_par[["cp"]], b_par[["vx"]], b_par[["vm"]], b_par[["vy"]])
  b_mat <- matrix(0, 3, 3)
  b_mat[2, 1] <- b_par[["a"]]
  b_mat[3, 2] <- b_par[["b"]]
  b_mat[3, 1] <- b_par[["cp"]]
  mu <- stats::setNames(drop(solve(diag(3) - b_mat, alpha)), tl_w)
  list(sw = sw, sb = sb, mu = mu)
}

tln_theta_o8 <- function(tl) {
  theta <- c(a_w = 0.5, b_w = 0.4, cp_w = 0.2, "X~~X" = 1.1, "M~~M" = 0.8, "Y~~Y" = 0.9,
             a_b = 0.3, b_b = 0.6, cp_b = 0.1, "X~~X.l2" = 0.7, "M~~M.l2" = 0.5, "Y~~Y.l2" = 0.6,
             "X~1.l2" = 1.5, "M~1.l2" = -0.8, "Y~1.l2" = 2.2)
  stopifnot(setequal(names(theta), tl$par_names))
  theta[tl$par_names]
}

test_that("the theta map names level-2 parameters apart and shares a label across levels", {
  s <- tln_setup(tl_lavaan_model, tl_data_unbalanced())
  expect_setequal(s$tl$par_names, names(tln_theta_o8(s$tl)))
  expect_identical(s$tl$q, 15L)
  # one label at both levels is one theta entry (the existing pipeline's label rule)
  shared <- sub("M ~ a_b*X", "M ~ a_w*X", tl_lavaan_model, fixed = TRUE)
  s2 <- tln_setup(shared, tl_data_unbalanced())
  expect_identical(s2$tl$q, 14L)
  k <- match("a_w", s2$tl$par_names)
  expect_true(k %in% s2$tl$k1 && k %in% s2$tl$k2)
  # sets: W over level 1, W then Z over level 2
  sz <- tln_setup(tln_model_z(), tln_data_z())
  expect_setequal(sz$tl$within, tl_w)
  expect_identical(sz$tl$between, "Z")
})

test_that("the per-size statistics group clusters by size from the complete rows", {
  d <- tl_data_unbalanced()
  d$Y[1] <- NA # one incomplete row: cluster 1 drops from size 3 to 2
  s <- tln_setup(tl_lavaan_model, d)$smp
  sizes <- vapply(s$sizes, `[[`, 1, "n")
  counts <- vapply(s$sizes, `[[`, 1, "count")
  expect_identical(sort(sizes), c(2, 3, 5, 8, 12))
  expect_identical(counts[match(c(2, 3, 5, 8, 12), sizes)], c(1, 9, 10, 10, 10))
  expect_identical(s$n, nrow(d) - 1L)
  expect_identical(s$j, 40L)
})

test_that("moment level: native equals tl_loglik() to 1e-10 and lavaan logLik() to 1e-6 relative (TL-4)", {
  skip_if_not_installed("lavaan")
  for (d in list(tl_data_balanced(), tl_data_unbalanced())) {
    s <- tln_setup(tl_lavaan_model, d)
    fit <- tln_fit_lavaan(tl_lavaan_model, d)
    m <- tln_lavaan_moments(fit, tl_w)
    native <- tln_native(s$smp, m)
    hand <- tl_loglik(tl_stats(d), m$sw[tl_w, tl_w], m$sb[tl_w, tl_w], m$mu[tl_w])
    tln_check_rel(native, hand, 1e-10)
    tln_check_rel(native, as.numeric(lavaan::logLik(fit)), 1e-6) # TL-4
    # away from the optimum too
    h <- tln_hand_moments(c(a = .2, b = .7, cp = -.1, vx = 1.4, vm = .6, vy = 1.2),
                          c(a = .5, b = .2, cp = .3, vx = .4, vm = .9, vy = .3), c(1, 0, -1))
    tln_check_rel(tln_native(s$smp, h), tl_loglik(tl_stats(d), h$sw, h$sb, h$mu), 1e-10)
  }
})

test_that("with a between-only Z: native equals the stacked density to 1e-10", {
  skip_if_not_installed("lavaan")
  d <- tln_data_z()
  s <- tln_setup(tln_model_z(), d)
  fit <- tln_fit_lavaan(tln_model_z(), d)
  m <- tln_lavaan_moments(fit, tl_w, "Z")
  expect_gt(abs(m$sb["X", "Z"]), 0.05)
  tln_check_rel(tln_native(s$smp, m), tln_stacked(d, tl_w, "Z", m$sw, m$sb, m$mu), 1e-10)
})

test_that("with a between-only Z: nested-fit difference equals lavaan's to 1e-6 absolute (TL-4)", {
  skip_if_not_installed("lavaan")
  d <- tln_data_z()
  s <- tln_setup(tln_model_z(), d)
  f1 <- tln_fit_lavaan(tln_model_z(), d)
  f0 <- tln_fit_lavaan(tln_model_z("M ~ X + 0*Z"), d)
  m1 <- tln_lavaan_moments(f1, tl_w, "Z")
  m0 <- tln_lavaan_moments(f0, tl_w, "Z")
  lav_diff <- as.numeric(lavaan::logLik(f1)) - as.numeric(lavaan::logLik(f0))
  expect_gt(abs(lav_diff), 1e-3) # the nested fits differ, so the check has something to compare
  tln_check_abs(tln_native(s$smp, m1) - tln_native(s$smp, m0), lav_diff, 1e-6)
})

test_that("balanced data through the per-size code equals the balanced closed form", {
  d <- tl_data_balanced()
  s <- tln_setup(tl_lavaan_model, d)
  h <- tln_hand_moments(c(a = .5, b = .4, cp = .2, vx = 1.1, vm = .8, vy = .9),
                        c(a = .3, b = .6, cp = .1, vx = .7, vm = .5, vy = .6), c(1.5, -.8, 2.2))
  tln_check_rel(tln_native(s$smp, h), tln_balanced_closed(d, tl_w, character(), h$sw, h$sb, h$mu), 1e-10)
  dz <- tln_data_z_balanced()
  sz <- tln_setup(tln_model_z(), dz)
  sb <- matrix(c(.7, .2, .1, .3, .2, .9, .25, .1, .1, .25, .8, .05, .3, .1, .05, .6), 4, 4,
               dimnames = list(c(tl_w, "Z"), c(tl_w, "Z")))
  mu <- c(X = 1.5, M = -.8, Y = 2.2, Z = .1)
  tln_check_rel(tln_native(sz$smp, list(sw = h$sw, sb = sb, mu = mu)),
                tln_balanced_closed(dz, tl_w, "Z", h$sw, sb, mu), 1e-10)
})

test_that("theta level: theta maps to the hand moments and .sem_eval() equals the moment level to 1e-10", {
  d <- tl_data_unbalanced()
  s <- tln_setup(tl_lavaan_model, d)
  theta <- tln_theta_o8(s$tl)
  mom <- .sem_twolevel_implied(s$tl, theta)
  h <- tln_hand_moments(c(a = .5, b = .4, cp = .2, vx = 1.1, vm = .8, vy = .9),
                        c(a = .3, b = .6, cp = .1, vx = .7, vm = .5, vy = .6), c(1.5, -.8, 2.2))
  expect_lt(max(abs(mom$sigma_w[tl_w, tl_w] - h$sw)), 1e-12)
  expect_lt(max(abs(mom$sigma_b[tl_w, tl_w] - h$sb)), 1e-12)
  expect_lt(max(abs(mom$mu_b[tl_w] - h$mu)), 1e-12)
  ev <- .sem_eval(theta, s$tl, s$smp, deriv = FALSE)
  tln_check_rel(ev$loglik, tln_native(s$smp, h), 1e-10)
  tln_check_rel(ev$loglik, tl_loglik(tl_stats(d), h$sw, h$sb, h$mu), 1e-10)
  expect_identical(ev$f, -2 * ev$loglik / s$smp$n)
  # with Z: the level-2 RAM carries the full W-Z block (here through the free X ~~ Z covariance)
  dz <- tln_data_z()
  sz <- tln_setup(tln_model_z(), dz)
  th <- stats::setNames(rep(0, sz$tl$q), sz$tl$par_names)
  th[grepl("~~", names(th))] <- 0.6
  th[c("X~~Z.l2", "M~X.l2", "M~Z.l2", "Y~M.l2", "M~X", "Y~M")] <- c(0.3, 0.4, -0.2, 0.5, 0.45, 0.35)
  mz <- .sem_twolevel_implied(sz$tl, th)
  expect_gt(abs(mz$sigma_b["X", "Z"]), 0.05)
  evz <- .sem_eval(th, sz$tl, sz$smp, deriv = FALSE)
  tln_check_rel(evz$loglik, tln_stacked(dz, tl_w, "Z", mz$sigma_w[tl_w, tl_w], mz$sigma_b, mz$mu_b), 1e-10)
  # a non-positive-definite Sigma_W is an unusable point (NULL), as in the single-level worker
  bad <- theta
  bad["X~~X"] <- -1
  expect_null(.sem_eval(bad, s$tl, s$smp, deriv = FALSE))
})

test_that("planted defect: n_j replaced by the mean size fails TL-4 on unbalanced sizes", {
  skip_if_not_installed("lavaan")
  d <- tl_data_unbalanced()
  s <- tln_setup(tl_lavaan_model, d)
  expect_gt(length(unique(table(d$cluster))), 1L)
  fit <- tln_fit_lavaan(tl_lavaan_model, d)
  m <- tln_lavaan_moments(fit, tl_w)
  nbar <- nrow(d) / length(unique(d$cluster))
  orig <- .sem_ml2_between_cov
  local_mocked_bindings(.sem_ml2_between_cov = function(sigma_b, sigma_w, n, w_idx) {
    orig(sigma_b, sigma_w, nbar, w_idx)
  })
  expect_failure(tln_check_rel(tln_native(s$smp, m), as.numeric(lavaan::logLik(fit)), 1e-6))
})

test_that("planted defect: dropping p_w log n_j fails TL-4 when sizes differ from 1", {
  skip_if_not_installed("lavaan")
  d <- tl_data_unbalanced()
  s <- tln_setup(tl_lavaan_model, d)
  expect_true(all(table(d$cluster) != 1L))
  fit <- tln_fit_lavaan(tl_lavaan_model, d)
  m <- tln_lavaan_moments(fit, tl_w)
  local_mocked_bindings(.sem_ml2_det_terms = function(n, p_w, ld_w) (n - 1) * ld_w)
  expect_failure(tln_check_rel(tln_native(s$smp, m), as.numeric(lavaan::logLik(fit)), 1e-6))
})

test_that("planted defect: dropping (n_j - 1) log|Sigma_W| fails TL-4 when log|Sigma_W| is away from 0", {
  skip_if_not_installed("lavaan")
  d <- tl_data_unbalanced()
  s <- tln_setup(tl_lavaan_model, d)
  fit <- tln_fit_lavaan(tl_lavaan_model, d)
  m <- tln_lavaan_moments(fit, tl_w)
  expect_gt(abs(as.numeric(determinant(m$sw, logarithm = TRUE)$modulus)), 0.1)
  local_mocked_bindings(.sem_ml2_det_terms = function(n, p_w, ld_w) p_w * log(n))
  expect_failure(tln_check_rel(tln_native(s$smp, m), as.numeric(lavaan::logLik(fit)), 1e-6))
})

test_that("planted defect: dropping the Sigma_B,WZ block fails the stacked oracle and the TL-4 difference", {
  skip_if_not_installed("lavaan")
  d <- tln_data_z()
  s <- tln_setup(tln_model_z(), d)
  f1 <- tln_fit_lavaan(tln_model_z(), d)
  f0 <- tln_fit_lavaan(tln_model_z("M ~ X + 0*Z"), d)
  m1 <- tln_lavaan_moments(f1, tl_w, "Z")
  m0 <- tln_lavaan_moments(f0, tl_w, "Z")
  expect_gt(max(abs(m1$sb[tl_w, "Z"])), 0.05)
  expect_gt(abs(m0$sb["X", "Z"]), 0.05)
  lav_diff <- as.numeric(lavaan::logLik(f1)) - as.numeric(lavaan::logLik(f0))
  orig <- .sem_ml2_between_cov
  local_mocked_bindings(.sem_ml2_between_cov = function(sigma_b, sigma_w, n, w_idx) {
    v <- orig(sigma_b, sigma_w, n, w_idx)
    v[w_idx, -w_idx] <- 0
    v[-w_idx, w_idx] <- 0
    v
  })
  expect_failure(tln_check_rel(tln_native(s$smp, m1), tln_stacked(d, tl_w, "Z", m1$sw, m1$sb, m1$mu), 1e-10))
  expect_failure(tln_check_abs(tln_native(s$smp, m1) - tln_native(s$smp, m0), lav_diff, 1e-6))
})

test_that("the single-level .sem_eval() path is unchanged by the two-level dispatch", {
  mod <- sem_model_observed()
  d <- sem_sim(mod, 300, seed = 3)
  smp <- .sem_sample(d, mod$ram)
  # the worker with the dispatch line removed is the origin/dev body
  orig <- sem_mutate(.sem_eval, "return(.sem_eval_ml2(theta, ram, smp, deriv))", "NULL")
  for (deriv in c(FALSE, TRUE)) {
    expect_identical(.sem_eval(mod$theta, mod$ram, smp, deriv), orig(mod$theta, mod$ram, smp, deriv))
  }
  # with a mean structure
  ram_m <- .sem_ram(mod$ram$vars, mod$ram$obs, mod$a, mod$s,
                    data.frame(row = mod$ram$obs, label = "", value = NA_real_, stringsAsFactors = FALSE))
  th <- c(mod$theta, stats::setNames(c(.1, -.2, .3, .4), paste0(mod$ram$obs, "~1")))[ram_m$par_names]
  smp_m <- .sem_sample(d, ram_m)
  expect_identical(.sem_eval(th, ram_m, smp_m, TRUE), orig(th, ram_m, smp_m, TRUE))
})

test_that("fit_sem() still stops on a valid two-level model (no fitter before S4a.4)", {
  expect_error(fit_sem(tl_lavaan_model, tl_data_unbalanced(), cluster = "cluster"),
               class = "medfit_error_twolevel_not_implemented")
  expect_error(fit_sem(tln_model_z(), tln_data_z(), cluster = "cluster"),
               class = "medfit_error_twolevel_not_implemented")
})
