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
multistart <- function(s, k = 5, seed = 1, feas = 1e-6) { set.seed(seed); starts <- c(list(s), lapply(seq_len(k-1), function(i) s + rnorm(length(s), 0, 0.5*pmax(abs(s), 1))))
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
