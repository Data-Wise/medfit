# S7 lifecycle gate (0.11.0 plan T1b, Codex review of T1): the package is installed into a scratch library and then
# loaded, used, unloaded and reloaded in a FRESH R process against each S7 library. The failure that PR #214 reported
# appeared only in an installed package (`load_all()` and the testthat process hid it), so nothing weaker counts.
#
# Libraries: `S7_RELEASE_LIB` (default: the S7 already on the library path, normally CRAN's) and `S7_MAIN_LIB`
# (a library holding `RConsortium/S7@main`; if unset the script installs it from GitHub into a temporary library).
# A library that cannot be obtained is a failed run, never a skip: a gate that skips is not evidence.
# Per library, six steps, each one row: library, construct_show, fit_tidy, unload, reload, fit_after_reload.
# Rows: 12 (2 libraries x 6 steps); a run fails when its step did not print OK.
# `MUTANT=<name>` plants a defect in a COPY of the source and the gate must then exit 1:
#   nounion  the plain numeric S4 union is not registered (the installed package fails on development S7)
#   noonload `.onLoad()` does not re-register the unions (a union registered at build time is not carried into the
#            installed namespace)
# Run from the package root:  Rscript tests/sim/s7-lifecycle-gate.R

mutant <- Sys.getenv("MUTANT", "")
steps <- c("library", "construct_show", "fit_tidy", "unload", "reload", "fit_after_reload")
root <- normalizePath(".")
work <- tempfile("s7gate-")
dir.create(work)
on.exit(unlink(work, recursive = TRUE), add = TRUE)

# The source that gets installed: the working tree, or a mutated copy of it
src <- file.path(work, "src")
dir.create(src)
invisible(file.copy(list.files(root, all.files = TRUE, full.names = TRUE, no.. = TRUE), src, recursive = TRUE))
for (d in c("planning", "tests", ".git", ".remember", "docs", "vignettes", "man")) {
  unlink(file.path(src, d), recursive = TRUE)
}
swap <- function(file, pattern, replacement) {
  p <- file.path(src, file)
  x <- paste(readLines(p, warn = FALSE), collapse = "\n")
  if (lengths(regmatches(x, gregexpr(pattern, x, fixed = TRUE))) != 1L) {
    stop("MUTANT ", mutant, ": the pattern must match exactly once in ", file, " (", pattern, ")")
  }
  writeLines(sub(pattern, replacement, x, fixed = TRUE), p)
}
if (mutant == "nounion") {
  swap("R/classes.R", '    medfit_numeric = c("integer", "numeric"),\n', "")
} else if (mutant == "noonload") {
  swap("R/zzz.R", "\n  .register_s4_unions()\n", "\n  NULL\n")
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

lib <- file.path(work, "medfit-lib")
dir.create(lib)
inst_args <- c("CMD", "INSTALL", "--no-docs", "--no-test-load", paste0("--library=", lib), src)
inst <- system2(file.path(R.home("bin"), "R"), inst_args, stdout = TRUE, stderr = TRUE)
installed <- dir.exists(file.path(lib, "medfit"))

main_lib <- Sys.getenv("S7_MAIN_LIB", "")
if (!nzchar(main_lib)) {
  main_lib <- file.path(work, "s7-main")
  dir.create(main_lib)
  try(remotes::install_github("RConsortium/S7", lib = main_lib, upgrade = "never", quiet = TRUE), silent = TRUE)
}
release_lib <- Sys.getenv("S7_RELEASE_LIB", "")

child <- file.path(work, "child.R")
writeLines(c(
  "args <- commandArgs(TRUE)",
  ".libPaths(c(args[1], if (nzchar(args[2])) args[2], .libPaths()))",
  "step <- function(name, expr) {",
  "  msg <- function(e) gsub('[\\r\\n]+', ' ', substr(conditionMessage(e), 1, 160))",
  "  r <- tryCatch({ force(expr); 'OK' }, error = function(e) paste('ERROR', msg(e)))",
  "  cat('STEP', name, r, '\\n')",
  "}",
  "cat('S7', as.character(packageVersion('S7')), '\\n')",
  "d <- function() transform(medfit::mediation_demo, m = mediator1, x = treatment, y = outcome)",
  "fit <- function() medfit::fit_sem('m ~ x\\ny ~ m + x', d())",
  "step('library', suppressMessages(library(medfit)))",
  "step('construct_show', {",
  "  b <- medfit::BootstrapResult(estimate = 0.2, ci_lower = 0.1, ci_upper = 0.3, ci_level = 0.95,",
  "    boot_estimates = c(0.1, 0.2, 0.3), n_boot = 3L, method = 'nonparametric', call = NULL)",
  "  invisible(capture.output(methods::show(b)))",
  "})",
  "step('fit_tidy', generics::tidy(fit()))",
  "step('unload', unloadNamespace('medfit'))",
  "step('reload', suppressMessages(library(medfit)))",
  "step('fit_after_reload', fit())"
), child)

run_one <- function(label, s7_lib) {
  if (!installed) {
    return(data.frame(s7 = label, s7_version = NA_character_, step = steps, ok = FALSE,
                      detail = "medfit did not install", stringsAsFactors = FALSE))
  }
  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c(child, lib, shQuote(s7_lib)),
                                  stdout = TRUE, stderr = TRUE))
  ver <- trimws(sub("^S7 ", "", grep("^S7 ", out, value = TRUE)[1]))
  got <- grep("^STEP ", out, value = TRUE)
  rows <- lapply(steps, function(st) {
    line <- got[startsWith(got, paste("STEP", st, ""))]
    ok <- length(line) == 1L && grepl(" OK $", line)
    detail <- if (length(line)) {
      sub(paste0("^STEP ", st, " "), "", line[1])
    } else {
      paste("no result; last output:", tail(out, 1))
    }
    data.frame(s7 = label, s7_version = ver, step = st, ok = ok, detail = trimws(detail), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

res <- rbind(run_one("release", release_lib), run_one("main", main_lib))
res$mutant <- mutant
res$improper <- ""
res$native_ok <- res$ok
res$omx_ok <- TRUE
print(res[, c("s7", "s7_version", "step", "ok", "detail")], row.names = FALSE)

if (!nzchar(mutant)) {
  dir.create(file.path(root, "tests/sim/results"), showWarnings = FALSE)
  utils::write.csv(res, file.path(root, "tests/sim/results", sprintf("s7-lifecycle-gate-%s.csv", Sys.Date())),
                   row.names = FALSE)
}
tag <- if (nzchar(mutant)) paste0(" (MUTANT=", mutant, ")") else ""
cat(sprintf("S7 LIFECYCLE GATE: %d of %d steps OK%s\n", sum(res$ok), nrow(res), tag))
quit(status = if (all(res$ok)) 0L else 1L)
