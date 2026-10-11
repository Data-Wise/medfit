# The cluster, lavaan and native model pages quote these error messages. Each test
# triggers the real error, so a reworded message fails here before the page goes stale.

native_base <- "
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
"

test_that("native engine messages quoted on the model pages exist", {
  expect_error(
    fit_sem("outcome ~ b * mediator1\nab := a * b", mediation_demo),
    "unknown parameter label"
  )
  expect_error(
    fit_sem("outcome ~ mediator1\nmediator1 ~ 1", mediation_demo),
    "mean structure is not supported"
  )
  expect_error(
    fit_sem("eta =~ m1 + m2 + m3\neta ~ a * X\nY ~ b * eta", mediation_demo),
    "variables in the model are not columns of `data`"
  )
})

test_that("fit_mediation(engine = 'native') takes one mediator", {
  expect_error(
    fit_mediation(model = native_base, data = mediation_demo, treatment = "treatment",
                  mediator = c("mediator1", "mediator2"), engine = "native"),
    "Must have length 1"
  )
})

test_that("a lavaan model without the b path is rejected with the quoted message", {
  skip_if_not_installed("lavaan")
  fit <- lavaan::sem("mediator1 ~ treatment", mediation_demo)
  expect_error(
    extract_mediation(fit, treatment = "treatment", mediator = "mediator1", outcome = "outcome"),
    "Could not find b path \\(mediator -> outcome\\)"
  )
})

test_that("a treatment that varies within clusters is rejected with the quoted message", {
  skip_if_not_installed("lme4")
  set.seed(1)
  d <- data.frame(school = factor(rep(1:12, each = 6)), X = rbinom(72, 1, 0.5))
  d$M <- 0.5 * d$X + rnorm(72)
  d$Y <- 0.3 * d$M + rnorm(72)
  expect_error(
    fit_mediation(Y ~ X + M, M ~ X, data = d, treatment = "X", mediator = "M",
                  engine = "lmer", cluster = "school"),
    "varies within clusters; 1-1-1 designs are not supported yet"
  )
})

test_that("the cluster-mean message names the term to add", {
  skip_if_not_installed("lme4")
  set.seed(2)
  J <- 12
  d <- data.frame(school = factor(rep(seq_len(J), each = 8)))
  d$X <- rep(rep(0:1, length.out = J), each = 8)
  d$M <- 0.5 * d$X + rnorm(J * 8)
  d$Y <- 0.3 * d$M + rnorm(J * 8)
  fm <- suppressMessages(lme4::lmer(M ~ X + (1 | school), d))
  fy <- suppressMessages(lme4::lmer(Y ~ X + M + (1 | school), d))
  expect_error(
    extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M"),
    "has no cluster-mean term for `M`"
  )
})

test_that("a random slope on the treatment is rejected and one on the within term is accepted", {
  skip_if_not_installed("lme4")
  set.seed(3)
  J <- 26
  d <- data.frame(school = factor(rep(seq_len(J), each = 8)))
  d$X <- rep(rep(0:1, length.out = J), each = 8)
  d$M <- 0.5 * d$X + rnorm(J * 8)
  d$Y <- 0.3 * d$M + rnorm(J * 8)
  fit <- function(slope) {
    suppressWarnings(suppressMessages(
      fit_mediation(Y ~ X + M, M ~ X, data = d, treatment = "X", mediator = "M",
                    engine = "lmer", cluster = "school", engine_args = list(random_y = slope))
    ))
  }
  expect_error(fit(~X), "A random slope on the treatment \\(`X`\\) is not supported: it is constant within clusters")
  expect_s7_class(fit(~M), ClusterMediationData)
})
