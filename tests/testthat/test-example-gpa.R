# The worked example (vignettes/articles/example-gpa.qmd) ends in stopifnot(all(checks$pass)). Run its code here so a
# regression breaks the test suite, not only the site build. The planted defect shows a check can fail.

example_gpa_path <- function() {
  p <- file.path(testthat::test_path("..", "..", "vignettes", "articles"), "example-gpa.qmd")
  if (file.exists(p)) p else NA_character_
}

run_example_gpa <- function(path, mutate = identity) {
  code <- tempfile(fileext = ".R")
  knitr::purl(path, output = code, quiet = TRUE, documentation = 0)
  src <- mutate(readLines(code))
  src <- src[!grepl("^library\\(medfit\\)", src)]
  env <- new.env(parent = asNamespace("medfit"))
  env$tidy <- generics::tidy
  env$glance <- generics::glance
  tc <- textConnection(src)
  on.exit(close(tc))
  error <- tryCatch({
    eval(parse(tc), env)
    NULL
  }, error = function(e) conditionMessage(e))
  list(env = env, error = error)
}

test_that("every check in the GPA worked example passes", {
  skip_on_cran()
  skip_if_not_installed("knitr")
  path <- example_gpa_path()
  skip_if(is.na(path), "vignettes not available")
  res <- run_example_gpa(path)
  expect_null(res$error)
  checks <- res$env$checks
  expect_gte(nrow(checks), 20)
  expect_true(all(checks$pass), info = paste(checks$check[!checks$pass], collapse = "; "))
})

test_that("planted defect: a wrong truth makes the GPA example fail", {
  skip_on_cran()
  skip_if_not_installed("knitr")
  path <- example_gpa_path()
  skip_if(is.na(path), "vignettes not available")
  res <- run_example_gpa(path, function(src) sub("b = 0.12,", "b = 0.20,", src, fixed = TRUE))
  expect_false(is.null(res$error))
  expect_match(res$error, "all\\(checks\\$pass\\)")
})
