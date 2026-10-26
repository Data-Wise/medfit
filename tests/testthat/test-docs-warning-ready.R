# The 0.14.0 default-change warning is gone in 0.15.0 (the flip shipped), so no article may carry the hidden setup
# chunk that muffled it, and none may describe the warning as live. `whats-new-0-11.qmd` is a historical page and is
# the one allowed exception for the chunk. Skipped when the vignettes are absent (installed or built package).

root_path <- function(...) testthat::test_path("..", "..", ...)

articles <- function() {
  d <- root_path("vignettes", "articles")
  testthat::skip_if_not(dir.exists(d), "vignettes are not available (installed or built package)")
  list.files(d, pattern = "\\.qmd$", full.names = TRUE)
}

test_that("no current article carries the 0.14.0 warning-muffling setup chunk", {
  for (f in articles()) {
    if (basename(f) == "whats-new-0-11.qmd") next
    lines <- readLines(f, warn = FALSE)
    expect_false(any(grepl("label:\\s*native-defaults-setup", lines)),
                 label = paste(basename(f), "has no native-defaults-setup chunk"))
    expect_false(any(grepl("invokeRestart(\"muffleWarning\")", lines, fixed = TRUE) &
                       grepl("medfit_warning_default_change", lines, fixed = TRUE)),
                 label = paste(basename(f), "does not muffle medfit_warning_default_change"))
  }
})

test_that("no current article shows the opt-in as required or the 0.14.0 warning as live", {
  stale <- c(
    "0\\.14\\.0 warns",
    "warns once per session that fit_sem",
    "In 0\\.15\\.0 the default becomes",
    "options\\(medfit\\.native_defaults = \"0\\.15\"\\)",
    "print on the 0\\.14 defaults"
  )
  for (f in articles()) {
    if (basename(f) %in% c("whats-new-0-11.qmd", "guide-changes.qmd", "native-defaults-0-15.qmd")) next
    lines <- readLines(f, warn = FALSE)
    for (p in stale) {
      expect_false(any(grepl(p, lines)), label = paste(basename(f), "does not contain", p))
    }
  }
})
