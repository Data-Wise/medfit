# P2 planted defects: the medsim audit and the medfit-side analysis must catch each one, and each has a positive control
# (the clean run passes the same checks, so a pass is not vacuous). LOCAL ONLY, smoke size: 3 cells x 4 datasets x 2 chunks,
# B = 40. Usage (repo root, environment as in adapter.R): Rscript planning/studies/fiml-stage0-hopper/medsim/tests/defects.R <workdir>
a <- commandArgs(TRUE); work <- a[1]
stopifnot(nzchar(work), !dir.exists(work) || length(list.files(work)) == 0L)
source("planning/studies/fiml-stage0-hopper/medsim/analysis.R")
nfail <- 0L; nchk <- 0L
check <- function(label, cond) { nchk <<- nchk + 1L; ok <- isTRUE(cond); if (!ok) nfail <<- nfail + 1L; cat(sprintf("%s  %s\n", if (ok) "PASS" else "FAIL", label)) }
g <- stage0_cells(); pick <- function(n, regime, miss, direct) g$cell[g$n == n & g$regime == regime & g$miss == miss & g$direct == direct]
cells <- c(pick(200L, "nonzero", "mcar", TRUE), pick(200L, "a_null", "mar", FALSE), pick(200L, "b_null", "empty", TRUE))
ND <- 4L; NCH <- 2L
chunks <- file.path(work, "chunks"); for (cc in cells) for (k in seq_len(NCH)) stage0_adapter_run_task(cc, k, NCH, ND, chunks)
types <- function(v) vapply(v, `[[`, "", "type")
clean <- stage0_adapter_combine(chunks, cells, ND, NCH, on_violation = "stop")
W <- clean$results; L <- stage0_medsim_long(W)

cat("-- positive controls: the clean run passes every check\n")
check("clean: medsim combine and cross-cell audit report no violation", length(clean$violations) == 0L)
check("clean: ledger complete and consistent", stage0_integrity(L, cells, ND)$ok)
check("clean: receipts constant, TRUE on every fitted row, nominal sizes reached", stage0_receipts(W)$ok)
check("clean: truth table and per-record truth match cells.R", stage0_truth_check(clean$truth, W)$ok)
cov0 <- stage0_coverage(L, cells, ND)
check("clean: every cell/effect/method has attempted == nd", all(cov0$attempted == ND) && nrow(cov0) == length(cells) * 6L)

cat("-- defect 1: dropped chunk\n")
d1 <- file.path(work, "d1"); dir.create(d1); file.copy(chunks, d1, recursive = TRUE)
unlink(file.path(d1, "chunks", sprintf("cell%03d", cells[2]), "chunk_0002.rds"))
d1dir <- file.path(d1, "chunks")
e <- tryCatch(stage0_adapter_combine(d1dir, cells, ND, NCH, on_violation = "stop"), medsim_combine_violation = function(e) e)
check("dropped chunk stops the combine with missing_chunks", inherits(e, "medsim_combine_violation") && "missing_chunks" %in% types(e$violations))
# without telling the combiner the chunk count, nsim still exposes the short cell (the surviving ids 1..2 are contiguous)
e2 <- tryCatch(medsim::medsim_combine_chunks(file.path(d1dir, sprintf("cell%03d", cells[2])), nsim = ND, on_violation = "stop", verbose = FALSE),
               medsim_combine_violation = function(e) e)
check("dropped chunk without expected_chunks is still caught by nsim", inherits(e2, "medsim_combine_violation") && "nsim_mismatch" %in% types(e2$violations))
Wd <- W[!(W$scenario == sprintf("cell%03d", cells[2]) & W$replication > ND / NCH), ]; Ld <- stage0_medsim_long(Wd)
check("dropped chunk: the long ledger reports missing keys and coverage refuses to run",
      stage0_integrity(Ld, cells, ND)$counts[["missing"]] == 2L * 6L && inherits(try(stage0_coverage(Ld, cells, ND), silent = TRUE), "try-error"))

