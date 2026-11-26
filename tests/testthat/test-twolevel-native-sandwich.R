# Cluster-robust (CR0) sandwich standard errors for the native two-level fit (IG2,
# planning/specs/SCOPE-IG2-cluster-robust-se-2026-11-19.md). The score of cluster j is s_j = d log L_j / d theta,
# from the cluster's own (ybar_j, z_j, SSW_j); the meat is sum_j s_j s_j' (no J / (J - 1)), the bread the observed
# information, V = A^-1 B A^-1, projected onto the tangent space of the active constraints.
# Oracles: lavaan se = "robust.huber.white" (TL-2, 1e-3 relative) and a hand sandwich from numeric per-cluster scores
# of the unreduced stacked density (1e-6 relative on the full V).

skip_on_cran()  # long run: skipped on CRAN to keep the check short; runs in GitHub CI and with NOT_CRAN=true
tls_lavaan <- function(model, data, ...) {
  suppressWarnings(lavaan::sem(model, data, cluster = "cluster", fixed.x = FALSE, information = "observed",
                               h1.information = "structured", se = "robust.huber.white", ...))
}
tls_fit <- function(model, data, ...) fit_sem(model, data, cluster = "cluster", se_type = "sandwich", ...)
tls_sets <- function(fit) list(within = fit@internals$ram$within, between = fit@internals$ram$between)
tls_x <- function(fit, data) data[, c(fit@internals$ram$within, fit@internals$ram$between, "cluster")]
# The native table's free rows next to lavaan's, keyed by level, lhs, op and rhs (as test-twolevel-native-fit.R).
tls_merge <- function(fit, lav) {
  key <- function(lhs, op, rhs, level) {
    paste(level, ifelse(op == "~~", pmin(lhs, rhs), lhs), op, ifelse(op == "~~", pmax(lhs, rhs), rhs))
  }
  nt <- fit@table[fit@table$free, ]
  pt <- lavaan::parameterEstimates(lav)
  pt <- pt[pt$op %in% c("~", "~~", "~1"), ]
  m <- match(key(nt$lhs, nt$op, nt$rhs, nt$level), key(pt$lhs, pt$op, pt$rhs, pt$level))
  data.frame(key = key(nt$lhs, nt$op, nt$rhs, nt$level), se = nt$se, lav_se = pt$se[m], stringsAsFactors = FALSE)
}
tls_contrast_se <- function(v) sqrt(v["a_w", "a_w"] + v["a_b", "a_b"] - 2 * v["a_w", "a_b"])
# theta index of each free table row (the order of tls_merge())
tls_rows <- function(fit) fit@internals$par_map[fit@table$free]
tls_rel_v <- function(v, ref) max(abs(v - ref) / sqrt(outer(diag(ref), diag(ref))))
tls_sum_identity <- function(scores, target) {
  expect_lt(max(abs(colSums(scores) - target)) / max(1, max(abs(target))), 1e-10)
}
tls_cmp_se <- function(se, lav_se, what = names(se)) {
  rel <- abs(se - lav_se) / lav_se
  expect_lt(max(rel), 1e-3, label = paste("worst SE:", what[which.max(rel)]))
}

test_that("sandwich SEs match lavaan robust.huber.white on every free row (TL-2), with and without a cluster Z", {
  skip_if_not_installed("lavaan")
  fixtures <- list(bal = tl_data_balanced(), unb = tl_data_unbalanced(),
                   unb40 = tl_simulate(rep(2:9, length.out = 40), seed = 42))
  for (nm in names(fixtures)) {
    for (with_z in c(FALSE, TRUE)) {
      model <- if (with_z) tln_model_z() else tl_lavaan_model
      d <- if (with_z) tln_add_z(fixtures[[nm]]) else fixtures[[nm]]
      fit <- tls_fit(model, d)
      lav <- tls_lavaan(model, d)
      cmp <- tls_merge(fit, lav)
      expect_false(anyNA(cmp$lav_se), label = paste(nm, with_z, "every free row has a lavaan row"))
      tls_cmp_se(cmp$se, cmp$lav_se, paste(nm, with_z, cmp$key))
      # the estimates are the model-based fit's: only the covariance changes
      expect_equal(fit@theta, fit_sem(model, d, cluster = "cluster")@theta, tolerance = 1e-10)
      if (!with_z) {
        # the cross-level block of the meat enters the SE of a_w - a_b
        lv <- lavaan::vcov(lav)
        lav_contrast <- sqrt(lv["a_w", "a_w"] + lv["a_b", "a_b"] - 2 * lv["a_w", "a_b"])
        expect_lt(abs(tls_contrast_se(stats::vcov(fit)) / lav_contrast - 1), 1e-3)
      }
    }
  }
})

