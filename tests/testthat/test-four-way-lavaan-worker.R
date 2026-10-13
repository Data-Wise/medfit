# Four-way worker on the lavaan route (.extract_interaction_mediation_lavaan):
# SEs with a mediator covariate (F1), rejected treatment products (F3), and
# weighted covariate means (F5).
#
# References are independent of the code under test: lavaan's own `:=` defined
# parameters (the sample covariate mean enters as a literal constant, so the
# SEs are conditional on the observed covariates, as in the extractor) and the
# lm/glm route, never `extract_mediation()` of the same lavaan fit.

skip_if_not_installed("lavaan")

fw_data <- function(n = 2000, seed = 11, covariate = TRUE) {
  set.seed(seed)
  d <- data.frame(x = rbinom(n, 1, 0.5), c1 = rnorm(n, mean = 2))
  d$m <- 0.3 + 0.5 * d$x + (if (covariate) 0.8 * d$c1 else 0) + rnorm(n)
  d$xm <- d$x * d$m
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.3 * d$xm + 0.5 * d$c1 + rnorm(n)
  d$w <- runif(n, 0.4, 2.5)
  d
}

# lavaan `:=` reference for the six effects; `cbar`/`m_star` are literals.
fw_oracle <- function(d, covariate = TRUE, m_star = 0, weights = NULL) {
  cbar <- if (is.null(weights)) mean(d$c1) else stats::weighted.mean(d$c1, d$w)
  m_eq <- if (covariate) "m ~ pa*x + pg*c1 + b0*1" else "m ~ pa*x + b0*1"
  mean_m <- if (covariate) {
    sprintf("(b0 + pg*%.17g - %.17g)", cbar, m_star)
  } else {
    sprintf("(b0 - %.17g)", m_star)
  }
  syn_lines <- c(
    m_eq,
    "y ~ cp*x + pb*m + t3*xm + ph*c1",
    sprintf("cde := cp + t3*%.17g", m_star),
    sprintf("intref := t3*%s", mean_m),
    "intmed := t3*pa",
    "pie := pb*pa",
    sprintf("nde := cp + t3*%.17g + t3*%s", m_star, mean_m),
    sprintf("nie := t3*pa + pb*pa"),
    sprintf("te := cp + t3*%.17g + t3*%s + t3*pa + pb*pa", m_star, mean_m)
  )
  syn <- paste(syn_lines, collapse = "\n")
  fit <- if (is.null(weights)) {
    lavaan::sem(syn, d, meanstructure = TRUE)
  } else {
    lavaan::sem(syn, d, meanstructure = TRUE, sampling.weights = "w")
  }
  pe <- lavaan::parameterEstimates(fit)
  pe <- pe[pe$op == ":=", ]
  stats::setNames(pe$se, pe$lhs)
}

fw_extract <- function(d, covariate = TRUE, m_star = 0, weights = FALSE) {
  syn <- paste0("m ~ x", if (covariate) " + c1" else "", "\ny ~ x + m + xm + c1")
  fit <- if (weights) {
    lavaan::sem(syn, d, meanstructure = TRUE, sampling.weights = "w")
  } else {
    lavaan::sem(syn, d, meanstructure = TRUE)
  }
  extract_mediation(fit, treatment = "x", mediator = "m", interaction = "xm",
                    m_star = m_star)
}

fw_se <- function(o) {
  keys <- c(cde = "cde", intref = "int_ref", intmed = "int_med", pie = "pie",
            nde = "nde", nie = "nie", te = "te")
  stats::setNames(unname(.effect_se(o, unname(keys))[unname(keys)]), names(keys))
}

# ==============================================================================
# F1: the mediator-covariate term in the SE gradient
# ==============================================================================

test_that("F1: four-way SEs match lavaan `:=` with a mediator covariate", {
  d <- fw_data()
  expect_equal(fw_se(fw_extract(d)), fw_oracle(d), tolerance = 1e-6)
})

test_that("F1: four-way SEs match `:=` with a covariate and m_star != 0", {
  d <- fw_data(seed = 12)
  expect_equal(fw_se(fw_extract(d, m_star = 0.7)), fw_oracle(d, m_star = 0.7),
               tolerance = 1e-6)
})