cat("-- defect 2: duplicated cell\n")
dup_obj <- clean$medsim; Wdup <- rbind(W, W[W$scenario == sprintf("cell%03d", cells[1]), ])
attr(Wdup, "medsim_schema") <- 2L; attr(Wdup, "medsim_meta_cols") <- attr(W, "medsim_meta_cols"); dup_obj$results <- Wdup
v <- medsim::medsim_audit_results(dup_obj, on_violation = "ignore", nsim = ND)
check("duplicated cell: medsim audit reports dup_rep_id", "dup_rep_id" %in% types(v))
Ldup <- stage0_medsim_long(Wdup); ig <- stage0_integrity(Ldup, cells, ND)
check("duplicated cell: the long ledger reports duplicated keys and coverage refuses to run",
      ig$counts[["duplicated"]] == ND * 6L && inherits(try(stage0_coverage(Ldup, cells, ND), silent = TRUE), "try-error"))

cat("-- defect 3: failed or incomplete intervals and the denominator\n")
Lf <- L; i <- which(Lf$cell == cells[1] & Lf$effect == "te" & Lf$method == "nonparametric")[1:2]
Lf[i[1], c("status", "reason", "estimate", "lo", "hi")] <- list("error", "injected", NA, NA, NA)
Lf[i[2], c("status", "estimate", "lo", "hi")] <- list("incomplete", NA, NA, NA)
sel <- function(d, c0) d[d$cell == c0 & d$effect == "te" & d$method == "nonparametric", ]
good <- sel(stage0_coverage(Lf, cells, ND), cells[1])
r0 <- sum(stage0_returned(Lf[Lf$cell == cells[1] & Lf$effect == "te" & Lf$method == "nonparametric", ]))
k0 <- sum(stage0_returned(Lf[Lf$cell == cells[1] & Lf$effect == "te" & Lf$method == "nonparametric", ]) &
          Lf$truth[Lf$cell == cells[1] & Lf$effect == "te" & Lf$method == "nonparametric"] >= Lf$lo[Lf$cell == cells[1] & Lf$effect == "te" & Lf$method == "nonparametric"] &
          Lf$truth[Lf$cell == cells[1] & Lf$effect == "te" & Lf$method == "nonparametric"] <= Lf$hi[Lf$cell == cells[1] & Lf$effect == "te" & Lf$method == "nonparametric"])
check("failed + incomplete: both stay in the attempted denominator and count as unavailable and uncovered",
      good$attempted == ND && good$returned == ND - 2L && r0 == ND - 2L && good$returned == r0 && good$covered == k0 &&
        isTRUE(all.equal(good$availability, (ND - 2) / ND)) && isTRUE(all.equal(good$joint, k0 / ND)))
bad <- sel(stage0_coverage(Lf, cells, ND, denominator = "complete"), cells[1])
check("positive control: dropping failures (the medsim_analyze_coverage-style denominator) reports availability 1 and a larger joint rate",
      k0 > 0 && bad$availability == 1 && bad$joint > good$joint && bad$attempted == ND - 2L)
Lx <- Lf[!(Lf$status %in% c("error", "incomplete")), ]
check("failure rows removed from the ledger: coverage refuses to run", inherits(try(stage0_coverage(Lx, cells, ND), silent = TRUE), "try-error"))
Lc <- L; j <- which(Lc$cell == cells[1] & Lc$effect == "te" & Lc$method == "nonparametric")[1]; Lc[j, c("status", "estimate", "lo", "hi")] <- list("complete", NA, NA, NA)
check("a 'complete' status with an unusable interval is flagged by the ledger", !stage0_integrity(Lc, cells, ND)$ok)

# real withheld intervals (refit failures injected in the adapter run, as in the parity test), not hand-edited rows
inj <- file.path(work, "d3inj")
st <- system2(file.path(R.home("bin"), "Rscript"), c("planning/studies/fiml-stage0-hopper/medsim/run-cells.R", inj, 3L, 1L, cells[1]),
              stdout = FALSE, stderr = FALSE, env = c(paste0("STAGE0_PRELUDE=", file.path("planning/studies/fiml-stage0-hopper/medsim/tests/inject-prelude.R")), "STAGE0_INJECT=fail"))
