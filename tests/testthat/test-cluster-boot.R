# Tests for the cluster bootstrap: bootstrap_mediation(cluster = )
#
# Kept in its own file so PR C does not conflict with PR B's additions to
# test-cluster-211.R. Uses the harness in helper-cluster.R.

# nolint start: object_usage_linter.
boot_data <- function(J = 12, size = 6, ...) {
  sim_cluster211(J = J, sizes = size, ...)$data
}
# nolint end

test_that("every cluster resample has J distinct ids (structural check)", {
  d <- boot_data()
  seen <- integer()
  stat <- function(x) {
    seen[length(seen) + 1L] <<- length(unique(x$cluster))
    mean(x$Y)
  }
  res <- bootstrap_mediation(stat, method = "nonparametric", data = d,
                             n_boot = 50L, seed = 1, cluster = "cluster")
  # One extra call computes the point estimate on the original data.
  expect_length(seen, 51L)
  expect_true(all(seen == 12L))
  expect_identical(res@n_boot, 50L)
})

test_that("a cluster drawn twice is relabeled as two clusters of the same size", {
  d <- boot_data(J = 5, size = 4)
  out <- medfit:::.relabel_clusters(d, "cluster", c("2", "2", "5", "1", "2"))
  expect_identical(nrow(out), 20L)
  expect_identical(nlevels(out$cluster), 5L)
  expect_identical(as.integer(table(out$cluster)), rep(4L, 5))
  # Draw 1 and draw 2 hold the same rows of original cluster 2.
  expect_equal(out$Y[out$cluster == "1"], out$Y[out$cluster == "2"])
  expect_equal(out$Y[out$cluster == "1"], d$Y[d$cluster == "2"])
  # Numeric and character cluster columns keep their type.
  dn <- d
  dn$cluster <- as.integer(dn$cluster)
  expect_type(medfit:::.relabel_clusters(dn, "cluster", c(1, 1, 3, 4, 5))$cluster, "integer")
  dc <- d
  dc$cluster <- as.character(dc$cluster)
  expect_type(medfit:::.relabel_clusters(dc, "cluster", c("1", "1", "3", "4", "5"))$cluster,
              "character")
})

test_that("cluster = needs the nonparametric method and a column of data", {
  d <- boot_data()
  stat <- function(x) mean(x$Y)
  expect_error(bootstrap_mediation(stat, method = "parametric", cluster = "cluster"),
               "needs method = \"nonparametric\"")
  expect_error(bootstrap_mediation(stat, method = "plugin", cluster = "cluster"),
               "needs method = \"nonparametric\"")
  expect_error(bootstrap_mediation(stat, method = "nonparametric", data = d,
                                   cluster = "school"),
               "cluster \\(must be in data\\)")
  expect_error(bootstrap_mediation(stat, method = "nonparametric", data = d,
                                   cluster = 1),
               "cluster")
})

test_that("cluster = NULL keeps the row bootstrap unchanged", {
  d <- boot_data()
  stat <- function(x) mean(x$Y)
  a <- bootstrap_mediation(stat, method = "nonparametric", data = d, n_boot = 40L,
                           seed = 7)
  b <- bootstrap_mediation(stat, method = "nonparametric", data = d, n_boot = 40L,
                           seed = 7, cluster = NULL)
  expect_identical(a@boot_estimates, b@boot_estimates)
  expect_identical(a@ci_lower, b@ci_lower)
})

test_that("failed refits are counted in the warning and excluded (D14)", {
  d <- boot_data()
  n <- 0L
  # Every third refit warns about convergence, and every fifth is singular.
  stat <- function(x) {
    n <<- n + 1L
    if (n %% 3L == 0L) warning("Model failed to converge")
    if (n %% 5L == 0L) message("boundary (singular) fit: see help('isSingular')")
    mean(x$Y)
  }
  expect_warning(
    res <- bootstrap_mediation(stat, method = "nonparametric", data = d,
                               n_boot = 60L, seed = 2, cluster = "cluster"),
    "bootstrap samples failed and were excluded \\([0-9]+ of them singular or non-convergent"
  )
  # 60 draws: 20 warn, 12 singular, 4 overlap -> 28 flagged, 32 kept.
  expect_identical(res@n_boot, 32L)
  expect_false(anyNA(res@boot_estimates))
})

test_that("a forced singular mixed-model fit is counted in the warning", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  # No cluster variance at all: many refits land on the boundary.
  d <- boot_data(J = 14, size = 4, tau_m = 0, tau_y = 0, seed = 3)
  d <- cluster_fit_data(d)
  stat <- function(x) {
    x <- cluster_fit_data(x)
    unname(lme4::fixef(lme4::lmer(Y ~ X + M_w + M_bar + (1 | cluster), data = x))["X"])
  }
  w <- NULL
  res <- withCallingHandlers(
    bootstrap_mediation(stat, method = "nonparametric", data = d, n_boot = 60L,
                        seed = 4, cluster = "cluster"),
    warning = function(cond) {
      w <<- conditionMessage(cond)
      invokeRestart("muffleWarning")
    }
  )
  expect_match(w, "\\([1-9][0-9]* of them singular or non-convergent")
  expect_lt(res@n_boot, 60L)
})

test_that("group 8: no relabeling breaks the structural check and shrinks the SE", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  nie_stat <- function(x) {
    unclass(nie(suppressWarnings(suppressMessages(fit_cluster211(x)))))[[1]]
  }
  # ICC of 0.5 in both the mediator and the outcome; a few datasets, because one
  # dataset's delta SE is itself noisy at J = 40.
  datasets <- lapply(101:103, function(k) {
    sim_cluster211(J = 40, sizes = 8, tau_m = 1, tau_y = 1, seed = k)$data
  })
  delta <- vapply(datasets, function(d) {
    unname(medfit:::.effect_se(fit_cluster211(d), "nie"))
  }, numeric(1))
  run <- function(k) {
    distinct <- integer()
    stat <- function(x) {
      distinct[length(distinct) + 1L] <<- length(unique(x$cluster))
      nie_stat(x)
    }
    res <- bootstrap_mediation(stat, method = "nonparametric", data = datasets[[k]],
                               n_boot = 100L, seed = k, cluster = "cluster")
    # The last call is the point estimate on the original data.
    list(distinct = distinct[-length(distinct)],
         ratio = stats::sd(res@boot_estimates) / delta[[k]])
  }

  good <- lapply(seq_along(datasets), run)
  expect_true(all(unlist(lapply(good, `[[`, "distinct")) == 40L))
  ratio_good <- vapply(good, `[[`, numeric(1), "ratio")
  expect_gt(mean(ratio_good), 0.85)
  expect_lt(mean(ratio_good), 1.15)

  # The defect: stack the drawn clusters without giving each draw a new id.
  local_mocked_bindings(.relabel_clusters = function(data, cluster, ids) {
    rows <- split(seq_len(nrow(data)), as.character(data[[cluster]]))
    data[unlist(rows[as.character(ids)], use.names = FALSE), , drop = FALSE]
  })
  bad <- lapply(seq_along(datasets), run)
  expect_false(all(unlist(lapply(bad, `[[`, "distinct")) == 40L))
  expect_lt(max(unlist(lapply(bad, `[[`, "distinct"))), 40L)
  ratio_bad <- vapply(bad, `[[`, numeric(1), "ratio")
  expect_lt(mean(ratio_bad), 0.9)
  expect_true(all(ratio_bad < ratio_good))
})
