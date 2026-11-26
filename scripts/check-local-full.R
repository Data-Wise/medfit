# Local full run: the local-only tier that hosted CI and CRAN no longer run.
#   tests/testthat/local-only-tests.txt  testthat files over ~300 s hosted (each starts with skip_unless_local())
#   tests/sim/gates-local-only.txt       simulation gates over ~300 s hosted (run-gates.R --local-only)
# Writes planning/local-full-runs/RECEIPT-<date>-<sha>.md (commit, list, pass counts, seconds) and exits 1 on any
# failure, error or missing result. Called by scripts/check-local-full.sh. Run from the package root.
# Options: --workers N (concurrent test files, default min(5, cores)), --tests-only, --gates-only, --dry-run (print the
# list, run nothing, write nothing), --receipt-dir DIR.

lf_read_list <- function(path) {
  x <- trimws(sub("#.*$", "", readLines(path, warn = FALSE)))
  x[nzchar(x)]
}

# One test file in its own R process; returns one row of counts and seconds.
lf_run_test_file <- function(f, out_dir) {
  out <- file.path(out_dir, paste0(sub("\\.R$", "", f), ".csv"))
  log <- file.path(out_dir, paste0(sub("\\.R$", "", f), ".log"))
  code <- paste(
    "suppressMessages(devtools::load_all(quiet = TRUE))",
    sprintf("r <- as.data.frame(testthat::test_file('tests/testthat/%s', reporter = 'summary', stop_on_failure = FALSE))", f),
    paste0("write.csv(data.frame(tests = nrow(r), expectations = sum(r$nb), failed = sum(r$failed), errors = sum(r$error), ",
           "skipped = sum(r$skipped), warnings = sum(r$warning), seconds = sum(r$real)), '", out, "', row.names = FALSE)"),
    sep = "\n")
  t0 <- Sys.time()
  status <- system2("Rscript", c("-e", shQuote(code)), stdout = log, stderr = log)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (file.exists(out)) {
    d <- utils::read.csv(out)
    d$seconds <- secs
  } else {
    d <- data.frame(tests = NA, expectations = NA, failed = NA, errors = NA, skipped = NA, warnings = NA, seconds = secs)
  }
  d$file <- f; d$exit <- status
  d$ok <- identical(status, 0L) && !is.na(d$tests) && d$failed == 0 && d$errors == 0 && d$expectations > 0 &&
    d$skipped < d$tests
  d
}

lf_run_gate <- function(g, log_dir) {
  log <- file.path(log_dir, paste0("gate-", g, ".log"))
  t0 <- Sys.time()
  status <- system2("Rscript", c("tests/sim/run-gates.R", "--sim", "--local-only", "--only", g), stdout = log, stderr = log)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  txt <- readLines(log, warn = FALSE)
  overall <- grep("^OVERALL:", txt, value = TRUE)
  data.frame(gate = g, seconds = secs, exit = status, verdict = if (length(overall)) overall[length(overall)] else "no OVERALL line",
             ok = identical(status, 0L) && length(overall) > 0 && grepl("^OVERALL: PASS", overall[length(overall)]))
}

lf_receipt <- function(path, sha, dirty, tests, gates, started, finished) {
  tbl <- function(d, cols) c(paste0("| ", paste(cols, collapse = " | "), " |"), paste0("|", strrep("---|", length(cols))),
    apply(d[, cols, drop = FALSE], 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
  all_ok <- all(tests$ok) && all(gates$ok)
  writeLines(c(
    sprintf("# Local full-run receipt: %s", substr(sha, 1, 12)),
    "", sprintf("- Commit: `%s`%s", sha, if (dirty) " (WORKING TREE DIRTY: not valid for a release)" else ""),
    sprintf("- Started: %s, finished: %s, total %.0f s", format(started, "%F %T"), format(finished, "%F %T"),
            as.numeric(difftime(finished, started, units = "secs"))),
    sprintf("- Machine: %s, %d cores, R %s", Sys.info()[["nodename"]], parallel::detectCores(), getRversion()),
    sprintf("- **Result: %s**", if (all_ok && !dirty) "GREEN" else if (all_ok) "green but dirty tree" else "RED"),
    "", "## Local-only testthat files (tests/testthat/local-only-tests.txt)", "",
    if (nrow(tests)) tbl(transform(tests, seconds = round(seconds), ok = ifelse(ok, "ok", "FAIL")),
      c("file", "tests", "expectations", "failed", "errors", "skipped", "seconds", "ok")) else "(not run)",
    "", "## Local-only gates (tests/sim/gates-local-only.txt)", "",
    if (nrow(gates)) tbl(transform(gates, seconds = round(seconds), ok = ifelse(ok, "ok", "FAIL")),
      c("gate", "verdict", "seconds", "ok")) else "(not run)", ""), path)
}

if (sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  opt <- function(f, d) { i <- match(f, a); if (is.na(i) || i == length(a)) d else a[i + 1L] }
  stopifnot(file.exists("DESCRIPTION"), file.exists("tests/testthat/local-only-tests.txt"))
  Sys.setenv(NOT_CRAN = "true"); Sys.unsetenv("CI")
  files <- if ("--gates-only" %in% a) character() else lf_read_list("tests/testthat/local-only-tests.txt")
  gates <- if ("--tests-only" %in% a) character() else lf_read_list("tests/sim/gates-local-only.txt")
  cat(sprintf("local-only tier: %d test file(s), %d gate(s)\n", length(files), length(gates)))
  cat(paste0("  test ", files, "\n"), paste0("  gate ", gates, "\n"), sep = "")
  if ("--dry-run" %in% a) quit(status = 0L)
  workers <- as.integer(opt("--workers", min(5L, parallel::detectCores())))
  sha <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
  dirty <- length(system2("git", c("status", "--porcelain", "--untracked-files=no"), stdout = TRUE)) > 0
  work <- file.path(Sys.getenv("TMPDIR", "/tmp"), paste0("medfit-local-full-", substr(sha, 1, 10))); dir.create(work, showWarnings = FALSE)
  started <- Sys.time()
  tests <- if (length(files)) do.call(rbind, parallel::mclapply(files, lf_run_test_file, out_dir = work, mc.cores = workers,
                                                               mc.preschedule = FALSE)) else data.frame()
  if (nrow(tests)) { cat("\ntestthat:\n"); print(tests[, c("file", "tests", "expectations", "failed", "errors", "skipped", "seconds", "ok")]) }
  # the gate scripts parallelize inside (detectCores() - 1), so the gates run one after another
  gres <- if (length(gates)) do.call(rbind, lapply(gates, function(g) { r <- lf_run_gate(g, work); cat(sprintf("gate %s: %s (%.0f s)\n", g, r$verdict, r$seconds)); r })) else data.frame()
  finished <- Sys.time()
  rdir <- opt("--receipt-dir", "planning/local-full-runs"); dir.create(rdir, showWarnings = FALSE, recursive = TRUE)
  rp <- file.path(rdir, sprintf("RECEIPT-%s-%s.md", format(Sys.Date()), substr(sha, 1, 10)))
  lf_receipt(rp, sha, dirty, tests, gres, started, finished)
  cat(sprintf("\nreceipt: %s\nlogs: %s\n", rp, work))
  ok <- (!nrow(tests) || all(tests$ok)) && (!nrow(gres) || all(gres$ok))
  if (!ok) { cat("LOCAL FULL RUN: RED\n"); quit(status = 1L) }
  cat("LOCAL FULL RUN: GREEN\n")
}
