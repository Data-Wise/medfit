# Self-tests for the cluster-mediation verification harness (helper-cluster.R).
#
# The harness must be shown correct on cases whose answer is a closed form
# before any ClusterMediationData code relies on it
# (PLAN-multilevel-mediation-2-1-1-2026-10-08.md, T1). None of these tests
# needs lme4, so they also run in the noSuggests job.
#
# Not exercised here: fit_cluster211() (first use T6), te_oracle() (T9) and
# sim_gate() (T9); they call ClusterMediationData code from T2-T5.

test_that("CANARY: skip_on_cran() companions run on CI (T0)", {
  skip_on_cran()
  expect_true(TRUE)
})

test_that("sim_cluster211() returns the stated shape and is reproducible", {
  s <- sim_cluster211(J = 12, sizes = 5, seed = 4)
  expect_identical(nrow(s$data), 60L)
  expect_identical(nlevels(s$data$cluster), 12L)
  # Treatment is constant within clusters and both arms are present.
  expect_true(all(tapply(s$data$X, s$data$cluster, function(v) length(unique(v))) == 1L))
  expect_identical(sort(unique(s$data$X)), 0:1)
  expect_identical(s$data, sim_cluster211(J = 12, sizes = 5, seed = 4)$data)
  expect_false(identical(s$data$Y, sim_cluster211(J = 12, sizes = 5, seed = 5)$data$Y))
  # Unbalanced sizes are honored.
  u <- sim_cluster211(J = 4, sizes = c(2, 3, 5, 7), seed = 1)
  expect_identical(as.integer(table(u$data$cluster)), c(2L, 3L, 5L, 7L))
  expect_error(sim_cluster211(J = 4, sizes = c(2, 3)), "length 1 or J")
  expect_error(sim_cluster211(J = 3, sizes = c(1, 3, 4), process = "peer_mean"),
               "at least 2")
})

test_that("true_cluster_effects() matches the balanced closed forms exactly", {
  a <- 0.5
  bw <- 0.3
  bb <- 0.6
  cp <- 0.2
  nj <- 10
  s <- sim_cluster211(J = 40, sizes = nj, a = a, b_W = bw, b_B = bb,
                      c_prime = cp, seed = 2)
  tr <- true_cluster_effects(s)
  expect_equal(unname(tr["nie"]), a * bb, tolerance = 1e-10)
  expect_equal(unname(tr["nde"]), cp, tolerance = 1e-10)
  expect_equal(unname(tr["te"]), a * bb + cp, tolerance = 1e-10)
  # Own effect: a b_W + a (b_B - b_W) / n_j (D-own).
  expect_equal(unname(tr["own"]), a * bw + a * (bb - bw) / nj, tolerance = 1e-10)
  expect_equal(unname(tr["spillover"]), a * (bb - bw) * (1 - 1 / nj),
               tolerance = 1e-10)
})

test_that("true_cluster_effects() uses mean(1/n_j) for unbalanced clusters", {
  a <- 0.5
  bw <- 0.3
  bb <- 0.6
  sizes <- c(2, 3, 5, 8, 13, 4, 6, 10)
  s <- sim_cluster211(J = 8, sizes = sizes, a = a, b_W = bw, b_B = bb, seed = 3)
  tr <- true_cluster_effects(s)
  expect_equal(unname(tr["nie"]), a * bb, tolerance = 1e-10)
  expect_equal(unname(tr["own"]), a * bw + a * (bb - bw) * mean(1 / sizes),
               tolerance = 1e-10)
})

test_that("the peer-mean process has own effect a b_W whatever the cluster size", {
  a <- 0.5
  bw <- 0.3
  bb <- 0.6
  s <- sim_cluster211(J = 10, sizes = c(2, 3, 4, 5, 6, 7, 8, 9, 10, 2),
                      a = a, b_W = bw, b_B = bb, process = "peer_mean", seed = 6)
  tr <- true_cluster_effects(s)
  expect_equal(unname(tr["nie"]), a * bb, tolerance = 1e-10)
  expect_equal(unname(tr["own"]), a * bw, tolerance = 1e-10)
})

