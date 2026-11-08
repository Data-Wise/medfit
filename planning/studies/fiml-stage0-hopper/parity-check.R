# Parity proof for the shared-refit patch: for every effect, the shared run must equal the unpatched run
# exactly (estimates, interval, status, counts, per-replicate records), including with injected refit failures.
# Run from the repo root: Rscript planning/studies/fiml-stage0-hopper/parity-check.R [mutant]
mutant <- "mutant" %in% commandArgs(TRUE)
suppressMessages(pkgload::load_all(quiet = TRUE))
source("planning/studies/fiml-stage0-hopper/shared-refits.R")
source("tests/testthat/helper-fiml-bootstrap.R")
utils::assignInNamespace(".fiml_source_inference_admitted", function() TRUE, ns = "medfit")
orig <- get(".bootstrap_fiml_refit", envir = asNamespace("medfit"))
flaky <- function(source, rows) { if (sum(rows) %% 7L == 0L) stop("injected refit failure", call. = FALSE); orig(source, rows) }
warny <- function(source, rows) { if (sum(rows) %% 3L == 0L) warning("injected refit warning", call. = FALSE); orig(source, rows) }
strip <- function(r) list(est = r@estimate, ci = c(r@ci_lower, r@ci_upper), boot = r@boot_estimates, inf = r@inference)  # full records incl. frame and warnings
fails <- 0L; checks <- 0L
for (direct in c(TRUE, FALSE)) for (kind in c("mar", "mcar")) for (inject in c("none", "fail", "warn")) {
  fit <- fit_sem(fb_model(direct), fb_fixture(kind, direct), missing = "fiml", fixed_x = FALSE)
  utils::assignInNamespace(".bootstrap_fiml_refit", switch(inject, none = orig, fail = flaky, warn = warny), ns = "medfit")
  base <- lapply(c("nie", "nde", "te"), function(e) strip(bootstrap_mediation(source_fit = fit, effect = e, method = "nonparametric", n_boot = 40L, seed = 11L)))
  sh <- study_shared_refits_install(key_fun = if (mutant) function(rows) "constant" else function(rows) rlang::hash(rows))
  # the cache wraps whatever is currently installed (orig or flaky), so shared == base unless the cache is wrong
  shared <- lapply(c("nie", "nde", "te"), function(e) strip(bootstrap_mediation(source_fit = fit, effect = e, method = "nonparametric", n_boot = 40L, seed = 11L)))
  n_cached <- sh$size(); sh$restore(); utils::assignInNamespace(".bootstrap_fiml_refit", orig, ns = "medfit")
  ok <- identical(base, shared); checks <- checks + 1L; if (!ok) fails <- fails + 1L
  cat(sprintf("direct=%s %s inject=%s: identical=%s  cached refits=%d (40 requested; 3 calls)\n", direct, kind, inject, ok, n_cached))
  if (inject == "warn") stopifnot(any(vapply(shared[[2]]$inf$replicates, function(x) length(x$warnings) > 0L, logical(1))))  # warning case is not vacuous
  stopifnot(mutant || n_cached <= 40L)
}
cat(sprintf("PARITY %s: %d/%d scenarios identical\n", if (fails == 0L) "PASS" else "FAIL", checks - fails, checks))
if (fails > 0L && !mutant) quit(status = 1)
if (mutant && fails == 0L) { cat("MUTANT NOT CAUGHT\n"); quit(status = 1) }
