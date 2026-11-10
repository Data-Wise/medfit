# Docs guard for the two-level (1-1-1) page, recipe 23 and the Troubleshooting rows (#394 S2 PR4).
# The page and recipe chunks are run and their claims are checked against independent oracles (lm on
# cluster-centered data, lavaan's own `:=` standard errors); every condition the guide quotes is triggered for
# real. Skips when the vignettes are absent (installed or built package).

doc_path <- function(f) testthat::test_path("..", "..", "vignettes", "articles", f)
doc_text <- function(f) {
  p <- doc_path(f)
  testthat::skip_if_not(file.exists(p), "vignettes are not available (installed or built package)")
  paste(readLines(p, warn = FALSE), collapse = " ")
}

# The R code of every chunk of a .qmd file, with the chunk options and library() calls dropped.
doc_chunk_code <- function(f, drop = "^library\\(") {
  lines <- readLines(doc_path(f), warn = FALSE)
  open <- grep("^```\\{r", lines)
  unlist(lapply(open, function(i) {
    j <- i + 1L
    while (!grepl("^```$", lines[j])) j <- j + 1L
    body <- lines[(i + 1L):(j - 1L)]
    body[!grepl("^#\\|", body) & !grepl(drop, body)]
  }))
}

test_that("the model page runs and its claims hold against lm and lavaan", {
  skip_if_not_installed("lavaan")
  testthat::skip_if_not(file.exists(doc_path("model-twolevel.qmd")), "vignettes are not available")
  code <- doc_chunk_code("model-twolevel.qmd")
  env <- new.env(parent = asNamespace("medfit"))
  assign("tidy", generics::tidy, env)
  assign("glance", generics::glance, env)
  suppressMessages(suppressWarnings(eval(parse(text = code), env)))

  td <- env$td
  expect_s7_class(td, TwoLevelMediationData)
  # within paths: lm on cluster-centered data (the ML and LS estimates differ slightly)
  expect_equal(unname(paths(td)[1:3]), unname(env$ols), tolerance = 1e-3)
  # the NIE standard errors are lavaan's own defined-parameter standard errors
  pe <- lavaan::parameterEstimates(lavaan::sem(env$labeled, data = env$d, cluster = "id"))
  expect_equal(tidy(td, type = "effects")$std_error[c(1, 5, 9)], pe[pe$op == ":=", "se"], tolerance = 1e-3)
  # the contrast is within minus between
  expect_equal(as.numeric(nie(td, level = "contrast")),
               as.numeric(nie(td, level = "within")) - as.numeric(nie(td, level = "between")))
  # the within-only demonstration
  expect_identical(class(env$caught)[1], "medfit_between_unidentified")
  expect_false(env$td0@between_identified)
  expect_true(all(is.na(paths(env$td0)[4:6])))
  # equated paths: the contrast is NA and the equated path is listed
  expect_identical(env$td_eq@cross_level_equal, "a")
  expect_true(is.na(suppressWarnings(nie(env$td_eq, level = "contrast"))))
  expect_false(is.na(nie(env$td_eq, level = "between")))

  # planted defect: a within path off by 0.1 fails the lm comparison
  bad <- unname(paths(td)[1:3]) + c(0.1, 0, 0)
  expect_false(isTRUE(all.equal(bad, unname(env$ols), tolerance = 1e-3)))
})

