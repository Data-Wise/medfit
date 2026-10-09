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

# Guards pass when extraction returns a ClusterMediationData.
expect_passes_guards <- function(p, ...) {
  expect_true(S7::S7_inherits(extract_pair(p, ...), ClusterMediationData))
}
# nolint end

test_that("an lmerMod pair extracts a ClusterMediationData", {
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
  expect_true(S7::S7_inherits(
    extract_mediation(sub_m, model_y = p$y, treatment = "X", mediator = "M"),
    ClusterMediationData
  ))
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


# T4: term detection by values, R1, product and slope guards ------------------

# nolint start: object_usage_linter.
terms_for <- function(fml_y, dat, fml_m = M ~ X + (1 | cluster), d = NULL) {
  if (is.null(d)) d <- cluster_fit_data(dat)
  m <- suppressWarnings(suppressMessages(lme4::lmer(fml_m, data = d)))
  y <- suppressWarnings(suppressMessages(lme4::lmer(fml_y, data = d)))
  ctx <- .lmer_guard(m, y, "X", "M", NULL, "model", NULL)
  list(t = .lmer_terms(m, y, ctx), y = y, m = m, ctx = ctx)
}

# (c_prime, b_within, b_between) and their vcov from a terms result.
paths_of <- function(r) {
  V <- as.matrix(stats::vcov(r$y))
  list(est = drop(r$t$L %*% lme4::fixef(r$y)), vcov = r$t$L %*% V %*% t(r$t$L))
}

sim_c <- function(...) sim_cluster211(J = 24, sizes = 8, seed = 4, ...)
# nolint end

test_that("the cluster-mean term is found by value under rescaling (affine detection)", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_c()$data)
  d$M_bar_gm <- d$M_bar - mean(d$M_bar)          # grand-mean centered
  d$M_bar_sc <- as.numeric(scale(d$M_bar))       # scale()d
  d$M_w_sc <- d$M_w * 3                          # rescaled within term
  base <- paths_of(terms_for(Y ~ X + M_w + M_bar + (1 | cluster), NULL, d = d))
  for (fml in list(Y ~ X + M_w + M_bar_gm + (1 | cluster),
                   Y ~ X + M_w + M_bar_sc + (1 | cluster),
                   Y ~ X + M_w_sc + M_bar_sc + (1 | cluster))) {
    r <- terms_for(fml, NULL, d = d)
    expect_identical(r$t$mean_term, setdiff(names(lme4::fixef(r$y)),
                                            c("(Intercept)", "X", "M_w", "M_w_sc"))[1])
    got <- paths_of(r)
    expect_equal(got$est, base$est, tolerance = 1e-8)
    expect_equal(got$vcov, base$vcov, tolerance = 1e-6)
  }
})

test_that("R1: raw and within parameterizations give the same b_between and vcov", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_c(cov = "centered")$data)
  within <- terms_for(Y ~ X + M_w + M_bar + C + (1 | cluster), NULL, d = d)
  raw <- terms_for(Y ~ X + M + M_bar + C + (1 | cluster), NULL, d = d)
  expect_identical(within$t$parameterization, "within")
  expect_identical(raw$t$parameterization, "raw")
  a <- paths_of(within)
  b <- paths_of(raw)
  expect_equal(b$est, a$est, tolerance = 1e-6)
  expect_equal(b$vcov, a$vcov, tolerance = 1e-5)
  # The raw kappa is b_between - b_within, so b_between needs the J transform.
  kappa <- unname(lme4::fixef(raw$y)["M_bar"])
  expect_equal(unname(b$est["b_between"] - b$est["b_within"]), kappa, tolerance = 1e-8)
})

test_that("a planted raw-read-as-within defect moves b_between by kappa", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_c()$data)
  good <- paths_of(terms_for(Y ~ X + M + M_bar + (1 | cluster), NULL, d = d))
  local_mocked_bindings(.raw_to_within = function(L) L)
  bad <- paths_of(terms_for(Y ~ X + M + M_bar + (1 | cluster), NULL, d = d))
  kappa <- good$est[["b_between"]] - good$est[["b_within"]]
  expect_equal(bad$est[["b_between"]], kappa, tolerance = 1e-8)
  expect_gt(abs(bad$est[["b_between"]] - good$est[["b_between"]]), 0.05)
})

