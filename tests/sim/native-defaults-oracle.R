# Native-defaults oracle matrix (0.14.0 plan T8a, spec R-12, E-15): the four combinations of fit_sem()'s
# (fixed_x, meanstructure) and the 0.15.0 opt-in, crossed with the core cells, against lavaan.
#
# Cells and rules: tests/sim/native-defaults-oracle-lib.R. Per cell x combination: estimates and SEs of the labeled
# structural parameters, chi-square, df, npar, logLik, AIC and BIC, each against lavaan (fixed.x, meanstructure,
# sampling.weights, se = "robust.huber.white", information = "observed"); the named-subset cell against lavaan with
# the subset's moments written as fixed values plus a hand calculation (the fixed block's marginal log-likelihood and
# the written fixed rows); the opt-in fit must also equal the explicit (TRUE, TRUE) fit. Tolerances are fixed in
# `ndo_tol`; a disagreement is a declared `limit` or `block` row with a reason (`ndo_declared`), never a wider
# tolerance. Any `fail` row exits 1.
# `MUTANT=fixedx_logical` plants a translation of a named fixed_x subset as all-fixed (`.sem_resolve_fixed_x()` returns
# every exogenous variable); the subset cell must then fail (npar, logLik, AIC, BIC) and the gate exit 1.
# Run from the package root:  Rscript tests/sim/native-defaults-oracle.R
# Results: tests/sim/results/native-defaults-oracle-<date>.csv, one row per cell x combination x quantity; a mutant
# run writes to the temporary directory.

suppressMessages(pkgload::load_all(quiet = TRUE))
if (!requireNamespace("lavaan", quietly = TRUE)) {
  stop("this gate needs lavaan (Suggests): without it the oracle comparisons would be skipped, not failed",
       call. = FALSE)
}
source("tests/testthat/helper-sem.R") # provides sem_mutate
source("tests/sim/native-defaults-oracle-lib.R")
mutant <- Sys.getenv("MUTANT", "")
ns <- asNamespace("medfit")
if (mutant == "fixedx_logical") {
  unlockBinding(".sem_resolve_fixed_x", ns)
  assign(".sem_resolve_fixed_x", sem_mutate(get(".sem_resolve_fixed_x", ns), "sel <- fixed_x", "sel <- roles$ov_x"),
         envir = ns)
} else if (nzchar(mutant)) {
  stop("unknown mutant '", mutant, "'", call. = FALSE)
}

res <- ndo_run()
res$lavaan <- as.character(utils::packageVersion("lavaan"))
out_dir <- if (nzchar(mutant)) tempdir() else "tests/sim/results"
dir.create(out_dir, showWarnings = FALSE)
f <- file.path(out_dir, sprintf("native-defaults-oracle-%s.csv", Sys.Date()))
utils::write.csv(res, f, row.names = FALSE)

cat(sprintf("rows %d: %s\n", nrow(res), paste(names(table(res$status)), table(res$status), collapse = ", ")))
nonpass <- res[res$status != "pass", c("cell", "combo", "quantity", "native", "oracle", "status"), drop = FALSE]
if (nrow(nonpass)) print(nonpass, row.names = FALSE)
for (s in c("limit", "block")) {
  r <- unique(res$reason[res$status == s])
  if (length(r)) cat(sprintf("\n%s reasons:\n%s\n", s, paste("-", r, collapse = "\n")))
}
cat(sprintf("\nresults: %s\n", f))
if (any(res$status == "fail")) {
  cat("\nRULE NOT MET\n")
  quit(status = 1)
}
cat("\nRULE MET\n")
