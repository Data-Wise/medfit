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

# ==============================================================================
# Routing and guards (PLAN T3; spec test groups 6 and 8)
# ==============================================================================

# Serial data with an X x M2 product; `...` passes extra extract args.
joint_call <- function(d, m1 = M1 ~ X + C, m2 = M2 ~ X + M1 + C,
                       y = Y ~ X * M2 + M1 + C, ...) {
  extract_mediation(lm(m1, d), model_y = lm(y, d), treatment = "X",
                    mediator = c("M1", "M2"),
                    mediator_models = list(lm(m2, d)), ...)
}

test_that("supported outcome products route to the joint worker", {
  d <- sim_joint("serial", "M2", n = 300)$data
  expect_error(joint_call(d), class = "medfit_joint_not_implemented")
  dp <- sim_joint("parallel", "M1", n = 300)$data
  expect_error(joint_call(dp, m2 = M2 ~ X + C, y = Y ~ X * M1 + M2 + C),
               class = "medfit_joint_not_implemented")
  # Both mediators interacting, `:` spelling, and a supported m_star.
  expect_error(joint_call(d, y = Y ~ X + M1 + M2 + X:M1 + M2:X + C,
                          m_star = c(M1 = 1, M2 = 0)),
               class = "medfit_joint_not_implemented")
})

test_that("unsupported products still error, naming the term and model", {
  d <- sim_joint("serial", "M2", n = 300)$data
  d$C2 <- stats::rnorm(nrow(d))
  msg <- "Unsupported product term\\(s\\) found: "
  # Legal outcome product, illegal product in a mediator model.
  expect_error(joint_call(d, m2 = M2 ~ X * M1 + C), paste0(msg, "M2: X:M1"))
  expect_error(joint_call(d, y = Y ~ X * M2 + M1 * M2 + C), "Y: M(1:M2|2:M1)")
  expect_error(joint_call(d, y = Y ~ X * M1 * M2 + C), "Y: X:M1:M2")
  expect_error(joint_call(d, y = Y ~ X * M2 + M1 + X * C), "Y: X:C")
  expect_error(joint_call(d, y = Y ~ X * M2 + M1 + M1:C + C), "Y: M1:C")
  # Wrapped product (regression test for #74), next to a legal one.
  expect_error(joint_call(d, y = Y ~ X * M2 + M1 + I(X * M1) + C),
               "Y: I\\(X \\* M1\\)")
})

test_that("the joint branch refuses fits outside the closed form", {
  d <- sim_joint("serial", "M2", n = 300)$data
  pre <- "Joint mediation effects"
  expect_error(joint_call(d, decomposition = "two_way"),
               paste0(pre, ".*two_way"))
  expect_error(joint_call(d, vcov_fun = function(m) stats::vcov(m)),
               "non-default `vcov_fun`")
  expect_error(joint_call(d, structure = "parallel"),
               "structure = 'parallel' conflicts.*imply 'serial'")
  expect_error(joint_call(d, y = Y ~ X * M2 + C), "missing: M1")
  expect_error(joint_call(d, m1 = M1 ~ 0 + X + C), "M1 model has no intercept")
  dw <- d
  dw$w <- stats::runif(nrow(d), 0.5, 2)
  expect_error(
    extract_mediation(lm(M1 ~ X + C, dw),
                      model_y = lm(Y ~ X * M2 + M1 + C, dw, weights = w),
                      treatment = "X", mediator = c("M1", "M2"),
                      mediator_models = list(lm(M2 ~ X + M1 + C, dw))),
    "Y model is weighted"
  )
  dl <- d
  dl$Y <- dl$Y + 20
  expect_error(
    extract_mediation(lm(M1 ~ X + C, dl),
                      model_y = glm(Y ~ X * M2 + M1 + C, dl,
                                    family = gaussian(link = "log")),
                      treatment = "X", mediator = c("M1", "M2"),
                      mediator_models = list(lm(M2 ~ X + M1 + C, dl))),
    "family gaussian\\(link = \"log\"\\)"
  )
  df <- d
  df$X <- factor(ifelse(df$X == 1, "b", "a"))
  expect_error(joint_call(df), "treatment 'X' must be numeric and coded 0/1")
  # Same n, different rows.
  expect_error(
    extract_mediation(lm(M1 ~ X + C, d[-1, ]),
                      model_y = lm(Y ~ X * M2 + M1 + C, d[-1, ]),
                      treatment = "X", mediator = c("M1", "M2"),
                      mediator_models = list(lm(M2 ~ X + M1 + C, d[-2, ]))),
    "same rows"
  )
  # Reversed mediator order: M2's model regresses on M1, listed after it.
  expect_error(
    extract_mediation(lm(M2 ~ X + M1 + C, d), model_y = lm(Y ~ X * M2 + M1 + C, d),
                      treatment = "X", mediator = c("M2", "M1"),
                      mediator_models = list(lm(M1 ~ X + C, d))),
    "M2 model uses M1.*causal order"
  )
  d$C2 <- stats::rnorm(nrow(d))
  expect_error(joint_call(d, y = Y ~ X * M2 + M1 + C + C2),
               "same covariates; the Y and M1 models differ in: C2")
})

test_that("m_star on the joint branch follows the G3 naming rules", {
  d <- sim_joint("serial", "M2", n = 300)$data
  expect_error(joint_call(d, m_star = c(M1 = 1)),
               "without a treatment-by-mediator product: M1")
  expect_error(joint_call(d, m_star = c(1, 2)), "scalar or a vector named")
  expect_error(joint_call(d, y = Y ~ X * M1 + X * M2 + C, m_star = c(M2 = 1)),
               "must name every interacting mediator; missing: M1")
  expect_equal(.normalize_joint_m_star(2, c("M1", "M2"), TRUE),
               c(M1 = 2, M2 = 2))
  expect_equal(.normalize_joint_m_star(99, "M2", FALSE), c(M2 = 0))
  # No product: a supplied m_star is still refused.
  expect_error(joint_call(d, y = Y ~ X + M1 + M2 + C, m_star = 1),
               "applies only when")
})

test_that("no-product serial and parallel outputs are unchanged", {
  ds <- sim_joint("serial", "none", n = 400, seed = 21)$data
  s <- joint_call(ds, y = Y ~ X + M1 + M2 + C)
  dp <- sim_joint("parallel", "none", n = 400, seed = 22)$data
  p <- joint_call(dp, m2 = M2 ~ X + C, y = Y ~ X + M1 + M2 + C)
  expect_s3_class(s, "medfit::SerialMediationData")
  expect_s3_class(p, "medfit::ParallelMediationData")
  snap <- function(o) {
    lapply(list(estimates = o@estimates, vcov = o@vcov), signif, digits = 10)
  }
  expect_snapshot_value(list(serial = snap(s), parallel = snap(p)),
                        style = "deparse")
})
