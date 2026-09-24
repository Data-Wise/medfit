# Verification harness for joint natural effects (D8(b), JointMediationData)
#
# See planning/specs/SPEC-joint-mediator-interactions-2026-09-23.md,
# "Verification harness". Every oracle here is independent of the closed-form
# formulas under test:
#
# - sim_joint():          data from a known data-generating process (DGP)
# - true_joint_effects(): oracle 1 -- simulated nested counterfactuals from the
#                         TRUE equations (never the closed-form formulas)
# - gcomp_joint():        oracle 2 -- the same simulation from the FITTED models,
#                         via predict(), so the closed form is not reused
# - boot_joint_se():      oracle 5 -- nonparametric bootstrap SDs
# - effects_from():       effects from an object, or from a planted-defect
#                         `effect_fn`, so defects are injected without editing
#                         production code
# - fit_joint():          the shared model fits + extract_mediation() call
#
# Design: every counterfactual world reuses the same unit-level errors, so the
# per-unit contrasts of a linear DGP cancel the noise wherever the effect does
# not depend on the mediator level (e.g. a no-product NIE is exact).

# Default true parameters. Serial adds d (M1 -> M2); parallel draws correlated
# mediator errors with correlation `rho`.
joint_default_par <- function() {
  list(
    b01 = 0.2, a1 = 0.5, g1 = 0.3,          # M1 = b01 + a1 X + g1 C + e1
    b02 = 0.1, a2 = 0.3, d = 0.4, g2 = 0.2, # M2 = b02 + a2 X (+ d M1) + g2 C + e2
    t0 = 0.1, t1 = 0.2, b1 = 0.3, b2 = 0.4, t4 = 0.3,
    t3_M1 = 0, t3_M2 = 0,                   # X x M1 / X x M2 products in Y
    sd_m = 1, sd_y = 1
  )
}

# Structural mediator equations: returns list(M1, M2) for treatment level `x`,
# covariate `cv` and unit errors `e1`, `e2`.
joint_mediators <- function(par, structure, x, cv, e1, e2) {
  m1 <- par$b01 + par$a1 * x + par$g1 * cv + e1
  m2 <- par$b02 + par$a2 * x + par$g2 * cv + e2
  if (structure == "serial") m2 <- m2 + par$d * m1
  list(M1 = m1, M2 = m2)
}

# Structural outcome mean (errors omitted: they cancel in every contrast).
joint_outcome_mean <- function(par, x, m1, m2, cv) {
  par$t0 + par$t1 * x + par$b1 * m1 + par$b2 * m2 +
    par$t3_M1 * x * m1 + par$t3_M2 * x * m2 + par$t4 * cv
}

# Simulate a data set from the DGP.
# product: "none", "M1" (X x M1 in Y) or "M2" (X x M2 in Y).
sim_joint <- function(structure = c("serial", "parallel"),
                      product = c("none", "M1", "M2"),
                      n = 2000, seed = 1, rho = 0, t3 = 0.3,
                      par = joint_default_par()) {
  structure <- match.arg(structure)
  product <- match.arg(product)
  if (product != "none") par[[paste0("t3_", product)]] <- t3
  set.seed(seed)
  x <- stats::rbinom(n, 1, 0.5)
  cv <- stats::rnorm(n)
  e1 <- stats::rnorm(n, sd = par$sd_m)
  e2 <- rho * e1 + sqrt(1 - rho^2) * stats::rnorm(n, sd = par$sd_m)
  m <- joint_mediators(par, structure, x, cv, e1, e2)
  y <- joint_outcome_mean(par, x, m$M1, m$M2, cv) + stats::rnorm(n, sd = par$sd_y)
  list(
    data = data.frame(X = x, C = cv, M1 = m$M1, M2 = m$M2, Y = y),
    par = par, structure = structure, product = product, rho = rho
  )
}

