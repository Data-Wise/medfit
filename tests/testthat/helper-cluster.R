# Verification harness for cluster-level mediation (ClusterMediationData, 2-1-1)
#
# See planning/specs/SPEC-multilevel-mediation-2-1-1-2026-09-25.md,
# "Verification harness". Every oracle here is independent of the effect
# formulas under test:
#
# - sim_cluster211():        data from a known data-generating process (DGP);
#                            the noise is stored so the truth reuses it
# - true_cluster_effects():  oracle 1 -- counterfactuals on the realized units
#                            from the TRUE equations (never the formulas)
# - fit_cluster211():        the shared lmer fits + extract_mediation() call
# - te_oracle():             the reduced-form lmer X coefficient, with the
#                            cluster-bootstrap SE of its difference from te()
# - sim_gate():              replication gates for tests/sim/coverage-2-1-1.R
#
# effects_from() is shared with helper-joint.R (PLAN decision P7): it already
# takes an object or a planted-defect `effect_fn`, so it is not redefined here.
# testthat sources helpers alphabetically, but the call happens at test time.
#
# fit_cluster211(), te_oracle() and sim_gate() call ClusterMediationData code
# that arrives in T2-T5, so no test exercises them yet (first use: T6/T9).

# Muffle only the few-cluster warning (A2), so tests that fit on a handful of
# clusters stay quiet while every other warning still surfaces.
quiet_few <- function(expr) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl("^Only [0-9]+ clusters|clusters \\(fewer than 25\\)", conditionMessage(w))) {
      invokeRestart("muffleWarning")
    }
  })
}

# Default constants. M = b0 + a X + g C + v + r; Y adds t4 (within) and t5
# (between) covariate effects, so t5 only matters when C has a between part.
cluster_default_par <- function() {
  list(b0 = 0.1, g = 0.3, t0 = 0.1, t4 = 0.3, t5 = 0.8, sd_r = 1, sd_e = 1)
}

# Mediator for every unit at cluster-level treatment `xj` (length J).
cluster_mediator <- function(dgp, xj) {
  p <- dgp$par
  cv <- if (is.null(dgp$C)) 0 else p$g * dgp$C
  p$b0 + dgp$a * xj[dgp$id] + cv + dgp$v[dgp$id] + dgp$r
}

# Structural outcome for the rows `idx` of one cluster (treatment `x`, mediator
# values `m`). `mbar` defaults to the cluster's observed mean; the defect hook
# in true_cluster_effects() overrides it.
cluster_outcome_rows <- function(dgp, idx, x, m, mbar = mean(m)) {
  p <- dgp$par
  j <- dgp$id[idx[1]]
  bw <- dgp$b_W + dgp$slope_sd * dgp$s[j]
  mean_term <- if (dgp$process == "class_mean") {
    bw * (m - mbar) + dgp$b_B * mbar
  } else {
    bw * m + (dgp$b_B - dgp$b_W) * (sum(m) - m) / (length(m) - 1)
  }
  cov_term <- if (is.null(dgp$C)) {
    0
  } else {
    cc <- dgp$C[idx]
    p$t4 * (cc - mean(cc)) + p$t5 * mean(cc)
  }
  p$t0 + dgp$c_prime * x + mean_term + cov_term + dgp$u[j] + dgp$e[idx]
}

# Simulate a data set from the DGP. `sizes` is a scalar or a length-J vector.
# cov: "none" (no covariate), "centered" (cluster-mean centered level-1 C) or
# "confounded" (C has a between part that drives M and Y at the upper level).
# process: "class_mean" (Y uses the cluster mean) or "peer_mean" (Y uses the
# mean of the other members; needs sizes >= 2).
# All noise is drawn whatever the options, so two calls with the same seed
# differ only in the stated way.
sim_cluster211 <- function(J = 40, sizes = 10, a = 0.5, b_W = 0.3, b_B = 0.6, # nolint: object_name_linter.
                           c_prime = 0.2, tau_m = 0.5, tau_y = 0.5,
                           rho_vu = 0, slope_sd = 0,
                           cov = c("none", "centered", "confounded"),
                           process = c("class_mean", "peer_mean"),
                           seed = 1, par = cluster_default_par()) {
  cov <- match.arg(cov)
  process <- match.arg(process)
  if (!length(sizes) %in% c(1L, J)) stop("`sizes` must have length 1 or J")
  sizes <- rep_len(as.integer(sizes), J)
  if (any(sizes < 1L)) stop("every cluster needs at least one member")
  if (process == "peer_mean" && any(sizes < 2L)) {
    stop("process = \"peer_mean\" needs every cluster to have at least 2 members")
  }
  set.seed(seed)
  id <- rep(seq_len(J), sizes)
  n <- length(id)
  x_j <- sample(rep_len(0:1, J))
  z <- stats::rnorm(J)
  w <- stats::rnorm(n)
  vu <- matrix(stats::rnorm(2 * J), J, 2)
  s <- stats::rnorm(J)
  r <- stats::rnorm(n, sd = par$sd_r)
  e <- stats::rnorm(n, sd = par$sd_e)
  dgp <- list(
    id = id, sizes = sizes, x_j = x_j, a = a, b_W = b_W, b_B = b_B,
    c_prime = c_prime, slope_sd = slope_sd, process = process, cov = cov,
    par = par, s = s, r = r, e = e,
    v = tau_m * vu[, 1],
    u = tau_y * (rho_vu * vu[, 1] + sqrt(1 - rho_vu^2) * vu[, 2]),
    C = switch(cov, none = NULL, centered = w - stats::ave(w, id),
               confounded = z[id] + w),
    truth = c(a = a, b_within = b_W, b_between = b_B, c_prime = c_prime)
  )
  m <- cluster_mediator(dgp, x_j)
  y <- numeric(n)
  for (j in seq_len(J)) {
    idx <- which(id == j)
    y[idx] <- cluster_outcome_rows(dgp, idx, x_j[j], m[idx])
  }
  df <- data.frame(cluster = factor(id), X = x_j[id], M = m, Y = y)
  if (!is.null(dgp$C)) df$C <- dgp$C
  attr(df, "cov") <- cov
  dgp$data <- df
  dgp
}