test_that("a planted wrong truth is caught by the closed-form check", {
  a <- 0.5
  bw <- 0.3
  bb <- 0.6
  nj <- 10
  s <- sim_cluster211(J = 40, sizes = nj, a = a, b_W = bw, b_B = bb, seed = 2)
  bad <- true_cluster_effects(s, defect = "own_fixed_mean")
  good_own <- a * bw + a * (bb - bw) / nj
  # Holding the cluster mean fixed drops the spillover share from the own effect.
  expect_equal(unname(bad["own"]), a * bw, tolerance = 1e-10)
  expect_gt(abs(unname(bad["own"]) - good_own), 1e-3)
  # The defect leaves NIE alone, so only the own/spillover split reveals it.
  expect_equal(unname(bad["nie"]), a * bb, tolerance = 1e-10)
})

test_that("each simulation option changes the data in the stated way", {
  base <- sim_cluster211(J = 20, sizes = 6, seed = 8)
  # slope_sd > 0 changes Y only; NIE stays exact, the own effect moves.
  sl <- sim_cluster211(J = 20, sizes = 6, slope_sd = 0.4, seed = 8)
  expect_identical(sl$data$M, base$data$M)
  expect_false(isTRUE(all.equal(sl$data$Y, base$data$Y)))
  expect_equal(unname(true_cluster_effects(sl)["nie"]),
               unname(true_cluster_effects(base)["nie"]), tolerance = 1e-10)
  expect_gt(abs(true_cluster_effects(sl)[["own"]] -
                  true_cluster_effects(base)[["own"]]), 1e-4)
  # process = "peer_mean" changes Y only.
  pm <- sim_cluster211(J = 20, sizes = 6, process = "peer_mean", seed = 8)
  expect_identical(pm$data$M, base$data$M)
  expect_false(isTRUE(all.equal(pm$data$Y, base$data$Y)))
  # cov: none has no C; centered has exactly zero cluster means; confounded
  # carries a between part.
  expect_false("C" %in% names(base$data))
  ce <- sim_cluster211(J = 20, sizes = 6, cov = "centered", seed = 8)
  expect_lt(max(abs(tapply(ce$data$C, ce$data$cluster, mean))), 1e-12)
  cf <- sim_cluster211(J = 20, sizes = 6, cov = "confounded", seed = 8)
  expect_gt(stats::sd(tapply(cf$data$C, cf$data$cluster, mean)), 0.3)
  expect_identical(attr(cf$data, "cov"), "confounded")
})

test_that("rho_vu correlates the random intercepts", {
  s <- sim_cluster211(J = 3000, sizes = 2, tau_m = 1, tau_y = 1, rho_vu = 0.6,
                      seed = 9)
  expect_equal(stats::cor(s$v, s$u), 0.6, tolerance = 0.05)
  expect_equal(stats::cor(sim_cluster211(J = 3000, sizes = 2, seed = 9)$v,
                          sim_cluster211(J = 3000, sizes = 2, seed = 9)$u),
               0, tolerance = 0.05)
})

test_that("effects_from(effect_fn = broken) changes the numbers", {
  d <- medfit::mediation_demo
  obj <- extract_mediation(
    stats::lm(mediator1 ~ treatment + covariate1 + covariate2, data = d),
    model_y = stats::lm(outcome ~ treatment + mediator1 + covariate1 + covariate2,
                        data = d),
    treatment = "treatment", mediator = "mediator1"
  )
  good <- effects_from(obj)
  # A planted defect: the NIE read as the a path alone.
  broken <- effects_from(obj, effect_fn = function(o) {
    c(nde = unclass(nde(o))[1], nie = unname(o@a_path), te = unclass(te(o))[1])
  })
  expect_false(isTRUE(all.equal(unname(good["nie"]), unname(broken["nie"]))))
  expect_length(good, 3L)
})

test_that("fit_cluster211() refuses the fit route and raw random slopes", {
  d <- sim_cluster211(J = 6, sizes = 4, seed = 1)$data
  expect_error(fit_cluster211(d, route = "fit"), "PR B")
  expect_error(fit_cluster211(d, parameterization = "raw", slope = TRUE),
               "within term only")
})
