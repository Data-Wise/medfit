# Reference side of the injected-failure parity: runs the UNCHANGED ../../run-chunk.R with one extra line that wraps the
# refit function before the shared-refit patch is installed (the cache then wraps the flaky function, as parity-check.R does).
# Usage: Rscript ref-inject.R <fail|warn> <run-chunk args: cell first last outdir>
a <- commandArgs(TRUE); inject <- a[1]
ln <- readLines("planning/studies/fiml-stage0-hopper/run-chunk.R")
i <- grep("^sh <- study_shared_refits_install\\(\\)", ln); stopifnot(length(i) == 1L)
code <- 'local({ orig <- get(".bootstrap_fiml_refit", envir = asNamespace("medfit")); utils::assignInNamespace(".bootstrap_fiml_refit", INJECT, ns = "medfit") })'
flaky <- 'function(source, rows) { if (sum(rows) %% 7L == 0L) stop("injected refit failure", call. = FALSE); orig(source, rows) }'
warny <- 'function(source, rows) { if (sum(rows) %% 3L == 0L) warning("injected refit warning", call. = FALSE); orig(source, rows) }'
code <- sub("INJECT", switch(inject, fail = flaky, warn = warny, stop("inject must be fail or warn")), code, fixed = TRUE)
ln <- append(ln, code, after = i - 1L)
commandArgs <- function(trailingOnly = FALSE) a[-1L]   # run-chunk.R reads its own arguments through this
eval(parse(text = ln), envir = globalenv())
