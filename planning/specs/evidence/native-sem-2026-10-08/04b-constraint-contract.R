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
solve1 <- function(s) { o <- try(nloptr(s,f,g,eval_g_eq=h,eval_jac_g_eq=hj,opts=list(algorithm="NLOPT_LD_SLSQP",xtol_rel=1e-10,ftol_rel=1e-14,maxeval=2000)), silent=TRUE)
  if (inherits(o,"try-error")) return(list(fm=Inf, res=Inf, th=s)); list(fm=o$objective, res=abs(h(o$solution)), th=o$solution) }
# Perturbed starts must be valid (finite objective, i.e. positive definite Sigma): redraw up to 20 times, else reuse the user's start.
perturb <- function(s) { for (j in 1:20) { p <- s + rnorm(length(s), 0, 0.5*pmax(abs(s), 1)); if (f(p) < 1e9) return(p) }; s }
multistart <- function(s, k = 5, seed = 1, feas = 1e-6) { set.seed(seed); starts <- c(list(s), lapply(seq_len(k-1), function(i) perturb(s)))
  r <- lapply(starts, solve1); fm <- vapply(r, `[[`, 0, "fm"); res <- vapply(r, `[[`, 0, "res"); ok <- res <= feas & is.finite(fm)
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
  if (inherits(o, "try-error")) return(list(fm = Inf, res = Inf)); list(fm = o$objective, res = max(abs(h(o$solution)))) }
ms2 <- function(h, hj, s, k = 5, seed = 1, maxeval = 2000) { set.seed(seed)
  starts <- c(list(s), lapply(seq_len(k - 1), function(i) perturb(s)))
  r <- lapply(starts, solve_cap, h = h, hj = hj, maxeval = maxeval) ; fm <- vapply(r, `[[`, 0, "fm"); res <- vapply(r, `[[`, 0, "res")
  ok <- res <= 1e-6 & is.finite(fm); if (!any(ok)) return(list(n_feasible = 0, warn = NA, spread = NA))
  best <- min(fm[ok]); spread <- diff(range(fm[ok])); thr <- max(1e-6, 1e-6 * abs(best))
  list(n_feasible = sum(ok), n_starts = k, best = best, spread = spread, threshold = thr, warn_infeasible = sum(ok) < k, warn_spread = spread > thr, warn = sum(ok) < k || spread > thr) }
rep_ <- function(lbl, r) cat(sprintf("%-46s feasible %d/%d | best %.4f | spread %.2e (threshold %.1e) | warn: infeasible=%s spread=%s -> %s\n", lbl, r$n_feasible, r$n_starts, r$best, r$spread, r$threshold, r$warn_infeasible, r$warn_spread, r$warn))
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