# Oracle 1: counterfactual truth with equal cluster weights, on the realized
# units (the same noise in every world, so noise cancels in each contrast).
# NIE switches every mediator from M(0) to M(1) at X = 0, NDE switches X with
# mediators held at M(0), and the own effect switches only unit i's mediator.
# Spillover is NIE minus own. `defect = "own_fixed_mean"` plants a wrong truth
# (the cluster mean is held fixed when one unit's mediator is switched) so the
# self-tests can show the oracle would catch it. The spec's `seed` argument has
# no role: the noise lives in `dgp`.
true_cluster_effects <- function(dgp, defect = c("none", "own_fixed_mean")) {
  defect <- match.arg(defect)
  J <- length(dgp$sizes)
  m0 <- cluster_mediator(dgp, rep(0, J))
  m1 <- cluster_mediator(dgp, rep(1, J))
  per <- vapply(seq_len(J), function(j) {
    idx <- which(dgp$id == j)
    out <- function(x, m, mbar = mean(m)) {
      cluster_outcome_rows(dgp, idx, x, m, mbar)
    }
    y00 <- out(0, m0[idx])
    own <- vapply(seq_along(idx), function(i) {
      mi <- m0[idx]
      mi[i] <- m1[idx][i]
      mbar <- if (defect == "own_fixed_mean") mean(m0[idx]) else mean(mi)
      out(0, mi, mbar)[i] - y00[i]
    }, numeric(1))
    c(nie = mean(out(0, m1[idx]) - y00), nde = mean(out(1, m0[idx]) - y00),
      te = mean(out(1, m1[idx]) - y00), own = mean(own))
  }, numeric(4))
  eff <- rowMeans(per)
  c(eff, spillover = unname(eff["nie"] - eff["own"]))
}

# Covariate columns added to the fitting data, and the covariate terms.
cluster_fit_data <- function(dat) {
  d <- dat
  d$M_bar <- stats::ave(d$M, d$cluster)
  d$M_w <- d$M - d$M_bar
  if ("C" %in% names(d)) {
    d$C_bar <- stats::ave(d$C, d$cluster)
    d$C_w <- d$C - d$C_bar
  }
  d
}

cluster_cov_terms <- function(dat) {
  cov <- attr(dat, "cov")
  if (is.null(cov) || cov == "none") return(character())
  if (cov == "centered") "C" else c("C_w", "C_bar")
}

# Fit both models the way the tests share and return the ClusterMediationData.
# route = "fit" needs the lmer engine of fit_mediation(), which arrives in PR B.
# `cov_terms` overrides the covariate terms of the outcome model (for example
# "C" alone, an uncentered level-1 covariate with no cluster-mean companion).
fit_cluster211 <- function(dat, parameterization = c("within", "raw"),
                           slope = FALSE, route = c("extract", "fit"),
                           se_type = "model", cov_terms = NULL) {
  parameterization <- match.arg(parameterization)
  route <- match.arg(route)
  if (route == "fit") {
    stop("route = \"fit\" needs the lmer engine of fit_mediation() (PR B)",
         call. = FALSE)
  }
  if (slope && parameterization == "raw") {
    stop("a random slope is supported on the within term only", call. = FALSE)
  }
  d <- cluster_fit_data(dat)
  covs <- if (is.null(cov_terms)) cluster_cov_terms(dat) else cov_terms
  rhs_m <- paste(c("X", if ("C" %in% names(d)) "C"), collapse = " + ")
  mterms <- if (parameterization == "within") c("M_w", "M_bar") else c("M", "M_bar")
  rhs_y <- paste(c("X", mterms, covs), collapse = " + ")
  re_y <- if (slope) "(1 + M_w | cluster)" else "(1 | cluster)"
  m_fit <- lme4::lmer(stats::as.formula(paste("M ~", rhs_m, "+ (1 | cluster)")),
                      data = d, REML = TRUE)
  y_fit <- lme4::lmer(stats::as.formula(paste("Y ~", rhs_y, "+", re_y)),
                      data = d, REML = TRUE)
  quiet_few(extract_mediation(m_fit, model_y = y_fit, treatment = "X",
                              mediator = "M", cluster = "cluster",
                              se_type = se_type))
}

