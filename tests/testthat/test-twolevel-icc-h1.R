# The ICC behind the within-only identification rule comes from the unrestricted (h1, saturated) estimate on both
# routes: `lavaan::lavInspect(fit, "icc")` for a lavaan fit, an EM estimate from the per-size sufficient statistics for
# a native fit (R/sem-twolevel-h1.R). Decision 2026-11-22, planning/studies/few-clusters/T5-pilot-memo.md (S4).
# Oracles: lavaan's own h1 ICC (default and tightened EM), a hand ANOVA estimator on balanced data, and the
# model-implied ICC as the source the rule used before (the divergence fixtures must separate the two).

skip_if_not_installed("lavaan")

tli_model <- "level: 1\n  M ~ X\n  Y ~ M + X\nlevel: 2\n  M ~ X\n  Y ~ M + X\n"
# The same paths with every path shared across levels: not saturated, so a fit has a positive level-2 variance where
# the saturated fit would have a negative one, and its implied moments differ from the h1 moments.
tli_model_shared <- "level: 1\n  M ~ a*X\n  Y ~ b*M + cp*X\nlevel: 2\n  M ~ a*X\n  Y ~ b*M + cp*X\n"

# A small-J DGP whose mediator has no between variance in the population, so the mediator ICC sits near the cut.
tli_sim <- function(seed, j = 20L, n = 3L) {
  withr::local_seed(seed)
  cl <- sort(rep(seq_len(j), n))
  xb <- stats::rnorm(j)
  mb <- stats::rnorm(j, sd = 0)
  yb <- stats::rnorm(j, sd = 0.5)
  x <- xb[cl] + stats::rnorm(length(cl))
  m <- mb[cl] + 0.4 * x + stats::rnorm(length(cl))
  y <- yb[cl] + 0.3 * m + 0.2 * x + stats::rnorm(length(cl))
  data.frame(cluster = cl, X = x, M = m, Y = y)
}

tli_smp <- function(data, w = c("M", "Y", "X"), z = character()) {
  .sem_sample_ml2(data, list(within = w, between = z), "cluster")
}

# lavaan with an EM stopping rule tight enough that its h1 is the maximum to about 1e-5 in the ICC. lavaan 0.7 takes
# `em.h1.args`; 0.6 takes `em.h1.iter.max` and `em.h1.tol`.
tli_lavaan_tight <- function(model, data) {
  args <- if ("em.h1.args" %in% names(lavaan::lavOptions())) {
    list(em.h1.args = list(tol = 1e-10, max_iter = 100000L))
  } else {
    list(em.h1.tol = 1e-10, em.h1.iter.max = 100000L)
  }
  suppressWarnings(do.call(lavaan::sem, c(list(model, data, cluster = "cluster", fixed.x = FALSE), args)))
}

# The rule's three outcomes as the adapter reports them: a classed warning for within-only and for weak, none otherwise.
tli_call <- function(expr) {
  seen <- character()
  value <- withCallingHandlers(expr, warning = function(w) {
    seen <<- c(seen, class(w))
    invokeRestart("muffleWarning")
  })
  call <- if ("medfit_between_unidentified" %in% seen) {
    "within_only"
  } else if ("medfit_warning_between_weak" %in% seen) {
    "weak"
  } else {
    "identified"
  }
  list(value = value, call = call)
}

# The call the rule would make from a given ICC vector (treatment X, mediator M), the pre-change source being the
# model-implied one: the same thresholds `.twolevel_identification()` applies.
tli_call_from_icc <- function(icc) {
  low <- min(icc[["X"]], icc[["M"]])
  if (low < 0.01) "within_only" else if (low < 0.05) "weak" else "identified"
}

# The three native divergence fixtures: (seed, call under the model-implied ICC, call under the h1 ICC). Each fit is
# admissible and the implied ICC of the shared-paths model differs from the h1 ICC enough to move the call.
tli_flip <- list(
  list(seed = 24L, implied = "identified", h1 = "within_only"),
  list(seed = 221L, implied = "within_only", h1 = "identified"),
  list(seed = 32L, implied = "identified", h1 = "weak")
)

