# Every product refusal carries a `medfit_error_product_*` class (and the shared parent `medfit_error_product`), its
# reason in the message, and a row in the two doc tables (?"medfit-syntax" and the supported-class table of
# vignettes/articles/model-sem.qmd). Dependents match on the class, not on the message, so the class is a contract.
# One planted trigger per refusal; test-product-messages.R pins the message fragments quoted in the docs.

pc_data <- function(n = 120L, seed = 3L) {
  withr::local_seed(seed)
  d <- data.frame(x = rnorm(n), w = rnorm(n), c = rnorm(n))
  d$m <- 0.5 * d$x + rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * d$x + 0.2 * d$x * d$m + rnorm(n)
  d
}
pc_fit <- function(model, ...) suppressWarnings(fit_sem(model, pc_data(), se_type = "sandwich", ...))
pc_endo <- "m ~ x\ny ~ m + x + x:m"
pc_complete <- function(syntax) .sem_complete(.sem_parse(syntax)$parameters)
pc_lab <- "m ~ a*x\ny ~ b*m + x:m\n"
pc_rescov <- function() pc_complete("m1 ~ x\nm2 ~ x\ny ~ m1 + m2 + x:m1\nm1 ~~ m2")
pc_extract <- function(model, ...) extract_mediation(pc_fit(model), treatment = "x", mediator = "m", ...)

# list(class, message reason, trigger)
pc_cases <- function() {
  list(
    list("medfit_error_product_syntax", "needs a variable name on each side", function() .sem_parse("Y ~ x :m")),
    list("medfit_error_product_syntax", "of a variable with itself", function() .sem_parse("Y ~ x:x")),
    list("medfit_error_product_syntax", "three-way or higher", function() .sem_parse("Y ~ x:m:w")),
    list("medfit_error_product_syntax", "cannot be a left side", function() .sem_parse("x:m ~ y")),
    list("medfit_error_product_syntax", "cannot be a left side", function() .sem_parse("x:m ~~ y")),
    list("medfit_error_product_syntax", "only valid on the right side of a regression",
         function() .sem_parse("eta =~ x:m")),
    list("medfit_error_product_syntax", "not inside the expression", function() .sem_parse("Y ~ a*X\nab := a*x:m")),
    list("medfit_error_product_syntax", "malformed modifier", function() .sem_parse("y ~ a:b*x")),
    list("medfit_error_product_latent", "involves a latent variable",
         function() .sem_parse("eta =~ m1 + m2 + m3\ny ~ eta + x\ny ~ eta:x")),
    list("medfit_error_product_duplicate", "are the same product", function() .sem_parse("y ~ x:m + m:x")),
    list("medfit_error_product_outcome_regressor", "rule 8", function() pc_complete("y ~ x + x:y")),
    list("medfit_error_product_recursive", "not recursive", function() pc_complete("y ~ z + x:w\nz ~ y")),
    list("medfit_error_product_residual_covariance", "residual covariance", pc_rescov),
    list("medfit_error_product_shared_label", "more than one parameter",
         function() pc_complete("m ~ a*x\ny ~ a*m + x:m")),
    list("medfit_error_product_fixed_coefficient", "fixed coefficient",
         function() pc_complete("m ~ x\ny ~ 0.3*x + x:m")),
    list("medfit_error_product_bound", "has a bound", function() pc_complete("m ~ x\ny ~ lower(0)*m + x:m")),
    list("medfit_error_product_constraint", "names the coefficient label",
         function() pc_complete(paste0(pc_lab, "a == b"))),
    list("medfit_error_product_constraint", "names the coefficient label",
         function() pc_complete(paste0(pc_lab, "a < 1"))),
    list("medfit_error_product_intercept", "intercept clause",
         function() pc_complete("y ~ x + m + x:m\nm ~ x\ny ~ 0*1")),
    list("medfit_error_product_intercept", "shares the label",
         function() pc_complete("y ~ x + m + x:m\nm ~ x\ny ~ a*1\nm ~ a*1")),
    list("medfit_error_product_intercept", "is in a constraint",
         function() pc_complete("y ~ x + m + x:m\nm ~ x\ny ~ a*1\na == 0")),
    list("medfit_error_product_meanstructure", "meanstructure = FALSE",
         function() pc_fit(pc_endo, meanstructure = FALSE)),
    list("medfit_error_product_column", "is not the product of", function() {
      d <- pc_data()
      d[["m:x"]] <- d$x * d$m + 0.01
      suppressWarnings(fit_sem(pc_endo, d, se_type = "sandwich"))
    }),
    list("medfit_error_product_nonnumeric", "needs numeric variables", function() {
      d <- pc_data()
      d$m <- as.Date("2026-01-01") + seq_len(nrow(d))
      fit_sem("y ~ x + x:m", d)
    }),
    list("medfit_error_product_information", "product of an endogenous variable",
         function() pc_fit(pc_endo, information = "expected")),
    list("medfit_error_product_modeltest", "is not available for",
         function() anova(pc_fit(pc_endo), pc_fit("m ~ x\ny ~ m + x:m"))),
    list("medfit_error_product_modeltest", "is not available for",
         function() mbco_sem(pc_fit(pc_endo), paths = c("m~x", "y~m"))),
    list("medfit_error_product_observed", "different observed variables",
         function() stats::AIC(pc_fit(pc_endo), pc_fit("m ~ x\ny ~ m + x"))),
    list("medfit_error_product_extract", "does not support the product",
         function() pc_extract("m ~ x + c\ny ~ x + m + x:m + x:c + c")),
    list("medfit_error_product_extract", "needs the treatment-by-mediator product",
         function() pc_extract("m ~ x\ny ~ x + m", decomposition = "four_way")),
    list("medfit_error_product_extract", "must be the product written with `:`",
         function() pc_extract(pc_endo, interaction = "x")),
    list("medfit_error_product_extract", "is not the product of the treatment",
         function() pc_extract("m ~ x + c\ny ~ x + m + x:m + c", interaction = "x:c"))
  )
}

