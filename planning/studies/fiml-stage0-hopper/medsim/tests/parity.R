# P2 parity: the SAME cells, datasets, seeds and B through the hand-written run-chunk.R and through the medsim adapter
# must give identical records (every column except `seconds`, which is wall-clock time; the provenance receipt lives in the
# wide frame, not in the 21 long columns, so it is not compared). LOCAL ONLY, smoke size (B = 40, 200 draws, 3 datasets).
# Usage (repo root, environment as in adapter.R): Rscript planning/studies/fiml-stage0-hopper/medsim/tests/parity.R <workdir> [mutant]
#   mutant: runs the adapter with a changed seed formula (positive control; must be reported as NOT identical).
a <- commandArgs(TRUE); work <- a[1]; mutant <- "mutant" %in% a[-1]
stopifnot(nzchar(work), !dir.exists(work) || length(list.files(work)) == 0L)
dir.create(work, recursive = TRUE, showWarnings = FALSE)
source("planning/studies/fiml-stage0-hopper/cells.R")
g <- stage0_cells(); pick <- function(n, regime, miss, direct) g$cell[g$n == n & g$regime == regime & g$miss == miss & g$direct == direct]
scen <- list(                                   # 12 scenarios: every regime, miss type, direct on/off and both n appear
  list(200L, "nonzero", "mcar", TRUE), list(200L, "nonzero", "mar", FALSE), list(200L, "b_null", "empty", TRUE),
  list(500L, "a_null", "mar", TRUE), list(200L, "joint_null", "mcar", FALSE), list(200L, "local", "empty", FALSE),
  list(500L, "nonzero", "empty", FALSE), list(200L, "b_null", "mar", FALSE), list(200L, "a_null", "empty", TRUE),
  list(200L, "joint_null", "mar", TRUE), list(200L, "local", "mcar", TRUE), list(500L, "nonzero", "mar", TRUE))
