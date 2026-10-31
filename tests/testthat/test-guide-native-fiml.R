native_fiml_chunk <- function(label) {
  path <- testthat::test_path("..", "..", "vignettes", "articles", "native-guide.qmd")
  testthat::skip_if_not(file.exists(path), "article source is unavailable")
  lines <- readLines(path, warn = FALSE)
  at <- which(lines == paste0("#| label: ", label))
  stopifnot(length(at) == 1L)
  end <- at + which(lines[(at + 1L):length(lines)] == "```")[[1]]
  parse(text = lines[(at + 1L):(end - 1L)])
}

native_fiml_continuous <- function(data) {
  identical(names(data), c("treatment", "mediator1", "outcome")) &&
    all(vapply(data, function(x) {
      is.numeric(x) && all(is.finite(x[!is.na(x)])) && length(unique(x[!is.na(x)])) > 20L
    }, logical(1)))
}

test_that("native-guide FIML data are continuous and preserve the caller RNG", {
  withr::local_preserve_seed()
  set.seed(42L)
  before <- .Random.seed
  env <- new.env(parent = asNamespace("medfit"))
  eval(native_fiml_chunk("bounded-fiml-data"), env)
  expect_identical(.Random.seed, before)
  expect_true(native_fiml_continuous(env$fiml_data))
  expect_equal(nrow(env$fiml_data), 400L)
  expect_equal(colSums(is.na(env$fiml_data)), c(treatment = 0L, mediator1 = 58L, outcome = 0L))
  # The old numeric 0/1 fixture must fail even though it is not an R factor.
  binary <- env$fiml_data
  binary$treatment <- rep(0:1, length.out = nrow(binary))
  expect_false(native_fiml_continuous(binary))
})

test_that("both executed native-guide FIML entry points agree", {
  env <- new.env(parent = asNamespace("medfit"))
  for (label in c("bounded-fiml-data", "bounded-fiml-workflow", "bounded-fiml-wrapper")) {
    invisible(utils::capture.output(eval(native_fiml_chunk(label), env)))
  }
  expect_true(native_fiml_continuous(env$fiml_data))
  expect_equal(stats::nobs(env$fiml_fit), 400L)
  expect_true(is.finite(as.numeric(stats::logLik(env$fiml_fit))))
  expect_equal(stats::coef(env$fiml_wrapped), stats::coef(env$fiml_effects), tolerance = 1e-8)
  expect_equal(stats::vcov(env$fiml_wrapped), stats::vcov(env$fiml_effects), tolerance = 1e-8)
  expect_equal(tidy(env$fiml_wrapped, type = "effects"), tidy(env$fiml_effects, type = "effects"),
               tolerance = 1e-8)
})
