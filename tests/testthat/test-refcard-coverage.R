# Drift guard for the reference card (SPEC-refcard-cookbook D6): every export and
# every class must be named in vignettes/articles/refcard.qmd. Articles are not
# in the built tarball, so the tests skip when the file is absent.

refcard_path <- function() {
  p <- testthat::test_path("..", "..", "vignettes", "articles", "refcard.qmd")
  if (file.exists(p)) p else NA_character_
}

# A name counts only as a whole word: `nie` inside `denied`, or `te` inside `tested`, is not a mention.
# Names ending in "(" are matched literally.
refcard_has <- function(text, n) {
  if (endsWith(n, "(")) {
    return(grepl(n, text, fixed = TRUE))
  }
  pat <- paste0("(?<![A-Za-z0-9_.])", gsub(".", "\\.", n, fixed = TRUE), "(?![A-Za-z0-9_.])")
  grepl(pat, text, perl = TRUE)
}

refcard_missing <- function(text, names) {
  names[!vapply(names, function(n) refcard_has(text, n), logical(1))]
}

refcard_exports <- function() {
  ex <- getNamespaceExports("medfit")
  setdiff(sort(ex[!startsWith(ex, ".__")]), c("tidy", "glance"))
}

test_that("the refcard names every export and every class", {
  p <- refcard_path()
  skip_if(is.na(p), "vignettes are not available (installed or built package)")
  text <- paste(readLines(p, warn = FALSE), collapse = "\n")
  classes <- c(
    "MediationData", "SerialMediationData", "ParallelMediationData",
    "InteractionMediationData", "JointMediationData", "ClusterMediationData"
  )
  expect_identical(refcard_missing(text, c(refcard_exports(), classes, "tidy(", "glance(")),
                   character())
})

test_that("planted defect: removing a name from the refcard is caught", {
  p <- refcard_path()
  skip_if(is.na(p), "vignettes are not available (installed or built package)")
  text <- paste(readLines(p, warn = FALSE), collapse = "\n")
  broken <- gsub("decompose", "decomp0se", text, fixed = TRUE)
  expect_identical(refcard_missing(broken, "decompose"), "decompose")
  expect_identical(refcard_missing(text, "decompose"), character())
})

test_that("planted defect: the name check is word-bounded, and a removed row is caught", {
  p <- refcard_path()
  skip_if(is.na(p), "vignettes are not available (installed or built package)")
  text <- paste(readLines(p, warn = FALSE), collapse = "\n")
  # bare substrings must not count: `nie` inside `denied`, `te` inside `tested`
  expect_identical(refcard_missing("denied and tested", c("nie", "te")), c("nie", "te"))
  expect_identical(refcard_missing("`nie(x)` and te(x)", c("nie", "te")), character())
  # remove the whole joint_effects row: the export is then reported missing
  rows <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  expect_true(any(grepl("joint_effects", rows, fixed = TRUE)))
  broken <- paste(rows[!grepl("joint_effects", rows, fixed = TRUE)], collapse = "\n")
  expect_identical(refcard_missing(broken, "joint_effects"), "joint_effects")
  expect_identical(refcard_missing(text, "joint_effects"), character())
})

test_that("the refcard's cluster formulas agree with the methods article", {
  rc <- refcard_path()
  skip_if(is.na(rc), "vignettes are not available (installed or built package)")
  rcx <- paste(readLines(rc, warn = FALSE), collapse = "\n")
  mx <- paste(readLines(file.path(dirname(rc), "methods.qmd"), warn = FALSE),
              collapse = "\n")
  expect_true(grepl("a [b_W + (b_B - b_W) / n_j]", rcx, fixed = TRUE))
  expect_true(grepl("b_W + \\frac{b_B - b_W}{n_j}", mx, fixed = TRUE))
})
