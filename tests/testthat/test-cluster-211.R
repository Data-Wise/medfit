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


# T6: point-estimate oracles (test groups 1, 4 and 8) --------------------------
# The effect generics and SEs arrive in T7, so these tests read the effects off
# the paths and take delta-method SEs from `@vcov` themselves.

# nolint start: object_usage_linter.
cluster_effects <- function(o) {
  a <- o@a_path
  bw <- o@b_within
  bb <- o@b_between
  c(nie = a * bb, nde = o@c_prime, te = a * bb + o@c_prime,
    own = a * bw, spillover = a * (bb - bw))
}

# Gradients of each effect over the alias rows (a, c_prime, b_within, b_between).
cluster_grads <- function(o) {
  a <- o@a_path
  bw <- o@b_within
  bb <- o@b_between
  k <- c("a", "c_prime", "b_within", "b_between")
  g <- function(...) stats::setNames(c(...), k)
  list(nie = g(bb, 0, 0, a), nde = g(0, 1, 0, 0), te = g(bb, 1, 0, a),
       own = g(bw, 0, a, 0), spillover = g(bb - bw, 0, -a, a))
}

cluster_se <- function(o) {
  V <- o@vcov[c("a", "c_prime", "b_within", "b_between"),
              c("a", "c_prime", "b_within", "b_between")]
  vapply(cluster_grads(o), function(g) sqrt(drop(t(g) %*% V %*% g)), numeric(1))
}

# |estimate - truth| in SE units, for the effect names in `keys`.
cluster_z <- function(o, truth, keys = c("nie", "nde", "te"), effect_fn = NULL) {
  fn <- if (is.null(effect_fn)) cluster_effects else effect_fn
  est <- effects_from(o, effect_fn = fn)
  abs(est[keys] - truth[keys]) / cluster_se(o)[keys]
}

fit_sim <- function(sim, ...) fit_cluster211(sim$data, ...)

# nolint end

test_that("group 1: NIE, NDE and TE fall within 3 SE of the counterfactual truth", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  sim <- sim_cluster211(J = 200, sizes = 30, cov = "centered", seed = 11)
  truth <- true_cluster_effects(sim)
  for (param in c("within", "raw")) {
    z <- cluster_z(fit_sim(sim, parameterization = param), truth)
    expect_true(all(z < 3), info = sprintf("%s: z = %s", param,
                                           paste(round(z, 2), collapse = ", ")))
  }
})

test_that("group 1 companion: a small fixed-seed fit is pinned (always on)", {
  skip_if_not_installed("lme4")
  sim <- sim_cluster211(J = 12, sizes = 6, cov = "centered", seed = 21)
  o <- fit_sim(sim)
  est <- unname(o@estimates[c("a", "c_prime", "b_within", "b_between")])
  # A regression pin, not a truth check (J = 12 is too small for that). Constants
  # recorded from this fit under lme4 2.0.6; 1e-6 relative absorbs optimizer drift.
  expect_equal(est, c(-0.3259615080, 0.1049751247, 0.5247731995, 0.4712130474),
               tolerance = 1e-6)
  expect_equal(unname(cluster_se(o)["nie"]), 0.2083165481, tolerance = 1e-5)
})

test_that("group 4 O3: own is within 3 SE of the exact own effect at n_j = 50", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  sim <- sim_cluster211(J = 120, sizes = 50, cov = "centered", seed = 12)
  truth <- true_cluster_effects(sim)
  o <- fit_sim(sim)
  expect_lt(cluster_z(o, truth, "own")[[1]], 3)
  # Spillover against the true NIE minus the true own effect.
  expect_lt(cluster_z(o, truth, "spillover")[[1]], 3)
})

test_that("group 4 O4: with dyads own misses by the D-own gap a (b_B - b_W) / H", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  a <- 0.8
  bw <- 0.2
  bb <- 1.0
  sim <- sim_cluster211(J = 1000, sizes = 2, a = a, b_W = bw, b_B = bb,
                        tau_y = 0.1, seed = 13)
  truth <- true_cluster_effects(sim)
  o <- fit_sim(sim)
  # The harmonic mean cluster size of dyads is 2.
  gap <- a * (bb - bw) / 2
  expect_gt(gap / cluster_se(o)[["own"]], 6)    # power: the gap exceeds 6 SE of own
  expect_equal(unname(truth["own"] - cluster_effects(o)["own"]), gap,
               tolerance = 3 * cluster_se(o)[["own"]])
})

