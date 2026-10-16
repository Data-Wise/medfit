# Oracles for the four-way decomposition (0.10.0 plan, task U8 preparation).
#
# Every reference here is independent of the code under test: `extract_mediation()` of a lavaan fit is NOT an
# oracle (the lavaan route and the native route share the worker, `.extract_interaction_mediation_lavaan()`).
# The references are
#   (a) lavaan's own `:=` defined parameters (`fwo_lavaan_defined()`), with the sample covariate mean entered as a
#       literal, so the standard errors are conditional on the observed covariates, as in the extractors;
#   (b) per-equation OLS fits with a hand-written delta method (`fwo_hand()`): model-based, `sandwich::vcovHC()`
#       HC0 per equation (block diagonal) and the stacked-score HC0 (cross-equation blocks included, which is what
#       a joint pseudo-ML sandwich computes);
#   (c) a known-answer generator (`fwo_kat_*`): data from a, b, c', theta3 with binary X and a reference level
#       `m_star`, the true components, and the empirical SD of the estimates over replications;
#   (d) a closed-form weighted point estimate (`fwo_hand()` with weights) for component parity with the glm route.
# Each reference takes a `defect` argument that plants a deliberate error; the oracle's own tests must then fail
# (tests/testthat/test-four-way-oracle-planted.R, and MUTANT= in tests/sim/four-way-known-answer.R).
#
# Model (VanderWeele 2014; binary X, 0 -> 1; M0 = E[M | X = 0, covariates at their means]):
#   M = b0 + a X + g'C + e_m          Y = t0 + cp X + b M + t3 X M + h'C + e_y
#   CDE = cp + t3 m*   INTref = t3 (M0 - m*)   INTmed = t3 a   PIE = b a
#   NDE = CDE + INTref   NIE = INTmed + PIE   TE = NDE + NIE

fwo_keys <- c("cde", "int_ref", "int_med", "pie", "nde", "nie", "te")

# The model variants every oracle test runs: one and two mediator covariates, and the no-covariate simple case.
fwo_cases <- list(one = "c1", two = c("c1", "c2"), none = character(0))

# Largest relative difference between two vectors of effects or SEs.
fwo_rel_gap <- function(a, b) max(abs(a - b) / abs(b))
fwo_g <- c(c1 = 0.8, c2 = -0.4)
fwo_h <- c(c1 = 0.5, c2 = 0.3)

# Simulated data with a binary treatment, `covs` (a subset of c1, c2) in both equations, `xm = x * m`, and
# a weight column `w`. `covs = character(0)` is the no-covariate model.
fwo_data <- function(n = 2000, seed = 11, covs = "c1") {
  stopifnot(all(covs %in% names(fwo_g)))
  set.seed(seed)
  d <- data.frame(x = rbinom(n, 1, 0.5), c1 = rnorm(n, mean = 2), c2 = rnorm(n, mean = -1))
  d$m <- 0.3 + 0.5 * d$x + as.vector(as.matrix(d[covs]) %*% fwo_g[covs]) + rnorm(n)
  d$xm <- d$x * d$m
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.3 * d$xm + as.vector(as.matrix(d[covs]) %*% fwo_h[covs]) + rnorm(n)
  # weights that depend on c1, so the weighted and unweighted covariate means differ (independent weights would hide
  # the F5 defect: both means are then the same up to noise)
  d$w <- runif(n, 0.4, 2.5) * exp(0.4 * (d$c1 - 2))
  d
}

# Covariate means used by the effects: weighted with case weights, as the glm route's design means. The planted
# defect `unweighted_means` always uses the plain mean.
fwo_cbar <- function(d, covs, weights = NULL, defect = "none") {
  if (!length(covs)) {
    return(numeric(0))
  }
  vapply(covs, function(cv) {
    if (is.null(weights) || identical(defect, "unweighted_means")) {
      mean(d[[cv]])
    } else {
      stats::weighted.mean(d[[cv]], weights)
    }
  }, numeric(1))
}

