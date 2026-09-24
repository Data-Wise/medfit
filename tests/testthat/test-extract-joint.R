# JointMediationData and extract_mediation() joint effects (D8(b)).
# Spec: planning/specs/SPEC-joint-mediator-interactions-2026-09-23.md

# A valid hand-built parallel object with an X x M2 product; `...` overrides.
make_joint_obj <- function(...) {
  args <- list(
    structure = "parallel", mediators = c("M1", "M2"),
    treatment = "X", outcome = "Y", interactions = "M2",
    a_total = c(M1 = 0.5, M2 = 0.3), b_paths = c(M1 = 0.3, M2 = 0.4),
    theta3 = c(M2 = 0.2), c_prime = 0.1,
    cde = 0.1 + 0.2 * 1, nde = 0.12, nie = 0.33, total_effect = 0.45,
    m_star = c(M2 = 1),
    estimates = c(a1 = 0.5, a2 = 0.3, b1 = 0.3, b2 = 0.4,
                  theta3_M2 = 0.2, c_prime = 0.1),
    vcov = diag(0.01, 6),
    n_obs = 200L, converged = TRUE, source_package = "medfit"
  )
  args[names(list(...))] <- list(...)
  do.call(JointMediationData, args)
}

test_that("a consistent JointMediationData object builds and prints", {
  obj <- make_joint_obj()
  expect_true(S7::S7_inherits(obj, JointMediationData))
  expect_output(print(obj), "JointMediationData")
  expect_output(print(obj), "t3 = \\+0.2000 \\(m\\* = 1\\)")
  # No products: empty theta3 / m_star, CDE = NDE = c_prime.
  obj0 <- make_joint_obj(interactions = character(0),
                         theta3 = stats::setNames(numeric(0), character(0)),
                         m_star = stats::setNames(numeric(0), character(0)),
                         cde = 0.1, nde = 0.1, nie = 0.27, total_effect = 0.37)
  expect_equal(obj0@cde, obj0@c_prime)
})

test_that("the JointMediationData validator rejects inconsistent effects", {
  expect_error(make_joint_obj(total_effect = 0.5),
               "total_effect must equal nde \\+ nie")
  expect_error(make_joint_obj(nie = 0.30, total_effect = 0.42),
               "nie must equal sum")
  expect_error(make_joint_obj(cde = 0.1), "cde must equal theta1")
  expect_error(make_joint_obj(m_star = c(M1 = 1)),
               "m_star must be named by exactly the interacting mediators")
  expect_error(make_joint_obj(theta3 = c(M1 = 0.2)),
               "theta3 must be named by exactly the interacting mediators")
  expect_error(make_joint_obj(a_total = c(M2 = 0.3, M1 = 0.5)),
               "a_total must be named by mediators, in order")
  expect_error(make_joint_obj(structure = "tree"), "structure must be")
})

test_that("the validator tolerance is relative to the total effect", {
  # A 1e-9 absolute slip on a total of 1e3 is round-off, not an error.
  big <- 1e3
  expect_no_error(make_joint_obj(
    a_total = c(M1 = 0.5, M2 = 0.3) * big,
    nie = 0.33 * big, nde = 0.12, total_effect = 0.33 * big + 0.12 + 1e-9
  ))
})
