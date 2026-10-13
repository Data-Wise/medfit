# Companion to exo-product-null.R: three configurations of the exogenous block for the same true model.
#   free      : no ~~ statement (engine completes variances and covariances, all free)
#   fixvar    : factor variances fixed at their true value (1), the covariances written out so they stay free
#   dropcov   : the user writes only `x ~~ 1*x`, `w ~~ 1*w`; R/sem-model.R:80-88 then leaves x, w, p out of the
#               pairing, so the covariances among x, w, p are silently fixed at 0 (true values are 0)
# x, w ~ N(0,1) or centered Exp(1) (variance 1, kurtosis 9). Every restriction is TRUE; any rejection above
# the nominal rate is a miscalibrated normal-theory test.
suppressMessages(devtools::load_all(quiet=TRUE))
mods <- c(
  free    = "m ~ x\ny ~ m + x + w + p",
  fixvar  = "m ~ x\ny ~ m + x + w + p\nx ~~ 1*x\nw ~~ 1*w\np ~~ p\nx ~~ w\nx ~~ p\nw ~~ p",
  dropcov = "m ~ x\ny ~ m + x + w + p\nx ~~ 1*x\nw ~~ 1*w"
)
one <- function(n, seed, xdist, mod) {
  set.seed(seed)
  if (xdist == "norm") { x <- rnorm(n); w <- rnorm(n) } else { x <- rexp(n) - 1; w <- rexp(n) - 1 }
  m <- .7*x + rnorm(n); p <- x*w
  y <- .4*m + .3*x + .3*w + .2*p + rnorm(n)
  f <- tryCatch(fit_sem(mod, data.frame(x, w, m, y, p)), error=function(e) NULL)
  if (is.null(f)) return(c(NA, NA))
  g <- as.data.frame(glance(f)); c(g$chisq, g$df)
}
for (xd in c("norm", "exp")) for (nm in names(mods)) {
  r <- t(vapply(1:1000, function(i) one(500, i, xd, mods[[nm]]), numeric(2)))
  p <- pchisq(r[,1], r[1,2], lower.tail=FALSE)
  cat(sprintf("factors %-4s %-8s: df=%g, reject .05 = %.3f, .01 = %.3f, mean chisq = %.2f, ok = %d\n",
    xd, nm, r[1,2], mean(p<.05, na.rm=TRUE), mean(p<.01, na.rm=TRUE), mean(r[,1], na.rm=TRUE), sum(!is.na(r[,1]))))
}
