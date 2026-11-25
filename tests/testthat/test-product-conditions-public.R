# QA (P2(c)): the product refusals as a user reaches them. test-product-conditions.R triggers the syntax refusals
# through the internal `.sem_parse()`; `fit_sem()` re-raises a parse error in `.sem_fit_syntax()`, and `mbco_sem()`
# wraps a refit failure, so a class set at the source can be lost on the way out. Each case here goes through the
# exported function a user calls and asks for the same classes.

pcp_data <- function(n = 120L, seed = 5L) {
  withr::local_seed(seed)
  d <- data.frame(x = rnorm(n), w = rnorm(n), c = rnorm(n))
  d$m <- 0.5 * d$x + rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * d$x + 0.2 * d$x * d$w + rnorm(n)
  d$g <- factor(sample(c("a", "b", "c"), n, TRUE))
  d$h <- factor(sample(c("u", "v"), n, TRUE))
  d
}
pcp_err <- function(expr) {
  tryCatch({
    force(expr)
    NULL
  }, error = function(e) e)
}

# list(class, message fragment, exported trigger)
pcp_cases <- function() {
  list(
    list("medfit_error_product_syntax", "needs a variable name on each side",
         function() fit_sem("y ~ x + x :w", pcp_data())),
    list("medfit_error_product_syntax", "of a variable with itself", function() fit_sem("y ~ x:x", pcp_data())),
    list("medfit_error_product_syntax", "three-way or higher", function() fit_sem("y ~ x:w:c", pcp_data())),
    list("medfit_error_product_syntax", "cannot be a left side", function() fit_sem("x:w ~ y", pcp_data())),
    list("medfit_error_product_syntax", "only valid on the right side of a regression",
         function() fit_sem("eta =~ x:w", pcp_data())),
    list("medfit_error_product_syntax", "not inside the expression",
         function() fit_sem("m ~ a*x\ny ~ b*m + x:w\nab := a:b", pcp_data())),
    # reachable through a numeric factor (the tokenizer lets `:.5` through): the "unreachable" defensive branch
    list("medfit_error_product_syntax", "malformed product", function() fit_sem("y ~ x:.5", pcp_data())),
    list("medfit_error_product_syntax", "malformed product", function() .sem_parse("y ~ .5:x")),
    list("medfit_error_product_latent", "involves a latent variable",
         function() fit_sem("eta =~ m + y + c\nw ~ eta + x\nw ~ eta:x", pcp_data())),
    list("medfit_error_product_duplicate", "are the same product", function() fit_sem("y ~ x:w + w:x", pcp_data())),
    # categorical columns (sem-factor.R): two categorical sides; fixed_x naming a column that only appears in products
    list("medfit_error_product_syntax", "both sides are categorical columns",
         function() fit_sem("y ~ g:h", pcp_data())),
    list("medfit_error_product_syntax", "appears only inside products",
         function() fit_sem("y ~ g:x + m", pcp_data(), fixed_x = "g")),
    list("medfit_error_product_syntax", "malformed modifier", function() fit_sem("y ~ a:b*x", pcp_data())),
    # mbco_sem() refits with `a == 0` on a supported product model; the rule-9 refusal is wrapped in the refit message
    list("medfit_error_product_constraint", "names the coefficient label", function() {
      f <- suppressWarnings(fit_sem("m ~ a*x\ny ~ b*m + x + x:w", pcp_data(), se_type = "sandwich"))
      mbco_sem(f, paths = c("a", "b"))
    })
  )
}

test_that("a product refusal reached through fit_sem() and mbco_sem() keeps its class, parent class and message", {
  for (case in pcp_cases()) {
    err <- pcp_err(case[[3L]]())
    info <- paste(case[[1L]], case[[2L]])
    expect_false(is.null(err), info = info)
    expect_true(inherits(err, case[[1L]]), info = info)
    expect_true(inherits(err, "medfit_error_product"), info = info)
    expect_match(conditionMessage(err), case[[2L]], fixed = TRUE, info = info)
  }
})

test_that("the cluster-engine product refusal (exported extract_mediation on lmer fits) is classed", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 24, sizes = 8, seed = 4, cov = "centered")$data)
  m <- suppressWarnings(suppressMessages(lme4::lmer(M ~ X + (1 | cluster), data = d)))
  y <- suppressWarnings(suppressMessages(lme4::lmer(Y ~ X + M_w + M_bar + X:M_w + C + (1 | cluster), data = d)))
  err <- pcp_err(suppressWarnings(extract_mediation(m, model_y = y, treatment = "X", mediator = "M")))
  expect_s3_class(err, "medfit_error_product_extract")
  expect_s3_class(err, "medfit_error_product")
  expect_match(conditionMessage(err), "product term `X:M_w`", fixed = TRUE)
  expect_null(conditionCall(err))
})

