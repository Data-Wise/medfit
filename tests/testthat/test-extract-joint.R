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
  s <- joint_call(d)
  expect_true(S7::S7_inherits(s, JointMediationData))
  expect_identical(s@structure, "serial")
  expect_identical(s@interactions, "M2")
  dp <- sim_joint("parallel", "M1", n = 300)$data
  p <- joint_call(dp, m2 = M2 ~ X + C, y = Y ~ X * M1 + M2 + C)
  expect_identical(p@structure, "parallel")
  # Both mediators interacting, `:` spelling in either order, named m_star.
  b <- joint_call(d, y = Y ~ X + M1 + M2 + X:M1 + M2:X + C,
                  m_star = c(M2 = 0, M1 = 1))
  expect_identical(b@interactions, c("M1", "M2"))
  expect_equal(b@m_star, c(M1 = 1, M2 = 0))
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

# ==============================================================================
# Worker (PLAN T4; spec test group 4)
# ==============================================================================

test_that("propagated serial coefficients equal the reduced-form OLS fit", {
  d <- sim_joint("serial", "M2", n = 500, seed = 31)$data
  obj <- joint_call(d)
  direct <- stats::coef(lm(M2 ~ X + C, d))
  # OLS omitted-variable identity: exact with shared covariate sets.
  expect_equal(unname(obj@a_total[["M2"]]), unname(direct[["X"]]), tolerance = 1e-10)
  cm1 <- stats::coef(lm(M1 ~ X + C, d))
  cm2 <- stats::coef(lm(M2 ~ X + M1 + C, d))
  p <- .propagate_mediator_means(
    b0 = c(cm1[[1]], cm2[[1]]), b1 = c(cm1[["X"]], cm2[["X"]]),
    gamma = matrix(c(cm1[["C"]], cm2[["C"]]), 2, 1),
    d = matrix(c(0, cm2[["M1"]], 0, 0), 2, 2)
  )
  expect_equal(c(p$b0[2], p$b1[2], p$gamma[2, 1]),
               unname(direct[c("(Intercept)", "X", "C")]), tolerance = 1e-10)
})

test_that("serial and outcome cross-blocks of the stacked vcov are zero", {
  d <- sim_joint("serial", "M2", n = 500, seed = 32)$data
  v <- joint_call(d)@vcov
  blk <- function(a, b) v[startsWith(rownames(v), a), startsWith(colnames(v), b)]
  expect_lt(max(abs(blk("m1_", "m2_"))), 1e-10)
  expect_lt(max(abs(blk("m1_", "y_"))), 1e-10)
  expect_lt(max(abs(blk("m2_", "y_"))), 1e-10)
  # Diagonal blocks are each model's vcov().
  expect_equal(unname(blk("y_", "y_")),
               unname(stats::vcov(lm(Y ~ X * M2 + M1 + C, d))), tolerance = 1e-12)
  # Parallel mediators with correlated errors: the cross-block is not zero.
  dp <- sim_joint("parallel", "M1", n = 500, seed = 33, rho = 0.5)$data
  vp <- joint_call(dp, m2 = M2 ~ X + C, y = Y ~ X * M1 + M2 + C)@vcov
  expect_gt(abs(vp["m1_X", "m2_X"]), 1e-4)
  expect_equal(vp["a1", "a2"], vp["m1_X", "m2_X"])
})

test_that("estimates carry source rows and path aliases", {
  d <- sim_joint("serial", "M2", n = 300, seed = 34)$data
  obj <- joint_call(d)
  est <- obj@estimates
  expect_true(all(c("m1_(Intercept)", "m2_M1", "y_X:M2", "a1", "a2", "d21",
                    "b1", "b2", "theta3_M2", "c_prime") %in% names(est)))
  expect_identical(est[["d21"]], est[["m2_M1"]])
  expect_identical(est[["theta3_M2"]], est[["y_X:M2"]])
  expect_identical(rownames(obj@vcov), names(est))
})

