# Join the reliability gate's shards (tests/sim/sem-reliability.R with SHARD/SHARDS set) into the one results file the
# verdict in tests/sim/run-gates.R reads, tests/sim/results/sem-reliability-<date>.csv.gz.
#   Rscript scripts/merge-reliability.R <shards-dir> <k> [results-dir]
# Fails unless exactly the k shard files of one date and one SHARDS value are present, each at most once; the verdict's own
# row-count check (76,800) then catches a shard that ran short.
args <- commandArgs(trailingOnly = TRUE)
dir <- args[[1]]; k <- as.integer(args[[2]])
out_dir <- if (length(args) >= 3) args[[3]] else file.path("tests", "sim", "results")
pat <- "^sem-reliability-([0-9]{4}-[0-9]{2}-[0-9]{2})-shard([0-9]+)of([0-9]+)\\.csv\\.gz$"
files <- list.files(dir, pattern = pat, recursive = TRUE)
base <- basename(files)
if (length(files) != k) stop(sprintf("expected %d shard files, found %d in %s", k, length(files), dir))
date <- unique(sub(pat, "\\1", base)); of <- unique(as.integer(sub(pat, "\\3", base)))
idx <- sort(as.integer(sub(pat, "\\2", base)))
if (length(date) != 1L) stop("shard files are from different dates: ", paste(date, collapse = ", "))
if (!identical(of, k)) stop("shard files were written for SHARDS = ", paste(of, collapse = ", "), ", expected ", k)
if (!identical(idx, seq_len(k))) stop("shard indices are ", paste(idx, collapse = ", "), ", expected 1..", k)
parts <- lapply(file.path(dir, files), function(f) utils::read.csv(gzfile(f), stringsAsFactors = FALSE))
cols <- lapply(parts, names)
if (any(!vapply(cols, identical, logical(1), cols[[1]]))) stop("shards have different columns")
res <- do.call(rbind, parts)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
target <- file.path(out_dir, sprintf("sem-reliability-%s.csv.gz", date))
utils::write.csv(res, gzfile(target), row.names = FALSE)
cat(sprintf("merged %d shards, %d rows -> %s\n", k, nrow(res), target))
