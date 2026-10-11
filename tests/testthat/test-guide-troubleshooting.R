# The Troubleshooting guide quotes the messages below. Each case triggers the real
# error and checks that the guide still quotes the same fragment, so a reworded
# message or an edited page fails here before the guide goes stale.

guide_path <- function() {
  testthat::test_path("..", "..", "vignettes", "articles", "guide-troubleshooting.qmd")
}

mediation_demo <- medfit::mediation_demo
cv <- "covariate1 + covariate2"
fy <- stats::as.formula(paste("outcome ~ treatment + mediator1 +", cv))
fm <- stats::as.formula(paste("mediator1 ~ treatment +", cv))
fit_glm <- function(...) {
  fit_mediation(fy, fm, data = mediation_demo, treatment = "treatment", mediator = "mediator1", ...)
}
lm1 <- function() lm(mediator1 ~ treatment + covariate1 + covariate2, mediation_demo)
lm_y1 <- function() lm(outcome ~ treatment + mediator1 + covariate1 + covariate2, mediation_demo)
lm_y2 <- function() {
  lm(outcome ~ treatment + mediator1 + mediator2 + covariate1 + covariate2, mediation_demo)
}

case <- function(fragment, expr) list(fragment = fragment, expr = substitute(expr))

cases <- list(
  case(
    "Treatment variable 'treatment' must be in formula_m",
    fit_mediation(fy, mediator1 ~ covariate1,
      data = mediation_demo,
      treatment = "treatment", mediator = "mediator1"
    )
  ),
  case(
    "Mediator variable 'mediator1' must be in formula_y",
    fit_mediation(outcome ~ treatment + covariate1, fm,
      data = mediation_demo,
      treatment = "treatment", mediator = "mediator1"
    )
  ),
  case(
    "Must be element of set {'glm','regmedint','lmer','native'}",
    fit_glm(engine = "foo")
  ),
  case("is only used with engine = \"native\"", fit_glm(model = "y ~ x")),
  case("engine = \"lmer\" needs", fit_glm(engine = "lmer")),
  case("is only used with engine = \"lmer\"", fit_glm(cluster = "covariate1")),
  case(
    "engine = \"regmedint\" does not support",
    fit_glm(engine = "regmedint", weights = rep(1, nrow(mediation_demo)))
  ),
  case(
    "supports se_type = \"model\" only",
    fit_glm(engine = "regmedint", se_type = "sandwich")
  ),
  case(
    "must be a numeric 0/1 variable for engine = \"regmedint\"",
    fit_mediation(outcome ~ covariate1 + mediator1 + covariate2,
      mediator1 ~ covariate1 + covariate2,
      data = mediation_demo,
      treatment = "covariate1", mediator = "mediator1", engine = "regmedint"
    )
  ),
  case(
    "regmedint fits the mediator model with the same covariates as the outcome model",
    fit_mediation(outcome ~ treatment + mediator1 + covariate1, fm,
      data = mediation_demo, treatment = "treatment", mediator = "mediator1",
      engine = "regmedint"
    )
  ),
  case(
    "contains the random-effect term",
    fit_mediation(outcome ~ treatment + mediator1 + (1 | covariate1), fm,
      data = mediation_demo, treatment = "treatment", mediator = "mediator1",
      engine = "lmer", cluster = "covariate1"
    )
  ),
  case(
    "must be in data",
    med(
      data = mediation_demo, treatment = "treatmentx", mediator = "mediator1",
      outcome = "outcome"
    )
  ),
  case(
    "requires 'mediator_models'",
    extract_mediation(lm1(),
      model_y = lm_y2(), treatment = "treatment",
      mediator = c("mediator1", "mediator2")
    )
  ),
  case(
    "must be the model for mediator 2",
    extract_mediation(lm1(),
      model_y = lm_y2(), treatment = "treatment",
      mediator = c("mediator1", "mediator2"),
      mediator_models = list(lm(mediator3 ~ treatment + mediator1, mediation_demo))
    )
  ),
  case(
    "applies only when the outcome model has a treatment-by-mediator",
    extract_mediation(lm1(),
      model_y = lm_y1(), treatment = "treatment",
      mediator = "mediator1", m_star = 1
    )
  ),
  case(
    "requires an interaction term",
    extract_mediation(lm1(),
      model_y = lm_y1(), treatment = "treatment",
      mediator = "mediator1", decomposition = "four_way"
    )
  ),
  case(
    "Four-way decomposition currently supports continuous (Gaussian)",
    {
      set.seed(1)
      d <- mediation_demo
      d$yb <- rbinom(nrow(d), 1, stats::plogis(d$outcome / 3))
      fyb <- glm(yb ~ treatment * mediator1 + covariate1 + covariate2, binomial, d)
      extract_mediation(lm1(), model_y = fyb, treatment = "treatment", mediator = "mediator1")
    }
  ),
  case("Can't find method for", nie(lm1())),
  case("quick() requires a MediationData", quick(1:3)),
  case("parm must be 'paths' or 'effects'", confint(fit_glm(), parm = "zzz")),
  case(
    "mediation_data is required for parametric bootstrap",
    bootstrap_mediation(function(t) t[1], method = "parametric", n_boot = 20)
  ),
  case(
    "resamples whole clusters and needs method = \"nonparametric\"",
    bootstrap_mediation(function(t) 1,
      method = "parametric",
      mediation_data = fit_glm(), n_boot = 20, cluster = "covariate1"
    )
  ),
  case(
    "Too many bootstrap samples failed",
    suppressWarnings(
      bootstrap_mediation(function(dd) stop("boom"),
        method = "nonparametric",
        data = mediation_demo, n_boot = 20, seed = 1
      )
    )
  )
)

