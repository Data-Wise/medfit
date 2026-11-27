# S4a.4: the native two-level fit (optimizer, gate, joint vcov), planning/PLAN-S4a-native-twolevel-core-2026-11-18.md.
# Oracles: lavaan with the TL-3 settings (fixed.x = FALSE, observed information, structured h1 information) for the
# estimates (TL-1, max(0.01 SE, 1e-4)), the SEs (TL-2, 1e-3 relative) and the df. Tolerances from
# planning/specs/ADR-twolevel-oracle-tolerances-2026-11-18.md. Planted defects (TL-7): a zeroed cross-level block of
# the vcov must fail the contrast-SE check, and an early-stopped SLSQP iterate must be rejected by the gate.

skip_unless_local() # local tier (5 s hosted-mode on the maintainer's machine); tests/testthat/local-only-tests.txt
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

# Native estimates and SEs under the OpenMx oracle's 15 names (tl_mx_param_map), matched by lhs, op, rhs and level.
tlf_mx_named <- function(fit) {
  tab <- fit@table
  row <- vapply(seq_len(nrow(tl_mx_param_map)), function(i) {
    r <- tl_mx_param_map[i, ]
    hit <- which(tab$lhs == r$lhs & tab$op == r$op & tab$rhs == r$rhs & tab$level == r$level)
    stopifnot(length(hit) == 1L)
    hit
  }, integer(1))
  list(est = stats::setNames(tab$est[row], tl_mx_param_map$name),
       se = stats::setNames(tab$se[row], tl_mx_param_map$name))
}

test_that("an independent optimizer (BFGS on the hand O8 likelihood) reaches the same optimum", {
  for (nm in c("bal40", "unb40")) {
    d <- tlf_fixtures()[[nm]]
    fit <- tlf_fit(tl_lavaan_model, d)
    o8 <- tl_o8_fit(d)
    expect_identical(o8$convergence, 0L)
    tln_check_rel(as.numeric(stats::logLik(fit)), o8$loglik, 1e-6)
    est <- c(a_w = o8$within[["a"]], b_w = o8$within[["b"]], cp_w = o8$within[["cp"]],
             a_b = o8$between[["a"]], b_b = o8$between[["b"]], cp_b = o8$between[["cp"]])
    se <- sqrt(diag(fit@vcov))[names(est)]
    excess <- abs(fit@theta[names(est)] - est) - pmax(0.01 * se, 1e-4)
    expect_lte(max(excess), 0, label = paste(nm, "worst path against optim():", names(est)[which.max(excess)]))
  }
})

test_that("OpenMx, a third oracle, agrees on the estimates, the SEs and the contrast SE (TL-5)", {
  skip_if_not_installed("OpenMx")
  skip_on_cran()
  for (nm in c("bal100", "unb100")) {
    d <- tlf_fixtures()[[nm]]
    fit <- tlf_fit(tl_lavaan_model, d)
    mx <- tl_mx_fit(d)
    omx <- tl_mx_estimates(mx)
    nat <- tlf_mx_named(fit)
    tl_mx_check_est(nat$est, omx)
    tl_mx_check_se(nat$se, omx)
    tl_mx_check_contrast_se(tlf_contrast_se(fit@vcov), tl_mx_contrast_se(mx$output$vcov))
    tln_check_rel(as.numeric(stats::logLik(fit)), omx$loglik, 1e-6)
  }
})

test_that("relabeling clusters and reordering rows leave the fit unchanged (metamorphic, 1e-10)", {
  d <- tlf_fixtures()$unb40
  fit <- tlf_fit(tl_lavaan_model, d)
  withr::local_seed(7)
  e <- d
  e$cluster <- c(sample(1000:2000, 40))[d$cluster] # new ids, a different sort order
  e <- e[sample(nrow(e)), ]
  fit2 <- tlf_fit(tl_lavaan_model, e)
  expect_lt(max(abs(fit2@theta - fit@theta)), 1e-10)
  expect_lt(max(abs(fit2@vcov - fit@vcov)), 1e-10)
  expect_lt(abs(fit2@f - fit@f), 1e-10)
})

test_that("adding a constant to X moves only the intercepts, by the implied amount (metamorphic, 1e-8)", {
  d <- tlf_fixtures()$unb40
  fit <- tlf_fit(tl_lavaan_model, d)
  e <- d
  e$X <- e$X + 3
  fit2 <- tlf_fit(tl_lavaan_model, e)
  th <- fit@theta
  int <- c("X~1.l2", "M~1.l2", "Y~1.l2")
  rest <- setdiff(names(th), int)
  expect_lt(max(abs(fit2@theta[rest] - th[rest])), 1e-8)
  shift <- c(3, -3 * th[["a_b"]], -3 * th[["cp_b"]])
  expect_lt(max(abs(fit2@theta[int] - th[int] - shift)), 1e-8)
  expect_lt(max(abs(fit2@vcov[rest, rest] - fit@vcov[rest, rest])), 1e-8)
})

