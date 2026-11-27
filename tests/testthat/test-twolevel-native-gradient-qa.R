# S4a.3 QA: the analytic two-level gradient against an oracle outside medfit. lavaan's own analytic gradient of its
# two-level ML objective fmin = -log L / N, read with `lavTech(, "gradient")` from a `do.fit = FALSE` model whose
# starting values are a chosen theta, is half of medfit's gradient of f = -2 log L / N. Agreement is about 1e-15; the
# tolerance is the S4a.3 acceptance bound (1e-6, error max_i |g_i - 2 g_lav,i| / max(1, max_i |g_i|)), validated
# (TL-7) by two planted defects that the bound must reject: a shared label that keeps only its level-2 contribution,
# and a level-2 mean chain that is dropped.

skip_on_cran() # Windows check time (0.21.3): runs in CI and the local full run

tlq_key <- function(pt) {
  base <- ifelse(pt$op == "~1", paste0(pt$lhs, "~1"), paste0(pt$lhs, pt$op, pt$rhs))
  key <- ifelse(pt$level == 2, paste0(base, ".l2"), base)
  ifelse(nzchar(pt$label), pt$label, key)
}

# lavaan's gradient at theta (named by medfit's par_names), summed over rows that share a label, times 2.
tlq_lavaan_grad <- function(model, data, theta) {
  fit0 <- suppressWarnings(lavaan::sem(model, data, cluster = "cluster", fixed.x = FALSE, do.fit = FALSE))
  pt <- lavaan::parTable(fit0)
  fi <- pt$free > 0
  key <- tlq_key(pt[fi, ])
  stopifnot(setequal(unique(key), names(theta)))
  pt$start[fi] <- unname(theta[key])
  pt$est[fi] <- pt$start[fi]
  fit <- suppressWarnings(lavaan::sem(pt, data, cluster = "cluster", fixed.x = FALSE, do.fit = FALSE,
                                      information = "observed", h1.information = "structured"))
  g <- lavaan::lavTech(fit, "gradient")
  expect_length(g, sum(fi))
  2 * vapply(names(theta), function(k) sum(g[key == k]), 1)
}

tlq_fixtures <- function() {
  unb <- tl_simulate(rep(2:9, 6), seed = 31)
  list(
    unbalanced_z = list(model = tln_model_z(), data = tln_add_z(unb)),
    shared_label = list(model = sub("M ~ a_b*X", "M ~ a_w*X", tl_lavaan_model, fixed = TRUE), data = unb),
    level2_means = list(model = paste0(tl_lavaan_model, "  Y ~ ny*1\n  X ~ 0*1\n"), data = unb)
  )
}

# Five usable thetas near a base point (paths 0.3, variances 0.8, covariances 0.1, means 0.5).
tlq_thetas <- function(tl, smp, seed = 2) {
  withr::local_seed(seed)
  nm <- tl$par_names
  var_par <- grepl("^(.+)~~\\1(\\.l2)?$", nm)
  cov_par <- grepl("~~", nm, fixed = TRUE) & !var_par
  mean_par <- grepl("~1", nm, fixed = TRUE) | nm == "ny"
  base <- ifelse(var_par, 0.8, ifelse(cov_par, 0.1, ifelse(mean_par, 0.5, 0.3)))
  out <- list()
  while (length(out) < 5L) {
    th <- stats::setNames(base + stats::runif(length(base), -0.3, 0.3), nm)
    if (!is.null(.sem_eval_ml2(th, tl, smp, deriv = FALSE))) out[[length(out) + 1L]] <- th
  }
  out
}

tlq_err <- function(g, ref) max(abs(g - ref)) / max(1, max(abs(g)))

tlq_cache <- new.env()
tlq_case <- function(name) {
  if (is.null(tlq_cache[[name]])) {
    fx <- tlq_fixtures()[[name]]
    s <- tln_setup(fx$model, fx$data)
    ths <- tlq_thetas(s$tl, s$smp)
    tlq_cache[[name]] <- list(s = s, ths = ths, ref = lapply(ths, function(th) tlq_lavaan_grad(fx$model, fx$data, th)))
  }
  tlq_cache[[name]]
}

tlq_max_err <- function(cs) {
  max(vapply(seq_along(cs$ths), function(i) {
    tlq_err(.sem_eval_ml2(cs$ths[[i]], cs$s$tl, cs$s$smp, deriv = TRUE)$g, cs$ref[[i]])
  }, 1))
}

for (fx_name in names(tlq_fixtures())) {
  test_that(sprintf("the two-level gradient is twice lavaan's analytic gradient to 1e-6 (%s)", fx_name), {
    skip_if_not_installed("lavaan")
    cs <- tlq_case(fx_name)
    expect_length(cs$ths, 5L)
    expect_lt(tlq_max_err(cs), 1e-6)
  })
}

test_that("planted defect: a shared label that keeps only its level-2 term fails the lavaan check", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  cs <- tlq_case("shared_label")
  k <- match("a_w", cs$s$tl$par_names)
  expect_true(k %in% cs$s$tl$k1 && k %in% cs$s$tl$k2)
  local({
    local_mocked_bindings(.sem_eval_ml2 = sem_mutate(
      .sem_eval_ml2, "g[l$k] <- g[l$k] + .sem_ram_chain", "g[l$k] <- .sem_ram_chain"
    ))
    err <- tlq_max_err(cs)
    expect_gt(err, 1e-4)
    expect_failure(expect_lt(err, 1e-6))
  })
})

test_that("planted defect: a dropped level-2 mean chain fails the lavaan check", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  cs <- tlq_case("level2_means")
  local({
    local_mocked_bindings(.sem_eval_ml2 = sem_mutate(
      .sem_eval_ml2, "l$mats$s, w, gmu, bm)", "l$mats$s, w, 0 * gmu, bm)"
    ))
    err <- tlq_max_err(cs)
    expect_gt(err, 1e-4)
    expect_failure(expect_lt(err, 1e-6))
  })
})
