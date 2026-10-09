# Spike (2026-10-08): native RAM engine + nloptr SLSQP vs OpenMx (the parity oracle, per the author).
# See docs/specs/PLAN-native-sem-engine-nloptr-2026-10-08.md. Needs OpenMx, nloptr, numDeriv.

#!/usr/bin/env Rscript
# Spike (2026-10-08): native RAM engine + nloptr SLSQP vs lavaan. Exploratory; see
# docs/specs/PLAN-native-sem-engine-nloptr-2026-10-08.md. Needs lavaan, nloptr, numDeriv.
suppressMessages({library(OpenMx);library(nloptr)})
# --- tiny RAM engine ---
mk <- function(vars, obs, paths, covs, fixed_cov = NULL){ # paths: list(to,from,lbl,val); covs same
  nv <- length(vars); ix <- function(v) match(v, vars)
  pr <- rbind(data.frame(m="A",r=ix(paths$to),c=ix(paths$from),lbl=paths$lbl,val=paths$val,stringsAsFactors=FALSE),
              data.frame(m="S",r=ix(covs$a),c=ix(covs$b),lbl=covs$lbl,val=covs$val,stringsAsFactors=FALSE))
  pr$free <- is.na(pr$val); pr$k <- NA; pr$k[pr$free] <- seq_len(sum(pr$free))
  list(vars=vars,obs=obs,nv=nv,pr=pr,F=diag(nv)[ix(obs),,drop=FALSE])}
mats <- function(mod,th){ A<-S<-matrix(0,mod$nv,mod$nv); for(i in seq_len(nrow(mod$pr))){p<-mod$pr[i,]; v<-if(p$free) th[p$k] else p$val
    if(p$m=="A") A[p$r,p$c]<-v else {S[p$r,p$c]<-v; S[p$c,p$r]<-v}}; list(A=A,S=S)}
sigma <- function(mod,th){m<-mats(mod,th);B<-solve(diag(mod$nv)-m$A);mod$F%*%B%*%m$S%*%t(B)%*%t(mod$F)}
fml <- function(mod,th,Sm){Sg<-sigma(mod,th);ev<-min(eigen(Sg,symmetric=TRUE,only.values=TRUE)$values);if(ev<=1e-10)return(1e10)
  log(det(Sg))+sum(diag(Sm%*%solve(Sg)))-log(det(Sm))-nrow(Sm)}
gml <- function(mod,th,Sm){m<-mats(mod,th);B<-solve(diag(mod$nv)-m$A);Sg<-mod$F%*%B%*%m$S%*%t(B)%*%t(mod$F);Si<-solve(Sg)
  W<-Si-Si%*%Sm%*%Si;P<-t(mod$F)%*%W%*%mod$F;gA<-2*t(B%*%m$S%*%t(B)%*%P%*%B);gS<-t(B)%*%P%*%B
  g<-numeric(length(th));for(i in seq_len(nrow(mod$pr))){p<-mod$pr[i,];if(!p$free)next
    g[p$k]<-g[p$k]+if(p$m=="A") gA[p$r,p$c] else if(p$r==p$c) gS[p$r,p$c] else 2*gS[p$r,p$c]};g}
fit <- function(mod,Sm,n,start,lb=NULL,eq=NULL,alg="NLOPT_LD_SLSQP"){
  q<-length(start); o<-nloptr(start,function(x)fml(mod,x,Sm),function(x)gml(mod,x,Sm),lb=if(is.null(lb))rep(-Inf,q) else lb,
    eval_g_eq=if(!is.null(eq))eq$g,eval_jac_g_eq=if(!is.null(eq))eq$j,opts=list(algorithm=alg,xtol_rel=1e-12,ftol_rel=1e-15,maxeval=2000))
  th<-o$solution; J<-sapply(seq_len(q),function(k){h<-1e-6;e<-replace(numeric(q),k,h);as.vector(sigma(mod,th+e)-sigma(mod,th-e))/(2*h)})
  Si<-solve(sigma(mod,th)); I<-(n/2)*t(J)%*%kronecker(Si,Si)%*%J; list(th=th,se=sqrt(diag(solve(I))),fmin=o$objective,status=o$status,iter=o$iterations)}
