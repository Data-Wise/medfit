# One Slurm task: cell `cell`, datasets `first`..`last`. DRAFT, not run on Hopper.
# Usage: Rscript run-chunk.R <cell> <first> <last> <outdir>
# Env for smoke tests only: STAGE0_B (refits, default 999), STAGE0_DRAWS (default 20000).
args <- commandArgs(TRUE); cell <- as.integer(args[1]); first <- as.integer(args[2]); last <- as.integer(args[3]); outdir <- args[4]
B <- as.integer(Sys.getenv("STAGE0_B", "999")); DRAWS <- as.integer(Sys.getenv("STAGE0_DRAWS", "20000"))
stopifnot(Sys.getenv("OPENBLAS_NUM_THREADS") == "1")           # one core per task; no hidden threading
source("planning/studies/fiml-stage0-hopper/cells.R")
suppressMessages(devtools::load_all(quiet = TRUE))
# Study-only override of the stage-0 release guard (in-process; never committed). Fingerprint gate:
fp <- Sys.getenv("STAGE0_FINGERPRINT"); stopifnot(nzchar(fp), file.exists(fp))
utils::assignInNamespace(".fiml_source_inference_admitted", function() TRUE, ns = "medfit")
stopifnot(isTRUE(medfit:::.fiml_source_inference_admitted()))
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
  kept <- NULL; coll <- 0L                       # collection cap 10 n is UNRESOLVED in the design (README)
  while (NROW(kept) < cl$n && coll < 10L * cl$n) {
    d <- mask(draw(1L)); coll <- coll + 1L
    if (runif(1) < .1) d[] <- NA
    if (!all(is.na(d))) kept <- rbind(kept, d)
  }
  if (NROW(kept) < cl$n) stop("collection cap reached")
  list(data = as.data.frame(kept), collected = coll)
}
mod <- paste0("M ~ a*X\nY ~ b*M + ", if (cl$direct) "cp" else "0", "*X")
rows <- list()
for (d in first:last) {
  seed <- stage0_seed(cell, d)
  g <- tryCatch(gen(seed), error = function(e) conditionMessage(e))
  base <- list(cell = cell, dataset = d, seed = seed)
  if (is.character(g)) { rows[[length(rows) + 1]] <- c(base, list(effect = NA, method = NA, status = "generation_failed", reason = g)); next }
  fit <- tryCatch(fit_sem(mod, g$data, missing = "fiml", fixed_x = FALSE), error = function(e) conditionMessage(e))
  if (is.character(fit)) { rows[[length(rows) + 1]] <- c(base, list(effect = NA, method = NA, status = "fit_failed", reason = fit)); next }
  for (eff in c("nie", "nde", "te")) for (meth in c("nonparametric", "parametric")) {
    t0 <- proc.time()[["elapsed"]]
    r <- tryCatch(bootstrap_mediation(source_fit = fit, effect = eff, method = meth,
                                      n_boot = if (meth == "nonparametric") B else DRAWS, seed = seed + 5000000L),
                  error = function(e) conditionMessage(e))
    secs <- proc.time()[["elapsed"]] - t0
    if (is.character(r)) { rows[[length(rows) + 1]] <- c(base, list(effect = eff, method = meth, status = "error", reason = r, seconds = secs)); next }
    inf <- r@inference
    rows[[length(rows) + 1]] <- c(base, list(effect = eff, method = meth, status = inf$status, reason = "", seconds = secs,
      estimate = r@estimate, lo = r@ci_lower, hi = r@ci_upper, requested = inf$requested, successful = inf$successful,
      failed = inf$failed, interrupted = inf$interrupted, unattempted = inf$unattempted,
      collected = g$collected, retained = NROW(g$data), truth = cl[[paste0("truth_", eff)]]))
  }
}
cols <- unique(unlist(lapply(rows, names)))
out <- do.call(rbind, lapply(rows, function(r) as.data.frame(r[cols], col.names = cols)))
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
write.csv(out, file.path(outdir, sprintf("cell%03d_%05d-%05d.csv", cell, first, last)), row.names = FALSE)
cat("done cell", cell, "datasets", first, "-", last, "rows", nrow(out), "\n")
