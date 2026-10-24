# QC plan (planning/specs/BRAINSTORM-optimizer-quality-control-2026-10-23.md, Q-1 and review R-2): a gate row must be
# real, and a native structure must name the gates that cover it. gates.csv carries an `oracle` (what the numbers are
# checked against) and a `mutants` list (the planted defects the gate must reject); a token is a `MUTANT=` name found in
# the gate's script (or a script it names), `driver` for the defects run-gates.R plants in every gate's results, or
# `driver:<kind>` for an extra kind that run-gates.R plants for this gate. structures.csv is the registry of native
# structures: every one lists its gates and its model page, and every `sem_models()` entry and every
# `model-native*.qmd` page must appear in it, so a new structure cannot merge without a gate.

sim <- test_path("..", "sim")
skip_if_not(file.exists(file.path(sim, "gates.csv")), "tests/sim is not shipped with the installed tests")
root <- normalizePath(test_path("..", ".."))
gc_gates <- utils::read.csv(file.path(sim, "gates.csv"), stringsAsFactors = FALSE, na.strings = c("NA", ""))
gc_struct <- utils::read.csv(file.path(sim, "structures.csv"), stringsAsFactors = FALSE)
gc_driver <- paste(readLines(file.path(sim, "run-gates.R"), warn = FALSE), collapse = "\n")
gc_tokens <- function(x) strsplit(x, "|", fixed = TRUE)[[1L]]

# the text a gate's mutant names are looked up in: its script, and each other tests/sim script the first names
gc_script_text <- function(prefix) {
  main <- file.path(sim, paste0(prefix, ".R"))
  if (!file.exists(main)) return(NULL)
  txt <- paste(readLines(main, warn = FALSE), collapse = "\n")
  others <- list.files(sim, pattern = "\\.R$", full.names = FALSE)
  named <- others[vapply(others, function(f) grepl(f, txt, fixed = TRUE), TRUE)]
  paste(c(txt, vapply(named, function(f) paste(readLines(file.path(sim, f), warn = FALSE), collapse = "\n"), "")),
        collapse = "\n")
}
# a mutant token the text must contain as a whole word
gc_has_word <- function(txt, tok) grepl(paste0("(^|[^A-Za-z0-9_])", tok, "([^A-Za-z0-9_]|$)"), txt)
gc_check_row <- function(row, driver_text = gc_driver) {
  bad <- character()
  if (is.na(row$oracle) || !nzchar(trimws(row$oracle))) bad <- c(bad, "oracle is empty")
  if (is.na(row$mutants) || !nzchar(trimws(row$mutants))) return(c(bad, "mutants is empty"))
  toks <- gc_tokens(row$mutants)
  prefix <- if (identical(row$gate, "stationarity")) "sem-constrained-gate" else row$results_prefix
  txt <- gc_script_text(prefix)
  for (t in toks) {
    if (identical(t, "driver")) next
    if (startsWith(t, "driver:")) {
      if (!gc_has_word(driver_text, sub("^driver:", "", t))) bad <- c(bad, paste0(t, " is not planted by run-gates.R"))
    } else if (is.null(txt) || !gc_has_word(txt, t)) {
      bad <- c(bad, paste0(t, " is not a MUTANT of the gate's script"))
    }
  }
  bad
}

test_that("every gates.csv row names its oracle and real planted defects", {
  expect_true(all(c("oracle", "mutants") %in% names(gc_gates)))
  for (i in seq_len(nrow(gc_gates))) {
    bad <- gc_check_row(gc_gates[i, ])
    expect_length(bad, 0L)
    if (length(bad)) message(gc_gates$gate[i], ": ", paste(bad, collapse = "; "))
  }
})

test_that("planted defect: an empty oracle, an empty mutants list and a stale mutant name are each rejected", {
  row <- gc_gates[gc_gates$gate == "restoration", ]
  expect_length(gc_check_row(row), 0L)
  expect_match(gc_check_row(transform(row, oracle = ""))[1L], "oracle is empty")
  expect_match(gc_check_row(transform(row, mutants = ""))[1L], "mutants is empty")
  expect_match(gc_check_row(transform(row, mutants = "nocurv|renamed_away"))[1L], "renamed_away is not a MUTANT")
  expect_match(gc_check_row(transform(row, mutants = "driver:never_planted"))[1L], "not planted by run-gates.R")
})

test_that("the registry names real gates and real model pages, and every gate is covered by a structure", {
  skip_if_not(dir.exists(file.path(root, "vignettes", "articles")), "vignettes are not shipped here")
  gates <- gc_gates$gate
  listed <- unlist(lapply(gc_struct$gates, gc_tokens))
  expect_setequal(setdiff(listed, gates), character())
  expect_setequal(setdiff(gates, listed), character())
  for (d in unique(gc_struct$doc)) {
    expect_true(file.exists(file.path(root, "vignettes", "articles", paste0(d, ".qmd"))), info = d)
  }
})

test_that("every sem_models() entry and every native model page is in the registry", {
  skip_if_not(dir.exists(file.path(root, "vignettes", "articles")), "vignettes are not shipped here")
  expect_setequal(setdiff(names(sem_models()), gc_struct$structure[gc_struct$kind == "sem_models"]), character())
  pages <- sub("\\.qmd$", "", list.files(file.path(root, "vignettes", "articles"), pattern = "^model-native.*\\.qmd$"))
  expect_setequal(setdiff(pages, gc_struct$doc), character())
})

test_that("planted defect: a structure with no gate, and a gate with no structure, are each detected", {
  none <- rbind(gc_struct, data.frame(structure = "new syntax", kind = "syntax", gates = "", doc = "model-native"))
  expect_true(any(!nzchar(none$gates)))
  without <- gc_struct[gc_struct$structure != "factor covariates", ]
  expect_true("factor" %in% setdiff(gc_gates$gate, unlist(lapply(without$gates, gc_tokens))))
})