tli_native <- function(data, model = tli_model_shared) {
  suppressMessages(suppressWarnings(fit_sem(model, data, cluster = "cluster")))
}

test_that("the native h1 ICC equals lavaan's h1 ICC on balanced, unbalanced and between-covariate data", {
  cases <- list(
    list(data = tl_data_unbalanced(), model = tli_model, z = character()),
    list(data = tl_data_balanced(), model = tli_model, z = character()),
    list(data = tln_data_z(), model = tln_model_z(), z = "Z")
  )
  for (case in cases) {
    h1 <- .sem_twolevel_h1_moments(tli_smp(case$data, z = case$z))
    expect_true(h1$converged)
    nat <- .sem_twolevel_icc(h1$sigma_w, h1$sigma_b)
    lav <- lavaan::lavInspect(tli_lavaan_tight(case$model, case$data), "icc")
    expect_lt(max(abs(nat[names(lav)] - lav)), 1e-6)
    # lavaan's own default stops at a log-likelihood gain of 1e-4, which is the size of the gap to the default fit
    lav_default <- lavaan::lavInspect(tln_fit_lavaan(case$model, case$data), "icc")
    expect_lt(max(abs(nat[names(lav_default)] - lav_default)), 5e-4)
  }
})

test_that("the native h1 moments equal the balanced closed form (a hand ANOVA estimator)", {
  d <- tl_data_balanced()
  g <- d$cluster
  n <- unique(table(g))
  expect_length(n, 1L)
  ml_var <- function(x) mean((x - mean(x))^2)
  hand <- vapply(c("X", "M", "Y"), function(v) {
    sw <- sum((d[[v]] - stats::ave(d[[v]], g))^2) / (nrow(d) - length(unique(g)))
    sb <- ml_var(tapply(d[[v]], g, mean)) - sw / n
    c(sw = sw, sb = sb, icc = sb / (sb + sw))
  }, numeric(3))
  expect_true(all(hand["sb", ] > 0))   # the closed form is the maximum only while Sigma_B is positive definite
  h1 <- .sem_twolevel_h1_moments(tli_smp(d))
  expect_equal(unname(diag(h1$sigma_w)[c("X", "M", "Y")]), unname(hand["sw", ]), tolerance = 1e-7)
  expect_equal(unname(diag(h1$sigma_b)[c("X", "M", "Y")]), unname(hand["sb", ]), tolerance = 1e-7)
  expect_equal(unname(.sem_twolevel_icc(h1$sigma_w, h1$sigma_b)[c("X", "M", "Y")]), unname(hand["icc", ]),
               tolerance = 1e-7)
})

test_that("the h1 moments are an unrestricted maximum: no nearby moments have a higher log-likelihood", {
  smp <- tli_smp(tl_data_unbalanced())
  h1 <- .sem_twolevel_h1_moments(smp)
  best <- .sem_loglik_ml2(smp, h1$sigma_w, h1$sigma_b, h1$mu_b)
  withr::local_seed(3)
  for (i in 1:20) {
    pw <- h1$sigma_w * (1 + 1e-3 * stats::rnorm(1))
    pb <- h1$sigma_b + 1e-3 * diag(stats::rnorm(nrow(h1$sigma_b)))
    expect_lte(.sem_loglik_ml2(smp, pw, pb, h1$mu_b), best + 1e-9)
  }
})

test_that(".twolevel_icc() returns lavaan's h1 ICC, 1 for a between-only variable, and the model-implied ICC differs", {
  fit <- tln_fit_lavaan(tln_model_z(), tln_data_z())
  icc <- .twolevel_icc(fit)
  h1 <- lavaan::lavInspect(fit, "icc")
  expect_equal(icc[names(h1)], h1, tolerance = 1e-12)
  expect_identical(icc[["Z"]], 1)
  expect_setequal(names(icc), c("M", "Y", "X", "Z"))
  # with no negative level-2 variance the implied and h1 ICCs stay close (memo S4: largest gap .018), so the source
  # matters only where they split
  implied <- lavaan::lavInspect(fit, "implied")
  expect_lt(max(abs(.sem_twolevel_icc(implied[[1]]$cov, implied[[2]]$cov)[names(h1)] - h1)), 0.02)
})

