# medsim adapter for the stage-0 FIML study (DRAFT, local only; nothing here has been run on Hopper).
# The unit of work is the one in ../run-chunk.R: per dataset, fit_sem(missing = "fiml"), then NIE/NDE/TE x
# {nonparametric, parametric} bootstrap_mediation() calls through the shared-refit patch. medsim_run_chunk() drives it:
# one scenario per cell, one replication per dataset, one wide row per dataset (6 calls x 12 fields). Use
# stage0_medsim_long() to get the long, 21-column run-chunk layout back.
#
# Run from the repo root. Environment (all as in run-chunk.R unless noted):
#   OPENBLAS_NUM_THREADS = OMP_NUM_THREADS = 1, STAGE0_FINGERPRINT (+ ".sha256"), STAGE0_B (999), STAGE0_DRAWS (20000),
#   STAGE0_BUDGET_S (6000), STAGE0_CAP_MULT (2), STAGE0_ALLOW_ANY_COMMIT (smoke tests only);
#   new: STAGE0_MEDSIM_LIB (library holding the pinned medsim), STAGE0_MEDSIM_COMMIT (REQUIRED: the medsim commit
#   that library was built from; recorded in every row), STAGE0_MEDSIM_VERSION (optional: stop if it differs).
.s0 <- new.env(parent = emptyenv())
.s0$dir <- "planning/studies/fiml-stage0-hopper"
EFFECTS <- c("nie", "nde", "te"); METHODS <- c("nonparametric", "parametric")
.s0_tag <- c(nonparametric = "np", parametric = "pa")
.s0_fields <- c("status", "reason", "seconds", "estimate", "lo", "hi", "requested", "successful", "failed",
                "interrupted", "unattempted", "truth")
.s0_char <- c("status", "reason")
.s0_col <- function(e, m, f) paste(e, .s0_tag[[m]], f, sep = "_")
.s0_call_cols <- function() unlist(lapply(EFFECTS, function(e) lapply(METHODS, function(m) .s0_col(e, m, .s0_fields))))
# Fixed receipt columns (strings are constant per run; the logicals are verified per row at call time).
.s0_receipt_cols <- c("rcp_medsim_version", "rcp_medsim_commit", "rcp_medfit_commit", "rcp_fp_sha256", "rcp_r_version",
                      "rcp_blas", "rcp_B", "rcp_draws", "rcp_fit_fiml", "rcp_guard_open", "rcp_shared_refit")

# ---- one-time process setup: library, medfit, guard override, shared refits, receipt -------------------------------
stage0_adapter_setup <- function(root = getwd()) {
  if (isTRUE(.s0$ready)) return(invisible(.s0))
  stopifnot(Sys.getenv("OPENBLAS_NUM_THREADS") == "1", Sys.getenv("OMP_NUM_THREADS") == "1")   # one core per task
  lib <- Sys.getenv("STAGE0_MEDSIM_LIB"); if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
  if (!requireNamespace("medsim", quietly = TRUE)) stop("medsim is not installed (set STAGE0_MEDSIM_LIB)")
  msha <- Sys.getenv("STAGE0_MEDSIM_COMMIT")
  if (!grepl("^[0-9a-f]{40}$", msha)) stop("STAGE0_MEDSIM_COMMIT must be the 40-hex commit the medsim library was built from")
  mver <- as.character(utils::packageVersion("medsim"))
  want <- Sys.getenv("STAGE0_MEDSIM_VERSION")
  if (nzchar(want) && !identical(want, mver)) stop(sprintf("medsim version %s, expected %s", mver, want))
  dir <- file.path(root, .s0$dir)
  source(file.path(dir, "cells.R")); source(file.path(dir, "shared-refits.R"))
  suppressMessages(pkgload::load_all(root, quiet = TRUE))
  fp <- Sys.getenv("STAGE0_FINGERPRINT"); stopifnot(nzchar(fp), file.exists(fp))
  fp_commit <- sub("^medfit_commit +", "", grep("^medfit_commit", readLines(fp), value = TRUE)[1])
  here <- if (nzchar(Sys.getenv("STAGE0_ALLOW_ANY_COMMIT"))) fp_commit else
    system2("git", c("-C", shQuote(root), "rev-parse", "HEAD"), stdout = TRUE)
  stopifnot(identical(here, fp_commit))                 # source must be the fingerprinted commit
  fp_hash <- if (file.exists(paste0(fp, ".sha256"))) sub(" .*", "", readLines(paste0(fp, ".sha256"))[1]) else NA_character_
  utils::assignInNamespace(".fiml_source_inference_admitted", function() TRUE, ns = "medfit")   # study-only, in-process
  stopifnot(isTRUE(medfit:::.fiml_source_inference_admitted()))
  .s0$sh <- study_shared_refits_install()
  .s0$cells <- stage0_cells()
  .s0$fp_commit <- fp_commit; .s0$fp_hash <- fp_hash
  .s0$budget <- as.numeric(Sys.getenv("STAGE0_BUDGET_S", "6000")); .s0$T0 <- proc.time()[["elapsed"]]
  .s0$B <- as.integer(Sys.getenv("STAGE0_B", "999")); .s0$draws <- as.integer(Sys.getenv("STAGE0_DRAWS", "20000"))
  .s0$cap_mult <- as.numeric(Sys.getenv("STAGE0_CAP_MULT", "2"))
  .s0$receipt <- list(rcp_medsim_version = mver, rcp_medsim_commit = msha, rcp_medfit_commit = fp_commit,
                      rcp_fp_sha256 = fp_hash, rcp_r_version = as.character(getRversion()),
                      rcp_blas = unname(extSoftVersion()[["BLAS"]]), rcp_B = .s0$B, rcp_draws = .s0$draws)
  .s0$ready <- TRUE
  invisible(.s0)
}

