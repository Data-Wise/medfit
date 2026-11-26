# S4a.5 oracle QA (independent of test-twolevel-native-extract.R): extract_mediation(<two-level SEMFit>) against the
# lavaan two-level adapter on designs the implementer did not use (unbalanced sizes 1 to 14 with singleton clusters,
# J = 55; a level-1 covariate, J = 70; a label shared at b; a two-mediator parallel model), the full 6 x 6 @vcov
# compared element by element (cross-level block included), the per-level effects from nie()/nde()/te()/pm() and
# tidy(), per-level admissibility (within level by the classifier and a mocked route, since an accepted optimum with a
# negative within variance is unreachable: Sigma_W must be positive definite for the likelihood), glance() after
# listwise deletion against lavaan and a hand count, and a row-shuffle invariance. Tolerances from
# planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md: estimates TL-1 max(0.01 SE, 1e-4); SEs and covariances
# TL-2 1e-3 relative (covariances relative to SE_i SE_j).

skip_on_cran()  # long run: skipped on CRAN to keep the check short; runs in GitHub CI and with NOT_CRAN=true
skip_if_not_installed("lavaan")

tlq_paths <- c("a_within", "b_within", "c_prime_within", "a_between", "b_between", "c_prime_between")

tlq_sim <- function(seed, J, covariate = FALSE) {
  withr::local_seed(seed)
  sizes <- sample(c(1, 2:14), J, replace = TRUE)
  cl <- rep(seq_len(J), sizes)
  xb <- stats::rnorm(J, sd = 0.8)
  mb <- 0.6 * xb + stats::rnorm(J, sd = 0.5)
  yb <- 0.4 * mb - 0.3 * xb + stats::rnorm(J, sd = 0.5)
  x <- xb[cl] + stats::rnorm(length(cl))
  m <- mb[cl] + 0.35 * x + stats::rnorm(length(cl))
  y <- yb[cl] + 0.45 * m + 0.15 * x + stats::rnorm(length(cl))
  d <- data.frame(cluster = cl, X = x + 3, M = m - 1, Y = y + 2)
  if (covariate) {
    d$C <- stats::rnorm(length(cl)) + stats::rnorm(J)[cl]
    d$Y <- d$Y + 0.3 * d$C
  }
  d
}
tlq_model <- function(b_between = "b_b", extra = "") {
  paste0("level: 1\n M ~ a_w*X\n Y ~ b_w*M + cp_w*X", extra, "\nlevel: 2\n M ~ a_b*X\n Y ~ ", b_between,
         "*M + cp_b*X", extra, "\n")
}
tlq_lavaan_fit <- function(model, d) {
  suppressWarnings(lavaan::sem(model, d, cluster = "cluster", fixed.x = FALSE, information = "observed",
                               h1.information = "structured"))
}
tlq_pair <- function(model, d, mediator = "M") {
  fit <- fit_sem(model, d, cluster = "cluster")
  list(
    fit = fit,
    nat = suppressWarnings(extract_mediation(fit, treatment = "X", mediator = mediator)),
    lav = suppressWarnings(extract_mediation(tlq_lavaan_fit(model, d), treatment = "X", mediator = mediator))
  )
}
tlq_effects <- function(o) {
  unlist(lapply(c("within", "between"), function(l) {
    c(nie = nie(o, level = l), nde = nde(o, level = l), te = te(o, level = l), pm = pm(o, level = l))
  }))
}
# every path (TL-1), every element of the vcov (TL-2 relative to SE_i SE_j), effects and their delta SEs via tidy()
tlq_check <- function(nat, lav, paths = rownames(lav@vcov)) {
  expect_identical(rownames(nat@vcov), paths)
  expect_identical(colnames(nat@vcov), paths)
  se <- sqrt(diag(lav@vcov))[paths]
  expect_lte(max(abs(nat@estimates[paths] - lav@estimates[paths]) / pmax(0.01 * se, 1e-4)), 1)
  expect_lt(max(abs(nat@vcov[paths, paths] - lav@vcov[paths, paths]) / outer(se, se)), 1e-3)
  tn <- tidy(nat)
  tl <- tidy(lav)
  expect_identical(tn$term, tl$term)
  expect_lte(max(abs(tn$estimate - tl$estimate) / pmax(0.01 * tl$std_error, 1e-4), na.rm = TRUE), 1)
  ok <- is.finite(tl$std_error) & tl$std_error > 0
  expect_lt(max(abs(tn$std_error[ok] - tl$std_error[ok]) / tl$std_error[ok]), 1e-3)
  expect_identical(nat@n_obs, lav@n_obs)
  expect_identical(nat@n_clusters, lav@n_clusters)
  expect_identical(nat@cluster_sizes, lav@cluster_sizes)
  expect_identical(nat@cross_level_equal, lav@cross_level_equal)
  expect_identical(nat@between_identified, lav@between_identified)
}

