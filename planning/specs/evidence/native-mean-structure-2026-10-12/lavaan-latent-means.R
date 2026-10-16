# Which `~1` rows does lavaan fix or free for latent variables under meanstructure = TRUE (single group)?
# Gates 0.11.0 (latent means) in the native engine. Probe only: no medfit code is used.
suppressMessages(library(lavaan)); cat("lavaan", as.character(packageVersion("lavaan")), "\n")
set.seed(1); n <- 400
x <- rnorm(n); M <- .5*x + rnorm(n); Y <- .4*M + .2*x + rnorm(n)
d <- data.frame(x, y1 = Y + rnorm(n, 0, .5), y2 = .8*Y + 1 + rnorm(n, 0, .5), y3 = 1.2*Y - 1 + rnorm(n, 0, .5),
                m1 = M + rnorm(n, 0, .5), m2 = .9*M + 2 + rnorm(n, 0, .5), m3 = 1.1*M + rnorm(n, 0, .5))
show <- function(tag, model, ...) {
  f <- tryCatch(sem(model, d, ...), error = function(e) e, warning = function(w) w)
  cat("\n==", tag, "==\n")
  if (inherits(f, "condition")) { cat(class(f)[1], ":", conditionMessage(f), "\n"); return(invisible()) }
  pt <- parTable(f); r <- pt[pt$op == "~1", c("lhs", "free", "ustart", "est")]
  r$status <- ifelse(r$free == 0, "FIXED", "free"); print(r[, c("lhs", "status", "est")], row.names = FALSE)
  cat("df =", fitMeasures(f, "df"), " converged =", lavInspect(f, "converged"), "\n")
}
base <- "M =~ m1 + m2 + m3\nY =~ y1 + y2 + y3\nM ~ x\nY ~ M + x"
show("A: meanstructure = TRUE, no ~1 written", base, meanstructure = TRUE)
show("B: explicit latent mean M ~ 1 (free), indicator intercepts free", paste0(base, "\nM ~ 1"), meanstructure = TRUE)
show("C: M ~ 1 free, first indicator intercept fixed 0", paste0(base, "\nM ~ 1\nm1 ~ 0*1"), meanstructure = TRUE)
show("D: M ~ 0*1 (latent mean fixed 0 explicitly)", paste0(base, "\nM ~ 0*1"), meanstructure = TRUE)
show("E: ~1 written, meanstructure not requested (does ~1 switch it on?)", paste0(base, "\nm1 ~ 1"))
show("F: only a latent intercept written, no meanstructure arg", paste0(base, "\nM ~ 1"))
show("G: meanstructure = TRUE, std.lv = TRUE", base, meanstructure = TRUE, std.lv = TRUE)
show("H: meanstructure = TRUE, auto.fix.first = FALSE and M variance fixed", paste0("M =~ NA*m1 + m2 + m3\nM ~~ 1*M\nY =~ y1 + y2 + y3\nM ~ x\nY ~ M + x"), meanstructure = TRUE)