test_that("F1: a model with no mediator covariate still matches `:=`", {
  d <- fw_data(covariate = FALSE, seed = 13)
  expect_equal(fw_se(fw_extract(d, covariate = FALSE)),
               fw_oracle(d, covariate = FALSE), tolerance = 1e-6)
})

test_that("F1: the covariate alias row is in @vcov and @estimates", {
  o <- fw_extract(fw_data())
  expect_true("m_c1" %in% rownames(o@vcov))
  ref <- lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1", fw_data(),
                     meanstructure = TRUE)
  expect_equal(unname(o@estimates[["m_c1"]]), unname(lavaan::coef(ref)[["m~c1"]]))
})

# ==============================================================================
# F3: treatment products outside the outcome's X x M term
# ==============================================================================

test_that("F3: a named `x:w2` product in the mediator equation errors", {
  # lavaan cannot parse a `:` term, so the accessor list stands in for a fit
  # whose parameter table carries one (the native engine writes them).
  d <- fw_data()
  d$w2 <- rnorm(nrow(d))
  d$xw <- d$x * d$w2
  fit <- lavaan::sem("m ~ x + w2 + xw\ny ~ x + m + xm + c1", d,
                     meanstructure = TRUE)
  acc <- .sem_accessors_lavaan(fit)
  pt <- acc$param_table
  acc$param_table <- function(standardized = FALSE) {
    out <- pt(standardized)
    out$rhs[out$rhs == "xw"] <- "x:w2"
    out
  }
  expect_error(extract_mediation_lavaan(acc, treatment = "x", mediator = "m",
                                        interaction = "xm"),
               "treatment.*mediator equation|mediator equation.*treatment")
})

test_that("F3: a user-built treatment product in the mediator equation errors", {
  d <- fw_data()
  d$w2 <- rnorm(nrow(d))
  d$xw <- d$x * d$w2
  fit <- lavaan::sem("m ~ x + w2 + xw\ny ~ x + m + xm + c1", d,
                     meanstructure = TRUE)
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m",
                                 interaction = "xm"), "mediator equation")
})

test_that("F3: a treatment-by-covariate product in the outcome equation errors", {
  d <- fw_data()
  d$xc <- d$x * d$c1
  fit <- lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1 + xc", d,
                     meanstructure = TRUE)
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m",
                                 interaction = "xm"), "outcome equation")
})

test_that("F3: decomposition = 'two_way' still accepts those models", {
  d <- fw_data()
  d$xc <- d$x * d$c1
  fit <- lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1 + xc", d,
                     meanstructure = TRUE)
  expect_no_error(extract_mediation(fit, treatment = "x", mediator = "m",
                                    decomposition = "two_way"))
})

test_that("F3: the effects are the 0-to-1 contrast of the treatment", {
  # The decomposition is for X = 0 versus X = 1 whatever the coding; a
  # continuous treatment is not rejected, and matches the lm route.
  set.seed(5)
  n <- 1500
  d <- data.frame(x = rnorm(n), c1 = rnorm(n, 2))
  d$m <- 0.3 + 0.5 * d$x + 0.8 * d$c1 + rnorm(n)
  d$xm <- d$x * d$m
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.3 * d$xm + 0.5 * d$c1 + rnorm(n)
  fit <- lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1", d, meanstructure = TRUE)
  o <- extract_mediation(fit, treatment = "x", mediator = "m", interaction = "xm")
  lm_m <- stats::lm(m ~ x + c1, d)
  lm_y <- stats::lm(y ~ x + m + x:m + c1, d)
  ref <- extract_mediation(lm_m, model_y = lm_y, treatment = "x",
                           mediator = "m")
  expect_equal(o@int_ref, ref@int_ref, tolerance = 1e-6)
  expect_equal(o@total_effect, ref@total_effect, tolerance = 1e-6)
})

# ==============================================================================
# F5: weighted covariate means
# ==============================================================================

