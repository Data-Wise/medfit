# Adapter side of the injected-failure parity (STAGE0_PRELUDE hook of ../run-cells.R; same injection rules as ref-inject.R):
# put the flaky/warny refit under the shared-refit cache, then rebuild the cache so it wraps the injected function.
inject <- Sys.getenv("STAGE0_INJECT"); .s0$sh$restore()
orig <- get(".bootstrap_fiml_refit", envir = asNamespace("medfit"))
f <- switch(inject,
  fail = function(source, rows) { if (sum(rows) %% 7L == 0L) stop("injected refit failure", call. = FALSE); orig(source, rows) },
  warn = function(source, rows) { if (sum(rows) %% 3L == 0L) warning("injected refit warning", call. = FALSE); orig(source, rows) },
  stop("STAGE0_INJECT must be fail or warn"))
utils::assignInNamespace(".bootstrap_fiml_refit", f, ns = "medfit")
.s0$sh <- study_shared_refits_install()
