# Release-docs gates (ADR-docs-release-pipeline-2026-11-12, decisions RD-4 to RD-9).
# Each gate is a pure function over text, run on the real files and on a planted
# defect that must make it report a problem. Skips when the source tree is absent
# (installed or built package).

root_path <- function(...) testthat::test_path("..", "..", ...)
have_tree <- function() {
  file.exists(root_path("DESCRIPTION")) && dir.exists(root_path("vignettes", "articles")) &&
    file.exists(root_path("NEWS.md"))
}
read_lines <- function(...) readLines(root_path(...), warn = FALSE)

desc_version <- function() read.dcf(root_path("DESCRIPTION"), fields = "Version")[1L, 1L]
# a release version has three parts; a development version carries a fourth (0.17.0.9000)
is_release <- function(v) length(strsplit(v, "[.-]")[[1L]]) == 3L

stale_words <- "development version|unreleased"

# RD-4: NEWS opens with a heading for the version, and that section no longer says
# "unreleased" or "development version" once the version is a release
news_problems <- function(lines, v) {
  heads <- grep("^# ", lines)
  if (!length(heads) || lines[heads[1L]] != paste0("# medfit ", v)) {
    return(sprintf("NEWS.md does not open with '# medfit %s'", v))
  }
  end <- if (length(heads) > 1L) heads[2L] - 1L else length(lines)
  top <- lines[heads[1L]:end]
  hit <- grep(stale_words, top, ignore.case = TRUE, value = TRUE)
  if (is_release(v) && length(hit)) {
    return(paste("NEWS top section has stale wording:", substr(hit[1L], 1L, 60L)))
  }
  character()
}

# RD-5: pages that name the version they document name the DESCRIPTION version, and a
# release leaves no "development version"/"unreleased" in README or articles
prose_problems <- function(texts, v) {
  bad <- character()
  for (n in names(texts)) {
    pat <- "(documents|describes) medfit [0-9]+\\.[0-9]+\\.[0-9]+"
    claims <- regmatches(texts[[n]], gregexpr(pat, texts[[n]]))[[1L]]
    wrong <- claims[!grepl(paste0(" ", v, "$"), claims)]
    if (length(wrong)) bad <- c(bad, sprintf("%s says '%s', DESCRIPTION is %s", n, wrong[1L], v))
    if (is_release(v) && grepl(stale_words, texts[[n]], ignore.case = TRUE)) {
      bad <- c(bad, sprintf("%s has 'development version' or 'unreleased' in a release", n))
    }
  }
  bad
}

# RD-6: README carries a "What's new in <version>" block, and CITATION takes the version from DESCRIPTION
home_problems <- function(readme, citation, v) {
  bad <- character()
  if (!any(grepl(paste0("What's new in ", v), readme, fixed = TRUE))) {
    bad <- c(bad, sprintf("README has no \"What's new in %s\"", v))
  }
  if (!any(grepl("meta$Version", citation, fixed = TRUE)) || any(grepl("version [0-9]+\\.[0-9]+", citation))) {
    bad <- c(bad, "inst/CITATION does not take its version from DESCRIPTION")
  }
  bad
}

# RD-7: CLAUDE.md "Current status" names the version, and .STATUS' newest 40 lines mention it
status_problems <- function(claude, status, v) {
  bad <- character()
  line <- grep("^\\*\\*Current status:\\*\\*", claude, value = TRUE)
  if (length(line) != 1L || !grepl(v, substr(line, 1L, 160L), fixed = TRUE)) {
    bad <- c(bad, sprintf("CLAUDE.md 'Current status' does not name %s in its first 160 characters", v))
  }
  if (!any(grepl(v, utils::head(status, 40L), fixed = TRUE))) {
    bad <- c(bad, sprintf(".STATUS: none of the newest 40 lines mention %s", v))
  }
  bad
}

# RD-8: the FIML caveat is on the home page and on the FIML page, one sentence each (a marker, not a count of pages)
caveat <- "not statistically admitted"
caveat_problems <- function(readme, fiml) {
  as.character(c(
    if (!any(grepl(caveat, readme, fixed = TRUE))) "README lacks the FIML caveat",
    if (!any(grepl(caveat, fiml, fixed = TRUE))) "model-fiml.qmd lacks the FIML caveat"
  ))
}

# RD-9: layout rules. Next block and hidden setup on each model page; the native pages are listed until the
# sem-vocabulary prose slice lands (then delete the list); navbar at most 8 items; contrast of the navbar CSS
native_pending <- c("model-native", "model-native-constraints", "model-native-factors", "model-native-latent",
                    "model-native-multi")
