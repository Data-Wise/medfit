# Does an endogenous product's omitted residual-product covariance leak through correlated equation
# residuals into an equation that has no product? x uncentered (mean 2) triggers the misfit of
# `m1 ~ x` vs the product p = x * m1. Compare joint ML to equation-wise OLS (the true values are
# a1 = .7, a2 = .5, b1 = .4, b2 = .3, bp = .2).
#   same : m1 and m2 have the same regressor set (SUR = OLS even with correlated residuals)
#   diff : m1 ~ x + cv, m2 ~ x + c2 (NON-NESTED regressors; with correlated residuals GLS differs from OLS)
suppressMessages(devtools::load_all(quiet=TRUE))
set.seed(17); n <- 20000
x <- rnorm(n, 2); cv <- rnorm(n); c2 <- rnorm(n); e <- MASS::mvrnorm(n, c(0, 0), matrix(c(1, .5, .5, 1), 2))
m1 <- .7*x + .5*cv + e[,1]; m2 <- .5*x + .5*c2 + e[,2]; p <- x*m1
y <- .4*m1 + .3*m2 + .3*x + .2*p + rnorm(n)
d <- data.frame(x, cv, c2, m1, m2, y, p)
for (design in c("same", "diff")) {
  m1f <- if (design == "same") "m1 ~ x + cv\nm2 ~ x + cv" else "m1 ~ x + cv\nm2 ~ x + c2"
  l1 <- if (design == "same") m1 ~ x + cv else m1 ~ x + cv
  l2 <- if (design == "same") m2 ~ x + cv else m2 ~ x + c2
  ols <- c(a1 = coef(lm(l1, d))[["x"]], a2 = coef(lm(l2, d))[["x"]], b1 = coef(lm(y ~ m1 + m2 + x + p, d))[["m1"]],
           b2 = coef(lm(y ~ m1 + m2 + x + p, d))[["m2"]], bp = coef(lm(y ~ m1 + m2 + x + p, d))[["p"]])
  for (cvf in c(FALSE, TRUE)) {
    f <- fit_sem(paste0(m1f, "\ny ~ m1 + m2 + x + p", if (cvf) "\nm1 ~~ m2" else ""), d); cf <- coef(f)
    sem <- c(a1 = cf[["m1~x"]], a2 = cf[["m2~x"]], b1 = cf[["y~m1"]], b2 = cf[["y~m2"]], bp = cf[["y~p"]])
    cat(sprintf("design %-4s, m1 ~~ m2 free = %-5s | max |SEM - OLS| = %.5f | max |SEM - truth| = %.4f\n",
                design, cvf, max(abs(sem - ols)), max(abs(sem - c(.7, .5, .4, .3, .2)))))
    if (max(abs(sem - ols)) > 1e-4) print(round(sem - ols, 5))
  }
}