# The seven effects and their analytic gradient over the stacked parameter vector
# ("m:(Intercept)", "m:x", "m:<cov>", "y:x", "y:m", "y:xm", "y:<cov>"). Planted defects:
#   no_cov_term  the gradient of INTref drops the mediator-covariate coefficients (the live F1 defect of 0.8.0)
#   wrong_mstar  the reference level is ignored (taken as 0)
fwo_effects <- function(par, covs, cbar, m_star = 0, defect = "none") {
  if (identical(defect, "wrong_mstar")) m_star <- 0
  b0 <- par[["m:(Intercept)"]]
  pa <- par[["m:x"]]
  g <- if (length(covs)) par[paste0("m:", covs)] else numeric(0)
  cp <- par[["y:x"]]
  pb <- par[["y:m"]]
  t3 <- par[["y:xm"]]
  m_ref <- b0 + sum(g * cbar)
  cde <- cp + t3 * m_star
  int_ref <- t3 * (m_ref - m_star)
  int_med <- t3 * pa
  pie <- pb * pa
  c(cde = cde, int_ref = int_ref, int_med = int_med, pie = pie, nde = cde + int_ref, nie = int_med + pie,
    te = cde + int_ref + int_med + pie)
}

fwo_gradients <- function(par, covs, cbar, m_star = 0, defect = "none") {
  if (identical(defect, "wrong_mstar")) m_star <- 0
  nm <- names(par)
  gr <- function(...) {
    v <- stats::setNames(numeric(length(par)), nm)
    a <- c(...)
    v[names(a)] <- a
    v
  }
  m_ref <- par[["m:(Intercept)"]] + sum(par[paste0("m:", covs)] * cbar)
  cov_term <- if (length(covs) && !identical(defect, "no_cov_term")) {
    stats::setNames(par[["y:xm"]] * cbar, paste0("m:", covs))
  } else {
    numeric(0)
  }
  g_cde <- gr(c("y:x" = 1, "y:xm" = m_star))
  g_intref <- gr(c("y:xm" = m_ref - m_star, "m:(Intercept)" = par[["y:xm"]], cov_term))
  g_intmed <- gr(c("y:xm" = par[["m:x"]], "m:x" = par[["y:xm"]]))
  g_pie <- gr(c("y:m" = par[["m:x"]], "m:x" = par[["y:m"]]))
  rbind(cde = g_cde, int_ref = g_intref, int_med = g_intmed, pie = g_pie, nde = g_cde + g_intref,
        nie = g_intmed + g_pie, te = g_cde + g_intref + g_intmed + g_pie)
}

# Per-equation OLS fits (weighted least squares with case weights).
fwo_fit_eqs <- function(d, covs, weights = NULL) {
  d$xm <- d$x * d$m
  f_m <- stats::reformulate(c("x", covs), "m")
  f_y <- stats::reformulate(c("x", "m", "xm", covs), "y")
  if (is.null(weights)) {
    list(m = stats::lm(f_m, d), y = stats::lm(f_y, d))
  } else {
    d$.wt <- weights
    list(m = stats::lm(f_m, d, weights = d$.wt), y = stats::lm(f_y, d, weights = d$.wt))
  }
}

# Stacked HC0: bread per equation, meat from the stacked scores (w e x), so the cross-equation blocks are kept.
fwo_hc0_joint <- function(fm, fy) {
  a <- function(fit) {
    x <- stats::model.matrix(fit)
    w <- if (is.null(stats::weights(fit))) rep(1, nrow(x)) else stats::weights(fit)
    solve(crossprod(x, w * x))
  }
  a_m <- a(fm)
  a_y <- a(fy)
  s <- cbind(sandwich::estfun(fm), sandwich::estfun(fy))
  k <- ncol(a_m)
  big <- matrix(0, k + ncol(a_y), k + ncol(a_y))
  big[seq_len(k), seq_len(k)] <- a_m
  big[-seq_len(k), -seq_len(k)] <- a_y
  big %*% crossprod(s) %*% big
}