cells <- vapply(scen, function(s) do.call(pick, s), 1L); stopifnot(length(unique(cells)) == 12L)
ND <- 3L
rscript <- file.path(R.home("bin"), "Rscript")
run <- function(args, env = character()) {
  out <- system2(rscript, args, stdout = TRUE, stderr = TRUE, env = if (length(env)) paste0(names(env), "=", env) else character())
  st <- attr(out, "status"); if (!is.null(st) && st != 0L) stop("child failed: ", paste(utils::tail(out, 8L), collapse = "\n"))
  invisible(out)
}
read_dir <- function(d) {
  fs <- list.files(d, "^cell[0-9]+_.*\\.csv$", full.names = TRUE)
  L <- do.call(rbind, lapply(fs, utils::read.csv, stringsAsFactors = FALSE))
  L <- L[order(L$cell, L$dataset, match(L$effect, c("nie", "nde", "te")), L$method), ]; rownames(L) <- NULL
  L[setdiff(names(L), "seconds")]
}
compare <- function(label, cells, nd, env = character(), inject = "none", nch_pattern = function(i) c(1L, 3L)[1 + i %% 2L]) {
  ref <- file.path(work, paste0(label, "-ref")); ad <- file.path(work, paste0(label, "-adapter"))
  tdir <- "planning/studies/fiml-stage0-hopper/medsim/tests"
  if (inject != "none") env <- c(env, STAGE0_PRELUDE = file.path(tdir, "inject-prelude.R"), STAGE0_INJECT = inject, STAGE0_GATE = "off")   # all-withheld cells are a medsim cell_failed violation by construction
  for (cc in cells) run(if (inject == "none") c("planning/studies/fiml-stage0-hopper/run-chunk.R", cc, 1L, nd, ref)
                        else c(file.path(tdir, "ref-inject.R"), inject, cc, 1L, nd, ref), env)
  for (i in seq_along(cells))   # chunk counts alternate 1 and 3 so the replication-offset path is exercised too
    run(c("planning/studies/fiml-stage0-hopper/medsim/run-cells.R", ad, nd, min(nd, nch_pattern(i)), cells[i]), env)
  R <- read_dir(ref); A <- read_dir(ad)
  same_cell <- vapply(cells, function(cc) identical(R[R$cell == cc, ], A[A$cell == cc, ]), NA)
  bad <- if (!all(same_cell)) { cc <- cells[!same_cell][1]; names(R)[!vapply(names(R), function(n) identical(R[R$cell == cc, n], A[A$cell == cc, n]), NA)] }
  cat(sprintf("%-8s cells identical %d/%d (%d records each side; first differing columns: %s)\n", label, sum(same_cell), length(cells),
              nrow(R), if (is.null(bad)) "none" else paste(bad, collapse = ",")))
  list(identical = all(same_cell) && identical(R, A), n = sum(same_cell), of = length(cells), R = R, A = A)
}
if (mutant) {   # planted defect: the adapter draws its datasets from a changed seed formula; parity must fail
  mut <- file.path(work, "mutant-prelude.R")
  writeLines("stage0_seed <- function(cell, dataset) 7000000L + as.integer(cell) * 10000L + as.integer(dataset) + 1L", mut)
  r <- compare("mutant", cells[1:3], ND, c(STAGE0_PRELUDE = mut))
  cat(if (!r$identical) "MUTANT CAUGHT: parity reports the seed-formula change\n" else "MUTANT NOT CAUGHT\n")
  quit(status = if (!r$identical) 0L else 1L)
}
main <- compare("main", cells, ND)
# failure/budget paths, each against the same reference: a collection-cap hit (generation_failed) and a zero wall-clock budget
empty <- pick(200L, "b_null", "empty", TRUE)
cap <- compare("cap", empty, 2L, c(STAGE0_CAP_MULT = "0.001", STAGE0_GATE = "off"))
bud <- compare("budget", cells[1], 2L, c(STAGE0_BUDGET_S = "0", STAGE0_GATE = "off"))
# injected refit failures/warnings (parity-check.R's rules: sum(rows) %% 7 fails, %% 3 warns): direct on/off x mar/mcar-or-empty
inj_cells <- c(pick(200L, "nonzero", "mar", TRUE), pick(200L, "nonzero", "mar", FALSE),
               pick(200L, "nonzero", "mcar", TRUE), pick(200L, "nonzero", "empty", FALSE))
inj_fail <- compare("inj-fail", inj_cells, ND, inject = "fail")
inj_warn <- compare("inj-warn", inj_cells, ND, inject = "warn")
npf <- inj_fail$R[inj_fail$R$method == "nonparametric", ]
cat(sprintf("injected failures: %d of %d nonparametric calls have failed > 0; statuses %s; %d with NA interval; parametric calls untouched: %s\n",
            sum(npf$failed > 0), nrow(npf), paste(sort(unique(npf$status)), collapse = ","), sum(is.na(npf$lo)),
            all(inj_fail$R$status[inj_fail$R$method == "parametric"] == "complete")))
stopifnot(any(npf$failed > 0), any(npf$status == "withheld" & is.na(npf$lo)))   # the withheld path is really compared, not vacuous
stopifnot(all(inj_warn$R$status == "complete"))   # warn case: warnings are not columns of the 21-column record, so it only shows nothing breaks
cat(sprintf("status mix (cap): %s | (budget): %s\n", paste(unique(cap$R$status), collapse = ","), paste(unique(bud$R$status), collapse = ",")))
stopifnot(all(cap$R$status == "generation_failed"), all(bud$R$status == "unattempted_budget"))   # the failure paths are really exercised
ok <- main$identical && cap$identical && bud$identical && inj_fail$identical && inj_warn$identical
cat(sprintf("PARITY %s: clean %d/%d cells identical, cap %s, budget %s, injected failures %d/%d, injected warnings %d/%d\n", if (ok) "PASS" else "FAIL", main$n, main$of, cap$identical, bud$identical, inj_fail$n, inj_fail$of, inj_warn$n, inj_warn$of))
quit(status = if (ok) 0L else 1L)
