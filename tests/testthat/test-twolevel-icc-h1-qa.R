# Independent QA of the h1 ICC change (feature/twolevel-icc-h1), 2026-11-22. Oracles: lavaan's own h1 ICC with a
# tightened EM (`lavInspect(fit, "icc")`), and a real (unmocked) low-ICC parallel fit for the within-only branch.

skip_if_not_installed("lavaan")

tliq_lavaan_tight <- function(model, data, cluster = "cluster") {
  args <- if ("em.h1.args" %in% names(lavaan::lavOptions())) {
    list(em.h1.args = list(tol = 1e-10, max_iter = 100000L))
  } else {
    list(em.h1.tol = 1e-10, em.h1.iter.max = 100000L)
  }
  suppressWarnings(do.call(lavaan::sem, c(list(model, data, cluster = cluster, fixed.x = FALSE), args)))
}

# A fresh two-level dataset: X, M, Y with a between part (`bsd`), optional unequal sizes (gamma, CV about .5) and an
# optional between-only variable Z (the cluster mean of X plus noise).
tliq_data <- function(seed, j, size, bsd = c(1, 0.5, 0.5), unbalanced = FALSE, z = FALSE) {
  withr::local_seed(seed)
  sizes <- if (unbalanced) pmax(2L, round(stats::rgamma(j, shape = 4, rate = 4 / size))) else rep(size, j)
  cl <- rep(seq_len(j), sizes)
  n <- length(cl)
  x <- stats::rnorm(j, sd = bsd[1])[cl] + stats::rnorm(n)
  m <- stats::rnorm(j, sd = bsd[2])[cl] + 0.4 * x + stats::rnorm(n)
  y <- stats::rnorm(j, sd = bsd[3])[cl] + 0.3 * m + stats::rnorm(n)
  d <- data.frame(cluster = cl, X = x, M = m, Y = y)
  if (z) d$Z <- as.numeric(tapply(d$X, cl, mean)[cl]) + stats::rnorm(j, sd = 0.5)[cl]
  d
}

tliq_model <- function(z = FALSE) {
  paste0("level: 1\n  M ~ X\n  Y ~ M + X\nlevel: 2\n  M ~ X", if (z) " + Z" else "", "\n  Y ~ M + X\n")
}

test_that("the native h1 ICC equals lavaan's tightened h1 ICC on fresh data: sizes, J, a between-only variable", {
  skip_on_cran()
  cells <- list(
    list(seed = 5101L, j = 10L, size = 4, unbalanced = FALSE, z = FALSE),
    list(seed = 5102L, j = 20L, size = 2, unbalanced = FALSE, z = FALSE),   # clusters of size 2
    list(seed = 5103L, j = 50L, size = 4, unbalanced = TRUE, z = FALSE),    # CV about .5
    list(seed = 5104L, j = 20L, size = 4, unbalanced = TRUE, z = TRUE),
    list(seed = 5105L, j = 50L, size = 3, unbalanced = FALSE, z = TRUE)
  )
  for (cs in cells) {
    d <- do.call(tliq_data, cs)
    expect_gt(stats::sd(table(d$cluster)) / mean(table(d$cluster)), if (cs$unbalanced) 0.2 else -1)
    w <- c("M", "Y", "X")
    between <- if (cs$z) "Z" else character()
    h1 <- .sem_twolevel_h1_moments(.sem_sample_ml2(d, list(within = w, between = between), "cluster"))
    expect_true(h1$converged, label = paste("seed", cs$seed))
    nat <- .sem_twolevel_icc(h1$sigma_w, h1$sigma_b)
    lav <- lavaan::lavInspect(tliq_lavaan_tight(tliq_model(cs$z), d), "icc")
    # both EMs stop on a step rule: the native moments are within about 3e-5 of the maximum (tol 1e-13 moves the ICC by
    # that much) and lavaan's tight fit within 1e-5; over 54 fresh QA datasets the gap was at most 3.4e-5
    expect_lt(max(abs(nat[names(lav)] - lav)), 5e-5, label = paste("seed", cs$seed))
  }
})