test_that("group 4 O5: the peer-mean difference is reported, not gated", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  sizes <- rep(2:10, length.out = 150)
  sim <- sim_cluster211(J = 150, sizes = sizes, process = "peer_mean", seed = 14)
  truth <- true_cluster_effects(sim)
  o <- fit_sim(sim)
  d_own_truth <- sim$a * sim$b_W + sim$a * (sim$b_B - sim$b_W) * mean(1 / sizes)
  diff <- unname(truth["own"] - d_own_truth)
  # Recorded for the PR body: class-mean D-own truth vs the peer-mean truth.
  note <- sprintf("O5: peer-mean own %.4f, class-mean D-own %.4f, difference %.4f",
                  truth[["own"]], d_own_truth, diff)
  expect_true(is.finite(diff), info = note)
  expect_true(is.finite(cluster_effects(o)[["own"]]))
})

test_that("group 8: planted point-estimate defects each fail their oracle", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  # Low-noise process with a (b_B - b_W) well above 6 SE.
  a <- 0.8
  bw <- 0.2
  bb <- 1.0
  sim <- sim_cluster211(J = 200, sizes = 30, a = a, b_W = bw, b_B = bb,
                        tau_y = 0.1, cov = "centered", seed = 15)
  truth <- true_cluster_effects(sim)
  o <- fit_sim(sim)
  expect_lt(cluster_z(o, truth, c("nie", "spillover"))[["nie"]], 3)

  # NIE computed as a b_W.
  nie_bw <- function(x) {
    e <- cluster_effects(x)
    e[["nie"]] <- x@a_path * x@b_within
    e
  }
  z_nie <- cluster_z(o, truth, "nie", effect_fn = nie_bw)[[1]]
  expect_gt(z_nie, 6)

  # Spillover with its sign flipped.
  flip <- function(x) {
    e <- cluster_effects(x)
    e[["spillover"]] <- -e[["spillover"]]
    e
  }
  expect_gt(cluster_z(o, truth, "spillover", effect_fn = flip)[[1]], 6)

  # Raw read as within (R1): b_between becomes kappa = b_B - b_W, so the raw fit
  # no longer reproduces the within fit's b_between. Without the defect it does.
  within_fit <- fit_sim(sim)
  expect_equal(fit_sim(sim, parameterization = "raw")@b_between,
               within_fit@b_between, tolerance = 1e-6)
  local_mocked_bindings(.raw_to_within = function(L) L)
  raw <- fit_sim(sim, parameterization = "raw")
  expect_gt(abs(raw@b_between - within_fit@b_between), 0.1)
  expect_equal(raw@b_between, within_fit@b_between - within_fit@b_within,
               tolerance = 1e-6)
})


# T7: gradients, SEs, effect generics, bootstrap acceptance --------------------

# nolint start: object_usage_linter.
fn_effects <- function(theta) {
  a <- theta[["a"]]
  bw <- theta[["b_within"]]
  bb <- theta[["b_between"]]
  c(nie = a * bb, nde = theta[["c_prime"]], te = a * bb + theta[["c_prime"]],
    own = a * bw, spillover = a * (bb - bw))
}

central_grad <- function(f, theta, key, h = 1e-6) {
  vapply(names(theta), function(nm) {
    up <- dn <- theta
    up[[nm]] <- up[[nm]] + h
    dn[[nm]] <- dn[[nm]] - h
    (f(up)[[key]] - f(dn)[[key]]) / (2 * h)
  }, numeric(1))
}
# nolint end

test_that("effect gradients equal central differences of the effect formulas", {
  skip_if_not_installed("lme4")
  o <- fit_sim(sim_cluster211(J = 40, sizes = 8, cov = "centered", seed = 31))
  theta <- c(a = o@a_path, c_prime = o@c_prime, b_within = o@b_within,
             b_between = o@b_between)
  grads <- .effect_gradients(o)
  expect_setequal(names(grads), c("nie", "nde", "te", "own", "spillover"))
  for (key in names(grads)) {
    num <- central_grad(fn_effects, theta, key)
    got <- stats::setNames(numeric(4), names(theta))
    got[names(grads[[key]])] <- grads[[key]]
    expect_equal(got, num, tolerance = 1e-6, info = key)
  }
  # SEs agree with the hand delta method used in T6.
  expect_equal(.effect_se(o, c("nie", "nde", "te", "own", "spillover")),
               cluster_se(o), tolerance = 1e-12)
})

test_that("a planted wrong gradient is caught by the central-difference check", {
  skip_if_not_installed("lme4")
  o <- fit_sim(sim_cluster211(J = 40, sizes = 8, seed = 31))
  theta <- c(a = o@a_path, c_prime = o@c_prime, b_within = o@b_within,
             b_between = o@b_between)
  bad <- c(a = o@b_within, b_between = o@a_path)   # a b_W's gradient used for NIE
  num <- central_grad(fn_effects, theta, "nie")
  expect_gt(max(abs(c(bad, c_prime = 0, b_within = 0)[names(theta)] - num)), 0.05)
})

