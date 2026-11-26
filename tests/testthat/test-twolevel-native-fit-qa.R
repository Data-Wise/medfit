# S4a.4 oracle QA (medfit-oracle-qa): checks on fixtures the implementer did not use.
# Oracles: lavaan two-level with the TL-3 settings (fixed.x = FALSE, observed information, structured h1 information)
# for estimates (TL-1), SEs (TL-2), df and logLik (TL-4); a Richardson-extrapolated Hessian of the objective values
# (numDeriv), a route independent of the finite differences of the analytic gradient that `.sem_vcov()` uses.
# Tolerances: planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md.

skip_on_cran()  # long run: skipped on CRAN to keep the check short; runs in GitHub CI and with NOT_CRAN=true
skip_if_not_installed("lavaan")

tlqa_key <- function(lhs, op, rhs, level) {
  a <- ifelse(op == "~~", pmin(lhs, rhs), lhs)
  b <- ifelse(op == "~~", pmax(lhs, rhs), rhs)
  paste(level, a, op, b)
}

# A cluster-only Z with a nonzero mean and a negative tie to the cluster mean of X, entering both between equations.
tlqa_data_z <- function() {
  withr::local_seed(2027)
  sizes <- sample(2:9, 40, replace = TRUE)
  d <- tl_simulate(sizes, seed = 2027, mu = c(-3, 10, 0.5))
  withr::local_seed(31)
  xb <- tapply(d$X, d$cluster, mean)
  zb <- -0.5 * (xb - mean(d$X)) + stats::rnorm(length(xb), sd = 0.9) + 4
  d$Z <- unname(zb[as.character(d$cluster)])
  d
}
tlqa_model_z <- "level: 1\n  M ~ a_w*X\n  Y ~ M + X\nlevel: 2\n  M ~ a_b*X + Z\n  Y ~ M + X + Z\n"

test_that("QA: unbalanced J = 40 with a cluster-only Z in both equations matches lavaan (TL-1, TL-2, TL-4, df)", {
  d <- tlqa_data_z()
  expect_identical(length(unique(d$cluster)), 40L)
  expect_gt(length(unique(table(d$cluster))), 1L)
  fit <- fit_sem(tlqa_model_z, d, cluster = "cluster")
  lav <- tln_fit_lavaan(tlqa_model_z, d)
  nt <- fit@table[fit@table$free, ]
  pt <- lavaan::parameterEstimates(lav, remove.nonfree = TRUE)
  pt <- pt[pt$op %in% c("~", "~~", "~1"), ]
  nk <- tlqa_key(nt$lhs, nt$op, nt$rhs, nt$level)
  pk <- tlqa_key(pt$lhs, pt$op, pt$rhs, pt$level)
  expect_setequal(nk, pk)
  expect_identical(nrow(nt), length(pk))
  m <- match(nk, pk)
  ratio <- abs(nt$est - pt$est[m]) / pmax(0.01 * pt$se[m], 1e-4)
  expect_lte(max(ratio), 1, label = paste("worst estimate:", nk[which.max(ratio)]))
  rel <- abs(nt$se - pt$se[m]) / pt$se[m]
  expect_lt(max(rel), 1e-3, label = paste("worst SE:", nk[which.max(rel)]))
  expect_identical(as.numeric(fit@df), as.numeric(lavaan::fitMeasures(lav, "df")))
  tln_check_rel(as.numeric(stats::logLik(fit)), as.numeric(lavaan::logLik(lav)), 1e-6)
  # the joint vcov carries a nonzero cross-level block, and the contrast SE needs it
  v <- fit@vcov
  lv <- lavaan::lavInspect(lav, "vcov")
  cs <- function(v) sqrt(v["a_w", "a_w"] + v["a_b", "a_b"] - 2 * v["a_w", "a_b"])
  expect_gt(abs(v["a_w", "a_b"]), 1e-4)
  expect_lt(abs(cs(v) - cs(lv)) / cs(lv), 1e-3)
})

