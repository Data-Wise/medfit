# Native SEM engine: compatibility gate for probmed (S17b; downstream contract in
# the plan, S17). probmed stays out of DESCRIPTION: it is a downstream package, so
# the file skips when probmed is not installed and the release gate runs it with
# probmed in a scratch library.
# Oracles: the lavaan route and the glm route on the same data. Planted defects:
# one alias row dropped (the contract pre-check must fail with its message) and
# `y_M` swapped with `y_X` (the plugin agreement must fail).

probmed_data <- function(n = 500, seed = 3) {
  # helper-defined functions are looked up by name: CI lint does not source the helper files
  match.fun("sem_sim")(match.fun("sem_model_observed")(), n, seed)[, c("X", "M", "Y")]
}

probmed_syntax <- "M ~ X\nY ~ M + X"

# What probmed resolves by name in @estimates and @vcov (plan S17, downstream contract). Returns the
# problems found, so the pre-check and its planted defect share one function.
contract_problems <- function(med) {
  need <- c("m_X", "y_M", "y_X")
  msg <- paste0(
    "native extraction no longer carries `m_<X>`/`y_<M>`/`y_<X>` names that probmed resolves by name; ",
    "see the S17 downstream contract"
  )
  missing_est <- setdiff(need, names(med@estimates))
  missing_vc <- setdiff(need, intersect(rownames(med@vcov), colnames(med@vcov)))
  if (length(missing_est) || length(missing_vc)) msg else character()
}

skip_unless_probmed <- function() {
  testthat::skip_if_not_installed("probmed")
  testthat::skip_if_not_installed("lavaan")
}

test_that("contract pre-check: the native MediationData carries the names probmed resolves", {
  skip_unless_probmed()
  nat <- extract_mediation(fit_sem(probmed_syntax, probmed_data()), "X", "M")
  expect_identical(contract_problems(nat), character())
  expect_s7_class(nat, MediationData)
  expect_true(all(c("a_path", "b_path", "c_prime", "sigma_m", "sigma_y", "family_m", "family_y", "data") %in%
                    S7::prop_names(nat)))
  expect_false(is.null(nat@data))
  expect_identical(nat@source_package, "medfit")
})

test_that("planted defect: a dropped alias row fails the contract pre-check with its message", {
  skip_unless_probmed()
  nat <- extract_mediation(fit_sem(probmed_syntax, probmed_data()), "X", "M")
  keep <- setdiff(names(nat@estimates), "y_M")
  broken <- S7::set_props(nat, estimates = nat@estimates[keep], vcov = nat@vcov[keep, keep])
  expect_match(contract_problems(broken), "`m_<X>`/`y_<M>`/`y_<X>` names that probmed resolves by name")
})

test_that("pmed plugin on the native route equals the lavaan route at the same seed", {
  skip_unless_probmed()
  dat <- probmed_data()
  nat <- extract_mediation(fit_sem(probmed_syntax, dat), "X", "M")
  lav <- extract_mediation(
    suppressWarnings(lavaan::sem(probmed_syntax, dat, fixed.x = FALSE, information = "observed")), "X", "M"
  )
  set.seed(1)
  pn <- probmed::pmed(nat, method = "plugin", n_sim = 5000L)
  set.seed(1)
  pl <- probmed::pmed(lav, method = "plugin", n_sim = 5000L)
  expect_equal(pn@estimate, pl@estimate, tolerance = 1e-6)
})

test_that("planted defect: swapping y_M and y_X (by name) breaks the bootstrap agreement", {
  skip_unless_probmed()
  dat <- probmed_data()
  nat <- extract_mediation(fit_sem(probmed_syntax, dat), "X", "M")
  glm <- fit_mediation(Y ~ X + M, M ~ X, dat, "X", "M")
  # swap the two names in @estimates and @vcov; the parametric bootstrap resolves them by name
  swap <- function(v) {
    v[v == "y_M"] <- "tmp"
    v[v == "y_X"] <- "y_M"
    v[v == "tmp"] <- "y_X"
    v
  }
  est <- nat@estimates
  names(est) <- swap(names(est))
  vc <- nat@vcov
  dimnames(vc) <- list(swap(rownames(vc)), swap(colnames(vc)))
  swapped <- S7::set_props(nat, estimates = est, vcov = vc)
  set.seed(2)
  bad <- probmed::pmed(swapped, method = "parametric_bootstrap", n_boot = 400L, n_sim = 2000L)
  set.seed(2)
  ref <- probmed::pmed(glm, method = "parametric_bootstrap", n_boot = 400L, n_sim = 2000L)
  expect_gt(abs(bad@estimate - ref@estimate), 0.02)
})

test_that("the native route differs from the glm route only by the residual-variance divisor", {
  skip_unless_probmed()
  dat <- probmed_data()
  n <- nrow(dat)
  nat <- extract_mediation(fit_sem(probmed_syntax, dat), "X", "M")
  glm <- fit_mediation(Y ~ X + M, M ~ X, dat, "X", "M")
  expect_equal(glm@sigma_m / nat@sigma_m, sqrt(n / (n - 2)), tolerance = 1e-6)
  expect_equal(glm@sigma_y / nat@sigma_y, sqrt(n / (n - 3)), tolerance = 1e-6)
  expect_equal(c(nat@a_path, nat@b_path, nat@c_prime), c(glm@a_path, glm@b_path, glm@c_prime), tolerance = 1e-6)
})

test_that("pmed parametric bootstrap runs on the native route and agrees with glm within Monte Carlo error", {
  skip_unless_probmed()
  dat <- probmed_data()
  nat <- extract_mediation(fit_sem(probmed_syntax, dat), "X", "M")
  glm <- fit_mediation(Y ~ X + M, M ~ X, dat, "X", "M")
  set.seed(2)
  bn <- probmed::pmed(nat, method = "parametric_bootstrap", n_boot = 400L, n_sim = 2000L)
  set.seed(2)
  bg <- probmed::pmed(glm, method = "parametric_bootstrap", n_boot = 400L, n_sim = 2000L)
  # measured gaps at this seed: estimate 5e-4, bounds 5e-4 and 2.6e-3
  expect_lt(abs(bn@estimate - bg@estimate), 0.02)
  expect_lt(abs(bn@ci_lower - bg@ci_lower), 0.02)
  expect_lt(abs(bn@ci_upper - bg@ci_upper), 0.02)
})

test_that("a latent mediator extracts and plugs in, but its nonparametric bootstrap is expected to fail", {
  skip_unless_probmed()
  dat <- sem_sim(sem_model_latent(), n = 400, seed = 3)
  lat <- extract_mediation(
    fit_sem("eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X", dat), treatment = "X", mediator = "eta"
  )
  expect_s7_class(lat, MediationData)
  set.seed(1)
  plug <- probmed::pmed(lat, method = "plugin", n_sim = 2000L)
  expect_true(is.finite(plug@estimate))
  # probmed refits glm from @data, and a latent mediator is not a column; asserted so a silent change is noticed
  expect_error(
    probmed::pmed(lat, method = "nonparametric_bootstrap", n_boot = 20L, n_sim = 500L),
    "eta"
  )
})
