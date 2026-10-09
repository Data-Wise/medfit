suppressMessages(library(nloptr)); invisible(capture.output(source("05-speed.R")))
ref <- nlminb(st, function(x) fastfg(x,S)$f, function(x) fastfg(x,S)$g, control=list(rel.tol=1e-14))$par
f <- function(x) fastfg(x,S)$f; g <- function(x) fastfg(x,S)$g
for (alg in c("NLOPT_LD_SLSQP","NLOPT_LD_LBFGS")) { o <- NULL
  t <- tm(o <- nloptr(st,f,g,opts=list(algorithm=alg,xtol_rel=1e-10,ftol_rel=1e-14,maxeval=2000)), 40)
  cat(sprintf("%-15s %.1f ms/fit | evals %d | max|th - nlminb| %.1e\n", alg, t/1000, o$iterations, max(abs(o$solution-ref)))) }
cat(sprintf("%-15s %.1f ms/fit\n", "nlminb", tm(nlminb(st,f,g),40)/1000))