# Oracle 1: the true joint effects of the DGP, by simulating the nested
# counterfactuals Y(1, M(0)), Y(0, M(0)), Y(1, M(1)) from the TRUE equations
# over the population covariate distribution (C ~ N(0, 1)).
# m_star: named reference levels for CDE, e.g. c(M1 = 0, M2 = 0).
true_joint_effects <- function(sim, draws = 1e6, seed = 99,
                               m_star = c(M1 = 0, M2 = 0)) {
  par <- sim$par
  set.seed(seed)
  cv <- stats::rnorm(draws)
  e1 <- stats::rnorm(draws, sd = par$sd_m)
  e2 <- sim$rho * e1 + sqrt(1 - sim$rho^2) * stats::rnorm(draws, sd = par$sd_m)
  m0 <- joint_mediators(par, sim$structure, 0, cv, e1, e2)
  m1 <- joint_mediators(par, sim$structure, 1, cv, e1, e2)
  y_1m0 <- joint_outcome_mean(par, 1, m0$M1, m0$M2, cv)
  y_0m0 <- joint_outcome_mean(par, 0, m0$M1, m0$M2, cv)
  y_1m1 <- joint_outcome_mean(par, 1, m1$M1, m1$M2, cv)
  nde <- mean(y_1m0 - y_0m0)
  nie <- mean(y_1m1 - y_1m0)
  cde <- joint_outcome_mean(par, 1, m_star[["M1"]], m_star[["M2"]], 0) -
    joint_outcome_mean(par, 0, m_star[["M1"]], m_star[["M2"]], 0)
  c(nde = nde, nie = nie, te = nde + nie, cde = cde)
}

# Oracle 2: g-computation from FITTED models. Resamples observed covariate rows,
# draws mediators from the fitted mediator models (serial: M2 uses the drawn M1)
# with Gaussian residual noise, and averages predict(model_y) over the
# counterfactual worlds. Uses predict(), not the closed-form formulas.
# models: list(m1 = lm, m2 = lm, y = lm); structure: "serial" / "parallel".
gcomp_joint <- function(models, data, structure, draws = 2e5, seed = 7) {
  set.seed(seed)
  base <- data[sample.int(nrow(data), draws, replace = TRUE), , drop = FALSE]
  e1 <- stats::rnorm(draws, sd = stats::sigma(models$m1))
  e2 <- stats::rnorm(draws, sd = stats::sigma(models$m2))
  draw_m <- function(x) {
    nd <- base
    nd$X <- x
    nd$M1 <- stats::predict(models$m1, newdata = nd) + e1
    nd$M2 <- stats::predict(models$m2, newdata = nd) + e2
    nd
  }
  w0 <- draw_m(0)
  w1 <- draw_m(1)
  y_at <- function(x, world) {
    nd <- world
    nd$X <- x
    stats::predict(models$y, newdata = nd)
  }
  y_1m0 <- y_at(1, w0)
  y_0m0 <- y_at(0, w0)
  y_1m1 <- y_at(1, w1)
  nde <- mean(y_1m0 - y_0m0)
  nie <- mean(y_1m1 - y_1m0)
  c(nde = nde, nie = nie, te = nde + nie)
}

# Fit the shared models (identical covariate set C in every model) and extract.
# Returns list(obj, models). `product` adds X:M1 or X:M2 to the outcome model.
fit_joint <- function(data, structure = c("serial", "parallel"),
                      product = c("none", "M1", "M2"), ...) {
  structure <- match.arg(structure)
  product <- match.arg(product)
  m1 <- stats::lm(M1 ~ X + C, data = data)
  m2 <- if (structure == "serial") {
    stats::lm(M2 ~ X + M1 + C, data = data)
  } else {
    stats::lm(M2 ~ X + C, data = data)
  }
  fy <- switch(product,
    none = Y ~ X + M1 + M2 + C,
    M1   = Y ~ X * M1 + M2 + C,
    M2   = Y ~ X * M2 + M1 + C
  )
  y <- stats::lm(fy, data = data)
  obj <- extract_mediation(m1, model_y = y, treatment = "X",
                           mediator = c("M1", "M2"),
                           mediator_models = list(m2),
                           structure = structure, ...)
  list(obj = obj, models = list(m1 = m1, m2 = m2, y = y))
}

# Effects of an object: nde/nie/te via the generics, or via a planted-defect
# `effect_fn(obj)` returning the same named vector.
effects_from <- function(obj, effect_fn = NULL) {
  if (!is.null(effect_fn)) return(effect_fn(obj))
  c(nde = unclass(nde(obj))[1], nie = unclass(nie(obj))[1],
    te = unclass(te(obj))[1])
}

# Oracle 5: nonparametric bootstrap SD of each effect. `fit_fun(data)` returns
# an object; `stat_fun(obj)` returns a named numeric vector.
boot_joint_se <- function(data, fit_fun, stat_fun, B = 5000, seed = 11) {
  set.seed(seed)
  n <- nrow(data)
  draws <- replicate(B, {
    stat_fun(fit_fun(data[sample.int(n, n, replace = TRUE), , drop = FALSE]))
  })
  apply(matrix(draws, ncol = B), 1L, stats::sd) |>
    stats::setNames(names(stat_fun(fit_fun(data))))
}