# The hand oracle: estimates and delta-method SEs from per-equation OLS.
#   vcov_type  "ols"        vcov(lm), RSS / (n - k)
#              "ml"         vcov(lm) * (n - k) / n, the ML scale (the one an SEM engine's information gives)
#              "hc0_block"  sandwich::vcovHC(lm, "HC0") per equation, block diagonal
#              "hc3_block"  sandwich::vcovHC(lm, "HC3") per equation (the glm route's `se_type = "sandwich"`)
#              "hc0_joint"  stacked-score HC0 with the cross-equation blocks
fwo_hand <- function(d, covs, weights = NULL, m_star = 0,
                     vcov_type = c("ols", "ml", "hc0_block", "hc3_block", "hc0_joint"), defect = "none") {
  vcov_type <- match.arg(vcov_type)
  eq <- fwo_fit_eqs(d, covs, weights)
  par <- c(stats::setNames(stats::coef(eq$m), paste0("m:", names(stats::coef(eq$m)))),
           stats::setNames(stats::coef(eq$y), paste0("y:", names(stats::coef(eq$y)))))
  n <- stats::nobs(eq$m)
  blk <- function(fit) {
    switch(vcov_type,
      ols = stats::vcov(fit),
      ml = stats::vcov(fit) * (n - length(stats::coef(fit))) / n,
      hc0_block = sandwich::vcovHC(fit, type = "HC0"),
      hc3_block = sandwich::vcovHC(fit, type = "HC3"),
      hc0_joint = NULL
    )
  }
  vc <- if (vcov_type == "hc0_joint") {
    fwo_hc0_joint(eq$m, eq$y)
  } else {
    k <- length(stats::coef(eq$m))
    out <- matrix(0, length(par), length(par))
    out[seq_len(k), seq_len(k)] <- blk(eq$m)
    out[-seq_len(k), -seq_len(k)] <- blk(eq$y)
    out
  }
  dimnames(vc) <- list(names(par), names(par))
  cbar <- fwo_cbar(d, covs, weights, defect)
  gm <- fwo_gradients(par, covs, cbar, m_star, defect)
  est <- fwo_effects(par, covs, cbar, m_star, defect)
  se <- sqrt(diag(gm %*% vc %*% t(gm)))
  list(est = est[fwo_keys], se = se[fwo_keys], par = par, vcov = vc, cbar = cbar, grad = gm)
}

# lavaan's own `:=` parameters for the seven effects. `information = "observed"` (the lavaan default for ML is
# expected); with weights, lavaan's `sampling.weights` robust sandwich. Planted defects as in fwo_effects, plus
# unweighted_means.
fwo_lavaan_defined <- function(d, covs, weights = NULL, m_star = 0, defect = "none") {
  cbar <- fwo_cbar(d, covs, weights, defect)
  if (identical(defect, "wrong_mstar")) m_star <- 0
  lit <- function(x) sprintf("%.17g", x)
  m_rhs <- paste(c("pa*x", if (length(covs)) paste0("pg", seq_along(covs), "*", covs), "b0*1"), collapse = " + ")
  y_rhs <- paste(c("cp*x", "pb*m", "t3*xm", if (length(covs)) paste0("ph", seq_along(covs), "*", covs)),
                 collapse = " + ")
  cov_part <- if (length(covs) && !identical(defect, "no_cov_term")) {
    paste0(" + ", paste0("pg", seq_along(covs), "*", lit(cbar), collapse = " + "))
  } else {
    ""
  }
  mean_m <- sprintf("(b0%s - %s)", cov_part, lit(m_star))
  syn <- paste(c(
    paste("m ~", m_rhs), paste("y ~", y_rhs),
    sprintf("cde := cp + t3*%s", lit(m_star)),
    sprintf("int_ref := t3*%s", mean_m),
    "int_med := t3*pa",
    "pie := pb*pa",
    sprintf("nde := cp + t3*%s + t3*%s", lit(m_star), mean_m),
    "nie := t3*pa + pb*pa",
    sprintf("te := cp + t3*%s + t3*%s + t3*pa + pb*pa", lit(m_star), mean_m)
  ), collapse = "\n")
  fit <- suppressWarnings(
    if (is.null(weights)) {
      lavaan::sem(syn, d, meanstructure = TRUE, information = "observed")
    } else {
      d$w <- weights
      lavaan::sem(syn, d, meanstructure = TRUE, sampling.weights = "w")
    }
  )
  pe <- lavaan::parameterEstimates(fit)
  pe <- pe[pe$op == ":=", ]
  list(est = stats::setNames(pe$est, pe$lhs)[fwo_keys], se = stats::setNames(pe$se, pe$lhs)[fwo_keys])
}

# ---- tolerances and their derivations -------------------------------------------------------------------------------

# Estimates and SEs of an SEM-type route against an independent reference: relative or absolute 1e-6. Derivation:
# the native engine's SLSQP stops about 3.5e-8 to 7.1e-8 from the optimum (0.10.0 plan F9, measured at n = 20000), so
# 1e-6 leaves more than a tenfold margin; lavaan's quasi-Newton iterations are observed at 1e-10 here (same models), so
# the one tolerance covers both routes and the claim "1e-8" of the first draft is not made.
fwo_tol_optimizer <- 1e-6

# Two computations of the SAME ordinary least squares fit (the glm route against the hand oracle; stacked HC0 against
# sandwich::vcovHC per block): they differ only by floating-point arithmetic, so the tolerance is 1e-8 (observed 1e-15).
fwo_tol_arithmetic <- 1e-8

