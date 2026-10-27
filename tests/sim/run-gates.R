# Verification-harness driver for the native SEM gates (0.8.0 plan T3, Codex finding 1).
#
# Verdicts are computed from each gate's results CSV against the thresholds and expected row counts in
# tests/sim/gates.csv, never from a script's exit status alone: sem-parity-gate.R and
# sem-constrained-gate.R print PASS/FAIL lines and write their CSV without ever failing the process,
# and sem-reliability.R had no aggregate threshold and dropped worker errors, so a script can exit 0
# with failed numerical checks. A result is rejected when it has a tolerance failure, a wrong (missing
# or extra) row count, a failed or errored run, or when the file is stale or unreadable.
#
# --sim adds two requirements (T3b, Codex finding 1): the child must exit 0 (a crash before the
# script's final write would otherwise leave the committed baselines as the newest file and pass), and
# the results file must have been modified at or after the child's start. The child's output goes to
# tests/sim/results/gates-<script>.log (ignored by version control) instead of being discarded.
#
# Modes (run from the package root):
#   Rscript tests/sim/run-gates.R                 verdicts on the latest committed results (default; fast)
#   Rscript tests/sim/run-gates.R --fast          unit tests (filter "sem-"), lint, and the check that
#                                                 gates.csv tol_est (stationarity) equals .sem_stat_tol
#   Rscript tests/sim/run-gates.R --sim [--only parity,constrained]
#                                                 run the sim scripts (slow), then verdicts
#   Rscript tests/sim/run-gates.R --mutants       prove the driver rejects bad results: four
#                                                 "exits 0 but bad" mutations per gate plus a control,
#                                                 the stationarity scale mutants, and stub-script
#                                                 cases for the --sim path (crash, no write, control)
# Options: --max-age DAYS (default 14; older results are stale), --dir DIR (results directory), --monthly (also run
# the gates listed in tests/sim/gates-monthly.txt, which every mode drops otherwise: the qc-monthly workflow passes it,
# the PR gates shards do not; ADR D-13).
# Exit status: 0 only when every requested check passes. Summary: tests/sim/results/gates-summary-<date>.txt

args <- commandArgs(trailingOnly = TRUE)
opt <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1L]
}
has <- function(flag) flag %in% args

results_dir <- opt("--dir", "tests/sim/results")
max_age <- as.numeric(opt("--max-age", "14"))
only <- if (!is.null(opt("--only"))) strsplit(opt("--only"), ",", fixed = TRUE)[[1]] else NULL
source("tests/sim/product-gate-common.R") # pass rules of the product-term and four-way gates (one implementation)
source("tests/sim/semopy-oracle-lib.R") # the semopy gate's verdict and the monthly-only gate list (ADR D-13)
spec_all <- utils::read.csv("tests/sim/gates.csv", stringsAsFactors = FALSE, na.strings = c("NA", ""))
spec <- spec_all
if (!is.null(only)) spec <- spec[spec$gate %in% only, , drop = FALSE]
monthly <- so_monthly_gates()
if (!has("--monthly") && any(spec$gate %in% monthly)) {
  cat(sprintf("monthly-only gates skipped (pass --monthly to run them): %s\n\n",
              paste(intersect(spec$gate, monthly), collapse = ", ")))
}
spec <- so_drop_monthly(spec, monthly, has("--monthly"))

chk <- function(check, ok, detail) {
  data.frame(check = check, pass = isTRUE(ok), detail = detail, stringsAsFactors = FALSE)
}
fmt <- function(x) format(x, digits = 3, scientific = TRUE)
num_max <- function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
bool_fail <- function(a, b = TRUE) sum(!(a %in% TRUE & b %in% TRUE))
imp_count <- function(x) {
  x <- as.character(x)
  sum(!is.na(x) & nzchar(x))
}

# ---- loading: the newest results file for a prefix; unreadable or stale files are failures ----
# not_before (a POSIXct, --sim only): a file modified earlier was not written by the run that just ended.
# The comparison is strict; a filesystem with coarse modification times can only cause a false FAIL.
load_results <- function(dir, prefix, max_age_days, not_before = NULL, undated = FALSE) {
  pat <- if (undated) sprintf("^%s\\.csv$", prefix) else
    sprintf("^%s-([0-9]{4}-[0-9]{2}-[0-9]{2})\\.csv(\\.gz)?$", prefix)
  files <- list.files(dir, pattern = pat)
  if (!length(files)) {
    label <- if (undated) paste0(prefix, ".csv") else paste0(prefix, "-<date>.csv")
    return(list(ok = FALSE, why = sprintf("no results file matches '%s' in %s", label, dir)))
  }
  dates <- if (undated) as.Date(file.mtime(file.path(dir, files))) else as.Date(sub(pat, "\\1", files))
  f <- files[which.max(dates)]
  if (!is.null(not_before)) {
    mt <- file.mtime(file.path(dir, f))
    if (is.na(mt) || mt < not_before) {
      why <- sprintf(
        "%s was not written by this run (modified %s, run started %s)", f,
        format(mt, "%Y-%m-%d %H:%M:%OS3"), format(not_before, "%Y-%m-%d %H:%M:%OS3")
      )
      return(list(ok = FALSE, file = f, why = why))
    }
  }
  d <- tryCatch(
    {
      con <- if (grepl("\\.gz$", f)) gzfile(file.path(dir, f)) else file.path(dir, f)
      utils::read.csv(con, stringsAsFactors = FALSE)
    },
    error = function(e) NULL,
    warning = function(w) NULL
  )
  if (is.null(d) || !nrow(d)) {
    return(list(ok = FALSE, file = f, why = sprintf("%s is unreadable or empty", f)))
  }
  age <- as.numeric(Sys.Date() - max(dates))
  if (is.na(age) || age > max_age_days) {
    why <- sprintf("%s is stale (%d days old, limit %g)", f, as.integer(age), max_age_days)
    return(list(ok = FALSE, file = f, why = why))
  }
  list(ok = TRUE, file = f, data = d)
}

# ---- per-gate verdicts: each returns a data frame of named checks ----
rows_chk <- function(d, s) {
  chk("rows", nrow(d) == s$expected_rows, sprintf("%d rows, expected %d", nrow(d), s$expected_rows))
}
failed_chk <- function(d) {
  n <- bool_fail(d$native_ok, d$omx_ok)
  chk("failed runs", n == 0, sprintf("%d failed or missing", n))
}
improper_chk <- function(d) {
  n <- imp_count(d$improper)
  chk("improper runs", n == 0, sprintf("%d improper", n))
}
max_chk <- function(name, x, limit) {
  m <- num_max(x)
  chk(name, isTRUE(m <= limit) && !anyNA(x), sprintf("max %s, limit %s, %d NA", fmt(m), fmt(limit), sum(is.na(x))))
}