test_that("QA: the finite-difference observed information agrees with a Richardson Hessian of the objective", {
  skip_if_not_installed("numDeriv")
  d <- tlqa_data_z()
  fit <- fit_sem(tlqa_model_z, d, cluster = "cluster")
  s <- tln_setup(tlqa_model_z, d)
  th <- unname(fit@theta)
  h <- numDeriv::hessian(function(t) .sem_eval(t, s$tl, s$smp, FALSE)$f, th) # nolint: object_usage_linter.
  se_rich <- sqrt(diag(solve(s$smp$n / 2 * h)))
  # TL-2's 1e-3 bound: the vcov route must not spend the SE budget the lavaan comparison relies on
  expect_lt(max(abs(sqrt(diag(fit@vcov)) - se_rich) / se_rich), 1e-4)
})

# Y has no between residual in the population and J = 30 clusters of size 3, so the level-2 variances of M and Y
# come out negative (lavaan agrees: about -0.08 and -0.37).
tlqa_data_negative <- function() {
  withr::local_seed(1)
  j <- 30
  cl <- rep(seq_len(j), 3)
  cl <- sort(cl)
  xb <- stats::rnorm(j)
  mb <- 0.5 * xb + stats::rnorm(j, sd = 0.3)
  yb <- 0.3 * mb + 0.2 * xb
  x <- xb[cl] + stats::rnorm(length(cl))
  m <- mb[cl] + 0.4 * x + stats::rnorm(length(cl))
  y <- yb[cl] + 0.3 * m + 0.2 * x + stats::rnorm(length(cl), sd = 1.5)
  data.frame(cluster = cl, X = x, M = m, Y = y)
}

test_that("QA: a negative level-2 variance is the classed inadmissible error, with the fit and the ledger kept", {
  d <- tlqa_data_negative()
  lav <- tln_fit_lavaan(tl_lavaan_model, d)
  pe <- lavaan::parameterEstimates(lav)
  lav_l2 <- pe[pe$op == "~~" & pe$lhs == pe$rhs & pe$level == 2, ]
  expect_true(any(lav_l2$est < 0)) # the oracle confirms the fixture is inadmissible
  err <- tryCatch(fit_sem(tl_lavaan_model, d, cluster = "cluster"), error = function(e) e)
  expect_s3_class(err, "medfit_error_twolevel_inadmissible")
  expect_match(conditionMessage(err), "negative level-2 variance")
  expect_true(any(grepl("level-2", err$improper)))
  expect_false(is.null(err$ledger))
  expect_identical(err$ledger$condition$class[1], "medfit_error_twolevel_inadmissible")
  # the kept fit is the unconstrained ML solution: its level-2 variances equal lavaan's (TL-1, no floor applied)
  theta <- err$fit$theta
  if (is.null(names(theta))) names(theta) <- err$fit$ram$par_names
  nat <- theta[paste0(lav_l2$lhs, "~~", lav_l2$rhs, ".l2")]
  expect_false(anyNA(nat))
  expect_lte(max(abs(nat - lav_l2$est) - pmax(0.01 * lav_l2$se, 1e-4)), 0)
  tln_check_rel(-0.5 * nrow(d) * err$fit$f, as.numeric(lavaan::logLik(lav)), 1e-6)
})

test_that("QA: a defined contrast a_w - a_b has lavaan's := estimate and delta-method SE (TL-1, TL-2)", {
  d <- tl_simulate(rep(2:9, length.out = 40), seed = 42)
  m <- paste0(tl_lavaan_model, "d_ab := a_w - a_b\n")
  fit <- fit_sem(m, d, cluster = "cluster")
  lav <- tln_fit_lavaan(m, d)
  pe <- lavaan::parameterEstimates(lav)
  ref <- pe[pe$op == ":=" & pe$lhs == "d_ab", ]
  nat <- fit@defined[fit@defined$name == "d_ab", ]
  expect_identical(nrow(ref), 1L)
  expect_identical(nrow(nat), 1L)
  expect_lte(abs(nat$est - ref$est) / max(0.01 * ref$se, 1e-4), 1)
  expect_lt(abs(nat$se - ref$se) / ref$se, 1e-3)
})