test_that("K = 1 reduces to the four-way InteractionMediationData", {
  set.seed(35)
  n <- 400
  x <- stats::rbinom(n, 1, 0.5)
  cv <- stats::rnorm(n)
  m <- 0.4 + 0.5 * x + 0.3 * cv + stats::rnorm(n)
  y <- 0.1 + 0.2 * x + 0.3 * m + 0.25 * x * m + 0.2 * cv + stats::rnorm(n)
  d <- data.frame(X = x, C = cv, M = m, Y = y)
  fm <- lm(M ~ X + C, d)
  fy <- lm(Y ~ X * M + C, d)
  four <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M",
                            m_star = 0.5)
  joint <- .extract_joint_mediation_lm(list(fm), fy, "X", "M", "serial", "M",
                                       c(M = 0.5))
  expect_equal(joint@nie, four@nie, tolerance = 1e-10)
  expect_equal(joint@nde, four@nde, tolerance = 1e-10)
  expect_equal(joint@cde, four@cde, tolerance = 1e-10)
  expect_equal(unname(joint@vcov[c("a1", "b1", "theta3_M", "c_prime"),
                                 c("a1", "b1", "theta3_M", "c_prime")]),
               unname(four@vcov[c("a", "b", "theta3", "c_prime"),
                                c("a", "b", "theta3", "c_prime")]),
               tolerance = 1e-10)
})

# ==============================================================================
# Point-estimate oracles (PLAN T5; spec test groups 1, 2, 3, 8 and 9)
# ==============================================================================

joint_fixtures <- list(
  serial_M1 = c("serial", "M1"),
  serial_M2 = c("serial", "M2"),
  parallel_M1 = c("parallel", "M1")
)

# Oracle 1 (counterfactual truth, 3 SE), oracle 2 (g-computation, 4 Monte
# Carlo SEs), and the planted defects, which must fail both oracles.
check_joint_oracles <- function(n, truth_draws, gcomp_draws, seed) {
  out <- list()
  for (nm in names(joint_fixtures)) {
    f <- joint_fixtures[[nm]]
    sim <- sim_joint(f[1], f[2], n = n, seed = seed)
    fj <- fit_joint(sim$data, f[1], f[2])
    obj <- fj$obj
    est <- c(nde = obj@nde, nie = obj@nie, te = obj@total_effect)
    # The test-side re-implementation reproduces the object exactly, so the
    # planted defects below perturb a correct baseline.
    expect_equal(effects_from(obj, joint_effect_fn()), est, tolerance = 1e-10)

    truth <- true_joint_effects(sim, draws = truth_draws)
    se <- joint_mc_se(obj)
    for (e in names(est)) {
      expect_lt(abs(est[[e]] - truth[[e]]), 3 * se[[e]], label = paste(nm, e, "vs truth"))
    }
    expect_lt(abs(obj@cde - truth[["cde"]]), 3 * se[["cde"]], label = paste(nm, "cde"))
    g <- gcomp_joint(fj$models, sim$data, f[1], draws = gcomp_draws)
    mcse <- attr(g, "mcse")
    for (e in names(est)) {
      expect_lt(abs(est[[e]] - g[[e]]), 4 * mcse[[e]] + 1e-12,
                label = paste(nm, e, "vs g-computation"))
    }

    defects <- list(flip_theta3 = joint_effect_fn(flip_theta3 = TRUE))
    if (f[1] == "serial") defects$raw_b1 <- joint_effect_fn(raw_b1 = TRUE)
    for (dn in names(defects)) {
      bad <- effects_from(obj, defects[[dn]])
      expect_true(abs(bad[["nie"]] - truth[["nie"]]) > 3 * se[["nie"]],
                  label = paste(nm, dn, "caught by oracle 1"))
      expect_true(abs(bad[["nie"]] - g[["nie"]]) > 4 * mcse[["nie"]],
                  label = paste(nm, dn, "caught by oracle 2"))
    }
    out[[nm]] <- est
  }
  out
}

