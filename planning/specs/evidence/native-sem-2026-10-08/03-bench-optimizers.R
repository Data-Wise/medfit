# 03-bench-optimizers.R
# Unconstrained optimizer reliability and speed against lavaan, on three model shapes.
#   models : latent mediator | observed + covariate | parallel two-mediator
#   n      : 50, 200, 1000
#   starts : "default" (moment-based) and "random" (default start perturbed by U(-0.5, 0.5); starts must have a positive-definite implied covariance, pd_ok in common.R)
# Reliability = the fitted model-implied covariance is within 1e-5 of lavaan's (model-agnostic, so improper
# solutions are compared too). Reps where lavaan itself did not converge are skipped and counted.
# Run from this directory:  Rscript 03-bench-optimizers.R      (REPS=30 by default; REPS=5 for a quick check)
suppressMessages({library(nloptr); library(lavaan); library(ucminf)})
source("common.R")
options(width = 200)  # keep the results table on one line per row
REPS <- as.integer(Sys.getenv("REPS", "30"))

mk_latent <- function(S) mk(c("X","M","m1","m2","m3","Y"), c("X","m1","m2","m3","Y"),
  list(to=c("m1","m2","m3","M","Y","Y"), from=c("M","M","M","X","M","X"), lbl=c("l1","l2","l3","g","b","cp"), val=c(1,NA,NA,NA,NA,NA)),
  list(a=c("X","m1","m2","m3","M","Y"), b=c("X","m1","m2","m3","M","Y"), lbl=c("vx","t1","t2","t3","vM","vY"), val=c(S["X","X"],NA,NA,NA,NA,NA)))
mk_obscov <- function(S) mk(c("X","C","M","Y"), c("X","C","M","Y"),
  list(to=c("M","M","Y","Y","Y"), from=c("X","C","M","X","C"), lbl=c("a","mc","b","cp","yc"), val=rep(NA,5)),
  list(a=c("X","C","C","M","Y"), b=c("X","C","X","M","Y"), lbl=c("vx","vc","cxc","vm","vy"), val=c(S["X","X"],S["C","C"],S["X","C"],NA,NA)))
mk_parallel <- function(S) mk(c("X","M1","M2","Y"), c("X","M1","M2","Y"),
  list(to=c("M1","M2","Y","Y","Y"), from=c("X","X","M1","M2","X"), lbl=c("a1","a2","b1","b2","cp"), val=rep(NA,5)),
  list(a=c("X","M1","M2","M1","Y"), b=c("X","M1","M2","M2","Y"), lbl=c("vx","v1","v2","c12","vy"), val=c(S["X","X"],NA,NA,NA,NA)))