test_that("a missing mean term errors with the corrected formula", {
  skip_if_not_installed("lme4")
  expect_error(terms_for(Y ~ X + M_w + (1 | cluster), sim_c()$data),
               "no cluster-mean term for `M`.*ave\\(M, cluster\\)")
  expect_error(terms_for(Y ~ X + M_bar + (1 | cluster), sim_c()$data),
               "no within-cluster or raw mediator term")
  d <- cluster_fit_data(sim_c()$data)
  d$M2 <- d$M * 2
  expect_error(terms_for(Y ~ X + M_w + M2 + M_bar + (1 | cluster), NULL, d = d),
               "both a within-cluster term.*raw mediator term")
  # The guard already refuses an outcome model without the treatment.
  expect_error(terms_for(Y ~ M_w + M_bar + (1 | cluster), sim_c()$data),
               "Treatment `X` is not a variable of the model")
})

test_that("a near-miss mean errors: constant within clusters, not affine in the mean", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_c()$data)
  set.seed(5)
  d$M_near <- d$M_bar + 0.01 * stats::rnorm(nlevels(d$cluster))[as.integer(d$cluster)]
  expect_gt(abs(stats::cor(d$M_near, d$M_bar)), 0.99)
  expect_error(terms_for(Y ~ X + M_w + M_near + (1 | cluster), NULL, d = d),
               "cluster mean must be computed on the rows the models use")
})

test_that("treatment- and covariate-by-mediator products error naming the term", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_c(cov = "centered")$data)
  expect_error(terms_for(Y ~ X + M_w + M_bar + X:M_w + C + (1 | cluster), NULL, d = d),
               "product term `X:M_w`")
  expect_error(terms_for(Y ~ X + M_w + M_bar + X:M_bar + C + (1 | cluster), NULL, d = d),
               "product term `X:M_bar`")
  expect_error(terms_for(Y ~ X + M_w + M_bar + M_w:C + (1 | cluster), NULL, d = d),
               "product term `M_w:C`")
  expect_error(terms_for(Y ~ X + M + M_bar + I(X * M) + (1 | cluster), NULL, d = d),
               "product term `I\\(X \\* M\\)`")
})

test_that("random slopes: within accepted; raw, mean term and treatment error", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_c(slope_sd = 0.3)$data)
  ok <- terms_for(Y ~ X + M_w + M_bar + (1 + M_w | cluster), NULL, d = d)
  expect_identical(ok$t$parameterization, "within")
  expect_error(terms_for(Y ~ X + M + M_bar + (1 + M | cluster), NULL, d = d),
               "random slope on the raw mediator term")
  expect_error(terms_for(Y ~ X + M_w + M_bar + (1 + M_bar | cluster), NULL, d = d),
               "random slope on the cluster-mean term")
  expect_error(terms_for(Y ~ X + M_w + M_bar + (1 + X | cluster), NULL, d = d),
               "random slope on the treatment")
  expect_error(terms_for(Y ~ X + M_w + M_bar + (1 | cluster), NULL, d = d,
                         fml_m = M ~ X + (1 + X | cluster)),
               "random slope on the treatment")
})

test_that("P6: equal cluster means error; a naive detector would return the intercept", {
  skip_if_not_installed("lme4")
  dat <- sim_c()$data
  dat$M <- mean(dat$M) + (dat$M - stats::ave(dat$M, dat$cluster))
  d <- cluster_fit_data(dat)
  expect_lt(stats::sd(d$M_bar), 1e-12)
  expect_error(terms_for(Y ~ X + M_w + M_bar + (1 | cluster), NULL, d = d),
               "no between-cluster variation in the mediator `M`")
  # A detector with neither the intercept exclusion nor a zero-variance skip
  # accepts "(Intercept)": it is constant within clusters and an exact affine
  # function of a constant cluster mean.
  naive <- function(X, m, cl, tol = 1e-8) {
    m_bar <- stats::ave(m, cl)
    for (nm in colnames(X)) {
      x <- X[, nm]
      if (max(abs(x - stats::ave(x, cl))) > tol) next
      fit <- stats::lm.fit(cbind(1, m_bar), x)
      if (max(abs(fit$residuals)) < tol) return(nm)
    }
    NULL
  }
  Xd <- cbind(`(Intercept)` = 1, X = d$X)
  expect_identical(naive(Xd, d$M, d$cluster), "(Intercept)")
  expect_null(.find_cluster_mean_term(Xd, d$M, d$cluster, exclude = "X"))
})

