# Generator for the FI-G3 slice S2 refusal fixture. Run from the package root ON THE S2 COMMIT; it only reads the
# frozen pre-serial, post-S1a and post-S1b files:
#   Rscript tests/testthat/fixtures/make-fiml-after-g3s2.R
# Writes fiml-refusals-after-g3s2.rds: the same near-miss models, with the class, stage and message they have once the
# pure chain k = 0 serial shape is also a public fit (the entries that became fits are listed in
# test-fiml-g3-baseline.R).
devtools::load_all(quiet = TRUE)
out <- "tests/testthat/fixtures"
before <- readRDS(file.path(out, "fiml-refusals-before-g3s1.rds"))
res <- lapply(before$models, function(m) {
  e <- tryCatch(fit_sem(m, before$data, missing = "fiml", fixed_x = FALSE), error = identity)
  if (!inherits(e, "error")) return(list(class = "<fit>", message = NA_character_, stage = NA_character_))
  list(class = class(e), message = conditionMessage(e), stage = if (is.null(e$stage)) NA_character_ else e$stage)
})
saveRDS(list(data = before$data, models = before$models, results = res),
        file.path(out, "fiml-refusals-after-g3s2.rds"), version = 2)
cat("refusal models:", length(res), "\n")
print(table(vapply(res, function(r) r$class[1L], "")))