gen_latent <- function(n) { X <- rnorm(n); Mm <- .4*X + rnorm(n); d <- data.frame(X, m1=Mm+rnorm(n,0,.5), m2=.8*Mm+rnorm(n), m3=.7*Mm+rnorm(n)); d$Y <- .4*Mm + .2*X + rnorm(n); d }
gen_obscov <- function(n) { X <- rnorm(n); C <- rnorm(n); M <- .45*X + .3*C + rnorm(n); data.frame(X, C, M, Y = .4*M + .2*X + .3*C + rnorm(n)) }
gen_parallel <- function(n) { X <- rnorm(n); M1 <- .4*X + rnorm(n); M2 <- .3*X + rnorm(n); data.frame(X, M1, M2, Y = .3*M1 + .25*M2 + .1*X + rnorm(n)) }
models <- list(
  latent   = list(mk = mk_latent,   gen = gen_latent,   ov = c("X","m1","m2","m3","Y"), start = c(1,1,0,0,0,.5,.5,.5,.5,.5), lav = "M =~ m1 + m2 + m3\nM ~ X\nY ~ M + X"),
  obs_cov  = list(mk = mk_obscov,   gen = gen_obscov,   ov = c("X","C","M","Y"),        start = c(0,0,0,0,0,.5,.5),          lav = "M ~ X + C\nY ~ M + X + C"),
  parallel = list(mk = mk_parallel, gen = gen_parallel, ov = c("X","M1","M2","Y"),      start = c(0,0,0,0,0,.5,.5,0,.5),     lav = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2"))
solvers <- list(
  nloptr_SLSQP = function(f,g,s) { o <- nloptr(s,f,g,opts=list(algorithm="NLOPT_LD_SLSQP",xtol_rel=1e-10,ftol_rel=1e-14,maxeval=2000)); list(th=o$solution, ok=o$status>0) },
  nloptr_LBFGS = function(f,g,s) { o <- nloptr(s,f,g,opts=list(algorithm="NLOPT_LD_LBFGS",xtol_rel=1e-10,ftol_rel=1e-14,maxeval=2000)); list(th=o$solution, ok=o$status>0) },
  nlminb       = function(f,g,s) { o <- nlminb(s,f,g,control=list(rel.tol=1e-14,x.tol=1e-12,iter.max=500,eval.max=1000)); list(th=o$par, ok=o$convergence==0) },
  optim_BFGS   = function(f,g,s) { o <- optim(s,f,g,method="BFGS",control=list(reltol=1e-14,maxit=2000)); list(th=o$par, ok=o$convergence==0) },
  ucminf       = function(f,g,s) { o <- ucminf(s,f,g,control=list(xtol=1e-12,grtol=1e-10,maxeval=2000)); list(th=o$par, ok=o$convergence>0) })
rows <- list(); skipped <- list()
for (mn in names(models)) for (n in c(50, 200, 1000)) for (st in c("default", "random")) {
  M <- models[[mn]]; acc <- lapply(solvers, function(x) c(conv = 0, match = 0, secs = 0, used = 0)); skip <- 0
  for (r in seq_len(REPS)) {
    set.seed(100000 * match(mn, names(models)) + 100 * n + r); d <- M$gen(n)
    S <- cov(d[, M$ov]) * (n - 1) / n; mod <- M$mk(S); Sm <- S[M$ov, M$ov]
    lv <- try(suppressWarnings(sem(M$lav, d)), silent = TRUE)
    if (inherits(lv, "try-error") || !lavInspect(lv, "converged")) { skip <- skip + 1; next }
    ref <- fitted(lv)$cov[M$ov, M$ov]
    s0 <- M$start
    if (st == "random") { for (k in 1:20) { s0 <- M$start + runif(length(M$start), -.5, .5); if (pd_ok(mod, s0)) break }
      if (!pd_ok(mod, s0)) s0 <- M$start }
    f <- function(x) fml(mod, x, Sm); g <- function(x) gml(mod, x, Sm)
    for (nm in names(solvers)) {
      t <- system.time(o <- try(suppressWarnings(solvers[[nm]](f, g, s0)), silent = TRUE))[["elapsed"]]
      a <- acc[[nm]]; a["used"] <- a["used"] + 1; a["secs"] <- a["secs"] + t
      if (!inherits(o, "try-error")) { a["conv"] <- a["conv"] + o$ok; a["match"] <- a["match"] + (max(abs(sigma(mod, o$th) - ref)) < 1e-5) }
      acc[[nm]] <- a } }
  for (nm in names(solvers)) { a <- acc[[nm]]
    rows[[length(rows) + 1]] <- data.frame(model = mn, n = n, start = st, solver = nm, reps = a[["used"]], lavaan_skipped = skip,
      reported_conv = round(a[["conv"]] / a[["used"]], 3), match_lavaan = round(a[["match"]] / a[["used"]], 3), ms_per_fit = round(1000 * a[["secs"]] / a[["used"]], 1)) } }
res <- do.call(rbind, rows); print(res, row.names = FALSE)
cat("\nSummary over all cells (min match, max ms):\n")
print(aggregate(cbind(match_lavaan, ms_per_fit) ~ solver, res, function(v) c(min = min(v), max = max(v))), row.names = FALSE)
