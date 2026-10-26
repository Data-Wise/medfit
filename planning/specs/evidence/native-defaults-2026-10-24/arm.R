args <- commandArgs(TRUE); S <- args[1]; v <- args[2]
lib <- file.path(S, paste0("lib_", v)); Sys.setenv(NOT_CRAN = "true")
cols <- c("file", "test", "nb", "failed", "skipped", "error", "warning")
only <- strsplit(Sys.getenv("ARM_ONLY"), ",")[[1]]  # optional: run a subset of arms (planted-defect checks)
sha <- function(path) {
  s <- suppressWarnings(system2("git", c("-C", shQuote(path), "rev-parse", "--short", "HEAD"), stdout = TRUE, stderr = FALSE))
  if (length(s) == 1L) s else "no-git"
}
run <- function(name, code, path) {
  if (length(only) && !name %in% only) return(invisible(NULL))
  out <- file.path(S, sprintf("%s-%s.rds", name, v)); log <- file.path(S, sprintf("%s-%s.log", name, v))
  unlink(c(out, log))  # fail-closed: an old artifact can never pass as this run's result
  full <- sprintf(paste0(".libPaths(c(%s, .libPaths())); Sys.setenv(NOT_CRAN='true'); %s; ",
                         "r <- as.data.frame(r)[, c(%s)]; saveRDS(r, %s)"),
                  deparse(lib), code, paste(shQuote(cols, "cmd"), collapse = ","), deparse(out))
  cat(v, name, sha(path), format(Sys.time(), "%H:%M:%S"), "\n"); flush.console()
  st <- system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(full)), stdout = log, stderr = log)
  if (!identical(as.integer(st), 0L)) stop(sprintf("arm '%s' (%s) exited with status %s; see %s", name, v, st, log), call. = FALSE)
  r <- tryCatch(readRDS(out), error = function(e) NULL)
  if (!is.data.frame(r) || !identical(names(r), cols)) stop(sprintf("arm '%s' (%s) produced no readable result with the expected columns", name, v), call. = FALSE)
  invisible(r)
}
srcdir <- file.path(S, "src_base")
run("medfit", sprintf("r <- testthat::test_dir(%s, package='medfit', load_package='installed', reporter='silent', stop_on_failure=FALSE)",
                      deparse(file.path(srcdir, "tests", "testthat"))), srcdir)
base <- "/Users/davood/projects/r-packages/active"
for (d in c("rmediation", "probmed", "missingmed", "mediationverse", "medsim", "medrobust")) {
  # MISSINGMED_DIR: a git worktree of the dependent, so the run never reads or writes the main checkout
  path <- if (d == "missingmed" && nzchar(Sys.getenv("MISSINGMED_DIR"))) Sys.getenv("MISSINGMED_DIR") else file.path(base, d)
  run(d, sprintf("r <- testthat::test_local(%s, reporter='silent', stop_on_failure=FALSE, load_package='source')", deparse(path)), path)
}
cat(v, "DONE", format(Sys.time(), "%H:%M:%S"), "\n")
