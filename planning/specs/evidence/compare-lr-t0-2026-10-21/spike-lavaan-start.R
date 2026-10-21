suppressMessages({ pkgload::load_all(quiet = TRUE); library(lavaan) })
base <- "M ~ a*X\nY ~ b*M + cp*X"
set.seed(2); n <- 100; d <- data.frame(X = rnorm(n), M = rnorm(n)); d$Y <- 0.3 * d$X + rnorm(n)
pt <- lavaanify(paste0(base, "\na*b == 0"), fixed.x = FALSE, meanstructure = FALSE, auto.var = TRUE)
sv <- lavaan(pt, data = d, fixed.x = FALSE, meanstructure = FALSE, do.fit = FALSE)
p0 <- parTable(sv); p0$start[p0$label %in% c("a", "b")] <- 0
f0 <- lavaan(model = p0, data = d, fixed.x = FALSE, meanstructure = FALSE, start = p0, do.fit = FALSE)
cat("start via start=pt:", parTable(f0)$start[parTable(f0)$label %in% c("a","b")], "\n")
f <- suppressWarnings(lavaan(model = p0, data = d, fixed.x = FALSE, meanstructure = FALSE, start = p0))
cat("converged:", lavInspect(f, "converged"), " chisq:", fitMeasures(f, "chisq"), "\n")