test_that("the fit records the sandwich SE type; glance() and print() name it and the cluster count", {
  d <- tl_data_unbalanced()
  fit <- tls_fit(tl_lavaan_model, d)
  expect_identical(fit@diagnostics$se_type, "sandwich")
  g <- glance(fit)
  expect_identical(g$se_type, "sandwich")
  expect_identical(g$n_clusters, 40L)
  expect_identical(glance(fit_sem(tl_lavaan_model, d, cluster = "cluster"))$se_type, "model")
  expect_output(print(fit), "cluster-robust sandwich \\(CR0, 40 clusters\\)")
  expect_output(print(summary(fit)), "cluster-robust sandwich \\(CR0, 40 clusters\\)")
  expect_output(print(fit_sem(tl_lavaan_model, d, cluster = "cluster")), "model-based")
})

test_that("per-cluster scores sum to the total gradient, at the optimum and away from it", {
  d <- tl_data_unbalanced()
  fit <- fit_sem(tl_lavaan_model, d, cluster = "cluster")
  tl <- fit@internals$ram
  x <- tls_x(fit, d)
  smp <- .sem_sample_ml2(x, tls_sets(fit), "cluster")
  for (delta in c(0, 0.05)) {
    th <- fit@theta + delta * seq_len(tl$q) / tl$q
    s <- .sem_scores_ml2(th, tl, x, "cluster")
    expect_identical(dim(s), c(40L, tl$q))
    tls_sum_identity(s, -smp$n / 2 * .sem_eval_ml2(th, tl, smp, TRUE)$g)
  }
})

test_that("the sandwich equals a hand sandwich from numeric scores of the stacked density (1e-6 on V)", {
  skip_if_not_installed("numDeriv")
  d <- tl_simulate(rep(2:6, length.out = 25), seed = 7)
  fit <- tls_fit(tl_lavaan_model, d)
  tl <- fit@internals$ram
  w <- tl$within
  cl_ll <- function(th, rows) {
    m <- .sem_twolevel_implied(tl, th)
    tln_stacked(rows, w, character(), m$sigma_w, m$sigma_b, m$mu_b)
  }
  groups <- split(d, d$cluster)
  scores <- t(vapply(groups, function(g) numDeriv::grad(function(th) cl_ll(th, g), fit@theta), numeric(tl$q)))
  hess <- numDeriv::hessian(function(th) cl_ll(th, d), fit@theta)
  bread <- solve(-hess)
  v_hand <- bread %*% crossprod(scores) %*% bread
  expect_lt(tls_rel_v(unname(stats::vcov(fit)), v_hand), 1e-6)
})

test_that("an equality constraint across levels projects the sandwich (a_w == a_b)", {
  skip_if_not_installed("lavaan")
  model <- paste(tl_lavaan_model, "a_w == a_b", sep = "\n")
  d <- tl_data_unbalanced()
  fit <- tls_fit(model, d)
  lav <- tls_lavaan(model, d)
  cmp <- tls_merge(fit, lav)
  tls_cmp_se(cmp$se, cmp$lav_se, cmp$key)
  # the constrained direction has no variance
  expect_lt(tls_contrast_se(stats::vcov(fit)), 1e-6)
})

