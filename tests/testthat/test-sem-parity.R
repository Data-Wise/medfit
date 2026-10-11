# Native SEM engine: parity with OpenMx (S19, J2/J7).
# Oracles: OpenMx fitted to S * n / (n - 1) with numObs = n (estimates to 1e-6, standard
# errors to the frozen K10 tolerance of 1e-3), and the MBCO known answers on RMediation's
# `memory_exp` (OpenMx diffLL 221.045546 and 0.083100 [scratch run, 2026-10-09]).
# Constrained cells use an OpenMx model without mxConstraint (shared label, fixed value),
# the active bound uses OpenMx's own lbound for the estimates and the fixed-at-bound model
# for the standard errors, because OpenMx's SE at an active bound ignores the bound.
# Planted defects: wrong likelihood-ratio multipliers, and the nonlinear solve's 221.05
# taken in place of the minimum, must miss the known answers.

parity_syntax <- c(
  observed = "M ~ X + C\nY ~ M + X + C",
  latent = "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X",
  parallel = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2",
  serial = "M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + M1 + X"
)

# Estimates of an OpenMx fit and their standard errors, named by the engine's parameter names.
parity_openmx <- function(om, mod) {
  sm <- summary(om)$parameters
  nm <- mod$ram$par_names[as.integer(sub("^p", "", sm$name))]
  list(est = stats::setNames(sm$Estimate, nm), se = stats::setNames(sm[["Std.Error"]], nm))
}

# Maximum absolute estimate gap and maximum relative SE gap between a native fit and an oracle,
# over the native names in `map` (native name -> oracle name), skipping SEs of pinned parameters.
parity_gap <- function(fit, oracle, map = NULL, no_se = character()) {
  native <- names(fit@theta)
  to <- if (is.null(map)) native else unname(map[native])
  se_n <- sqrt(diag(fit@vcov))
  keep <- !(native %in% no_se)
  list(
    est = max(abs(fit@theta - oracle$est[to])),
    se = max(abs(se_n[keep] / oracle$se[to[keep]] - 1))
  )
}

test_that("estimates and standard errors match OpenMx on the four K10 structures", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  mods <- sem_models()
  for (nm in names(parity_syntax)) {
    dat <- sem_sim(mods[[nm]], n = 500, seed = 3)
    fit <- fit_sem(parity_syntax[[nm]], dat)
    om <- parity_openmx(sem_openmx(mods[[nm]], .sem_sample(dat, mods[[nm]]$ram)), mods[[nm]])
    gap <- parity_gap(fit, om)
    expect_lt(gap$est, 1e-6, label = nm)
    expect_lt(gap$se, 1e-3, label = nm)
  }
})

test_that("a == b matches OpenMx with one shared label", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  mod <- sem_model_equal_paths()
  dat <- sem_sim(mod, n = 200, seed = 5)
  fit <- fit_sem("M ~ a*X\nY ~ b*M + cp*X\na == b", dat)
  om <- parity_openmx(sem_openmx(mod, .sem_sample(dat, mod$ram)), mod)
  map <- c(a = "a", b = "a", cp = "Y ~ X", `M ~~ M` = "M ~~ M", `Y ~~ Y` = "Y ~~ Y", `X ~~ X` = "X ~~ X")
  gap <- parity_gap(fit, om, map)
  expect_lt(gap$est, 1e-6)
  expect_lt(gap$se, 1e-3)
})

test_that("a == 0 matches the OpenMx model with the path fixed at zero", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  mod <- sem_model_zero_path()
  dat <- sem_sim(mod, n = 200, seed = 5)
  fit <- fit_sem("M ~ a*X\nY ~ b*M + cp*X\na == 0", dat)
  om <- parity_openmx(sem_openmx(mod, .sem_sample(dat, mod$ram)), mod)
  map <- c(a = NA, b = "Y ~ M", cp = "Y ~ X", `M ~~ M` = "M ~~ M", `Y ~~ Y` = "Y ~~ Y", `X ~~ X` = "X ~~ X")
  free <- setdiff(names(fit@theta), "a")
  fit_free <- list(theta = fit@theta[free], vcov = fit@vcov[free, free])
  est <- max(abs(fit_free$theta - om$est[map[free]]))
  se <- max(abs(sqrt(diag(fit_free$vcov)) / om$se[map[free]] - 1))
  expect_lt(est, 1e-6)
  expect_lt(se, 1e-3)
  expect_identical(fit@theta[["a"]], 0)
})

