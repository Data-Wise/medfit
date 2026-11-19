# S4a.4: the native two-level fit (optimizer, gate, joint vcov), planning/PLAN-S4a-native-twolevel-core-2026-11-18.md.
# Oracles: lavaan with the TL-3 settings (fixed.x = FALSE, observed information, structured h1 information) for the
# estimates (TL-1, max(0.01 SE, 1e-4)), the SEs (TL-2, 1e-3 relative) and the df. Tolerances from
# planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md. Planted defects (TL-7): a zeroed cross-level block of
# the vcov must fail the contrast-SE check, and an early-stopped SLSQP iterate must be rejected by the gate.

skip_if_not_installed("lavaan")

tlf_fixtures <- function() {
  list(
    bal40 = tl_simulate(rep(5, 40), seed = 41),
    unb40 = tl_simulate(rep(2:9, length.out = 40), seed = 42),
    bal100 = tl_mx_data_balanced(),
    unb100 = tl_mx_data_unbalanced()
  )
}
tlf_fit <- function(model, data, ...) fit_sem(model, data, cluster = "cluster", ...)

# The native table's free rows next to lavaan's, keyed by level, lhs, op and rhs (`~~` keys sorted, so `X ~~ Z` and
# `Z ~~ X` meet).
tlf_merge <- function(fit, lav) {
  key <- function(lhs, op, rhs, level) {
    a <- ifelse(op == "~~", pmin(lhs, rhs), lhs)
    b <- ifelse(op == "~~", pmax(lhs, rhs), rhs)
    paste(level, a, op, b)
  }
  nt <- fit@table[fit@table$free, ]
  pt <- lavaan::parameterEstimates(lav)
  pt <- pt[pt$op %in% c("~", "~~", "~1"), ]
  m <- match(key(nt$lhs, nt$op, nt$rhs, nt$level), key(pt$lhs, pt$op, pt$rhs, pt$level))
  data.frame(key = key(nt$lhs, nt$op, nt$rhs, nt$level), est = nt$est, se = nt$se, lav_est = pt$est[m],
             lav_se = pt$se[m], stringsAsFactors = FALSE)
}
tlf_check_est <- function(cmp) {
  excess <- abs(cmp$est - cmp$lav_est) - pmax(0.01 * cmp$lav_se, 1e-4)
  expect_lte(max(excess), 0, label = paste("worst estimate:", cmp$key[which.max(excess)]))
}
tlf_check_se <- function(se, lav_se, what = names(se)) {
  rel <- abs(se - lav_se) / lav_se
  expect_lt(max(rel), 1e-3, label = paste("worst SE:", what[which.max(rel)]))
}
# Within and between paths of the labeled O8 model, read from theta by name (for tl_check_paths()).
tlf_hand <- function(fit) {
  th <- fit@theta
  list(within = c(a = th[["a_w"]], b = th[["b_w"]], cp = th[["cp_w"]]),
       between = c(a = th[["a_b"]], b = th[["b_b"]], cp = th[["cp_b"]]))
}
# SE of a_w - a_b from a covariance matrix with named rows.
tlf_contrast_se <- function(v) sqrt(v["a_w", "a_w"] + v["a_b", "a_b"] - 2 * v["a_w", "a_b"])

test_that("two-level estimates match lavaan (TL-1) and the SEs match (TL-2), with and without Z", {
  for (nm in names(tlf_fixtures())) {
    d <- tlf_fixtures()[[nm]]
    for (with_z in c(FALSE, TRUE)) {
      model <- if (with_z) tln_model_z() else tl_lavaan_model
      dd <- if (with_z) tln_add_z(d) else d
      fit <- tlf_fit(model, dd)
      lav <- tln_fit_lavaan(model, dd)
      expect_true(S7::S7_inherits(fit, SEMFit))
      cmp <- tlf_merge(fit, lav)
      expect_false(anyNA(cmp$lav_est), label = paste(nm, with_z, "every free native row has a lavaan row"))
      expect_identical(nrow(cmp), as.integer(lavaan::fitMeasures(lav, "npar")))
      tlf_check_est(cmp)
      tlf_check_se(cmp$se, cmp$lav_se, cmp$key)
      expect_identical(as.numeric(fit@df), as.numeric(lavaan::fitMeasures(lav, "df")))
      if (!with_z) tl_check_paths(tlf_hand(fit), lav)
    }
  }
})

test_that("the log-likelihood at the native optimum matches lavaan's (TL-4, 1e-6 relative)", {
  d <- tlf_fixtures()$unb40
  fit <- tlf_fit(tl_lavaan_model, d)
  lav <- tln_fit_lavaan(tl_lavaan_model, d)
  tln_check_rel(as.numeric(stats::logLik(fit)), as.numeric(lavaan::logLik(lav)), 1e-6)
})

test_that("the joint vcov carries the cross-level block; zeroing it fails the contrast SE (TL-7)", {
  d <- tlf_fixtures()$unb40
  fit <- tlf_fit(tl_lavaan_model, d)
  lav <- tln_fit_lavaan(tl_lavaan_model, d)
  v <- fit@vcov
  expect_gt(abs(v["a_w", "a_b"]), 1e-4)
  lv <- lavaan::lavInspect(lav, "vcov")
  tlf_check_se(tlf_contrast_se(v), tlf_contrast_se(lv), "a_w - a_b")
  tl <- fit@internals$ram
  i1 <- setdiff(tl$k1, tl$k2)
  i2 <- setdiff(tl$k2, tl$k1)
  bad <- v
  bad[i1, i2] <- 0
  bad[i2, i1] <- 0
  expect_gt(abs(tlf_contrast_se(bad) - tlf_contrast_se(v)) / tlf_contrast_se(v), 1e-3)
  expect_failure(tlf_check_se(tlf_contrast_se(bad), tlf_contrast_se(lv), "a_w - a_b"))
})

test_that("the acceptance gate rejects an early-stopped SLSQP iterate and accepts the optimum (TL-7)", {
  d <- tlf_fixtures()$unb40
  s <- tln_setup(tl_lavaan_model, d)
  tl <- s$tl
  smp <- s$smp
  lb <- rep(-Inf, tl$q)
  ub <- rep(Inf, tl$q)
  start <- .sem_default_start(tl, smp)
  opts <- list(algorithm = .sem_nloptr_algorithm, xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = 8L)
  early <- .sem_solve_one(start, tl, smp, lb, ub, opts, TRUE, .sem_objective(tl, smp), NULL)
  # the status is forced to a success code, so the rejection comes from the stationarity check, not the status
  g_early <- .sem_gate(early$solution, 4L, tl, smp, lb, ub)
  expect_false(g_early$accepted)
  expect_gt(g_early$decrement, 1e-3)
  fit <- tlf_fit(tl_lavaan_model, d)
  g_opt <- .sem_gate(unname(fit@theta), 4L, tl, smp, lb, ub)
  expect_true(g_opt$accepted)
})

test_that("a labeled two-level fit keeps both levels' rows apart in the table", {
  fit <- tlf_fit(tl_lavaan_model, tlf_fixtures()$bal40)
  tab <- fit@table
  expect_true("level" %in% names(tab))
  expect_identical(sort(unique(tab$level)), 1:2)
  expect_identical(tab$label[tab$lhs == "M" & tab$op == "~" & tab$rhs == "X"], c("a_w", "a_b"))
  expect_true(isTRUE(fit@internals$ram$twolevel))
})
