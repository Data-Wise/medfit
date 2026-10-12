# Consistency guard for the cookbook (SPEC-refcard-cookbook T4/T5): twelve numbered
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

test_that("the cookbook has twelve numbered recipes and every article link resolves", {
  cb <- article_text("cookbook.qmd")
  heads <- regmatches(cb, gregexpr("(?m)^## [0-9]+\\. ", cb, perl = TRUE))[[1]]
  expect_identical(trimws(sub("^## ", "", heads)), paste0(1:12, "."))
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

test_that("the introduction articles point at the refcard and the cookbook", {
  for (a in c("getting-started.qmd", "introduction.qmd")) {
    txt <- article_text(a)
    expect_true(grepl("](refcard.html)", txt, fixed = TRUE), info = a)
    expect_true(grepl("](cookbook.html)", txt, fixed = TRUE), info = a)
  }
})

# Each task recipe must run after the setup chunk alone, so a reader can jump to
# any recipe. Running the page top to bottom hides a fit that only an earlier
# recipe defines. The cluster, lavaan and native recipes (9-11) simulate their own
# data and are slow, so recipes 1-8, which share fitted models, are checked here.
cookbook_recipe_chunks <- function(cb_lines) {
  heads <- grep("^## ", cb_lines)
  bounds <- cbind(start = c(1L, heads), end = c(heads - 1L, length(cb_lines)))
  chunks <- function(a, b) {
    seg <- cb_lines[a:b]
    out <- list()
    i <- 1L
    while (i <= length(seg)) {
      if (grepl("^```\\{r", seg[i])) {
        j <- i + 1L
        while (!grepl("^```$", seg[j])) j <- j + 1L
        body <- seg[(i + 1L):(j - 1L)]
        out[[length(out) + 1L]] <- body[!grepl("^#\\|", body)]
        i <- j
      }
      i <- i + 1L
    }
    out
  }
  lapply(seq_len(nrow(bounds)), function(k) chunks(bounds[k, "start"], bounds[k, "end"]))
}

run_cookbook_recipe <- function(setup, chunks) {
  setup <- setup[!grepl("^library\\(medfit\\)", setup)]
  env <- new.env(parent = asNamespace("medfit"))
  tryCatch({
    suppressMessages(suppressWarnings({
      eval(parse(text = setup), env)
      env$tidy <- generics::tidy
      for (ch in chunks) eval(parse(text = ch), env)
    }))
    NULL
  }, error = function(e) conditionMessage(e))
}

test_that("each cookbook recipe 1-8 runs after the setup chunk alone", {
  article_text("cookbook.qmd") # skips when the vignettes are absent
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  setup <- unlist(parsed[[1L]])
  for (k in 1:8) {
    err <- run_cookbook_recipe(setup, parsed[[k + 1L]])
    expect_null(err, info = sprintf("recipe %d fails on its own: %s", k, err))
  }
})

test_that("planted defect: a recipe that needs an earlier recipe's fit is caught", {
  article_text("cookbook.qmd")
  parsed <- cookbook_recipe_chunks(readLines(article_path("cookbook.qmd"), warn = FALSE))
  setup <- unlist(parsed[[1L]])
  err <- run_cookbook_recipe(setup, list("fit_defined_in_another_recipe <- 1", "xb <- fit_never_defined"))
  expect_match(err, "fit_never_defined")
})
