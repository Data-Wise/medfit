# R0: what does lavaan 0.7.2 do with an explicit (co)variance statement on an exogenous variable under fixed.x = TRUE?
suppressMessages(library(lavaan))
set.seed(1)
n <- 300
d <- data.frame(x = rnorm(n), c1 = rnorm(n))
d$m <- 0.5 * d$x + 0.3 * d$c1 + rnorm(n)
d$y <- 0.4 * d$m + 0.2 * d$x + 0.1 * d$c1 + rnorm(n)
base <- "m ~ a*x + c1\ny ~ b*m + cp*x + c1\n"
show <- function(label, syn, ...) {
  fit <- tryCatch(withCallingHandlers(sem(syn, d, ...), warning = function(w) {
    cat("  WARNING:", conditionMessage(w), "\n"); invokeRestart("muffleWarning")
  }), error = function(e) {
    cat(label, "-> ERROR:", conditionMessage(e), "\n"); NULL })
  if (is.null(fit)) return(invisible())
  pt <- parTable(fit)
  rows <- pt[pt$lhs == "x" & pt$op == "~~" & pt$rhs == "x", c("lhs", "op", "rhs", "free", "est")]
  cat(label, "-> npar", fitMeasures(fit, "npar"), "df", fitMeasures(fit, "df"), "\n"); print(rows)
}
show("auto, fixed.x = TRUE", base, fixed.x = TRUE)
show("explicit x ~~ x, fixed.x = TRUE", paste0(base, "x ~~ x\n"), fixed.x = TRUE)
show("explicit x ~~ v*x, fixed.x = TRUE", paste0(base, "x ~~ v*x\n"), fixed.x = TRUE)
show("explicit x ~~ c1, fixed.x = TRUE", paste0(base, "x ~~ c1\n"), fixed.x = TRUE)
show("explicit x ~ 1, fixed.x = TRUE, meanstructure", paste0(base, "x ~ 1\n"), fixed.x = TRUE, meanstructure = TRUE)
