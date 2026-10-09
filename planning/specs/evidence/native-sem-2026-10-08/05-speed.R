suppressMessages({library(Matrix); library(parallel)}); source("common.R")
n <- 200; set.seed(7); X <- rnorm(n); Mm <- .4*X+rnorm(n)
d <- data.frame(X, m1=Mm+rnorm(n,0,.5), m2=.8*Mm+rnorm(n), m3=.7*Mm+rnorm(n)); d$Y <- .4*Mm+.2*X+rnorm(n)
S <- cov(d[,c("X","m1","m2","m3","Y")])*(n-1)/n
mod <- mk(c("X","M","m1","m2","m3","Y"), c("X","m1","m2","m3","Y"),
  list(to=c("m1","m2","m3","M","Y","Y"), from=c("M","M","M","X","M","X"), lbl=c("l1","l2","l3","g","b","cp"), val=c(1,NA,NA,NA,NA,NA)),
  list(a=c("X","m1","m2","m3","M","Y"), b=c("X","m1","m2","m3","M","Y"), lbl=c("vx","t1","t2","t3","vM","vY"), val=c(S["X","X"],NA,NA,NA,NA,NA)))
th <- c(1,1,0,0,0,.5,.5,.5,.5,.5)
tm <- function(expr, reps) { e <- substitute(expr); t <- system.time(for (i in seq_len(reps)) eval(e, parent.frame()))[["elapsed"]]; 1e6*t/reps }
cat("== 1. cost per call (microseconds), latent model, 6 vars, 10 params ==\n")
cat(sprintf("mats %.0f | sigma %.0f | fml %.0f | gml %.0f\n", tm(mats(mod,th),3000), tm(sigma(mod,th),3000), tm(fml(mod,th,S),3000), tm(gml(mod,th,S),3000)))
# vectorized version: precomputed indices, no per-parameter loop
pr <- mod$pr; nv <- mod$nv; isA <- pr$m=="A"
posA <- (pr$c[isA]-1)*nv + pr$r[isA]; frA <- pr$free[isA]; kA <- pr$k[isA]; vA <- pr$val[isA]
posS <- (pr$c[!isA]-1)*nv + pr$r[!isA]; posS2 <- (pr$r[!isA]-1)*nv + pr$c[!isA]; frS <- pr$free[!isA]; kS <- pr$k[!isA]; vS <- pr$val[!isA]
A0 <- matrix(0,nv,nv); A0[posA[!frA]] <- vA[!frA]; S0 <- matrix(0,nv,nv); S0[posS[!frS]] <- vS[!frS]; S0[posS2[!frS]] <- vS[!frS]
Fm <- mod$F; I <- diag(nv); q <- length(th)
fastmats <- function(th) { A <- A0; A[posA[frA]] <- th[kA[frA]]; Sg <- S0; Sg[posS[frS]] <- th[kS[frS]]; Sg[posS2[frS]] <- th[kS[frS]]; list(A=A, S=Sg) }
fastfg <- function(th, Sm) { m <- fastmats(th); B <- solve(I - m$A); BS <- B %*% m$S; Sg <- Fm %*% (BS %*% t(B)) %*% t(Fm)
  ch <- chol(Sg); Si <- chol2inv(ch); f <- 2*sum(log(diag(ch))) + sum(Sm*Si) - log(det(Sm)) - nrow(Sm)   # tr(Sm Si) = sum(Sm*Si)
  W <- Si - Si %*% Sm %*% Si; P <- crossprod(Fm, W %*% Fm); gA <- 2*t(BS %*% t(B) %*% P %*% B); gS <- crossprod(B, P %*% B)
  g <- numeric(q); g[kA[frA]] <- gA[posA[frA]]; dS <- ifelse(pr$r[!isA]==pr$c[!isA], 1, 2)[frS]; g[kS[frS]] <- g[kS[frS]] + dS*gS[posS[frS]]
  list(f=f, g=g) }
ff <- fastfg(th, S); cat(sprintf("vectorized: max|f diff| %.1e, max|g diff| %.1e\n", abs(ff$f - fml(mod,th,S)), max(abs(ff$g - gml(mod,th,S)))))
cat(sprintf("vectorized f+g %.0f us vs original f+g %.0f us\n", tm(fastfg(th,S),3000), tm({fml(mod,th,S); gml(mod,th,S)},3000)))
# end-to-end fit with each
st <- c(1,1,0,0,0,.5,.5,.5,.5,.5)
t_orig <- tm(nlminb(st, function(x) fml(mod,x,S), function(x) gml(mod,x,S)), 40)
t_fast <- tm(nlminb(st, function(x) fastfg(x,S)$f, function(x) fastfg(x,S)$g), 40)
cat(sprintf("== 2. end-to-end nlminb fit: original %.1f ms | vectorized %.1f ms\n", t_orig/1000, t_fast/1000))
cat("\n== 3. dense vs sparse (Matrix) for B = (I - A)^-1, A strictly lower-triangular, ~3 nonzeros/row, microseconds ==\n")
for (p in c(6, 30, 100, 300, 1000)) { set.seed(p); Ad <- matrix(0,p,p); for (i in 2:p) Ad[i, sample(seq_len(i-1), min(3,i-1))] <- .3
  As <- Matrix(Ad, sparse=TRUE); Id <- diag(p); Is <- Diagonal(p); reps <- if (p>=300) 5 else 100
  cat(sprintf("p=%4d dense %9.0f | sparse %9.0f\n", p, tm(solve(Id-Ad), reps), tm(solve(Is-As), reps))) }
cat("\n== 4. parallelism across independent fits (200 fits of the latent model) ==\n")
cat("cores available:", detectCores(), "\n")
job <- function(i) { set.seed(i); nlminb(st, function(x) fastfg(x,S)$f, function(x) fastfg(x,S)$g)$objective }
for (nc in c(1,2,4,8)) { t <- system.time(r <- mclapply(1:200, job, mc.cores=nc))[["elapsed"]]; cat(sprintf("mc.cores=%d: %.2f s\n", nc, t)) }
