# Native limits and glossary statements (docs audit batch 3):
# - AIC()/BIC() refuse a fit with a product against a fit without one (observed variables differ; documented in
#   five places);
# - the glossary entries for the native mean structure, `fixed_x`, products and `anova()` are true and link to
#   headings that exist.

root_path <- function(...) testthat::test_path("..", "..", ...)

limits_syntax <- function(extra = "") {
  paste0("mediator1 ~ treatment + covariate1\noutcome ~ treatment + mediator1", extra, "\n")
}

# The subject here is the observed-variable guard and the glossary, not the defaults: pin the 0.14.x settings
# (nothing fixed, covariance-only unless the model needs means), which also keeps the AIC figures the docs quote.
limits_fit <- function(model) {
  suppressWarnings(fit_sem(model, medfit::mediation_demo, fixed_x = FALSE, meanstructure = NULL))
}

test_that("AIC/BIC refuse a product fit against a no-product fit; a comparable pair still works", {
  with_x <- limits_fit(limits_syntax(" + treatment:mediator1"))
  without <- limits_fit(limits_syntax())
  # Same outcome, same data rows: only the product column differs (the docs quote AIC 3934.7 against 2994.1).
  expect_error(stats::AIC(with_x, without), "different observed variables")
  expect_error(stats::BIC(with_x, without), "treatment:mediator1|mediator1:treatment")
  expect_error(stats::AIC(without, with_x), "different observed variables")
  expect_error(anova(without, with_x))
  # Positive control: a pair over the same observed variables (one more path among variables already in the model)
  # is compared, and its gap stays near the parameter penalty.
  comparable <- limits_fit(limits_syntax("\noutcome ~ covariate1"))
  aic_c <- stats::AIC(comparable, without)
  expect_lt(abs(aic_c$AIC[1] - aic_c$AIC[2] - 2 * (aic_c$df[1] - aic_c$df[2])), 100)
  expect_no_error(stats::BIC(comparable, without))
})

test_that("planted: without the observed-variable guard the incomparable AIC is returned", {
  fx_skip_covr()
  with_x <- limits_fit(limits_syntax(" + treatment:mediator1"))
  without <- limits_fit(limits_syntax())
  mutated <- sem_mutate(.sem_check_same_observed, "if (!all(vapply(obs[-1L], identical, logical(1), obs[[1L]]))) {",
                        "if (FALSE) {")
  local_mocked_bindings(.sem_check_same_observed = mutated)
  aic <- stats::AIC(with_x, without)
  expect_gt(aic$AIC[1] - aic$AIC[2] - 2 * (aic$df[1] - aic$df[2]), 500)
})

test_that("the refusal sentence is in the five documented places, and the check can fail", {
  has_sentence <- function(txt) {
    all(vapply(c("not comparable", "refuse such a pair", "AIC(fit_a, fit_b)"), function(p) {
      any(grepl(p, txt, fixed = TRUE))
    }, logical(1)))
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
    txt <- gsub("\\s+", " ", gsub("(^|\\s)#'\\s", " ", txt))
    expect_true(has_sentence(txt), info = f)
    # Planted defect: with the sentence removed the check fails.
    expect_false(has_sentence(gsub("refuse such a pair", "rank such a pair", txt, fixed = TRUE)), info = f)
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
  fx <- suppressWarnings(fit_sem(limits_syntax(), d, fixed_x = TRUE, meanstructure = NULL))
  shared <- c("mediator1~treatment", "outcome~mediator1", "outcome~treatment")
  expect_equal(coef(fx)[shared], coef(free)[shared], tolerance = 1e-5)
  expect_false(isTRUE(all.equal(as.numeric(logLik(fx)), as.numeric(logLik(free)))))
  expect_error(stats::AIC(fx, free))
  # 0.15.0: an unset `fixed_x` is the exogenous set, so a default fit is the conditional one and is refused against
  # the free fit too
  dflt <- suppressWarnings(fit_sem(limits_syntax(), d))
  expect_true(nzchar(glance(dflt)$fixed_x))
  expect_error(stats::AIC(dflt, free))
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
