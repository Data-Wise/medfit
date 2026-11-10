# medfit-side analysis for the stage-0 decision over combined records (DRAFT; thresholds are PREREG-DRAFT.md Section 4,
# not frozen). Deliberately does NOT use medsim_analyze_coverage(): that drops rows with a missing interval or truth and
# reports failures separately, while the stage-0 rule counts every attempted replication, an unavailable interval is never
# covered, and conditional coverage uses returned intervals only.
# Input: the long layout (stage0_medsim_long() or the run-chunk.R CSVs read together). Run from the repo root.
.s0_dir <- "planning/studies/fiml-stage0-hopper"
source(file.path(.s0_dir, "medsim/adapter.R"))          # EFFECTS, .s0_col() (setup is lazy: nothing is loaded here)
# check-complete.R (unchanged) locates its siblings from the outermost sourced file, which would be wrong here, so its
# `.here` line is pinned to the study directory while the rest is evaluated verbatim: stage0_check(), FAIL_STATUS.
local({
  ln <- readLines(file.path(.s0_dir, "check-complete.R"))
  i <- grep("^\\.here <- tryCatch", ln); stopifnot(length(i) == 1L)
  ln[i] <- sprintf(".here <- \"%s\"", .s0_dir)
  eval(parse(text = ln), envir = globalenv())
})

# "Returned interval" = the inference object's status is "complete" with a finite, ordered interval. The exact status
# strings are still to be frozen from the pinned source (PREREG P7); medfit's source emits complete / incomplete / withheld.
stage0_returned <- function(L) L$status %in% "complete" & is.finite(L$lo) & is.finite(L$hi) & L$lo <= L$hi

# Expected-record ledger for an arbitrary set of cells (stage0_check() hard-codes cells 1..nc). Row-level checks are
# reused from stage0_check(); only its key-ledger problem is replaced by a subset-aware one.
stage0_integrity <- function(L, cells, nd) {
  # check-complete.R lists only four failure statuses, so a medfit "withheld"/"incomplete" call (a legitimate outcome:
  # NA interval, status from the inference object) would be reported as an inconsistent success. Those rows are presented to
  # it as `error` rows: still in the ledger, still unavailable. A "complete" row with an unusable interval stays flagged.
  Lc <- L; Lc$status[Lc$status %in% c("withheld", "incomplete")] <- "error"
  res <- stage0_check(Lc, nc = max(cells), nd = nd)
  problems <- res$problems[!grepl("^ledger keys:", res$problems)]
  ek <- with(expand.grid(cell = cells, dataset = seq_len(nd), effect = EFFECTS, method = c("nonparametric", "parametric"),
                         stringsAsFactors = FALSE), paste(cell, dataset, effect, method))
  key <- with(L, paste(cell, dataset, effect, method))
  counts <- c(rows = nrow(L), expected = length(ek), missing = length(setdiff(ek, key)),
              duplicated = sum(duplicated(key)), unexpected = length(setdiff(key, ek)))
  if (sum(counts[c("missing", "duplicated", "unexpected")]) > 0)
    problems <- c(sprintf("ledger keys: missing %d, duplicated %d, unexpected %d", counts[["missing"]], counts[["duplicated"]],
                          counts[["unexpected"]]), problems)
  list(ok = length(problems) == 0L, problems = problems, counts = counts)
}

# Receipts (wide frame): one value per constant field, the logical checks TRUE on every fitted row, and the nominal
# interval size reached (a call whose `requested` differs from the nominal B / draws is an effective-K mismatch).
stage0_receipts <- function(W) {
  problems <- character()
  for (cc in c("rcp_medsim_version", "rcp_medsim_commit", "rcp_medfit_commit", "rcp_fp_sha256", "rcp_r_version", "rcp_blas",
               "rcp_B", "rcp_draws"))
    if (!cc %in% names(W)) problems <- c(problems, sprintf("receipt column %s missing", cc))
    else if (length(unique(W[[cc]])) != 1L) problems <- c(problems, sprintf("receipt %s is not constant (%d values)", cc, length(unique(W[[cc]]))))
  fitted <- W$ds_status %in% "ok"
  for (cc in c("rcp_fit_fiml", "rcp_guard_open", "rcp_shared_refit"))
    if (!cc %in% names(W) || !all(W[[cc]][fitted] %in% TRUE))
      problems <- c(problems, sprintf("receipt %s is not TRUE on every fitted row", cc))
  if (!length(problems)) {
    B <- unique(W$rcp_B); D <- unique(W$rcp_draws)
    for (e in EFFECTS) {
      bad_np <- sum(!is.na(W[[.s0_col(e, "nonparametric", "requested")]]) & W[[.s0_col(e, "nonparametric", "requested")]] != B)
      bad_pa <- sum(!is.na(W[[.s0_col(e, "parametric", "requested")]]) & W[[.s0_col(e, "parametric", "requested")]] != D)
      if (bad_np + bad_pa) problems <- c(problems, sprintf("%s: %d calls requested a size other than the nominal B=%d/draws=%d", e, bad_np + bad_pa, B, D))
    }
  }
  list(ok = !length(problems), problems = problems)
}