test_that("an active lower bound matches OpenMx's lbound and the fixed-at-bound standard errors", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  mod <- sem_model_heywood()
  dat <- sem_sim(mod, n = 50, seed = 10)
  fit <- fit_sem("eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X\nm1 ~~ lower(0)*m1", dat)
  expect_identical(fit@diagnostics$active_bounds, "m1 ~~ m1")
  om <- parity_openmx(
    sem_openmx(mod, .sem_sample(dat, mod$ram), lbound = c(`m1 ~~ m1` = 0)), mod
  )
  expect_lt(max(abs(fit@theta - om$est[names(fit@theta)])), 1e-6)
  # OpenMx's SE ignores the bound, so the oracle for the SEs is the model with the variance fixed at 0
  fixed <- mod
  fixed$s$value[fixed$s$row == "m1" & fixed$s$col == "m1"] <- 0
  fixed <- sem_model(fixed$ram$vars, fixed$ram$obs, fixed$a, fixed$s, mod$theta[setdiff(names(mod$theta), "m1 ~~ m1")],
                     latent = "eta", loadings = mod$loadings)
  omf <- parity_openmx(sem_openmx(fixed, .sem_sample(dat, fixed$ram)), fixed)
  rest <- setdiff(names(fit@theta), "m1 ~~ m1")
  expect_lt(max(abs(sqrt(diag(fit@vcov))[rest] / omf$se[rest] - 1)), 1e-3)
  expect_identical(unname(sqrt(diag(fit@vcov))[["m1 ~~ m1"]]), 0)
})

# --- always-on companions: the native values pinned to 1e-6 (relative), so the noSuggests job still checks them ---

pinned <- list(
  observed = c(`M ~ X` = 0.380333284, `M ~ C` = 0.355324784, `Y ~ M` = 0.494495842, `Y ~ X` = 0.26224622,
               `Y ~ C` = 0.0671801071, `M ~~ M` = 0.784533788, `Y ~~ Y` = 0.697089383, `X ~~ X` = 1.06174226,
               `X ~~ C` = 0.230629541, `C ~~ C` = 1.06881152),
  latent = c(`m2 ~ eta` = 0.861127383, `m3 ~ eta` = 0.714641858, `eta ~ X` = 0.42224048, `Y ~ eta` = 0.393299806,
             `Y ~ X` = 0.197604671, `m1 ~~ m1` = 0.457043716, `m2 ~~ m2` = 0.580161362, `m3 ~~ m3` = 0.713679558,
             `Y ~~ Y` = 0.806446327, `eta ~~ eta` = 0.81442999, `X ~~ X` = 1.06174225),
  parallel = c(`M1 ~ X` = 0.429721998, `M2 ~ X` = 0.37454591, `Y ~ M1` = 0.260730646, `Y ~ M2` = 0.394660187,
               `Y ~ X` = 0.271473817, `M1 ~~ M2` = 0.23287186, `M1 ~~ M1` = 0.734208739, `M2 ~~ M2` = 0.907428041,
               `Y ~~ Y` = 0.697089381, `X ~~ X` = 1.06174226),
  serial = c(`M1 ~ X` = 0.429721996, `M2 ~ M1` = 0.469121395, `M2 ~ X` = 0.0621838384, `Y ~ M2` = 0.294810633,
             `Y ~ M1` = 0.0614714399, `Y ~ X` = 0.270524304, `M1 ~~ M1` = 0.734208741, `M2 ~~ M2` = 0.882600521,
             `Y ~~ Y` = 0.697089384, `X ~~ X` = 1.06174226)
)

test_that("the native estimates on the K10 structures are pinned (no oracle needed)", {
  mods <- sem_models()
  for (nm in names(pinned)) {
    fit <- fit_sem(parity_syntax[[nm]], sem_sim(mods[[nm]], n = 500, seed = 3))
    expect_equal(fit@theta[names(pinned[[nm]])], pinned[[nm]], tolerance = 1e-6, info = nm)
  }
})

test_that("the native estimates on the constrained and bounded cells are pinned", {
  eq <- fit_sem("M ~ a*X\nY ~ b*M + cp*X\na == b", sem_sim(sem_model_equal_paths(), n = 200, seed = 5))
  expect_equal(eq@theta, c(a = 0.456148376, b = 0.456148376, cp = 0.102963365, `M ~~ M` = 0.808260265,
                           `Y ~~ Y` = 0.692207122, `X ~~ X` = 0.98415528), tolerance = 1e-6)
  zero <- fit_sem("M ~ a*X\nY ~ b*M + cp*X\na == 0", sem_sim(sem_model_zero_path(), n = 200, seed = 5))
  expect_equal(zero@theta, c(a = 0, b = 0.461302662, cp = 0.125158791, `M ~~ M` = 0.810816705,
                             `Y ~~ Y` = 0.692185645, `X ~~ X` = 0.984155281), tolerance = 1e-6)
  bnd <- fit_sem("eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X\nm1 ~~ lower(0)*m1",
                 sem_sim(sem_model_heywood(), n = 50, seed = 10))
  expect_equal(bnd@theta, c(`m2 ~ eta` = 0.746182488, `m3 ~ eta` = 0.535619673, `eta ~ X` = 0.549041196,
                            `Y ~ eta` = 0.36041097, `Y ~ X` = 0.2013694, `m1 ~~ m1` = 0, `m2 ~~ m2` = 0.120495486,
                            `m3 ~~ m3` = 0.589188838, `Y ~~ Y` = 0.656149018, `eta ~~ eta` = 0.886139213,
                            `X ~~ X` = 0.735648723), tolerance = 1e-6)
})

