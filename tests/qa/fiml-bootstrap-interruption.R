# Zero-fit interruption regression: reuse the frozen independent matrix source.
devtools::load_all(quiet = TRUE)
workspace <- "_agents_workspace/fiml-bounded-inference"
saved <- readRDS(file.path(workspace, "qa-matrix.rds"))
fit <- saved$artifacts[["mar-free"]]$fit
set.seed(911L)
indices <- lapply(1:3, function(i) sample.int(fit@n_obs, fit@n_obs, replace = TRUE))
result <- testthat::test_that("public interrupted intervals retain every ID and withhold every accessor", {
  for (use_parallel in c(FALSE, TRUE)) {
    out <- testthat::with_mocked_bindings(
      bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 3L,
                          seed = 911L, parallel = use_parallel, ncores = 2L),
      .bootstrap_fiml_refit = function(source, rows) {
        if (identical(rows, indices[[2]])) {
          stop(structure(list(message = "synthetic interrupt", call = NULL), class = c("interrupt", "condition")))
        }
        fit
      }, .package = "medfit"
    )
    testthat::expect_identical(out@n_boot, 3L)
    testthat::expect_identical(out@inference$status, "incomplete")
    testthat::expect_identical(out@inference$interrupted, 1L)
    testthat::expect_identical(out@inference$unattempted, 1L)
    testthat::expect_identical(is.na(out@boot_estimates), c(FALSE, TRUE, TRUE))
    testthat::expect_identical(out@inference$replicates[[3]]$rows, indices[[3]])
    testthat::expect_identical(vapply(out@inference$replicates, `[[`, integer(1), "id"), 1:3)
    testthat::expect_identical(vapply(out@inference$replicates, `[[`, character(1), "status"),
                               c("accepted", "interrupted", "unattempted"))
    out@ci_lower <- -1
    out@ci_upper <- 1
    for (level in c(.01, .5, .8, .95, .99)) testthat::expect_true(all(is.na(confint(out, level = level))))
    testthat::expect_true(all(is.na(tidy(out)[c("std_error", "conf_low", "conf_high")])))
    testthat::expect_true(all(is.na(summary(out)$ci)))
    testthat::expect_output(print(out), "incomplete")
    testthat::expect_output(show(out), "Lower: +NA")
  }
  args <- list(source_fit = fit, effect = "te", method = "parametric", n_boot = 8L, seed = 123L)
  sequential <- do.call(bootstrap_mediation, args)
  parallel <- do.call(bootstrap_mediation, c(args, list(parallel = TRUE, ncores = 2L)))
  testthat::expect_identical(parallel@boot_estimates, sequential@boot_estimates)
  testthat::expect_identical(c(parallel@ci_lower, parallel@ci_upper), c(sequential@ci_lower, sequential@ci_upper))
})
saveRDS(result, file.path(workspace, "interruption-public.rds"))
