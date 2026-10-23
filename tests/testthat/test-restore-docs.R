# Documentation of the restoration cap (restoration-bound plan T8): the article states the safety factor the code uses,
# the NEWS records the behavior change, and the Rd of `mbco_sem()` and `compare_lr()` describe the unresolved result.
# The constant lives in R/sem-constraints.R (`.sem_restore_k`) and in tests/sim/gates.csv; a drift in either fails here
# or in run-gates.R --fast. Planted defect: an article stating another k must be caught by the same check.

root <- normalizePath(test_path("..", ".."))
methods_file <- file.path(root, "vignettes", "articles", "methods.qmd")
news_file <- file.path(root, "NEWS.md")
skip_if_not(file.exists(methods_file) && file.exists(news_file),
            "vignettes and NEWS are not shipped with the installed tests")

states_k <- function(text, k) grepl(sprintf("k = %g([^0-9.]|$)", k), text)

test_that("the methods article states the safety factor of the code", {
  txt <- paste(readLines(methods_file, warn = FALSE), collapse = "\n")
  expect_true(states_k(txt, .sem_restore_k))
  expect_match(txt, "-4", fixed = TRUE) # status -4 named
  # planted defect: a different k in the text is not accepted as this one
  expect_false(states_k(sub(sprintf("k = %g", .sem_restore_k), "k = 40", txt, fixed = TRUE), .sem_restore_k))
})

test_that("the gates.csv row carries the same k as the code", {
  path <- file.path(root, "tests", "sim", "gates.csv")
  skip_if_not(file.exists(path), "tests/sim is not shipped with the installed tests")
  g <- utils::read.csv(path, stringsAsFactors = FALSE)
  expect_equal(g$tol_est[g$gate == "restoration"], .sem_restore_k)
})

test_that("the NEWS records the cap and the behavior change", {
  txt <- paste(readLines(news_file, warn = FALSE), collapse = "\n")
  expect_match(txt, "can no longer raise the discrepancy without limit", fixed = TRUE)
  expect_match(txt, "Behavior change (correctness fix)", fixed = TRUE)
  expect_match(txt, "$unresolved", fixed = TRUE)
})

test_that("the help pages describe the unresolved result", {
  rd <- function(topic) {
    h <- utils::help(topic, package = "medfit")
    out <- utils::capture.output(tools::Rd2txt(h, options = list(underline_titles = FALSE)))
    paste(out, collapse = "\n")
  }
  skip_if(!nzchar(system.file(package = "medfit")), "package is not installed")
  mb <- tryCatch(rd("mbco_sem"), error = function(e) "")
  skip_if(!nzchar(mb), "help pages are not available under load_all()")
  expect_match(mb, "unresolved", fixed = TRUE)
  expect_match(rd("compare_lr"), "no accepted reference when one of its own", fixed = TRUE)
})