test_that("F5: weighted INTref matches the lm route and the hand value", {
  d <- fw_data(seed = 21)
  o <- fw_extract(d, weights = TRUE)
  lm_m <- stats::lm(m ~ x + c1, d, weights = w)
  lm_y <- stats::lm(y ~ x + m + x:m + c1, d, weights = w)
  ref <- extract_mediation(lm_m, model_y = lm_y, treatment = "x",
                           mediator = "m", interaction = "xm")
  expect_equal(o@a_path, ref@a_path, tolerance = 1e-6)
  expect_equal(o@int_ref, ref@int_ref, tolerance = 1e-6)
  expect_equal(o@nde, ref@nde, tolerance = 1e-6)
  expect_equal(o@total_effect, ref@total_effect, tolerance = 1e-6)
  b0 <- unname(o@estimates[["b0"]])
  g <- unname(o@estimates[["m_c1"]])
  hand <- o@interaction * (b0 + g * stats::weighted.mean(d$c1, d$w) - o@m_star)
  expect_equal(o@int_ref, hand, tolerance = 1e-10)
})

test_that("F5: weighted four-way SEs match `:=` with the weighted mean", {
  d <- fw_data(seed = 22)
  expect_equal(fw_se(fw_extract(d, weights = TRUE)),
               fw_oracle(d, weights = TRUE), tolerance = 1e-6)
})

# ==============================================================================
# Review follow-ups: unusable covariates, weighted multi-group, product probe
# ==============================================================================

test_that("a mediator covariate missing from the data errors instead of being skipped", {
  d <- fw_data()
  fit <- lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1", d, meanstructure = TRUE)
  acc <- .sem_accessors_lavaan(fit)
  acc$data <- function() d[, setdiff(names(d), "c1"), drop = FALSE]
  expect_error(extract_mediation_lavaan(acc, treatment = "x", mediator = "m",
                                        interaction = "xm"),
               "Cannot compute the covariate means.*c1")
})

test_that("a non-numeric mediator covariate errors instead of being skipped", {
  d <- fw_data()
  fit <- lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1", d, meanstructure = TRUE)
  acc <- .sem_accessors_lavaan(fit)
  acc$data <- function() {
    out <- d
    out$c1 <- as.character(out$c1)
    out
  }
  expect_error(extract_mediation_lavaan(acc, treatment = "x", mediator = "m",
                                        interaction = "xm"),
               "Cannot compute the covariate means.*c1")
})

test_that("a weighted multi-group fit errors rather than using unweighted means", {
  d <- fw_data(n = 1600)
  d$g <- rep(1:2, each = 800)
  fit <- lavaan::sem("m ~ x + c1\ny ~ x + m + xm + c1", d, meanstructure = TRUE,
                     sampling.weights = "w", group = "g")
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m",
                                 interaction = "xm"),
               "multi-group.*not supported")
})

test_that("the product probe still finds a hand-built product among many columns", {
  d <- fw_data()
  d$w2 <- rnorm(nrow(d))
  d$xw <- d$x * d$w2
  set.seed(3)
  decoys <- as.data.frame(matrix(rnorm(nrow(d) * 60), ncol = 60))
  names(decoys) <- paste0("z", seq_len(60))
  # The matching column sits after 60 decoys, so the probe must reject them all.
  dd <- cbind(decoys, d)
  fit <- lavaan::sem("m ~ x + w2 + xw\ny ~ x + m + xm + c1", dd,
                     meanstructure = TRUE)
  expect_error(extract_mediation(fit, treatment = "x", mediator = "m",
                                 interaction = "xm"), "mediator equation")
})

test_that("the product probe handles a continuous treatment and an uncorrelated covariate", {
  set.seed(8)
  n <- 1200
  d <- data.frame(x = rnorm(n), c1 = rnorm(n, 2), w2 = rnorm(n))
  d$xw <- d$x * d$w2
  d$m <- 0.3 + 0.5 * d$x + 0.8 * d$c1 + 0.4 * d$xw + rnorm(n)
  d$xm <- d$x * d$m
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.3 * d$xm + 0.5 * d$c1 + rnorm(n)
  # The model's data holds only the model variables, so the second factor (w2)
  # must be in the model for a hand-built product to be recognized.
  bad <- lavaan::sem("m ~ x + c1 + w2 + xw\ny ~ x + m + xm + c1", d,
                     meanstructure = TRUE)
  expect_error(extract_mediation(bad, treatment = "x", mediator = "m",
                                 interaction = "xm"), "mediator equation")
  # Without the xw column, w2 is not a treatment product, so it is accepted.
  ok <- lavaan::sem("m ~ x + c1 + w2\ny ~ x + m + xm + c1", d,
                    meanstructure = TRUE)
  expect_no_error(extract_mediation(ok, treatment = "x", mediator = "m",
                                    interaction = "xm"))
})
