# Every article that makes a native fit carries one hidden setup chunk that consumes the once-per-session
# default-change warning (0.14.0, T5a), so the rendered pages stay quiet once the warning lands (T5).
# Skipped when the vignettes are absent (installed or built package).

root_path <- function(...) testthat::test_path("..", "..", ...)

native_fit_pattern <- "fit_sem\\(|engine\\s*=\\s*\"native\""

# Body lines of the chunk labeled `native-defaults-setup`, or NULL when there is none.
setup_chunk <- function(lines) {
  lab <- grep("^#\\|\\s*label:\\s*native-defaults-setup\\s*$", lines)
  if (length(lab) != 1L) {
    return(NULL)
  }
  open <- max(grep("^```\\{r", lines[seq_len(lab)]))
  close <- lab + min(grep("^```\\s*$", lines[(lab + 1):length(lines)]))
  list(open = open, body = lines[(open + 1):(close - 1)])
}

test_that("every article with a native fit has the hidden setup chunk before its first native fit", {
  d <- root_path("vignettes", "articles")
  testthat::skip_if_not(dir.exists(d), "vignettes are not available (installed or built package)")
  files <- list.files(d, pattern = "\\.qmd$", full.names = TRUE)
  native <- Filter(function(f) any(grepl(native_fit_pattern, readLines(f, warn = FALSE))), files)
  expect_gte(length(native), 1L)
  for (f in native) {
    lines <- readLines(f, warn = FALSE)
    chunk <- setup_chunk(lines)
    expect_false(is.null(chunk), label = paste(basename(f), "has a native-defaults-setup chunk"))
    if (is.null(chunk)) next
    expect_true(any(grepl("^#\\|\\s*include:\\s*false\\s*$", chunk$body)),
                label = paste(basename(f), "setup chunk is include: false"))
    expect_true(any(grepl("medfit_warning_default_change", chunk$body, fixed = TRUE)),
                label = paste(basename(f), "setup chunk muffles only the default-change class"))
    expect_true(any(grepl("medfit::fit_sem(", chunk$body, fixed = TRUE)),
                label = paste(basename(f), "setup chunk calls the public fit_sem()"))
    first_fit <- min(setdiff(grep(native_fit_pattern, lines), chunk$open + seq_along(chunk$body)))
    expect_lt(chunk$open, first_fit, label = paste(basename(f), "setup chunk precedes the first native fit"))
  }
})

test_that("the setup chunk's code runs and leaves no visible output", {
  d <- root_path("vignettes", "articles")
  testthat::skip_if_not(dir.exists(d), "vignettes are not available (installed or built package)")
  chunk <- setup_chunk(readLines(file.path(d, "model-native.qmd"), warn = FALSE))
  code <- grep("^#", chunk$body, value = TRUE, invert = TRUE)
  out <- utils::capture.output(res <- withVisible(eval(parse(text = code), envir = new.env())))
  expect_identical(out, character(0))
  expect_false(res$visible)
})