test_that("joint effects match the truth and g-computation (small n, always on)", {
  est <- check_joint_oracles(n = 5000, truth_draws = 2e5, gcomp_draws = 5e4, seed = 41)
  # Regression pins at the fixed seed.
  expect_equal(unlist(est), c(
    serial_M1.nde = 0.2057887549, serial_M1.nie = 0.5010109192, serial_M1.te = 0.7067996741,
    serial_M2.nde = 0.1947546533, serial_M2.nie = 0.4946574373, serial_M2.te = 0.6894120906,
    parallel_M1.nde = 0.2057887549, parallel_M1.nie = 0.4190438150, parallel_M1.te = 0.6248325699
  ), tolerance = 1e-8)
})

test_that("joint effects match the truth and g-computation (n = 20,000)", {
  skip_on_cran()
  check_joint_oracles(n = 20000, truth_draws = 1e6, gcomp_draws = 2e5, seed = 42)
})

test_that("without products the joint NIE is the all-paths sum (G1, group 3)", {
  # Parallel: the joint worker with no interactions reproduces
  # ParallelMediationData on the same fits.
  dp <- sim_joint("parallel", "none", n = 800, seed = 43)$data
  fp <- fit_joint(dp, "parallel", "none")
  jp <- .extract_joint_mediation_lm(unname(fp$models[c("m1", "m2")]), fp$models$y,
                                    "X", c("M1", "M2"), "parallel", character(0),
                                    stats::setNames(numeric(0), character(0)))
  expect_equal(jp@nie, unname(unclass(nie(fp$obj))[1]), tolerance = 1e-8)
  expect_equal(jp@nde, fp$obj@c_prime, tolerance = 1e-8)
  # Serial: the joint NIE counts every path and differs from the chain-only
  # a * d * b that SerialMediationData reports.
  ds <- sim_joint("serial", "none", n = 800, seed = 44)$data
  fs <- fit_joint(ds, "serial", "none")
  js <- .extract_joint_mediation_lm(unname(fs$models[c("m1", "m2")]), fs$models$y,
                                    "X", c("M1", "M2"), "serial", character(0),
                                    stats::setNames(numeric(0), character(0)))
  cf <- lapply(fs$models, stats::coef)
  all_paths <- cf$m1[["X"]] * cf$y[["M1"]] +
    (cf$m2[["X"]] + cf$m2[["M1"]] * cf$m1[["X"]]) * cf$y[["M2"]]
  chain <- unname(unclass(nie(fs$obj))[1])
  expect_equal(js@nie, all_paths, tolerance = 1e-10)
  expect_equal(chain, cf$m1[["X"]] * cf$m2[["M1"]] * cf$y[["M2"]], tolerance = 1e-10)
  expect_gt(abs(js@nie - chain), 0.05)
})

# ==============================================================================
# Gradients, SEs, generics, bootstrap (PLAN T6; spec test groups 5 and 8)
# ==============================================================================

test_that("analytic gradients match central differences for every effect", {
  cases <- list(
    serial_M1 = list(sim_joint("serial", "M1", n = 500, seed = 51)$data, "serial", "M1"),
    serial_M2 = list(sim_joint("serial", "M2", n = 500, seed = 52)$data, "serial", "M2"),
    parallel_M1 = list(sim_joint("parallel", "M1", n = 500, seed = 53)$data, "parallel", "M1")
  )
  for (nm in names(cases)) {
    cs <- cases[[nm]]
    obj <- fit_joint(cs[[1]], cs[[2]], cs[[3]], m_star = 0.7)$obj
    spec <- joint_spec(obj)
    est <- obj@estimates[spec$src]
    grads <- .effect_gradients(obj)
    h <- 1e-6
    for (e in c("nde", "nie", "te", "cde")) {
      num <- vapply(names(est), function(p) {
        up <- est
        dn <- est
        up[p] <- up[p] + h
        dn[p] <- dn[p] - h
        (joint_effects_est(up, spec)[[e]] - joint_effects_est(dn, spec)[[e]]) / (2 * h)
      }, numeric(1))
      ana <- stats::setNames(numeric(length(est)), names(est))
      ana[names(grads[[e]])] <- grads[[e]]
      expect_equal(ana, num, tolerance = 1e-6, label = paste(nm, e, "gradient"))
    }
  }
})