page_problems <- function(pages) {
  bad <- character()
  for (n in setdiff(names(pages), native_pending)) {
    p <- pages[[n]]
    if (!any(grepl("{.next-action}", p, fixed = TRUE))) bad <- c(bad, paste(n, "has no Next block"))
    i <- grep("#| label: setup", p, fixed = TRUE)
    if (length(i) && !any(grepl("#| include: false", p[i[1L]:min(i[1L] + 2L, length(p))], fixed = TRUE))) {
      bad <- c(bad, paste(n, "shows its setup chunk output"))
    }
  }
  bad
}
navbar_problems <- function(yml, max_items = 8L) {
  m <- regmatches(yml, regexpr("left: +\\[[^]]*\\]", yml))
  n <- length(strsplit(sub("left: +\\[", "", sub("\\]$", "", m)), ",")[[1L]])
  if (n > max_items) sprintf("navbar has %d items, limit %d", n, max_items) else character()
}
lum <- function(hex) {
  rgb <- strtoi(substring(sub("#", "", hex), c(1, 3, 5), c(2, 4, 6)), 16L) / 255
  sum(c(0.2126, 0.7152, 0.0722) * ifelse(rgb <= 0.03928, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4))
}
contrast <- function(a, b) {
  x <- sort(c(lum(a), lum(b)), decreasing = TRUE)
  (x[1L] + 0.05) / (x[2L] + 0.05)
}
contrast_problems <- function(scss, bg = "#d9dadb", min = 4.5) {
  # the darkest navbar background seen in the Lighthouse pass is the active item, #d9dadb
  scss <- paste(scss, collapse = "\n")
  cols <- regmatches(scss, gregexpr("(?<=color: )#[0-9a-fA-F]{6}", scss, perl = TRUE))[[1L]]
  if (!length(cols)) return("extra.scss sets no colors")
  low <- cols[vapply(cols, contrast, numeric(1), b = bg) < min]
  if (length(low)) paste("colors below 4.5:1 on", bg, ":", paste(low, collapse = " ")) else character()
}

# documentation coverage: every export has an Rd alias
export_problems <- function(namespace, aliases) {
  ex <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", namespace, value = TRUE))
  ex <- gsub("\"", "", ex)
  miss <- setdiff(ex, aliases)
  if (!length(miss)) return(character())
  paste("exports without an Rd alias:", paste(utils::head(miss, 5L), collapse = ", "))
}

test_that("NEWS has a heading for the DESCRIPTION version and no stale wording in a release", {
  skip_if_not(have_tree(), "source tree not available")
  expect_identical(news_problems(read_lines("NEWS.md"), desc_version()), character())
})

test_that("planted defects: the NEWS gate catches a missing heading and stale wording", {
  ok <- c("# medfit 1.2.0", "", "* a feature", "# medfit 1.1.0", "* old, unreleased")
  expect_identical(news_problems(ok, "1.2.0"), character())
  expect_match(news_problems(c("# medfit 1.1.0", "* x"), "1.2.0"), "does not open")
  expect_match(news_problems(c("# medfit 1.2.0", "* (the adapter is unreleased)"), "1.2.0"), "stale wording")
  # a development version may still say it
  expect_identical(news_problems(c("# medfit 1.2.0.9000", "* unreleased"), "1.2.0.9000"), character())
})

test_that("README and articles name the DESCRIPTION version and carry no stale wording", {
  skip_if_not(have_tree(), "source tree not available")
  files <- c(list.files(root_path("vignettes", "articles"), "\\.qmd$", full.names = TRUE), root_path("README.md"))
  one <- function(f) paste(readLines(f, warn = FALSE), collapse = "\n")
  texts <- stats::setNames(lapply(files, one), basename(files))
  expect_identical(prose_problems(texts, desc_version()), character())
})

test_that("planted defects: the prose gate catches a stale version claim and stale wording", {
  expect_identical(prose_problems(list(a = "This site documents medfit 1.2.0."), "1.2.0"), character())
  expect_match(prose_problems(list(a = "This card describes medfit 1.1.0"), "1.2.0"), "DESCRIPTION is 1.2.0")
  expect_match(prose_problems(list(a = "in the development version"), "1.2.0"), "development version")
  expect_identical(prose_problems(list(a = "in the development version"), "1.2.0.9000"), character())
})

test_that("README has the What's new block and CITATION takes the DESCRIPTION version", {
  skip_if_not(have_tree(), "source tree not available")
  expect_identical(home_problems(read_lines("README.md"), read_lines("inst", "CITATION"), desc_version()), character())
})