pc_class_of <- function(trigger) {
  tryCatch({
    trigger()
    NULL
  }, error = function(e) e)
}

# TRUE when the trigger errors with the case's class, the parent class and the reason in the message.
pc_ok <- function(case) {
  err <- pc_class_of(case[[3L]])
  !is.null(err) && inherits(err, case[[1L]]) && inherits(err, "medfit_error_product") &&
    grepl(case[[2L]], conditionMessage(err), fixed = TRUE) && is.null(conditionCall(err))
}

test_that("every product refusal carries its medfit_error_product_* class, the parent class and its reason", {
  for (case in pc_cases()) {
    expect_true(pc_ok(case), info = paste(case[[1L]], case[[2L]]))
  }
})

test_that("the model-test NA warning is classed", {
  w <- tryCatch(fit_sem(pc_endo, pc_data(), se_type = "sandwich"), warning = function(w) w)
  expect_s3_class(w, "medfit_warning_product_modeltest")
  expect_match(conditionMessage(w), "the model test is not valid for this model", fixed = TRUE)
})

test_that("the refusals the cases do not list are not hiding: the source names only classes the cases cover", {
  src <- testthat::test_path("..", "..", "R")
  skip_if_not(dir.exists(src), "R sources are not part of the installed package")
  txt <- unlist(lapply(list.files(src, "\\.R$", full.names = TRUE), readLines, warn = FALSE))
  named <- unique(unlist(regmatches(txt, gregexpr("medfit_error_product_[a-z_]+", txt))))
  covered <- unique(vapply(pc_cases(), `[[`, character(1), 1L))
  expect_setequal(setdiff(named, "medfit_error_product"), covered)
})

test_that("every class has a row in ?medfit-syntax and in the supported-class table of the native model page", {
  rd <- testthat::test_path("..", "..", "R", "sem-syntax-help.R")
  qmd <- testthat::test_path("..", "..", "vignettes", "articles", "model-sem.qmd")
  skip_if_not(file.exists(rd) && file.exists(qmd), "doc sources are not part of the installed package")
  covered <- unique(vapply(pc_cases(), `[[`, character(1), 1L))
  for (path in c(rd, qmd)) {
    lines <- readLines(path, warn = FALSE)
    for (cls in covered) {
      expect_true(any(grepl(paste0("`", cls, "`"), lines, fixed = TRUE)), info = paste(basename(path), cls))
    }
    expect_true(any(grepl("`medfit_warning_product_modeltest`", lines, fixed = TRUE)), info = basename(path))
  }
})

test_that("planted defect: a refusal stripped of its class fails the check", {
  fx_skip_covr()
  case <- list("medfit_error_product_bound", "has a bound", function() pc_complete("m ~ x\ny ~ lower(0)*m + x:m"))
  expect_true(pc_ok(case))
  bad <- sem_mutate(.sem_check_product_parsed, "\"medfit_error_product_bound\"", "\"unclassed\"")
  testthat::local_mocked_bindings(.sem_check_product_parsed = bad)
  expect_false(pc_ok(case))
})