test_that("relabeling and reordering the clusters leaves the meat unchanged; duplicating every cluster halves V", {
  d <- tl_data_unbalanced()
  fit <- tls_fit(tl_lavaan_model, d)
  tl <- fit@internals$ram
  v_at <- function(data, se_type = "sandwich") {
    x <- tls_x(fit, data)
    smp <- .sem_sample_ml2(x, tls_sets(fit), "cluster")
    meat <- if (se_type == "sandwich") .sem_meat_ml2(fit@theta, tl, x, "cluster")
    .sem_vcov(fit@theta, tl, smp, "observed", se_type = se_type, meat = meat)
  }
  v0 <- v_at(d)
  expect_equal(unname(v0), unname(stats::vcov(fit)), tolerance = 1e-10)
  relabeled <- d
  relabeled$cluster <- paste0("k", 1000 - as.integer(factor(d$cluster)))
  s0 <- .sem_scores_ml2(fit@theta, tl, tls_x(fit, d), "cluster")
  m0 <- .sem_meat_ml2(fit@theta, tl, tls_x(fit, d), "cluster")
  v0_model <- v_at(d, "model")
  for (seed in 1:5) {
    withr::with_seed(seed, shuffled <- relabeled[sample(nrow(relabeled)), ])
    # the IG2 part, scores and meat, is invariant elementwise (cluster i of d is cluster k(1000 - i) of shuffled)
    s1 <- .sem_scores_ml2(fit@theta, tl, tls_x(fit, shuffled), "cluster")
    expect_lt(max(abs(s1[paste0("k", 1000 - seq_len(nrow(s0))), ] - s0)), 1e-10)
    expect_lt(max(abs(.sem_meat_ml2(fit@theta, tl, tls_x(fit, shuffled), "cluster") - m0)), 1e-10)
    # V is not: the observed-information bread is a finite-difference Hessian of a sum taken in row order, so it
    # moves with the row order before IG2 too (the model-based V moves about 2e-11 here). The sandwich V may move
    # only as much as that bread noise carries through, a small multiple of the model-based V's own change.
    ref_change <- max(tls_rel_v(v_at(shuffled, "model"), v0_model), 1e-13)
    expect_lt(tls_rel_v(v_at(shuffled), v0), 10 * ref_change)
  }
  twice <- rbind(d, transform(d, cluster = paste0("copy", cluster)))
  fit2 <- tls_fit(tl_lavaan_model, twice)
  expect_lt(tls_rel_v(2 * stats::vcov(fit2), stats::vcov(fit)), 1e-3)
})

test_that("a one-row cluster has a finite score and still matches lavaan", {
  skip_if_not_installed("lavaan")
  d <- tl_data_unbalanced()
  single <- d[d$cluster != d$cluster[1] | !duplicated(d$cluster), ]
  expect_identical(sum(table(single$cluster) == 1L), 1L)
  fit <- tls_fit(tl_lavaan_model, single)
  s <- .sem_scores_ml2(fit@theta, fit@internals$ram, tls_x(fit, single), "cluster")
  expect_true(all(is.finite(s)))
  cmp <- tls_merge(fit, tls_lavaan(tl_lavaan_model, single))
  tls_cmp_se(cmp$se, cmp$lav_se, cmp$key)
})

test_that("the meat over two clusters has rank 2 at a given theta; a real two-cluster fit does not converge", {
  d <- tl_data_unbalanced()
  # a property of B alone, not of a fit: evaluated at the 40-cluster estimate on a two-cluster subset, the meat is a
  # sum of two outer products, so its rank is 2 whatever q is
  fit40 <- fit_sem(tl_lavaan_model, d, cluster = "cluster")
  two <- d[d$cluster %in% unique(d$cluster)[1:2], ]
  meat <- .sem_meat_ml2(fit40@theta, fit40@internals$ram, tls_x(fit40, two), "cluster")
  expect_true(all(is.finite(meat)))
  expect_identical(qr(meat)$rank, 2L)
  # fitting those two clusters fails before any covariance is formed, the same classed error for both SE types
  expect_error(fit_sem(tl_lavaan_model, two, cluster = "cluster"), class = "medfit_error_no_convergence")
  expect_error(tls_fit(tl_lavaan_model, two), class = "medfit_error_no_convergence")
})

test_that("a sandwich fit keeps the few-clusters warning at extraction", {
  fit <- tls_fit(tl_lavaan_model, tl_data_unbalanced())
  expect_warning(extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"),
                 class = "medfit_warning_twolevel_few_clusters")
})

