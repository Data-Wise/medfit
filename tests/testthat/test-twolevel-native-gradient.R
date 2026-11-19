# S4a.3 (planning/PLAN-S4a-native-twolevel-core-2026-11-18.md): the analytic gradient of the two-level objective
# f = -2 log L / N. Oracle: Richardson-extrapolated central differences of the S4a.2 objective `.sem_eval_ml2()$f` at
# 20 random admissible thetas per fixture. Error measure: max_i |g_i - g_fd,i| / max(1, max_i |g_fd,i|), tolerance
# 1e-6. Planted defects (TL-7) change only the gradient (never f), and each must exceed the tolerance by a clear margin.

tl_w <- c("X", "M", "Y")

# Richardson extrapolation of central differences: R(h) = (4 D(h/2) - D(h)) / 3, error O(h^4). The oracle is R(h/2);
# `err` = |R(h/2) - R(h)| estimates its error (an upper estimate: R(h) has 16 times the truncation error of R(h/2)).
# NULL when any step is unusable.
tlg_fd <- function(theta, tl, smp) {
  f <- function(th) {
    r <- .sem_eval_ml2(th, tl, smp, deriv = FALSE)
    if (is.null(r)) NA_real_ else r$f
  }
  d <- function(i, h) {
    e <- numeric(length(theta))
    e[i] <- h
    (f(theta + e) - f(theta - e)) / (2 * h)
  }
  out <- vapply(seq_along(theta), function(i) {
    h <- 1e-3 * max(1, abs(theta[[i]]))
    d1 <- d(i, h)
    d2 <- d(i, h / 2)
    d4 <- d(i, h / 4)
    r1 <- (4 * d2 - d1) / 3
    r2 <- (4 * d4 - d2) / 3
    c(r2, abs(r2 - r1))
  }, numeric(2))
  if (anyNA(out)) return(NULL)
  list(g = out[1, ], err = out[2, ])
}

tlg_rel <- function(g, fd) max(abs(g - fd)) / max(1, max(abs(fd)))

# Base theta: paths 0.3, variances 0.8, covariances 0.1, means 0.5; draws perturb every entry uniformly in
# [-0.35, 0.35] (variances in [0.4, 1.2]) and are kept only when the point and every finite-difference step are usable.
tlg_draws <- function(tl, smp, n_draws = 20L, seed = 1) {
  withr::local_seed(seed)
  nm <- tl$par_names
  var_par <- vapply(strsplit(sub("\\.l2$", "", nm), "~~", fixed = TRUE), function(p) {
    length(p) == 2L && p[1] == p[2]
  }, TRUE)
  cov_par <- grepl("~~", nm, fixed = TRUE) & !var_par
  mean_par <- grepl("~1", nm, fixed = TRUE)
  base <- ifelse(var_par, 0.8, ifelse(cov_par, 0.1, ifelse(mean_par, 0.5, 0.3)))
  out <- list()
  tries <- 0L
  while (length(out) < n_draws) {
    tries <- tries + 1L
    stopifnot(tries < 50L * n_draws)
    th <- stats::setNames(base + stats::runif(length(base), -0.35, 0.35), nm)
    if (is.null(.sem_eval_ml2(th, tl, smp, deriv = FALSE))) next
    fd <- tlg_fd(th, tl, smp)
    if (is.null(fd)) next
    out[[length(out) + 1L]] <- list(theta = th, fd = fd)
  }
  out
}

tlg_shared_model <- sub("M ~ a_b*X", "M ~ a_w*X", tl_lavaan_model, fixed = TRUE)
tlg_mean_model <- paste0(tl_lavaan_model, "  Y ~ ny*1\n  X ~ 0*1\n")

tlg_fixtures <- function() {
  unb <- tl_simulate(rep(2:9, 6), seed = 31)
  list(
    balanced = list(model = tl_lavaan_model, data = tl_data_balanced()),
    unbalanced = list(model = tl_lavaan_model, data = unb),
    balanced_z = list(model = tln_model_z(), data = tln_data_z_balanced()),
    unbalanced_z = list(model = tln_model_z(), data = tln_add_z(unb)),
    shared_label = list(model = tlg_shared_model, data = unb),
    level2_means = list(model = tlg_mean_model, data = unb)
  )
}

tlg_cache <- new.env()
tlg_setup_draws <- function(name) {
  if (is.null(tlg_cache[[name]])) {
    fx <- tlg_fixtures()[[name]]
    s <- tln_setup(fx$model, fx$data)
    tlg_cache[[name]] <- list(s = s, draws = tlg_draws(s$tl, s$smp))
  }
  tlg_cache[[name]]
}

