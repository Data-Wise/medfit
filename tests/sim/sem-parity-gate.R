# J2 parity gate for the native SEM engine (plan S19, S20): native estimates and standard errors against OpenMx.
#
# Cells: the four K10 structures, `a == b` (shared label), `a == 0` (fixed value) and an active lower bound
# (the Heywood latent model with `lower(0)` on `m1 ~~ m1`), each at n in {50, 200, 1000} x 20 seeds, plus
# RMediation's memory_exp (one dataset, n = 369) with its MBCO known answers. The oracle is OpenMx on
# S * n / (n - 1) with numObs = n. Estimates are compared in absolute terms (rule 1e-6), standard errors
# relatively (frozen K10 tolerance 1e-3); the SE of a pinned parameter is not compared, and the SEs under an
# active bound are compared with the OpenMx model that fixes the variance at 0. Improper and failed runs
# are counted and listed, not dropped. Run from the package root:
#   Rscript tests/sim/sem-parity-gate.R
# Results: tests/sim/results/sem-parity-gate-<date>.csv and .out

suppressMessages({
  pkgload::load_all(quiet = TRUE)
  library(OpenMx)
})
source("tests/testthat/helper-sem.R")
mxOption(NULL, "Number of Threads", 1)

syntax <- c(
  observed = "M ~ X + C\nY ~ M + X + C",
  latent = "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X",
  parallel = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2",
  serial = "M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + M1 + X",
  equal = "M ~ a*X\nY ~ b*M + cp*X\na == b",
  zero = "M ~ a*X\nY ~ b*M + cp*X\na == 0",
  bounded = "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X\nm1 ~~ lower(0)*m1"
)
oracle_model <- function(cell) {
  switch(cell, equal = sem_model_equal_paths(), zero = sem_model_zero_path(), bounded = sem_model_heywood(),
         sem_models()[[cell]])
}
omx_table <- function(om, mod) {
  sm <- summary(om)$parameters
  nm <- mod$ram$par_names[as.integer(sub("^p", "", sm$name))]
  list(est = stats::setNames(sm$Estimate, nm), se = stats::setNames(sm[["Std.Error"]], nm))
}
# native name -> oracle name, and the names whose SE is not compared
cell_map <- function(cell, native) {
  m <- switch(cell,
    equal = c(a = "a", b = "a", cp = "Y ~ X"),
    zero = c(b = "Y ~ M", cp = "Y ~ X"),
    character()
  )
  out <- stats::setNames(native, native)
  out[names(m)] <- m
  out
}

grid <- expand.grid(cell = names(syntax), n = c(50, 200, 1000), seed = 1:20, stringsAsFactors = FALSE)
one <- function(i) {
  g <- grid[i, ]
  mod <- oracle_model(g$cell)
  d <- sem_sim(mod, g$n, 1000L * g$seed + g$n)
  row <- data.frame(g, native_ok = FALSE, omx_ok = FALSE, improper = NA_character_, active = NA_integer_,
                    est_gap = NA_real_, se_rel = NA_real_, lav_gap = NA_real_)
  fit <- tryCatch(suppressWarnings(fit_sem(syntax[[g$cell]], d)), error = function(e) NULL)
  if (is.null(fit)) return(row)
  row$native_ok <- TRUE
  row$improper <- paste(fit@diagnostics$improper, collapse = "; ")
  row$active <- length(fit@diagnostics$active_bounds) + length(fit@diagnostics$active_constraints)
  pinned <- names(fit@theta)[sqrt(diag(fit@vcov)) == 0]
  oracle_mod <- mod
  lb <- NULL
  if (g$cell == "bounded") {
    lb <- c(`m1 ~~ m1` = 0)
  }
  om <- tryCatch(sem_openmx(oracle_mod, .sem_sample(d, oracle_mod$ram), lbound = lb), error = function(e) NULL)
  if (is.null(om) || om$output$status$code > 1) return(row)
  row$omx_ok <- TRUE
  o <- omx_table(om, oracle_mod)
  map <- cell_map(g$cell, names(fit@theta))
  keep <- setdiff(names(fit@theta), "a"[g$cell == "zero"])
  row$est_gap <- max(abs(fit@theta[keep] - o$est[map[keep]]))
  # an independent referee for the unconstrained structures: lavaan converged tightly
  if (g$cell %in% names(sem_models())) {
    lav <- tryCatch(
      suppressWarnings(lavaan::sem(syntax[[g$cell]], d, fixed.x = FALSE, control = list(rel.tol = 1e-12))),
      error = function(e) NULL
    )
    if (!is.null(lav)) {
      pe <- lavaan::parameterEstimates(lav)
      lv <- stats::setNames(pe$est, ifelse(pe$op == "=~", paste(pe$rhs, "~", pe$lhs), paste(pe$lhs, pe$op, pe$rhs)))
      row$lav_gap <- max(abs(fit@theta - lv[names(fit@theta)]))
    }
  }
  se_names <- setdiff(keep, pinned)
  se_oracle <- o$se
  if (g$cell == "bounded" && length(pinned)) {
    fixed <- oracle_mod
    fixed$s$value[fixed$s$row == "m1" & fixed$s$col == "m1"] <- 0
    fixed <- sem_model(fixed$ram$vars, fixed$ram$obs, fixed$a, fixed$s,
                       oracle_mod$theta[setdiff(names(oracle_mod$theta), "m1 ~~ m1")],
                       latent = "eta", loadings = oracle_mod$loadings)
    omf <- tryCatch(sem_openmx(fixed, .sem_sample(d, fixed$ram)), error = function(e) NULL)
    if (is.null(omf)) return(row)
    se_oracle <- omx_table(omf, fixed)$se
  }
  row$se_rel <- max(abs(sqrt(diag(fit@vcov))[se_names] / se_oracle[map[se_names]] - 1))
  row
}
res <- do.call(rbind, parallel::mclapply(seq_len(nrow(grid)), one, mc.cores = max(1L, parallel::detectCores() - 1L)))

