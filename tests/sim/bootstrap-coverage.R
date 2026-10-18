# Coverage gate for the parametric bootstrap (0.11.0 plan T6c): the 95% percentile interval for the indirect effect a*b
# contains the true value about 95% of the time. It replaces an unconditional skip() in test-bootstrap.R, whose
# comment said to run it separately and which nothing ran.
#
# Cells: NSIM data sets (2000 by default) drawn from X -> M -> Y (a = 0.5, b = 0.3, c' = 0.2, n = 200), each with
# `bootstrap_mediation(method = "parametric", n_boot = 1000)` and a 95% interval. The rule (a failing run fails the
# gate): the coverage lies in [0.93, 0.97], which is the nominal 0.95 plus or minus four Monte Carlo SEs at 2000 data
# sets (SE = 0.0049); gates.csv carries the band (min_pass, tol_est). Baseline 2026-10-17: 500 data sets gave 0.944.
# `MUTANT=<name>` plants a defect and the gate must then exit 1: narrow (the 80% level is used for the interval) and
# wrongtruth (the coverage is checked against a*b = 0.2 instead of 0.15).
# Run from the package root:  Rscript tests/sim/bootstrap-coverage.R   (NSIM=2000 by default)
# Results: tests/sim/results/bootstrap-coverage-<date>.csv, one row per data set (a mutant run writes to the temporary
# directory)

suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/testthat/helper-test-data.R")
n_sim <- as.integer(Sys.getenv("NSIM", "2000"))
mutant <- Sys.getenv("MUTANT", "")
if (nzchar(mutant) && !mutant %in% c("narrow", "wrongtruth")) stop("unknown mutant '", mutant, "'", call. = FALSE)
level <- if (mutant == "narrow") 0.80 else 0.95
truth <- if (mutant == "wrongtruth") 0.2 else 0.5 * 0.3

runs <- do.call(rbind, lapply(seq_len(n_sim), function(i) {
  d <- generate_mediation_data(seed = 1000 + i)
  r <- bootstrap_mediation(
    statistic_fn = indirect_effect, method = "parametric", mediation_data = create_test_mediation_data(d),
    n_boot = 1000, ci_level = level, seed = 2000 + i
  )
  data.frame(sim = i, lower = r@ci_lower, upper = r@ci_upper, hit = r@ci_lower <= truth && truth <= r@ci_upper)
}))

out_dir <- if (nzchar(mutant)) tempdir() else "tests/sim/results"
dir.create(out_dir, showWarnings = FALSE)
utils::write.csv(runs, file.path(out_dir, sprintf("bootstrap-coverage-%s.csv", Sys.Date())), row.names = FALSE)

band <- c(0.93, 0.97)
cov <- mean(runs$hit)
cat(sprintf("coverage %.4f over %d data sets, band [%.2f, %.2f]\n", cov, nrow(runs), band[1], band[2]))
ok <- nrow(runs) == n_sim && !anyNA(runs$hit) && cov >= band[1] && cov <= band[2]
cat(if (ok) "\nRULE MET\n" else "\nRULE NOT MET\n")
quit(status = if (ok) 0L else 1L)
