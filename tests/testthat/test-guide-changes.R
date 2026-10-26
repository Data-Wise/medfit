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

# ---- names, nobs and the lavaan four-way fixes (upgrade-guide rows for 0.8.0 and 0.9.0) ----

glm_fit <- function(data = mediation_demo) {
  fit_mediation(
    outcome ~ treatment + mediator1 + covariate1, mediator1 ~ treatment + covariate1,
    data = data, treatment = "treatment", mediator = "mediator1"
  )
}

test_that("tidy() and glance() use snake_case names; no dotted name is left", {
  fit <- glm_fit()
  expect_equal(names(generics::tidy(fit, type = "effects", conf_int = TRUE)),
               c("term", "estimate", "std_error", "conf_low", "conf_high"))
  sem <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment", mediation_demo)
  # 0.15.0: the default fixes the exogenous variables, so the parameter table carries the `fixed_x` column
  expect_equal(names(generics::tidy(sem)), c("term", "op", "estimate", "std_error", "statistic", "p_value", "fixed_x"))
  expect_true("p_value" %in% names(generics::glance(sem)))
  expect_false(any(grepl(".", c(names(generics::tidy(sem)), names(generics::glance(sem))), fixed = TRUE)))
  expect_s3_class(summary(fit), "summary_MediationData")
})

test_that("the dotted tidy() arguments still work and warn", {
  withr::local_options(lifecycle_verbosity = "warning")
  fit <- glm_fit()
  expect_warning(old <- generics::tidy(fit, type = "effects", conf.int = TRUE, conf.level = 0.9),
                 "is deprecated as of medfit 0.9.0", fixed = TRUE)
  expect_equal(old, generics::tidy(fit, type = "effects", conf_int = TRUE, conf_level = 0.9))
  expect_equal(names(old), c("term", "estimate", "std_error", "conf_low", "conf_high"))
})

test_that("planted: a tidy() that reverts to dotted names fails the naming check", {
  fit <- glm_fit()
  reverted <- generics::tidy(fit, type = "effects", conf_int = TRUE)
  names(reverted) <- sub("std_error", "std.error", names(reverted), fixed = TRUE)
  expect_failure(expect_equal(names(reverted), c("term", "estimate", "std_error", "conf_low", "conf_high")))
})

test_that("fit_sem(sampling_weights =) still works and warns; weights = is the name (0.8.0)", {
  withr::local_options(lifecycle_verbosity = "warning")
  syn <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
  w <- seq_len(nrow(mediation_demo)) %% 3 + 1
  new <- fit_sem(syn, mediation_demo, weights = w, se_type = "sandwich")
  expect_warning(old <- fit_sem(syn, mediation_demo, sampling_weights = w, se_type = "sandwich"),
                 "sampling_weights", fixed = TRUE)
  expect_equal(coef(old), coef(new))
})

test_that("nobs(), n_obs and med() count the rows the models used when values are missing (0.8.0)", {
  d <- mediation_demo[seq_len(400), ]
  expect_equal(nrow(d), 400L)
  d$treatment[1:5] <- NA
  fit <- glm_fit(d)
  expect_equal(nobs(fit), 395L)
  expect_equal(fit@n_obs, 395L)
  m <- med(data = d, treatment = "treatment", mediator = "mediator1", outcome = "outcome")
  expect_equal(nobs(m), 395L)
  # the old answer is what a count of the data rows gives, and it fails the check
  expect_failure(expect_equal(nrow(d), nobs(fit)))
})

# Four-way decomposition from a lavaan fit (0.9.0): a mediator equation with a covariate, simulated data.
fw_data <- function(n = 2000, seed = 11) {
  set.seed(seed)
  d <- data.frame(x = rbinom(n, 1, 0.5), c1 = rnorm(n, mean = 2))
  d$m <- 0.3 + 0.5 * d$x + 0.8 * d$c1 + rnorm(n)
  d$xm <- d$x * d$m
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.3 * d$xm + 0.5 * d$c1 + rnorm(n)
  d$w <- runif(n, 0.4, 2.5) * exp(0.4 * (d$c1 - 2))
  d
}
fw_syntax <- "m ~ x + c1\ny ~ x + m + xm + c1"
fw_extract <- function(d, weights = NULL) {
  fit <- suppressWarnings(
    if (is.null(weights)) {
      lavaan::sem(fw_syntax, d, meanstructure = TRUE, information = "observed")
    } else {
      lavaan::sem(fw_syntax, d, meanstructure = TRUE, sampling.weights = "w")
    }
  )
  extract_mediation(fit, treatment = "x", mediator = "m", interaction = "xm")
}
fw_se <- function(x, term) {
  td <- generics::tidy(x, type = "components")
  td$std_error[td$term == term]
}