test_that("a lavaan fit without an h1 estimate falls back to the model-implied ICC with a classed warning", {
  d <- tl_data_unbalanced()
  fit <- suppressWarnings(lavaan::sem(tli_model, d, cluster = "cluster", fixed.x = FALSE, h1 = FALSE))
  expect_warning(icc <- .twolevel_icc(fit), class = "medfit_warning_twolevel_icc_h1_unavailable")
  implied <- lavaan::lavInspect(fit, "implied")
  expect_equal(icc, .sem_twolevel_icc(implied[[1]]$cov, implied[[2]]$cov))
})

test_that("an all-NA lavInspect ICC falls back to the model-implied ICC with the classed warning (fault injection)", {
  fit <- tln_fit_lavaan(tli_model, tl_data_unbalanced())
  real_inspect <- lavaan::lavInspect
  testthat::local_mocked_bindings(
    lavInspect = function(object, what = "list", ...) {
      if (identical(what, "icc")) {
        return(stats::setNames(rep(NA_real_, 3L), c("M", "Y", "X")))
      }
      real_inspect(object, what, ...)
    },
    .package = "lavaan"
  )
  expect_warning(icc <- .twolevel_icc(fit), class = "medfit_warning_twolevel_icc_h1_unavailable")
  implied <- real_inspect(fit, "implied")
  expect_equal(icc, .sem_twolevel_icc(implied[[1]]$cov, implied[[2]]$cov))
  expect_true(all(icc > 0))   # not the silent all-zero (within-only) vector
})

test_that("a saturated lavaan fit with a negative level-2 variance is identified under h1, within-only under implied", {
  d <- tli_sim(35L)
  fit <- tln_fit_lavaan(tli_model, d)
  implied <- lavaan::lavInspect(fit, "implied")
  icc_implied <- .sem_twolevel_icc(implied[[1]]$cov, implied[[2]]$cov)
  expect_lt(icc_implied[["M"]], 0.01)               # Heywood: the clamp gives 0
  expect_gt(.twolevel_icc(fit)[["M"]], 0.05)         # the h1 estimate does not see the negative variance
  expect_identical(tli_call_from_icc(icc_implied), "within_only")
  expect_identical(tli_call(extract_mediation(fit, "X", "M"))$call, "identified")
})

test_that("both routes make the same within-only call on the same data, and it differs from the implied call", {
  for (fx in tli_flip) {
    d <- tli_sim(fx$seed)
    nat_fit <- tli_native(d)
    # the lavaan-route call is read from the tightened-EM fit: on lavaan's default stopping rule these fixtures sit
    # within .002 to .003 of a cut (seeds 24 and 32), which a change in lavaan's EM could flip
    lav_fit <- tli_lavaan_tight(tli_model_shared, d)
    nat <- tli_call(extract_mediation(nat_fit, treatment = "X", mediator = "M"))
    lav <- tli_call(extract_mediation(lav_fit, "X", "M"))
    label <- paste("seed", fx$seed)
    expect_identical(nat$call, fx$h1, label = label)
    expect_identical(lav$call, fx$h1, label = label)
    # the fixture separates the sources: the model-implied ICC of the same native fit makes the other call
    mom <- .sem_twolevel_implied(nat_fit@internals$ram, unname(nat_fit@theta))
    expect_identical(tli_call_from_icc(.sem_twolevel_icc(mom$sigma_w, mom$sigma_b)), fx$implied, label = label)
    # and the native ICC is the h1 one: the object's own ICCs track lavaan's tightened h1 ICCs to 1e-4, and the default
    # lavaan fit to 1e-2 (the fixtures sit on the boundary, where lavaan's default stops about 5e-3 short)
    lav_tight <- lavaan::lavInspect(lav_fit, "icc")
    expect_lt(max(abs(nat$value@icc[names(lav_tight)] - lav_tight)), 1e-4, label = label)
    lav_default <- lavaan::lavInspect(tln_fit_lavaan(tli_model_shared, d), "icc")
    expect_lt(max(abs(nat$value@icc[names(lav_default)] - lav_default)), 1e-2, label = label)
  }
})

