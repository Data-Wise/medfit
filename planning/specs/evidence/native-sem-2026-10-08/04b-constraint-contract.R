suppressMessages(library(nloptr)); source("common.R")
set.seed(3); n <- 300; X <- rnorm(n); M <- .3*X + rnorm(n); Y <- .3*M + .1*X + rnorm(n); S <- cov(data.frame(X,M,Y))*(n-1)/n
mod <- mk(c("X","M","Y"),c("X","M","Y"),list(to=c("M","Y","Y"),from=c("X","M","X"),lbl=c("a","b","cp"),val=rep(NA,3)),
  list(a=c("X","M","Y"),b=c("X","M","Y"),lbl=c("vx","vm","vy"),val=c(S[1,1],NA,NA)))
f <- function(x) fml(mod,x,S); g <- function(x) gml(mod,x,S)
jac <- function(h, x) { q <- length(x); sapply(seq_len(q), function(k) { s <- .Machine$double.eps^(1/3)*max(abs(x[k]),1); e <- replace(numeric(q),k,s); (h(x+e)-h(x-e))/(2*s) }) }
# --- linearity test: Jacobian at 3 points must agree ---
is_linear <- function(h, q, tol = 1e-6, seed = 1) { set.seed(seed); J <- lapply(1:3, function(i) jac(h, runif(q, -1, 1)*2)); all(vapply(J[-1], function(j) max(abs(j - J[[1]])) <= tol*max(1, max(abs(J[[1]]))), TRUE)) }
tests <- list(`a*b`=function(x) x[1]*x[2], `a+b-0.5`=function(x) x[1]+x[2]-.5, `a-2*b`=function(x) x[1]-2*x[2], `exp(a)-1`=function(x) exp(x[1])-1, `a^2`=function(x) x[1]^2, `a*0+b`=function(x) x[1]*0+x[2], `abs(a)-b`=function(x) abs(x[1])-x[2])
cat("== linearity test (q = 5 parameters) ==\n"); for (nm in names(tests)) cat(sprintf("%-10s linear: %s\n", nm, is_linear(tests[[nm]], 5)))
# --- multistart on a*b == 0 ---
h <- function(x) x[1]*x[2]; hj <- function(x) jac(h, x)
# Acceptance (spec 4.5c): nloptr status in {1, 3, 4} (success, ftol reached, xtol reached) AND KKT stationarity <= 1e-3 (provisional; calibrated below) AND constraint residual <= 1e-6.
kkt_measure <- function(x, h, hj) { gx <- g(x); J <- matrix(hj(x), nrow = 1)
  lam <- tryCatch(qr.solve(t(J), -gx), error = function(e) 0)            # least-squares multiplier: J' lam = -g
  r <- gx + as.vector(t(J) %*% lam); max(abs(r)) / max(1, max(abs(gx))) }  # stationarity residual, scaled by the objective gradient
solve1 <- function(s) { o <- try(nloptr(s,f,g,eval_g_eq=h,eval_jac_g_eq=hj,opts=list(algorithm="NLOPT_LD_SLSQP",xtol_rel=1e-10,ftol_rel=1e-14,maxeval=2000)), silent=TRUE)
  if (inherits(o,"try-error")) return(list(fm=Inf, res=Inf, th=s, status=NA, kkt=Inf)); list(fm=o$objective, res=abs(h(o$solution)), th=o$solution, status=o$status, kkt=kkt_measure(o$solution, h, hj)) }
