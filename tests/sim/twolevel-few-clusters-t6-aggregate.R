# Few-clusters design study, task T6: aggregate the per-cell rows of tests/sim/twolevel-few-clusters-t6.sh into the
# committed tables. Stops (never warns) when a cell is short of R rows or its failure categories do not sum to R.
#
# Environment (defaults in brackets):
#   W        the runner's work directory [_agents_workspace/fc-t6]
#   REPS     replicates per cell [1000]; reads W/rows/cell-<id>-R<REPS>.csv
#   OUT_DIR  where the tables go [planning/studies/few-clusters]
#   P1       the P1 cell list [planning/studies/few-clusters/T6-p1-cells.csv]
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
p1_cells <- as.integer(utils::read.csv(p1_file)$cell_id)
files <- file.path(w, "rows", sprintf("cell-%d-R%d.csv", cells, reps))
absent <- cells[!file.exists(files)]
if (length(absent)) stop(length(absent), " cells have no row file, first ", absent[1], call. = FALSE)
rows <- do.call(rbind, lapply(files, function(f) {
  r <- utils::read.csv(f, stringsAsFactors = FALSE)
  r[setdiff(names(r), c("medfit_version", "lavaan_version"))]
}))
res <- fc_t6_aggregate(rows, reps = reps, cells = cells, p1_cells = p1_cells)
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
sha <- if (file.exists(file.path(w, "install-sha.txt"))) readLines(file.path(w, "install-sha.txt")) else NA
man <- c(sprintf("# T6 manifest, R = %d, %d cells, %d P1 cells, medfit installed from %s, written %s", reps,
                 length(cells), length(p1_cells), sha, format(Sys.time(), tz = "UTC", usetz = TRUE)),
         sprintf("%s  %s", hash(files), file.path("rows", basename(files))),
         sprintf("%s  %s", hash(c(outs, scripts)), c(outs, scripts)))
writeLines(man, file.path(out_dir, "T6-manifest-sha256.txt"))
cat(sprintf("%d rows -> %d summary rows, %d P0/P1 rows in %s\n", nrow(rows), nrow(res$cells),
            NROW(res$parametrization), out_dir))