set.seed(1);n<-400;X<-rnorm(n);C<-rnorm(n);M<-.45*X+.3*C+rnorm(n);Y<-.4*M+.2*X+.3*C+rnorm(n);d1<-data.frame(X,M,Y,C)
S1<-cov(d1)*(n-1)/n; ov<-c("X","M","Y","C")
vars1<-c("X","C","M","Y")
mod1<-mk(vars1,ov,list(to=c("M","M","Y","Y","Y"),from=c("X","C","M","X","C"),lbl=c("a","m_c","b","cp","y_c"),val=rep(NA,5)),
 list(a=c("X","C","C","M","Y"),b=c("X","C","X","M","Y"),lbl=c("vx","vc","cxc","vm","vy"),val=c(S1["X","X"],S1["C","C"],S1["X","C"],NA,NA)))
f1<-fit(mod1,S1[ov,ov],n,start=c(0,0,0,0,0,.5,.5))
omx<-mxModel("p",type="RAM",manifestVars=ov,
 mxPath("X",to="M",values=0,labels="a"),mxPath("C",to="M",values=0,labels="mc"),mxPath("M",to="Y",values=0,labels="b"),
 mxPath("X",to="Y",values=0,labels="cp"),mxPath("C",to="Y",values=0,labels="yc"),
 mxPath(c("M","Y"),arrows=2,values=.5,labels=c("vm","vy")),mxPath(c("X","C"),arrows=2,free=FALSE,values=diag(S1)[c("X","C")]),
 mxPath("X",to="C",arrows=2,free=FALSE,values=S1["X","C"]),mxData(S1[ov,ov]*n/(n-1),type="cov",numObs=n))
r<-mxRun(omx,silent=TRUE,suppressWarnings=TRUE); ps<-summary(r)$parameters
cat("== OpenMx (",mxOption(NULL,"Default optimizer"),") vs native: observed path model ==\n")
nm<-c("a","mc","b","cp","yc","vm","vy"); k<-match(nm,ps$name)
d<-data.frame(par=nm,omx=ps$Estimate[k],own=f1$th,d_est=ps$Estimate[k]-f1$th,omx_se=ps$Std.Error[k],own_se=f1$se,d_se=ps$Std.Error[k]-f1$se); d[-1]<-round(d[-1],6); print(d)
cat("OpenMx status code",r$output$status$code,"| nloptr status",f1$status,"\n")
# latent model
set.seed(2);n2<-300;X<-rnorm(n2);Mm<-.4*X+rnorm(n2);d2<-data.frame(X,m1=Mm+rnorm(n2,0,.5),m2=.8*Mm+rnorm(n2),m3=.7*Mm+rnorm(n2));d2$Y<-.4*Mm+.2*X+rnorm(n2)
ov2<-c("X","m1","m2","m3","Y");S2<-cov(d2[,ov2])*(n2-1)/n2
mod2<-mk(c("X","M","m1","m2","m3","Y"),ov2,list(to=c("m1","m2","m3","M","Y","Y"),from=c("M","M","M","X","M","X"),lbl=c("l1","l2","l3","g","b","cp"),val=c(1,NA,NA,NA,NA,NA)),
 list(a=c("X","m1","m2","m3","M","Y"),b=c("X","m1","m2","m3","M","Y"),lbl=c("vx","t1","t2","t3","vM","vY"),val=c(S2["X","X"],NA,NA,NA,NA,NA)))
f2<-fit(mod2,S2,n2,start=c(1,1,0,0,0,.5,.5,.5,.5,.5))
o2<-mxModel("l",type="RAM",manifestVars=ov2,latentVars="M",
 mxPath("M",to=c("m1","m2","m3"),free=c(FALSE,TRUE,TRUE),values=c(1,1,1),labels=c("l1","l2","l3")),mxPath("X",to="M",values=0,labels="g"),
 mxPath("M",to="Y",values=0,labels="b"),mxPath("X",to="Y",values=0,labels="cp"),
 mxPath(c("m1","m2","m3","M","Y"),arrows=2,values=.5,labels=c("t1","t2","t3","vM","vY")),mxPath("X",arrows=2,free=FALSE,values=S2["X","X"]),mxData(S2*n2/(n2-1),type="cov",numObs=n2))
r2<-mxRun(o2,silent=TRUE,suppressWarnings=TRUE);p2<-summary(r2)$parameters
nm2<-c("l2","l3","g","b","cp","t1","t2","t3","vM","vY");k2<-match(nm2,p2$name)
cat("== latent mediator ==\nmax |d_est|",max(abs(p2$Estimate[k2]-f2$th)),"max |d_se|",max(abs(p2$Std.Error[k2]-f2$se)),"| OpenMx code",r2$output$status$code,"\n")