# Planted defects (scope note section 6): each wrong sandwich must fail the check the oracle tests use.
test_that("planted defects in the scores, meat or projection fail the oracle checks", {
  skip_if_not_installed("lavaan")
  d <- tl_data_unbalanced()
  fit <- tls_fit(tl_lavaan_model, d)
  tl <- fit@internals$ram
  x <- tls_x(fit, d)
  smp <- .sem_sample_ml2(x, tls_sets(fit), "cluster")
  lav <- tls_lavaan(tl_lavaan_model, d)
  cmp <- tls_merge(fit, lav)
  s <- .sem_scores_ml2(fit@theta, tl, x, "cluster")
  a_inv <- solve(.sem_info_observed(fit@theta, tl, smp))
  se_from <- function(meat) sqrt(diag(a_inv %*% meat %*% a_inv))[tls_rows(fit)]
  # the correct pieces pass
  tls_cmp_se(se_from(crossprod(s)), cmp$lav_se)
  # 1. scores pooled by cluster size instead of per cluster, planted in .sem_scores_ml2() and run through the fit
  scores_ok <- .sem_scores_ml2
  local({
    local_mocked_bindings(.package = "medfit", .sem_scores_ml2 = function(theta, ram, data, cluster) {
      sc <- scores_ok(theta, ram, data, cluster)
      rowsum(sc, as.integer(table(factor(data[[cluster]]))))
    })
    bad <- tls_merge(tls_fit(tl_lavaan_model, d), lav)
    expect_failure(tls_cmp_se(bad$se, bad$lav_se))
  })
  n_j <- as.integer(table(x$cluster))
  # 2. casewise: each row carries s_j / n_j, so the meat is sum_j s_j s_j' / n_j
  expect_failure(tls_cmp_se(se_from(crossprod(s / sqrt(n_j))), cmp$lav_se))
  # 3. the cross-level block of the meat dropped: the SE of a_w - a_b moves
  meat <- crossprod(s)
  i1 <- setdiff(tl$k1, tl$k2)
  i2 <- setdiff(tl$k2, tl$k1)
  meat[i1, i2] <- 0
  meat[i2, i1] <- 0
  v_cut <- a_inv %*% meat %*% a_inv
  dimnames(v_cut) <- list(tl$par_names, tl$par_names)
  lv <- lavaan::vcov(lav)
  lav_contrast <- sqrt(lv["a_w", "a_w"] + lv["a_b", "a_b"] - 2 * lv["a_w", "a_b"])
  expect_failure(expect_lt(abs(tls_contrast_se(v_cut) / lav_contrast - 1), 1e-3))
  # 4. a cluster dropped or doubled: the scores no longer sum to the gradient (taken away from the optimum)
  th <- fit@theta + 0.05
  s_off <- .sem_scores_ml2(th, tl, x, "cluster")
  target <- -smp$n / 2 * .sem_eval_ml2(th, tl, smp, TRUE)$g
  expect_failure(tls_sum_identity(s_off[-1, , drop = FALSE], target))
  expect_failure(tls_sum_identity(rbind(s_off, s_off[1, ]), target))
  # 5. a CR1 meat, J / (J - 1) times CR0, planted in .sem_meat_ml2() and run through the fit
  meat_ok <- .sem_meat_ml2
  local({
    local_mocked_bindings(.package = "medfit", .sem_meat_ml2 = function(theta, ram, data, cluster) {
      n_cl <- length(unique(data[[cluster]]))
      n_cl / (n_cl - 1) * meat_ok(theta, ram, data, cluster)
    })
    bad <- tls_merge(tls_fit(tl_lavaan_model, d), lav)
    expect_failure(tls_cmp_se(bad$se, bad$lav_se))
  })
  # 6. the projection skipped under a_w == a_b: the unprojected sandwich at the constrained optimum
  model_c <- paste(tl_lavaan_model, "a_w == a_b", sep = "\n")
  fit_c <- tls_fit(model_c, d)
  s_c <- .sem_scores_ml2(fit_c@theta, tl, x, "cluster")
  a_c <- solve(.sem_info_observed(fit_c@theta, fit_c@internals$ram, smp))
  se_raw <- sqrt(diag(a_c %*% crossprod(s_c) %*% a_c))[tls_rows(fit_c)]
  expect_failure(tls_cmp_se(se_raw, tls_merge(fit_c, tls_lavaan(model_c, d))$lav_se))
})
