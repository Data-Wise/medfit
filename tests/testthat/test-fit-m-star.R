# Tests for fit_mediation(m_star = ) -- SPEC-m-star-argument-2026-08-22.md
#
# m_star fixes the reference mediator level at which the controlled direct
# effect is read off. It reaches the glm engine at extraction time and the
# regmedint engine at fitting time (as regmedint's own `m_cde`), so these
# tests assert both routes land on the same numbers.

make_int_data <- function(n = 300, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = stats::rbinom(n, 1, 0.5))
  d$C <- stats::rnorm(n)
  d$M <- 1 + 0.5 * d$X + 0.3 * d$C + stats::rnorm(n)
  d$Y <- 0.3 * d$X + 0.4 * d$M + 0.2 * d$X * d$M + 0.1 * d$C + stats::rnorm(n)
  d
}

# --- Signature -------------------------------------------------------------

test_that("m_star sits after engine_args and before dots", {
  nms <- names(formals(fit_mediation))
  expect_true(all(c("engine_args", "m_star", "...") %in% nms))
  expect_equal(
    which(nms == "m_star"), which(nms == "engine_args") + 1L
  )
  expect_equal(which(nms == "..."), length(nms))
  # Positional callers reaching through se_type must be undisturbed.
  expect_lt(which(nms == "se_type"), which(nms == "m_star"))
})

test_that("m_star defaults to 0, matching the lm and lavaan extractors", {
  expect_identical(formals(fit_mediation)$m_star, 0)
})

# --- glm engine ------------------------------------------------------------

test_that("m_star is honored by the glm engine", {
  d <- make_int_data()
  for (ms in c(0, 1, 2.5, -0.5)) {
    obj <- fit_mediation(Y ~ X * M, M ~ X, data = d,
                         treatment = "X", mediator = "M", m_star = ms)
    expect_s3_class(obj, "medfit::InteractionMediationData")
    expect_equal(obj@m_star, ms)
    # The class validator's own identity: CDE = c' + theta3 * m*
    expect_equal(obj@cde, obj@c_prime + obj@interaction * ms)
  }
})

test_that("headline effects are invariant to m_star; only the split moves", {
  d <- make_int_data()
  a <- fit_mediation(Y ~ X * M, M ~ X, data = d,
                     treatment = "X", mediator = "M", m_star = 0)
  b <- fit_mediation(Y ~ X * M, M ~ X, data = d,
                     treatment = "X", mediator = "M", m_star = 2)

  expect_equal(as.numeric(nde(a)), as.numeric(nde(b)))
  expect_equal(as.numeric(nie(a)), as.numeric(nie(b)))
  expect_equal(as.numeric(te(a)), as.numeric(te(b)))
  expect_equal(as.numeric(pm(a)), as.numeric(pm(b)))

  # CDE and INTref shift in exactly compensating directions.
  expect_false(isTRUE(all.equal(a@cde, b@cde)))
  expect_equal(a@cde + a@int_ref, b@cde + b@int_ref)
})

test_that("m_star reaches the four-way object with covariates present", {
  d <- make_int_data()
  obj <- fit_mediation(Y ~ X * M + C, M ~ X + C, data = d,
                       treatment = "X", mediator = "M", m_star = 1.25)
  expect_equal(obj@m_star, 1.25)
  expect_equal(obj@cde, obj@c_prime + obj@interaction * 1.25)
})

# --- Guard: refuse a value that cannot be used (SPEC D3) --------------------

test_that("supplying m_star without an interaction term is an error", {
  d <- make_int_data()
  expect_error(
    fit_mediation(Y ~ X + M, M ~ X, data = d,
                  treatment = "X", mediator = "M", m_star = 1),
    "four-way decomposition only"
  )
  # Even the default value errors when supplied explicitly -- the guard keys on
  # whether the argument was given, not on its value.
  expect_error(
    fit_mediation(Y ~ X + M, M ~ X, data = d,
                  treatment = "X", mediator = "M", m_star = 0),
    "four-way decomposition only"
  )
})

test_that("omitting m_star on a two-way fit is unaffected", {
  d <- make_int_data()
  obj <- fit_mediation(Y ~ X + M, M ~ X, data = d,
                       treatment = "X", mediator = "M")
  expect_s3_class(obj, "medfit::MediationData")
})

test_that("an explicit X:M term counts as an interaction for the guard", {
  d <- make_int_data()
  obj <- fit_mediation(Y ~ X + M + X:M, M ~ X, data = d,
                       treatment = "X", mediator = "M", m_star = 1)
  expect_equal(obj@m_star, 1)
})

