# Consistency guard for vignettes/articles/native-defaults-0-15.qmd: the page is in the Guides menu and the articles
# index, its article links resolve, and the numeric claims of its worked example hold (four explicit combinations of
# fixed_x and meanstructure: identical structural estimates and SEs, the stated npar differences, equal logLik and
# AIC across meanstructure, the unconditional lenient message, the obsolete-option note and the 2k AIC gap against
# lavaan).

root_path <- function(...) testthat::test_path("..", "..", ...)
read_text <- function(p) paste(readLines(p, warn = FALSE), collapse = "\n")
article <- function() {
  p <- root_path("vignettes", "articles", "native-defaults-0-15.qmd")
  testthat::skip_if_not(file.exists(p), "vignettes are not available (installed or built package)")
  p
}

test_that("the article is in the Guides menu and the articles index, and its links resolve", {
  txt <- read_text(article())
  pk <- read_text(root_path("_pkgdown.yml"))
  expect_true(grepl("articles/native-defaults-0-15`", pk, fixed = TRUE))
  expect_true(grepl("articles/native-defaults-0-15.html", pk, fixed = TRUE))
  links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z0-9-]+)\\.html[#)]", txt))[[1]])
  targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
  expect_gte(length(targets), 3L)
  expect_identical(targets[!file.exists(root_path("vignettes", "articles", targets))], character())
  flat <- gsub("\\s+", " ", txt)
  expect_true(grepl("557 rows: 503 agree, 54 are recorded limits, 0 block", flat, fixed = TRUE))
})

ndo_model <- "
  mediator1 ~ a * treatment + covariate1
  outcome ~ b * mediator1 + cp * treatment + covariate1
"

test_that("the four-combination table: same structural results, the stated npar, logLik and AIC", {
  fits <- list(
    ff = fit_sem(ndo_model, mediation_demo, fixed_x = FALSE, meanstructure = FALSE),
    tf = fit_sem(ndo_model, mediation_demo, fixed_x = TRUE, meanstructure = FALSE),
    ft = fit_sem(ndo_model, mediation_demo, fixed_x = FALSE, meanstructure = TRUE),
    tt = fit_sem(ndo_model, mediation_demo, fixed_x = TRUE, meanstructure = TRUE)
  )
  est <- vapply(fits, function(f) coef(f)[c("a", "b", "cp")], numeric(3))
  se <- vapply(fits, function(f) sqrt(diag(vcov(f)))[c("a", "b", "cp")], numeric(3))
  expect_lt(max(abs(est - est[, "ff"])), 1e-6)
  expect_lt(max(abs(se - se[, "ff"])), 1e-6)

  npar <- vapply(fits, function(f) length(coef(f)), numeric(1))
  expect_identical(unname(npar[["ff"]] - npar[["tf"]]), 3)  # two exogenous variances and their covariance
  expect_identical(unname(npar[["ft"]] - npar[["tt"]]), 5)  # the same three plus two exogenous means
  expect_identical(unname(npar[["ft"]] - npar[["ff"]]), 4)  # one intercept per observed variable
  expect_identical(unname(npar[["tt"]] - npar[["tf"]]), 2)  # intercepts of the two non-fixed variables

  ll <- vapply(fits, function(f) as.numeric(logLik(f)), numeric(1))
  aic <- vapply(fits, AIC, numeric(1))
  expect_lt(abs(ll[["ff"]] - ll[["ft"]]), 1e-6)
  expect_lt(abs(ll[["tf"]] - ll[["tt"]]), 1e-6)
  expect_lt(abs(aic[["ff"]] - aic[["ft"]]), 1e-6)
  expect_lt(abs(aic[["tf"]] - aic[["tt"]]), 1e-6)
  expect_gt(abs(ll[["ff"]] - ll[["tf"]]), 1)  # the conditional likelihood differs
})

test_that("the default leaves a variable named in ~~ free with the lenient message (0.15.0: no opt-in)", {
  msg <- NULL
  fit <- withCallingHandlers(
    fit_sem(paste(ndo_model, "covariate1 ~~ covariate1", sep = "\n"), mediation_demo),
    medfit_message_fixed_x_lenient = function(m) {
      msg <<- m
      invokeRestart("muffleMessage")
    }
  )
  expect_false(is.null(msg))
  expect_identical(glance(fit)$fixed_x, "treatment")
})

