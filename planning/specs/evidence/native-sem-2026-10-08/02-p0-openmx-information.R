suppressMessages(library(numDeriv))
e <- new.env(); invisible(capture.output(sys.source("00-spike-ram-nloptr-vs-openmx.R", envir = e)))
with(e, {
  report <- function(lab, mod, Sm, n, f, om, nm, p) {
    th <- f$th; q <- length(th)
    H <- numDeriv::hessian(function(x) fml(mod, x, Sm), th)          # Hessian of F_ML (divisor-n scale)
    Jm <- sapply(seq_len(q), function(k){h<-1e-6;ee<-replace(numeric(q),k,h);as.vector(sigma(mod,th+ee)-sigma(mod,th-ee))/(2*h)})
    Si <- solve(sigma(mod, th)); E <- t(Jm) %*% kronecker(Si, Si) %*% Jm   # expected Hessian of F (= 2 * info per obs)
    k <- match(nm, p$name); se_omx <- p$Std.Error[k]
    se <- function(Hf, s) sqrt(diag(solve(s * Hf)))
    cat("\n==", lab, "==\n")
    cat("max|SE diff| vs OpenMx:\n")
    cat(sprintf("  expected, n/2      : %.2e\n", max(abs(se(E/2, n) - se_omx))))
    cat(sprintf("  observed, n/2      : %.2e\n", max(abs(se(H/2, n) - se_omx))))
    cat(sprintf("  observed, (n-1)/2  : %.2e\n", max(abs(se(H/2, n-1) - se_omx))))
    cat(sprintf("  expected, (n-1)/2  : %.2e\n", max(abs(se(E/2, n-1) - se_omx))))
    Ho <- om$output$hessian; if (!is.null(dimnames(Ho))) Ho <- Ho[nm, nm]   # OpenMx Hessian of -2LL
    cat(sprintf("  OpenMx hessian vs n*H_obs     : max rel diff %.2e\n", max(abs(Ho/(n*H) - 1))))
    cat(sprintf("  OpenMx hessian vs (n-1)*H_obs : max rel diff %.2e\n", max(abs(Ho/((n-1)*H) - 1))))
    cat(sprintf("  OpenMx hessian vs n*H_exp     : max rel diff %.2e\n", max(abs(Ho/(n*E) - 1))))
    cat(sprintf("  OpenMx hessian vs (n-1)*H_exp : max rel diff %.2e\n", max(abs(Ho/((n-1)*E) - 1))))
    cat(sprintf("  OpenMx -2LL (minus sat.) vs n*F_ML, (n-1)*F_ML : %.6f | %.6f | %.6f\n", om$output$fit - 0, n*f$fmin, (n-1)*f$fmin))
  }
  report("latent mediator (n=300)", mod2, S2, n2, f2, r2, nm2, p2)
  report("observed path model (n=400)", mod1, S1[ov,ov], n, f1, r, nm, ps)
})

e <- new.env(); invisible(capture.output(sys.source("00-spike-ram-nloptr-vs-openmx.R", envir = e)))
with(e, {
  k <- match(nm, ps$name); cat("observed model: max|d_est| (S*n/(n-1) input):", signif(max(abs(ps$Estimate[k]-f1$th)),3), "\n")
  # wrong convention: feed the divisor-n matrix directly
  o_bad <- omx; o_bad <- mxModel(o_bad, mxData(S1[ov,ov], type="cov", numObs=n))
  rb <- mxRun(o_bad, silent=TRUE, suppressWarnings=TRUE); pb <- summary(rb)$parameters
  cat("divisor-n input, variance ratio OpenMx/native (vm, vy):", signif(pb$Estimate[match(c("vm","vy"),pb$name)]/f1$th[6:7],7), " expected (n-1)/n =", (n-1)/n, "\n")
  cat("latent: max|d_est| (S*n/(n-1) input):", signif(max(abs(p2$Estimate[match(nm2,p2$name)]-f2$th)),3), "\n")
})
