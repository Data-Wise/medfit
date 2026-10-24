# Spec R-8 (native defaults): every `fit_sem()` call in the simulation gates states `fixed_x` and `meanstructure`, so a
# change of the defaults (0.15.0) cannot move a gate's baseline. A call is checked by its own argument text (nested
# parentheses and strings are skipped); comment lines are ignored. `fit_sem_pinned()` (product-gate-common.R) is the
# pinned default `fit_fun` of the product gates.

sim <- test_path("..", "sim")
skip_if_not(dir.exists(sim), "tests/sim is not shipped with the installed tests")

# the argument text of every fit_sem( call in `src`, comments removed
sp_calls <- function(src) {
  src <- gsub("(^|\n)[ \t]*#[^\n]*", "\\1", src)
  starts <- gregexpr("(?<![[:alnum:]_.])(medfit::)?fit_sem\\(", src, perl = TRUE)[[1]]
  if (starts[1] < 0) return(character())
  chars <- strsplit(src, "")[[1]]
  vapply(starts + attr(starts, "match.length") - 1L, function(open) {
    depth <- 0L
    quote <- ""
    for (i in open:length(chars)) {
      ch <- chars[i]
      if (nzchar(quote)) {
        if (ch == quote && chars[i - 1L] != "\\") quote <- ""
      } else if (ch %in% c("\"", "'")) {
        quote <- ch
      } else if (ch == "(") {
        depth <- depth + 1L
      } else if (ch == ")") {
        depth <- depth - 1L
        if (depth == 0L) return(paste(chars[(open + 1L):(i - 1L)], collapse = ""))
      }
    }
    NA_character_
  }, character(1))
}

sp_unpinned <- function(files) {
  out <- character()
  for (f in files) {
    args <- sp_calls(paste(readLines(f, warn = FALSE), collapse = "\n"))
    bad <- args[is.na(args) | !grepl("\\bfixed_x\\s*=", args) | !grepl("\\bmeanstructure\\s*=", args)]
    if (length(bad)) out <- c(out, paste0(basename(f), ": fit_sem(", bad, ")"))
  }
  out
}

test_that("every fit_sem() call in tests/sim states fixed_x and meanstructure", {
  expect_identical(sp_unpinned(list.files(sim, "\\.R$", full.names = TRUE)), character())
})

test_that("the product gates' default fit_fun is the pinned one", {
  for (f in c("exo-product-null.R", "exo-product-fixed-var.R", "product-correlated-residuals.R")) {
    src <- paste(readLines(file.path(sim, f), warn = FALSE), collapse = "\n")
    expect_match(src, "fit_fun = fit_sem_pinned", fixed = TRUE, info = f)
    expect_no_match(src, "fit_fun = fit_sem,", fixed = TRUE, info = f)
  }
})

test_that("planted defect: an unpinned call is reported", {
  tmp <- withr::local_tempfile(fileext = ".R")
  writeLines(c("# fit_sem(commented, out)", "a <- fit_sem(m, d, fixed_x = FALSE, meanstructure = NULL)",
               "b <- suppressWarnings(fit_sem(paste0(m, \"\\n\", c), d))"), tmp)
  bad <- sp_unpinned(tmp)
  expect_length(bad, 1L)
  expect_match(bad, "paste0(m", fixed = TRUE)
})
