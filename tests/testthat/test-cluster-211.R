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


# T3: routing and design guards (test group 6) ---------------------------------
# These need lme4; the noSuggests job skips them.

# nolint start: object_usage_linter.
lmer_pair <- function(dat = sim_cluster211(J = 10, sizes = 5, seed = 1)$data,
                      fml_m = M ~ X + (1 | cluster),
                      fml_y = Y ~ X + M_w + M_bar + (1 | cluster)) {
  d <- cluster_fit_data(dat)
  suppressMessages(list(m = lme4::lmer(fml_m, data = d),
                        y = lme4::lmer(fml_y, data = d), d = d))
}

extract_pair <- function(p, ...) {
  extract_mediation(p$m, model_y = p$y, treatment = "X", mediator = "M", ...)
}

# Guards pass when the next error is the T4 stub, not a guard message.
expect_passes_guards <- function(p, ...) {
  expect_error(extract_pair(p, ...), "not implemented yet")
}
# nolint end

test_that("an lmerMod pair reaches the extraction body and reports the cluster", {
  skip_if_not_installed("lme4")
  expect_passes_guards(lmer_pair())
  expect_passes_guards(lmer_pair(), cluster = "cluster")
})

test_that("a subclass of lmerMod dispatches through the merMod method", {
  skip_if_not_installed("lme4")
  setClass("localLmer", contains = "lmerMod")
  on.exit(removeClass("localLmer"), add = TRUE)
  p <- lmer_pair()
  sub_m <- methods::as(p$m, "localLmer")
  expect_s4_class(sub_m, "localLmer")
  expect_error(
    extract_mediation(sub_m, model_y = p$y, treatment = "X", mediator = "M"),
    "not implemented yet"
  )
})

test_that("glmerMod gets the D7 error, not S7's 'can't find method'", {
  skip_if_not_installed("lme4")
  p <- lmer_pair()
  d <- p$d
  d$Yb <- as.integer(d$Y > stats::median(d$Y))
  g <- suppressWarnings(lme4::glmer(Yb ~ X + M_w + M_bar + (1 | cluster), data = d,
                                    family = stats::binomial()))
  expect_error(extract_pair(list(m = p$m, y = g)), "glmer fit")
  expect_error(extract_pair(list(m = p$m, y = g)), "link scale")
  expect_error(
    extract_mediation(g, model_y = p$y, treatment = "X", mediator = "M"),
    "mediator model.*glmer fit"
  )
})

test_that("an outcome model that is not an lmer fit is named", {
  skip_if_not_installed("lme4")
  p <- lmer_pair()
  bad <- list(m = p$m, y = stats::lm(Y ~ X + M, data = p$d))
  expect_error(extract_pair(bad), "outcome model.*lme4::lmer")
})

test_that("two or differing grouping factors ask for cluster =", {
  skip_if_not_installed("lme4")
  dat <- sim_cluster211(J = 10, sizes = 6, seed = 2)$data
  dat$site <- factor(rep(1:3, length.out = nrow(dat)))
  d <- cluster_fit_data(dat)
  two <- lme4::lmer(M ~ X + (1 | cluster) + (1 | site), data = d)
  y <- lme4::lmer(Y ~ X + M_w + M_bar + (1 | cluster), data = d)
  expect_error(extract_pair(list(m = two, y = y)),
               "Name it with `cluster =`")
  expect_error(extract_pair(list(m = two, y = y)), "cluster, site")
  # Naming the cluster resolves it, and a name the models lack still errors.
  expect_passes_guards(list(m = two, y = y), cluster = "cluster")
  expect_error(extract_pair(list(m = two, y = y), cluster = "site"),
               "outcome model")
  expect_error(extract_pair(list(m = two, y = y), cluster = "school"),
               "not a grouping factor")
  # Differing factors: no shared single choice.
  y_site <- lme4::lmer(Y ~ X + M_w + M_bar + (1 | site), data = d)
  m1 <- lme4::lmer(M ~ X + (1 | cluster), data = d)
  expect_error(extract_pair(list(m = m1, y = y_site)), "Name it with `cluster =`")
})

test_that("a missing cluster intercept errors with the corrected formula", {
  skip_if_not_installed("lme4")
  p <- lmer_pair()
  slope_only <- lme4::lmer(Y ~ X + M_w + M_bar + (0 + M_w | cluster), data = p$d)
  expect_error(extract_pair(list(m = p$m, y = slope_only)),
               "outcome model has no random intercept for `cluster`.*\\(1 \\| cluster\\)")
  m_slope <- lme4::lmer(M ~ X + (0 + X | cluster), data = p$d)
  expect_error(extract_pair(list(m = m_slope, y = p$y)),
               "mediator model has no random intercept")
})

test_that("treatment varying within a cluster is a 1-1-1 design and errors", {
  skip_if_not_installed("lme4")
  dat <- sim_cluster211(J = 10, sizes = 6, seed = 3)$data
  dat$X <- rep(c(0, 1), length.out = nrow(dat))
  p <- lmer_pair(dat)
  expect_error(extract_pair(p), "varies within clusters; 1-1-1 designs")
})

test_that("different rows, cluster vectors or treatment vectors error (D12)", {
  skip_if_not_installed("lme4")
  p <- lmer_pair()
  # Different number of rows: the outcome model drops a row with a missing Y.
  d_na <- p$d
  d_na$Y[3] <- NA
  y_na <- lme4::lmer(Y ~ X + M_w + M_bar + (1 | cluster), data = d_na)
  expect_error(extract_pair(list(m = p$m, y = y_na)),
               "same rows and the same cluster vector")
  # Same number of rows, cluster ids in a different order.
  d_perm <- p$d[c(2:nrow(p$d), 1), ]
  y_perm <- lme4::lmer(Y ~ X + M_w + M_bar + (1 | cluster), data = d_perm)
  expect_error(extract_pair(list(m = p$m, y = y_perm)),
               "same rows and the same cluster vector")
  # Same clusters, a different treatment vector.
  d_x <- p$d
  d_x$X <- ifelse(as.integer(d_x$cluster) %% 2 == 0, 1 - d_x$X, d_x$X)
  y_x <- lme4::lmer(Y ~ X + M_w + M_bar + (1 | cluster), data = d_x)
  expect_error(extract_pair(list(m = p$m, y = y_x)), "treatment `X` differs")
  # The treatment column must exist in both models.
  expect_error(
    extract_mediation(p$m, model_y = p$y, treatment = "Z", mediator = "M"),
    "Treatment `Z` is not a variable"
  )
})

test_that("vcov_fun and se_type = 'kr' are refused on the lmer method (P1)", {
  skip_if_not_installed("lme4")
  p <- lmer_pair()
  expect_error(extract_pair(p, vcov_fun = stats::vcov), "`vcov_fun` is not used")
  expect_error(extract_pair(p, se_type = "kr"), "arrives with the fit engine")
  expect_error(extract_pair(p, se_type = "sandwich"), "should be one of")
})