# Reduced-form X coefficient: lmer(Y ~ X + covariates + (1 | cluster)).
cluster_reduced_te <- function(dat) {
  d <- cluster_fit_data(dat)
  rhs <- paste(c("X", cluster_cov_terms(dat)), collapse = " + ")
  fit <- lme4::lmer(stats::as.formula(paste("Y ~", rhs, "+ (1 | cluster)")),
                    data = d, REML = TRUE)
  unname(lme4::fixef(fit)["X"])
}

# TE oracle: the reduced-form coefficient and the cluster-bootstrap SE of its
# difference from te(). Judge a gap against `se_diff`, not 3 SE of either one.
te_oracle <- function(dat, B = 200, seed = 3, ...) {
  te_of <- function(d) unclass(te(fit_cluster211(d, ...)))[1]
  ref <- cluster_reduced_te(dat)
  est <- te_of(dat)
  set.seed(seed)
  cl <- levels(dat$cluster)
  diffs <- vapply(seq_len(B), function(b) {
    pick <- sample(cl, length(cl), replace = TRUE)
    parts <- lapply(seq_along(pick), function(k) {
      p <- dat[dat$cluster == pick[k], , drop = FALSE]
      p$cluster <- factor(k)
      p
    })
    d <- do.call(rbind, parts)
    attr(d, "cov") <- attr(dat, "cov")
    te_of(d) - cluster_reduced_te(d)
  }, numeric(1))
  c(oracle = ref, te = unname(est), se_diff = stats::sd(diffs))
}

# Replication gates: simulate `R` data sets from `scenario` (named arguments of
# sim_cluster211()), fit each (`fit_args` go to fit_cluster211()), and return
# per path and effect: the SE ratio (mean model SE over the SD of the
# estimates), 95% Wald coverage, and the mean bias with its Monte Carlo SE; plus
# the cross-replication correlation of a-hat and b_between-hat (D4) and the
# number of fits. Effects are nie, nde, te, own, spillover (own and spillover
# are the large-cluster approximation). Uses fork parallelism on Unix.
# `se_scale` multiplies every SE, a hook for planting a wrong-SE defect.
# mclapply() cannot fork on Windows, so `cores` falls back to 1 there.
sim_gate <- function(scenario, R = 200, seed = 1, fit_args = list(), cores = 1L,
                     se_scale = 1) {
  if (.Platform$OS.type == "windows") cores <- 1L
  paths <- c("a", "b_within", "b_between", "c_prime")
  effects <- c("nie", "nde", "te", "own", "spillover")
  one <- function(r) {
    sim <- do.call(sim_cluster211, c(scenario, list(seed = seed + r)))
    obj <- tryCatch(
      suppressWarnings(suppressMessages(
        do.call(fit_cluster211, c(list(sim$data), fit_args))
      )),
      error = function(e) NULL
    )
    if (is.null(obj)) return(NULL)
    list(
      kr_df = if (identical(obj@se_type, "kr")) obj@kr_df,
      est = c(obj@estimates[paths], medfit:::.cluster_effect_vec(obj)),
      se = se_scale * c(sqrt(diag(obj@vcov)[paths]),
                        medfit:::.effect_se(obj, effects)),
      truth = c(sim$truth[paths],
                nie = sim$a * sim$b_B, nde = sim$c_prime,
                te = sim$a * sim$b_B + sim$c_prime, own = sim$a * sim$b_W,
                spillover = sim$a * (sim$b_B - sim$b_W))
    )
  }
  runs <- Filter(Negate(is.null), parallel::mclapply(seq_len(R), one, mc.cores = cores))
  est <- do.call(rbind, lapply(runs, `[[`, "est"))
  se <- do.call(rbind, lapply(runs, `[[`, "se"))
  truth <- runs[[1]]$truth
  err <- sweep(est, 2, truth[colnames(est)])
  # Wald coverage; path intervals are t intervals with the Kenward-Roger df when
  # the fits are KR (D10), effect intervals stay normal.
  crit <- matrix(stats::qnorm(0.975), nrow(est), ncol(est), dimnames = dimnames(est))
  if (!is.null(runs[[1]]$kr_df)) {
    df <- do.call(rbind, lapply(runs, `[[`, "kr_df"))
    crit[, paths] <- stats::qt(0.975, df = df[, paths])
  }
  list(
    n_fits = length(runs), R = R,
    se_ratio = colMeans(se) / apply(est, 2, stats::sd),
    coverage = colMeans(abs(err) <= crit * se),
    bias = colMeans(err),
    mc_se = apply(err, 2, stats::sd) / sqrt(nrow(err)),
    cor_a_b_between = stats::cor(est[, "a"], est[, "b_between"]),
    err = err, truth = truth
  )
}