test_that("QA: unbalanced sizes 1 to 14, J = 55: paths, the full 6 x 6 vcov and the per-level effects match lavaan", {
  p <- tlq_pair(tlq_model(), tlq_sim(9173, 55))
  expect_true(any(p$nat@cluster_sizes == 1L))
  # the cross-level block is not zero in the oracle, so a dropped or swapped block is visible
  expect_gt(max(abs(p$lav@vcov[1:3, 4:6])), 1e-3)
  tlq_check(p$nat, p$lav, tlq_paths)
  e_nat <- tlq_effects(p$nat)
  e_lav <- tlq_effects(p$lav)
  expect_identical(names(e_nat), names(e_lav))
  se_e <- tidy(p$lav)$std_error[match(c("nie_within", "nde_within", "te_within", "pm_within", "nie_between",
                                        "nde_between", "te_between", "pm_between"), tidy(p$lav)$term)]
  expect_lte(max(abs(e_nat - e_lav) / pmax(0.01 * se_e, 1e-4)), 1)
  expect_lte(abs(nie(p$nat, level = "contrast") - nie(p$lav, level = "contrast")), 1e-3)
})

test_that("QA: a level-1 covariate in both Y equations, J = 70, matches lavaan", {
  model <- tlq_model(extra = " + C")
  d <- tlq_sim(4242, 70, covariate = TRUE)
  p <- tlq_pair(model, d)
  tlq_check(p$nat, p$lav, tlq_paths)
  expect_identical(as.numeric(glance(p$fit)$df), as.numeric(lavaan::fitMeasures(tlq_lavaan_fit(model, d), "df")))
})

test_that("QA: b shared across levels is one free parameter; its 2 x 2 block is read by index", {
  model <- tlq_model(b_between = "b_w")
  p <- tlq_pair(model, tlq_sim(5150, 50))
  expect_identical(p$nat@cross_level_equal, "b")
  tlq_check(p$nat, p$lav, tlq_paths)
  k <- p$fit@internals$par_map[p$fit@table$op == "~" & p$fit@table$lhs == "Y" & p$fit@table$rhs == "M"]
  expect_length(unique(k), 1L)
  v <- p$fit@vcov[k[1L], k[1L]]
  expect_identical(unname(p$nat@vcov[c("b_within", "b_between"), c("b_within", "b_between")]), matrix(v, 2L, 2L))
  # the other rows come from their own indices: a_within against the engine's vcov
  ka <- p$fit@internals$par_map[p$fit@table$op == "~" & p$fit@table$lhs == "M" & p$fit@table$level == 1]
  expect_identical(p$nat@vcov["a_within", "b_between"], p$fit@vcov[ka, k[1L]])
  # a differs across levels, so the contrast is defined: an estimate, compared at the TL-1 floor scale
  expect_lte(abs(nie(p$nat, level = "contrast") - nie(p$lav, level = "contrast")), 1e-3)
})

test_that("QA: a two-mediator parallel native fit matches the lavaan adapter (open item k >= 2)", {
  d <- tlp_sim(J = 60L, n = 6L, seed = 31L)
  names(d)[names(d) == "id"] <- "cluster"
  p <- tlq_pair(tlp_model(), d, mediator = c("M1", "M2"))
  expect_true(S7::S7_inherits(p$nat, TwoLevelParallelMediationData))
  tlq_check(p$nat, p$lav)
})

test_that("QA: the classifier marks a negative within variance as a within-level failure only", {
  fit <- fit_sem(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41), cluster = "cluster")
  tl <- fit@internals$ram
  theta <- unname(fit@theta)
  ok <- .sem_admissibility_ml2(theta, tl)
  expect_identical(ok$within$state, "admissible")
  expect_identical(ok$between$state, "admissible")
  k_w <- tl$k1[tl$ram1$k_s[tl$ram1$s_weight == 1]]
  bad <- theta
  bad[k_w[1L]] <- -0.05
  adm <- .sem_admissibility_ml2(bad, tl)
  expect_identical(adm$within$state, "inadmissible")
  expect_match(adm$within$reasons, "negative level-1 variance", all = FALSE)
  expect_identical(adm$between, ok$between)
})

