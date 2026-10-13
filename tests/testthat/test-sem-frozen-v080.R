# Frozen v0.8.0 values for the native engine (0.9.0 mean-structure gate, T1 / G3).
#
# `fixtures/sem-v080-frozen.rds` was generated from the v0.8.0 tag, before the `has_mean` edits, by
# `planning/specs/evidence/native-mean-structure-2026-10-12/make-sem-v080-frozen.R`. With the mean
# structure off every value must be reproduced: F, gradient and expected information at the stored
# theta to 1e-12, observed information to 1e-9, refitted estimates and vcov to 1e-6. Three cases
# cover the plain, the weighted-sandwich (`.sem_scores`, `.sem_sample`) and the constrained path.

frozen <- readRDS(test_path("fixtures", "sem-v080-frozen.rds"))
frozen_cases <- setdiff(names(frozen), "r_version")

for (case in frozen_cases) {
  local({
    k <- frozen[[case]]

    test_that(paste0("frozen v0.8.0 evaluators are reproduced: ", case), {
      fit <- fit_sem(k$model, k$data, weights = k$weights, se_type = k$se_type)
      ram <- fit@internals$ram
      smp <- .sem_sample(fit@data, ram, fit@internals$weights)
      th <- k$theta
      expect_equal(.sem_fml(th, ram, smp), k$f, tolerance = 1e-12)
      expect_equal(.sem_grad(th, ram, smp), k$grad, tolerance = 1e-12)
      expect_equal(.sem_info_expected(th, ram, smp), k$info_expected, tolerance = 1e-12)
      expect_equal(.sem_info_observed(th, ram, smp), k$info_observed, tolerance = 1e-9)
    })

    test_that(paste0("frozen v0.8.0 fit is reproduced: ", case), {
      fit <- fit_sem(k$model, k$data, weights = k$weights, se_type = k$se_type)
      expect_equal(fit@theta, k$theta, tolerance = 1e-6)
      expect_equal(fit@vcov, k$vcov, tolerance = 1e-6)
    })
  })
}

test_that("the mean-structure flag is off in the RAM spec and the sample", {
  k <- frozen$observed
  fit <- fit_sem(k$model, k$data)
  ram <- fit@internals$ram
  expect_false(ram$has_mean)
  expect_false(.sem_sample(fit@data, ram)$has_mean)
})