Li <- utils::read.csv(list.files(inj, "csv$", full.names = TRUE)); ci <- stage0_coverage(Li, cells[1], 3L)
np <- ci[ci$method == "nonparametric", ]; pa <- ci[ci$method == "parametric", ]
check("injected refit failures: withheld nonparametric calls stay in the denominator (attempted 3, returned 0), parametric untouched",
      st == 0L && all(Li$status[Li$method == "nonparametric"] == "withheld") && all(np$attempted == 3L) && all(np$returned == 0L) &&
        all(np$availability == 0) && all(pa$returned == 3L))
check("finding: the unchanged check-complete.R reports those withheld rows as inconsistent (FAIL_STATUS lacks withheld/incomplete)",
      !stage0_check(Li, cells[1], 3L)$ok && stage0_integrity(Li, cells[1], 3L)$ok)

cat("-- defect 4: seed-formula change\n")
Ls <- L; Ls$seed <- Ls$seed + 1L
check("seed column off by one: ledger flags the seed formula", any(grepl("seed that does not match", stage0_integrity(Ls, cells, ND)$problems)))
mut <- file.path(work, "mutant-prelude.R")
writeLines("stage0_seed <- function(cell, dataset) 7000000L + as.integer(cell) * 10000L + as.integer(dataset) + 1L", mut)
out <- file.path(work, "d4")
st <- system2(file.path(R.home("bin"), "Rscript"), c("planning/studies/fiml-stage0-hopper/medsim/run-cells.R", out, 2L, 1L, cells[1]),
              stdout = FALSE, stderr = FALSE, env = paste0("STAGE0_PRELUDE=", mut))
Lm <- utils::read.csv(list.files(out, "csv$", full.names = TRUE))
check("adapter run with a changed seed formula: its records fail the frozen seed check", st == 0L && any(grepl("seed that does not match", stage0_integrity(Lm, cells[1], 2L)$problems)))
Lref <- L[L$cell == cells[1] & L$dataset <= 2L, ]
check("and its estimates differ from the clean run on the same dataset ids (the datasets really changed)",
      !isTRUE(all.equal(Lm$estimate[1:6], Lref$estimate[1:6])))

cat("-- defect 5: swapped truth column\n")
Lt <- L; i1 <- Lt$cell == cells[1] & Lt$effect == "nie"; i2 <- Lt$cell == cells[1] & Lt$effect == "nde"
t1 <- Lt$truth[i1]; Lt$truth[i1] <- Lt$truth[i2]; Lt$truth[i2] <- t1
check("per-record truth swapped between NIE and NDE: ledger flags the truth", any(grepl("truth value", stage0_integrity(Lt, cells, ND)$problems)))
Wt <- W; tmp <- Wt$nie_np_truth; Wt$nie_np_truth <- Wt$nde_np_truth; Wt$nde_np_truth <- tmp
check("per-record truth swapped in the wide frame: truth check flags it", !stage0_truth_check(clean$truth, Wt)$ok)
tt <- clean$truth; tmp <- tt$nie; tt$nie <- tt$nde; tt$nde <- tmp
check("truth table columns swapped: truth check flags it", !stage0_truth_check(tt, W)$ok)

cat("-- defect 6: receipts (effective K and provenance)\n")
Wr <- W; Wr$rcp_shared_refit[1] <- FALSE
check("a fitted row without the shared-refit patch active: receipts flag it", !stage0_receipts(Wr)$ok)
Wr <- W; Wr$rcp_medsim_commit[2] <- strrep("a", 40)
check("two medsim commits in one study: receipts flag it", !stage0_receipts(Wr)$ok)
Wr <- W; Wr$nie_np_requested[3] <- 1
check("a call that ran fewer refits than the nominal B (K = 1 style fallback): receipts flag it", !stage0_receipts(Wr)$ok)
Wr <- W; Wr$rcp_fit_fiml[1] <- FALSE
check("a fitted row that is not a FIML fit: receipts flag it", !stage0_receipts(Wr)$ok)

cat(sprintf("DEFECTS %s: %d/%d checks passed\n", if (nfail == 0L) "PASS" else "FAIL", nchk - nfail, nchk))
quit(status = if (nfail == 0L) 0L else 1L)
