# The semopy oracle gate (ADR D-13): pure-R pieces shared by the gate script (tests/sim/semopy-oracle-gate.R), the
# driver (tests/sim/run-gates.R) and the unit tests (tests/testthat/test-semopy-oracle.R). No Python is needed here
# except in so_run_semopy(), which calls tests/sim/semopy-oracle.py through uv.
#
# Counting rule (author decision 2026-10-26): semopy agrees with medfit only when semopy also agrees with lavaan. A
# parameter where semopy disagrees with lavaan is "disputed" and counts as neither a pass nor a fail; a gate-level
# floor (gates.csv min_pass) keeps a run where everything is disputed from passing with nothing tested.
# Statuses: pass, fail, disputed, unmatched (a parameter missing on one side), error (a fit failed), n/a (uv or semopy
# unavailable: every row of the run, and the gate skips unless MEDFIT_SEMOPY_REQUIRED=true, as in qc-monthly).

so_semopy_pin <- "semopy==2.3.11"
so_statuses <- c("pass", "fail", "disputed", "unmatched", "error", "n/a")

# ---- names: semopy's inspect() table -> medfit's lavaan-style names ----
# "eta =~ m1 + 1*m2" -> c("eta=~m1", "eta=~m2"); a label or fixed value before `*` is dropped
so_measurement_pairs <- function(model) {
  lines <- trimws(unlist(strsplit(model, "[\n;]")))
  lines <- lines[grepl("=~", lines, fixed = TRUE)]
  if (!length(lines)) return(character(0))
  unlist(lapply(strsplit(lines, "=~", fixed = TRUE), function(p) {
    ind <- trimws(strsplit(p[2], "+", fixed = TRUE)[[1]])
    paste0(trimws(p[1]), "=~", sub("^.*\\*", "", ind))
  }))
}

# canonical key: the two sides of a `~~` name in C-locale order (lavaan writes M1~~M2, semopy may write M2 ~~ M1)
so_key <- function(name) {
  cov <- grepl("~~", name, fixed = TRUE)
  name[cov] <- vapply(strsplit(name[cov], "~~", fixed = TRUE), function(p) {
    paste(sort(p, method = "radix"), collapse = "~~")
  }, "")
  name
}

# rows: lval, op, rval, estimate, se, fixed (semopy's "Std. Err" is "-" for a fixed parameter). semopy writes a
# loading as `indicator ~ latent`, the same shape as a regression on a latent (`Y ~ eta`); the model's `=~` lines
# decide which is which. Only rows semopy marks fixed are dropped: a free parameter with a missing SE stays and fails.
so_map_names <- function(rows, model) {
  rows <- rows[!(rows$fixed %in% TRUE), , drop = FALSE]
  pairs <- so_measurement_pairs(model)
  load <- paste0(rows$rval, "=~", rows$lval)
  name <- ifelse(rows$op == "~" & load %in% pairs, load, paste0(rows$lval, rows$op, rows$rval))
  data.frame(name = so_key(name), estimate = as.numeric(rows$estimate), se = as.numeric(rows$se),
             stringsAsFactors = FALSE)
}

# a named estimate vector and a named SE vector (medfit coef()/sqrt(diag(vcov())), lavaan coef()) as a name table
so_named <- function(est, se) {
  data.frame(name = so_key(names(est)), estimate = unname(est), se = unname(se[names(est)]),
             stringsAsFactors = FALSE)
}

# ---- the counting rule ----
so_status <- function(est_gap, se_rel, sl_est_gap, sl_se_rel, tol_est, tol_se) {
  within <- function(e, s) !is.na(e) & !is.na(s) & e <= tol_est & s <= tol_se
  ifelse(!within(sl_est_gap, sl_se_rel), "disputed", ifelse(within(est_gap, se_rel), "pass", "fail"))
}

# med, sem, lav: data frames name, estimate, se. One row per parameter on any side; a parameter missing on a side is
# "unmatched" (a mapping hole must fail, not drop out of the max).
so_compare <- function(med, sem, lav, tol_est, tol_se) {
  sides <- list(medfit = med, semopy = sem, lavaan = lav)
  sides <- lapply(sides, function(d) {
    d$name <- so_key(d$name)
    d
  })
  for (side in names(sides)) {
    duplicate <- unique(sides[[side]]$name[duplicated(sides[[side]]$name)])
    if (length(duplicate)) stop(side, " has duplicate parameter names: ", paste(duplicate, collapse = ", "),
                                call. = FALSE)
  }
  keys <- unique(unlist(lapply(sides, `[[`, "name")))
  pick <- function(side, col) sides[[side]][[col]][match(keys, sides[[side]]$name)]
  r <- data.frame(param = keys, est_medfit = pick("medfit", "estimate"), est_semopy = pick("semopy", "estimate"),
                  est_lavaan = pick("lavaan", "estimate"), se_medfit = pick("medfit", "se"),
                  se_semopy = pick("semopy", "se"), se_lavaan = pick("lavaan", "se"), stringsAsFactors = FALSE)
  r$est_gap <- abs(r$est_medfit - r$est_semopy)
  r$se_rel <- abs(r$se_medfit - r$se_semopy) / abs(r$se_semopy)
  r$sl_est_gap <- abs(r$est_semopy - r$est_lavaan)
  r$sl_se_rel <- abs(r$se_semopy - r$se_lavaan) / abs(r$se_lavaan)
  r$status <- so_status(r$est_gap, r$se_rel, r$sl_est_gap, r$sl_se_rel, tol_est, tol_se)
  present <- vapply(sides, function(d) keys %in% d$name, logical(length(keys)))
  present <- matrix(present, nrow = length(keys))
  miss <- !apply(present, 1L, all)
  r$status[miss] <- "unmatched"
  r$reason <- ""
  r$reason[miss] <- paste("missing in", apply(present[miss, , drop = FALSE], 1L, function(p) {
    paste(names(sides)[!p], collapse = ", ")
  }))
  r
}

