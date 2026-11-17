# Few-clusters design study driver (planning/PLAN-few-clusters-design-study-2026-11-16.md, task T1): one row per
# dataset and arm for the lavaan two-level (1-1-1) adapter, delta intervals from `tidy(conf_int = TRUE)`.
# Generator, grid, seeds, arms and row builder: tests/sim/twolevel-few-clusters-lib.R.
#
# Environment:
#   CELLS   required: comma-separated cell ids from fc_grid() (1001 to 1120) or "all"; no default, so the full
#           campaign never starts by accident
#   REPS    replicates per cell (default 1000); seeds cell_id * 1e5 + rep
#   ARMS    "p0", "p1" or "p0,p1" (default "p0"); P0 lavaan defaults, P1 the syntax floor at EPS
#   EPS     P1 floor (default 1e-3; decision M7 is open)
#   CORES   parallel::mclapply cores (default 1)
#   OUT     output CSV (default a file in tempdir(); per-dataset rows stay outside git, section 7)
#   MUTANT  "" (default), "truth" (every truth + .05) or "narrow" (every delta interval 20% narrower): T4's first
#           attempt. The current T4 mutants (truth shifted by 2 x the median baseline SE) are built from a baseline
#           run's rows with fc_mutate_runs() and judged with fc_paired_catch(); they need no MUTANT run
#   SCALE_X k (default 1): analyze each dataset with X times k and every truth divided by k (T4 metamorphic rescale;
#           the same seeds, so rows pair with an unscaled run by cell_id, rep and arm)
#
# Uses the installed medfit: install it from the source at a recorded SHA into a scratch library first (section 9),
# e.g. R CMD INSTALL -l <lib> . then R_LIBS=<lib> CELLS=1001 REPS=2 Rscript tests/sim/twolevel-few-clusters.R

for (pkg in c("lavaan", "medfit", "withr", "checkmate", "generics")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("this study needs ", pkg, call. = FALSE)
}
if (!exists("TwoLevelMediationData", envir = asNamespace("medfit"))) {
  stop("the installed medfit (", format(utils::packageVersion("medfit")), ") has no two-level adapter; ",
       "install the dev source into a scratch library", call. = FALSE)
}
source("tests/sim/twolevel-few-clusters-lib.R")

cells_env <- Sys.getenv("CELLS", "")
if (!nzchar(cells_env)) stop("set CELLS (cell ids from fc_grid(), or \"all\")", call. = FALSE)
grid <- fc_grid()
cell_ids <- if (cells_env == "all") grid$cell_id else as.integer(strsplit(cells_env, ",", fixed = TRUE)[[1]])
if (anyNA(cell_ids) || !all(cell_ids %in% grid$cell_id)) stop("unknown cell id in CELLS", call. = FALSE)
reps <- as.integer(Sys.getenv("REPS", "1000"))
arms <- strsplit(Sys.getenv("ARMS", "p0"), ",", fixed = TRUE)[[1]]
if (!length(arms) || !all(arms %in% c("p0", "p1"))) stop("ARMS must be p0, p1 or p0,p1", call. = FALSE)
eps <- as.numeric(Sys.getenv("EPS", "1e-3"))
cores <- as.integer(Sys.getenv("CORES", "1"))
mutant <- Sys.getenv("MUTANT", "")
scale_x <- as.numeric(Sys.getenv("SCALE_X", "1"))
if (!is.finite(scale_x) || scale_x <= 0) stop("SCALE_X must be a positive number", call. = FALSE)
invisible(fc_apply_mutant(data.frame(truth_x = 0, est_x = 0, lo_x = 0, hi_x = 0), mutant)) # unknown names error
out <- Sys.getenv("OUT", file.path(tempdir(), sprintf("twolevel-few-clusters-%s.csv", format(Sys.Date()))))

jobs <- expand.grid(rep = seq_len(reps), cell_id = cell_ids, KEEP.OUT.ATTRS = FALSE)
run_job <- function(k) {
  cell <- grid[grid$cell_id == jobs$cell_id[k], ]
  rows <- lapply(arms, function(a) {
    fc_row(cell, jobs$rep[k], a, eps = eps, mutant = mutant, scale_x = scale_x) # nolint: object_usage_linter.
  })
  do.call(rbind, rows)
}
t0 <- proc.time()[["elapsed"]]
res <- if (cores > 1L) {
  parallel::mclapply(seq_len(nrow(jobs)), run_job, mc.cores = cores, mc.preschedule = FALSE)
} else {
  lapply(seq_len(nrow(jobs)), run_job)
}
failed <- vapply(res, inherits, logical(1), "try-error")
if (any(failed)) stop(sum(failed), " jobs raised an R error: ", as.character(res[[which(failed)[1]]]), call. = FALSE)
res <- do.call(rbind, res)
res$medfit_version <- format(utils::packageVersion("medfit"))
res$lavaan_version <- format(utils::packageVersion("lavaan"))
utils::write.csv(res, out, row.names = FALSE)
cat(sprintf("%d rows (%d cells x %d reps x %d arms) in %.1f s -> %s\n", nrow(res), length(cell_ids), reps,
            length(arms), proc.time()[["elapsed"]] - t0, out))
