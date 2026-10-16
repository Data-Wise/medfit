# The product-term error tables quoted in the docs: the "Product terms" section of ?"medfit-syntax"
# (R/sem-syntax-help.R, man/medfit-syntax.Rd) and the supported-class table in
# vignettes/articles/model-native.qmd (model-interaction.qmd links to it). Every quoted fragment has a trigger here,
# and where the doc sources are reachable the quoted fragments are parsed from them, so a table row added, removed or
# reworded without its trigger fails this file instead of leaving the docs wrong under green tests.

pmsg_data <- function(n = 120L, seed = 3L) {
  withr::local_seed(seed)
  d <- data.frame(x = rnorm(n), w = rnorm(n), c = rnorm(n))
  d$m <- 0.5 * d$x + rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * d$x + 0.2 * d$x * d$m + rnorm(n)
  d
}
pmsg_fit <- function(model, ...) suppressWarnings(fit_sem(model, pmsg_data(), se_type = "sandwich", ...))
pmsg_endo <- "m ~ x\ny ~ m + x + x:m"
pmsg_complete <- function(syntax) .sem_complete(.sem_parse(syntax)$parameters)
pmsg_extract <- function() {
  fit <- pmsg_fit("m ~ x + c\ny ~ x + m + x:m + x:c + c")
  extract_mediation(fit, treatment = "x", mediator = "m")
}
pmsg_anova <- function() anova(pmsg_fit(pmsg_endo), pmsg_fit("m ~ x\ny ~ m + x:m"))
pmsg_rescov <- function() pmsg_complete("m1 ~ x\nm2 ~ x\ny ~ m1 + m2 + x:m1\nm1 ~~ m2")
pmsg_expected <- function() pmsg_fit(pmsg_endo, information = "expected")

# list(fragment as the docs quote it, function() that must fail with a message containing it)
pmsg_cases <- function() {
  lab <- "m ~ a*x\ny ~ b*m + x:m\n"
  list(
    list("a product ':' needs a variable name on each side, written without spaces (x:m)",
         function() .sem_parse("Y ~ x :m")),
    list("of a variable with itself is not supported", function() .sem_parse("Y ~ x:x")),
    list("a three-way or higher product", function() .sem_parse("Y ~ x:m:w")),
    list("cannot be a left side", function() .sem_parse("x:m ~ y")),
    list("cannot be a left side", function() .sem_parse("x:m ~~ y")),
    list("is only valid on the right side of a regression", function() .sem_parse("eta =~ x:m")),
    list("not inside the expression", function() .sem_parse("Y ~ a*X\nab := a*x:m")),
    list("products with latent variables are not supported in this version",
         function() .sem_parse("eta =~ m1 + m2 + m3\ny ~ eta + x\ny ~ eta:x")),
    list("are the same product (canonical name", function() .sem_parse("y ~ x:m + m:x")),
    list("(rule 8: no outcome-derived regressors)", function() pmsg_complete("y ~ x + x:y")),
    list("The model is not recursive", function() pmsg_complete("y ~ z + x:w\nz ~ y")),
    list("cannot have a residual covariance (rule 9)", pmsg_rescov),
    list("A product model cannot have a residual covariance (rule 9)", pmsg_rescov),
    list("is used on more than one parameter", function() pmsg_complete("m ~ a*x\ny ~ a*m + x:m")),
    list("has a fixed coefficient (rule 9)", function() pmsg_complete("m ~ x\ny ~ 0.3*x + x:m")),
    list("has a fixed coefficient (rule 9)", function() pmsg_complete("m ~ x\ny ~ 0*x + x:m")),
    list("has a bound (rule 9", function() pmsg_complete("m ~ x\ny ~ lower(0)*m + x:m")),
    list("names the coefficient label", function() pmsg_complete(paste0(lab, "a == b"))),
    list("names the coefficient label", function() pmsg_complete(paste0(lab, "a < 1"))),
    list("(rule 9, intercept clause", function() pmsg_complete("y ~ x + m + x:m\nm ~ x\ny ~ 0*1")),
    list("`meanstructure = FALSE`, but the model has a product term",
         function() pmsg_fit(pmsg_endo, meanstructure = FALSE)),
    list("is not the product of", function() {
      d <- pmsg_data()
      d[["m:x"]] <- d$x * d$m + 0.01
      suppressWarnings(fit_sem(pmsg_endo, d, se_type = "sandwich"))
    }),
    list("needs numeric variables", function() {
      d <- pmsg_data()
      d$m <- as.Date("2026-01-01") + seq_len(nrow(d)) # a factor, character or logical column is expanded instead
      fit_sem("y ~ x + x:m", d)
    }),
    list("with a product of an endogenous variable", pmsg_expected),
    list("is not available for a model with a product of an endogenous variable", pmsg_expected),
    list("is not available for", pmsg_anova),
    list("a model with a product term", pmsg_anova),
    list("does not support the product", pmsg_extract),
    list("the native extraction does not support the product", pmsg_extract)
  )
}

# TRUE when the trigger errors with a message that contains the fragment as quoted.
pmsg_produces <- function(case) {
  msg <- tryCatch({
    case[[2]]()
    NA_character_
  }, error = function(e) conditionMessage(e))
  !is.na(msg) && grepl(case[[1]], msg, fixed = TRUE)
}

# The quoted fragments of the last cell of every row of the table that follows `anchor` in a doc source.
pmsg_doc_fragments <- function(path, anchor) {
  lines <- sub("^#' ?", "", readLines(path, warn = FALSE))
  lines <- lines[seq(grep(anchor, lines, fixed = TRUE)[1], length(lines))]
  first <- match(TRUE, startsWith(lines, "| Limit |"))
  tbl <- lines[seq(first, length(lines))]
  tbl <- tbl[seq_len(min(which(!startsWith(tbl, "|")), length(tbl) + 1L) - 1L)]
  rows <- tbl[-(1:2)]
  stopifnot(length(rows) > 10L)
  cells <- vapply(strsplit(rows, " | ", fixed = TRUE), function(p) sub(" \\|$", "", p[length(p)]), character(1))
  quoted <- unlist(regmatches(cells, gregexpr('"[^"]*"', cells)))
  unlist(strsplit(substring(quoted, 2L, nchar(quoted) - 1L), " ... ", fixed = TRUE))
}

test_that("every fragment quoted in the product error tables is produced by its trigger", {
  for (case in pmsg_cases()) {
    expect_true(pmsg_produces(case), info = case[[1]])
  }
})

test_that("the tables in the docs and the triggers here quote the same fragments", {
  rd <- testthat::test_path("..", "..", "R", "sem-syntax-help.R")
  qmd <- testthat::test_path("..", "..", "vignettes", "articles", "model-native.qmd")
  skip_if_not(file.exists(rd) && file.exists(qmd), "doc sources are not part of the installed package")
  documented <- unique(c(
    pmsg_doc_fragments(rd, "@section Product terms:"),
    pmsg_doc_fragments(qmd, "A product is fitted only in the class below")
  ))
  covered <- unique(vapply(pmsg_cases(), `[[`, character(1), 1L))
  expect_setequal(documented, covered)
})

test_that("planted defect: a reworded message fails the trigger check", {
  fx_skip_covr()
  case <- list("cannot be a left side", function() .sem_parse("x:m ~ y"))
  expect_true(pmsg_produces(case))
  bad <- sem_mutate(.sem_relation, "cannot be a left side", "may not be a left side")
  testthat::local_mocked_bindings(.sem_relation = bad)
  expect_false(pmsg_produces(case))
})