# ---- uv and the Python runner ----
so_uv_lookup <- function() unname(Sys.which("uv"))
so_uv <- function(env = Sys.getenv("MEDFIT_UV")) {
  if (!nzchar(env)) return(so_uv_lookup())
  if (file.exists(env) && file.access(env, 1L) == 0L) env else ""
}
so_script <- function() {
  cands <- c(file.path("tests", "sim", "semopy-oracle.py"), file.path("..", "sim", "semopy-oracle.py"))
  hit <- cands[file.exists(cands)]
  if (length(hit)) normalizePath(hit[1]) else cands[1]
}

# Resolve the exact pinned environment before running the script. Only explicit uv diagnostics establish absence;
# cache locks, network failures, unknown diagnostics and Python import errors remain failures.
so_preflight <- function(uv, timeout = 900) {
  log <- tempfile("semopy-preflight-")
  on.exit(unlink(log), add = TRUE)
  status <- suppressWarnings(system2(
    uv, c("run", "--quiet", "--with", so_semopy_pin, "python", "-I", "-c", shQuote("import semopy")),
    stdout = log, stderr = log, timeout = timeout
  ))
  status <- as.integer(status)
  lines <- if (file.exists(log)) readLines(log, warn = FALSE) else character()
  if (identical(status, 0L)) return(list(ok = TRUE))
  missing_python <- identical(status, 2L) && any(grepl("^error: No interpreter found (at path|for)", lines))
  missing_package <- identical(status, 1L) &&
    any(grepl("^error: No solution found when resolving", lines)) &&
    any(grepl("was not found in the cache", lines, fixed = TRUE)) &&
    any(grepl("Packages were unavailable because the network was disabled", lines, fixed = TRUE))
  why <- paste(utils::tail(lines, 5L), collapse = " | ")
  list(ok = FALSE, unavailable = missing_python || missing_package,
       why = sprintf("semopy preflight exited %s: %s", status, why))
}

# jobs: data frame id, model (syntax text), data (CSV path). One uv call fits every job. Returns list(ok, why) on a
# run-level failure, else list(ok = TRUE, rows, versions): rows carry id, fit_ok, error, lval, op, rval, estimate,
# se, fixed, and one row per failed job (fit_ok FALSE) with the error text.
so_run_semopy <- function(jobs, uv = so_uv(), timeout = 900, script = so_script()) {
  checkmate::assert_data_frame(jobs, min.rows = 1L)
  checkmate::assert_names(names(jobs), must.include = c("id", "model", "data"))
  checkmate::assert_string(uv)
  if (!nzchar(uv)) return(list(ok = FALSE, unavailable = TRUE,
                               why = "uv not found (install uv or set MEDFIT_UV): semopy rows are n/a"))
  preflight <- so_preflight(uv, timeout)
  if (!preflight$ok) return(preflight)
  dir <- tempfile("semopy-")
  dir.create(dir)
  model_file <- file.path(dir, paste0("model-", seq_len(nrow(jobs)), ".txt"))
  for (i in seq_len(nrow(jobs))) writeLines(jobs$model[i], model_file[i])
  spec <- data.frame(id = jobs$id, model_file = model_file, data = normalizePath(jobs$data, mustWork = FALSE))
  spec_csv <- file.path(dir, "jobs.csv")
  out_csv <- file.path(dir, "out.csv")
  log <- file.path(dir, "semopy.log")
  utils::write.csv(spec, spec_csv, row.names = FALSE)
  status <- suppressWarnings(system2(
    uv, c("run", "--quiet", "--with", so_semopy_pin, "python", "-I", shQuote(script), shQuote(spec_csv),
          shQuote(out_csv)),
    stdout = log, stderr = log, timeout = timeout
  ))
  tail_log <- if (file.exists(log)) paste(utils::tail(readLines(log, warn = FALSE), 5L), collapse = " | ") else ""
  status <- as.integer(status)
  if (identical(status, 124L)) return(list(ok = FALSE, unavailable = FALSE,
                                           why = sprintf("semopy runner timed out after %d s", timeout)))
  if (identical(status, 127L)) return(list(ok = FALSE, unavailable = FALSE,
                                           why = sprintf("could not start %s: %s", uv, tail_log)))
  if (!identical(status, 0L) || !file.exists(out_csv)) {
    return(list(ok = FALSE, unavailable = FALSE, why = sprintf("semopy runner exited %s: %s", status, tail_log)))
  }
  rows <- utils::read.csv(out_csv, stringsAsFactors = FALSE, na.strings = c("NA", ""))
  ver <- c("semopy", "python", "numpy", "scipy", "pandas")
  list(ok = TRUE, rows = rows, versions = vapply(ver, function(v) as.character(rows[[v]][1]), ""))
}

