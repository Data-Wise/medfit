# Tests for ClusterMediationData (2-1-1 cluster-level treatment mediation)
#
# T2 covers the class and its validator. The hand-built objects need no lme4,
# so these tests also run in the noSuggests job.

named_diag <- function(nms, v = 0.01) {
  m <- diag(v, length(nms))
  dimnames(m) <- list(nms, nms)
  m
}

cluster_fixture <- function(...) {
  est <- c(a = 0.5, c_prime = 0.2, b_within = 0.3, b_between = 0.6,
           `M:(Intercept)` = 0.1)
  args <- list(
    a_path = 0.5, b_within = 0.3, b_between = 0.6, c_prime = 0.2,
    estimates = est,
    vcov = named_diag(names(est)),
    treatment = "X", mediator = "M", outcome = "Y", cluster = "school",
    n_obs = 60L, n_clusters = 6L, cluster_sizes = rep(10L, 6),
    parameterization = "within", covariates_centered = TRUE,
    se_type = "model", reml = TRUE, converged = TRUE,
    sigma_m = 1, sigma_y = 1, tau_m = 0.5, tau_y = 0.5,
    source_package = "medfit"
  )
  do.call(ClusterMediationData, utils::modifyList(args, list(...)))
}

test_that("a valid ClusterMediationData builds and prints", {
  obj <- cluster_fixture()
  expect_true(S7::S7_inherits(obj, ClusterMediationData))
  expect_identical(obj@n_clusters, 6L)
  expect_length(obj@kr_df, 0L)
  # `data` has no explicit default: like the other classes it is an empty data frame
  expect_identical(nrow(obj@data), 0L)
  out <- utils::capture.output(print(obj))
  expect_match(out[1], "<ClusterMediationData>", fixed = TRUE)
  expect_match(paste(out, collapse = "\n"), "NIE (a * b_between) = +0.3000",
               fixed = TRUE)
  # show() goes through print() once the class is S4-registered in .onLoad().
  expect_identical(utils::capture.output(methods::show(obj)), out)
})

test_that("the raw parameterization and kr se_type build", {
  expect_no_error(cluster_fixture(parameterization = "raw"))
  expect_no_error(cluster_fixture(
    se_type = "kr",
    kr_df = c(a = 4, c_prime = 4, b_within = 40, b_between = 4.5)
  ))
})

test_that("the validator rejects each broken invariant with its message", {
  expect_error(cluster_fixture(a_path = c(0.5, 0.5)), "a_path must be a single")
  expect_error(cluster_fixture(tau_m = -1), "tau_m must be finite and non-negative")
  expect_error(cluster_fixture(sigma_y = Inf), "sigma_y must be finite")
  expect_error(cluster_fixture(parameterization = "centered"),
               "parameterization must be")
  expect_error(cluster_fixture(se_type = "sandwich"), "se_type must be")
  expect_error(cluster_fixture(n_clusters = 5L),
               "n_clusters must equal length\\(cluster_sizes\\)")
  expect_error(cluster_fixture(n_obs = 59L), "sum\\(cluster_sizes\\) must equal n_obs")
  expect_error(cluster_fixture(n_obs = 10L, n_clusters = 1L, cluster_sizes = 10L),
               "at least 2 clusters")
  expect_error(cluster_fixture(n_obs = 61L, cluster_sizes = c(11L, rep(10L, 5))),
               NA)
  expect_error(cluster_fixture(cluster_sizes = c(0L, 20L, rep(10L, 4)), n_obs = 60L),
               "at least 1")
})

test_that("alias rows must be present, named consistently and equal to the paths", {
  est <- c(a = 0.5, c_prime = 0.2, b_within = 0.3, b_between = 0.6)
  vc <- named_diag(names(est))
  # Missing alias row
  expect_error(cluster_fixture(estimates = est[-1], vcov = vc[-1, -1]),
               "alias rows a, c_prime, b_within and b_between")
  # A path property that disagrees with its alias row
  expect_error(cluster_fixture(estimates = est, vcov = vc, b_between = 0.61),
               "alias rows of estimates must equal the path properties")
  # vcov dimnames that do not match the estimate names
  bad <- vc
  dimnames(bad) <- list(rev(names(est)), rev(names(est)))
  expect_error(cluster_fixture(estimates = est, vcov = bad),
               "vcov dimnames must equal names")
  # Size mismatch and unnamed estimates
  expect_error(cluster_fixture(estimates = est, vcov = diag(0.01, 3)),
               "must match vcov dimensions")
  expect_error(cluster_fixture(estimates = unname(est), vcov = vc),
               "unique names")
})

test_that("kr_df is present exactly when se_type is kr, and kr needs REML", {
  df_ok <- c(a = 4, c_prime = 4, b_within = 40, b_between = 4.5)
  expect_error(cluster_fixture(se_type = "kr"), "kr_df must hold a positive df")
  expect_error(cluster_fixture(se_type = "kr", kr_df = df_ok[-1]),
               "kr_df must hold a positive df")
  expect_error(cluster_fixture(se_type = "kr", kr_df = c(df_ok[-1], a = -1)),
               "kr_df must hold a positive df")
  expect_error(cluster_fixture(se_type = "model", kr_df = df_ok),
               "kr_df must be empty unless")
  expect_error(cluster_fixture(se_type = "kr", kr_df = df_ok, reml = FALSE),
               "requires REML")
  # numeric(0) behaves like NULL for the model route (the class_numeric|NULL pitfall)
  expect_no_error(cluster_fixture(kr_df = numeric(0)))
})
