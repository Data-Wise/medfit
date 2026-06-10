# Tests for the InteractionMediationData S7 class (Extension B, PR B1).
#
# Scope: the CLASS only -- construction, validator, print/show, effect methods
# (nie/nde/te/pm/paths/decompose), and base methods (coef/vcov/nobs). Extraction
# from fitted models and confint() delta-method SEs arrive in later increments.
#
# Path/component convention (continuous Y, M; binary X; reference m_star):
#   a_path is beta_1 (treatment on mediator), b_path is theta_2 (mediator main
#   effect), c_prime is theta_1 (treatment main effect), interaction is theta_3.
#   CDE is theta1 plus theta3 times m_star; INTmed is theta3 times beta1;
#   PIE is theta2 times beta1.

# A valid hand-built object with internally consistent components. With
# beta1 0.5, theta2 0.3, theta1 0.1, theta3 0.2 and reference 0: CDE is 0.1,
# INTmed is 0.10, PIE is 0.15, INTref is 0.04 (chosen), total is 0.39,
# NDE is 0.14, NIE is 0.25.
make_interaction <- function(a_path = 0.5, b_path = 0.3, c_prime = 0.1,
                             interaction = 0.2,
                             cde = 0.1, int_ref = 0.04,
                             int_med = 0.10, pie = 0.15,
                             nde = 0.14, nie = 0.25, total_effect = 0.39,
                             m_star = 0) {
  InteractionMediationData(
    a_path = a_path, b_path = b_path, c_prime = c_prime, interaction = interaction,
    cde = cde, int_ref = int_ref, int_med = int_med, pie = pie,
    nde = nde, nie = nie, total_effect = total_effect, m_star = m_star,
    estimates = c(a = a_path, b = b_path, c_prime = c_prime, theta3 = interaction),
    vcov = diag(0.01, 4),
    treatment = "X", mediator = "M", outcome = "Y",
    mediator_predictors = "X", outcome_predictors = c("X", "M", "X:M"),
    n_obs = 200L, converged = TRUE, source_package = "medfit"
  )
}

# ==============================================================================
# Construction and structure
# ==============================================================================

test_that("a valid object constructs and carries the expected slots", {
  imd <- make_interaction()
  expect_s3_class(imd, "medfit::InteractionMediationData")
  expect_equal(imd@interaction, 0.2)
  expect_equal(imd@m_star, 0)
  expect_equal(imd@treatment, "X")
  expect_equal(imd@outcome, "Y")
  expect_true(imd@converged)
  expect_equal(imd@source_package, "medfit")
})

# ==============================================================================
# Effect methods
# ==============================================================================

test_that("nde/nie/te aggregate the four-way components correctly", {
  imd <- make_interaction()
  expect_equal(as.numeric(nde(imd)), 0.14)   # controlled direct plus reference interaction
  expect_equal(as.numeric(nie(imd)), 0.25)   # mediated interaction plus pure indirect
  expect_equal(as.numeric(te(imd)), 0.39)    # all four components
})

test_that("pm is NIE / TE", {
  imd <- make_interaction()
  expect_equal(as.numeric(pm(imd)), 0.25 / 0.39)
})

test_that("paths returns a, b, c_prime, theta3", {
  imd <- make_interaction()
  p <- paths(imd)
  expect_equal(names(p), c("a", "b", "c_prime", "theta3"))
  expect_equal(unname(p), c(0.5, 0.3, 0.1, 0.2))
})

test_that("decompose returns the components plus derived effects", {
  imd <- make_interaction()
  d <- decompose(imd)
  expect_equal(names(d),
               c("cde", "int_ref", "int_med", "pie", "nde", "nie", "total"))
  expect_equal(unname(d), c(0.1, 0.04, 0.10, 0.15, 0.14, 0.25, 0.39))
})

# ==============================================================================
# theta_3 = 0 collapses to standard simple mediation
# ==============================================================================

test_that("no interaction (theta3 = 0) collapses to simple mediation", {
  # With theta3 zero: INTmed and INTref vanish, CDE is theta1 (0.1), PIE is
  # theta2 times beta1 (0.15).
  imd0 <- make_interaction(
    interaction = 0, cde = 0.1, int_ref = 0, int_med = 0, pie = 0.15,
    nde = 0.1, nie = 0.15, total_effect = 0.25
  )
  expect_equal(as.numeric(nde(imd0)), imd0@cde)            # NDE collapses to CDE
  expect_equal(as.numeric(nie(imd0)), imd0@pie)            # NIE collapses to PIE
  expect_equal(imd0@int_med, 0)
  expect_equal(imd0@int_ref, 0)
})

# ==============================================================================
# Base methods
# ==============================================================================

test_that("coef supports paths/components/effects/all", {
  imd <- make_interaction()
  expect_equal(names(coef(imd, "paths")), c("a", "b", "c_prime", "theta3"))
  expect_equal(coef(imd, "components"),
               c(cde = 0.1, int_ref = 0.04, int_med = 0.10, pie = 0.15))
  expect_equal(coef(imd, "effects"),
               c(nde = 0.14, nie = 0.25, total = 0.39))
  expect_length(coef(imd, "all"), 4)
})

test_that("vcov and nobs return the stored slots", {
  imd <- make_interaction()
  expect_equal(dim(vcov(imd)), c(4, 4))
  expect_equal(nobs(imd), 200L)
})

# ==============================================================================
# Validator (structural + the implemented aggregate invariant)
# ==============================================================================

test_that("validator rejects components that do not sum to total_effect", {
  expect_error(
    make_interaction(total_effect = 0.99),   # stated total mismatches the sum
    "sum to total_effect"
  )
})

test_that("validator enforces the aggregate identities (NDE, NIE)", {
  expect_error(make_interaction(nde = 0.99), "nde must equal cde \\+ int_ref")
  expect_error(make_interaction(nie = 0.99), "nie must equal int_med \\+ pie")
})

test_that("validator enforces the path ties (the stronger checks)", {
  # cde tie: change c_prime so cde != c_prime + interaction*m_star.
  expect_error(make_interaction(c_prime = 0.5), "cde must equal c_prime")
  # int_med tie: change a_path so int_med != interaction*a_path (components fixed).
  expect_error(make_interaction(a_path = 0.9), "int_med must equal interaction")
  # pie tie: change b_path so pie != b_path*a_path.
  expect_error(make_interaction(b_path = 0.99), "pie must equal b_path")
})

test_that("validator rejects a non-square vcov", {
  expect_error(
    InteractionMediationData(
      a_path = 0.5, b_path = 0.3, c_prime = 0.1, interaction = 0.2,
      cde = 0.1, int_ref = 0.04, int_med = 0.10, pie = 0.15,
      nde = 0.14, nie = 0.25, total_effect = 0.39, m_star = 0,
      estimates = c(0.5, 0.3, 0.1, 0.2), vcov = matrix(0, 4, 3),
      treatment = "X", mediator = "M", outcome = "Y",
      mediator_predictors = "X", outcome_predictors = c("X", "M", "X:M"),
      n_obs = 200L, converged = TRUE, source_package = "medfit"
    ),
    "square"
  )
})

# ==============================================================================
# print and show
# ==============================================================================

test_that("print emits a readable summary", {
  imd <- make_interaction()
  out <- capture.output(print(imd))
  expect_true(any(grepl("InteractionMediationData", out)))
  expect_true(any(grepl("Four-way", out)))
  expect_true(any(grepl("CDE", out)))
})