# Ratio bounds for SE(OLS scale) / SE(ML scale). With block-diagonal V, SE^2 = q_m + q_y with q >= 0 per equation,
# and the OLS covariance of equation e is the ML one times n / (n - k_e). The ratio of the two effect SEs therefore
# lies between
# sqrt(n / (n - k_m)) and sqrt(n / (n - k_y)), whatever the gradient.
fwo_scale_bounds <- function(n, k_m, k_y) sort(sqrt(n / (n - c(k_m, k_y))))

# Known-answer tolerances for `reps` replications: the SD of a sample SD is 1 / sqrt(2 (reps - 1)) of the SD (normal
# theory), so a four-sigma band, plus 0.03 for the second-order delta-method terms the empirical SD includes (observed
# |SE / SD - 1| <= 0.03 at 2000 replications, n = 400). Bias is judged in Monte Carlo standard errors, four of them.
fwo_kat_tolerance <- function(reps) list(z = 4, se = 4 / sqrt(2 * (reps - 1)) + 0.03)

# ---- routes under test: each returns list(est, se) of the seven effects --------------------------------------------

fwo_out <- function(o) {
  est <- c(cde = o@cde, int_ref = o@int_ref, int_med = o@int_med, pie = o@pie, nde = o@nde, nie = o@nie,
           te = o@total_effect)
  keys <- c("cde", "int_ref", "int_med", "pie", "nde", "nie", "te")
  se <- .effect_se(o, keys) # nolint: object_usage_linter.
  list(est = est, se = stats::setNames(unname(se[keys]), fwo_keys))
}

# The existing lavaan route (extract_mediation() of a lavaan fit with the product column precomputed).
fwo_route_lavaan <- function(d, covs, weights = NULL, m_star = 0) {
  d$xm <- d$x * d$m
  syn <- paste0("m ~ ", paste(c("x", covs), collapse = " + "), "\ny ~ ",
                paste(c("x", "m", "xm", covs), collapse = " + "))
  fit <- suppressWarnings(
    if (is.null(weights)) {
      lavaan::sem(syn, d, meanstructure = TRUE, information = "observed")
    } else {
      d$w <- weights
      lavaan::sem(syn, d, meanstructure = TRUE, sampling.weights = "w")
    }
  )
  fwo_out(extract_mediation(fit, treatment = "x", mediator = "m", interaction = "xm", m_star = m_star))
}

# The glm route (fit_mediation(), engine "glm"); se_type "model" or "sandwich" (HC3 per equation, sandwich::vcovHC
# default; the native engine's sandwich is HC0).
fwo_route_glm <- function(d, covs, weights = NULL, m_star = 0, se_type = "model") {
  fit <- fit_mediation(
    stats::reformulate(c("x", "m", "x:m", covs), "y"), stats::reformulate(c("x", covs), "m"), d,
    treatment = "x", mediator = "m", weights = weights, se_type = se_type, m_star = m_star
  )
  fwo_out(fit)
}

# The native route: `fit_sem()` with the `:` product term (a product of two observed regressors, saturated mean
# structure on by the product), then `extract_mediation()` (the four-way decomposition on a SEMFit, U7). `information`
# is observed: the SEs equal OLS at the ML scale (rule-9 class), and with an endogenous product factor the expected
# information would be wrong (plan F4). `se_type` "model" is the unweighted route, "sandwich" the weighted one.
# `fwo_native_available()` probes for the `:` term with a tiny model (the sim gate skips its native route without it).
fwo_native_available <- function() {
  d <- fwo_data(200, 1)
  ok <- tryCatch({
    suppressWarnings(suppressMessages(fit_sem("m ~ x + c1\ny ~ x + m + x:m + c1", d)))
    TRUE
  }, error = function(e) FALSE)
  ok
}

fwo_route_native <- function(d, covs, weights = NULL, m_star = 0, se_type = "model") {
  syn <- paste0("m ~ ", paste(c("x", covs), collapse = " + "), "\ny ~ ",
                paste(c("x", "m", "x:m", covs), collapse = " + "))
  fit <- suppressWarnings(fit_sem( # nolint: object_usage_linter.
    syn, d, weights = weights, se_type = se_type, information = "observed"
  ))
  fwo_out(extract_mediation(fit, treatment = "x", mediator = "m", m_star = m_star))
}

# ---- known-answer simulation ------------------------------------------------------------------------------------

