# Generator for the FI-G3 slice S4 fixtures. Run from the package root ON THE S4 COMMIT; it only reads the frozen
# pre-serial file:
#   Rscript tests/testthat/fixtures/make-fiml-after-g3s4.R
# Writes fiml-refusals-after-g3s4.rds: the same near-miss models, with the class, stage and message they have once the
# k = 2 serial shapes (both variants) are also public fits (the entries that became fits, and the partial exogenous
# covariance entry that is now worded by its own reason, are listed in test-fiml-g3-serial-two-cov.R), and
# fiml-tables-after-g3s4.rds: the four k = 2 serial tables (both variants x the direct path free or fixed), frozen for
# the identical() checks of any later slice.
devtools::load_all(quiet = TRUE)
out <- "tests/testthat/fixtures"
before <- readRDS(file.path(out, "fiml-refusals-before-g3s1.rds"))
res <- lapply(before$models, function(m) {
  e <- tryCatch(fit_sem(m, before$data, missing = "fiml", fixed_x = FALSE), error = identity)
  if (!inherits(e, "error")) return(list(class = "<fit>", message = NA_character_, stage = NA_character_))
  list(class = class(e), message = conditionMessage(e), stage = if (is.null(e$stage)) NA_character_ else e$stage)
})
saveRDS(list(data = before$data, models = before$models, results = res),
        file.path(out, "fiml-refusals-after-g3s4.rds"), version = 2)
tb <- list()
for (sc in c(TRUE, FALSE)) for (dr in c(TRUE, FALSE)) {
  tb[[paste0(if (sc) "sat2" else "chain2", if (dr) "free" else "fixed")]] <- .sem_fiml_tables_ser(dr, 2L, sc)
}
saveRDS(tb, file.path(out, "fiml-tables-after-g3s4.rds"), version = 2)
cat("refusal models:", length(res), "\n")
print(table(vapply(res, function(r) r$class[1L], "")))
