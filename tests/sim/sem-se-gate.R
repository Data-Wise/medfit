# SE gate for the native SEM engine (plan S6, G3): native standard errors against OpenMx.
#
# Grid: four unconstrained structures x n in {50, 200, 1000} x 20 seeds. Both engines are
# fitted to the same data; the oracle is OpenMx on S * n / (n - 1) with numObs = n. Reports, per cell,
# the maximum relative SE difference for observed and expected information. Improper fits are
# counted and listed, not dropped. Run from the package root:
#   Rscript tests/sim/sem-se-gate.R
# Results: tests/sim/results/sem-se-gate-<date>.csv

suppressMessages({
  pkgload::load_all(quiet = TRUE)
  library(OpenMx)
})
source("tests/testthat/helper-sem.R")
mxOption(NULL, "Number of Threads", 1)

grid <- expand.grid(structure = names(sem_models()), n = c(50, 200, 1000), seed = 1:20, stringsAsFactors = FALSE)
one <- function(i) {
  g <- grid[i, ]
  mod <- sem_models()[[g$structure]]
  d <- sem_sim(mod, g$n, 1000L * g$seed + g$n)
  smp <- .sem_sample(d, mod$ram)
  row <- data.frame(g, native_ok = FALSE, omx_ok = FALSE, improper = NA_character_, est_gap = NA_real_,
                    rel_obs = NA_real_, rel_exp = NA_real_)
  fit <- tryCatch(suppressWarnings(.sem_optimize(mod$ram, smp, .sem_default_start(mod$ram, smp))), error = function(e) NULL)
  if (is.null(fit)) return(row)
  row$native_ok <- TRUE
  row$improper <- paste(fit$improper, collapse = "; ")
  om <- tryCatch(sem_openmx(mod, smp), error = function(e) NULL)
  if (is.null(om) || om$output$status$code > 1) return(row)
  row$omx_ok <- TRUE
  sm <- summary(om)$parameters
  lbl <- as.integer(sub("^p", "", sm$name))
  est_o <- stats::setNames(sm$Estimate, mod$ram$par_names[lbl])[names(fit$theta)]
  se_o <- stats::setNames(sm[["Std.Error"]], mod$ram$par_names[lbl])[names(fit$theta)]
  row$est_gap <- max(abs(est_o - fit$theta))
  se_obs <- suppressWarnings(sqrt(diag(.sem_vcov(fit$theta, mod$ram, smp, "observed"))))
  se_exp <- suppressWarnings(sqrt(diag(.sem_vcov(fit$theta, mod$ram, smp, "expected"))))
  row$rel_obs <- max(abs(se_obs / se_o - 1))
  row$rel_exp <- max(abs(se_exp / se_o - 1))
  row
}
res <- do.call(rbind, parallel::mclapply(seq_len(nrow(grid)), one, mc.cores = max(1L, parallel::detectCores() - 1L)))

proper <- res$native_ok & res$omx_ok & !nzchar(res$improper)
cell <- function(df) {
  data.frame(runs = nrow(df), improper = sum(nzchar(df$improper) & !is.na(df$improper)), failed = sum(!df$native_ok | !df$omx_ok),
             max_rel_obs = max(df$rel_obs, na.rm = TRUE), max_rel_exp = max(df$rel_exp, na.rm = TRUE))
}
cat("Per cell (all runs with both engines fitted; improper counted):\n")
print(do.call(rbind, lapply(split(res, list(res$structure, res$n), drop = TRUE), cell)), digits = 3)
worst <- max(res$rel_obs[proper], na.rm = TRUE)
cat(sprintf("\nProper cells: %d of %d runs; observed-information max relative SE difference %.3e; expected %.3e\n",
            sum(proper), nrow(res), worst, max(res$rel_exp[proper], na.rm = TRUE)))
cat("Improper runs (listed, not dropped):\n")
print(res[!is.na(res$improper) & nzchar(res$improper), c("structure", "n", "seed", "improper", "rel_obs")])
cat(sprintf("\nFreeze rule (G3): %s\n", if (worst <= 3.3e-4) "freeze 1e-3 (3x headroom)" else if (worst <= 1e-3) "keep 1e-3, record narrow headroom" else "ABOVE 1e-3: K10 applies, default reverts to expected information"))
ver <- sapply(c("OpenMx", "lavaan", "nloptr", "MASS"), function(p) as.character(utils::packageVersion(p)))
res$versions <- paste(names(ver), ver, collapse = "; ")
dir.create("tests/sim/results", showWarnings = FALSE)
utils::write.csv(res, sprintf("tests/sim/results/sem-se-gate-%s.csv", Sys.Date()), row.names = FALSE)