# ---- scenarios -----------------------------------------------------------------------------------------------------
# medsim seeds each replication with .medsim_det_seed(name, rep) and hands the generator only `n`, so the generator
# recovers the replication id by matching the RNG state against the states of set.seed(det_seed(name, r)), r = 1..nd
# (exact; stops if nothing matches), then re-seeds with stage0_seed(cell, r) so the data equal run-chunk.R's.
.s0_rep_lookup <- local({
  tables <- list()
  function(name, nd) {
    key <- paste(name, nd)
    if (is.null(tables[[key]])) {
      det <- getFromNamespace(".medsim_det_seed", "medsim")
      k <- vapply(seq_len(nd), function(r) { set.seed(det(name, r)); paste(.Random.seed[3:10], collapse = ",") }, "")
      tables[[key]] <<- stats::setNames(seq_len(nd), k)
    }
    tables[[key]]
  }
})
.s0_recover_rep <- function(name, nd) {
  if (!exists(".Random.seed", envir = globalenv(), inherits = FALSE)) stop("no RNG state: replication id not recoverable")
  st <- get(".Random.seed", envir = globalenv()); kind <- st[1L]
  r <- .s0_rep_lookup(name, nd)[paste(st[3:10], collapse = ",")]
  if (is.na(r) || kind != 10403L) stop("generator was not called right after medsim's per-replication set.seed (or rep > nd)")
  unname(r)
}

stage0_medsim_scenario <- function(cell, nd) {
  stage0_adapter_setup()
  cl <- .s0$cells[cell, ]; name <- sprintf("cell%03d", cell); cap_mult <- .s0$cap_mult
  gen_data <- function(seed) {            # same draws, in the same order, as gen() in run-chunk.R
    set.seed(seed)
    draw <- function(k) { x <- rnorm(k); m <- cl$a * x + rnorm(k); y <- cl$c * x + cl$b * m + rnorm(k); cbind(X = x, M = m, Y = y) }
    mask <- function(d) {
      k <- nrow(d)
      if (cl$miss == "mar") { p <- plogis(log(.2 / .8) + .5 * d[, "X"]); d[runif(k) < p, "M"] <- NA; d[runif(k) < p, "Y"] <- NA }
      else { d[runif(k) < .2, "M"] <- NA; d[runif(k) < .2, "Y"] <- NA }
      d
    }
    if (cl$miss != "empty") return(list(data = as.data.frame(mask(draw(cl$n))), collected = cl$n))
    kept <- NULL; coll <- 0L
    CAP <- as.integer(ceiling(cap_mult * cl$n))
    while (NROW(kept) < cl$n && coll < CAP) {
      d <- mask(draw(1L)); coll <- coll + 1L
      if (runif(1) < .1) d[] <- NA
      if (!all(is.na(d))) kept <- rbind(kept, d)
    }
    if (NROW(kept) < cl$n) stop("collection cap reached (defect: probability ~1e-91 by design)")
    list(data = as.data.frame(kept), collected = coll)
  }
  generator <- function(n) {
    if (identical(as.integer(n), 1L)) return(data.frame(X = 0, M = 0, Y = 0))   # truth pass (config n_truth = 1): placeholder
    ds <- .s0_recover_rep(name, nd); seed <- stage0_seed(cl$cell, ds)
    g <- tryCatch(gen_data(seed), error = function(e) conditionMessage(e))
    if (is.character(g)) return(structure(data.frame(), stage0 = list(dataset = ds, seed = seed, gen_error = g)))
    structure(g$data, stage0 = list(dataset = ds, seed = seed, collected = g$collected, gen_error = NULL))
  }
  medsim::medsim_scenario(name = name, description = sprintf("stage-0 cell %d", cell), data_generator = generator,
                          params = list(cell = cell, nd = nd, n = cl$n, direct = cl$direct, miss = cl$miss, regime = cl$regime))
}