# --- MBCO known answers on memory_exp (J2) ---

memory_exp_data <- function() {
  path <- testthat::test_path("fixtures", "memory_exp.rds")
  if (!file.exists(path)) testthat::skip("tests/testthat/fixtures/memory_exp.rds is not present")
  readRDS(path)
}

mem_syntax <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
# The Rd example of RMediation::mbco() as written: its labels are shifted (x -> repetition is a2,
# x -> imagery is cp, x -> recall is a1), so `a1 == 0` constrains the direct path.
mem_syntax_shifted <- "repetition ~ a2*x\nimagery ~ cp*x\nrecall ~ a1*x + b1*repetition + b2*imagery"

# n * (F_constrained - F_full): twice the log-likelihood difference with the means free.
mem_stat <- function(syntax, constraint, data, n_mult = nrow(data)) {
  full <- fit_sem(syntax, data)
  con <- fit_sem(paste0(syntax, "\n", constraint), data)
  n_mult * (con@f - full@f)
}

test_that("MBCO known answer: n * dF equals OpenMx diffLL and the statistic is the minimum", {
  d <- memory_exp_data()
  a1 <- mem_stat(mem_syntax, "a1 == 0", d)
  b1 <- mem_stat(mem_syntax, "b1 == 0", d)
  # The references are OpenMx's six printed decimals, so the rule is an absolute 1e-6 (measured 3e-8 and 4e-7).
  expect_lt(abs(a1 - 221.045546), 1e-6)
  expect_lt(abs(b1 - 0.083100), 1e-6)
  expect_lt(abs(min(a1, b1) - 0.083100), 1e-6)
})

test_that("MBCO as written in the RMediation example (shifted labels) equals mxCompare's 0.060332", {
  d <- memory_exp_data()
  stat <- min(mem_stat(mem_syntax_shifted, "a1 == 0", d), mem_stat(mem_syntax_shifted, "b1 == 0", d))
  expect_lt(abs(stat - 0.060332), 1e-6)
})

test_that("planted defects: wrong multipliers and the nonlinear solve's diffLL miss the known answers", {
  d <- memory_exp_data()
  n <- nrow(d)
  b1_true <- 0.083100
  expect_gt(abs(mem_stat(mem_syntax, "b1 == 0", d, n - 1) - b1_true), 1e-6)
  expect_gt(abs(mem_stat(mem_syntax, "b1 == 0", d, 2 * n) - b1_true), 1e-6)
  # OpenMx's nonlinear a1*b1 == 0 solve lands at a1 = 0 (221.05); taking it instead of the minimum fails
  expect_gt(abs(221.045546 - b1_true), 1e-6)
  a1 <- mem_stat(mem_syntax, "a1 == 0", d)
  expect_gt(abs(a1 - min(a1, mem_stat(mem_syntax, "b1 == 0", d))), 1)
})

test_that("native estimates on memory_exp match OpenMx", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  d <- memory_exp_data()
  mod <- sem_model(
    vars = c("x", "repetition", "imagery", "recall"), obs = c("x", "repetition", "imagery", "recall"),
    a = sem_rows(list("repetition", "x", "a1"), list("imagery", "x", "a2"), list("recall", "x", "cp"),
                 list("recall", "repetition", "b1"), list("recall", "imagery", "b2")),
    s = sem_rows(list("x", "x"), list("repetition", "repetition"), list("imagery", "imagery"),
                 list("recall", "recall")),
    theta = c(a1 = 0, a2 = 0, cp = 0, b1 = 0, b2 = 0, `x ~~ x` = 1, `repetition ~~ repetition` = 1,
              `imagery ~~ imagery` = 1, `recall ~~ recall` = 1)
  )
  fit <- fit_sem(mem_syntax, d)
  om <- parity_openmx(sem_openmx(mod, .sem_sample(d, mod$ram)), mod)
  gap <- parity_gap(fit, om)
  expect_lt(gap$est, 1e-6)
  expect_lt(gap$se, 1e-3)
})
