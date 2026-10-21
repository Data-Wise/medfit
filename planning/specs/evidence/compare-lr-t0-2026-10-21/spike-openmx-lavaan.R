suppressMessages({ pkgload::load_all(quiet = TRUE); library(OpenMx); library(lavaan) })
source("tests/testthat/helper-sem.R"); mxOption(NULL, "Number of Threads", 1)
base <- "M ~ a*X\nY ~ b*M + cp*X"
text0 <- paste0(base, "\nM ~~ Vm*M\nY ~~ Vy*Y")
cat("OpenMx", as.character(packageVersion("OpenMx")), "| lavaan", as.character(packageVersion("lavaan")), "\n")
vars <- c("X", "M", "Y")
a_rows <- sem_rows(list("M", "X", "a"), list("Y", "M", "b"), list("Y", "X", "cp"))
s_rows <- sem_rows(list("X", "X"), list("M", "M", "Vm"), list("Y", "Y", "Vy"))
ram0 <- .sem_ram(vars, vars, a_rows, s_rows)
mod0 <- list(ram = ram0, a = a_rows, s = s_rows)
setup <- function(text, d) list(ram = ram0, smp = .sem_sample(d[, vars], ram0), mod = mod0)
one <- function(seed) {
  set.seed(seed); n <- 100
  X <- rnorm(n); M <- rnorm(n); Y <- 0.3 * X + rnorm(n)   # joint null: a = b = 0
  d <- data.frame(X = X, M = M, Y = Y)
  fit <- suppressWarnings(fit_sem(text0, d))
  mb <- suppressWarnings(mbco_sem(fit, "a", "b"))
  lr_m <- min(mb$tests$diff_ll)
  # lavaan: saturated full model, so the statistic of the null is the LR
  lv <- function(zero) {
    pt <- lavaanify(paste0(base, "\na*b == 0"), fixed.x = FALSE, meanstructure = FALSE, auto.var = TRUE)
    pt$start <- NA
    if (zero) pt$start[pt$label %in% c("a", "b")] <- 0
    f <- tryCatch(suppressWarnings(lavaan(pt, data = d, fixed.x = FALSE, meanstructure = FALSE,
                                          estimator = "ML")), error = function(e) NULL)
    if (is.null(f) || !lavInspect(f, "converged")) return(NA_real_)
    unname(fitMeasures(f, "chisq"))
  }
  # OpenMx on the same RAM, constraint p_a * p_b == 0
  s <- setup(text0, d); pn <- s$ram$par_names; if (seed == 1) { cat("par_names:", pn, "\n") }
  ia <- match("a", pn); ib <- match("b", pn)
  full <- tryCatch(sem_openmx(s$mod, s$smp), error = function(e) NULL)
  omx <- function(zero) {
    st <- .sem_default_start(s$ram, s$smp); if (zero) st[c(ia, ib)] <- 0
    m <- tryCatch(suppressWarnings(sem_openmx(s$mod, s$smp, start = st,
                  constraints = sprintf("p%d * p%d == 0", ia, ib))), error = function(e) NULL)
    if (is.null(m) || is.null(full)) return(c(lr = NA_real_, a = NA_real_, b = NA_real_))
    est <- coef(m)
    c(lr = m$output$fit - full$output$fit, a = unname(est[paste0("p", ia)]), b = unname(est[paste0("p", ib)]))
  }
  od <- omx(FALSE); oz <- omx(TRUE)
  data.frame(seed = seed, medfit = lr_m, lv_def = lv(FALSE), lv_zero = lv(TRUE),
             omx_def = od[["lr"]], omx_zero = oz[["lr"]],
             omx_zero_resid = abs(oz[["a"]] * oz[["b"]]), omx_def_resid = abs(od[["a"]] * od[["b"]]))
}
res <- do.call(rbind, lapply(1:60, one))
tol <- 1e-4 * pmax(1, res$medfit)
cat("\nrows:", nrow(res), "\n")
cat("lavaan default : LR above medfit (beyond tol):", sum(res$lv_def  > res$medfit + tol, na.rm = TRUE), "of", sum(!is.na(res$lv_def)), "\n")
cat("lavaan zero    : LR above medfit (beyond tol):", sum(res$lv_zero > res$medfit + tol, na.rm = TRUE), "of", sum(!is.na(res$lv_zero)), "\n")
cat("OpenMx default : LR below medfit (beyond tol):", sum(res$omx_def  < res$medfit - tol, na.rm = TRUE), "of", sum(!is.na(res$omx_def)), "| LR == 0 while medfit > tol:", sum(abs(res$omx_def) < 1e-8 & res$medfit > tol, na.rm = TRUE), "| constraint violated (>1e-4):", sum(res$omx_def_resid > 1e-4, na.rm = TRUE), "\n")
cat("OpenMx zero    : LR below medfit (beyond tol):", sum(res$omx_zero < res$medfit - tol, na.rm = TRUE), "of", sum(!is.na(res$omx_zero)), "| LR == 0 while medfit > tol:", sum(abs(res$omx_zero) < 1e-8 & res$medfit > tol, na.rm = TRUE), "| constraint violated (>1e-4):", sum(res$omx_zero_resid > 1e-4, na.rm = TRUE), "\n")
cat("medfit LR range:", format(range(res$medfit), digits = 4), " rows with medfit LR > 1e-4:", sum(res$medfit > 1e-4), "\n")
print(utils::head(res[order(-(res$omx_zero < res$medfit - tol)), ], 5))
