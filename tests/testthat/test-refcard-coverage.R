# Drift guard for the reference card (SPEC-refcard-cookbook D6): every export and
# every class must be named in vignettes/articles/refcard.qmd. Articles are not
# in the built tarball, so the tests skip when the file is absent.

refcard_path <- function() {
  p <- testthat::test_path("..", "..", "vignettes", "articles", "refcard.qmd")
  if (file.exists(p)) p else NA_character_
}

refcard_missing <- function(text, names) {
  names[!vapply(names, function(n) grepl(n, text, fixed = TRUE), logical(1))]
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

test_that("the refcard's cluster formulas agree with the methods article", {
  rc <- refcard_path()
  skip_if(is.na(rc), "vignettes are not available (installed or built package)")
  rcx <- paste(readLines(rc, warn = FALSE), collapse = "\n")
  mx <- paste(readLines(file.path(dirname(rc), "methods.qmd"), warn = FALSE),
              collapse = "\n")
  expect_true(grepl("a [b_W + (b_B - b_W) / n_j]", rcx, fixed = TRUE))
  expect_true(grepl("b_W + \\frac{b_B - b_W}{n_j}", mx, fixed = TRUE))
})
