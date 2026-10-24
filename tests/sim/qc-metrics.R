# One shard's history row, written next to its results.
#   Rscript tests/sim/qc-metrics.R <shard> [<results-dir>]
# The results directory defaults to tests/sim/results; the newest gates-summary-*.txt in it is read.
args <- commandArgs(trailingOnly = TRUE)
shard <- args[1L]
dir <- if (length(args) >= 2L) args[2L] else "tests/sim/results"
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1L])) else "tests/sim"
source(file.path(here, "qc-lib.R"))
sm <- sort(list.files(dir, pattern = "^gates-summary-.*\\.txt$", full.names = TRUE))
sha <- tryCatch(system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE),
                error = function(e) NA)
ref <- Sys.getenv("QC_REF", NA_character_)
row <- qc_row(if (length(sm)) readLines(sm[length(sm)], warn = FALSE) else character(), dir, sha[1L], ref)
out <- file.path(dir, sprintf("qc-metrics-%s.csv", shard))
utils::write.csv(row, out, row.names = FALSE, na = "")
cat("qc-metrics: wrote", out, "\n")
