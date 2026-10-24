# Called by the publish job of .github/workflows/qc-weekly.yaml.
#   Rscript tests/sim/qc-collect.R <shard-dir>... --history <csv or none> --out <csv> --alerts <txt> [--planted]
# Each <shard-dir> holds a `qc-metrics-<shard>.csv` row. Merges them into one row, appends it to the history, writes
# the new history to --out, and writes one line per alert to --alerts ("gate: <name>" or "env: <key>: <old> -> <new>").
args <- commandArgs(trailingOnly = TRUE)
opt <- function(flag) if (flag %in% args) args[which(args == flag) + 1L] else NA_character_
dirs <- setdiff(args, c("--history", opt("--history"), "--out", opt("--out"), "--alerts", opt("--alerts"), "--planted"))
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1L])) else "tests/sim"
source(file.path(here, "qc-lib.R"))
rows <- lapply(unlist(lapply(dirs, list.files, pattern = "^qc-metrics-.*\\.csv$", full.names = TRUE)),
               utils::read.csv, stringsAsFactors = FALSE, check.names = FALSE)
stopifnot(length(rows) > 0L)
new <- qc_merge(rows)
hist <- if (!is.na(opt("--history")) && file.exists(opt("--history"))) {
  utils::read.csv(opt("--history"), stringsAsFactors = FALSE, check.names = FALSE)
}
al <- qc_alerts(new, hist, planted = "--planted" %in% args)
utils::write.csv(qc_append(hist, new), opt("--out"), row.names = FALSE, na = "")
writeLines(c(paste0("gate: ", al$gate_failures), paste0("env: ", al$env_changes)), opt("--alerts"))
cat(sprintf("qc-collect: %d shard row(s), %d gate failure(s), %d environment change(s)\n",
            length(rows), length(al$gate_failures), length(al$env_changes)))