test_that("a boundary dataset (negative closed-form level-2 variance) stays positive definite and matches lavaan", {
  skip_on_cran()
  d <- tliq_data(5206L, j = 10L, size = 3, bsd = c(1, 0, 0))
  w <- c("M", "Y", "X")
  smp <- .sem_sample_ml2(d, list(within = w, between = character()), "cluster")
  # the closed form (SSW / (N - J), S_B - SW / n) is indefinite here, which is why the native route uses EM
  g <- d$cluster
  sw <- vapply(w, function(v) sum((d[[v]] - stats::ave(d[[v]], g))^2) / (nrow(d) - 10), 0)
  sb <- vapply(w, function(v) mean((tapply(d[[v]], g, mean) - mean(d[[v]]))^2) - sw[[v]] / 3, 0)
  expect_true(any(sb < 0))
  h1 <- .sem_twolevel_h1_moments(smp)
  expect_true(h1$converged)
  expect_true(.sem_sigma_pd(h1$sigma_w))
  expect_true(.sem_sigma_pd(h1$sigma_b))
  nat <- .sem_twolevel_icc(h1$sigma_w, h1$sigma_b)
  lav <- lavaan::lavInspect(tliq_lavaan_tight(tliq_model(), d), "icc")
  expect_lt(max(abs(nat[names(lav)] - lav)), 1e-4)
})

test_that("on fresh balanced data the native h1 equals the hand ANOVA estimator", {
  d <- tliq_data(5002L, j = 10L, size = 4)
  g <- d$cluster
  w <- c("M", "Y", "X")
  hand <- vapply(w, function(v) {
    sw <- sum((d[[v]] - stats::ave(d[[v]], g))^2) / (nrow(d) - 10)
    sb <- mean((tapply(d[[v]], g, mean) - mean(d[[v]]))^2) - sw / 4
    c(sw = sw, sb = sb, icc = sb / (sb + sw))
  }, numeric(3))
  expect_true(all(hand["sb", ] > 0))
  h1 <- .sem_twolevel_h1_moments(.sem_sample_ml2(d, list(within = w, between = character()), "cluster"))
  expect_equal(unname(.sem_twolevel_icc(h1$sigma_w, h1$sigma_b)[w]), unname(hand["icc", ]), tolerance = 1e-6)
})

test_that("a REAL (unmocked) parallel fit with a near-zero mediator ICC is within-only on both h1 sources", {
  # tlp_sim(m2_between = FALSE, seed = 76): lavaan's default h1 ICC of M2 is .0025 (native EM .0019), a margin of
  # four times below the .01 floor, so the parallel within-only branch is tested without tlp_mock_low_icc_m2().
  d <- tlp_sim(m2_between = FALSE, seed = 76L)
  fit <- tl_fit(d, tlp_model())
  icc <- .twolevel_icc(fit)
  expect_lt(icc[["M2"]], 0.005)
  expect_gt(icc[["M1"]], 0.05)
  expect_equal(icc[["M2"]], lavaan::lavInspect(fit, "icc")[["M2"]], tolerance = 1e-12)
  w <- tl_catch(extract_mediation(fit, "X", c("M1", "M2"), "Y"), "medfit_between_unidentified")
  expect_s3_class(w, "medfit_between_unidentified")
  expect_match(conditionMessage(w), "the ICC of the mediator 'M2'", fixed = TRUE)
  td <- tlp_extract(fit)
  expect_false(td@between_identified)
  # the native EM on the same data reads the same side of the floor
  smp <- .sem_sample_ml2(d, list(within = c("M1", "M2", "Y", "X"), between = character()), "id")
  h1 <- .sem_twolevel_h1_moments(smp)
  expect_lt(.sem_twolevel_icc(h1$sigma_w, h1$sigma_b)[["M2"]], 0.01)
})

test_that("the native object's own ICCs are the h1 ICCs (not the implied ones) on unbalanced fresh data", {
  skip_on_cran()
  shared <- "level: 1\n  M ~ a*X\n  Y ~ b*M + cp*X\nlevel: 2\n  M ~ a*X\n  Y ~ b*M + cp*X\n"
  for (seed in c(5103L, 5104L)) {
    d <- tliq_data(seed, j = if (seed == 5103L) 50L else 20L, size = 4, unbalanced = TRUE)
    nf <- suppressMessages(suppressWarnings(fit_sem(shared, d, cluster = "cluster")))
    td <- suppressWarnings(extract_mediation(nf, treatment = "X", mediator = "M"))
    lav <- lavaan::lavInspect(tliq_lavaan_tight(shared, d), "icc")
    expect_lt(max(abs(td@icc - lav[names(td@icc)])), 5e-5, label = paste("seed", seed))
    # the model-implied ICC of the same fit is far from lavaan's h1 (gap .03 and .12), so a swapped source fails here
    mom <- .sem_twolevel_implied(nf@internals$ram, unname(nf@theta))
    imp <- .sem_twolevel_icc(mom$sigma_w, mom$sigma_b)
    expect_gt(max(abs(imp[names(td@icc)] - lav[names(td@icc)])), 0.02, label = paste("seed", seed))
  }
})