# True parameters: a, b, c' (cp), theta3 and the intercepts; g, h are the covariate coefficients.
fwo_kat_truth <- function(a = 0.5, b = 0.4, cp = 0.2, theta3 = 0.6, b0 = 0.3, t0 = 0) {
  list(a = a, b = b, cp = cp, theta3 = theta3, b0 = b0, t0 = t0)
}

# A fixed design: X (balanced binary), covariates and weights are drawn once and held across replications, so the
# covariate means the effects use are constants and the empirical SD over replications is the SD the
# conditional delta-method SE targets (with random covariates, the SD of an effect that contains
# `t3 * g * cbar` also carries the sampling variance of cbar, which the extractors' SEs do not).
fwo_kat_design <- function(n, seed, covs = "c1", weighted = FALSE, c_mean = 3, c_sd = 0.6) {
  set.seed(seed)
  d <- data.frame(x = sample(rep(0:1, length.out = n)), c1 = rnorm(n, c_mean, c_sd), c2 = rnorm(n, -c_mean / 2, c_sd))
  list(base = d, covs = covs,
       w = if (weighted) runif(n, 0.4, 2.5) * exp(0.5 * (d$c1 - c_mean) / c_sd) else NULL)
}

# True components at the design's covariate means (weighted when the design has weights).
fwo_kat_components <- function(truth, design, m_star = 0) {
  covs <- design$covs
  cbar <- fwo_cbar(design$base, covs, design$w)
  m_ref <- truth$b0 + sum(fwo_g[covs] * cbar)
  cde <- truth$cp + truth$theta3 * m_star
  int_ref <- truth$theta3 * (m_ref - m_star)
  int_med <- truth$theta3 * truth$a
  pie <- truth$b * truth$a
  c(cde = cde, int_ref = int_ref, int_med = int_med, pie = pie, nde = cde + int_ref, nie = int_med + pie,
    te = cde + int_ref + int_med + pie)
}

# One replication: new errors on the fixed design.
fwo_kat_draw <- function(design, truth, seed) {
  set.seed(seed)
  d <- design$base
  covs <- design$covs
  n <- nrow(d)
  d$m <- truth$b0 + truth$a * d$x + as.vector(as.matrix(d[covs]) %*% fwo_g[covs]) + rnorm(n)
  d$xm <- d$x * d$m
  d$y <- truth$t0 + truth$cp * d$x + truth$b * d$m + truth$theta3 * d$xm +
    as.vector(as.matrix(d[covs]) %*% fwo_h[covs]) + rnorm(n)
  d
}

# Run `fit_fun(data, covs, weights, m_star)` (-> list(est, se)) over `reps` replications. Returns one row per
# component: the truth, the mean estimate, the bias in Monte Carlo standard errors, the empirical SD of the
# estimates, the root-mean-square reported SE and their ratio.
fwo_kat_run <- function(fit_fun, design, truth, m_star = 0, reps = 500, seed0 = 1000L) {
  est <- se <- matrix(NA_real_, reps, length(fwo_keys), dimnames = list(NULL, fwo_keys))
  for (r in seq_len(reps)) {
    d <- fwo_kat_draw(design, truth, seed0 + r)
    # a failed fit is an unfitted replication (NA row), counted in `reps_ok`, never an aborted run
    o <- tryCatch(fit_fun(d, design$covs, design$w, m_star), error = function(e) NULL)
    if (is.null(o)) next
    est[r, ] <- o$est[fwo_keys]
    se[r, ] <- o$se[fwo_keys]
  }
  tv <- fwo_kat_components(truth, design, m_star)[fwo_keys]
  ok <- stats::complete.cases(est, se)
  sd_est <- apply(est[ok, , drop = FALSE], 2, stats::sd)
  rms_se <- sqrt(colMeans(se[ok, , drop = FALSE]^2))
  data.frame(
    component = fwo_keys, truth = unname(tv), mean_est = colMeans(est[ok, , drop = FALSE]),
    bias_z = (colMeans(est[ok, , drop = FALSE]) - tv) / (sd_est / sqrt(sum(ok))),
    sd_est = sd_est, rms_se = rms_se, se_ratio = rms_se / sd_est, reps_ok = sum(ok), row.names = NULL
  )
}

# The oracle itself as a route, for the known-answer run: hand fit, ML-scaled model SEs or HC0.
fwo_route_hand <- function(vcov_type = "ml", defect = "none") {
  function(d, covs, weights = NULL, m_star = 0) {
    o <- fwo_hand(d, covs, weights, m_star, vcov_type = vcov_type, defect = defect)
    list(est = o$est, se = o$se)
  }
}
