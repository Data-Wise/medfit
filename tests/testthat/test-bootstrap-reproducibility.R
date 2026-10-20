# A fixed seed gives the same nonparametric resamples for any ncores, in sequential runs and
# in the cluster bootstrap (#247). Resamples are drawn in the parent before dispatch.

slope_fn <- function(d) unname(stats::coef(stats::lm(y ~ x, data = d))[2L])
mean_fn <- function(d) mean(d$y)

boot_np <- function(parallel, ncores = NULL, cluster = NULL, fn = slope_fn, data = np_data, n_boot = 60) {
  bootstrap_mediation(statistic_fn = fn, method = "nonparametric", data = data, n_boot = n_boot,
                      parallel = parallel, ncores = ncores, cluster = cluster, seed = 11)@boot_estimates
}

np_data <- local({
  set.seed(1)
  x <- stats::rnorm(80)
  data.frame(x = x, y = 0.4 * x + stats::rnorm(80), g = rep(1:20, each = 4))
})

test_that("nonparametric resamples do not depend on ncores", {
  skip_on_os("windows")
  seq_est <- boot_np(FALSE)
  expect_identical(boot_np(TRUE, ncores = 1), seq_est)
  expect_identical(boot_np(TRUE, ncores = 2), seq_est)
  expect_identical(boot_np(TRUE, ncores = 3), seq_est)
})

test_that("sequential resamples keep the stream of the previous release", {
  # set.seed(s); then n_boot calls to sample.int(n, n, replace = TRUE), in order
  set.seed(11)
  manual <- vapply(seq_len(60), function(i) slope_fn(np_data[sample.int(80, 80, replace = TRUE), ]), numeric(1))
  expect_identical(boot_np(FALSE), manual)
})

test_that("cluster bootstrap resamples do not depend on ncores", {
  skip_on_os("windows")
  seq_est <- boot_np(FALSE, cluster = "g", fn = mean_fn)
  expect_identical(boot_np(TRUE, ncores = 2, cluster = "g", fn = mean_fn), seq_est)
  expect_identical(boot_np(TRUE, ncores = 3, cluster = "g", fn = mean_fn), seq_est)
})

test_that("the check can fail: drawing inside the workers breaks the equality", {
  skip_on_os("windows")
  # the old layout: each replicate draws its own resample inside mclapply()
  worker_draw <- function(ncores) {
    set.seed(11)
    unlist(parallel::mclapply(seq_len(60), function(i) {
      slope_fn(np_data[sample.int(80, 80, replace = TRUE), ])
    }, mc.cores = ncores))
  }
  expect_false(identical(worker_draw(2), worker_draw(1)))
})
