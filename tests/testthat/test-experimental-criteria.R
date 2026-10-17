# Exit criteria for the "experimental" label on the native engine (0.11.0 plan T5). The criteria live in
# planning/specs/CRITERIA-native-experimental-exit-2026-10-17.csv; this test checks that each names evidence that
# exists, so the list cannot rot: a deleted gate row, an unlisted new gate, a missing export or a missing page fails.
# The gates themselves are run by tests/sim/run-gates.R; the label drops only when they all pass.

root <- normalizePath(test_path("..", ".."))
crit_file <- file.path(root, "planning", "specs", "CRITERIA-native-experimental-exit-2026-10-17.csv")
gates_file <- file.path(root, "tests", "sim", "gates.csv")
skip_if_not(
  file.exists(crit_file) && file.exists(gates_file),
  "planning/ and tests/sim are not shipped with the installed tests"
)

# gates that are not native-engine gates (a package-level check): excluded from the C2 set comparison
non_native <- "s7-lifecycle"

criteria_failures <- function(crit, gates, exports, root) {
  out <- character()
  for (i in seq_len(nrow(crit))) {
    ids <- strsplit(crit$ref[i], "|", fixed = TRUE)[[1L]]
    id <- crit$id[i]
    if (crit$kind[i] %in% c("gate", "gateset")) {
      miss <- setdiff(ids, gates$gate)
      if (length(miss)) out <- c(out, sprintf("%s: gate(s) not in gates.csv: %s", id, paste(miss, collapse = ", ")))
    }
    if (crit$kind[i] == "gateset") {
      extra <- setdiff(setdiff(gates$gate, non_native), ids)
      if (length(extra)) {
        out <- c(out, sprintf("%s: gate(s) not in the criteria: %s", id, paste(extra, collapse = ", ")))
      }
    }
    if (crit$kind[i] == "export") {
      miss <- setdiff(ids, exports)
      if (length(miss)) out <- c(out, sprintf("%s: not exported: %s", id, paste(miss, collapse = ", ")))
    }
    if (crit$kind[i] == "doc" && !file.exists(file.path(root, crit$ref[i]))) {
      out <- c(out, sprintf("%s: reference page missing: %s", id, crit$ref[i]))
    }
    if (!file.exists(file.path(root, crit$doc[i]))) out <- c(out, sprintf("%s: doc page missing: %s", id, crit$doc[i]))
  }
  out
}

crit <- utils::read.csv(crit_file, stringsAsFactors = FALSE)
gates <- utils::read.csv(gates_file, stringsAsFactors = FALSE, na.strings = c("NA", ""))
exports <- getNamespaceExports("medfit")

test_that("every criterion names evidence that exists (control)", {
  expect_identical(criteria_failures(crit, gates, exports, root), character())
  expect_setequal(crit$id, c("C1", "C2", "C3a", "C3b", "C4a", "C4b"))
})

test_that("planted defects are caught", {
  # a deleted gate row
  expect_match(criteria_failures(crit, gates[gates$gate != "factor", ], exports, root), "not in gates.csv: factor",
               all = FALSE)
  # a new native gate nobody listed
  extra <- gates[1L, ]
  extra$gate <- "brand-new-gate"
  expect_match(criteria_failures(crit, rbind(gates, extra), exports, root), "not in the criteria: brand-new-gate",
               all = FALSE)
  # a package-level gate does not need listing
  expect_identical(non_native, "s7-lifecycle")
  # a missing export
  no_mbco <- setdiff(exports, "mbco_sem")
  expect_match(criteria_failures(crit, gates, no_mbco, root), "not exported: mbco_sem", all = FALSE)
  # a missing page
  bad <- crit
  bad$doc[bad$id == "C3a"] <- "vignettes/articles/no-such-page.qmd"
  expect_match(criteria_failures(bad, gates, exports, root), "doc page missing", all = FALSE)
})