stage0_truth_fun <- function(data, params) {       # closed form from cells.R; must return a named list of length-1 numerics
  cl <- stage0_cells()[params$cell, ]
  list(nie = cl$truth_nie, nde = cl$truth_nde, te = cl$truth_te)
}

# ---- the method ----------------------------------------------------------------------------------------------------
.s0_blank_row <- function() {
  r <- list(dataset = NA_integer_, seed = NA_integer_, ds_status = "ok", ds_reason = "", collected = NA_integer_, retained = NA_integer_)
  for (cc in .s0_call_cols()) r[[cc]] <- if (sub(".*_", "", cc) %in% .s0_char) NA_character_ else NA_real_
  r
}

stage0_medsim_method <- function() {
  stage0_adapter_setup(); sh <- .s0$sh
  function(data, params) {
    st <- attr(data, "stage0"); if (is.null(st)) stop("stage-0 data carries no stage0 attribute (generator not used?)")
    cl <- .s0$cells[params$cell, ]
    row <- c(.s0_blank_row(), .s0$receipt, list(rcp_fit_fiml = NA, rcp_guard_open = NA, rcp_shared_refit = NA))
    row[c("dataset", "seed")] <- list(as.integer(st$dataset), as.integer(st$seed))
    fail <- function(status, reason, ...) { row[c("ds_status", "ds_reason")] <<- list(status, reason)
      for (nm in names(list(...))) row[[nm]] <<- list(...)[[nm]]; row }
    if (proc.time()[["elapsed"]] - .s0$T0 > .s0$budget) return(fail("unattempted_budget", "wall-clock budget reached"))
    if (!is.null(st$gen_error)) return(fail("generation_failed", st$gen_error))
    sh$reset()                                           # one dataset at a time: the cache never spans datasets
    fit <- tryCatch(medfit::fit_sem(paste0("M ~ a*X\nY ~ b*M + ", if (cl$direct) "cp" else "0", "*X"), data,
                                    missing = "fiml", fixed_x = FALSE), error = function(e) conditionMessage(e))
    info <- list(collected = as.integer(st$collected), retained = NROW(data))
    if (is.character(fit)) return(fail("fit_failed", fit, collected = info$collected, retained = info$retained))
    row$collected <- info$collected; row$retained <- info$retained
    row$rcp_fit_fiml <- isTRUE(medfit:::.sem_fiml_is(fit))
    row$rcp_guard_open <- isTRUE(medfit:::.fiml_source_inference_admitted())
    row$rcp_shared_refit <- !identical(get(".bootstrap_fiml_refit", envir = asNamespace("medfit")), sh$orig)
    for (eff in EFFECTS) for (meth in METHODS) {
      t0 <- proc.time()[["elapsed"]]
      r <- tryCatch(medfit::bootstrap_mediation(source_fit = fit, effect = eff, method = meth,
                                                n_boot = if (meth == "nonparametric") .s0$B else .s0$draws,
                                                seed = st$seed + 5000000L), error = function(e) conditionMessage(e))
      secs <- proc.time()[["elapsed"]] - t0; truth <- cl[[paste0("truth_", eff)]]
      put <- function(f, v) row[[.s0_col(eff, meth, f)]] <<- v
      put("seconds", secs); put("truth", truth)
      if (is.character(r)) { put("status", "error"); put("reason", r); next }
      inf <- r@inference
      put("status", inf$status); put("reason", ""); put("estimate", r@estimate); put("lo", r@ci_lower); put("hi", r@ci_upper)
      for (f in c("requested", "successful", "failed", "interrupted", "unattempted")) put(f, inf[[f]])
    }
    row
  }
}

# ---- one array task: cell, chunk k of n_chunks, nd datasets per cell -------------------------------------------------
stage0_adapter_run_task <- function(cell, chunk_id, n_chunks, nd, outdir, verbose = FALSE, overwrite = FALSE) {
  stage0_adapter_setup()
  # like run-chunk.R ("output exists"): a rerun (e.g. a requeued task) must not silently replace a chunk file
  target <- file.path(outdir, sprintf("cell%03d", cell), getFromNamespace(".medsim_chunk_filename", "medsim")(chunk_id))
  if (file.exists(target) && !isTRUE(overwrite)) stop(sprintf("output exists: %s (pass overwrite = TRUE to replace it)", target), call. = FALSE)
  cfg <- medsim::medsim_config(mode = "local", n_replications = nd, n_cores = 1L, seed = 7000000L + cell,
                               output_dir = file.path(outdir, sprintf("cell%03d", cell)), chunk_id = chunk_id,
                               n_chunks = n_chunks, n_truth = 1L)
  medsim::medsim_run_chunk(list(stage0_medsim_scenario(cell, nd)), stage0_medsim_method(), cfg, verbose = verbose,
                           code_sha = .s0$fp_commit, compute_truth = stage0_truth_fun)
}

