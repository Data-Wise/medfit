# Few-clusters design study, task T6: aggregate the per-cell rows of tests/sim/twolevel-few-clusters-t6.sh into the
# committed tables. Stops (never warns) when a cell is short of R rows, holds other replicates than the launch's
# REP_START to REP_START + R - 1, mixes medfit or lavaan versions (or differs from the versions recorded at launch), or
# its failure categories do not sum to R.
#
# Environment (defaults in brackets):
#   W        the runner's work directory [_agents_workspace/fc-t6]
#   REPS     replicates per cell [1000]; reads W/rows/cell-<id>-R<REPS>.csv and the launch manifest
#            W/manifest-R<REPS>.txt (rep_start, SHA, medfit and lavaan versions)
#   REP_START optional; must equal the manifest's rep_start when set
#   OUT_DIR  where the tables go [planning/studies/few-clusters]
#   P1       the P1 cell list [planning/studies/few-clusters/T6-p1-cells.csv]
#   CELLS    comma-separated cell ids to aggregate [all 120; a subset only for a smoke check, never committed]
# Writes OUT_DIR/T6-cells.csv (one row per cell, arm, interval and estimand), OUT_DIR/T6-parametrization.csv (P0
# against P1 on the P1 cells) and OUT_DIR/T6-manifest-sha256.txt (hashes of every row file, the scripts and the
# installed SHA; the rows stay outside git, plan section 7).
#   Rscript tests/sim/twolevel-few-clusters-t6-aggregate.R

source("tests/sim/twolevel-few-clusters-lib.R")
source("tests/sim/twolevel-few-clusters-t6-lib.R")
w <- Sys.getenv("W", "_agents_workspace/fc-t6")
reps <- as.integer(Sys.getenv("REPS", "1000"))
out_dir <- Sys.getenv("OUT_DIR", "planning/studies/few-clusters")
p1_file <- Sys.getenv("P1", "planning/studies/few-clusters/T6-p1-cells.csv")
if (is.na(reps) || reps < 1L) stop("REPS must be a positive count", call. = FALSE)

cells <- fc_grid()$cell_id
cells_env <- Sys.getenv("CELLS", "")
if (nzchar(cells_env)) {
  sub_cells <- as.integer(strsplit(cells_env, ",", fixed = TRUE)[[1]])
  if (anyNA(sub_cells) || !all(sub_cells %in% cells)) stop("unknown cell id in CELLS", call. = FALSE)
  cells <- sub_cells
}
man <- fc_t6_read_manifest(file.path(w, sprintf("manifest-R%d.txt", reps)))
rep_start <- as.integer(man$rep_start)
rs_env <- Sys.getenv("REP_START", "")
if (nzchar(rs_env) && !identical(as.integer(rs_env), rep_start)) {
  stop("REP_START = ", rs_env, " but the launch manifest records ", rep_start, call. = FALSE)
}
p1_cells <- intersect(as.integer(utils::read.csv(p1_file)$cell_id), cells)
files <- file.path(w, "rows", sprintf("cell-%d-R%d.csv", cells, reps))
absent <- cells[!file.exists(files)]
if (length(absent)) stop(length(absent), " cells have no row file, first ", absent[1], call. = FALSE)
rows <- do.call(rbind, lapply(files, function(f) {
  utils::read.csv(f, stringsAsFactors = FALSE,
                  colClasses = c(medfit_version = "character", lavaan_version = "character"))
}))
fc_t6_check_versions(rows, medfit = man$medfit_version, lavaan = man$lavaan_version)
rows <- rows[setdiff(names(rows), c("medfit_version", "lavaan_version"))]
res <- fc_t6_aggregate(rows, reps = reps, cells = cells, p1_cells = p1_cells, rep_start = rep_start)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
utils::write.csv(res$cells, file.path(out_dir, "T6-cells.csv"), row.names = FALSE)
utils::write.csv(res$parametrization, file.path(out_dir, "T6-parametrization.csv"), row.names = FALSE)

hash <- function(paths) {
  vapply(paths, function(p) strsplit(system2("shasum", c("-a", "256", shQuote(p)), stdout = TRUE), " ")[[1]][1],
         character(1))
}
outs <- file.path(out_dir, c("T6-cells.csv", "T6-parametrization.csv"))
scripts <- c("tests/sim/twolevel-few-clusters.R", "tests/sim/twolevel-few-clusters-lib.R",
             "tests/sim/twolevel-few-clusters-t6-lib.R", "tests/sim/twolevel-few-clusters-t6.sh",
             "tests/sim/twolevel-few-clusters-t6-aggregate.R", p1_file)
out_man <- c(sprintf(paste("# T6 manifest, R = %d, replicates %d to %d, %d cells, %d P1 cells, medfit %s installed",
                           "from %s, lavaan %s, written %s"), reps, rep_start, rep_start + reps - 1L,
                     length(cells), length(p1_cells), man$medfit_version, man$sha, man$lavaan_version,
                     format(Sys.time(), tz = "UTC", usetz = TRUE)),
             sprintf("%s  %s", hash(files), file.path("rows", basename(files))),
             sprintf("%s  %s", hash(c(outs, scripts)), c(outs, scripts)))
writeLines(out_man, file.path(out_dir, "T6-manifest-sha256.txt"))
cat(sprintf("%d rows -> %d summary rows, %d P0/P1 rows in %s\n", nrow(rows), nrow(res$cells),
            NROW(res$parametrization), out_dir))