# An absent optional dependency may skip only if the other fits succeeded; unexpected subprocess failures are errors.
so_runner_status <- function(result, sides_ok = TRUE) {
  if (isTRUE(result$unavailable) && isTRUE(sides_ok)) "n/a" else "error"
}

# Keep errors from the other fits even when semopy is unavailable.
so_failed_runner_rows <- function(med, lav, result, tol_est, tol_se) {
  sides_ok <- vapply(list(med, lav), is.data.frame, TRUE)
  empty <- data.frame(name = character(), estimate = numeric(), se = numeric())
  m <- if (sides_ok[1]) med else empty
  l <- if (sides_ok[2]) lav else empty
  if (!nrow(m) && !nrow(l)) {
    placeholder <- data.frame(name = "<fit failed>", estimate = NA_real_, se = NA_real_)
    rows <- so_compare(placeholder, placeholder, placeholder, tol_est, tol_se)
  } else {
    rows <- so_compare(m, l, l, tol_est, tol_se)
  }
  rows$status <- so_runner_status(result, sides_ok = all(sides_ok))
  errs <- c(medfit = if (!sides_ok[1]) med, lavaan = if (!sides_ok[2]) lav)
  rows$reason <- paste(c(result$why, if (length(errs)) paste(names(errs), errs, sep = ": ")), collapse = "; ")
  rows
}

# ---- registration: monthly-only gates (kept out of the PR gates shards) ----
so_monthly_gates <- function(path = file.path("tests", "sim", "gates-monthly.txt")) {
  x <- trimws(sub("#.*$", "", readLines(path, warn = FALSE)))
  x[nzchar(x)]
}
so_drop_monthly <- function(spec, monthly, enabled) {
  if (enabled) spec else spec[!spec$gate %in% monthly, , drop = FALSE]
}

# ---- the driver's verdict, re-derived from the recorded gaps ----
so_gate_checks <- function(d, s, required = identical(Sys.getenv("MEDFIT_SEMOPY_REQUIRED"), "true")) {
  ck <- function(check, ok, detail) data.frame(check = check, pass = isTRUE(ok), detail = detail)
  fmt <- function(x) format(x, digits = 3, scientific = TRUE)
  n <- function(st) sum(d$status %in% st)
  out <- rbind(
    ck("rows", nrow(d) == s$expected_rows, sprintf("%d rows, expected %d", nrow(d), s$expected_rows)),
    ck("known status", all(d$status %in% so_statuses),
       sprintf("%d rows with another status", sum(!d$status %in% so_statuses)))
  )
  na <- d$status %in% "n/a"
  if (nrow(d) && all(na)) {
    why <- if ("reason" %in% names(d)) d$reason[1] else "semopy unavailable"
    detail <- if (required) {
      paste("semopy is required here (MEDFIT_SEMOPY_REQUIRED) but every row is n/a:", why)
    } else {
      paste("skipped: every row is n/a:", why)
    }
    return(rbind(out, ck("semopy available", !required, detail)))
  }
  judged <- d$status %in% c("pass", "fail", "disputed")
  re <- so_status(d$est_gap, d$se_rel, d$sl_est_gap, d$sl_se_rel, s$tol_est, s$tol_se)
  lie <- judged & re != d$status
  pass <- d$status == "pass"
  rbind(
    out,
    ck("n/a is all or nothing", !any(na), sprintf("%d n/a rows among judged rows", sum(na))),
    ck("status re-derived", !any(lie),
       sprintf("%d rows whose status disagrees with the gaps and tolerances", sum(lie))),
    ck("no failed comparison", n(c("fail", "error", "unmatched")) == 0,
       sprintf("%d fail, %d error, %d unmatched", n("fail"), n("error"), n("unmatched"))),
    ck("pass floor", sum(pass) >= s$min_pass,
       sprintf("%d pass, %d disputed, need at least %s pass; max est gap %s, max rel SE gap %s (pass rows)",
               sum(pass), n("disputed"), s$min_pass, fmt(max(c(0, d$est_gap[pass]))),
               fmt(max(c(0, d$se_rel[pass])))))
  )
}
