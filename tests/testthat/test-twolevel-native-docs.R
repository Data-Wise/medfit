# The native two-level refusal table quoted in the docs: the "Two-level models (experimental)" section of
# ?"medfit-syntax" (R/sem-syntax-help.R, man/medfit-syntax.Rd), and the conditions the native section of
# vignettes/articles/model-twolevel.qmd quotes. Every quoted fragment has a trigger here, and the fragments are parsed
# from the doc source, so a table row added, removed or reworded without its trigger fails this file.

tlnd_data <- function() {
  dat <- tl_data_balanced()
  withr::local_seed(23)
  dat$Zc <- stats::rnorm(40)[dat$cluster] # constant within each cluster
  dat$Q <- stats::rnorm(nrow(dat)) # varies within clusters
  dat
}
tlnd_fit <- function(model = tl_lavaan_model, data = tlnd_data(), cluster = "cluster", ...) {
  suppressWarnings(fit_sem(model, data, cluster = cluster, ...))
}
# The inadmissible fixture of test-twolevel-native-extract.R: 30 clusters of 3, a negative level-2 variance.
tlnd_negative <- function() {
  withr::local_seed(1)
  j <- 30
  cl <- sort(rep(seq_len(j), 3))
  xb <- stats::rnorm(j)
  mb <- 0.5 * xb + stats::rnorm(j, sd = 0.3)
  yb <- 0.3 * mb + 0.2 * xb
  x <- xb[cl] + stats::rnorm(length(cl))
  m <- mb[cl] + 0.4 * x + stats::rnorm(length(cl))
  y <- yb[cl] + 0.3 * m + 0.2 * x + stats::rnorm(length(cl), sd = 1.5)
  data.frame(cluster = cl, X = x, M = m, Y = y)
}

# list(fragment as the docs quote it, function() that must fail with a message containing it)
tlnd_cases <- function() {
  zc <- "level: 1\nM ~ X\nY ~ M + X\nlevel: 2\nM ~ X + Zc\nY ~ M + X + Zc"
  varies <- function() {
    d <- tlnd_data()
    d$Zc[2] <- d$Zc[2] + 1
    tlnd_fit(zc, d)
  }
  one <- function() {
    d <- tlnd_data()
    d$cluster <- 1L
    tlnd_fit(data = d)
  }
  na <- function() {
    d <- tlnd_data()
    d$cluster[5] <- NA
    tlnd_fit(data = d)
  }
  list(
    list("is given but the model has no `level:` blocks", function() tlnd_fit("M ~ X\nY ~ M + X")),
    list("the model uses `level:` blocks but `cluster` is not given",
         function() fit_sem(tl_lavaan_model, tlnd_data())),
    list("is not a column of `data`", function() tlnd_fit(cluster = "school")),
    list("has missing values; drop those rows first", na),
    list("has fewer than 2 clusters", one),
    list("the model has more than two levels",
         function() tlnd_fit(paste(tl_lavaan_model, "level: 3\nY ~ X", sep = "\n"))),
    list("malformed level line", function() tlnd_fit(sub("level: 2", "level: school", tl_lavaan_model))),
    list("has statements before the first `level:` line",
         function() tlnd_fit(paste("X ~~ X", tl_lavaan_model, sep = "\n"))),
    list("appears more than once",
         function() tlnd_fit("level: 1\nM ~ X\nY ~ M + X\nlevel: 2\nM ~ X\nlevel: between\nY ~ M + X")),
    list("rows but no `level: 1` block", function() tlnd_fit("level: 2\nM ~ X\nY ~ M + X")),
    list("every level-1 variable also needs a `level: 2` row",
         function() tlnd_fit("level: 1\nM ~ X\nY ~ M + X + Q\nlevel: 2\nM ~ X\nY ~ M + X")),
    list("a cluster-level variable belongs only in `level: 2` rows",
         function() tlnd_fit("level: 1\nM ~ X + Zc\nY ~ M + X\nlevel: 2\nM ~ X + Zc\nY ~ M + X")),
    list("must be constant within each cluster", varies),
    list("latent variables (`=~`) are not supported in a two-level model",
         function() tlnd_fit(sub("level: 1", "level: 1\n  f =~ X + M + Y", tl_lavaan_model))),
    list("a product term (`x:m`) is not supported in a two-level model",
         function() tlnd_fit(paste(tl_lavaan_model, "  Y ~ X:M", sep = "\n"))),
    list("`weights` are not supported in a two-level model",
         function() tlnd_fit(weights = rep(1, nrow(tlnd_data())))),
    list("se_type =", function() tlnd_fit(se_type = "sandwich")),
    list("is not supported in a two-level model", function() tlnd_fit(se_type = "sandwich")),
    list("missing =", function() tlnd_fit(missing = "fiml")),
    list("incomplete rows are dropped (listwise)", function() tlnd_fit(missing = "fiml")),
    list("nonlinear constraints (including a product of labels",
         function() tlnd_fit(paste(tl_lavaan_model, "a_w*b_w == 0", sep = "\n"))),
    list("a two-level model takes `fixed_x = FALSE` only", function() tlnd_fit(fixed_x = TRUE)),
    list("`meanstructure = FALSE` is refused", function() tlnd_fit(meanstructure = FALSE)),
    list("information =", function() tlnd_fit(information = "expected")),
    list("is not supported in a two-level model; use", function() tlnd_fit(information = "expected")),
    list("the two-level solution is inadmissible", function() tlnd_fit(data = tlnd_negative()))
  )
}

