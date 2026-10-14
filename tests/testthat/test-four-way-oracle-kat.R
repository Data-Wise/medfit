# The known-answer generator (0.10.0 plan U8): true components from a, b, c', theta3, binary X and m_star, and the
# routes' estimates AND standard errors against the empirical SD over replications. The full gate is
# tests/sim/four-way-known-answer.R (1000 replications, 63 rows); these tests run it small.

skip_if_not_installed("lavaan")
skip_if_not_installed("sandwich")

test_that("the true components follow the VanderWeele formulas at the design's covariate mean", {
  truth <- fwo_kat_truth(a = 0.5, b = 0.4, cp = 0.2, theta3 = 0.6, b0 = 0.3)
  des <- fwo_kat_design(500, 3, "c1", FALSE)
  cbar <- mean(des$base$c1)
  tv <- fwo_kat_components(truth, des, m_star = 0.7)
  m_ref <- 0.3 + fwo_g[["c1"]] * cbar
  expect_equal(tv[["cde"]], 0.2 + 0.6 * 0.7)
  expect_equal(tv[["int_ref"]], 0.6 * (m_ref - 0.7))
  expect_equal(tv[["int_med"]], 0.6 * 0.5)
  expect_equal(tv[["pie"]], 0.4 * 0.5)
  expect_equal(tv[["nde"]], tv[["cde"]] + tv[["int_ref"]])
  expect_equal(tv[["nie"]], tv[["int_med"]] + tv[["pie"]])
  expect_equal(tv[["te"]], tv[["nde"]] + tv[["nie"]])
  # the no-covariate model reduces to INTref = theta3 (b0 - m_star)
  tv0 <- fwo_kat_components(truth, fwo_kat_design(500, 3, character(0), FALSE), m_star = 0.7)
  expect_equal(tv0[["int_ref"]], 0.6 * (0.3 - 0.7))
})

test_that("the design is fixed across replications; the draws differ; weights enter the truth", {
  truth <- fwo_kat_truth()
  des <- fwo_kat_design(400, 7, "c1", TRUE)
  expect_true(all(des$base$x %in% 0:1))
  expect_equal(sum(des$base$x), 200)
  d1 <- fwo_kat_draw(des, truth, 1)
  d2 <- fwo_kat_draw(des, truth, 2)
  expect_equal(d1$x, d2$x)
  expect_equal(d1$c1, d2$c1)
  expect_false(isTRUE(all.equal(d1$m, d2$m)))
  expect_equal(fwo_kat_draw(des, truth, 1), d1)
  plain <- des
  plain$w <- NULL
  expect_gt(abs(fwo_kat_components(truth, des)[["int_ref"]] - fwo_kat_components(truth, plain)[["int_ref"]]), 0.05)
})

test_that("known answers: hand oracle, glm route and lavaan route recover the truth and their own SEs", {
  truth <- fwo_kat_truth()
  routes <- list(
    unweighted = list(
      hand = fwo_route_hand("ml"),
      glm = function(d, covs, w, ms) fwo_route_glm(d, covs, w, ms),
      lavaan = function(d, covs, w, ms) fwo_route_lavaan(d, covs, w, ms)
    ),
    weighted = list(
      hand = fwo_route_hand("hc0_joint"),
      glm = function(d, covs, w, ms) fwo_route_glm(d, covs, w, ms, se_type = "sandwich"),
      lavaan = function(d, covs, w, ms) fwo_route_lavaan(d, covs, w, ms)
    )
  )
  for (wt in names(routes)) {
    des <- fwo_kat_design(400, if (wt == "weighted") 8 else 7, "c1", wt == "weighted")
    for (rt in names(routes[[wt]])) {
      reps <- if (rt == "lavaan") 120 else 300
      tol <- fwo_kat_tolerance(reps)
      r <- fwo_kat_run(routes[[wt]][[rt]], des, truth, 0.5, reps)
      expect_equal(r$reps_ok, rep(reps, 7), info = paste(wt, rt))
      expect_lt(max(abs(r$bias_z)), tol$z)
      expect_lt(max(abs(r$se_ratio - 1)), tol$se)
    }
  }
})

test_that("the known-answer tolerance shrinks with the number of replications and has a floor", {
  expect_gt(fwo_kat_tolerance(100)$se, fwo_kat_tolerance(1000)$se)
  expect_equal(fwo_kat_tolerance(1000)$se, 4 / sqrt(1998) + 0.03)
  expect_gt(fwo_kat_tolerance(1e6)$se, 0.03)
})

test_that("native route known answer: components and SEs through the `:` term, unweighted and weighted", {
  expect_true(fwo_native_available())
  truth <- fwo_kat_truth()
  for (wt in c(FALSE, TRUE)) {
    des <- fwo_kat_design(400, if (wt) 8 else 7, "c1", wt)
    reps <- 200
    se_type <- if (wt) "sandwich" else "model"
    r <- fwo_kat_run(function(d, covs, w, ms) fwo_route_native(d, covs, w, ms, se_type = se_type), des, truth, 0.5,
                     reps)
    tol <- fwo_kat_tolerance(reps)
    expect_equal(r$reps_ok, rep(reps, 7))
    expect_lt(max(abs(r$bias_z)), tol$z)
    expect_lt(max(abs(r$se_ratio - 1)), tol$se)
  }
})

test_that("planted: the known-answer rule fails the native route for dropped weights", {
  truth <- fwo_kat_truth()
  des <- fwo_kat_design(400, 8, "c1", TRUE)
  reps <- 200
  tol <- fwo_kat_tolerance(reps)
  # an unweighted native fit on weighted data (covariate-dependent weights) is biased for the weighted truth
  bad <- fwo_kat_run(function(d, covs, w, ms) fwo_route_native(d, covs, NULL, ms), des, truth, 0.3, reps)
  expect_failure(expect_lt(max(abs(bad$bias_z)), tol$z))
})
