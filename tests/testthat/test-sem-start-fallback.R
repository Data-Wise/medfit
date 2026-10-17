# A start that lands every attempt in a bad basin must not end the fit when the model's own default start works
# (found by the reliability gate, tests/sim/sem-reliability.R: latent structure, n = 50, replicate 4, random start).
# The perturbed retries are drawn around the supplied start, so a bad start gives five bad attempts; the default
# start is now the last attempt (it replaces the fifth perturbation), reached only after the others failed.

latent_case <- function() {
  mod <- sem_models()[["latent"]]
  d <- sem_sim(mod, 50L, 100000L * 4L + 50L)
  smp <- .sem_sample(d, mod$ram)
  bad <- stats::setNames(
    c(-0.281003038623678, -0.185190417714988, -0.346372090895406, -0.17753822723853, -0.298466603458729,
      0.0862632735070528, 0.581120484020166, 1.79004163185541, 0.163125115857936, 0.0155421444153081,
      0.57536826440264),
    mod$ram$par_names
  )
  list(ram = mod$ram, smp = smp, bad = bad, default = .sem_default_start(mod$ram, smp))
}

test_that("a bad supplied start falls back to the default start instead of failing", {
  x <- latent_case()
  ref <- .sem_optimize(x$ram, x$smp, x$default)
  expect_true(ref$converged)
  expect_warning(fit <- .sem_optimize(x$ram, x$smp, x$bad), "the fit used the default start")
  expect_true(fit$converged)
  expect_equal(fit$f, ref$f, tolerance = 1e-8)
  expect_equal(unname(fit$theta), unname(ref$theta), tolerance = 1e-5)
  # the fallback is the last attempt: the supplied start and three perturbations failed, then the default start
  expect_equal(fit$retries, 4L)
})

test_that("the default start is not tried when an earlier start is accepted", {
  x <- latent_case()
  fit <- .sem_optimize(x$ram, x$smp, x$default)
  expect_equal(fit$retries, 0L)
})

test_that("a model with no valid start still reports the failure", {
  x <- latent_case()
  # a cap of one evaluation makes every attempt, the fallback included, stop at the maxeval status
  expect_error(
    .sem_optimize(x$ram, x$smp, x$bad, control = list(maxeval = 1L)),
    "no start converged \\(5 tried\\)"
  )
})
