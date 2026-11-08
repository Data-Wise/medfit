# One Slurm task: cell `cell`, datasets `first`..`last`. DRAFT, not run on Hopper.
# Output: one CSV per chunk, appended after EVERY dataset; every (dataset, effect, method) has a row, failures included.
# Usage: Rscript run-chunk.R <cell> <first> <last> <outdir>
# Env for smoke tests only: STAGE0_B (refits, default 999), STAGE0_DRAWS (default 20000).
args <- commandArgs(TRUE); cell <- as.integer(args[1]); first <- as.integer(args[2]); last <- as.integer(args[3]); outdir <- args[4]
B <- as.integer(Sys.getenv("STAGE0_B", "999")); DRAWS <- as.integer(Sys.getenv("STAGE0_DRAWS", "20000"))
stopifnot(Sys.getenv("OPENBLAS_NUM_THREADS") == "1", Sys.getenv("OMP_NUM_THREADS") == "1")   # one core per task
source("planning/studies/fiml-stage0-hopper/cells.R")
suppressMessages(pkgload::load_all(quiet = TRUE))
# Study-only override of the stage-0 release guard (in-process; never committed). Fingerprint gate:
fp <- Sys.getenv("STAGE0_FINGERPRINT"); stopifnot(nzchar(fp), file.exists(fp))
fp_commit <- sub("^medfit_commit +", "", grep("^medfit_commit", readLines(fp), value = TRUE)[1])
here_commit <- if (nzchar(Sys.getenv("STAGE0_ALLOW_ANY_COMMIT"))) fp_commit else system("git rev-parse HEAD", intern = TRUE)
stopifnot(identical(here_commit, fp_commit))        # source must be the fingerprinted commit
fp_hash <- if (file.exists(paste0(fp, ".sha256"))) sub(" .*", "", readLines(paste0(fp, ".sha256"))[1]) else NA_character_
BUDGET <- as.numeric(Sys.getenv("STAGE0_BUDGET_S", "6000")); T0 <- proc.time()[["elapsed"]]  # leave headroom under the 2 h limit
utils::assignInNamespace(".fiml_source_inference_admitted", function() TRUE, ns = "medfit")
stopifnot(isTRUE(medfit:::.fiml_source_inference_admitted()))
source("planning/studies/fiml-stage0-hopper/shared-refits.R")   # study-only; parity proven by parity-check.R
sh <- study_shared_refits_install()
cl <- stage0_cells()[cell, ]
gen <- function(seed) {
  set.seed(seed)
  draw <- function(k) { x <- rnorm(k); m <- cl$a * x + rnorm(k); y <- cl$c * x + cl$b * m + rnorm(k); cbind(X = x, M = m, Y = y) }
  mask <- function(d) {
    k <- nrow(d)
    if (cl$miss == "mar") { p <- plogis(log(.2 / .8) + .5 * d[, "X"]); d[runif(k) < p, "M"] <- NA; d[runif(k) < p, "Y"] <- NA }
    else { d[runif(k) < .2, "M"] <- NA; d[runif(k) < .2, "Y"] <- NA }
    d
  }
  if (cl$miss != "empty") return(list(data = as.data.frame(mask(draw(cl$n))), collected = cl$n))
  kept <- NULL; coll <- 0L   # collection cap: 2 n (decided 2026-11-08; hit probability ~1e-91, so a hit means a generator defect)
  CAP <- as.integer(ceiling(as.numeric(Sys.getenv("STAGE0_CAP_MULT", "2")) * cl$n))   # env override for tests only
  while (NROW(kept) < cl$n && coll < CAP) {
    d <- mask(draw(1L)); coll <- coll + 1L
    if (runif(1) < .1) d[] <- NA
    if (!all(is.na(d))) kept <- rbind(kept, d)
  }
  if (NROW(kept) < cl$n) stop("collection cap reached (defect: probability ~1e-91 by design)")
  list(data = as.data.frame(kept), collected = coll)
}
mod <- paste0("M ~ a*X\nY ~ b*M + ", if (cl$direct) "cp" else "0", "*X")
COLS <- c("cell", "dataset", "seed", "effect", "method", "status", "reason", "seconds", "estimate", "lo", "hi",
          "requested", "successful", "failed", "interrupted", "unattempted", "collected", "retained", "truth",
          "medfit_commit", "fingerprint_sha256")
