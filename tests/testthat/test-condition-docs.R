# Drift guard: every classed condition the package signals (medfit_error_*,
# medfit_warning_* and medfit_message_*) must be named in the articles, the Rd
# files, README.md or NEWS.md, so a new condition cannot ship without a place
# where its cause and fix are written down. The source and the articles are not in the
# installed package, so the tests skip when either is absent.

condition_pattern <- "medfit_(error|warning|message)_[a-z0-9_]+"

condition_names <- function(text) {
  sort(unique(unlist(regmatches(text, gregexpr(condition_pattern, text)))))
}

condition_undocumented <- function(code_text, doc_text) {
  setdiff(condition_names(code_text), condition_names(doc_text))
}

read_dir_text <- function(dir, pattern) {
  files <- list.files(dir, pattern = pattern, full.names = TRUE, recursive = TRUE)
  paste(unlist(lapply(files, readLines, warn = FALSE)), collapse = "\n")
}

condition_sources <- function() {
  root <- testthat::test_path("..", "..")
  needed <- c("R", file.path("vignettes", "articles"), "NEWS.md")
  testthat::skip_if_not(all(file.exists(file.path(root, needed))),
                        "source or vignettes are not available (installed or built package)")
  list(
    code = read_dir_text(file.path(root, "R"), "\\.R$"),
    docs = paste(
      read_dir_text(file.path(root, "vignettes", "articles"), "\\.qmd$"),
      read_dir_text(file.path(root, "man"), "\\.Rd$"),
      paste(readLines(file.path(root, "NEWS.md"), warn = FALSE), collapse = "\n"),
      if (file.exists(file.path(root, "README.md"))) {
        paste(readLines(file.path(root, "README.md"), warn = FALSE), collapse = "\n")
      },
      sep = "\n"
    )
  )
}

test_that("every classed condition in R/ is named in the docs", {
  s <- condition_sources()
  expect_gt(length(condition_names(s$code)), 20L)
  expect_identical(condition_undocumented(s$code, s$docs), character())
})

test_that("planted defect: an undocumented condition is caught", {
  s <- condition_sources()
  expect_identical(
    condition_undocumented(s$code, gsub("medfit_warning_vcov_diagonal", "medfit_xx", s$docs, fixed = TRUE)),
    "medfit_warning_vcov_diagonal"
  )
  expect_identical(
    condition_undocumented(paste(s$code, "class = \"medfit_error_brand_new\""), s$docs),
    "medfit_error_brand_new"
  )
})
