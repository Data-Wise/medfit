# S4a.5: admissibility per level in the outcome ledger, `extract_mediation()` on a native two-level fit, its
# provenance and `glance()`; planning/PLAN-S4a-native-twolevel-core-2026-11-18.md. Oracle: the lavaan two-level
# adapter (R/extract-lavaan-twolevel.R) on lavaan's TL-3 fit of the same data (fixed.x = FALSE, observed information,
# structured h1 information), estimates within TL-1 (max(0.01 SE, 1e-4)) and SEs within TL-2 (1e-3 relative), from
# planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md. Planted defects: admissibility read from `converged`
# only (the forged-ledger tests) and covariance rows keyed by name (the shared-label test).

skip_on_cran()  # long run: skipped on CRAN to keep the check short; runs in GitHub CI and with NOT_CRAN=true
skip_if_not_installed("lavaan")

tlx_fit <- function(model, data) fit_sem(model, data, cluster = "cluster")
tlx_lavaan <- function(model, data) suppressWarnings(extract_mediation(tln_fit_lavaan(model, data), "X", "M"))
tlx_native <- function(fit) suppressWarnings(extract_mediation(fit, treatment = "X", mediator = "M"))
tlx_shared_data <- function() {
  d <- tl_sim(J = 60L, n = 5L, seed = 11L)
  names(d)[names(d) == "id"] <- "cluster"
  d
}
# The S4a.4 QA fixture (test-twolevel-native-fit-qa.R): Y has no between residual in the population and J = 30
# clusters of size 3, so the level-2 variances of M and Y come out negative.
tlx_data_negative <- function() {
  withr::local_seed(1)
  j <- 30
  cl <- sort(rep(seq_len(j), 3))
  xb <- stats::rnorm(j)
  mb <- 0.5 * xb + stats::rnorm(j, sd = 0.3)
  yb <- 0.3 * mb + 0.2 * xb
  x <- xb[cl] + stats::rnorm(length(cl))
  m <- mb[cl] + 0.4 * x + stats::rnorm(length(cl))
  y <- yb[cl] + 0.3 * m + 0.2 * x + stats::rnorm(length(cl), sd = 1.5)
  data.frame(cluster = cl, X = x, M = m, Y = y)
}
tlx_paths <- c("a_within", "b_within", "c_prime_within", "a_between", "b_between", "c_prime_between")

# The native object next to the adapter's: the paths (TL-1), their SEs and the a-contrast SE (TL-2), and the design.
tlx_check_parity <- function(nat, lav) {
  expect_true(S7::S7_inherits(nat, TwoLevelMediationData))
  se_lav <- sqrt(diag(lav@vcov))[tlx_paths]
  excess <- abs(nat@estimates[tlx_paths] - lav@estimates[tlx_paths]) - pmax(0.01 * se_lav, 1e-4)
  expect_lte(max(excess), 0, label = paste("worst path:", tlx_paths[which.max(excess)]))
  rel <- abs(sqrt(diag(nat@vcov))[tlx_paths] - se_lav) / se_lav
  expect_lt(max(rel), 1e-3, label = paste("worst SE:", tlx_paths[which.max(rel)]))
  contrast <- function(v) {
    sqrt(max(v["a_within", "a_within"] + v["a_between", "a_between"] - 2 * v["a_within", "a_between"], 0))
  }
  if (contrast(lav@vcov) > 1e-6) {
    expect_lt(abs(contrast(nat@vcov) - contrast(lav@vcov)) / contrast(lav@vcov), 1e-3)
  } else {
    expect_lt(contrast(nat@vcov), 1e-6)
  }
  expect_identical(nat@cross_level_equal, lav@cross_level_equal)
  expect_identical(nat@between_identified, lav@between_identified)
  expect_identical(nat@n_obs, lav@n_obs)
  expect_identical(nat@n_clusters, lav@n_clusters)
  expect_identical(nat@cluster_sizes, lav@cluster_sizes)
  # the ICCs are ratios of implied variances, smooth in the estimates, so TL-1 agreement of the parameters keeps them
  # within 1e-3 (the observed gap is below 1e-5)
  expect_lt(max(abs(nat@icc - lav@icc[names(nat@icc)])), 1e-3)
}

test_that("a two-level fit records admissibility per level in its ledger", {
  fit <- tlx_fit(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41))
  ledger <- fit@diagnostics$ledger
  expect_true(isTRUE(ledger$context$twolevel))
  ok <- list(state = "admissible", reasons = character())
  expect_identical(ledger$admissibility, list(within = ok, between = ok))
  expect_true(.sem_valid_outcome(ledger))
})

test_that("the validator refuses a two-level ledger without admissibility or with an inadmissible level", {
  ledger <- tlx_fit(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41))@diagnostics$ledger
  gone <- ledger
  gone$admissibility <- NULL
  expect_false(.sem_valid_outcome(gone))
  bad <- ledger
  bad$admissibility$between <- list(state = "inadmissible", reasons = "negative level-2 variance: M~~M.l2")
  expect_false(.sem_valid_outcome(bad))
  # a single-level ledger never carries the field
  single <- fit_sem("M ~ X\nY ~ M + X", tl_simulate(rep(5, 40), seed = 41))@diagnostics$ledger
  expect_null(single$admissibility)
  single$admissibility <- list(within = list(state = "admissible", reasons = character()))
  expect_false(.sem_valid_outcome(single))
})