test_that(".product_reraise() keeps a product refusal's classes and re-raises anything else as before", {
  prod <- .product_condition("inner", "medfit_error_product_bound")
  out <- .product_reraise(prod, "outer")
  expect_s3_class(out, "medfit_error_product_bound")
  expect_s3_class(out, "medfit_error_product")
  expect_identical(conditionMessage(out), "outer")
  expect_null(conditionCall(out))
  # a non-product condition is not touched (the caller falls back to a plain error with the new message, call NULL)
  expect_null(.product_reraise(simpleError("boom"), "outer"))
  expect_null(.product_reraise(structure(class = c("medfit_error_ledger", "error", "condition"),
                                         list(message = "x", call = NULL)), "outer"))
  # through fit_sem(): a non-product parse error keeps its message and call NULL, and gains no product class
  err <- pcp_err(fit_sem("y ~ nosuchvar +", pcp_data()))
  expect_false(inherits(err, "medfit_error_product"))
  expect_null(conditionCall(err))
  expect_match(conditionMessage(err), "[Ee]xpected|ends|unexpected|incomplete|missing|empty", perl = TRUE)
})

test_that("planted defect: dropping the class in .product_reraise() fails the exported-path cases", {
  fx_skip_covr()
  bad <- sem_mutate(.product_reraise, "class = class(err)", "class = c(\"error\", \"condition\")")
  testthat::local_mocked_bindings(.product_reraise = bad)
  err <- pcp_err(fit_sem("y ~ x:x", pcp_data()))
  expect_false(inherits(err, "medfit_error_product_syntax"))
})

# A refusal that mentions a product in the native engine's files must be built by .product_condition() (or a classed
# helper); an unclassed stop()/warning() naming a product would slip past the case list above. The allowlist: the
# se_type warning (advice), the internal-error stop (programming error), the classed search-evidence error and the
# two-level nonlinear-constraint abort (classed by its own family; a product of labels is a constraint, not a term).
test_that("no stop() or warning() in the native engine's files names a product without a class", {
  src <- testthat::test_path("..", "..", "R")
  skip_if_not(file.exists(file.path(src, "fit-sem.R")), "R sources are not part of the installed package")
  files <- file.path(src, c(list.files(src, "^sem-.*\\.R$"), "extract-sem.R", "methods-aic.R", "fit-sem.R"))
  hits <- character()
  walk <- function(e, f) {
    if (!is.call(e)) return(invisible())
    fn <- if (is.symbol(e[[1L]])) as.character(e[[1L]]) else ""
    if (fn %in% c("stop", "warning", "abort", ".sem_syntax_error", ".sem_product_stop")) {
      txt <- paste(deparse(e, width.cutoff = 500L), collapse = " ")
      strs <- paste(regmatches(txt, gregexpr("\"[^\"]*\"", txt))[[1L]], collapse = " ")
      classed <- grepl(paste0("product_condition|product_reraise|medfit_error_product|medfit_warning_product|",
                              "twolevel|\"product\""), txt)
      if (grepl("product", strs, ignore.case = TRUE) && !classed) {
        hits <<- c(hits, paste(f, substr(gsub("\\s+", " ", txt), 1L, 90L)))
      }
    }
    for (i in seq_along(e)) tryCatch(walk(e[[i]], f), error = function(z) NULL)
  }
  for (f in files) for (e in parse(f, keep.source = FALSE)) walk(e, basename(f))
  hits <- hits[!grepl(paste0("the model has a product term|internal error: a product model|",
                             "invalid nonzero-product search evidence|",
                             "nonlinear constraints \\(including a product"), hits)]
  expect_identical(hits, character())
})

test_that("the class tables list exactly the classes the source emits", {
  src <- testthat::test_path("..", "..", "R")
  qmd <- testthat::test_path("..", "..", "vignettes", "articles", "model-sem.qmd")
  skip_if_not(dir.exists(src) && file.exists(qmd), "sources are not part of the installed package")
  txt <- unlist(lapply(list.files(src, "\\.R$", full.names = TRUE), function(f) {
    if (basename(f) == "sem-syntax-help.R") character() else readLines(f, warn = FALSE)
  }))
  emitted <- setdiff(unique(unlist(regmatches(txt, gregexpr("medfit_(error|warning)_product_[a-z_]+", txt)))),
                     character())
  doc <- function(path) {
    l <- readLines(path, warn = FALSE)
    unique(unlist(regmatches(l, gregexpr("medfit_(error|warning)_product_[a-z_]+", l))))
  }
  expect_setequal(doc(qmd), emitted)
  expect_setequal(doc(file.path(src, "sem-syntax-help.R")), emitted)
  expect_setequal(doc(testthat::test_path("..", "..", "man", "medfit-syntax.Rd")), emitted)
})
