# Consistency guard for the Models pages: every model-*.qmd page is on the landing
# page, in the pkgdown articles index and in the navbar; every article link and
# every cookbook anchor the pages and the navbar use resolves. Skips when the
# vignettes are absent (installed or built package).

root_path <- function(...) testthat::test_path("..", "..", ...)

page_names <- function() {
  d <- root_path("vignettes", "articles")
  testthat::skip_if_not(dir.exists(d), "vignettes are not available (installed or built package)")
  sub("\\.qmd$", "", list.files(d, pattern = "^model-.*\\.qmd$"))
}

read_text <- function(p) paste(readLines(p, warn = FALSE), collapse = "\n")

# The id pandoc gives a heading: leading number dropped, lowercased, punctuation
# removed, spaces to hyphens.
heading_id <- function(h) {
  h <- sub("^[0-9]+\\.\\s*", "", h)
  h <- gsub("`", "", tolower(h))
  h <- gsub("[^a-z0-9 -]", "", h)
  gsub(" +", "-", trimws(h))
}

cookbook_ids <- function() {
  testthat::skip_if_not(dir.exists(root_path("vignettes", "articles")),
                        "vignettes are not available (installed or built package)")
  cb <- readLines(root_path("vignettes", "articles", "cookbook.qmd"), warn = FALSE)
  heads <- sub("^## ", "", grep("^## ", cb, value = TRUE))
  vapply(heads, heading_id, character(1), USE.NAMES = FALSE)
}

anchors_in <- function(txt) {
  m <- regmatches(txt, gregexpr("cookbook\\.html#[a-z0-9-]+", txt))[[1]]
  unique(sub("^cookbook\\.html#", "", m))
}

test_that("every model page is on the landing page, in the articles index and in the navbar", {
  pages <- page_names()
  expect_gt(length(pages), 0L)
  landing <- read_text(root_path("vignettes", "articles", "models.qmd"))
  pk <- read_text(root_path("_pkgdown.yml"))
  for (p in pages) {
    expect_true(grepl(paste0("](", p, ".html)"), landing, fixed = TRUE), info = paste(p, "landing"))
    expect_true(grepl(paste0("articles/", p, "`"), pk, fixed = TRUE), info = paste(p, "articles index"))
    expect_true(grepl(paste0("articles/", p, ".html"), pk, fixed = TRUE), info = paste(p, "navbar"))
  }
})

test_that("every article link on the model pages resolves", {
  files <- c("models", page_names())
  for (f in files) {
    txt <- read_text(root_path("vignettes", "articles", paste0(f, ".qmd")))
    links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z-]+)\\.html[#)]", txt))[[1]])
    targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
    missing <- targets[!file.exists(root_path("vignettes", "articles", targets))]
    expect_identical(missing, character(), info = f)
  }
})

test_that("every cookbook anchor used by the model pages and the navbar is a real recipe", {
  ids <- cookbook_ids()
  expect_length(ids, 11L)
  txt <- c(vapply(c("models", page_names()), function(f) {
    read_text(root_path("vignettes", "articles", paste0(f, ".qmd")))
  }, character(1)), read_text(root_path("_pkgdown.yml")))
  used <- unique(unlist(lapply(txt, anchors_in)))
  expect_gt(length(used), 0L)
  expect_identical(setdiff(used, ids), character())
})

test_that("the anchor check catches a planted broken anchor", {
  ids <- cookbook_ids()
  planted <- "see [x](cookbook.html#no-such-recipe) and [y](cookbook.html#binary-outcome)"
  expect_identical(setdiff(anchors_in(planted), ids), "no-such-recipe")
})

test_that("the home page and Getting Started link to real articles and cookbook anchors", {
  skip_if_not(file.exists(root_path("README.md")), "README.md is not available (built package)")
  arts <- root_path("vignettes", "articles")
  skip_if_not(dir.exists(arts), "vignettes are not available (installed or built package)")
  gs <- read_text(file.path(arts, "getting-started.qmd"))
  rd <- read_text(root_path("README.md"))

  # Getting Started uses relative links; the README uses absolute site links
  rel <- unique(gsub("^\\]\\(|\\.html[#)]$", "",
                     regmatches(gs, gregexpr("\\]\\(([a-z-]+)\\.html[#)]", gs))[[1]]))
  site <- "https://data-wise\\.github\\.io/medfit/articles/[a-z-]+\\.html"
  abs <- unique(sub("^.*/articles/([a-z-]+)\\.html.*$", "\\1", regmatches(rd, gregexpr(site, rd))[[1]]))
  expect_gt(length(rel), 5L)
  expect_gt(length(abs), 5L)
  missing <- setdiff(c(rel, abs), sub("\\.qmd$", "", list.files(arts, pattern = "\\.qmd$")))
  expect_identical(missing, character())

  ids <- cookbook_ids()
  expect_identical(setdiff(unique(c(anchors_in(gs), anchors_in(rd))), ids), character())
})
