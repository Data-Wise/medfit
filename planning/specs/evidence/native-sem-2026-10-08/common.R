# common.R: tiny RAM engine used by every script here (model builder, implied covariance, ML discrepancy, analytic gradient).
# Provenance: copied from missingmed dev/spike-ram-nloptr-vs-openmx.R (author: Davood Tofighi, 2026-10-08). Exploratory code, not package code.
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