cell <- function(df) {
  data.frame(runs = nrow(df), failed = sum(!df$native_ok | !df$omx_ok),
             improper = sum(!is.na(df$improper) & nzchar(df$improper)), active = sum(df$active > 0, na.rm = TRUE),
             max_est_gap = max(df$est_gap, na.rm = TRUE), max_se_rel = max(df$se_rel, na.rm = TRUE))
}
cat("J2 table (maximum over 20 seeds; estimates absolute, SEs relative):\n")
print(do.call(rbind, lapply(split(res, list(res$cell, res$n), drop = TRUE), cell)), digits = 3)
est_worst <- max(res$est_gap, na.rm = TRUE)
se_worst <- max(res$se_rel, na.rm = TRUE)
cat(sprintf("\nWorst estimate gap %.3e (rule 1e-6): %s; worst SE difference %.3e (rule 1e-3): %s\n",
            est_worst, if (est_worst <= 1e-6) "PASS" else "FAIL", se_worst, if (se_worst <= 1e-3) "PASS" else "FAIL"))
over <- res[!is.na(res$est_gap) & res$est_gap > 1e-6, c("cell", "n", "seed", "est_gap", "lav_gap")]
cat(sprintf("Runs with an estimate gap above 1e-6: %d of %d\n", nrow(over), nrow(res)))
if (nrow(over)) {
  cat("  (lav_gap: the native fit against lavaan converged tightly, an independent referee)\n")
  print(over)
}
cat(sprintf("Failed runs: %d of %d; improper runs: %d\n", sum(!res$native_ok | !res$omx_ok), nrow(res),
            sum(!is.na(res$improper) & nzchar(res$improper))))
print(res[!is.na(res$improper) & nzchar(res$improper), c("cell", "n", "seed", "improper")])

# memory_exp and its MBCO known answers
fx <- "tests/testthat/fixtures/memory_exp.rds"
if (file.exists(fx)) {
  d <- readRDS(fx)
  ms <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
  full <- fit_sem(ms, d)
  stat <- function(con) nrow(d) * (fit_sem(paste0(ms, "\n", con), d)@f - full@f)
  a1 <- stat("a1 == 0")
  b1 <- stat("b1 == 0")
  cat(sprintf(
    "\nmemory_exp (n = %d): n*dF a1 == 0 = %.6f (OpenMx 221.045546), b1 == 0 = %.6f (OpenMx 0.083100); minimum %.6f\n",
    nrow(d), a1, b1, min(a1, b1)
  ))
  cat(sprintf("absolute differences: %.2e, %.2e (rule 1e-6 on OpenMx's printed decimals)\n",
              abs(a1 - 221.045546), abs(b1 - 0.083100)))
}

ver <- sapply(c("OpenMx", "nloptr"), function(p) as.character(utils::packageVersion(p)))
res$versions <- paste(names(ver), ver, collapse = "; ")
dir.create("tests/sim/results", showWarnings = FALSE)
utils::write.csv(res, sprintf("tests/sim/results/sem-parity-gate-%s.csv", Sys.Date()), row.names = FALSE)