# Perturbed starts must be valid (positive-definite implied covariance, pd_ok in common.R): redraw up to 20 times, else reuse the user's start.
perturb <- function(s) { for (j in 1:20) { p <- s + rnorm(length(s), 0, 0.5*pmax(abs(s), 1)); if (pd_ok(mod, p)) return(p) }; s }
multistart <- function(s, k = 5, seed = 1, feas = 1e-6) { set.seed(seed); starts <- c(list(s), lapply(seq_len(k-1), function(i) perturb(s)))
  r <- lapply(starts, solve1); fm <- vapply(r, `[[`, 0, "fm"); res <- vapply(r, `[[`, 0, "res"); st <- vapply(r, function(z) isTRUE(z$status %in% c(1, 3, 4)), TRUE); kk <- vapply(r, `[[`, 0, "kkt"); ok <- res <= feas & is.finite(fm) & st & kk <= 1e-3
  if (!any(ok)) return(list(fm = NA, won = NA, spread = NA, feasible = FALSE))
  w <- which(ok)[which.min(fm[ok])]; list(fm = fm[w], won = w, spread = diff(range(fm[ok])), feasible = TRUE, n_feasible = sum(ok)) }
BEST <- 0.095154
st0 <- c(0,0,0,.5,.5); r1 <- solve1(st0); r5 <- multistart(st0)
cat(sprintf("\n== stalled start (0,0,0,.5,.5): single solve F = %.4f (|h| = %.1e) | 5 starts F = %.4f, winner = start %d, spread = %.4f ==\n", r1$fm, r1$res, r5$fm, r5$won, r5$spread))
set.seed(11); U <- lapply(1:60, function(i) c(runif(2,-1,1), runif(1,-.5,.5), runif(2,.3,2)))
hit <- function(fm) !is.na(fm) & fm < BEST + 1e-6
one <- vapply(U, function(s) hit(solve1(s)$fm), TRUE); five <- vapply(seq_along(U), function(i) hit(multistart(U[[i]], 5, seed = i)$fm), TRUE)
cat(sprintf("60 random user starts, reaches the better solution (F = %.6f): 1 start %d/60 | 5 starts %d/60\n", BEST, sum(one), sum(five)))
# --- feasibility rejection: infeasible pair  a == 1 and a == 2 ---
h2 <- function(x) c(x[1]-1, x[1]-2); h2j <- function(x) rbind(c(1,0,0,0,0), c(1,0,0,0,0))
o <- try(nloptr(c(.3,.3,.1,1,1),f,g,eval_g_eq=h2,eval_jac_g_eq=h2j,opts=list(algorithm="NLOPT_LD_SLSQP",xtol_rel=1e-10,maxeval=500)), silent=TRUE)
cat("infeasible constraint set: ", if (inherits(o,"try-error")) "nloptr error" else sprintf("status %d, max |residual| %.2f -> rejected by the 1e-6 gate: %s", o$status, max(abs(h2(o$solution))), max(abs(h2(o$solution))) > 1e-6), "\n")

# ======================================================================================================
# Review round 2 (F3 follow-ups). Spec 4.5a (syntactic linearity) and 4.5d (warning rule).
# ======================================================================================================
cat("\n== 4.5a syntactic linearity on the expression tree (conservative: anything unproven is nonlinear) ==\n")
syn_class <- function(text, labels) { e <- parse(text = text, keep.source = FALSE)[[1]]
  const <- function(e) !any(all.vars(e) %in% labels)
  lin <- function(e) { if (const(e)) return(TRUE); if (is.symbol(e)) return(TRUE)
    h <- as.character(e[[1]]); a <- as.list(e)[-1]
    switch(h, `(` = lin(a[[1]]), `+` = , `-` = all(vapply(a, lin, TRUE)),
      `*` = sum(!vapply(a, const, TRUE)) <= 1 && all(vapply(a, lin, TRUE)),
      `/` = const(a[[2]]) && lin(a[[1]]), FALSE) }
  if (lin(e)) "linear" else "nonlinear" }
tab <- c("a*b"="nonlinear", "a+b-0.5"="linear", "a-2*b"="linear", "exp(a)-1"="nonlinear", "a^2"="nonlinear", "a*0+b"="linear", "abs(a)-b"="nonlinear",
         "(a-b)*(a+b)"="nonlinear", "2*(a+b)/3"="linear", "a/b"="nonlinear", "-a + 3"="linear", "exp(1)*a"="linear",
         "a*b - a*b + a"="nonlinear", "a^1"="nonlinear", "min(a, b)"="nonlinear", "1e3*a - b"="linear")