verdict_gate <- function(gate, d, s) {
  needs <- list(
    parity = c("native_ok", "omx_ok", "improper", "est_gap", "se_rel"),
    constrained = c("native_ok", "omx_ok", "est_gap", "rel_se"),
    se = c("native_ok", "omx_ok", "improper", "rel_obs"),
    stationarity = c("kind", "dec", "dist"),
    reliability = c("algo", "precond", "mode", "class", "gate_accepts", "match"),
    "product-null" = c("xdist", "df", "reject05", "mean_chisq", "reps", "reps_ok"),
    "product-null-colon" = c("xdist", "df", "reject05", "mean_chisq", "reps", "reps_ok"),
    "product-fixed-var" = c("xdist", "config", "expect", "df", "reject05", "mean_chisq", "reps", "reps_ok"),
    "product-fixed-var-colon" = c("xdist", "config", "expect", "df", "reject05", "mean_chisq", "reps", "reps_ok"),
    "product-corr" = c("design", "cvf", "path", "expect", "gap"),
    "product-corr-colon" = c("design", "cvf", "path", "expect", "gap", "gap_column", "err"),
    "four-way-kat" = c("scenario", "route", "component", "bias_z", "se_ratio", "reps", "reps_ok"),
    "s7-lifecycle" = c("s7", "s7_version", "step", "ok"),
    "nonlinear-profile" = c("fixture", "q_tag", "native_ok", "omx_ok", "lr", "lr_oracle", "gap", "note", "disproved",
                            "q_ach"),
    "nonlinear-parity" = c("problem", "structure", "n", "seed", "native_ok", "improper", "feas", "omx_ok", "f_gap",
                           "est_gap", "ref_gap", "ann", "se_rel", "se_oracle"),
    "bootstrap-coverage" = c("sim", "lower", "upper", "hit"),
    "fixed-x" = c("tag", "check", "pass"),
    "mean-constrained" = c("structure", "n", "seed", "shift", "problem", "ok", "feas", "invariance", "lavaan_ok"),
    factor = c("n", "k", "seed", "miss", "pass", "err", "fxmode", "lavaan", "fitstats"),
    "oracle-sweep" = c("seed", "family", "n", "scale", "constraint", "outcome", "max_abs_error",
                       "feasibility", "f_gap", "warning", "error", "optimum"),
    "compare-lr" = c("engine", "version", "seed", "verdict", "all_converged", "ref_ok", "drop", "above", "warn_drop",
                     "warn_above", "mislabel", "pass"),
    restoration = c("check", "kind", "value", "limit", "pass", "detail"),
    "native-defaults" = c("cell", "combo", "quantity", "native", "oracle", "diff", "tol", "status", "reason"),
    semopy = c("param", "status", "est_gap", "se_rel", "sl_est_gap", "sl_se_rel", "reason")
  )
  if (is.null(needs[[gate]])) {
    return(chk("known gate", FALSE, paste("no verdict function for gate", gate)))
  }
  miss <- setdiff(needs[[gate]], names(d))
  if (length(miss)) {
    return(chk("columns", FALSE, paste("missing columns:", paste(miss, collapse = ", "))))
  }
  switch(gate,
    parity = {
      est_ok <- sum(d$est_gap <= s$tol_est, na.rm = TRUE)
      rbind(
        rows_chk(d, s), failed_chk(d), improper_chk(d),
        chk(
          "estimates", est_ok >= s$min_pass,
          sprintf("%d within %s, need at least %d (D22 baseline)", est_ok, fmt(s$tol_est), s$min_pass)
        ),
        chk("missing estimates", !anyNA(d$est_gap), sprintf("%d NA est_gap", sum(is.na(d$est_gap)))),
        max_chk("standard errors", d$se_rel, s$tol_se)
      )
    },
    constrained = rbind(
      rows_chk(d, s), failed_chk(d),
      max_chk("estimates", d$est_gap, s$tol_est), max_chk("standard errors", d$rel_se, s$tol_se)
    ),
    se = rbind(rows_chk(d, s), failed_chk(d), improper_chk(d), max_chk("standard errors", d$rel_obs, s$tol_se)),
    stationarity = {
      # S6 rule on both sides of the acceptance threshold tol (gates.csv tol_est); tol_se holds the distance
      # cutoff (natural units) that separates a stall far from the optimum from a near-converged stop
      tol <- s$tol_est
      cut <- s$tol_se
      acc <- d$dec[d$kind == "accepted"]
      oth <- d$dec[d$kind != "accepted" & is.finite(d$dec)]
      sep <- if (length(acc) && length(oth)) min(oth) / max(acc) else NA_real_
      trunc <- d$kind == "truncated" & is.finite(d$dec)
      far <- d$dec[trunc & d$dist > cut & !is.na(d$dist)]
      rbind(
        rows_chk(d, s),
        chk(
          "accepted decrements", length(acc) > 0 && all(is.finite(acc)),
          sprintf("%d accepted rows, %d non-finite", length(acc), sum(!is.finite(acc)))
        ),
        chk(
          "separation", isTRUE(sep >= 10),
          sprintf("smallest finite non-accepted / largest accepted = %s, need at least 10", fmt(sep))
        ),
        chk(
          "accepted margin", isTRUE(length(acc) > 0 && max(acc) <= tol / 10),
          sprintf("largest accepted %s, need at most tol / 10 = %s", fmt(num_max(acc)), fmt(tol / 10))
        ),
        chk(
          "far-run margin", isTRUE(length(far) > 0 && min(far) >= 10 * tol && !anyNA(d$dist[trunc])),
          sprintf(
            "%d truncated runs beyond distance %s, smallest %s, need at least 10 * tol = %s; %d without distance",
            length(far), fmt(cut), if (length(far)) fmt(min(far)) else "none", fmt(10 * tol), sum(is.na(d$dist[trunc]))
          )
        ),
        chk(
          "truncated above tol", isTRUE(any(trunc) && all(d$dec[trunc] > tol)),
          sprintf("%d finite truncated runs, %d at or below tol = %s", sum(trunc), sum(d$dec[trunc] <= tol), fmt(tol))
        )
      )
    },
    reliability = {
      ship <- d$algo == "SLSQP" & d$precond %in% TRUE
      retry <- ship & d$mode == "retry"
      rate <- if (any(retry)) mean(d$match[retry] %in% TRUE) else NA_real_
      stalled <- sum(ship & d$gate_accepts %in% TRUE & d$class == "native_stalled")
      nsc <- sum(ship & d$class == "no_start_converged")
      errs <- sum(d$class == "error", na.rm = TRUE)
      rbind(
        chk("rows", nrow(d) == s$expected_rows, sprintf("%d rows, expected %d (REPS=100)", nrow(d), s$expected_rows)),
        chk("worker errors", errs == 0, sprintf("%d class = error rows", errs)),
        chk(
          "match rate (shipped config, retry)", isTRUE(rate >= s$min_pass),
          sprintf("%.4f, need at least %.3f over %d runs", rate, s$min_pass, sum(retry))
        ),
        chk("gate-accepted stalled fits (shipped config)", stalled == 0, sprintf("%d", stalled)),
        chk("no_start_converged (shipped config)", nsc == 0, sprintf("%d", nsc))
      )
    },
    "s7-lifecycle" = {
      # T1b: install, load, use, unload and reload in a fresh process against each S7 library; no step may fail
      bad <- d$step[!(d$ok %in% TRUE)]
      vers <- unique(d$s7_version[d$s7 == "release"])
      main_vers <- unique(d$s7_version[d$s7 == "main"])
      rbind(
        rows_chk(d, s),
        chk(
          "steps", length(bad) == 0 && !anyNA(d$ok),
          sprintf("%d failed or missing: %s", length(bad), paste(unique(bad), collapse = ", "))
        ),
        chk("both S7 libraries", setequal(d$s7, c("release", "main")), paste(unique(d$s7), collapse = ", ")),
        chk(
          "two different S7 versions", length(vers) == 1 && length(main_vers) == 1 && !anyNA(c(vers, main_vers)) &&
            vers != main_vers,
          sprintf("release %s, main %s", paste(vers, collapse = ","), paste(main_vers, collapse = ","))
        )
      )
    },
    "bootstrap-coverage" = {
      # 0.11.0 T6c: the coverage of the 95% parametric-bootstrap interval lies in [min_pass, tol_est] (the nominal 0.95
      # plus or minus four Monte Carlo SEs at 2000 data sets); the script applies the same band
      cov <- mean(d$hit %in% TRUE)
      rbind(
        rows_chk(d, s),
        chk(
          "no missing interval", !anyNA(d$lower) && !anyNA(d$upper) && !anyNA(d$hit),
          sprintf("%d NA hit", sum(is.na(d$hit)))
        ),
        chk("coverage in band", cov >= s$min_pass && cov <= s$tol_est,
            sprintf("%.4f, band [%s, %s]", cov, s$min_pass, s$tol_est))
      )
    },
    "fixed-x" = {
      # 0.9.0 V9: every check the script makes is a row; each must pass, and each kind of check must have run
      kinds <- c("fit", "estimates", "SEs", "df", "npar", "chisq", "accepted", "paths", "logLik",
                 "non-exogenous fixed_x name refused", "AIC across different fixed sets refused")
      missing_kind <- setdiff(kinds, d$check)
      # T5e: the lavaan-only checks (chi-square, the conditional logLik) must be present, not skipped
      lav_rows <- d[d$check == "chisq" | d$tag == "lavaan", , drop = FALSE]
      rbind(
        rows_chk(d, s),
        chk("checks pass", all(d$pass %in% TRUE), sprintf("%d of %d fail", bool_fail(d$pass), nrow(d))),
        chk("lavaan checks ran", nrow(lav_rows) > 0 && any(d$tag == "lavaan") && all(lav_rows$pass %in% TRUE),
            sprintf("%d lavaan rows", nrow(lav_rows))),
        chk("every kind ran", !length(missing_kind),
            if (length(missing_kind)) paste("missing:", paste(missing_kind, collapse = ", ")) else "all 11 kinds")
      )
    },
    "mean-constrained" = {
      # 0.9.0 S5 (Checkpoint B): the rule of tests/sim/sem-mean-constrained-gate.R re-applied to its CSV
      inv <- d$invariance[!is.na(d$invariance)]
      lav <- d$lavaan_ok[!is.na(d$lavaan_ok)]
      # the script compares every converged unshifted non-zero-problem fit with lavaan (the others stay NA): a run
      # that skipped some comparisons is not a smaller pass (Codex R4 finding)
      lav_eligible <- sum(d$ok %in% TRUE & d$shift == 0 & d$problem != "zero")
      rbind(
        rows_chk(d, s),
        chk("converged", all(d$ok %in% TRUE), sprintf("%d of %d fits fail", bool_fail(d$ok), nrow(d))),
        max_chk("feasibility", d$feas[!is.na(d$feas)], 1e-6),
        chk("location invariance", length(inv) > 0 && all(inv <= 1),
            sprintf("%d pairs, worst ratio %s (limit 1)", length(inv), fmt(num_max(inv)))),
        chk("lavaan parity", length(lav) > 0 && length(lav) == lav_eligible && all(lav %in% TRUE),
            sprintf("%d of %d eligible runs compared, %d bad", length(lav), lav_eligible, sum(!(lav %in% TRUE))))
      )
    },
    "nonlinear-parity" = {
      # T19 (G6): the rule of tests/sim/sem-nonlinear-gate.R re-applied to its CSV. The `sum` problem is best-effort
      # (its hit rate is reported, never gated, G12); the script's bootstrap SE cross-check is not in the CSV, so
      # --sim covers it through the child's exit status.
      g <- d[d$problem != "sum", , drop = FALSE]
      ran <- g$omx_ok %in% TRUE
      eqz <- g[g$problem %in% c("eq", "zero") & ran, , drop = FALSE]
      ineq <- g[g$problem == "ineq" & ran, , drop = FALSE]
      se_all <- d[d$problem %in% c("eq", "ineq"), , drop = FALSE]
      se_runs <- se_all[se_all$se_oracle %in% TRUE, , drop = FALSE]
      act <- g[!is.na(g$ann), , drop = FALSE]
      rbind(
        rows_chk(d, s),
        chk(
          "native fits", all(g$native_ok %in% TRUE),
          sprintf("%d of %d gated runs failed", bool_fail(g$native_ok), nrow(g))
        ),
        chk("improper runs", !any(g$improper %in% TRUE), sprintf("%d improper", sum(g$improper %in% TRUE))),
        max_chk("feasibility", g$feas, 1e-6),
        chk(
          "oracle ran", mean(ran) >= s$min_pass,
          sprintf("%.3f of gated runs, need %s", mean(ran), s$min_pass)
        ),
        chk(
          "never worse (eq, zero)", nrow(eqz) > 0 && all(eqz$f_gap <= 1e-8),
          sprintf("max f_gap %s over %d runs", fmt(num_max(eqz$f_gap)), nrow(eqz))
        ),
        chk(
          "ineq best branch", nrow(ineq) > 0 && mean(ineq$f_gap <= 1e-8) >= s$min_pass,
          sprintf("%.3f over %d runs", mean(ineq$f_gap <= 1e-8), nrow(ineq))
        ),
        max_chk("estimates vs OpenMx", g$est_gap[!is.na(g$est_gap)], 1e-4),
        max_chk("estimates vs reparameterized fit", g$ref_gap[!is.na(g$ref_gap)], s$tol_est),
        chk(
          "Jacobian annihilates covariance", nrow(act) > 0 && all(act$ann <= 1e-8),
          sprintf("max %s over %d active runs", fmt(num_max(act$ann)), nrow(act))
        ),
        chk(
          "SEs vs reparameterized fit", nrow(se_runs) >= 0.5 * nrow(se_all) && all(se_runs$se_rel <= s$tol_se),
          sprintf(
            "%d of %d runs compared, max %s, limit %s",
            nrow(se_runs), nrow(se_all), fmt(num_max(se_runs$se_rel)), fmt(s$tol_se)
          )
        )
      )
    },
    factor = {
      # T4: the factor gate applies its own per-run rule (twin, names, lavaan, fitstats, moments, refit, lost cells,
      # product cells) and writes one `pass` per run; the driver re-checks the count, every pass and every error
      errs <- sum(nzchar(ifelse(is.na(d$err), "", as.character(d$err))))
      lav_cells <- d[d$fxmode %in% c("free", "all"), , drop = FALSE]
      rbind(
        rows_chk(d, s),
        chk("passing runs", all(d$pass %in% TRUE), sprintf("%d of %d fail", sum(!(d$pass %in% TRUE)), nrow(d))),
        chk("errors", errs == 0, sprintf("%d runs with an error message", errs)),
        # T5e (Codex review): a run that skipped lavaan has NA here and must not count as parity
        chk(
          "lavaan checks ran", nrow(lav_cells) > 0 && all(lav_cells$lavaan %in% TRUE & lav_cells$fitstats %in% TRUE),
          sprintf(
            "%d free/all cells, %d without a passing lavaan and fit-statistic check", nrow(lav_cells),
            sum(!(lav_cells$lavaan %in% TRUE & lav_cells$fitstats %in% TRUE))
          )
        )
      )
    },
    "oracle-sweep" = {
      # Layer 4: warnings flag uncertainty, and fit errors count as refusals; only unflagged wrong fits fail.
      errors <- nzchar(ifelse(is.na(d$error), "", as.character(d$error))) & d$outcome != "refused"
      bad <- !(d$outcome %in% c("correct", "flagged", "refused"))
      wrong <- sum(d$outcome == "WRONG", na.rm = TRUE)
      rbind(
        rows_chk(d, s),
        chk("outcomes", !any(bad), sprintf("%d WRONG, %d missing or unknown", wrong, sum(bad) - wrong)),
        chk("non-refusal errors", !any(errors), sprintf("%d errors outside refusals", sum(errors, na.rm = TRUE)))
      )
    },
    "compare-lr" = {
      # Issue 249 T5: the comparison never mislabels; upstream reproduction is recorded, not gated
      rbind(
        rows_chk(d, s),
        chk("no mislabel", !any(d$mislabel %in% TRUE) && all(d$pass %in% TRUE),
            sprintf("%d of %d rows mislabeled or failed", sum(!(d$pass %in% TRUE)), nrow(d))),
        chk("both engines ran", all(c("lavaan", "openmx") %in% d$engine), paste(unique(d$engine), collapse = ", ")),
        chk("returned", !any(d$verdict %in% "error"), sprintf("%d rows with an error", sum(d$verdict %in% "error"))),
        chk("reference matches the closed form", all(d$ref_ok %in% TRUE),
            sprintf("%d rows off", sum(!(d$ref_ok %in% TRUE)))),
        chk("unresolved only after a failed run", !any(d$verdict %in% "unresolved" & d$all_converged %in% TRUE),
            sprintf("%d unresolved rows with every run converged",
                    sum(d$verdict %in% "unresolved" & d$all_converged %in% TRUE)))
      )
    },
    "nonlinear-profile" = {
      # T3 (#213): every fit reaches the independent oracle's constrained optimum (the gate script applies the
      # per-run rule; the driver re-checks the counts and the largest gap)
      rbind(
        rows_chk(d, s), failed_chk(d),
        max_chk("oracle gap", d$gap, s$tol_est),
        chk("floor cases warn", all(d$native_ok[d$fixture %in% "var-1e6-1e-6"] %in% TRUE), "var-1e6-1e-6 rows"),
        # #276: the driver recomputes the signed difference from the recorded numbers, so a planted disproof or a
        # lying label (note, disproved, native_ok) cannot pass. A returned floor row needs finite lr and lr_oracle.
        chk("floor rows carry numbers", floor_numbers_ok(d), "returned floor rows need finite lr and lr_oracle"),
        chk("floor no disproof", floor_disproved(d) == 0L,
            sprintf("%d floor rows with lr above the floored oracle or below it", floor_disproved(d))),
        chk("floor labels agree", floor_labels_ok(d), "note, disproved and native_ok match lr - lr_oracle"),
        # the cases that carry the contract must return a numerical result: q = q_hat (the MLE) and q = 0 (exact
        # nulls) are strict rows, never refused or merely flagged; the zero row meets its constraint to 1e-7
        # all() over an empty set is TRUE, so the critical-row checks below would pass if the rows were missing: the
        # fixture must carry exactly one row for each of its six q values
        chk("floor rows complete", floor_rows_complete(d), "var-1e6-1e-6 needs exactly one row per q_tag"),
        chk("floor critical rows strict",
            all(d$note[d$fixture %in% "var-1e6-1e-6" & d$q_tag %in% c("qhat", "zero")] %in% "strict"),
            "q_hat and zero floor rows must be strict"),
        chk("floor zero residual", all(abs(d$q_ach[d$fixture %in% "var-1e6-1e-6" & d$q_tag %in% "zero"]) <= 1e-7),
            "zero floor row meets a * b / sqrt(...) = 0 to 1e-7"),
        # a flagged or refused row is allowed on some CPUs, but not for most of the fixture
        chk("floor strict share", mean(d$note[d$fixture %in% "var-1e6-1e-6"] %in% "strict") >= 0.5,
            sprintf("%d of %d floor rows meet the strict contract",
                    sum(d$note[d$fixture %in% "var-1e6-1e-6"] %in% "strict"), sum(d$fixture %in% "var-1e6-1e-6")))
      )
    },
    "native-defaults" = {
      # 0.14.0 T8a/T8b (R-12): every pass/fail row is re-derived from the recorded diff and tolerance, a declared row
      # needs a reason, every cell ran under its combinations and the unset fit, and the unset fit equals
      # the explicit fit
      need_cells <- c("simple", "weights", "fixed_intercept", "constrained_intercepts", "latent", "subset")
      combos <- c("fx=FALSE ms=NULL", "fx=FALSE ms=TRUE", "fx=TRUE ms=NULL", "fx=TRUE ms=TRUE", "unset")
      judged <- d$status %in% c("pass", "fail")
      ok <- !is.na(d$diff) & !is.na(d$tol) & d$diff <= d$tol
      lie <- judged & (d$status == "pass") != ok
      declared <- d$status %in% c("limit", "block")
      have <- paste(d$cell, d$combo)
      core <- need_cells[need_cells != "subset"]
      # T8b cells: product (four-way, plus the named subset that leaves the product free), factor (fixed_x = "g"),
      # lenient (the unset fit leaves a variable with a statement free); each unset also checks the resolved set
      t8b <- c(paste("product", c(combos, "fx=x,c ms=TRUE")),
               paste("factor", c(combos, "fx=g ms=NULL", "fx=g ms=TRUE")),
               paste("lenient", c("fx=FALSE ms=TRUE", "fx=x ms=TRUE", "unset")))
      miss <- setdiff(c(as.vector(outer(core, combos, paste)), paste("subset", c("fx=c ms=NULL", "fx=c ms=TRUE")), t8b),
                      have)
      unset_cells <- c(core, "product", "factor", "lenient")
      same <- d[d$quantity == "same_as_explicit", , drop = FALSE]
      set <- d[d$quantity == "same_as_explicit:fixed_x", , drop = FALSE]
      rbind(
        rows_chk(d, s),
        chk("known status", all(judged | declared), sprintf("%d rows with another status", sum(!(judged | declared)))),
        chk("no failed comparison", !any(d$status == "fail"), sprintf("%d fail", sum(d$status == "fail"))),
        chk("status re-derived", !any(lie), sprintf("%d rows whose status disagrees with diff <= tol", sum(lie))),
        chk("declared rows give a reason", all(nzchar(d$reason[declared]) & !is.na(d$reason[declared])),
            sprintf("%d limit, %d block", sum(d$status == "limit"), sum(d$status == "block"))),
        chk("every cell and combination ran", !length(miss),
            if (length(miss)) paste("missing:", paste(miss, collapse = "; ")) else "all"),
        chk("unset equals the explicit fit", nrow(same) == length(unset_cells) && all(same$status == "pass"),
            sprintf("%d unset identity rows", nrow(same))),
        chk("unset resolves the expected subset", nrow(set) == 3L && all(set$status == "pass"),
            sprintf("%d resolved-set rows (product, factor, lenient)", nrow(set)))
      )
    },
    # ADR D-13: semopy counts only where it agrees with lavaan; each status is re-derived from the recorded gaps, and
    # a pass floor keeps an all-disputed run from passing. Every row n/a (no uv) is a skip, except in qc-monthly.
    semopy = so_gate_checks(d, s), # nolint: object_usage_linter.
    restoration = {
      # restoration-bound T5/T6 (G12): every check of the script is a row; the numeric verdicts are re-derived from the
      # recorded numbers, so a row that claims pass over a bad number cannot pass. tol_est is k, tol_se the margin.
      need <- c("allowance matches the normal-equations value", "scale of a row does not change the allowance",
                "a duplicated row does not change the allowance", "rank zero fails closed",
                "a far worse restoration is refused", "boundary: accepted at k = rho / 0.9",
                "boundary: refused at k = rho / 1.1", "the curvature term decides a case",
                "no restoration the old code kept is refused by the cap",
                "separation: k keeps its margin over the largest legitimate rho",
                "basin gap: the cap stays below the nearest inferior basin", "restoration attempts observed")
      miss <- setdiff(need, d$check)
      val <- function(x) d$value[d$check == x][1L]
      lim <- function(x) d$limit[d$check == x][1L]
      tol3 <- need[1:3]
      sep <- val(need[10])
      gap_v <- val(need[11])
      gap_l <- lim(need[11])
      rbind(
        rows_chk(d, s),
        chk("checks pass", all(d$pass %in% TRUE), sprintf("%d of %d fail", bool_fail(d$pass), nrow(d))),
        chk("every check present", !length(miss),
            if (length(miss)) paste("missing:", paste(miss, collapse = "; ")) else "all 12"),
        chk("planted tolerances", all(vapply(tol3, function(x) isTRUE(val(x) <= lim(x)), TRUE)),
            "hand value 1e-8, scale and duplicate-row invariance 1e-6"),
        chk("far-worse restoration is far above the cap", isTRUE(val(need[5]) > 100),
            sprintf("rise = %s x k * allowance", fmt(val(need[5])))),
        chk("curvature decides", isTRUE(val(need[8]) > lim(need[8])), sprintf("%s", fmt(val(need[8])))),
        chk("the cap refuses no restoration the old code kept", isTRUE(val(need[9]) == 0),
            sprintf("%s refused", fmt(val(need[9])))),
        chk("separation re-derived (k over margin)", is.na(sep) || isTRUE(sep <= s$tol_est / s$tol_se),
            sprintf("largest legitimate rho %s, k / margin = %s", fmt(sep), fmt(s$tol_est / s$tol_se))),
        chk("basin gap re-derived", is.na(gap_v) || is.na(gap_l) || isTRUE(gap_v < gap_l),
            sprintf("cap %s, nearest inferior basin %s", fmt(gap_v), fmt(gap_l)))
      )
    },
    # product-term and four-way gates: the rules live in tests/sim/product-gate-common.R
    product_gate_rules[[gate]](d, s) # nolint: object_usage_linter.
  )
}