test_that("effect generics read the stored joint effects", {
  obj <- fit_joint(sim_joint("serial", "M2", n = 400, seed = 54)$data,
                   "serial", "M2")$obj
  expect_equal(unclass(nie(obj))[1], obj@nie, ignore_attr = TRUE)
  expect_equal(unclass(nde(obj))[1], obj@nde, ignore_attr = TRUE)
  expect_equal(unclass(te(obj))[1], obj@total_effect, ignore_attr = TRUE)
  expect_equal(unclass(pm(obj))[1], obj@nie / obj@total_effect, ignore_attr = TRUE)
  expect_equal(decompose(obj), c(cde = obj@cde, nde = obj@nde, nie = obj@nie,
                                 total = obj@total_effect))
  expect_named(paths(obj), c("a1", "a2", "b1", "b2", "theta3_M2", "c_prime", "d21"))
  # pm() warns and returns NA when the total effect is ~0.
  z <- make_joint_obj(a_total = c(M1 = 0, M2 = 0), c_prime = 0, cde = 0.2,
                      nde = 0, nie = 0, total_effect = 0)
  expect_warning(expect_true(is.na(pm(z))), "approximately zero")
})

test_that("plugin and parametric bootstraps accept JointMediationData", {
  obj <- fit_joint(sim_joint("serial", "M2", n = 400, seed = 55)$data,
                   "serial", "M2")$obj
  spec <- joint_spec(obj)
  stat <- function(theta) joint_effects_est(theta, spec)[["nie"]]
  plug <- bootstrap_mediation(stat, method = "plugin", mediation_data = obj)
  expect_equal(plug@estimate, obj@nie, tolerance = 1e-10)
  par <- bootstrap_mediation(stat, method = "parametric", mediation_data = obj,
                             n_boot = 200L, seed = 1)
  expect_equal(par@estimate, obj@nie, tolerance = 1e-10)
})

# Oracle 5: delta-method SEs against nonparametric bootstrap SDs, for serial
# and for parallel mediators with correlated errors (where the stacked-OLS
# cross-block matters).
se_fixtures <- list(
  serial_M2 = list("serial", "M2", 0),
  parallel_M1_rho = list("parallel", "M1", 0.5)
)

check_joint_se <- function(n, B, tol, seed) {
  for (nm in names(se_fixtures)) {
    f <- se_fixtures[[nm]]
    d <- sim_joint(f[[1]], f[[2]], n = n, seed = seed, rho = f[[3]])$data
    obj <- fit_joint(d, f[[1]], f[[2]])$obj
    delta <- .effect_se(obj, c("nde", "nie", "te"))
    boot <- boot_joint_se(
      d, function(dd) fit_joint(dd, f[[1]], f[[2]])$obj,
      function(o) c(nde = o@nde, nie = o@nie, te = o@total_effect),
      B = B, seed = seed
    )
    expect_equal(unname(delta), unname(boot[c("nde", "nie", "te")]),
                 tolerance = tol, label = paste(nm, "delta SE vs bootstrap"))
    if (f[[3]] > 0) {
      # Positive control: a block-diagonal vcov misses the correlation.
      src <- grep("^(m[0-9]+|y)_", rownames(obj@vcov), value = TRUE)
      bd <- obj@vcov[src, src]
      eq <- sub("_.*", "", src)
      bd[outer(eq, eq, "!=")] <- 0
      g <- .effect_gradients(obj)$nie
      se_bd <- sqrt(.gradient_var(g, bd))
      # The correlated cross-block moves the NIE SE (deterministic) ...
      expect_gt(abs(se_bd / delta[["nie"]] - 1), 0.03)
      # ... and at the strict tolerance, dropping it fails the bootstrap oracle.
      if (tol <= 0.03) expect_gt(abs(se_bd / boot[["nie"]] - 1), tol)
    }
  }
}

test_that("delta-method SEs agree with the bootstrap (always on, loose)", {
  check_joint_se(n = 800, B = 300, tol = 0.15, seed = 61)
})

test_that("delta-method SEs are within 3% of the bootstrap (B = 5000)", {
  skip_on_cran()
  check_joint_se(n = 1500, B = 5000, tol = 0.03, seed = 62)
})