test_that("an inadmissible two-level fit is an error whose ledger keeps the accepted optimum (fault test)", {
  d <- tlx_data_negative()
  err <- tryCatch(tlx_fit(tl_lavaan_model, d), error = function(e) e)
  expect_s3_class(err, "medfit_error_twolevel_inadmissible")
  expect_true(isTRUE(err$fit$converged)) # the optimizer converged: `converged` alone would call it a fit
  ledger <- err$ledger
  expect_identical(ledger$outcome, "unresolved")
  expect_identical(ledger$optimizer$state, "accepted")
  expect_identical(ledger$likelihood$state, "available")
  expect_identical(ledger$likelihood$f, err$fit$f)
  expect_true(isTRUE(ledger$context$twolevel))
  expect_identical(ledger$admissibility$within$state, "admissible")
  expect_identical(ledger$admissibility$between$state, "inadmissible")
  expect_match(ledger$admissibility$between$reasons, "negative level-2 variance", all = FALSE)
  expect_identical("medfit_error_twolevel_inadmissible", ledger$condition$class[1L])
  expect_false(.sem_valid_outcome(ledger))
})

test_that("extract_mediation() on a native two-level fit matches the lavaan adapter (TL-1, TL-2)", {
  for (sizes in list(rep(5, 40), rep(2:9, length.out = 40))) {
    d <- tl_simulate(sizes, seed = 41 + length(unique(sizes)))
    nat <- tlx_native(tlx_fit(tl_lavaan_model, d))
    lav <- tlx_lavaan(tl_lavaan_model, d)
    tlx_check_parity(nat, lav)
    expect_identical(dim(nat@vcov), c(6L, 6L))
    expect_identical(rownames(nat@vcov), tlx_paths)
  }
})

test_that("a label shared across levels is one parameter: the vcov is keyed by index, not by name", {
  d <- tlx_shared_data()
  model <- tl_model(within = "a*X", between = "a*X")
  fit <- tlx_fit(model, d)
  nat <- tlx_native(fit)
  tlx_check_parity(nat, tlx_lavaan(model, d))
  expect_identical(nat@cross_level_equal, "a")
  k <- fit@internals$par_map[fit@table$op == "~" & fit@table$lhs == "M"]
  expect_identical(k[1L], k[2L])
  v <- fit@vcov[k[1L], k[1L]]
  expect_equal(unname(nat@vcov[c("a_within", "a_between"), c("a_within", "a_between")]), matrix(v, 2L, 2L),
               tolerance = 0)
})

test_that("extraction refuses a forged ledger even when the fit says converged (planted defect: converged only)", {
  fit <- tlx_fit(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41))
  expect_true(fit@converged)
  bad <- fit
  diag_bad <- bad@diagnostics
  diag_bad$ledger$admissibility$between <- list(state = "inadmissible", reasons = "negative level-2 variance: M~~M.l2")
  bad@diagnostics <- diag_bad
  expect_true(bad@converged)
  expect_error(tlx_native(bad), class = "medfit_error_twolevel_inadmissible")
  gone <- fit
  diag_gone <- gone@diagnostics
  diag_gone$ledger$admissibility <- NULL
  gone@diagnostics <- diag_gone
  expect_error(tlx_native(gone), class = "medfit_error_ledger")
})

test_that("the native object records its provenance", {
  fit <- tlx_fit(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41))
  nat <- tlx_native(fit)
  expect_identical(nat@source, "native")
  expect_identical(nat@source_package, "medfit")
  expect_identical(nat@source_version, as.character(utils::packageVersion("medfit")))
  expect_identical(nat@lavaan_version, character(0))
  expect_identical(nat@cluster, "cluster")
  expect_false(nat@fixed_x)
  expect_identical(nat@information, "observed")
  expect_identical(nat@estimator, "ML")
  expect_identical(nat@missing, "listwise")
  expect_true(nat@admissible)
  expect_true(nat@converged)
})

test_that("glance() on a two-level fit reports df, the total logLik, N, J and the cluster-size range", {
  d <- tl_simulate(rep(2:9, length.out = 40), seed = 42)
  fit <- tlx_fit(tl_lavaan_model, d)
  lav <- tln_fit_lavaan(tl_lavaan_model, d)
  g <- glance(fit)
  expect_identical(g$nobs, 220L)
  expect_identical(as.numeric(g$df), as.numeric(lavaan::fitMeasures(lav, "df")))
  expect_lt(abs(g$logLik - as.numeric(lavaan::logLik(lav))) / abs(as.numeric(lavaan::logLik(lav))), 1e-6)
  expect_identical(g$n_clusters, 40L)
  expect_identical(g$cluster_size_min, 2L)
  expect_identical(g$cluster_size_max, 9L)
  # there is no saturated two-level model in the engine, so no chi-square test
  expect_true(is.na(g$chisq) && is.na(g$p_value))
  expect_match(attr(g, "note"), "two-level")
  single <- glance(fit_sem("M ~ X\nY ~ M + X", d))
  expect_false(any(c("n_clusters", "cluster_size_min", "cluster_size_max") %in% names(single)))
})

test_that("cluster counts and sizes are taken after listwise deletion", {
  d <- tl_simulate(rep(2:9, length.out = 40), seed = 42)
  d$Y[1L] <- NA
  d$M[d$cluster == d$cluster[3L]] <- NA # removes a whole cluster
  fit <- suppressMessages(tlx_fit(tl_lavaan_model, d))
  nat <- tlx_native(fit)
  g <- glance(fit)
  expect_identical(sum(nat@cluster_sizes), nat@n_obs)
  expect_identical(g$nobs, nat@n_obs)
  expect_identical(g$n_clusters, length(unique(d$cluster[stats::complete.cases(d[c("X", "M", "Y")])])))
  expect_identical(nat@n_clusters, g$n_clusters)
})
