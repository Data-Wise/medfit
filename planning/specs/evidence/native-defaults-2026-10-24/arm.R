args <- commandArgs(TRUE); S <- args[1]; v <- args[2]
lib <- file.path(S, paste0("lib_", v)); Sys.setenv(NOT_CRAN = "true")
run <- function(name, code) {
  out <- file.path(S, sprintf("%s-%s.rds", name, v)); log <- file.path(S, sprintf("%s-%s.log", name, v))
  full <- sprintf(paste0(".libPaths(c(%s, .libPaths())); Sys.setenv(NOT_CRAN='true'); %s; ",
                         "r <- as.data.frame(r)[, c('file','test','nb','failed','skipped','error','warning')]; saveRDS(r, %s)"),
                  deparse(lib), code, deparse(out))
  cat(v, name, format(Sys.time(), "%H:%M:%S"), "\n"); flush.console()
  system2(file.path(R.home("bin"), "Rscript"), c("-e", shQuote(full)), stdout = log, stderr = log)
}
run("medfit", sprintf("r <- testthat::test_dir(%s, package='medfit', load_package='installed', reporter='silent', stop_on_failure=FALSE)",
                      deparse(file.path(S, "src_base", "tests", "testthat"))))
base <- "/Users/davood/projects/r-packages/active"
for (d in c("rmediation", "probmed", "missingmed", "mediationverse", "medsim", "medrobust")) {
  # MISSINGMED_DIR: a git worktree of the dependent, so the run never reads or writes the main checkout
  path <- if (d == "missingmed" && nzchar(Sys.getenv("MISSINGMED_DIR"))) Sys.getenv("MISSINGMED_DIR") else file.path(base, d)
  run(d, sprintf("r <- testthat::test_local(%s, reporter='silent', stop_on_failure=FALSE, load_package='source')", deparse(path)))
}
cat(v, "DONE", format(Sys.time(), "%H:%M:%S"), "\n")
