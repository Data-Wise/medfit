# Split the `gates (rest)` gates into balanced shards by measured time (.github/workflows/gates.yaml).
#   Rscript scripts/gate-shards.R plan <k>                  table of the k shards with loads
#   Rscript scripts/gate-shards.R select <i> <k>            comma list of shard i (1-based) for run-gates.R --only
#   Rscript scripts/gate-shards.R union-check <dir>         every <dir>/**/shard-gates-*.txt together equal the rest set
# Each command takes a trailing `--local-only` to include the gates of tests/sim/gates-local-only.txt, which the rest set
# otherwise excludes (they cost more than about 300 s hosted; the gates workflow's `local_only` dispatch input passes it).
# The rest set is tests/sim/gates.csv without "reliability" (its own job). Weights are seconds per gate in
# tests/sim/gate-seconds.csv (median of four hosted runs, 2026-11-24 to 26); a gate with no row gets
# DEFAULT_SECONDS, so a new gate still lands in a shard (the lightest one at its turn). Gates that share a script
# (constrained and stationarity) stay in one shard because run-gates.R runs each script once. Greedy longest-first,
# ties by name, so every shard computes the same split independently.

source("tests/sim/gate-tier-lib.R")
DEFAULT_SECONDS <- 300
REST_EXCLUDE <- "reliability"

gate_script_map <- function(run_gates = "tests/sim/run-gates.R") {
  exprs <- parse(run_gates, keep.source = FALSE)
  for (e in exprs) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) && identical(e[[2]], as.name("scripts"))) return(eval(e[[3]]))
  }
  stop("no `scripts <- c(...)` in ", run_gates)
}

rest_gates <- function(gates_csv = "tests/sim/gates.csv", exclude = REST_EXCLUDE, include_local = FALSE,
                       local_only = gate_local_only()) {
  setdiff(utils::read.csv(gates_csv, stringsAsFactors = FALSE)$gate, c(exclude, if (!include_local) local_only))
}

assign_shards <- function(gates, seconds, script_of, k) {
  stopifnot(k >= 1L, !anyDuplicated(gates))
  w <- ifelse(gates %in% names(seconds), seconds[gates], DEFAULT_SECONDS)
  key <- ifelse(gates %in% names(script_of), script_of[gates], gates)
  grp <- split(seq_along(gates), key)
  gw <- vapply(grp, function(ix) sum(w[ix]), numeric(1))
  ord <- order(-gw, names(gw))
  load <- numeric(k)
  shard_of <- integer(length(gates))
  for (g in names(gw)[ord]) {
    s <- which.min(load) # first minimum: ties go to the lowest index
    shard_of[grp[[g]]] <- s
    load[s] <- load[s] + gw[[g]]
  }
  list(gates = lapply(seq_len(k), function(s) gates[shard_of == s]), load = load)
}

plan_shards <- function(k, gates_csv = "tests/sim/gates.csv", weights_csv = "tests/sim/gate-seconds.csv",
                        run_gates = "tests/sim/run-gates.R", include_local = FALSE) {
  wt <- utils::read.csv(weights_csv, stringsAsFactors = FALSE)
  assign_shards(rest_gates(gates_csv, include_local = include_local), stats::setNames(wt$seconds, wt$gate), gate_script_map(run_gates), k)
}

# `ran`: the gate ids the shards report having run. Returns the problems (character(0) when the union is exact).
union_problems <- function(ran, expected) {
  c(
    if (length(miss <- setdiff(expected, ran))) paste("gate(s) run by no shard:", paste(miss, collapse = ", ")),
    if (length(extra <- setdiff(ran, expected))) paste("unexpected gate(s):", paste(extra, collapse = ", ")),
    if (length(dup <- unique(ran[duplicated(ran)]))) paste("gate(s) run by more than one shard:", paste(dup, collapse = ", "))
  )
}

if (sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  cmd <- if (length(a)) a[[1]] else ""
  inc <- "--local-only" %in% a
  a <- setdiff(a, "--local-only")
  if (cmd == "plan") {
    p <- plan_shards(as.integer(a[[2]]), include_local = inc)
    for (s in seq_along(p$gates)) cat(sprintf("shard %d: %5.0f s  %s\n", s, p$load[s], paste(p$gates[[s]], collapse = ",")))
  } else if (cmd == "select") {
    i <- as.integer(a[[2]]); k <- as.integer(a[[3]])
    stopifnot(i >= 1L, i <= k)
    cat(paste(plan_shards(k, include_local = inc)$gates[[i]], collapse = ","), "\n", sep = "")
  } else if (cmd == "union-check") {
    files <- list.files(a[[2]], pattern = "^shard-gates-.*\\.txt$", recursive = TRUE, full.names = TRUE)
    ran <- unlist(lapply(files, function(f) strsplit(trimws(readLines(f, warn = FALSE)), ",", fixed = TRUE)[[1]]))
    ran <- ran[nzchar(ran)]
    cat(sprintf("%d shard file(s), %d gate(s) reported\n", length(files), length(ran)))
    pr <- union_problems(ran, rest_gates(include_local = inc))
    if (length(pr)) { cat(paste0("UNION CHECK FAILED: ", pr, "\n"), sep = ""); quit(status = 1L) }
    cat("union check: PASS (shards together run exactly the rest set)\n")
  } else {
    stop("usage: gate-shards.R plan <k> | select <i> <k> | union-check <dir>")
  }
}