for (tx in names(tab)) { got <- syn_class(tx, c("a","b")); cat(sprintf("%-16s %-10s %s\n", tx, got, if (got == tab[[tx]]) "PASS" else paste("FAIL, expected", tab[[tx]]))) }
cat("(a*b - a*b + a and a^1 are numerically linear; the syntactic rule calls them nonlinear on purpose: the cost is a warning and 5 starts, never a missed safeguard.)\n")
cat("A kink outside [-2, 2] that the old 3-point numeric check missed: ", syn_class("abs(a - 50) - b", c("a","b")), "\n")

cat("\n== 4.5d warning rule: warn if any start is infeasible/failed OR spread > max(1e-6, 1e-6*|F_best|) ==\n")
solve_cap <- function(h, hj, s, maxeval) { o <- try(nloptr(s, f, g, eval_g_eq = h, eval_jac_g_eq = hj, opts = list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-14, maxeval = maxeval)), silent = TRUE)
  if (inherits(o, "try-error")) return(list(fm = Inf, res = Inf, status = NA, kkt = Inf)); list(fm = o$objective, res = max(abs(h(o$solution))), status = o$status, kkt = kkt_measure(o$solution, h, hj)) }
ms2 <- function(h, hj, s, k = 5, seed = 1, maxeval = 2000) { set.seed(seed)
  starts <- c(list(s), lapply(seq_len(k - 1), function(i) perturb(s)))
  r <- lapply(starts, solve_cap, h = h, hj = hj, maxeval = maxeval) ; fm <- vapply(r, `[[`, 0, "fm"); res <- vapply(r, `[[`, 0, "res")
  ok <- res <= 1e-6 & is.finite(fm) & vapply(r, function(z) isTRUE(z$status %in% c(1, 3, 4)) && z$kkt <= 1e-3, TRUE); if (!any(ok)) return(list(n_feasible = 0, warn = NA, spread = NA))
  best <- min(fm[ok]); spread <- diff(range(fm[ok])); thr <- max(1e-6, 1e-6 * abs(best))
  list(n_feasible = sum(ok), n_starts = k, best = best, spread = spread, threshold = thr, warn_infeasible = sum(ok) < k, warn_spread = spread > thr, warn = sum(ok) < k || spread > thr) }
rep_ <- function(lbl, r) cat(sprintf("%-46s accepted %d/%d | best %.4f | spread %.2e (threshold %.1e) | warn: infeasible=%s spread=%s -> %s\n", lbl, r$n_feasible, r$n_starts, r$best, r$spread, r$threshold, r$warn_infeasible, r$warn_spread, r$warn))
hp <- function(x) x[1]*x[2]; hpj <- function(x) jac(hp, x)
rep_("a*b == 0, normal (two local solutions)", ms2(hp, hpj, c(.3,.3,.1,1,1)))
he <- function(x) exp(x[1]) + x[2] - 1.5; hej <- function(x) jac(he, x)
rep_("exp(a) + b == 1.5, normal (unique optimum)", ms2(he, hej, c(.3,.3,.1,1,1)))
cat("\n== 4.5d rule, unit level (stubbed start results): warn if any start fails OR spread > max(1e-6, 1e-6*|F_best|) ==\n")
warn_rule <- function(fm, res, new = TRUE) { ok <- is.finite(fm) & res <= 1e-6; if (!any(ok)) return("ERROR: no feasible start")
  best <- min(fm[ok]); spread <- diff(range(fm[ok])); thr <- max(1e-6, 1e-6 * abs(best)); w_spread <- spread > thr; w_fail <- sum(ok) < length(fm)
  if (new) (if (w_spread || w_fail) "WARN" else "silent") else (if (w_spread) "WARN" else "silent") }
