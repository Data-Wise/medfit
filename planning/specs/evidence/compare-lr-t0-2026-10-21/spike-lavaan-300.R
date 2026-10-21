suppressMessages({ pkgload::load_all(quiet = TRUE); library(lavaan) })
base <- "M ~ a*X\nY ~ b*M + cp*X"
chk <- function(seed, zero) {
  set.seed(seed); n <- 100; d <- data.frame(X = rnorm(n), M = rnorm(n)); d$Y <- 0.3 * d$X + rnorm(n)
  pt <- lavaanify(paste0(base, "\na*b == 0"), fixed.x = FALSE, meanstructure = FALSE, auto.var = TRUE)
  pt$start <- NA; if (zero) pt$start[pt$label %in% c("a", "b")] <- 0
  f0 <- lavaan(pt, data = d, fixed.x = FALSE, meanstructure = FALSE, do.fit = FALSE)
  st <- parTable(f0)$start[parTable(f0)$label %in% c("a", "b")]
  f <- suppressWarnings(lavaan(pt, data = d, fixed.x = FALSE, meanstructure = FALSE))
  fit_m <- suppressWarnings(fit_sem(paste0(base, "\nM ~~ Vm*M\nY ~~ Vy*Y"), d))
  mb <- suppressWarnings(mbco_sem(fit_m, "a", "b"))
  c(start_a = st[1], start_b = st[2], conv = lavInspect(f, "converged"), lv = unname(fitMeasures(f, "chisq")), medfit = min(mb$tests$diff_ll))
}
for (z in c(FALSE, TRUE)) {
  r <- t(sapply(1:300, chk, zero = z))
  tol <- 1e-4 * pmax(1, r[, "medfit"])
  cat(if (z) "zero" else "default", "start applied (a,b):", unique(round(r[, 1:2], 3))[1, ], "| converged", sum(r[, "conv"] == 1), "/300 | lavaan above medfit beyond tol:", sum(r[, "lv"] > r[, "medfit"] + tol, na.rm = TRUE), "| below:", sum(r[, "lv"] < r[, "medfit"] - tol, na.rm = TRUE), "\n")
}