# ---- long layout (the 21 run-chunk.R columns) ----------------------------------------------------------------------
STAGE0_COLS <- c("cell", "dataset", "seed", "effect", "method", "status", "reason", "seconds", "estimate", "lo", "hi",
                 "requested", "successful", "failed", "interrupted", "unattempted", "collected", "retained", "truth",
                 "medfit_commit", "fingerprint_sha256")
stage0_medsim_long <- function(W) {
  stopifnot(is.data.frame(W))
  cell <- as.integer(sub("^cell", "", W$scenario)); stopifnot(!anyNA(cell))
  if ("error" %in% names(W)) {                       # a medsim-level failure row (the method itself raised): keep it in the ledger
    e <- !is.na(W$error)
    for (nm in setdiff(c("dataset", "seed"), names(W))) W[[nm]] <- NA_integer_
    W$dataset[e] <- W$replication[e]; W$seed[e] <- stage0_seed(cell[e], W$replication[e])
    W$ds_status[e] <- "error"; W$ds_reason[e] <- paste("medsim:", W$error[e])
  }
  if (!all(W$dataset == W$replication)) stop("dataset recovered by the generator differs from medsim's replication id")
  ok <- function(x) !is.na(x$ds_status) && x$ds_status == "ok"
  out <- vector("list", nrow(W) * 6L); k <- 0L
  for (i in seq_len(nrow(W))) {
    w <- W[i, , drop = FALSE]
    for (eff in EFFECTS) for (meth in METHODS) {
      k <- k + 1L
      r <- stats::setNames(as.list(rep(NA, length(STAGE0_COLS))), STAGE0_COLS)
      r$cell <- cell[i]; r$dataset <- w$dataset; r$seed <- w$seed; r$effect <- eff; r$method <- meth
      r$medfit_commit <- w$rcp_medfit_commit; r$fingerprint_sha256 <- w$rcp_fp_sha256
      if (ok(w)) {
        for (f in .s0_fields) r[[f]] <- w[[.s0_col(eff, meth, f)]]
        r$collected <- w$collected; r$retained <- w$retained
      } else {
        r$status <- w$ds_status; r$reason <- w$ds_reason; r$collected <- w$collected; r$retained <- w$retained
      }
      out[[k]] <- as.data.frame(r[STAGE0_COLS], stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, out)
}

# ---- combine: per-cell medsim integrity audit, then one cross-cell audit -----------------------------------------------
stage0_collapse_exclude <- function(W) {            # keep the collapse audit on NIE/TE estimates and intervals only
  keep <- unlist(lapply(c("nie", "te"), function(e) lapply(METHODS, function(m) .s0_col(e, m, c("estimate", "lo", "hi")))))
  num <- names(W)[vapply(W, is.numeric, logical(1))]
  union(getFromNamespace(".medsim_collapse_exclude_default", "medsim"), setdiff(num, c(keep, "replication", "elapsed", "dataset", "seed")))
}
.s0_union_rbind <- function(frames) {
  cols <- unique(unlist(lapply(frames, names)))
  do.call(rbind, lapply(frames, function(f) { for (cc in setdiff(cols, names(f))) f[[cc]] <- NA; f[cols] }))
}
stage0_adapter_combine <- function(outdir, cells, nd, n_chunks, on_violation = "stop") {
  per <- lapply(cells, function(cc) {
    d <- file.path(outdir, sprintf("cell%03d", cc))
    if (!dir.exists(d)) stop(sprintf("no chunk directory for cell %d", cc))
    ex <- stage0_collapse_exclude(readRDS(list.files(d, "^chunk_.*\\.rds$", full.names = TRUE)[1])$results)
    medsim::medsim_combine_chunks(d, expected_chunks = n_chunks, nsim = nd, collapse_exclude = ex,
                                  on_violation = on_violation, verbose = FALSE)
  })
  W <- .s0_union_rbind(lapply(per, `[[`, "results"))
  attr(W, "medsim_schema") <- 2L; attr(W, "medsim_meta_cols") <- attr(per[[1]]$results, "medsim_meta_cols")
  merged <- per[[1]]; merged$results <- W
  merged$truth <- .s0_union_rbind(lapply(per, `[[`, "truth"))
  merged$chunk_provenance <- unlist(lapply(per, `[[`, "chunk_provenance"), recursive = FALSE)
  merged$summary <- NULL
  viol <- medsim::medsim_audit_results(merged, on_violation = on_violation, nsim = nd, collapse_exclude = stage0_collapse_exclude(W))
  list(results = W, truth = merged$truth, provenance = merged$chunk_provenance, violations = viol, medsim = merged)
}