test_that("covariates_centered follows cluster-mean centering (P10)", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_c(cov = "confounded")$data)
  centered <- terms_for(Y ~ X + M_w + M_bar + C_w + C_bar + (1 | cluster), NULL, d = d)
  expect_true(centered$t$covariates_centered)
  companion <- terms_for(Y ~ X + M_w + M_bar + C + C_bar + (1 | cluster), NULL, d = d)
  expect_true(companion$t$covariates_centered)
  no_companion <- terms_for(Y ~ X + M_w + M_bar + C + (1 | cluster), NULL, d = d)
  expect_false(no_companion$t$covariates_centered)
  none <- terms_for(Y ~ X + M_w + M_bar + (1 | cluster), NULL, d = d)
  expect_true(none$t$covariates_centered)
  pre <- cluster_fit_data(sim_c(cov = "centered")$data)
  pre_c <- terms_for(Y ~ X + M_w + M_bar + C + (1 | cluster), NULL, d = pre)
  expect_true(pre_c$t$covariates_centered)
})


# T5: vcov assembly and object construction -----------------------------------

# nolint start: object_usage_linter.
fit_obj <- function(fml_y, d, fml_m = M ~ X + (1 | cluster)) {
  m <- suppressWarnings(suppressMessages(lme4::lmer(fml_m, data = d)))
  y <- suppressWarnings(suppressMessages(lme4::lmer(fml_y, data = d)))
  list(obj = extract_mediation(m, model_y = y, treatment = "X", mediator = "M"),
       m = m, y = y)
}
# nolint end

test_that("the object validates for both parameterizations and carries the design", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 24, sizes = c(rep(6, 12), rep(9, 12)),
                                       seed = 7, cov = "centered")$data)
  for (fml in list(Y ~ X + M_w + M_bar + C + (1 | cluster),
                   Y ~ X + M + M_bar + C + (1 | cluster))) {
    r <- fit_obj(fml, d)
    o <- r$obj
    expect_true(S7::S7_inherits(o, ClusterMediationData))
    expect_identical(o@n_obs, 180L)
    expect_identical(o@n_clusters, 24L)
    expect_identical(o@cluster_sizes, c(rep(6L, 12), rep(9L, 12)))
    expect_identical(c(o@treatment, o@mediator, o@outcome, o@cluster),
                     c("X", "M", "Y", "cluster"))
    expect_true(o@reml)
    expect_true(o@converged)
    expect_identical(o@se_type, "model")
    expect_identical(o@source_package, "lme4")
    expect_equal(o@sigma_m, stats::sigma(r$m))
    expect_equal(o@sigma_y, stats::sigma(r$y))
    expect_equal(o@tau_m, sqrt(lme4::VarCorr(r$m)$cluster[1, 1]))
    expect_equal(o@tau_y, sqrt(lme4::VarCorr(r$y)$cluster[1, 1]))
    expect_true(o@covariates_centered)
  }
  expect_identical(fit_obj(Y ~ X + M_w + M_bar + C + (1 | cluster), d)$obj@parameterization,
                   "within")
  expect_identical(fit_obj(Y ~ X + M + M_bar + C + (1 | cluster), d)$obj@parameterization,
                   "raw")
})