cases <- list(
  list("one feasible start of five, at a poor local solution (F = 1.03)", c(1.03, Inf, Inf, Inf, Inf), c(0, Inf, Inf, Inf, Inf)),
  list("all five feasible and agreeing", rep(0.0952, 5), rep(0, 5)),
  list("all five feasible, two local solutions (0.0952 / 0.1061)", c(.0952, .1061, .0952, .0952, .1061), rep(0, 5)),
  list("four feasible agreeing, one failed", c(rep(0.0952, 4), Inf), c(rep(0, 4), 3)),
  list("none feasible", rep(Inf, 5), rep(Inf, 5)))
for (cs in cases) cat(sprintf("%-62s old rule: %-7s new rule: %s\n", cs[[1]], warn_rule(cs[[2]], cs[[3]], FALSE), warn_rule(cs[[2]], cs[[3]], TRUE)))

cat("\n== 4.5b start validity: three candidate rules on the same starts (spec uses pd_ok) ==\n")
cases <- list("negative variances (vm = vy = -0.5)" = c(0,0,0,-0.5,-0.5), "tiny positive variances (vm = vy = 1e-9), positive definite" = c(0,0,0,1e-9,1e-9), "ordinary start" = c(.3,.3,.1,1,1))
cat(sprintf("%-58s %12s | %-14s %-18s %-8s\n", "start", "objective", "is.finite(F)", "F < 1e9 (old script)", "pd_ok"))
for (nm in names(cases)) { st <- cases[[nm]]; v <- f(st); cat(sprintf("%-58s %12.3g | %-14s %-18s %-8s\n", nm, v, is.finite(v), v < 1e9, pd_ok(mod, st))) }
cat("is.finite(F) admits the negative-variance start (the sentinel 1e10 is finite); F < 1e9 rejects a genuinely positive-definite start whose objective is large; pd_ok decides both correctly.\n")

# ======================================================================================================
# Review round 4 (F3-c). Convergence criteria: nloptr termination status plus a KKT stationarity check.
# ======================================================================================================
cat("\n== 4.5c convergence: nloptr status + KKT stationarity of the Lagrangian (equality constraint a*b == 0) ==\n")
run_one <- function(s) { o <- try(nloptr(s, f, g, eval_g_eq = hp, eval_jac_g_eq = hpj, opts = list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-14, maxeval = 2000)), silent = TRUE)
  if (inherits(o, "try-error")) return(data.frame(status = NA, F = NA, resid = NA, kkt = NA))
  data.frame(status = o$status, F = o$objective, resid = abs(hp(o$solution)), kkt = kkt_measure(o$solution, hp, hpj)) }
st_stall <- run_one(c(0,0,0,.5,.5)); cat(sprintf("stalled start (0,0,0,.5,.5): status %d, F = %.4f, |h| = %.1e, KKT stationarity = %.3g\n", st_stall$status, st_stall$F, st_stall$resid, st_stall$kkt))
set.seed(11); U <- lapply(1:60, function(i) c(runif(2,-1,1), runif(1,-.5,.5), runif(2,.3,2)))
R <- do.call(rbind, lapply(U, run_one)); R$class <- ifelse(is.na(R$F), "error", ifelse(R$F < BEST + 1e-6, "better (a = 0)", ifelse(R$F < 0.107, "other local (b = 0)", "stalled/poor")))
cat("status codes over 60 random user starts:\n"); print(table(R$status, useNA = "ifany"))
cat("KKT stationarity by solution class (n, min, median, max):\n")
print(do.call(rbind, lapply(split(R, R$class), function(d) data.frame(n = nrow(d), min = signif(min(d$kkt, na.rm = TRUE), 3), median = signif(median(d$kkt, na.rm = TRUE), 3), max = signif(max(d$kkt, na.rm = TRUE), 3)))))