# Floor-fixture helpers (#276 slice 1): rows of var-1e6-1e-6 that returned a fit (not a refusal) carry lr and lr_oracle.
floor_returned <- function(d) d$fixture %in% "var-1e6-1e-6" & !(d$note %in% "refused")
floor_tol <- function(d) ifelse(d$q_tag %in% "zero", 1e-5, 1e-6) * pmax(1, d$lr_oracle)
floor_tags <- c("qhat", "qhat-0.1", "qhat+0.05", "qhat+0.2", "-qhat", "zero")
floor_rows_complete <- function(d) {
  tags <- d$q_tag[d$fixture %in% "var-1e6-1e-6"]
  length(tags) == length(floor_tags) && setequal(tags, floor_tags)
}
floor_numbers_ok <- function(d) {
  r <- floor_returned(d)
  all(is.finite(d$lr[r]) & is.finite(d$lr_oracle[r]))
}
floor_diff <- function(d) {
  r <- floor_returned(d)
  ifelse(r & is.finite(d$lr) & is.finite(d$lr_oracle), d$lr - d$lr_oracle, NA_real_)
}
floor_disproved <- function(d) {
  df <- floor_diff(d)
  sum(!is.na(df) & abs(df) > floor_tol(d))
}
floor_labels_ok <- function(d) {
  df <- floor_diff(d)
  r <- floor_returned(d)
  off <- !is.na(df) & df > floor_tol(d) # disproved
  strict <- d$note %in% "strict"
  all(
    !(strict & r & (is.na(df) | abs(df) > floor_tol(d))), # strict needs agreement
    !(r & !is.na(df) & (d$disproved %in% TRUE) != off), # the disproved column is the numeric verdict
    !(r & !is.na(df) & off & d$native_ok %in% TRUE) # a disproved row cannot pass
  )
}