test_that("the native ICC is the h1 ICC even where the model-implied ICC would flip the call (planted defect)", {
  fx <- tli_flip[[2]]   # implied: within-only (X), h1: identified
  fit <- tli_native(tli_sim(fx$seed))
  # the defect: the source swapped back to the model-implied moments
  testthat::local_mocked_bindings(
    .sem_twolevel_h1_icc = function(object) {
      mom <- .sem_twolevel_implied(object@internals$ram, unname(object@theta))
      .sem_twolevel_icc(mom$sigma_w, mom$sigma_b)
    },
    .package = "medfit"
  )
  swapped <- tli_call(extract_mediation(fit, treatment = "X", mediator = "M"))$call
  expect_identical(swapped, fx$implied)
  expect_false(identical(swapped, fx$h1))   # a test pinned to the h1 call fails under the swapped source
})

test_that("the h1 moments return NULL, and the native ICC falls back with a warning, for a collinear variable", {
  d <- tl_data_unbalanced()
  d$Y2 <- d$Y
  expect_null(.sem_twolevel_h1_moments(tli_smp(d, w = c("M", "Y", "X", "Y2"))))
  fit <- tli_native(tli_sim(32L))
  testthat::local_mocked_bindings(.sem_twolevel_h1_moments = function(smp, ...) NULL, .package = "medfit")
  expect_warning(icc <- .sem_twolevel_h1_icc(fit), class = "medfit_warning_twolevel_icc_h1_unavailable")
  mom <- .sem_twolevel_implied(fit@internals$ram, unname(fit@theta))
  expect_equal(icc, .sem_twolevel_icc(mom$sigma_w, mom$sigma_b))
})

test_that("an h1 EM that does not converge warns with a classed condition and still returns its last iterate", {
  fit <- tli_native(tli_sim(32L))
  real <- .sem_twolevel_h1_moments
  testthat::local_mocked_bindings(
    .sem_twolevel_h1_moments = function(smp, ...) real(smp, max_iter = 1L),
    .package = "medfit"
  )
  expect_warning(icc <- .sem_twolevel_h1_icc(fit), class = "medfit_warning_twolevel_icc_h1_unconverged")
  expect_setequal(names(icc), c("M", "Y", "X"))
})

test_that("a parallel-mediator fit whose mediator has no between part is weak, not within-only, under h1", {
  # tlp_fixture("weak_icc_m2"): M2 has a negative level-2 variance (implied ICC 0, the pre-change within-only call);
  # its h1 ICC is about .013, inside the weak band [.01, .05). Every mediator is read, as before (D2).
  fit <- tlp_fixture("weak_icc_m2")
  icc <- .twolevel_icc(fit)
  expect_gte(icc[["M2"]], 0.01)
  expect_lt(icc[["M2"]], 0.05)
  expect_equal(icc[["M2"]], lavaan::lavInspect(fit, "icc")[["M2"]], tolerance = 1e-12)
  r <- tli_call(extract_mediation(fit, "X", c("M1", "M2"), "Y"))
  expect_identical(r$call, "weak")
})

test_that("the cluster-refit bootstrap callback reads the h1 ICC (a refit below the floor is dropped)", {
  d <- tli_sim(35L)
  fit <- tln_fit_lavaan(tli_model, d)
  stat <- twolevel_statistic(fit, effect = "nie_between", treatment = "X", mediator = "M", outcome = "Y")
  # the original data: the h1 mediator ICC is above the floor, so the refit value is finite; under the implied ICC
  # (0 after the clamp) the same refit returns NA
  expect_true(is.finite(stat(d)))
  testthat::local_mocked_bindings(
    .twolevel_icc = function(fit) {
      implied <- lavaan::lavInspect(fit, "implied")
      .sem_twolevel_icc(implied[[1L]]$cov, implied[[2L]]$cov)
    },
    .package = "medfit"
  )
  expect_true(is.na(stat(d)))
})