test_that("the fixtures exercise sizes 2..9, Z, a shared label, labeled and fixed level-2 means", {
  u <- tlg_setup_draws("unbalanced")$s
  expect_identical(sort(vapply(u$smp$sizes, `[[`, 1, "n")), as.numeric(2:9))
  z <- tlg_setup_draws("unbalanced_z")$s
  expect_identical(z$tl$between, "Z")
  expect_true("X~~Z.l2" %in% z$tl$par_names)
  sh <- tlg_setup_draws("shared_label")$s
  k <- match("a_w", sh$tl$par_names)
  expect_true(k %in% sh$tl$k1 && k %in% sh$tl$k2)
  mn <- tlg_setup_draws("level2_means")$s
  expect_true("ny" %in% mn$tl$par_names)
  expect_false(any(c("X~1.l2", "X~1") %in% mn$tl$par_names))
})

for (fx_name in names(tlg_fixtures())) {
  test_that(sprintf("analytic gradient equals Richardson central differences to 1e-6 (%s)", fx_name), {
    cs <- tlg_setup_draws(fx_name)
    rel <- fd_err <- numeric(length(cs$draws))
    for (i in seq_along(cs$draws)) {
      dr <- cs$draws[[i]]
      ev <- .sem_eval_ml2(dr$theta, cs$s$tl, cs$s$smp, deriv = TRUE)
      expect_identical(ev$f, .sem_eval_ml2(dr$theta, cs$s$tl, cs$s$smp, deriv = FALSE)$f)
      expect_length(ev$g, cs$s$tl$q)
      expect_identical(.sem_grad(dr$theta, cs$s$tl, cs$s$smp), ev$g)
      rel[i] <- tlg_rel(ev$g, dr$fd$g)
      fd_err[i] <- max(dr$fd$err) / max(1, max(abs(dr$fd$g)))
    }
    expect_length(rel, 20L)
    # the finite-difference oracle itself is far more accurate than the tolerance it checks
    expect_lt(max(fd_err), 1e-7)
    expect_lt(max(rel), 1e-6)
  })
}

test_that(".sem_grad() is a finite zero vector at an unusable two-level point", {
  s <- tlg_setup_draws("unbalanced")$s
  bad <- tlg_setup_draws("unbalanced")$draws[[1]]$theta
  bad["X~~X"] <- -1
  expect_null(.sem_eval(bad, s$tl, s$smp, deriv = TRUE))
  expect_identical(.sem_grad(bad, s$tl, s$smp), numeric(s$tl$q))
})

# Error of a gradient against the clean finite differences over a fixture's draws (the reference is computed before
# any mock, from the unmutated f).
tlg_max_rel <- function(cs) {
  max(vapply(cs$draws, function(dr) {
    tlg_rel(.sem_eval_ml2(dr$theta, cs$s$tl, cs$s$smp, deriv = TRUE)$g, dr$fd$g)
  }, 1))
}

test_that("planted defect: a sign error in the Sigma_W / n_j chain term fails the 1e-6 tolerance", {
  for (fx_name in c("balanced", "unbalanced")) {
    cs <- tlg_setup_draws(fx_name)
    local({
      local_mocked_bindings(.sem_ml2_grad_moments = sem_mutate(
        .sem_ml2_grad_moments, "g_w + g_v[w_idx, w_idx]/n", "g_w - g_v[w_idx, w_idx]/n"
      ))
      err <- tlg_max_rel(cs)
      expect_gt(err, 1e-4)
      expect_failure(expect_lt(err, 1e-6))
    })
  }
})

test_that("planted defect: the balanced-form gradient (mean size) on unbalanced data fails the 1e-6 tolerance", {
  mutant <- sem_mutate(.sem_ml2_grad_moments, "n <- s$n", "n <- smp$n/smp$j")
  cs <- tlg_setup_draws("unbalanced")
  expect_gt(length(cs$s$smp$sizes), 1L)
  local({
    local_mocked_bindings(.sem_ml2_grad_moments = mutant)
    err <- tlg_max_rel(cs)
    expect_gt(err, 1e-4)
    expect_failure(expect_lt(err, 1e-6))
  })
  # positive control: on balanced data the mean size is the size, so the mutant is the correct gradient
  cb <- tlg_setup_draws("balanced")
  expect_identical(length(cb$s$smp$sizes), 1L)
  dr <- cb$draws[[1]]
  g <- .sem_eval_ml2(dr$theta, cb$s$tl, cb$s$smp, deriv = TRUE)$g
  local({
    local_mocked_bindings(.sem_ml2_grad_moments = mutant)
    expect_lt(max(abs(.sem_eval_ml2(dr$theta, cb$s$tl, cb$s$smp, deriv = TRUE)$g - g)), 1e-12)
  })
})