test_that("m_star is validated as a single number", {
  d <- make_int_data()
  expect_error(
    fit_mediation(Y ~ X * M, M ~ X, data = d,
                  treatment = "X", mediator = "M", m_star = "a"),
    "m_star"
  )
  expect_error(
    fit_mediation(Y ~ X * M, M ~ X, data = d,
                  treatment = "X", mediator = "M", m_star = c(1, 2)),
    "m_star"
  )
})

# --- regmedint engine ------------------------------------------------------

test_that("m_star is honored by the regmedint engine", {
  skip_if_not_installed("regmedint")
  d <- make_int_data()
  obj <- fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X",
                       mediator = "M", engine = "regmedint", m_star = 1.5)
  expect_equal(obj@m_star, 1.5)
  expect_equal(obj@cde, obj@c_prime + obj@interaction * 1.5)
})

test_that("the two engines agree on the CDE/INTref split at the same m_star", {
  skip_if_not_installed("regmedint")
  d <- make_int_data()
  for (ms in c(0, 1.5)) {
    g <- fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X",
                       mediator = "M", m_star = ms)
    r <- fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X",
                       mediator = "M", engine = "regmedint", m_star = ms)
    expect_equal(g@m_star, r@m_star)
    expect_equal(g@cde, r@cde, tolerance = 1e-8)
    expect_equal(g@int_ref, r@int_ref, tolerance = 1e-8)
  }
})

test_that("the regmedint guard honors an engine_args interaction override", {
  skip_if_not_installed("regmedint")
  d <- make_int_data()
  expect_error(
    fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X", mediator = "M",
                  engine = "regmedint", engine_args = list(interaction = FALSE),
                  m_star = 1),
    "four-way decomposition only"
  )
})

# --- One knob, not two (SPEC D1) -------------------------------------------

test_that("engine_args$m_cde is refused and points at m_star", {
  skip_if_not_installed("regmedint")
  d <- make_int_data()
  expect_error(
    fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X", mediator = "M",
                  engine = "regmedint", engine_args = list(m_cde = 1)),
    "m_star"
  )
})

test_that("the other engine_args names still work", {
  skip_if_not_installed("regmedint")
  d <- make_int_data()
  obj <- fit_mediation(Y ~ X * M + C, M ~ X + C, data = d,
                       treatment = "X", mediator = "M", engine = "regmedint",
                       engine_args = list(c_cond = 0), m_star = 0.5)
  expect_equal(obj@m_star, 0.5)
})

# --- Inference at a non-zero m_star --------------------------------------
#
# The CDE gradient row is `c(c_prime = 1, theta3 = m_star)`, so at the default
# m_star = 0 the whole theta3 contribution to Var(CDE) drops out. Every other
# test in the package runs at that default, which would leave a wrong sign or a
# dropped term in that row unreachable. These two exercise it.

test_that("effect-level standard errors are invariant to m_star", {
  d <- make_int_data()
  se_of <- function(obj, parm) {
    ci <- suppressMessages(confint(obj, parm = parm))
    (ci[, 2] - ci[, 1]) / (2 * stats::qnorm(0.975))
  }
  a <- fit_mediation(Y ~ X * M, M ~ X, data = d,
                     treatment = "X", mediator = "M", m_star = 0)
  b <- fit_mediation(Y ~ X * M, M ~ X, data = d,
                     treatment = "X", mediator = "M", m_star = 2)

  # NDE = CDE + INTref, and both shift compensatingly, so the m_star terms must
  # cancel in the summed gradient -- Var(NDE) cannot depend on a reference level.
  expect_equal(se_of(a, "effects"), se_of(b, "effects"))
  expect_equal(se_of(a, "paths"), se_of(b, "paths"))

  # The split itself does move, or the test above would be vacuous.
  expect_false(isTRUE(all.equal(
    se_of(a, "components")[["cde"]], se_of(b, "components")[["cde"]]
  )))
})

test_that("the two engines agree on component SEs at a non-zero m_star", {
  skip_if_not_installed("regmedint")
  d <- make_int_data()
  se_of <- function(obj, parm) {
    ci <- suppressMessages(confint(obj, parm = parm))
    (ci[, 2] - ci[, 1]) / (2 * stats::qnorm(0.975))
  }
  # medfit's delta-method gradients (R/methods-base.R) and regmedint's own
  # delta method (.regmedint_component_vcov) are independent implementations,
  # so agreement here is evidence rather than a tautology.
  g <- fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X",
                     mediator = "M", m_star = 2)
  r <- fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X",
                     mediator = "M", m_star = 2, engine = "regmedint")

  expect_equal(se_of(g, "components"), se_of(r, "components"), tolerance = 1e-8)
  expect_equal(se_of(g, "effects"), se_of(r, "effects"), tolerance = 1e-8)
})