test_that("faults: a singular start, a size-1 cluster, all clusters of size 1, an NA cluster id", {
  d <- tlf_fixtures()$unb40
  # a start with a zero within variance (singular Sigma_W) is not used; the fit still reaches the optimum
  fit <- tlf_fit(tl_lavaan_model, d)
  s <- tln_setup(tl_lavaan_model, d)
  bad <- unname(fit@theta)
  bad[match("M~~M", s$tl$par_names)] <- 0
  expect_false(.sem_start_valid(bad, s$tl))
  sing <- sub("M ~ a_w\\*X", "M ~ a_w*X\nM ~~ start(0)*M", tl_lavaan_model)
  expect_warning(fit_s <- tlf_fit(sing, d), "first start was not accepted")
  expect_lt(abs(fit_s@f - fit@f), 1e-8)
  # one cluster of size 1 among larger ones: lavaan agrees (TL-1, TL-2)
  one <- rbind(d, transform(d[1, ], cluster = 999L))
  fit1 <- tlf_fit(tl_lavaan_model, one)
  cmp <- tlf_merge(fit1, tln_fit_lavaan(tl_lavaan_model, one))
  tlf_check_est(cmp)
  tlf_check_se(cmp$se, cmp$lav_se, cmp$key)
  # every cluster of size 1, and a missing cluster id: the guards refuse
  single <- d
  single$cluster <- seq_len(nrow(single))
  expect_error(tlf_fit(tl_lavaan_model, single), class = "medfit_error_twolevel_varset")
  na_id <- d
  na_id$cluster[3] <- NA
  expect_error(tlf_fit(tl_lavaan_model, na_id), class = "medfit_error_twolevel_cluster")
})


# Frozen native results (TL-6, 1e-6): the theta, the SEs and the log-likelihood of two fixtures, recorded from
# this implementation after the oracle tests above passed. A change to the objective, the solver or the vcov that
# moves any of them by more than 1e-6 fails here.
tlf_frozen <- list(
  bal40 = list(
    model = function() tl_lavaan_model,
    data = function() tl_simulate(rep(5, 40), seed = 41),
    names = c(
      "a_w", "b_w", "cp_w", "M~~M", "Y~~Y", "X~~X", "a_b", "b_b", "cp_b", "M~~M.l2", "Y~~Y.l2",
      "X~~X.l2", "M~1.l2", "X~1.l2", "Y~1.l2"
    ),
    theta = c(
      0.54638866064, 0.419627768309, 0.224526626987, 0.738659737892, 0.93812843108, 1.05749989809,
      0.39902328947, 0.0757341253397, 0.252390100749, 0.38850655291, 0.410282550927, 0.677864921191,
      -1.20415287585, 1.5688828194, 2.1019174012
    ),
    se = c(
      0.0660727001768, 0.0890940997495, 0.0889620018647, 0.0825846693001, 0.104885947165, 0.118232082909,
      0.163321108934, 0.239963470761, 0.195247701993, 0.12212687924, 0.14079542415, 0.200268942554,
      0.281381348984, 0.149111107971, 0.407747915068
    ),
    loglik = -898.625015314
  ),
  unb40_z = list(
    model = function() tln_model_z(),
    data = function() tln_add_z(tl_simulate(rep(2:9, length.out = 40), seed = 42)),
    names = c(
      "M~X", "Y~M", "Y~X", "M~~M", "Y~~Y", "X~~X", "M~X.l2", "M~Z.l2", "Y~M.l2", "Y~X.l2", "M~~M.l2",
      "Y~~Y.l2", "X~~X.l2", "X~~Z.l2", "Z~~Z.l2", "M~1.l2", "X~1.l2", "Z~1.l2", "Y~1.l2"
    ),
    theta = c(
      0.538872379381, 0.455309788837, 0.0686088972821, 0.837972456913, 0.76023410502, 0.889492147473,
      0.322379038738, -0.0683857984373, 0.642457261739, 0.112143856825, 0.341176438978, 0.698771503919,
      0.91495116045, 1.04723590921, 1.40507023497, -1.22793229203, 1.39644984855, 0.0555926532474,
      2.46350568176
    ),
    se = c(
      0.0721267063078, 0.0708210549358, 0.0781626511432, 0.0880676463793, 0.0798676191381, 0.0935464287752,
      0.482840171909, 0.372056860283, 0.310622597108, 0.179565173997, 0.116858841077, 0.192392337284,
      0.250959873525, 0.258379034767, 0.314183255995, 0.666781390337, 0.165248843489, 0.187421332495,
      0.435911585582
    ),
    loglik = -1006.82373217
  )
)

test_that("the frozen two-level fixtures are reproduced to 1e-6 (TL-6)", {
  for (nm in names(tlf_frozen)) {
    fz <- tlf_frozen[[nm]]
    fit <- tlf_fit(fz$model(), fz$data())
    expect_identical(names(fit@theta), fz$names)
    expect_lt(max(abs(unname(fit@theta) - fz$theta)), 1e-6)
    expect_lt(max(abs(unname(sqrt(diag(fit@vcov))) - fz$se)), 1e-6)
    expect_lt(abs(as.numeric(stats::logLik(fit)) - fz$loglik), 1e-6)
  }
})