test_that("planted defects: the home gate catches a stale What's new and a hard-coded CITATION version", {
  cit <- "note = sprintf(\"R package version %s\", meta$Version)"
  expect_identical(home_problems("What's new in 1.2.0", cit, "1.2.0"), character())
  expect_match(home_problems("What's new in 1.1.0", cit, "1.2.0"), "What's new in 1.2.0")
  expect_match(home_problems("What's new in 1.2.0", "note = \"R package version 1.1.0\"", "1.2.0"), "CITATION")
})

test_that("CLAUDE.md and .STATUS status lines name the DESCRIPTION version", {
  skip_if_not(have_tree() && file.exists(root_path("CLAUDE.md")) && file.exists(root_path(".STATUS")),
              "CLAUDE.md or .STATUS not available")
  expect_identical(status_problems(read_lines("CLAUDE.md"), read_lines(".STATUS"), desc_version()), character())
})

test_that("planted defects: the status gate catches a stale CLAUDE.md line and a stale .STATUS", {
  cl <- "**Current status:** 2026-11-12: **1.2.0 released** (see above)"
  expect_identical(status_problems(cl, "# 1.2.0 prep", "1.2.0"), character())
  old <- "**Current status:** 2026-10-31: **1.1.0 released**"
  expect_match(status_problems(old, "# 1.2.0", "1.2.0")[1L], "CLAUDE.md")
  expect_match(status_problems(cl, "# 1.1.0 prep", "1.2.0"), ".STATUS")
})

test_that("the FIML caveat is on the home page and on the FIML page", {
  skip_if_not(have_tree(), "source tree not available")
  expect_identical(caveat_problems(read_lines("README.md"), read_lines("vignettes", "articles", "model-fiml.qmd")),
                   character())
})

test_that("planted defects: the caveat gate names the page that lost the sentence", {
  expect_match(caveat_problems("nothing", "not statistically admitted"), "README")
  expect_match(caveat_problems("not statistically admitted", "nothing"), "model-fiml")
})

test_that("model pages follow the template, the navbar is short and its colors are readable", {
  skip_if_not(have_tree() && file.exists(root_path("_pkgdown.yml")), "source tree not available")
  dir <- root_path("vignettes", "articles")
  fs <- list.files(dir, "^model-.*\\.qmd$", full.names = TRUE)
  pages <- stats::setNames(lapply(fs, readLines, warn = FALSE), sub("\\.qmd$", "", basename(fs)))
  expect_identical(page_problems(pages), character())
  yml <- paste(readLines(root_path("_pkgdown.yml"), warn = FALSE), collapse = "\n")
  expect_identical(navbar_problems(yml), character())
  skip_if_not(file.exists(root_path("pkgdown", "extra.scss")), "extra.scss not available")
  expect_identical(contrast_problems(readLines(root_path("pkgdown", "extra.scss"), warn = FALSE)), character())
})

test_that("planted defects: layout gates catch a missing Next block, shown setup, a long navbar and a pale color", {
  good <- c("#| label: setup", "#| include: false", "library(medfit)", "::: {.next-action}")
  expect_identical(page_problems(list(`model-x` = good)), character())
  expect_match(page_problems(list(`model-x` = good[1:3])), "no Next block")
  expect_match(page_problems(list(`model-x` = good[c(1, 3, 4)])), "setup chunk")
  expect_identical(page_problems(list(`model-native` = "no template yet")), character())  # pending list
  expect_match(navbar_problems("left:  [a, b, c, d, e, f, g, h, i]"), "9 items")
  expect_identical(navbar_problems("left:  [a, b, c, d, e, f, g, h]"), character())
  expect_match(contrast_problems("a { color: #909294; }"), "below 4.5:1")
  expect_identical(contrast_problems("a { color: #3f4244; }"), character())
})

test_that("every export has an Rd alias", {
  skip_if_not(have_tree() && dir.exists(root_path("man")), "man/ not available")
  rd <- list.files(root_path("man"), "\\.Rd$", full.names = TRUE)
  aliases <- unlist(lapply(rd, function(f) {
    l <- readLines(f, warn = FALSE)
    sub("^\\\\alias\\{(.*)\\}$", "\\1", grep("^\\\\alias\\{", l, value = TRUE))
  }))
  expect_identical(export_problems(readLines(root_path("NAMESPACE"), warn = FALSE), aliases), character())
})

test_that("planted defect: the export gate catches an undocumented export", {
  expect_identical(export_problems("export(a)", "a"), character())
  expect_match(export_problems(c("export(a)", "export(b)"), "a"), "without an Rd alias: b")
})