cat("\n== stalled start under the acceptance rule (status + KKT + residual) ==\n")
a1 <- multistart(c(0,0,0,.5,.5), k = 1); a5 <- multistart(c(0,0,0,.5,.5), k = 5)
cat(sprintf("n_starts = 1: accepted = %s  -> the fit errors 'no start converged' instead of returning F = 1.029\n", a1$feasible))
cat(sprintf("n_starts = 5: accepted = %s, n_accepted = %d, F = %.4f\n", a5$feasible, a5$n_feasible, a5$fm))
cat("60 random user starts, reaches the better solution under the acceptance rule: 1 start", sum(vapply(U, function(s) { r <- multistart(s, 1, seed = 1); isTRUE(r$feasible) && r$fm < BEST + 1e-6 }, TRUE)), "/60 | 5 starts",
    sum(vapply(seq_along(U), function(i) { r <- multistart(U[[i]], 5, seed = i); isTRUE(r$feasible) && r$fm < BEST + 1e-6 }, TRUE)), "/60\n")

cat("\n== KKT threshold calibration (equality constraints; converged solutions vs a stalled start) ==\n")
per_start <- function(h, hj, s, k = 5, seed = 1) { set.seed(seed); starts <- c(list(s), lapply(seq_len(k - 1), function(i) perturb(s)))
  do.call(rbind, lapply(seq_along(starts), function(i) { o <- nloptr(starts[[i]], f, g, eval_g_eq = h, eval_jac_g_eq = hj, opts = list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-14, maxeval = 2000))
    data.frame(start = i, status = o$status, F = round(o$objective, 10), resid = signif(abs(h(o$solution)), 2), kkt = signif(kkt_measure(o$solution, h, hj), 3)) })) }
cat("exp(a) + b == 1.5, five starts (all converged; the largest KKT is on an xtol-terminated start whose F equals the others to 1e-10):\n"); print(per_start(he, hej, c(.3,.3,.1,1,1)), row.names = FALSE)
cat("Planted early stop: the same constraint with loose tolerances (does a successfully terminated but non-stationary feasible point exist?):\n")
for (tol in c(1e-1, 1e-2, 1e-3)) { o <- nloptr(c(.3,.3,.1,1,1), f, g, eval_g_eq = he, eval_jac_g_eq = hej, opts = list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = tol, ftol_rel = tol, maxeval = 2000))
  cat(sprintf("  xtol_rel = ftol_rel = %.0e: status %d, F = %.6f, |h| = %.1e, KKT = %.2e -> accepted by status+residual: %s, by KKT <= 1e-3: %s\n", tol, o$status, o$objective, abs(he(o$solution)), kkt_measure(o$solution, he, hej),
      o$status %in% c(1,3,4) && abs(he(o$solution)) <= 1e-6, kkt_measure(o$solution, he, hej) <= 1e-3)) }

cat("\n== 4.5c acceptance rule, unit level (stubbed solver results) ==\n")
accept <- function(status, resid, kkt) { why <- c(if (!(status %in% c(1, 3, 4))) "status", if (!(resid <= 1e-6)) "residual", if (!(kkt <= 1e-3)) "KKT"); if (length(why)) paste("REJECT by", paste(why, collapse = " + ")) else "accept" }
stubs <- list(list("converged (status 3, resid 1e-9, KKT 1e-8)", 3, 1e-9, 1e-8), list("xtol-terminated, still converged (status 4, KKT 2.8e-5)", 4, 4.3e-9, 2.83e-5),
  list("max evaluations (status 5), feasible, stationary", 5, 0, 1e-9), list("roundoff-limited stall (status -4, resid 0, KKT 1.0): the real stalled start", -4, 0, 1),
  list("stall mislabeled as success (status 4, resid 0, KKT 1.0): only KKT can catch it", 4, 0, 1), list("success but infeasible (status 3, resid 1e-3, KKT 1e-9)", 3, 1e-3, 1e-9))
for (st in stubs) cat(sprintf("%-82s -> %s\n", st[[1]], accept(st[[2]], st[[3]], st[[4]])))
