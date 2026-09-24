# Self-tests for the joint-effects verification harness (helper-joint.R).
#
# The harness must be shown correct on cases whose answer medfit already knows
# (no product term) before any JointMediationData code relies on it
# (PLAN-joint-mediator-interactions-2026-09-23.md, T1).

test_that("true_joint_effects() gives the all-paths NIE with no product", {
  par <- joint_default_par()
  # Parallel: NIE = a1 b1 + a2 b2, exact (unit errors cancel in the contrast).
  sp <- sim_joint("parallel", "none", n = 10)
  tp <- true_joint_effects(sp, draws = 1e4)
  expect_equal(unname(tp["nie"]), par$a1 * par$b1 + par$a2 * par$b2,
               tolerance = 1e-10)
  expect_equal(unname(tp["nde"]), par$t1, tolerance = 1e-10)
  # Serial: every mediated path, a1 b1 + (a2 + d a1) b2, not just a1 d b2.
  ss <- sim_joint("serial", "none", n = 10)
  ts <- true_joint_effects(ss, draws = 1e4)
  expect_equal(unname(ts["nie"]),
               par$a1 * par$b1 + (par$a2 + par$d * par$a1) * par$b2,
               tolerance = 1e-10)
  expect_equal(unname(ts["te"]), unname(ts["nde"] + ts["nie"]))
})

test_that("true_joint_effects() tracks an X x M product through the chain", {
  par <- joint_default_par()
  t3 <- 0.3
  # Downstream product X:M2 in a serial chain: the NIE picks up t3 on the
  # propagated M2 effect (a2 + d a1), including the path through M1.
  s <- sim_joint("serial", "M2", n = 10, t3 = t3)
  tt <- true_joint_effects(s, draws = 1e4)
  expect_equal(unname(tt["nie"]),
               par$a1 * par$b1 + (par$a2 + par$d * par$a1) * (par$b2 + t3),
               tolerance = 1e-10)
  # CDE at m* = 0 is t1 (the product term vanishes at M2 = 0).
  expect_equal(unname(tt["cde"]), par$t1, tolerance = 1e-12)
  # NDE averages t3 * M2(0) over the population: t1 + t3 E[M2(0)], where
  # E[M2(0)] = b02 + d b01 (C has mean 0). Monte Carlo tolerance.
  expect_equal(unname(tt["nde"]),
               par$t1 + t3 * (par$b02 + par$d * par$b01), tolerance = 0.01)
})

test_that("gcomp_joint() reproduces the existing parallel NIE with no product", {
  s <- sim_joint("parallel", "none", n = 1500, seed = 3)
  fj <- fit_joint(s$data, "parallel", "none")
  expect_s3_class(fj$obj, "medfit::ParallelMediationData")
  g <- gcomp_joint(fj$models, s$data, "parallel", draws = 5e4)
  # No product: noise cancels per unit, so g-computation is exact.
  expect_equal(unname(g["nie"]), unname(unclass(nie(fj$obj))[1]),
               tolerance = 1e-8)
  expect_equal(unname(g["nde"]), unname(fj$obj@c_prime), tolerance = 1e-8)
})

test_that("gcomp_joint() gives the all-paths serial NIE with no product", {
  s <- sim_joint("serial", "none", n = 1500, seed = 4)
  fj <- fit_joint(s$data, "serial", "none")
  cf <- lapply(fj$models, stats::coef)
  all_paths <- cf$m1[["X"]] * cf$y[["M1"]] +
    (cf$m2[["X"]] + cf$m2[["M1"]] * cf$m1[["X"]]) * cf$y[["M2"]]
  g <- gcomp_joint(fj$models, s$data, "serial", draws = 5e4)
  expect_equal(unname(g["nie"]), all_paths, tolerance = 1e-8)
  # And it differs from the chain-only NIE the serial class reports (G1).
  expect_false(isTRUE(all.equal(unname(g["nie"]),
                                unname(unclass(nie(fj$obj))[1]))))
})

test_that("effects_from() routes through a planted-defect effect_fn", {
  s <- sim_joint("parallel", "none", n = 500, seed = 5)
  obj <- fit_joint(s$data, "parallel", "none")$obj
  good <- effects_from(obj)
  broken <- effects_from(obj, effect_fn = function(o) {
    e <- effects_from(o)
    e[["nie"]] <- -e[["nie"]]
    e
  })
  expect_named(good, c("nde", "nie", "te"))
  expect_equal(good[["nde"]], broken[["nde"]])
  expect_false(isTRUE(all.equal(good[["nie"]], broken[["nie"]])))
})

test_that("boot_joint_se() agrees with the delta-method SE on a no-product fit", {
  skip_on_cran()
  s <- sim_joint("parallel", "none", n = 1000, seed = 6)
  fit_fun <- function(d) fit_joint(d, "parallel", "none")$obj
  stat_fun <- function(o) c(nie = unname(unclass(nie(o))[1]))
  sd_boot <- boot_joint_se(s$data, fit_fun, stat_fun, B = 400)
  se_delta <- unname(.effect_se(fit_fun(s$data), "nie"))
  # Independent errors (rho = 0): block-diagonal delta SE is right; B = 400 gives
  # a Monte Carlo SE of about 3.5% on the SD, so allow 15%.
  expect_equal(unname(sd_boot[["nie"]]), se_delta, tolerance = 0.15)
})

test_that("canary: skip_on_cran() tests run on this platform", {
  # PLAN T0: if CI reports this test as skipped "On CRAN", the heavy
  # joint-effect oracles would be skipped there too.
  skip_on_cran()
  expect_true(TRUE)
})