test_that("the dependent-package wrapper pins the 0.14 results under the 0.15.0 defaults", {
  wrap <- function(...) {
    args <- list(...)
    f <- names(formals(fit_sem))
    if ("fixed_x" %in% f && !"fixed_x" %in% names(args)) args$fixed_x <- FALSE
    if ("meanstructure" %in% f && !"meanstructure" %in% names(args)) {
      args["meanstructure"] <- list(NULL)
    }
    do.call(fit_sem, args)
  }
  expect_no_warning(fw <- wrap(ndo_model, mediation_demo))
  expect_false(isTRUE(fw@internals$ram$has_mean))
  fe <- fit_sem(ndo_model, mediation_demo, fixed_x = FALSE, meanstructure = NULL)
  expect_identical(coef(fw), coef(fe))
  expect_identical(as.numeric(logLik(fw)), as.numeric(logLik(fe)))
})

test_that("the article's pitfall holds: `args$meanstructure <- NULL` drops the element and the default applies", {
  bad <- function(...) {
    args <- list(...)
    args$fixed_x <- FALSE
    args$meanstructure <- NULL
    do.call(fit_sem, args)
  }
  # 0.15.0: no warning, and the mean structure is on, so the wrapper's intended covariance-only fit is silently lost.
  expect_no_warning(fit <- bad(ndo_model, mediation_demo))
  expect_true(isTRUE(fit@internals$ram$has_mean))
  expect_true(any(grepl("~1", names(coef(fit)), fixed = TRUE)))
  keep <- fit_sem(ndo_model, mediation_demo, fixed_x = FALSE, meanstructure = NULL)
  expect_false(isTRUE(keep@internals$ram$has_mean))
})

test_that("options(medfit.native_defaults) has no effect: no message, no 0.14.0 warning, the 0.15.0 defaults", {
  withr::local_options(medfit.native_defaults = "0.15")
  expect_no_message(fit <- fit_sem(ndo_model, mediation_demo))
  expect_identical(glance(fit)$fixed_x, "treatment, covariate1")
  expect_true(isTRUE(fit@internals$ram$has_mean))
  expect_no_warning(fit_sem(ndo_model, mediation_demo), class = "medfit_warning_default_change")
})

test_that("covariance-only AIC exceeds lavaan's by 2k, and agrees under meanstructure = TRUE", {
  testthat::skip_if_not_installed("lavaan")
  ff <- fit_sem(ndo_model, mediation_demo, fixed_x = FALSE, meanstructure = FALSE)
  ft <- fit_sem(ndo_model, mediation_demo, fixed_x = FALSE, meanstructure = TRUE)
  lv_cov <- lavaan::sem(ndo_model, mediation_demo, fixed.x = FALSE)
  lv_mean <- lavaan::sem(ndo_model, mediation_demo, fixed.x = FALSE, meanstructure = TRUE)
  # The gap is 2k with k = 4 implicit means.
  expect_lt(abs(AIC(ff) - lavaan::fitMeasures(lv_cov, "aic")[[1]] - 8), 1e-4)
  expect_lt(abs(AIC(ft) - lavaan::fitMeasures(lv_mean, "aic")[[1]]), 1e-4)
})

test_that("the default fit has the 0.15.0 AIC gap against a default lavaan::sem(), none against meanstructure = TRUE", {
  testthat::skip_if_not_installed("lavaan")
  fd <- suppressMessages(fit_sem(ndo_model, mediation_demo))
  lv_def <- lavaan::sem(ndo_model, mediation_demo)
  lv_mean <- lavaan::sem(ndo_model, mediation_demo, meanstructure = TRUE)
  expect_lt(abs(AIC(fd) - lavaan::fitMeasures(lv_mean, "aic")[[1]]), 1e-4)
  expect_lt(abs(AIC(fd) - lavaan::fitMeasures(lv_def, "aic")[[1]] - 4), 1e-4)  # 2k with k = 2 non-fixed means
  expect_lt(abs(as.numeric(logLik(fd)) - as.numeric(lavaan::logLik(lv_def))), 1e-4)
})
