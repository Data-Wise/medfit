# Self-test: a clean synthetic ledger passes; each planted defect must be caught. Run: Rscript test-check-complete.R
source("planning/studies/fiml-stage0-hopper/check-complete.R")
nc <- 60L; nd <- 2L; cells <- stage0_cells()
L <- expand.grid(cell = seq_len(nc), dataset = seq_len(nd), effect = c("nie", "nde", "te"), method = c("nonparametric", "parametric"), stringsAsFactors = FALSE)
cl <- cells[L$cell, ]
L$seed <- stage0_seed(L$cell, L$dataset); L$status <- "ok"; L$reason <- ""; L$seconds <- 1
L$truth <- ifelse(L$effect == "nie", cl$truth_nie, ifelse(L$effect == "nde", cl$truth_nde, cl$truth_te))
L$estimate <- L$truth; L$lo <- L$truth - .1; L$hi <- L$truth + .1
L$estimate[L$effect == "nde" & !cl$direct] <- 0; L$lo[L$effect == "nde" & !cl$direct] <- 0; L$hi[L$effect == "nde" & !cl$direct] <- 0
L$requested <- 999; L$successful <- 999; L$failed <- 0; L$interrupted <- 0; L$unattempted <- 0
L$collected <- cl$n; L$retained <- cl$n; L$medfit_commit <- "abc"; L$fingerprint_sha256 <- "def"
chk <- function(x) stage0_check(x, nc, nd)
stopifnot(chk(L)$ok)
plant <- list(
  missing_row   = function(x) x[-1, ],
  duplicate     = function(x) rbind(x, x[1, ]),
  bad_seed      = function(x) { x$seed[5] <- x$seed[5] + 1L; x },
  budget_row    = function(x) { x$status[7] <- "unattempted_budget"; x },
  cap_hit       = function(x) { x$reason[9] <- "collection cap reached (defect)"; x },
  retained_ne_n = function(x) { x$retained[3] <- x$retained[3] - 1L; x },
  wrong_truth   = function(x) { x$truth[4] <- x$truth[4] + .01; x },
  nonfinite     = function(x) { x$hi[6] <- NA; x },
  reversed_ci   = function(x) { x$lo[2] <- x$hi[2] + 1; x },
  count_mismatch = function(x) { x$successful[8] <- 900; x },
  nde_1e17      = function(x) { i <- which(x$effect == "nde" & !cells$direct[x$cell])[1]; x$estimate[i] <- 1e-17; x$hi[i] <- 1e-17; x },
  two_commits   = function(x) { x$medfit_commit[1] <- "zzz"; x })
for (nm in names(plant)) { r <- chk(plant[[nm]](L)); cat(sprintf("%-15s %s\n", nm, if (r$ok) "NOT CAUGHT" else "caught")); stopifnot(!r$ok) }
cat("all planted defects caught\n")
