# The "What changed since CRAN 0.3.2" guide states what each behavior change does.
# Known-answer and error checks keep those statements true, and a last test keeps
# the guide quoting the same message fragments.

guide_path <- function() {
  testthat::test_path("..", "..", "vignettes", "articles", "guide-changes.qmd")
}

mediation_demo <- medfit::mediation_demo

serial_fit <- function() {
  m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
  m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2, mediation_demo)
  y <- lm(outcome ~ treatment + mediator1 + mediator2 + covariate1 + covariate2, mediation_demo)
  extract_mediation(m1,
    model_y = y, treatment = "treatment",
    mediator = c("mediator1", "mediator2"), mediator_models = list(m2)
  )
}

test_that("serial te() is the treatment coefficient of the total-effect regression", {
  x <- serial_fit()
  total <- unname(coef(lm(outcome ~ treatment + covariate1 + covariate2, mediation_demo))["treatment"])
  expect_equal(as.numeric(te(x)), total, tolerance = 1e-8)
  expect_equal(as.numeric(nie(x, type = "total")), as.numeric(te(x)) - as.numeric(nde(x)), tolerance = 1e-10)
  expect_lt(as.numeric(nie(x)), as.numeric(nie(x, type = "total")))
})

test_that("serial objects gain the nie_total entries the guide lists", {
  x <- serial_fit()
  expect_true("nie_total" %in% tidy(x, type = "effects")$term)
  expect_true("nie_total" %in% names(glance(x)))
  expect_true("indirect_total" %in% names(coef(x, type = "effects")))
})

test_that("the simple-fit total-effect SE is 0.119, not the old 0.127", {
  fit <- fit_mediation(
    outcome ~ treatment + mediator1 + covariate1 + covariate2,
    mediator1 ~ treatment + covariate1 + covariate2,
    data = mediation_demo, treatment = "treatment", mediator = "mediator1"
  )
  se_te <- tidy(fit, type = "effects")$std_error[3]
  expect_equal(round(se_te, 3), 0.119)
})

test_that("a lavaan simple fit appends the three lm-style rows", {
  skip_if_not_installed("lavaan")
  syn <- paste0(
    "mediator1 ~ a * treatment + covariate1 + covariate2\n",
    "outcome ~ b * mediator1 + c_prime * treatment + covariate1 + covariate2"
  )
  x <- extract_mediation(lavaan::sem(syn, mediation_demo),
    treatment = "treatment",
    mediator = "mediator1", outcome = "outcome"
  )
  expect_true(all(c("m_treatment", "y_mediator1", "y_treatment") %in% names(x@estimates)))
  expect_true(all(c("m_treatment", "y_mediator1", "y_treatment") %in% rownames(x@vcov)))
})

test_that("the errors the guide lists are real", {
  m1 <- lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
  m2 <- lm(mediator2 ~ treatment + mediator1 + covariate1 + covariate2, mediation_demo)
  wrapped <- lm(
    outcome ~ treatment + mediator1 + I(treatment * mediator1) + covariate1 + covariate2,
    mediation_demo
  )
  expect_error(
    extract_mediation(m1, model_y = wrapped, treatment = "treatment", mediator = "mediator1"),
    "Found function-wrapped treatment-by-mediator product term(s)",
    fixed = TRUE
  )
  mm <- lm(
    outcome ~ treatment + mediator1 + mediator2 + mediator1:mediator2 + covariate1 + covariate2,
    mediation_demo
  )
  expect_error(
    extract_mediation(m1,
      model_y = mm, treatment = "treatment",
      mediator = c("mediator1", "mediator2"), mediator_models = list(m2)
    ),
    "Multi-mediator (serial or parallel) extraction supports only treatment-by-mediator product terms",
    fixed = TRUE
  )
  d <- mediation_demo
  d$y_log <- exp(d$outcome_int / 5)
  gm <- glm(mediator1 ~ treatment + covariate1 + covariate2, gaussian(), d)
  gy <- glm(y_log ~ treatment * mediator1 + covariate1 + covariate2, gaussian(link = "log"), d)
  expect_error(
    extract_mediation(gm, model_y = gy, treatment = "treatment", mediator = "mediator1"),
    "Four-way decomposition requires the identity link",
    fixed = TRUE
  )
  expect_error(
    fit_mediation(outcome ~ treatment + mediator1, mediator1 ~ treatment,
      data = mediation_demo,
      treatment = "treatment", mediator = "mediator1", mod = FALSE
    ),
    "is only used with engine = \"native\"",
    fixed = TRUE
  )
})

test_that("the guide quotes the message fragments this test file checks", {
  skip_if_not(file.exists(guide_path()), "vignettes are not available (installed or built package)")
  txt <- paste(readLines(guide_path(), warn = FALSE), collapse = "\n")
  quoted <- c(
    "applies only when the outcome model has a treatment-by-mediator",
    "Found function-wrapped treatment-by-mediator product term(s)",
    "Multi-mediator (serial or parallel) extraction supports only treatment-by-mediator product terms",
    "Four-way decomposition requires the identity link",
    "is only used with engine = \"native\""
  )
  for (frag in quoted) {
    expect_true(grepl(frag, txt, fixed = TRUE), info = frag)
  }
})
