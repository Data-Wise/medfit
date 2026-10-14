suppressMessages(devtools::load_all(quiet=TRUE))
one <- function(n, seed, xdist) {
  set.seed(seed)
  if (xdist == "norm") { x <- rnorm(n); w <- rnorm(n) } else { x <- rexp(n) - 1; w <- rexp(n) - 1 }
  m <- .7*x + rnorm(n); p <- x*w
  y <- .4*m + .3*x + .3*w + .2*p + rnorm(n)
  d <- data.frame(x, w, m, y, p)
  f <- tryCatch(fit_sem("m ~ x\ny ~ m + x + w + p", d), error=function(e) NULL)
  if (is.null(f)) return(c(NA, NA))
  g <- as.data.frame(glance(f)); c(g$chisq, g$df)
}
for (xd in c("norm", "exp")) {
  r <- t(vapply(1:1000, function(i) one(500, i, xd), numeric(2)))
  p <- pchisq(r[,1], r[1,2], lower.tail=FALSE)
  cat(sprintf("factors %s: df=%g, rejection at .05 = %.3f, at .01 = %.3f, mean chisq = %.2f (df %g), reps ok = %d\n",
    xd, r[1,2], mean(p<.05, na.rm=TRUE), mean(p<.01, na.rm=TRUE), mean(r[,1], na.rm=TRUE), r[1,2], sum(!is.na(r[,1]))))
}
