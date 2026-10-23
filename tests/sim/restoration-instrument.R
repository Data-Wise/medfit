# Read-only instrument for status -4 restorations (restoration-bound plan T2,
# planning/specs/IMPL-restoration-bound-2026-10-23.md). Not a gate and not in gates.csv: it records every
# restoration attempt (`.sem_polish_accept(restore = TRUE)`) made while the nonlinear-profile gate's fixtures are
# fitted, so the allowance |g'delta| + 0.5|delta' H_L delta| and the rise it must bound can be compared on real
# attempts. It changes no package behavior: `trace()` wraps `.sem_polish_accept` and only reads; the polish and
# the gate are recomputed from the entry arguments to give the hypothetical rise of a rejected attempt.
#
# The fixtures are the profile gate's own (tests/sim/sem-nonlinear-profile-gate.R is evaluated with its result
# writer and `quit()` neutralized, so there is one fixture builder and no results CSV from this script).
#
# Per attempt (one CSV row): fixture, q_tag, status, gate accepted before and after (the after is the gate's verdict
# on the polished point), whether the polish returned a point, whether the unmodified code kept it, f before and
# after, rise, allowance, rho = rise / allowance, restoration distance (natural units), active rows, and the
# per-fit start index. The quantities missing on an early return (no polished point) are NA, never an error.
#
# Run from the package root:  Rscript tests/sim/restoration-instrument.R [out.csv]   (FAST=1: 8 fixtures x 3 q's)
# Output: tests/sim/results/restoration-instrument-<fast|full>-<blas>-<date>.csv unless a path is given. The
# `results/` prefix is not read by run-gates.R (its gates match their own prefixes), but delete smoke runs anyway.

suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/sim/restoration-common.R")
out_arg <- commandArgs(trailingOnly = TRUE)
fast <- nzchar(Sys.getenv("FAST", ""))

d <- rst_run_profile(fast)
blas <- rst_blas()
path <- if (length(out_arg)) {
  out_arg[1L]
} else {
  dir.create("tests/sim/results", showWarnings = FALSE)
  file.path("tests/sim/results",
            sprintf("restoration-instrument-%s-%s-%s.csv", if (fast) "fast" else "full", blas, Sys.Date()))
}
utils::write.csv(d, path, row.names = FALSE)
cat(sprintf("restoration instrument: %d restoration attempts over %d polish calls -> %s\n", nrow(d),
            log_env$calls, path))
if (nrow(d)) {
  cat(sprintf("polished %d, kept %d, gate_after accepted %d, rho max %.3g (finite %d)\n", sum(d$polished), sum(d$kept),
              sum(d$gate_after %in% TRUE), suppressWarnings(max(d$rho[is.finite(d$rho)], -Inf)), sum(is.finite(d$rho))))
}
