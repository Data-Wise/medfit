# Self-checks for the floored variants of the independent oracle (#276 T2). No medfit code: every expected value is
# derived from lm() fits or hand formulas. Run from the package root:  Rscript tests/sim/oracle213-floor-check.R
# Checks (each prints PASS/FAIL; the script exits 1 on any FAIL):
#   hand      q = 0 nulls with a binding Vy floor, a binding Vm floor, and both, against values built from lm() RSS
#   feasible  at a binding floor the oracle's returned parameters respect both floors and meet the constraint
#   control   the oracle called WITHOUT the floors violates them on the same data (the checker catches a missing clip)
#   grid      no floor-feasible (t, u, z) grid point beats the oracle value by more than 1e-6
#   gridctl   an oracle value inflated by 5 is beaten by the grid (the grid check can fail)
#   equiv     a floor far below the fitted variances reproduces the unfloored oracle exactly

source("tests/sim/oracle213.R", local = FALSE)
fails <- 0L
chk <- function(name, ok, note = "") {
  cat(sprintf("%-9s %s %s\n", name, if (isTRUE(ok)) "PASS" else "FAIL", note))
  if (!isTRUE(ok)) fails <<- fails + 1L
}
gen <- function(seed, a, b, s2, n = 150) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y <- 0.3 * X + b * M + rnorm(n, sd = sqrt(s2))
  data.frame(X, M, Y)
}

# --- hand: q = 0 -------------------------------------------------------------------------------------------------
d <- gen(5, 0.6, 0.7, 1)
n <- nrow(d)
Kss <- sum((d$M - mean(d$M))^2) # a = 0: Vm numerator
Css <- sum(stats::resid(stats::lm(M ~ X, d))^2) # b = 0: Vm numerator
Ess <- sum(stats::resid(stats::lm(Y ~ X, d))^2) # b = 0: Vy numerator
Rss <- sum(stats::resid(stats::lm(Y ~ X + M, d))^2) # a = 0: Vy numerator after profiling b
hand0 <- function(vm_min, vy_min) {
  term <- function(S, v_min) {
    v <- max(S / n, v_min)
    n * log(v) + S / v
  }
  min(term(Kss, vm_min) + term(Rss, vy_min), term(Css, vm_min) + term(Ess, vy_min))
}
for (fl in list(c(0, 0), c(0, 3 * Rss / n), c(3 * Kss / n, 0), c(3 * Kss / n, 3 * Ess / n))) {
  got <- or213_fit(d, 0, fl[1], fl[2])$objective
  chk("hand", abs(got - hand0(fl[1], fl[2])) < 1e-9 * max(1, abs(got)),
      sprintf("vm_min=%.3g vy_min=%.3g", fl[1], fl[2]))
}

# --- feasible / control / grid at q != 0 -------------------------------------------------------------------------
d <- gen(7, 1.2, 0.9, 1)
cr <- or213_cross(d)
un <- or213_unres(cr)$par
q <- or213_qhat(d) + 0.2
cons <- function(p) unname(p["a"] * p["b"] / sqrt(2 * (p["b"]^2 * p["Vm"] + p["Vy"])))
for (fl in list(c(0, 3 * un[["Vy"]]), c(3 * un[["Vm"]], 0), c(2 * un[["Vm"]], 2 * un[["Vy"]]))) {
  tag <- sprintf("vm_min=%.3g vy_min=%.3g", fl[1], fl[2])
  fit <- or213_fit(d, q, fl[1], fl[2])
  p <- fit$par
  ok_floor <- p[["Vm"]] >= fl[1] * (1 - 1e-9) && p[["Vy"]] >= fl[2] * (1 - 1e-9)
  chk("feasible", ok_floor && abs(cons(p) - q) < 1e-8 * max(1, abs(q)), tag)
  # control: the oracle without the floors lands below a binding floor, which the feasibility check rejects
  free <- or213_fit(d, q)$par
  chk("control", free[["Vm"]] < fl[1] * (1 - 1e-9) || free[["Vy"]] < fl[2] * (1 - 1e-9), tag)
  # grid over (t, u, z) with u <= u_max, z <= z_max; Q at (a, b, Vm, Vy) from the profile parametrization
  umax <- if (fl[1] > 0) 1 / sqrt(fl[1]) else Inf
  zmax <- if (fl[2] > 0) 1 / sqrt(fl[2]) else Inf
  tg <- c(-exp(seq(-4, 4, length.out = 41)), exp(seq(-4, 4, length.out = 41)))
  ug <- exp(seq(log(0.05), log(min(umax, 20)), length.out = 40))
  zg <- exp(seq(log(0.05), log(min(zmax, 20)), length.out = 40))
  best <- Inf
  for (t in tg) {
    ct <- q * sqrt(2 * (1 + t^2)) / t
    for (u in ug) for (z in zg) best <- min(best, or213_Q(cr, ct / u, t * u / z, 1 / u^2, 1 / z^2))
  }
  chk("grid", best >= fit$objective - 1e-6, sprintf("%s grid min - oracle = %.4g", tag, best - fit$objective))
  # positive control: an oracle value inflated by 5 (a too-high minimum) is beaten by the grid
  chk("gridctl", !(best >= fit$objective + 5 - 1e-6), tag)
}

