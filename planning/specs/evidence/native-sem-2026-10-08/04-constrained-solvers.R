suppressMessages({library(nloptr); library(alabama)}); source("common.R")
set.seed(3); n<-300; X<-rnorm(n); M<-.3*X+rnorm(n); Y<-.3*M+.1*X+rnorm(n); S<-cov(data.frame(X,M,Y))*(n-1)/n
mod <- mk(c("X","M","Y"),c("X","M","Y"),list(to=c("M","Y","Y"),from=c("X","M","X"),lbl=c("a","b","cp"),val=rep(NA,3)),
  list(a=c("X","M","Y"),b=c("X","M","Y"),lbl=c("vx","vm","vy"),val=c(S[1,1],NA,NA)))
f <- function(x) fml(mod,x,S); g <- function(x) gml(mod,x,S)
cons <- list(prod=list(h=function(x) x[1]*x[2], j=function(x) matrix(c(x[2],x[1],0,0,0),1), ref=c(.047577,.053074)),
             lin =list(h=function(x) x[1]+x[2]-.5, j=function(x) matrix(c(1,1,0,0,0),1), ref=NULL))
starts <- c(list(c(.3,.3,.1,1,1), c(.5,-.5,0,1,1), c(-.8,.8,.3,2,2), c(0,0,0,.5,.5)), lapply(1:6, function(i){set.seed(100+i); c(runif(2,-1,1), runif(1,-.5,.5), runif(2,.3,2))}))
slv <- list(
 nloptr_SLSQP=function(h,j,s) {o<-nloptr(s,f,g,eval_g_eq=h,eval_jac_g_eq=j,opts=list(algorithm="NLOPT_LD_SLSQP",xtol_rel=1e-10,ftol_rel=1e-14,maxeval=2000)); list(th=o$solution,fm=o$objective)},
 alabama=function(h,j,s) {o<-auglag(s,f,g,heq=h,heq.jac=j,control.outer=list(trace=FALSE),control.optim=list(maxit=2000)); list(th=o$par,fm=o$value)})
for (cn in names(cons)) { cc <- cons[[cn]]; cat("\n== constraint:", cn, "==\n"); rows <- list()
  for (sn in names(slv)) { fm <- viol <- numeric(0); t0 <- proc.time()[[3]]
    for (s in starts) { o <- try(slv[[sn]](cc$h, cc$j, s), silent=TRUE)
      if (inherits(o,"try-error")) { fm <- c(fm, NA); viol <- c(viol, NA) } else { fm <- c(fm, o$fm); viol <- c(viol, abs(cc$h(o$th))) } }
    el <- (proc.time()[[3]]-t0)*1000/length(starts); rows[[sn]] <- list(fm=fm, viol=viol, ms=el) }
  best <- min(unlist(lapply(rows, function(r) r$fm)), na.rm=TRUE)
  for (sn in names(rows)) { r <- rows[[sn]]
    cat(sprintf("%-13s feasible(|h|<1e-6): %2d/%d | at best fmin(%.6f) +1e-6: %2d/%d | ms/solve %.1f\n", sn, sum(r$viol<1e-6,na.rm=TRUE), length(starts), best, sum(r$fm<best+1e-6 & r$viol<1e-6, na.rm=TRUE), length(starts), r$ms)) }
  if (!is.null(cc$ref)) for (sn in names(rows)) cat(sprintf("  %-13s fmin by start: %s\n", sn, paste(round(rows[[sn]]$fm,4), collapse=" "))) }
