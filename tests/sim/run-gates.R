# Verification-harness driver for the native SEM gates (0.8.0 plan T3, Codex finding 1).
#
# Verdicts are computed from each gate's results CSV against the thresholds and expected row counts in
# tests/sim/gates.csv, never from a script's exit status: sem-parity-gate.R and sem-constrained-gate.R
# print PASS/FAIL lines and write their CSV without ever failing the process, and sem-reliability.R
# had no aggregate threshold and dropped worker errors, so a script can exit 0 with failed numerical
# checks. A result is rejected when it has a tolerance failure, a wrong (missing or extra) row count,
# a failed or errored run, or when the file is stale or unreadable.
#
# Modes (run from the package root):
#   Rscript tests/sim/run-gates.R                 verdicts on the latest committed results (default; fast)
#   Rscript tests/sim/run-gates.R --fast          unit tests (filter "sem-") and lint, with counts
#   Rscript tests/sim/run-gates.R --sim [--only parity,constrained]
#                                                 run the sim scripts (slow), then verdicts
#   Rscript tests/sim/run-gates.R --mutants       prove the driver rejects bad results: four
#                                                 "exits 0 but bad" mutations per gate plus a control
# Options: --max-age DAYS (default 14; older results are stale), --dir DIR (results directory).
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
spec <- utils::read.csv("tests/sim/gates.csv", stringsAsFactors = FALSE, na.strings = c("NA", ""))
if (!is.null(only)) spec <- spec[spec$gate %in% only, , drop = FALSE]

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
load_results <- function(dir, prefix, max_age_days) {
  pat <- sprintf("^%s-([0-9]{4}-[0-9]{2}-[0-9]{2})\\.csv(\\.gz)?$", prefix)
  files <- list.files(dir, pattern = pat)
  if (!length(files)) {
    return(list(ok = FALSE, why = sprintf("no results file matches '%s-<date>.csv' in %s", prefix, dir)))
  }
  dates <- as.Date(sub(pat, "\\1", files))
  f <- files[which.max(dates)]
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
  if (age > max_age_days) {
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
    stationarity = c("kind", "dec"),
    reliability = c("algo", "precond", "mode", "class", "gate_accepts", "match")
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
      acc <- d$dec[d$kind == "accepted"]
      oth <- d$dec[d$kind != "accepted" & is.finite(d$dec)]
      sep <- if (length(acc) && length(oth)) min(oth) / max(acc) else NA_real_
      rbind(
        rows_chk(d, s),
        chk(
          "accepted decrements", length(acc) > 0 && all(is.finite(acc)),
          sprintf("%d accepted rows, %d non-finite", length(acc), sum(!is.finite(acc)))
        ),
        chk(
          "separation", isTRUE(sep >= 10),
          sprintf("smallest finite non-accepted / largest accepted = %s, need at least 10", fmt(sep))
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
    }
  )
}

run_verdicts <- function() {
  all <- list()
  for (i in seq_len(nrow(spec))) {
    s <- spec[i, ]
    ld <- load_results(results_dir, s$results_prefix, max_age)
    r <- if (!ld$ok) chk("results file", FALSE, ld$why) else verdict_gate(s$gate, ld$data, s)
    r <- cbind(gate = s$gate, file = if (is.null(ld$file)) NA_character_ else ld$file, r, stringsAsFactors = FALSE)
    all[[i]] <- r
  }
  do.call(rbind, all)
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
  if (kind == "missing") d <- d[-(1:7), , drop = FALSE]
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
    ld <- load_results(results_dir, s$results_prefix, 1e9)
    if (!ld$ok) {
      cat(sprintf("%-13s cannot run mutants: %s\n", s$gate, ld$why))
      ok_all <- FALSE
      next
    }
    ctrl <- all(verdict_gate(s$gate, ld$data, s)$pass)
    ctrl_msg <- if (ctrl) "passes, as it must" else "FAILS: the baseline itself is bad"
    cat(sprintf("%-13s control (unmutated committed results) %s\n", s$gate, ctrl_msg))
    ok_all <- ok_all && ctrl
    for (kind in c("tolerance", "missing", "failed")) {
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
    today_file <- file.path(tmp, sprintf("%s-%s.csv", s$results_prefix, Sys.Date()))
    writeLines(c("\"a\",\"b\"", "1,2,3,\"unterminated"), today_file)
    bad <- load_results(tmp, s$results_prefix, max_age)
    cat(sprintf("%-13s %-10s mutation %s\n", "", "unreadable", if (!bad$ok) "rejected" else "NOT REJECTED"))
    ok_all <- ok_all && !bad$ok
    old <- Sys.Date() - (max_age + 5)
    utils::write.csv(ld$data, file.path(tmp, sprintf("%s-%s.csv", s$results_prefix, old)), row.names = FALSE)
    unlink(today_file)
    stale <- load_results(tmp, s$results_prefix, max_age)
    cat(sprintf("%-13s %-10s mutation %s\n", "", "stale", if (!stale$ok) "rejected" else "NOT REJECTED"))
    ok_all <- ok_all && !stale$ok
  }
  cat(
    "\nGate-owned mutants (planted defects inside the engine, for example the covariance-projection freeze):",
    "none registered yet; each gate task registers its own.\n"
  )
  ok_all
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
    "cat('LINTS', length(lintr::lint_package()), '\\n')"
  ))
  ll <- grep("^LINTS", l_out, value = TRUE)
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
  v <- do.call(rbind, res)
  cbind(gate = "fast", file = NA_character_, v, stringsAsFactors = FALSE)
}

scripts <- c(
  parity = "tests/sim/sem-parity-gate.R", constrained = "tests/sim/sem-constrained-gate.R",
  se = "tests/sim/sem-se-gate.R", stationarity = "tests/sim/sem-constrained-gate.R",
  reliability = "tests/sim/sem-reliability.R"
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
  if (has("--sim")) {
    to_run <- unique(scripts[spec$gate])
    for (sc in to_run) {
      cat(sprintf("running %s ...\n", sc))
      # exit status deliberately ignored: verdicts come from the CSV
      system2("Rscript", sc, stdout = FALSE, stderr = FALSE)
    }
  }
  if (has("--sim") || !has("--fast")) {
    v_all <- rbind(v_all, run_verdicts())
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