test_that("lavaan four-way: INTref SE equals lavaan's own `:=` (0.069), not 0.022 (0.9.0)", {
  skip_if_not_installed("lavaan")
  d <- fw_data()
  x <- fw_extract(d)
  cbar <- sprintf("%.17g", mean(d$c1))
  syn <- paste0(
    "m ~ pa*x + pg*c1 + b0*1\ny ~ cp*x + pb*m + t3*xm + ph*c1\n",
    "int_ref := t3*(b0 + pg*", cbar, ")"
  )
  lv <- suppressWarnings(lavaan::sem(syn, d, meanstructure = TRUE, information = "observed"))
  ref <- lavaan::parameterEstimates(lv)
  ref <- ref[ref$op == ":=", ]
  expect_equal(fw_se(x, "int_ref"), ref$se, tolerance = 1e-6)
  expect_equal(round(fw_se(x, "int_ref"), 3), 0.069)
})

test_that("planted: dropping the covariate gradient term moves the INTref SE off lavaan's `:=`", {
  fx_skip_covr()
  skip_if_not_installed("lavaan")
  d <- fw_data()
  mutated <- sem_mutate(.effect_gradients_interaction, "cov_grad[pn] <- t3 * cm", "cov_grad[pn] <- 0")
  clean <- fw_se(fw_extract(d), "int_ref")
  local_mocked_bindings(.effect_gradients_interaction = mutated)
  bad <- fw_se(fw_extract(d), "int_ref")
  # the mutation restores only one of the pieces 0.8.0 left out (0.8.0 gave 0.022 on this data); it already misses 0.069
  expect_gt(abs(bad - clean) / clean, 0.02)
  expect_failure(expect_equal(bad, clean, tolerance = 1e-6))
})

test_that("lavaan four-way with weights: INTref uses the weighted covariate means (0.841), not 0.726 (0.9.0)", {
  skip_if_not_installed("lavaan")
  d <- fw_data()
  x <- fw_extract(d, d$w)
  glm_route <- suppressMessages(fit_mediation(y ~ x + m + x:m + c1, m ~ x + c1, d,
    treatment = "x", mediator = "m", weights = d$w
  ))
  expect_equal(x@int_ref, glm_route@int_ref, tolerance = 1e-6)
  expect_equal(round(x@int_ref, 3), 0.841)
})

test_that("planted: unweighted covariate means restore the 0.726 INTref of 0.8.0", {
  fx_skip_covr()
  skip_if_not_installed("lavaan")
  d <- fw_data()
  mutated <- sem_mutate(.extract_interaction_mediation_lavaan, "else sum(data[[cv]] * w)/sum(w)",
                        "else mean(data[[cv]])")
  local_mocked_bindings(.extract_interaction_mediation_lavaan = mutated)
  bad <- fw_extract(d, d$w)
  expect_equal(round(bad@int_ref, 3), 0.726)
})

test_that("lavaan four-way stops on a treatment product in the mediator or outcome equation (0.9.0)", {
  skip_if_not_installed("lavaan")
  d <- fw_data()
  d$xc <- d$x * d$c1
  m_eq <- suppressWarnings(lavaan::sem("m ~ x + c1 + xc\ny ~ x + m + xm + c1", d, meanstructure = TRUE))
  expect_error(extract_mediation(m_eq, treatment = "x", mediator = "m", interaction = "xm"),
               "does not support a treatment product in the mediator equation", fixed = TRUE)
  y_eq <- suppressWarnings(lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1 + xc", d, meanstructure = TRUE))
  expect_error(extract_mediation(y_eq, treatment = "x", mediator = "m", interaction = "xm"),
               "does not support a treatment product in the outcome equation", fixed = TRUE)
})

test_that("the guide quotes the message fragments this test file checks", {
  skip_if_not(file.exists(guide_path()), "vignettes are not available (installed or built package)")
  txt <- paste(readLines(guide_path(), warn = FALSE), collapse = "\n")
  quoted <- c(
    "applies only when the outcome model has a treatment-by-mediator",
    "Found function-wrapped treatment-by-mediator product term(s)",
    "Multi-mediator (serial or parallel) extraction supports only treatment-by-mediator product terms",
    "Four-way decomposition requires the identity link",
    "is only used with engine = \"native\"",
    "does not support a treatment product",
    "is deprecated as of medfit 0.9.0",
    "std_error", "conf_low", "p_value", "summary_MediationData", "sampling_weights",
    "0.022", "0.069", "0.726", "0.841", "395"
  )
  for (frag in quoted) {
    expect_true(grepl(frag, txt, fixed = TRUE), info = frag)
  }
})

test_that("the 0.11.0 AIC/BIC refusal the guide lists is real, and the guide quotes it", {
  skip_if_not(file.exists(guide_path()), "vignettes are not available (installed or built package)")
  base <- "mediator1 ~ treatment\noutcome ~ mediator1 + treatment"
  with_x <- suppressWarnings(fit_sem(paste0(base, " + treatment:mediator1"), medfit::mediation_demo))
  without <- suppressWarnings(fit_sem(base, medfit::mediation_demo))
  expect_error(stats::AIC(with_x, without), "different observed variables")
  txt <- paste(readLines(guide_path(), warn = FALSE), collapse = "\n")
  expect_true(grepl("different observed variables", txt, fixed = TRUE))
  expect_true(grepl("covariate_mean_variance", txt, fixed = TRUE))
  expect_true(grepl("model-native-factors.html", txt, fixed = TRUE))
})
