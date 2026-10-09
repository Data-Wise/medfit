# Consistency guard for the cookbook (SPEC-refcard-cookbook T4/T5): ten numbered
# recipes, every article link resolves, and the cluster recipe simulates the same
# data as methods.qmd so their numbers agree. Skips when the vignettes are absent
# (installed or built package).

article_path <- function(name) {
  p <- testthat::test_path("..", "..", "vignettes", "articles", name)
  if (file.exists(p)) p else NA_character_
}

article_text <- function(name) {
  p <- article_path(name)
  testthat::skip_if(is.na(p), "vignettes are not available (installed or built package)")
  paste(readLines(p, warn = FALSE), collapse = "\n")
}

test_that("the cookbook has ten numbered recipes and every article link resolves", {
  cb <- article_text("cookbook.qmd")
  heads <- regmatches(cb, gregexpr("(?m)^## [0-9]+\\. ", cb, perl = TRUE))[[1]]
  expect_identical(trimws(sub("^## ", "", heads)), paste0(1:10, "."))
  links <- unique(regmatches(cb, gregexpr("\\]\\(([a-z-]+)\\.html\\)", cb))[[1]])
  targets <- paste0(gsub("^\\]\\(|\\.html\\)$", "", links), ".qmd")
  expect_gt(length(targets), 0L)
  missing <- targets[is.na(vapply(targets, article_path, character(1)))]
  expect_identical(missing, character())
})

test_that("the cookbook's cluster recipe simulates the same data as methods.qmd", {
  cb <- article_text("cookbook.qmd")
  mx <- article_text("methods.qmd")
  lines <- c(
    "set.seed(2026)", "J <- 40", "n <- 10",
    "cdat$Y <- 0.2 * cdat$X + 0.3 * (cdat$M - mbar) + 0.6 * mbar + u[cl] + rnorm(J * n)"
  )
  for (l in lines) {
    expect_true(grepl(l, cb, fixed = TRUE), info = l)
    expect_true(grepl(l, mx, fixed = TRUE), info = l)
  }
})

test_that("planted defect: a changed seed in the cookbook is caught", {
  cb <- article_text("cookbook.qmd")
  broken <- sub("set.seed(2026)", "set.seed(2027)", cb, fixed = TRUE)
  expect_false(grepl("set.seed(2026)", broken, fixed = TRUE))
  expect_true(grepl("set.seed(2026)", cb, fixed = TRUE))
})
