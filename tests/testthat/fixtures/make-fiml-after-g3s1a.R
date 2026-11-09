# Generator for the FI-G3 slice S1a fixtures. Run from the package root ON THE S1A COMMIT; it never touches the frozen
# pre-serial files (fiml-*-before-g3s1.rds), which it only reads:
#   Rscript tests/testthat/fixtures/make-fiml-after-g3s1a.R
# Writes
#   fiml-refusals-after-g3s1a.rds  the same near-miss models as the pre-serial dump, with the class, stage and message
#                                  they have once the serial router answers serial syntax (every serial syntax is still
#                                  refused at fit); S2-S4 must keep every entry that is not meant to change
#   fiml-tables-after-g3s1a.rds    the 12 serial table cells (saturated and chain x k = 0, 1, 2 x direct free and
#                                  fixed at zero) from .sem_fiml_tables_ser(), asserted with identical() by S2-S4
devtools::load_all(quiet = TRUE)
out <- "tests/testthat/fixtures"
before <- readRDS(file.path(out, "fiml-refusals-before-g3s1.rds"))
res <- lapply(before$models, function(m) {
  e <- tryCatch(fit_sem(m, before$data, missing = "fiml", fixed_x = FALSE), error = identity)
  if (!inherits(e, "error")) return(list(class = "<fit>", message = NA_character_, stage = NA_character_))
  list(class = class(e), message = conditionMessage(e), stage = if (is.null(e$stage)) NA_character_ else e$stage)
})
saveRDS(list(data = before$data, models = before$models, results = res),
        file.path(out, "fiml-refusals-after-g3s1a.rds"), version = 2)
tab <- list()
for (sc in c(TRUE, FALSE)) for (k in 0:2) for (d in c(TRUE, FALSE)) {
  tab[[paste0(if (sc) "sat" else "chain", k, if (d) "free" else "fixed")]] <- .sem_fiml_tables_ser(d, k, sc)
}
saveRDS(tab, file.path(out, "fiml-tables-after-g3s1a.rds"), version = 2)
cat("refusal models:", length(res), " serial table cells:", length(tab), "\n")
print(table(vapply(res, function(r) r$class[1L], "")))