# Run one gate script as a child process; its output goes to <dir>/gates-<script>.log.
run_child <- function(script, dir) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  log <- file.path(dir, sprintf("gates-%s.log", sub("\\.R$", "", basename(script))))
  t0 <- Sys.time()
  status <- suppressWarnings(system2("Rscript", script, stdout = log, stderr = log))
  list(script = script, status = status, start = t0, log = log)
}
# Each distinct script runs once (the constrained and stationarity gates share sem-constrained-gate.R).
run_scripts <- function(spec, script_of, dir) {
  to_run <- unique(script_of[spec$gate])
  stats::setNames(lapply(to_run, function(sc) {
    cat(sprintf("running %s ...\n", sc))
    run_child(sc, dir)
  }), to_run)
}

# runs (--sim only): the child records from run_scripts; adds the exit-status check and the freshness bound.
run_verdicts <- function(spec, dir, max_age, runs = NULL, script_of = scripts) {
  out <- list()
  for (i in seq_len(nrow(spec))) {
    s <- spec[i, ]
    run <- if (is.null(runs)) NULL else runs[[script_of[[s$gate]]]]
    ld <- load_results(dir, s$results_prefix, max_age, not_before = run$start,
                       undated = s$gate == "oracle-sweep")
    r <- if (!ld$ok) chk("results file", FALSE, ld$why) else verdict_gate(s$gate, ld$data, s)
    if (!is.null(run)) {
      st <- chk(
        "script exit status", identical(as.integer(run$status), 0L),
        sprintf("%s exited %s (log: %s)", run$script, run$status, run$log)
      )
      r <- rbind(st, r)
    }
    f <- if (is.null(ld$file)) NA_character_ else ld$file
    out[[i]] <- cbind(gate = s$gate, file = f, r, stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

print_verdicts <- function(v) {
  for (g in unique(v$gate)) {
    x <- v[v$gate == g, ]
    cat(sprintf("\n%-13s %s  [%s]\n", g, if (all(x$pass)) "PASS" else "FAIL", x$file[1]))
    for (j in seq_len(nrow(x))) {
      cat(sprintf("  %-4s %-44s %s\n", if (x$pass[j]) "ok" else "FAIL", x$check[j], x$detail[j]))
    }
  }
}

# ---- --mutants: the driver must reject results that a script would write with exit status 0 ----
mutate <- function(gate, kind, d) {
  if (kind == "tolerance") {
    if (gate == "parity") {
      d$est_gap[1:5] <- 1e-3
      d$se_rel[1:5] <- 1e-1
    }
    if (gate == "constrained") d$est_gap[1:3] <- 1e-3
    if (gate == "se") d$rel_obs[1:3] <- 1
    if (gate == "stationarity") d$dec[d$kind == "accepted"][1:3] <- 0.5
    if (gate == "reliability") {
      ship <- which(d$algo == "SLSQP" & d$precond %in% TRUE & d$mode == "retry")
      d$match[ship[1:60]] <- FALSE
    }
  }
  if (kind == "tolerance") {
    if (gate %in% c("product-null", "product-null-colon")) d$reject05[1] <- 0.5
    if (gate %in% c("product-fixed-var", "product-fixed-var-colon")) {
      d$reject05[which(d$expect == "calibrated")[1]] <- 0.5
    }
    if (gate %in% c("product-corr", "product-corr-colon")) d$gap[which(d$expect == "match")[1:3]] <- 1e-2
    if (gate == "four-way-kat") d$bias_z[1:3] <- 9
    if (gate == "s7-lifecycle") d$s7_version[d$s7 == "main"] <- d$s7_version[d$s7 == "release"][1]
    if (gate == "nonlinear-profile") d$gap[1:3] <- 1
    if (gate == "nonlinear-parity") d$ref_gap[which(d$problem == "eq")[1:3]] <- 1e-3
    if (gate == "fixed-x") d$pass[which(d$check == "estimates")[1:3]] <- FALSE
    if (gate == "bootstrap-coverage") d$hit[1:200] <- FALSE
    if (gate == "mean-constrained") d$invariance[which(!is.na(d$invariance))[1:3]] <- 5
    if (gate == "factor") d$pass[1:3] <- FALSE
    if (gate == "oracle-sweep") d$outcome[1] <- "WRONG"
    if (gate == "native-defaults") d$diff[which(d$status == "pass")[1:3]] <- 1 # status still says pass
    if (gate == "semopy") d$est_gap[which(d$status == "pass")[1:3]] <- 1e-3 # status still says pass
    if (gate == "compare-lr") {
      d$mislabel[1:3] <- TRUE
      d$pass[1:3] <- FALSE
    }
    if (gate == "restoration") {
      # the recorded numbers say fail while the pass column still says TRUE
      d$value[grepl("^separation", d$check)] <- 100
      d$value[d$check == "allowance matches the normal-equations value"] <- 1
    }
  }
  if (kind == "no_lavaan") {
    # T5e: what a run without lavaan used to write: its lavaan-only checks absent or NA, everything else passing
    if (gate == "factor") {
      d$lavaan[d$fxmode %in% c("free", "all")] <- NA
      d$fitstats[d$fxmode %in% c("free", "all")] <- NA
    }
    if (gate == "fixed-x") d <- d[!(d$check == "chisq" | d$tag == "lavaan"), , drop = FALSE]
    if (gate == "mean-constrained") d$lavaan_ok <- NA
  }
  if (kind == "lavaan_partial") {
    # Codex R4: nearly every lavaan comparison skipped, one left: must not pass
    keep <- which(!is.na(d$lavaan_ok))[1L]
    d$lavaan_ok[-keep] <- NA
  }
  if (kind == "failed") {
    if (gate %in% c("product-null", "product-null-colon", "product-fixed-var", "product-fixed-var-colon",
                    "four-way-kat")) {
      d$reps_ok[1] <- 0
    }
    if (gate %in% c("product-corr", "product-corr-colon")) d$gap[1] <- NA_real_
    if (gate == "s7-lifecycle") d$ok[1] <- FALSE
    if (gate == "nonlinear-profile") d$native_ok[1] <- FALSE
    if (gate == "nonlinear-parity") d$native_ok[which(d$problem == "eq")[1]] <- FALSE
    if (gate == "fixed-x") d$pass[which(d$check == "fit")[1]] <- FALSE
    if (gate == "bootstrap-coverage") d$hit[1] <- NA
    if (gate == "mean-constrained") d$ok[1] <- FALSE
    if (gate == "factor") d$err[1] <- "fit failed"
    if (gate == "oracle-sweep") d$error[1] <- "fit failed"
    if (gate == "compare-lr") d$verdict[1] <- "error"
    if (gate == "native-defaults") d$status[1] <- "fail"
    if (gate == "semopy") d$status[1] <- "error"
    if (gate == "restoration") d$pass[1] <- FALSE
  }
  if (kind == "all_flagged" && gate == "nonlinear-profile") d$note[d$fixture %in% "var-1e6-1e-6"] <- "flagged"
  if (kind == "floor_disproved_silent" && gate == "nonlinear-profile") {
    # lr raised above the oracle while note, disproved and native_ok still claim a clean strict row
    d$lr[d$fixture %in% "var-1e6-1e-6"][1] <- d$lr[d$fixture %in% "var-1e6-1e-6"][1] + 5
  }
  if (kind == "floor_oracle_missing" && gate == "nonlinear-profile") {
    d$lr_oracle[d$fixture %in% "var-1e6-1e-6"] <- NA_real_
  }
  if (kind == "floor_note_lies" && gate == "nonlinear-profile") d$disproved[d$fixture %in% "var-1e6-1e-6"][1] <- TRUE
  if (kind == "floor_refuse_critical" && gate == "nonlinear-profile") {
    # the q_hat and zero floor rows refuse (note refused, no numbers): three refusals still pass the strict share
    i <- d$fixture %in% "var-1e6-1e-6" & d$q_tag %in% c("qhat", "zero", "-qhat")
    d$note[i] <- "refused"
    d$lr[i] <- NA_real_
    d$lr_oracle[i] <- NA_real_
  }
  if (kind == "floor_critical_missing" && gate == "nonlinear-profile") {
    # the q_hat and zero floor rows are replaced by copies of other floor rows: the total stays 144
    i <- which(d$fixture %in% "var-1e6-1e-6")
    src <- i[d$q_tag[i] %in% "qhat+0.2"]
    for (tag in c("qhat", "zero")) d[i[d$q_tag[i] %in% tag], ] <- d[src, ]
  }
  if (kind == "floor_zero_off" && gate == "nonlinear-profile") {
    d$q_ach[d$fixture %in% "var-1e6-1e-6" & d$q_tag %in% "zero"] <- 1e-4
  }
  if (kind == "unresolved_converged" && gate == "compare-lr") {
    d$verdict[1] <- "unresolved"
    d$all_converged[1] <- TRUE
  }
  if (kind == "ref_off" && gate == "compare-lr") d$ref_ok[1] <- FALSE
  if (kind == "scale_down" && gate == "stationarity") d$dec <- d$dec * 1e-6
  if (kind == "scale_up" && gate == "stationarity") d$dec <- d$dec * 1e6
  if (kind == "missing") {
    # the product-term and four-way gates have 2 to 84 rows: drop the last one, so only the row-count check can reject
    # nolint start: object_usage_linter.
    new_gate <- gate %in% c(
      names(product_gate_rules), "s7-lifecycle", "nonlinear-profile", "nonlinear-parity", "fixed-x",
      "mean-constrained", "factor", "bootstrap-coverage", "oracle-sweep", "compare-lr", "restoration",
      "native-defaults", "semopy"
    )
    # nolint end
    d <- if (new_gate) d[-nrow(d), , drop = FALSE] else d[-(1:7), , drop = FALSE]
  }
  if (kind == "failed") {
    if (gate %in% c("parity", "constrained", "se")) d$native_ok[1] <- FALSE
    if (gate == "stationarity") d$dec[d$kind == "accepted"][1] <- NA_real_
    if (gate == "reliability") d$class[1] <- "error"
  }
  d
}

run_mutants <- function() {
  ok_all <- TRUE
  for (i in seq_len(nrow(spec))) {
    s <- spec[i, ]
    ld <- load_results(results_dir, s$results_prefix, 1e9, undated = s$gate == "oracle-sweep")
    if (!ld$ok) {
      cat(sprintf("%-13s cannot run mutants: %s\n", s$gate, ld$why))
      ok_all <- FALSE
      next
    }
    ctrl <- all(verdict_gate(s$gate, ld$data, s)$pass)
    ctrl_msg <- if (ctrl) "passes, as it must" else "FAILS: the baseline itself is bad"
    cat(sprintf("%-13s control (unmutated committed results) %s\n", s$gate, ctrl_msg))
    ok_all <- ok_all && ctrl
    kinds <- c("tolerance", "missing", "failed")
    # a common rescaling of every decrement keeps the accepted/non-accepted ratio, so only the threshold
    # checks can reject it
    if (s$gate == "stationarity") kinds <- c(kinds, "scale_down", "scale_up")
    # the gates whose scripts need lavaan: a run that skipped its lavaan checks must be rejected (T5e)
    if (s$gate %in% c("factor", "fixed-x", "mean-constrained")) kinds <- c(kinds, "no_lavaan")
    if (s$gate == "mean-constrained") kinds <- c(kinds, "lavaan_partial")
    if (s$gate == "compare-lr") kinds <- c(kinds, "unresolved_converged", "ref_off")
    if (s$gate == "nonlinear-profile") {
      kinds <- c(kinds, "all_flagged", "floor_disproved_silent", "floor_oracle_missing", "floor_note_lies",
                 "floor_refuse_critical", "floor_zero_off", "floor_critical_missing")
    }
    for (kind in kinds) {
      v <- verdict_gate(s$gate, mutate(s$gate, kind, ld$data), s)
      rejected <- !all(v$pass)
      by <- if (rejected) paste0(" (", paste(v$check[!v$pass], collapse = "; "), ")") else ""
      cat(sprintf("%-13s %-10s mutation %s%s\n", "", kind, if (rejected) "rejected" else "NOT REJECTED", by))
      ok_all <- ok_all && rejected
    }
    # file-level: unreadable and stale
    tmp <- tempfile("gates-")
    dir.create(tmp)
    on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
    today_file <- if (s$gate == "oracle-sweep") file.path(tmp, paste0(s$results_prefix, ".csv")) else
      file.path(tmp, sprintf("%s-%s.csv", s$results_prefix, Sys.Date()))
    writeLines(c("\"a\",\"b\"", "1,2,3,\"unterminated"), today_file)
    bad <- load_results(tmp, s$results_prefix, max_age, undated = s$gate == "oracle-sweep")
    cat(sprintf("%-13s %-10s mutation %s\n", "", "unreadable", if (!bad$ok) "rejected" else "NOT REJECTED"))
    ok_all <- ok_all && !bad$ok
    old <- Sys.Date() - (max_age + 5)
    if (s$gate == "oracle-sweep") {
      utils::write.csv(ld$data, today_file, row.names = FALSE)
      Sys.setFileTime(today_file, as.POSIXct(old))
    } else {
      utils::write.csv(ld$data, file.path(tmp, sprintf("%s-%s.csv", s$results_prefix, old)), row.names = FALSE)
      unlink(today_file)
    }
    stale <- load_results(tmp, s$results_prefix, max_age, undated = s$gate == "oracle-sweep")
    cat(sprintf("%-13s %-10s mutation %s\n", "", "stale", if (!stale$ok) "rejected" else "NOT REJECTED"))
    ok_all <- ok_all && !stale$ok
  }
  cat("\n--sim path (stub gate scripts; the se gate's committed baseline is the passing CSV):\n")
  ok_all <- run_stub_mutants() && ok_all
  cat(
    "\nGate-owned mutants (planted defects inside the engine, for example the covariance-projection freeze):",
    "none registered yet; each gate task registers its own.\n"
  )
  ok_all
}

# Stub gate scripts run through the same run_scripts()/run_verdicts() code as --sim, in a scratch directory.
# crash: exits 1 without writing while an older passing CSV is the newest file. silent: exits 0 without
# writing; the passing CSV carries today's date but an old modification time. control: copies the passing CSV.
run_stub_mutants <- function() {
  s <- spec_all[spec_all$gate == "se", ]
  if (nrow(s) != 1L) {
    cat("se            cannot run stub cases: gates.csv has no unique 'se' row\n")
    return(FALSE)
  }
  ld <- load_results(results_dir, s$results_prefix, 1e9)
  if (!ld$ok) {
    cat(sprintf("%-13s cannot run stub cases: %s\n", s$gate, ld$why))
    return(FALSE)
  }
  tmp <- tempfile("gates-stub-")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  src <- file.path(tmp, "baseline.csv")
  utils::write.csv(ld$data, src, row.names = FALSE)
  # want: NULL for the control (every check must pass), else c(check, pattern) that must fail
  one_case <- function(name, body, stale_date, want = NULL) {
    dir <- file.path(tmp, name)
    dir.create(dir)
    script <- file.path(dir, "stub-gate.R")
    dest <- file.path(dir, sprintf("%s-%s.csv", s$results_prefix, Sys.Date()))
    writeLines(body(src, dest), script)
    old <- file.path(dir, sprintf("%s-%s.csv", s$results_prefix, as.Date(stale_date)))
    utils::write.csv(ld$data, old, row.names = FALSE)
    Sys.setFileTime(old, Sys.time() - 86400)
    runs <- run_scripts(s, c(se = script), dir)
    v <- run_verdicts(s, dir, max_age, runs, c(se = script))
    bad <- v[!v$pass, ]
    ok <- if (is.null(want)) all(v$pass) else any(bad$check == want[1] & grepl(want[2], bad$detail))
    shown <- if (is.null(want)) {
      if (ok) "passes, as it must" else "FAILS"
    } else if (ok) {
      "rejected"
    } else {
      "NOT REJECTED"
    }
    by <- if (nrow(bad)) paste0(" (", paste(bad$check, collapse = "; "), ")") else ""
    cat(sprintf("%-13s %-10s %s%s\n", "", name, shown, by))
    ok
  }
  copy_body <- function(src, dest) sprintf("file.copy(%s, %s, overwrite = TRUE)", deparse(src), deparse(dest))
  r <- c(
    one_case("crash", function(src, dest) "quit(status = 1L)", Sys.Date() - 1, c("script exit status", "exited 1")),
    one_case(
      "silent", function(src, dest) "invisible(NULL)", Sys.Date(),
      c("results file", "was not written by this run")
    ),
    one_case("control", copy_body, Sys.Date() - 1)
  )
  all(r)
}

# ---- --fast: unit tests and lint, with counts ----
child <- function(expr) {
  out <- suppressWarnings(system2("Rscript", c("-e", shQuote(expr)), stdout = TRUE, stderr = TRUE))
  out
}
run_fast <- function() {
  t_out <- child(paste(
    "suppressMessages(devtools::load_all(quiet = TRUE));",
    "r <- as.data.frame(testthat::test_local(filter = 'sem-', reporter = 'silent', stop_on_failure = FALSE));",
    "cat('COUNTS', sum(r$failed), sum(r$error), sum(r$skipped), sum(r$passed), '\\n')"
  ))
  tl <- grep("^COUNTS", t_out, value = TRUE)
  l_out <- child(paste(
    "suppressMessages(devtools::load_all(quiet = TRUE));",
    "cat('LINTS', length(lintr::lint_package()), '\\n');",
    "cat('STATTOL', format(.sem_stat_tol, digits = 15), '\\n');",
    "cat('RESTOREK', format(.sem_restore_k, digits = 15), '\\n')"
  ))
  ll <- grep("^LINTS", l_out, value = TRUE)
  tt <- grep("^STATTOL", l_out, value = TRUE)
  rk <- grep("^RESTOREK", l_out, value = TRUE)
  res <- list()
  if (length(tl) == 1L) {
    n <- as.numeric(strsplit(tl, " ")[[1]][-1])
    detail <- sprintf("%d passed, %d failed, %d errors, %d skipped", n[4], n[1], n[2], n[3])
    res[[1]] <- chk("unit tests (filter 'sem-')", n[1] == 0 && n[2] == 0, detail)
  } else {
    res[[1]] <- chk("unit tests (filter 'sem-')", FALSE, "no COUNTS line from the child process")
  }
  if (length(ll) == 1L) {
    n <- as.numeric(strsplit(ll, " ")[[1]][2])
    res[[2]] <- chk("lint (after load_all, same process)", n == 0, sprintf("%d lints", n))
  } else {
    res[[2]] <- chk("lint (after load_all, same process)", FALSE, "no LINTS line from the child process")
  }
  # gates.csv carries the stationarity threshold; it must not drift from the package constant
  gtol <- spec_all$tol_est[spec_all$gate == "stationarity"]
  ptol <- if (length(tt) == 1L) as.numeric(strsplit(tt, " ")[[1]][2]) else NA_real_
  res[[3]] <- chk(
    "gates.csv tol_est (stationarity) equals .sem_stat_tol", length(gtol) == 1L && isTRUE(gtol == ptol),
    sprintf("gates.csv %s, package %s", paste(format(gtol), collapse = ","), format(ptol))
  )
  # the restoration gate's k must not drift from the package constant either
  gk <- spec_all$tol_est[spec_all$gate == "restoration"]
  pk <- if (length(rk) == 1L) as.numeric(strsplit(rk, " ")[[1]][2]) else NA_real_
  res[[4]] <- chk(
    "gates.csv tol_est (restoration) equals .sem_restore_k", length(gk) == 1L && isTRUE(gk == pk),
    sprintf("gates.csv %s, package %s", paste(format(gk), collapse = ","), format(pk))
  )
  v <- do.call(rbind, res)
  cbind(gate = "fast", file = NA_character_, v, stringsAsFactors = FALSE)
}

scripts <- c(
  parity = "tests/sim/sem-parity-gate.R", constrained = "tests/sim/sem-constrained-gate.R",
  se = "tests/sim/sem-se-gate.R", stationarity = "tests/sim/sem-constrained-gate.R",
  reliability = "tests/sim/sem-reliability.R",
  "product-null" = "tests/sim/exo-product-null.R", "product-null-colon" = "tests/sim/exo-product-null-colon.R",
  "product-fixed-var" = "tests/sim/exo-product-fixed-var.R",
  "product-fixed-var-colon" = "tests/sim/exo-product-fixed-var-colon.R",
  "product-corr" = "tests/sim/product-correlated-residuals.R",
  "product-corr-colon" = "tests/sim/product-correlated-residuals-colon.R",
  "four-way-kat" = "tests/sim/four-way-known-answer.R",
  "s7-lifecycle" = "tests/sim/s7-lifecycle-gate.R",
  "nonlinear-profile" = "tests/sim/sem-nonlinear-profile-gate.R",
  "nonlinear-parity" = "tests/sim/sem-nonlinear-gate.R",
  "bootstrap-coverage" = "tests/sim/bootstrap-coverage.R",
  "fixed-x" = "tests/sim/sem-fixed-x-gate.R",
  "mean-constrained" = "tests/sim/sem-mean-constrained-gate.R",
  factor = "tests/sim/sem-factor-gate.R",
  "oracle-sweep" = "tests/sim/sem-oracle-sweep.R",
  "compare-lr" = "tests/sim/compare-lr-gate.R",
  restoration = "tests/sim/sem-restoration-gate.R",
  "native-defaults" = "tests/sim/native-defaults-oracle.R",
  semopy = "tests/sim/semopy-oracle-gate.R"
)

# ---- main ----
status_ok <- TRUE

if (has("--mutants")) {
  cat("Driver self-test: results that a script would write with exit status 0 but that are bad\n\n")
  status_ok <- run_mutants()
  cat(if (status_ok) {
    "\nMUTANTS: every mutation rejected, every control passes\n"
  } else {
    "\nMUTANTS: FAILED (see above)\n"
  })
} else {
  v_all <- NULL
  if (has("--fast")) {
    f <- run_fast()
    v_all <- rbind(v_all, f)
  }
  runs <- if (has("--sim")) run_scripts(spec, scripts, results_dir) else NULL
  if (has("--sim") || !has("--fast")) {
    v_all <- rbind(v_all, run_verdicts(spec, results_dir, max_age, runs))
  }
  print_verdicts(v_all)
  status_ok <- all(v_all$pass)
  cat(sprintf(
    "\nOVERALL: %s (%d of %d checks pass)\n",
    if (status_ok) "PASS" else "FAIL", sum(v_all$pass), nrow(v_all)
  ))
  dir.create(results_dir, showWarnings = FALSE)
  out <- sprintf("%s/gates-summary-%s.txt", results_dir, Sys.Date())
  utils::capture.output(print_verdicts(v_all), file = out)
  cat(sprintf("summary: %s\n", out))
}
quit(status = if (status_ok) 0L else 1L)
