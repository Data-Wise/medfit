# Completeness and integrity checker for the 60 x 2500 x 3 x 2 ledger.
# Usage: Rscript check-complete.R <outdir> [ncells=60] [ndatasets=2500]
# Library use: source(); stage0_check(L, nc, nd) returns list(ok, problems, counts) with no side effects.
.here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) NULL)
if (is.null(.here) || !nzchar(.here)) .here <- "planning/studies/fiml-stage0-hopper"
source(file.path(.here, "cells.R"))
FAIL_STATUS <- c("error", "fit_failed", "generation_failed", "unattempted_budget")

stage0_check <- function(L, nc = 60L, nd = 2500L) {
  problems <- character(); add <- function(...) problems <<- c(problems, sprintf(...))
  key <- with(L, paste(cell, dataset, effect, method))
  exp <- expand.grid(cell = seq_len(nc), dataset = seq_len(nd), effect = c("nie", "nde", "te"),
                     method = c("nonparametric", "parametric"), stringsAsFactors = FALSE)
  ek <- with(exp, paste(cell, dataset, effect, method))
  counts <- c(rows = nrow(L), expected = nrow(exp), missing = length(setdiff(ek, key)),
              duplicated = sum(duplicated(key)), unexpected = length(setdiff(key, ek)))
  if (counts[["missing"]] + counts[["duplicated"]] + counts[["unexpected"]] > 0) add("ledger keys: missing %d, duplicated %d, unexpected %d", counts[["missing"]], counts[["duplicated"]], counts[["unexpected"]])
  if (length(unique(L$medfit_commit)) != 1L) add("expected exactly one medfit_commit, found %d", length(unique(L$medfit_commit)))
  if (length(unique(L$fingerprint_sha256)) != 1L) add("expected exactly one fingerprint_sha256, found %d", length(unique(L$fingerprint_sha256)))
  cells <- stage0_cells()
  cl <- cells[match(L$cell, cells$cell), ]
  # seeds follow the formula
  bad <- which(L$seed != stage0_seed(L$cell, L$dataset) | is.na(L$seed))
  if (length(bad)) add("%d rows with a seed that does not match the formula", length(bad))
  # whole-dataset failures and the budget rule
  nbud <- sum(L$status == "unattempted_budget", na.rm = TRUE); counts[["unattempted_budget"]] <- nbud
  if (nbud) add("%d unattempted_budget rows: rerun those datasets on their original seeds (decision OPEN-4) before analysis", nbud)
  ncap <- sum(grepl("collection cap reached", L$reason), na.rm = TRUE); counts[["collection_cap_hits"]] <- ncap
  if (ncap) add("%d collection-cap hits (each is a generator defect, not a statistical outcome)", ncap)
  # rows that reached the interval step: retained == n and collected >= retained, truth matches the cell
  reached <- !(L$status %in% c("generation_failed", "unattempted_budget")) & !(L$status == "fit_failed" & is.na(L$retained))
  r <- which(reached)
  badr <- r[is.na(L$retained[r]) | L$retained[r] != cl$n[r] | is.na(L$collected[r]) | L$collected[r] < L$retained[r]]
  if (length(badr)) add("%d rows with retained != n or collected < retained", length(badr))
  tr <- ifelse(L$effect == "nie", cl$truth_nie, ifelse(L$effect == "nde", cl$truth_nde, cl$truth_te))
  hastruth <- r[L$status[r] != "fit_failed"]
  badt <- hastruth[is.na(L$truth[hastruth]) | abs(L$truth[hastruth] - tr[hastruth]) > 1e-12]
  if (length(badt)) add("%d rows with a truth value that does not match the cell", length(badt))
  # purported successes: finite estimate and interval, ordered, counts consistent
  ret <- which(!(L$status %in% FAIL_STATUS))
  nonfin <- ret[!is.finite(L$estimate[ret]) | !is.finite(L$lo[ret]) | !is.finite(L$hi[ret]) | L$lo[ret] > L$hi[ret]]
  if (length(nonfin)) add("%d non-error rows with a nonfinite or reversed interval", length(nonfin))
  cc <- ret[!is.na(L$requested[ret])]
  badc <- cc[L$requested[cc] != L$successful[cc] + L$failed[cc] + L$interrupted[cc] + L$unattempted[cc]]
  if (length(badc)) add("%d rows where requested != successful + failed + interrupted + unattempted", length(badc))
  # exact structural zero: NDE in fixed-direct cells must be exactly 0 with 0 inside the interval
  z <- ret[L$effect[ret] == "nde" & !cl$direct[ret]]
  badz <- z[is.finite(L$estimate[z]) & (L$estimate[z] != 0 | L$lo[z] > 0 | L$hi[z] < 0)]
  if (length(badz)) add("%d fixed-direct NDE successes that are not exactly 0 (any nonzero value, even 1e-17, fails the stage)", length(badz))
  list(ok = length(problems) == 0L, problems = problems, counts = counts)
}

if (sys.nframe() == 0L && length(commandArgs(TRUE)) >= 1L) {
  a <- commandArgs(TRUE); outdir <- a[1]
  nc <- as.integer(ifelse(is.na(a[2]), 60, a[2])); nd <- as.integer(ifelse(is.na(a[3]), 2500, a[3]))
  fs <- list.files(outdir, pattern = "^cell[0-9]+_.*\\.csv$", full.names = TRUE)
  L <- do.call(rbind, lapply(fs, read.csv, stringsAsFactors = FALSE))
  res <- stage0_check(L, nc, nd)
  cat(sprintf("files %d\n", length(fs))); print(res$counts)
  cat("provenance: commits", paste(unique(L$medfit_commit), collapse = ","), "| fingerprints", paste(unique(L$fingerprint_sha256), collapse = ","), "\n")
  print(table(L$method, L$status, useNA = "ifany"))
  if (length(res$problems)) cat(paste0("PROBLEM: ", res$problems, "\n"), sep = "")
  cat(if (res$ok) "COMPLETE\n" else "INCOMPLETE OR INCONSISTENT\n"); quit(status = if (res$ok) 0L else 1L)
}