# One-sided exact 95% lower bound (Clopper-Pearson); 0 successes -> 0, 0 trials -> NA.
.s0_lb <- function(x, n) if (n == 0L) NA_real_ else if (x == 0L) 0 else stats::binom.test(x, n, alternative = "greater", conf.level = .95)$conf.int[[1]]

# Per cell x effect x method. `denominator = "attempted"` is the stage-0 rule; "complete" (drop failures) exists only so the
# tests can show that it gives a different, wrong answer. `attempted` must equal the ledger's nd or it stops.
stage0_coverage <- function(L, cells, nd, denominator = c("attempted", "complete")) {
  denominator <- match.arg(denominator)
  if (!stage0_integrity(L, cells, nd)$ok) stop("ledger is not complete and consistent; no coverage is computed")
  cl <- stage0_cells()
  rows <- list()
  for (c0 in cells) for (e in EFFECTS) for (m in c("nonparametric", "parametric")) {
    d <- L[L$cell == c0 & L$effect == e & L$method == m, ]
    ret <- stage0_returned(d)
    attempted <- if (denominator == "attempted") nrow(d) else sum(ret)
    cover <- ret & d$truth >= d$lo & d$truth <= d$hi
    cover[is.na(cover)] <- FALSE
    k <- sum(cover); r <- sum(ret)
    zero_ok <- if (e == "nde" && !cl$direct[c0]) all(d$estimate[ret] == 0 & d$lo[ret] == 0 & d$hi[ret] == 0) else NA
    rows[[length(rows) + 1L]] <- data.frame(
      cell = c0, effect = e, method = m, attempted = attempted, returned = r, covered = k,
      availability = r / attempted, cond_coverage = if (r) k / r else NA_real_, joint = k / attempted,
      avail_lb = .s0_lb(r, attempted), cond_lb = .s0_lb(k, r), joint_lb = .s0_lb(k, attempted), structural_zero_ok = zero_ok,
      pass = !is.na(.s0_lb(k, r)) && .s0_lb(r, attempted) >= .95 && .s0_lb(k, r) >= .925 && .s0_lb(k, attempted) >= .90,
      stringsAsFactors = FALSE)
  }
  do.call(rbind, rows)
}

# Truth table (medsim's scenario-level $truth) and the per-record truth against cells.R. A swapped or shifted column in
# either place is a problem; the row-level check in stage0_check() alone would not see a wrong scenario table.
stage0_truth_check <- function(truth, W) {
  problems <- character(); cl <- stage0_cells()
  cell <- as.integer(sub("^cell", "", truth$scenario))
  for (e in EFFECTS) {
    want <- cl[[paste0("truth_", e)]][cell]
    if (!isTRUE(all(abs(truth[[e]] - want) < 1e-12))) problems <- c(problems, sprintf("truth table column %s differs from cells.R", e))
    wcell <- as.integer(sub("^cell", "", W$scenario))
    for (m in c("nonparametric", "parametric")) {
      v <- W[[.s0_col(e, m, "truth")]]; ok <- !is.na(v)
      if (!isTRUE(all(abs(v[ok] - cl[[paste0("truth_", e)]][wcell[ok]]) < 1e-12)))
        problems <- c(problems, sprintf("per-record truth %s/%s differs from cells.R", e, m))
    }
  }
  list(ok = !length(problems), problems = problems)
}