# --- fixture: the extreme-scale floor fixture of the gate (var-1e6-1e-6), the regime the comparator will judge --------
# Vm ~ 1e6, Vy true ~ 1e-6, so t = b * sqrt(Vm / Vy) is about 1e3 (outside the order-one grid above). The floors are
# 1e-4 x the observed variance (the solver's natural unit for a variance is sd(var)^2 with the divisor-n covariance).
gen_fix <- function(seed, a, b, sm, sy) {
  set.seed(seed)
  n <- 250
  d <- data.frame(X = stats::rbinom(n, 1, 0.5))
  d$M <- a * d$X + sm * stats::rnorm(n)
  d$Y <- 0.3 * d$X + b * d$M + sy * stats::rnorm(n)
  d
}
d <- gen_fix(7, 0, 1e-3, 1e3, 1e-3)
n <- nrow(d)
vm_min <- 1e-4 * mean((d$M - mean(d$M))^2)
vy_min <- 1e-4 * mean((d$Y - mean(d$Y))^2)
cr <- or213_cross(d)
qh <- or213_qhat(d)
set.seed(99)
for (tg in c("qhat", "qhat-0.1", "qhat+0.05", "qhat+0.2", "-qhat", "zero")) {
  q <- switch(tg,
    qhat = qh, `qhat-0.1` = qh - 0.1, `qhat+0.05` = qh + 0.05, `qhat+0.2` = qh + 0.2, `-qhat` = -qh, zero = 0
  )
  fit <- or213_fit(d, q, vm_min, vy_min)
  p <- fit$par
  feas <- p[["Vm"]] >= vm_min * (1 - 1e-9) && p[["Vy"]] >= vy_min * (1 - 1e-9)
  chk("fixture", feas && abs(cons(p) - q) < 1e-7 * max(1, abs(q)),
      sprintf("%s q=%.4g Vy=%.3g (floor %.3g)", tg, q, p[["Vy"]], vy_min))
  if (q != 0) {
    # a second, finer and wider scan on the t axis must not find a lower value than the main scan
    alt <- min(vapply(c(-1, 1), function(sg) {
      b2 <- or213_branch(sg, q, cr, r_grid = seq(-20, 20, by = 0.005), vm_min = vm_min, vy_min = vy_min)
      if (length(b2)) b2[[1]]$objective else Inf
    }, numeric(1)))
    chk("fixscan", alt >= fit$objective - 1e-7 * max(1, abs(fit$objective)),
        sprintf("%s alt - main = %.3g", tg, alt - fit$objective))
    # independent feasible candidates around the returned minimum, including the clip boundaries
    umax <- 1 / sqrt(vm_min)
    zmax <- 1 / sqrt(vy_min)
    t0 <- fit$t
    u0 <- 1 / sqrt(p[["Vm"]])
    z0 <- 1 / sqrt(p[["Vy"]])
    best <- Inf
    for (i in 1:4000) {
      t <- t0 * exp(stats::rnorm(1, 0, 0.05))
      u <- min(u0 * exp(stats::rnorm(1, 0, 0.05)), umax)
      z <- min(z0 * exp(stats::rnorm(1, 0, 0.05)), zmax)
      ct <- q * sqrt(2 * (1 + t^2)) / t
      best <- min(best, or213_Q(cr, ct / u, t * u / z, 1 / u^2, 1 / z^2))
    }
    chk("fixlocal", best >= fit$objective - 1e-6 * max(1, abs(fit$objective)),
        sprintf("%s local min - oracle = %.3g", tg, best - fit$objective))
  }
}

# --- equiv: tiny floors change nothing -----------------------------------------------------------------------------
for (qq in c(q, -q, 0)) {
  chk("equiv", identical(or213_lr(d, qq), or213_lr(d, qq, 0, 0)) &&
        abs(or213_lr(d, qq, 1e-12, 1e-12) - or213_lr(d, qq)) < 1e-9, sprintf("q=%.4g", qq))
}
if (fails) quit(status = 1L)
cat("all floor checks pass\n")
