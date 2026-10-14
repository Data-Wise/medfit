# Native limits and glossary statements (docs audit batch 3):
# - AIC()/BIC() of a fit with a product are not comparable with a fit without one, and multi-fit AIC() does not check
#   (documented in five places; the numbers below are the probe the docs quote);
# - the glossary entries for the native mean structure, `fixed_x`, products and `anova()` are true and link to
#   headings that exist.

root_path <- function(...) testthat::test_path("..", "..", ...)

limits_syntax <- function(extra = "") {
  paste0("mediator1 ~ treatment + covariate1\noutcome ~ treatment + mediator1", extra, "\n")
}

limits_fit <- function(model) suppressWarnings(fit_sem(model, medfit::mediation_demo))

test_that("AIC/BIC of a product fit are not comparable with a no-product fit, and multi-fit AIC() does not refuse", {
  with_x <- limits_fit(limits_syntax(" + treatment:mediator1"))
  without <- limits_fit(limits_syntax())
  # Same outcome, same data rows: only the product column differs.
  expect_no_error(aic <- stats::AIC(with_x, without))
  expect_no_error(bic <- stats::BIC(with_x, without))
  penalty <- 2 * (aic$df[1] - aic$df[2])
  gap <- aic$AIC[1] - aic$AIC[2]
  # The product column adds a variable to the joint likelihood, so the gap is far from the parameter penalty
  # (the docs quote 3934.7 against 2994.1 for the same outcome on the demo data).
  expect_gt(gap - penalty, 500)
  expect_gt(bic$BIC[1] - bic$BIC[2], 500)
  # Positive control: a comparable pair (one more path among variables already in the model) stays near the penalty.
  comparable <- limits_fit(limits_syntax("\noutcome ~ covariate1"))
  aic_c <- stats::AIC(comparable, without)
  expect_lt(abs(aic_c$AIC[1] - aic_c$AIC[2] - 2 * (aic_c$df[1] - aic_c$df[2])), 100)
  # anova() refuses the pair, as the docs say.
  expect_error(anova(without, with_x))
})

test_that("the not-comparable sentence is in the five documented places, and the check can fail", {
  has_sentence <- function(txt) {
    any(grepl("not comparable", txt, fixed = TRUE)) && any(grepl("AIC(fit_a, fit_b)", txt, fixed = TRUE))
  }
  files <- c(
    root_path("vignettes", "articles", "model-native.qmd"),
    root_path("vignettes", "articles", "native-guide.qmd"),
    root_path("vignettes", "articles", "model-interaction.qmd"),
    root_path("R", "methods-sem.R"),
    root_path("R", "sem-syntax-help.R")
  )
  testthat::skip_if_not(all(file.exists(files)), "source files are not available (installed or built package)")
  for (f in files) {
    txt <- paste(readLines(f, warn = FALSE), collapse = " ")
    txt <- gsub("(^|\\s)#'\\s", " ", txt)
    expect_true(has_sentence(txt), info = f)
    # Planted defect: with the sentence removed the check fails.
    expect_false(has_sentence(gsub("not comparable", "comparable", txt, fixed = TRUE)), info = f)
  }
})

test_that("the glossary's native entries are true", {
  d <- medfit::mediation_demo
  # canonical name: the two names sorted in the C locale, so x:m and m:x are one term
  a <- limits_fit("mediator1 ~ treatment\noutcome ~ treatment + mediator1 + treatment:mediator1")
  b <- limits_fit("mediator1 ~ treatment\noutcome ~ treatment + mediator1 + mediator1:treatment")
  expect_true("outcome~mediator1:treatment" %in% names(coef(a)))
  expect_equal(coef(a), coef(b), tolerance = 1e-8)
  # a product turns the mean structure on (intercept rows appear)
  expect_true(any(grepl("~1", names(coef(a)), fixed = TRUE)))
  # any ~1 statement turns the mean structure on and frees every unwritten observed intercept
  m1 <- limits_fit("mediator1 ~ 1\nmediator1 ~ treatment\noutcome ~ treatment + mediator1")
  expect_true(all(c("mediator1~1", "outcome~1") %in% names(coef(m1))))
  # y ~ 0*1 is a restriction: one more degree of freedom
  m0 <- limits_fit("mediator1 ~ 0*1\nmediator1 ~ treatment\noutcome ~ treatment + mediator1")
  expect_equal(glance(m0)$df, glance(m1)$df + 1)
  # fixed_x leaves the structural estimates unchanged and makes the log likelihood conditional
  free <- limits_fit(limits_syntax())
  fx <- suppressWarnings(fit_sem(limits_syntax(), d, fixed_x = TRUE))
  shared <- c("mediator1~treatment", "outcome~mediator1", "outcome~treatment")
  expect_equal(coef(fx)[shared], coef(free)[shared], tolerance = 1e-5)
  expect_false(isTRUE(all.equal(as.numeric(logLik(fx)), as.numeric(logLik(free)))))
  expect_error(stats::AIC(fx, free))
})

heading_ids <- function(path) {
  x <- readLines(path, warn = FALSE)
  h <- sub("^#+\\s+", "", x[grepl("^#+\\s", x)])
  explicit <- regmatches(h, regexpr("\\{#[^}]+\\}", h))
  explicit <- sub("^\\{#(.*)\\}$", "\\1", explicit)
  h <- trimws(sub("\\s*\\{[^}]*\\}\\s*$", "", h))
  slug <- tolower(gsub("`", "", h))
  slug <- gsub("[^a-z0-9_. -]", "", slug)
  slug <- gsub("[ .]+", "-", slug)
  slug <- sub("^[^a-z]+", "", slug)
  c(slug, explicit)
}

test_that("every glossary link in the native table resolves to a page and a heading", {
  g <- root_path("vignettes", "articles", "guide-glossary.qmd")
  testthat::skip_if_not(file.exists(g), "vignettes are not available (installed or built package)")
  txt <- readLines(g, warn = FALSE)
  rows <- txt[grepl("^\\| \\*\\*", txt)]
  expect_gt(length(rows), 0)
  for (entry in c("mean structure", "intercept", "fixed_x", "product term", "canonical name", "nested comparison",
                  "conditional log likelihood")) {
    expect_true(any(grepl(entry, rows, fixed = TRUE)), info = entry)
  }
  links <- unlist(regmatches(rows, gregexpr("\\]\\(([a-z0-9-]+)\\.html(#[^)]*)?\\)", rows)))
  links <- sub("^\\]\\(", "", sub("\\)$", "", links))
  for (l in links) {
    page <- sub("\\.html.*$", "", l)
    path <- root_path("vignettes", "articles", paste0(page, ".qmd"))
    expect_true(file.exists(path), info = l)
    if (grepl("#", l, fixed = TRUE) && file.exists(path)) {
      expect_true(sub("^[^#]*#", "", l) %in% heading_ids(path), info = l)
    }
  }
  # Positive control: a dead fragment is caught by the same check.
  expect_false("no-such-heading" %in% heading_ids(root_path("vignettes", "articles", "model-native.qmd")))
})