test_that("recipe 23 runs after the setup chunk alone and its numbers match the page's estimands", {
  skip_if_not_installed("lavaan")
  testthat::skip_if_not(file.exists(doc_path("cookbook.qmd")), "vignettes are not available")
  lines <- readLines(doc_path("cookbook.qmd"), warn = FALSE)
  start <- grep("^## 23\\. ", lines)
  expect_length(start, 1L)
  rest <- lines[(start + 1L):length(lines)]
  rest <- rest[seq_len(grep("^## ", rest)[1] - 1L)]
  open <- grep("^```\\{r", rest)
  code <- unlist(lapply(open, function(i) {
    j <- i + 1L
    while (!grepl("^```$", rest[j])) j <- j + 1L
    b <- rest[(i + 1L):(j - 1L)]
    b[!grepl("^#\\|", b)]
  }))
  env <- new.env(parent = asNamespace("medfit"))
  assign("tidy", generics::tidy, env)
  suppressWarnings(eval(parse(text = code), env))
  z <- env$z
  expect_s7_class(z, TwoLevelMediationData)
  d2 <- env$d2
  dc <- data.frame(Xc = d2$X - ave(d2$X, d2$id), Mc = d2$M - ave(d2$M, d2$id), Yc = d2$Y - ave(d2$Y, d2$id))
  a_w <- unname(coef(lm(Mc ~ 0 + Xc, dc))["Xc"])
  b_w <- unname(coef(lm(Yc ~ 0 + Mc + Xc, dc))["Mc"])
  expect_equal(as.numeric(nie(z)), a_w * b_w, tolerance = 5e-3)
  # the recipe's own seed (a different one from the page, so the cookbook seed guard stays unambiguous)
  expect_true(grepl("set.seed(394)", paste(code, collapse = "\n"), fixed = TRUE))
  # planted defect: the between NIE is not the within NIE
  expect_gt(abs(as.numeric(nie(z, level = "between")) - as.numeric(nie(z))), 0.1)
})

# ---- every condition the guide quotes is real ----

# The condition of class `class` raised by extracting the cached fixture `fixture`.
tl_ex <- function(class, fixture = "base", ...) {
  tl_catch(extract_mediation(tl_fixture(fixture), "X", "M", "Y", ...), class)
}

tl_doc_cases <- function() {
  list(
    list("medfit_between_unidentified",
         "The between level is not identified, so only the within-level paths are returned",
         function() tl_ex("medfit_between_unidentified", "x_centered")),
    list("medfit_warning_between_weak", "The between-level variance of the treatment or the mediator is small",
         function() tl_ex("medfit_warning_between_weak", "x_small_between")),
    list("medfit_warning_twolevel_constrained", "The contrast NIE_within - NIE_between is NA",
         function() {
           td <- tl_extract(tl_fixture("shared_label"))
           tl_catch(nie(td, level = "contrast"), "medfit_warning_twolevel_constrained")
         }),
    list("medfit_warning_twolevel_inadmissible", "The lavaan fit is not admissible",
         function() {
           testthat::local_mocked_bindings(.twolevel_admissible = function(fit) FALSE, .package = "medfit")
           tl_catch(extract_mediation(tl_fixture("base"), "X", "M", "Y"), "medfit_warning_twolevel_inadmissible")
         }),
    list("medfit_warning_twolevel_few_clusters",
         "Two-level estimates and between-level standard errors are unreliable with few clusters",
         function() tl_ex("medfit_warning_twolevel_few_clusters", "j20")),
    list("medfit_warning_twolevel_labels_ignored", "is ignored for a two-level fit",
         function() {
           rlang::reset_warning_verbosity("medfit_twolevel_labels_ignored")
           tl_catch(extract_mediation(tl_fixture("base"), "X", "M", "Y", a_label = "alpha"),
                    "medfit_warning_twolevel_labels_ignored")
         }),
    list("medfit_error_twolevel_standardized", "standardized = TRUE is not supported for a two-level fit",
         function() tl_ex("medfit_error_twolevel_standardized", standardized = TRUE)),
    list("medfit_error_twolevel_product", "A product (interaction) term is not supported for a two-level fit",
         function() tl_ex("medfit_error_twolevel_product", interaction = "X:M")),
    list("medfit_error_twolevel_unsupported", "A two-level fit supports exactly one mediator",
         function() {
           tl_catch(extract_mediation(tl_fixture("base"), "X", c("M", "Y"), "Y"), "medfit_error_twolevel_unsupported")
         }),
    list("medfit_error_twolevel_unsupported", "is not in the model at the",
         function() {
           d <- tl_sim()
           d$X <- stats::ave(d$X, d$id)
           fit <- tl_fit(d, "level: 1\n M ~ 1\n Y ~ M\nlevel: 2\n M ~ X\n Y ~ M + X\n")
           tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_error_twolevel_unsupported")
         }),
    list("medfit_error_twolevel_path_missing", "is not assumed to be 0",
         function() {
           fit <- tl_fit(tl_sim(), "level: 1\n M ~ X\n Y ~ M + X\nlevel: 2\n M ~ X\n Y ~ M\n")
           tl_catch(extract_mediation(fit, "X", "M", "Y"), "medfit_error_twolevel_path_missing")
         }),
    list("medfit_error_twolevel_unusable", "The two-level fit is not usable",
         function() {
           testthat::local_mocked_bindings(
             .twolevel_converged = function(fit) FALSE,
             .twolevel_read_vcov = function(fit) {
               v <- lavaan::vcov(fit)
               v[1, 1] <- NA_real_
               v
             },
             .package = "medfit"
           )
           tl_catch(extract_mediation(tl_fixture("base"), "X", "M", "Y"), "medfit_error_twolevel_unusable")
         }),
    list("medfit_error_twolevel_level", "is defined only for nie()",
         function() tl_catch(nde(tl_extract(tl_fixture("base")), level = "contrast"), "medfit_error_twolevel_level")),
    list("medfit_error_lavaan_multilevel", "The lavaan fit has more than two levels",
         function() {
           testthat::local_mocked_bindings(.lavaan_nlevels = function(object) 3L, .package = "medfit")
           tl_catch(extract_mediation(tl_fixture("base"), "X", "M", "Y"), "medfit_error_lavaan_multilevel")
         }),
    list("medfit_error_lavaan_multigroup", "The lavaan fit has more than one group",
         function() {
           testthat::local_mocked_bindings(.lavaan_is_multigroup = function(object) TRUE, .package = "medfit")
           tl_catch(extract_mediation(tl_fixture("base"), "X", "M", "Y"), "medfit_error_lavaan_multigroup")
         })
  )
}