test_that("nie(), nde(), te(), pm() and paths() follow the effects table", {
  skip_if_not_installed("lme4")
  o <- fit_sim(sim_cluster211(J = 40, sizes = 8, seed = 32))
  expect_equal(unclass(nie(o))[[1]], o@a_path * o@b_between)
  expect_equal(unclass(nde(o))[[1]], o@c_prime)
  expect_equal(unclass(te(o))[[1]], o@a_path * o@b_between + o@c_prime)
  expect_equal(unclass(pm(o))[[1]], unclass(nie(o))[[1]] / unclass(te(o))[[1]])
  expect_s3_class(nie(o), "mediation_effect")
  expect_identical(names(paths(o)), c("a", "b_within", "b_between", "c_prime"))
  expect_equal(unname(paths(o)),
               c(o@a_path, o@b_within, o@b_between, o@c_prime))
})

test_that("pm() is undefined with a zero total effect", {
  skip_if_not_installed("lme4")
  o <- fit_sim(sim_cluster211(J = 40, sizes = 8, seed = 32))
  est <- o@estimates
  est[c("a", "b_between", "c_prime")] <- c(0.5, 0.4, -0.2)
  o <- S7::set_props(o, a_path = 0.5, b_between = 0.4, c_prime = -0.2,
                     estimates = est)
  expect_warning(expect_true(is.na(pm(o))), "approximately zero")
})

test_that("decompose() splits the NIE and carries its label", {
  skip_if_not_installed("lme4")
  o <- fit_sim(sim_cluster211(J = 120, sizes = 50, seed = 33))
  d <- decompose(o)
  expect_identical(names(d), c("own", "spillover", "nie"))
  expect_equal(unname(d["own"] + d["spillover"]), unname(d["nie"]))
  expect_identical(attr(d, "label"), "cluster-average, large-cluster approximation")
})

test_that("D11: decompose() warns on dyads and stays quiet at n_j = 50", {
  skip_if_not_installed("lme4")
  skip_on_cran()
  dyads <- fit_sim(sim_cluster211(J = 1000, sizes = 2, a = 0.8, b_W = 0.2, b_B = 1.0,
                                  tau_y = 0.1, seed = 13))
  expect_warning(decompose(dyads), "own-effect approximation")
  big <- fit_sim(sim_cluster211(J = 120, sizes = 50, seed = 12, cov = "centered"))
  expect_no_warning(decompose(big))
  # The warning rule: gap above half the own SE.
  gap <- medfit:::.cluster_own_gap(dyads)
  expect_gt(gap, 0.5 * .effect_se(dyads, "own")[[1]])
  expect_lt(medfit:::.cluster_own_gap(big), 0.5 * .effect_se(big, "own")[[1]])
})

test_that("group 7: a parametric bootstrap from @estimates/@vcov reproduces the NIE", {
  skip_if_not_installed("lme4")
  o <- fit_sim(sim_cluster211(J = 60, sizes = 10, seed = 34))
  stat <- function(theta) theta[["a"]] * theta[["b_between"]]
  plug <- bootstrap_mediation(stat, method = "plugin", mediation_data = o)
  expect_equal(plug@estimate, unclass(nie(o))[[1]], tolerance = 1e-10)
  boot <- bootstrap_mediation(stat, method = "parametric", mediation_data = o,
                              n_boot = 400L, seed = 1)
  expect_equal(boot@estimate, unclass(nie(o))[[1]], tolerance = 1e-10)
  # The draws' spread matches the delta SE (Monte Carlo tolerance).
  expect_equal(stats::sd(boot@boot_estimates), .effect_se(o, "nie")[[1]],
               tolerance = 0.2)
  expect_error(bootstrap_mediation(stat, method = "plugin", mediation_data = 1),
               "ClusterMediationData")
})


# T8: base and tidy methods, print and summary ---------------------------------

# A hand-built object with fixed numbers, so the snapshots do not depend on lme4.
# nolint start: object_usage_linter.
snap_object <- function(centered = TRUE) {
  nm <- c("a", "c_prime", "b_within", "b_between")
  est <- c(a = 0.5, c_prime = 0.2, b_within = 0.3, b_between = 0.6)
  vc <- matrix(c(0.0100, 0, 0, 0,
                 0, 0.0200, 0.0010, 0.0005,
                 0, 0.0010, 0.0030, 0.0004,
                 0, 0.0005, 0.0004, 0.0150), 4, 4, dimnames = list(nm, nm))
  ClusterMediationData(
    a_path = 0.5, b_within = 0.3, b_between = 0.6, c_prime = 0.2,
    estimates = est, vcov = vc, treatment = "X", mediator = "M",
    outcome = "Y", cluster = "school", n_obs = 400L, n_clusters = 40L,
    cluster_sizes = rep(c(8L, 12L), 20), parameterization = "within",
    covariates_centered = centered, se_type = "model", reml = TRUE,
    converged = TRUE, sigma_m = 1, sigma_y = 1, tau_m = 0.5, tau_y = 0.5,
    source_package = "lme4"
  )
}
# nolint end