test_that("every error the Troubleshooting guide quotes is real", {
  for (case in cases) {
    expect_error(eval(case$expr), case$fragment, fixed = TRUE, info = case$fragment)
  }
})

test_that("the guide quotes every fragment this test triggers", {
  skip_if_not(file.exists(guide_path()), "vignettes are not available (installed or built package)")
  txt <- paste(readLines(guide_path(), warn = FALSE), collapse = "\n")
  for (case in cases) {
    expect_true(grepl(case$fragment, txt, fixed = TRUE), info = case$fragment)
  }
})

# Messages that are warnings or notes, not errors.
test_that("the few-clusters warnings and the dropped-draws warning are real", {
  skip_if_not_installed("lme4")
  set.seed(5)
  make <- function(J) {
    d <- data.frame(school = factor(rep(seq_len(J), each = 8)))
    d$X <- rep(rep(0:1, length.out = J), each = 8)
    d$M <- 0.5 * d$X + rnorm(J * 8)
    d$Y <- 0.3 * d$M + rnorm(J * 8)
    d
  }
  fit <- function(d, ...) {
    suppressMessages(fit_mediation(Y ~ X + M, M ~ X,
      data = d, treatment = "X", mediator = "M",
      engine = "lmer", cluster = "school", ...
    ))
  }
  expect_warning(fit(make(8)), "clusters: inference on the cluster-level paths is unreliable",
    fixed = TRUE
  )
  expect_warning(fit(make(14)), "fewer than 25", fixed = TRUE)
  # Draws that fail are dropped with a warning; some draws must succeed to get that far.
  n_call <- 0L
  flaky <- function(dd) {
    n_call <<- n_call + 1L
    if (n_call %% 4L == 0L) stop("boom")
    mean(dd$outcome)
  }
  expect_warning(
    bootstrap_mediation(flaky, method = "nonparametric", data = mediation_demo, n_boot = 20, seed = 1),
    "bootstrap samples failed and were excluded",
    fixed = TRUE
  )
})

test_that("the inverse-probability weighting note is shown for weights with model SEs", {
  state <- utils::getFromNamespace(".medfit_state", "medfit")
  state[["ipw_model_se"]] <- NULL
  expect_message(
    fit_glm(weights = rep(1, nrow(mediation_demo))),
    "Model-based standard errors are not valid under inverse-probability weighting",
    fixed = TRUE
  )
})

test_that("the guide also quotes the cluster and native messages tested elsewhere", {
  skip_if_not(file.exists(guide_path()), "vignettes are not available (installed or built package)")
  txt <- paste(readLines(guide_path(), warn = FALSE), collapse = "\n")
  elsewhere <- c(
    "varies within clusters; 1-1-1 designs are not supported yet",
    "has no cluster-mean term for",
    "unknown parameter label",
    "mean structure is not supported",
    "nonlinear constraints are not supported in this version",
    "variables in the model are not columns of",
    "Must have length 1",
    "clusters: inference on the cluster-level paths is unreliable",
    "fewer than 25",
    "bootstrap samples failed and were excluded",
    "Model-based standard errors are not valid under inverse-probability weighting"
  )
  for (frag in elsewhere) {
    expect_true(grepl(frag, txt, fixed = TRUE), info = frag)
  }
})