tlnd_produces <- function(case) {
  msg <- tryCatch({
    case[[2]]()
    NA_character_
  }, error = function(e) conditionMessage(e))
  !is.na(msg) && grepl(case[[1]], msg, fixed = TRUE)
}

# The quoted fragments of the last cell of every row of the table that follows `anchor` in a doc source.
tlnd_doc_fragments <- function(path, anchor) {
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

test_that("every fragment quoted in the native two-level refusal table is produced by its trigger", {
  for (case in tlnd_cases()) {
    expect_true(tlnd_produces(case), info = case[[1]])
  }
})

test_that("the table in ?medfit-syntax and the triggers here quote the same fragments", {
  rd <- testthat::test_path("..", "..", "R", "sem-syntax-help.R")
  skip_if_not(file.exists(rd), "doc sources are not part of the installed package")
  documented <- unique(tlnd_doc_fragments(rd, "@section Two-level models (experimental):"))
  covered <- unique(vapply(tlnd_cases(), `[[`, character(1), 1L))
  expect_setequal(documented, covered)
})

test_that("the conditions the model page quotes for the native route are raised", {
  page <- testthat::test_path("..", "..", "vignettes", "articles", "model-twolevel.qmd")
  skip_if_not(file.exists(page), "doc sources are not part of the installed package")
  txt <- gsub("\\s+", " ", paste(readLines(page, warn = FALSE), collapse = "\n")) # prose wraps lines
  for (cls in c("medfit_error_twolevel_inadmissible", "medfit_warning_twolevel_few_clusters")) {
    expect_true(grepl(cls, txt, fixed = TRUE), info = cls)
  }
  err <- tryCatch(tlnd_fit(data = tlnd_negative()), error = function(e) e)
  expect_s3_class(err, "medfit_error_twolevel_inadmissible")
  expect_true(grepl("Level-2 variances are fitted without a floor (experimental)", conditionMessage(err), fixed = TRUE))
  expect_true(grepl("Level-2 variances are fitted without a floor", txt, fixed = TRUE))
  # the glance() note the page quotes
  g <- glance(tlnd_fit())
  expect_true(all(c("n_clusters", "cluster_size_min", "cluster_size_max") %in% names(g)))
  expect_true(is.na(g$chisq) && is.na(g$p_value))
  expect_true(grepl("the engine fits no saturated two-level model", txt, fixed = TRUE))
})

test_that("the lavaan route on the inadmissible data warns instead, as the model page says", {
  skip_if_not_installed("lavaan")
  d <- tlnd_negative()
  model <- "level: 1\nM ~ X\nY ~ M + X\nlevel: 2\nM ~ X\nY ~ M + X"
  fit <- suppressWarnings(lavaan::sem(model, data = d, cluster = "cluster"))
  seen <- character()
  out <- withCallingHandlers(extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"),
                             warning = function(w) {
                               seen <<- c(seen, class(w)[1L])
                               invokeRestart("muffleWarning")
                             })
  expect_true(S7::S7_inherits(out, TwoLevelMediationData))
  expect_true("medfit_warning_twolevel_inadmissible" %in% seen)
})

test_that("planted defect: a reworded table fragment or a lost trigger fails the checks", {
  case <- list("must be constant within each cluster", function() tlnd_fit())
  expect_false(tlnd_produces(case)) # the valid base model raises nothing
  reworded <- list("must be fixed within each cluster", tlnd_cases()[[13]][[2]])
  expect_false(tlnd_produces(reworded))
  rd <- testthat::test_path("..", "..", "R", "sem-syntax-help.R")
  skip_if_not(file.exists(rd), "doc sources are not part of the installed package")
  tmp <- withr::local_tempfile(fileext = ".R")
  src <- readLines(rd, warn = FALSE)
  writeLines(sub("has fewer than 2 clusters", "has under 2 clusters", src, fixed = TRUE), tmp)
  documented <- unique(tlnd_doc_fragments(tmp, "@section Two-level models (experimental):"))
  covered <- unique(vapply(tlnd_cases(), `[[`, character(1), 1L))
  expect_false(setequal(documented, covered))
})