test_that("alias rows equal their source rows and the vcov is a base matrix", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 24, sizes = 8, seed = 7)$data)
  r <- fit_obj(Y ~ X + M_w + M_bar + (1 | cluster), d)
  o <- r$obj
  expect_identical(class(o@vcov), c("matrix", "array"))
  expect_false(methods::is(o@vcov, "Matrix"))
  expect_identical(rownames(o@vcov), names(o@estimates))
  expect_identical(colnames(o@vcov), names(o@estimates))
  fy <- lme4::fixef(r$y)
  fm <- lme4::fixef(r$m)
  expect_equal(o@estimates[["a"]], unname(fm["X"]), tolerance = 1e-12)
  expect_equal(o@estimates[["c_prime"]], unname(fy["X"]), tolerance = 1e-12)
  expect_equal(o@estimates[["b_within"]], unname(fy["M_w"]), tolerance = 1e-12)
  expect_equal(o@estimates[["b_between"]], unname(fy["M_bar"]), tolerance = 1e-12)
  expect_equal(o@estimates[["y_M_bar"]], unname(fy["M_bar"]), tolerance = 1e-12)
  expect_equal(o@estimates[["m_(Intercept)"]], unname(fm["(Intercept)"]),
               tolerance = 1e-12)
  # Alias variances match the source variances (within parameterization).
  Vy <- as.matrix(stats::vcov(r$y))
  Vm <- as.matrix(stats::vcov(r$m))
  expect_equal(o@vcov["b_between", "b_between"], Vy["M_bar", "M_bar"], tolerance = 1e-10)
  expect_equal(o@vcov["a", "a"], Vm["X", "X"], tolerance = 1e-10)
  expect_equal(o@vcov["c_prime", "b_within"], Vy["X", "M_w"], tolerance = 1e-10)
})

test_that("blocks between the mediator model and the outcome block are exactly zero", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 24, sizes = 8, seed = 7)$data)
  for (fml in list(Y ~ X + M_w + M_bar + (1 | cluster), Y ~ X + M + M_bar + (1 | cluster))) {
    o <- fit_obj(fml, d)$obj
    nm <- names(o@estimates)
    left <- c("a", nm[startsWith(nm, "m_")])
    right <- c("c_prime", "b_within", "b_between", nm[startsWith(nm, "y_")])
    expect_true(all(o@vcov[left, right] == 0))
    expect_true(all(o@vcov[right, left] == 0))
    expect_true(isSymmetric(o@vcov, tol = 1e-12))
    expect_true(all(diag(o@vcov) > 0))
  }
})

test_that("the raw parameterization's vcov carries b_between = b_within + kappa", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 24, sizes = 8, seed = 7)$data)
  r <- fit_obj(Y ~ X + M + M_bar + (1 | cluster), d)
  V <- as.matrix(stats::vcov(r$y))
  expect_equal(r$obj@vcov["b_between", "b_between"],
               V["M", "M"] + V["M_bar", "M_bar"] + 2 * V["M", "M_bar"],
               tolerance = 1e-10)
  expect_equal(r$obj@vcov["b_within", "b_between"], V["M", "M"] + V["M", "M_bar"],
               tolerance = 1e-10)
})

test_that("a rescaled mean term gives the same paths, SEs and covariances", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 24, sizes = 8, seed = 7)$data)
  d$M_bar_sc <- as.numeric(scale(d$M_bar))
  base <- fit_obj(Y ~ X + M_w + M_bar + (1 | cluster), d)$obj
  sc <- fit_obj(Y ~ X + M_w + M_bar_sc + (1 | cluster), d)$obj
  keys <- c("a", "c_prime", "b_within", "b_between")
  expect_equal(sc@estimates[keys], base@estimates[keys], tolerance = 1e-6)
  expect_equal(sc@vcov[keys, keys], base@vcov[keys, keys], tolerance = 1e-5)
})

test_that("the mediator name must be the response of the mediator model", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 10, sizes = 5, seed = 1)$data)
  m <- suppressMessages(lme4::lmer(M ~ X + (1 | cluster), d))
  y <- suppressMessages(lme4::lmer(Y ~ X + M_w + M_bar + (1 | cluster), d))
  expect_error(extract_mediation(m, model_y = y, treatment = "X", mediator = "Z"),
               "not the response of the mediator model")
})

test_that("an ML fit is flagged reml = FALSE and converged tracks lme4", {
  skip_if_not_installed("lme4")
  d <- cluster_fit_data(sim_cluster211(J = 24, sizes = 8, seed = 7)$data)
  m <- suppressMessages(lme4::lmer(M ~ X + (1 | cluster), d, REML = FALSE))
  y <- suppressMessages(lme4::lmer(Y ~ X + M_w + M_bar + (1 | cluster), d, REML = FALSE))
  o <- extract_mediation(m, model_y = y, treatment = "X", mediator = "M")
  expect_false(o@reml)
  expect_true(o@converged)
})