test_that("QA: a within-level failure (mocked classifier) errors with the ledger kept; extraction refuses it", {
  d <- tl_simulate(rep(5, 40), seed = 41)
  fit <- fit_sem(tl_lavaan_model, d, cluster = "cluster")
  real <- .sem_admissibility_ml2
  local_mocked_bindings(.sem_admissibility_ml2 = function(theta, tl) {
    out <- real(theta, tl)
    out$within <- list(state = "inadmissible", reasons = "negative level-1 variance: QA")
    out
  })
  err <- tryCatch(fit_sem(tl_lavaan_model, d, cluster = "cluster"), error = function(e) e)
  expect_s3_class(err, "medfit_error_twolevel_inadmissible")
  expect_true(isTRUE(err$fit$converged))
  expect_identical(err$ledger$admissibility$within$state, "inadmissible")
  expect_identical(err$ledger$admissibility$between$state, "admissible")
  expect_identical(err$ledger$outcome, "unresolved")
  expect_false(.sem_valid_outcome(err$ledger))
  # a fitted object (built before the mock) whose ledger is forged to a within failure is refused
  forged <- fit
  dg <- forged@diagnostics
  dg$ledger$admissibility$within <- list(state = "inadmissible", reasons = "negative level-1 variance: QA")
  forged@diagnostics <- dg
  expect_error(suppressWarnings(extract_mediation(forged, treatment = "X", mediator = "M")),
               class = "medfit_error_twolevel_inadmissible")
})

test_that("QA: the validators refuse forged two-level ledgers", {
  fit <- fit_sem(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41), cluster = "cluster")
  led <- fit@diagnostics$ledger
  forge <- function(f) {
    x <- led
    f(x)
  }
  # admissible state with a reason, an unknown state, one level missing, the levels swapped in a list without names
  expect_false(.sem_valid_outcome(forge(function(x) {
    x$admissibility$within$reasons <- "x"
    x
  })))
  expect_false(.sem_valid_outcome(forge(function(x) {
    x$admissibility$between$state <- "unknown"
    x
  })))
  expect_false(.sem_valid_outcome(forge(function(x) {
    x$admissibility$between <- NULL
    x
  })))
  expect_false(.sem_valid_outcome(forge(function(x) {
    x$admissibility <- unname(x$admissibility)
    x
  })))
  # dropping both the two-level mark and the record gives a well-formed single-level node, which must not pass for
  # this two-level fit
  stripped <- forge(function(x) {
    x$context$twolevel <- NULL
    x$admissibility <- NULL
    x
  })
  bad <- fit
  dg <- bad@diagnostics
  dg$ledger <- stripped
  bad@diagnostics <- dg
  expect_error(suppressWarnings(extract_mediation(bad, treatment = "X", mediator = "M")), class = "medfit_error_ledger")
})

test_that("QA: glance() after listwise deletion (whole clusters and singletons lost) matches lavaan and a hand count", {
  d <- tl_simulate(rep(c(1, 3:11), length.out = 45), seed = 88)
  withr::with_seed(5, d$X[sample(nrow(d), 12)] <- NA)
  d$M[d$cluster %in% c(4, 17)] <- NA
  d$Y[d$cluster == 1] <- NA
  fit <- suppressMessages(fit_sem(tl_lavaan_model, d, cluster = "cluster"))
  lav <- tlq_lavaan_fit(tl_lavaan_model, d)
  g <- glance(fit)
  kept <- d[stats::complete.cases(d[c("X", "M", "Y")]), ]
  sizes <- table(kept$cluster)
  expect_identical(g$nobs, nrow(kept))
  expect_identical(g$nobs, as.integer(lavaan::lavInspect(lav, "nobs")))
  expect_identical(g$n_clusters, length(sizes))
  expect_identical(g$n_clusters, as.integer(lavaan::lavInspect(lav, "nclusters")))
  expect_identical(g$cluster_size_min, as.integer(min(sizes)))
  expect_identical(g$cluster_size_max, as.integer(max(sizes)))
  expect_lt(abs(g$logLik - as.numeric(lavaan::logLik(lav))), 1e-6)
  expect_identical(as.numeric(g$df), as.numeric(lavaan::fitMeasures(lav, "df")))
  expect_true(is.na(g$chisq))
  nat <- suppressWarnings(extract_mediation(fit, treatment = "X", mediator = "M"))
  expect_identical(nat@cluster_sizes, as.integer(sizes))
})

test_that("QA: shuffling rows and using character cluster ids changes no estimate and keeps lavaan's cluster order", {
  d <- tl_simulate(rep(c(2, 4, 7, 3, 9), length.out = 45), seed = 123)
  d$cluster <- c(LETTERS, letters)[d$cluster]
  ds <- d[withr::with_seed(2, sample(nrow(d))), ]
  a <- suppressWarnings(extract_mediation(fit_sem(tl_lavaan_model, d, cluster = "cluster"), treatment = "X",
                                          mediator = "M"))
  p <- tlq_pair(tl_lavaan_model, ds)
  expect_lt(max(abs(a@estimates - p$nat@estimates)), 1e-8)
  expect_identical(p$nat@cluster_sizes, p$lav@cluster_sizes)
})