mkrow <- function(base, eff, meth, ...) {            # fixed schema: every column present, NA by default
  r <- setNames(as.list(rep(NA, length(COLS))), COLS)
  for (nm in names(base)) r[[nm]] <- base[[nm]]
  r$effect <- eff; r$method <- meth; r$medfit_commit <- fp_commit; r$fingerprint_sha256 <- fp_hash
  extra <- list(...); for (nm in names(extra)) r[[nm]] <- extra[[nm]]
  r
}
EFFECTS <- c("nie", "nde", "te"); METHODS <- c("nonparametric", "parametric")
whole_dataset <- function(base, status, reason, ...)   # a dataset-level failure expands to all 6 rows
  unlist(lapply(EFFECTS, function(e) lapply(METHODS, function(m) mkrow(base, e, m, status = status, reason = reason, ...))), recursive = FALSE)
outfile <- file.path(outdir, sprintf("cell%03d_%05d-%05d.csv", cell, first, last))
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
flush <- function(rows) {
  df <- do.call(rbind, lapply(rows, function(r) as.data.frame(r[COLS], stringsAsFactors = FALSE)))
  utils::write.table(df, outfile, sep = ",", row.names = FALSE, col.names = !file.exists(outfile),
                     append = file.exists(outfile), qmethod = "double")
}
if (file.exists(outfile)) stop("output exists; remove or choose another outdir (no silent appends across reruns)")
for (d in first:last) {
  seed <- stage0_seed(cell, d); base <- list(cell = cell, dataset = d, seed = seed)
  if (proc.time()[["elapsed"]] - T0 > BUDGET) { flush(whole_dataset(base, "unattempted_budget", "wall-clock budget reached")); next }
  g <- tryCatch(gen(seed), error = function(e) conditionMessage(e))
  if (is.character(g)) { flush(whole_dataset(base, "generation_failed", g)); next }
  sh$reset()                                          # one dataset at a time: the cache never spans datasets
  fit <- tryCatch(fit_sem(mod, g$data, missing = "fiml", fixed_x = FALSE), error = function(e) conditionMessage(e))
  info <- list(collected = g$collected, retained = NROW(g$data))
  if (is.character(fit)) { flush(do.call(whole_dataset, c(list(base, "fit_failed", fit), info))); next }
  rows <- list()
  for (eff in EFFECTS) for (meth in METHODS) {
    t0 <- proc.time()[["elapsed"]]
    r <- tryCatch(bootstrap_mediation(source_fit = fit, effect = eff, method = meth,
                                      n_boot = if (meth == "nonparametric") B else DRAWS, seed = seed + 5000000L),
                  error = function(e) conditionMessage(e))
    secs <- proc.time()[["elapsed"]] - t0; truth <- cl[[paste0("truth_", eff)]]
    rows[[length(rows) + 1]] <- if (is.character(r)) mkrow(base, eff, meth, status = "error", reason = r, seconds = secs, truth = truth, collected = info$collected, retained = info$retained)
    else { inf <- r@inference
      mkrow(base, eff, meth, status = inf$status, reason = "", seconds = secs, estimate = r@estimate, lo = r@ci_lower, hi = r@ci_upper,
            requested = inf$requested, successful = inf$successful, failed = inf$failed, interrupted = inf$interrupted,
            unattempted = inf$unattempted, collected = info$collected, retained = info$retained, truth = truth) }
  }
  flush(rows)
}
cat("done cell", cell, "datasets", first, "-", last, "\n")