test_that("every two-level condition the Troubleshooting guide quotes is triggered with that class and text", {
  skip_if_not_installed("lavaan")
  for (cs in tl_doc_cases()) {
    cnd <- cs[[3]]()
    expect_false(is.null(cnd), info = cs[[2]])
    expect_s3_class(cnd, cs[[1]])
    expect_true(grepl(cs[[2]], conditionMessage(cnd), fixed = TRUE), info = cs[[2]])
  }
})

test_that("the guide quotes every two-level fragment and class, and the page lists the classes it names", {
  guide <- doc_text("guide-troubleshooting.qmd")
  page <- doc_text("model-twolevel.qmd")
  for (cs in tl_doc_cases()) {
    expect_true(grepl(cs[[2]], guide, fixed = TRUE), info = paste("guide fragment:", cs[[2]]))
    expect_true(grepl(paste0("`", cs[[1]], "`"), guide, fixed = TRUE), info = paste("guide class:", cs[[1]]))
  }
  classes <- unique(vapply(tl_doc_cases(), `[[`, character(1), 1L))
  for (k in setdiff(classes, c("medfit_error_lavaan_multilevel", "medfit_error_lavaan_multigroup"))) {
    expect_true(grepl(paste0("`", k, "`"), page, fixed = TRUE), info = paste("page class:", k))
  }
  # planted defect: a reworded fragment is not found in the guide
  expect_false(grepl("The between level is unidentified, so", guide, fixed = TRUE))
})

test_that("the page states the literature caveats and no fixed.x gap size", {
  page <- doc_text("model-twolevel.qmd")
  expect_true(grepl("sigma_{ab}", page, fixed = TRUE))
  expect_true(grepl("Preacher, Zyphur and Zhang", page, fixed = TRUE))
  expect_true(grepl("not a test", page, fixed = TRUE))
  expect_true(grepl("a judgment", page, fixed = TRUE))
  expect_false(grepl("narrower", page, fixed = TRUE))
  expect_false(grepl("[0-9]%", page))
})

test_that("the lavaan page and the troubleshooting guide no longer call two-level support planned", {
  expect_false(grepl("Two-level mediation support is planned", doc_text("model-lavaan.qmd"), fixed = TRUE))
})