test_that("print() and summary() end with the estimand and assumptions block", {
  expect_snapshot(print(snap_object(TRUE)))
  expect_snapshot(print(summary(snap_object(TRUE))))
  expect_snapshot(print(snap_object(FALSE)))
  expect_snapshot(print(summary(snap_object(FALSE))))
})

test_that("the uncentered block drops the upper-level robustness clause", {
  flat <- function(x) {
    gsub("\\s+", " ", paste(utils::capture.output(print(x)), collapse = " "))
  }
  centered <- flat(snap_object(TRUE))
  uncentered <- flat(snap_object(FALSE))
  expect_match(centered, "additive upper-level confounders are allowed")
  expect_no_match(centered, "does NOT hold")
  expect_match(uncentered, "robustness to upper-level confounding does NOT hold")
  expect_no_match(uncentered, "additive upper-level")
})

test_that("summary() always prints the D-own gap and flags a large one", {
  s <- utils::capture.output(print(summary(snap_object())))
  expect_true(any(grepl("D-own gap", s, fixed = TRUE)))
  expect_false(any(grepl("read the split with care", s, fixed = TRUE)))
  # Dyads: the gap is large against the own SE.
  d <- snap_object()
  d <- S7::set_props(d, n_obs = 400L, n_clusters = 200L,
                     cluster_sizes = rep(2L, 200))
  expect_true(any(grepl("read the split with care",
                        utils::capture.output(print(summary(d))), fixed = TRUE)))
  expect_equal(summary(snap_object())$own_gap, 0.5 * 0.3 / (2 / (1 / 8 + 1 / 12)),
               tolerance = 1e-12)
})

test_that("coef(), vcov() and nobs() read the object", {
  o <- snap_object()
  expect_identical(coef(o), c(a = 0.5, b_within = 0.3, b_between = 0.6, c_prime = 0.2))
  expect_equal(coef(o, "effects"), c(nie = 0.3, nde = 0.2, te = 0.5))
  expect_identical(coef(o, "all"), o@estimates)
  expect_identical(vcov(o), o@vcov)
  expect_identical(class(vcov(o)), c("matrix", "array"))
  expect_identical(nobs(o), 400L)
})

test_that("confint() equals tidy(conf.int = TRUE) to 1e-12", {
  o <- snap_object()
  td <- tidy(o, conf.int = TRUE)
  for (parm in c("paths", "effects")) {
    ci <- confint(o, parm = parm)
    rows <- td[td$term %in% rownames(ci), ]
    expect_identical(rows$term, rownames(ci))
    expect_equal(unname(ci[, 1]), rows$conf.low, tolerance = 1e-12)
    expect_equal(unname(ci[, 2]), rows$conf.high, tolerance = 1e-12)
  }
  expect_identical(tidy(o, type = "paths")$term,
                   c("a", "b_within", "b_between", "c_prime"))
  expect_identical(tidy(o, type = "effects")$term,
                   c("nie", "nde", "te", "own", "spillover"))
  # The tidy SEs are the delta-method SEs.
  expect_equal(tidy(o, type = "effects")$std.error,
               unname(.effect_se(o, c("nie", "nde", "te", "own", "spillover"))),
               tolerance = 1e-12)
})

test_that("glance() has the stated columns and n_clusters", {
  g <- glance(snap_object())
  expect_identical(names(g), c("nie", "nde", "te", "pm", "n_clusters", "nobs",
                               "converged"))
  expect_identical(g$n_clusters, 40L)
  expect_equal(g$nie, 0.3)
  expect_equal(g$pm, 0.3 / 0.5)
})

test_that("quick() works and med() does not take cluster =", {
  expect_output(quick(snap_object()), "NIE = 0.3 .*own = 0.15 .*clusters = 40")
  expect_error(med(medfit::mediation_demo, "treatment", "mediator1", "outcome",
                   cluster = "covariate1"), "unused argument")
})

test_that("print.summary is registered for S3 dispatch", {
  expect_true(is.function(utils::getS3method("print", "summary.ClusterMediationData")))
  expect_s3_class(summary(snap_object()), "summary.ClusterMediationData")
})
