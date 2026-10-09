# Tests for the m_/y_ alias rows on lavaan-derived MediationData (issue #106).
#
# probmed::pmed(method = "parametric_bootstrap") resolves three coefficients
# BY NAME in @estimates and @vcov: m_<treatment>, y_<mediator>, y_<treatment>.
# The glm route names its rows that way; the lavaan route did not, so the
# bootstrap failed with a subscript-out-of-bounds error.
#
# Test categories:
# 1. Names and covariance structure of the alias rows (no probmed needed)
# 2. Pre-existing rows are unchanged (frozen pre-change output)
# 3. Edge cases: labels, meanstructure, fixed.x = FALSE, covariates, latent
#    mediator, other MediationData classes
# 4. Integration with probmed (skipped when probmed is absent)

skip_if_not_installed("lavaan")

alias_names <- c("m_X", "y_M", "y_X")

extract_simple <- function(fit) {
  extract_mediation_lavaan(fit, treatment = "X", mediator = "M")
}

# ==============================================================================
# 1. Names and covariance structure
# ==============================================================================

test_that("lavaan simple route carries m_<X>, y_<M>, y_<X> beside the old rows", {
  md <- extract_simple(probmed_names_fits()$unlabeled)

  expect_true(all(alias_names %in% names(md@estimates)))
  expect_true(all(alias_names %in% rownames(md@vcov)))
  expect_true(all(c("M~X", "Y~M", "Y~X", "M~~M", "Y~~Y", "a", "b", "c_prime") %in%
                    names(md@estimates)))
  expect_identical(names(md@estimates), rownames(md@vcov))
  expect_identical(rownames(md@vcov), colnames(md@vcov))
  expect_true(isSymmetric(unname(md@vcov), tol = 1e-12))
})

test_that("alias rows hold the values and covariances of their source rows", {
  md <- extract_simple(probmed_names_fits()$unlabeled)
  est <- md@estimates
  v <- md@vcov

  expect_equal(unname(est["m_X"]), unname(est["M~X"]))
  expect_equal(unname(est["y_M"]), unname(est["Y~M"]))
  expect_equal(unname(est["y_X"]), unname(est["Y~X"]))
  expect_equal(unname(est["m_X"]), md@a_path)
  expect_equal(unname(est["y_M"]), md@b_path)
  expect_equal(unname(est["y_X"]), md@c_prime)

  # Each alias row equals its source row over the original block
  orig <- rownames(lavaan::vcov(probmed_names_fits()$unlabeled))
  for (pair in list(c("m_X", "M~X"), c("y_M", "Y~M"), c("y_X", "Y~X"))) {
    expect_equal(v[pair[1], orig], v[pair[2], orig])
    expect_equal(v[orig, pair[1]], v[orig, pair[2]])
  }
  expect_equal(v["m_X", "m_X"], v["M~X", "M~X"])
  expect_equal(v["y_M", "y_X"], v["Y~M", "Y~X"])
  expect_equal(v["y_M", "y_M"], v["b", "b"])
  expect_equal(v["m_X", "y_M"], v["a", "b"])
})

# ==============================================================================
# 2. Pre-existing rows are unchanged
# ==============================================================================

test_that("the pre-existing block is identical to lavaan's own coef() and vcov()", {
  fit <- probmed_names_fits()$unlabeled
  md <- extract_simple(fit)
  old <- names(lavaan::coef(fit))

  expect_identical(as.numeric(md@estimates[old]), as.numeric(lavaan::coef(fit)))
  expect_identical(names(md@estimates)[seq_along(old)], old)
  expect_identical(md@vcov[old, old], lavaan::vcov(fit)[old, old])
  # The three structural aliases keep their place right after lavaan's block
  expect_identical(names(md@estimates)[length(old) + 1:3], c("a", "b", "c_prime"))
})

test_that("the pre-existing block matches the frozen pre-change output", {
  frozen <- readRDS(test_path("fixtures", "lavaan-simple-before-aliases.rds"))
  fits <- probmed_names_fits()

  for (nm in names(frozen)) {
    md <- extract_simple(fits[[nm]])
    old_names <- names(frozen[[nm]]$estimates)
    k <- length(old_names)

    expect_identical(names(md@estimates)[seq_len(k)], old_names, info = nm)
    expect_identical(rownames(md@vcov)[seq_len(k)], old_names, info = nm)
    expect_equal(unname(md@estimates[seq_len(k)]),
                 unname(frozen[[nm]]$estimates), tolerance = 1e-10, info = nm)
    expect_equal(unname(md@vcov[seq_len(k), seq_len(k)]),
                 unname(frozen[[nm]]$vcov), tolerance = 1e-8, info = nm)
  }
})

# ==============================================================================
# 3. Edge cases
# ==============================================================================

test_that("labeled, meanstructure, fixed.x = FALSE and covariate fits get the rows", {
  fits <- probmed_names_fits()
  for (nm in c("labeled", "meanstructure", "free_x", "covariate")) {
    md <- extract_simple(fits[[nm]])
    expect_true(all(alias_names %in% names(md@estimates)), info = nm)
    expect_true(all(alias_names %in% rownames(md@vcov)), info = nm)
    expect_identical(names(md@estimates), rownames(md@vcov), info = nm)
    expect_equal(unname(md@estimates["m_X"]), md@a_path, info = nm)
    expect_equal(unname(md@estimates["y_M"]), md@b_path, info = nm)
    expect_equal(unname(md@estimates["y_X"]), md@c_prime, info = nm)
    expect_equal(md@vcov["y_M", "y_M"], md@vcov["b", "b"], info = nm)
  }
})

test_that("a label equal to an alias name keeps one row for the same path", {
  d <- probmed_names_data()
  md <- extract_simple(lavaan::sem("M ~ m_X*X\n Y ~ M + X", data = d))

  expect_identical(sum(names(md@estimates) == "m_X"), 1L)
  expect_identical(names(md@estimates), rownames(md@vcov))
  expect_equal(unname(md@estimates["m_X"]), md@a_path)
})

test_that("a label that names a different path as an alias is a named error", {
  d <- probmed_names_data()
  fit <- lavaan::sem("M ~ y_X*X\n Y ~ M + X", data = d)
  expect_error(extract_simple(fit), "already has a parameter named 'y_X'")
})

test_that("a latent mediator gets none of the three rows and does not error", {
  set.seed(2)
  n <- 400
  X <- stats::rbinom(n, 1, 0.5)
  eta <- 0.5 * X + stats::rnorm(n)
  d <- data.frame(
    X = X,
    m1 = eta + stats::rnorm(n, 0, 0.5),
    m2 = 0.8 * eta + stats::rnorm(n, 0, 0.5),
    m3 = 1.2 * eta + stats::rnorm(n, 0, 0.5)
  )
  d$Y <- 0.4 * eta + 0.2 * X + stats::rnorm(n)
  fit <- lavaan::sem("eta =~ m1 + m2 + m3\n eta ~ X\n Y ~ eta + X", data = d)

  md <- expect_no_error(
    extract_mediation_lavaan(fit, treatment = "X", mediator = "eta")
  )
  expect_s3_class(md, "medfit::MediationData")
  expect_false(any(alias_names %in% names(md@estimates)))
  expect_false(any(grepl("^(m|y)_", names(md@estimates))))
  expect_false(any(grepl("^(m|y)_", rownames(md@vcov))))
  expect_true(all(c("a", "b", "c_prime") %in% names(md@estimates)))
})

test_that("an ordered outcome gets none of the three rows and does not error", {
  set.seed(5)
  n <- 500
  X <- stats::rnorm(n)
  M <- 0.5 * X + stats::rnorm(n)
  Y <- cut(0.5 * M + 0.2 * X + stats::rnorm(n), c(-Inf, -0.5, 0.5, Inf),
           labels = FALSE)
  d <- data.frame(X = X, M = M, Y = Y)
  fit <- suppressWarnings(
    lavaan::sem("M ~ X\n Y ~ M + X", data = d, ordered = "Y")
  )

  md <- expect_no_error(extract_simple(fit))
  expect_false(any(grepl("^(m|y)_", names(md@estimates))))
  expect_false(any(grepl("^(m|y)_", rownames(md@vcov))))
  expect_identical(names(md@estimates), rownames(md@vcov))
})

test_that("serial, parallel and four-way lavaan objects get no m_/y_ rows", {
  set.seed(3)
  n <- 300
  X <- stats::rnorm(n)
  M1 <- 0.5 * X + stats::rnorm(n)
  M2 <- 0.4 * M1 + 0.2 * X + stats::rnorm(n)
  Y <- 0.3 * M2 + 0.2 * M1 + 0.1 * X + stats::rnorm(n)
  d <- data.frame(X = X, M1 = M1, M2 = M2, Y = Y)

  serial <- extract_mediation_lavaan(
    lavaan::sem("M1 ~ X\n M2 ~ M1 + X\n Y ~ M2 + M1 + X", data = d),
    treatment = "X", mediator = c("M1", "M2"), structure = "serial"
  )
  expect_s3_class(serial, "medfit::SerialMediationData")
  expect_false(any(grepl("^(m|y)_", names(serial@estimates))))

  parallel <- extract_mediation_lavaan(
    lavaan::sem("M1 ~ X\n M2 ~ X\n Y ~ M1 + M2 + X", data = d),
    treatment = "X", mediator = c("M1", "M2"), structure = "parallel"
  )
  expect_s3_class(parallel, "medfit::ParallelMediationData")
  expect_false(any(grepl("^(m|y)_", names(parallel@estimates))))

  d$XM <- d$X * d$M1
  four_way <- extract_mediation_lavaan(
    lavaan::sem("M1 ~ X\n Y ~ M1 + X + XM", data = d, meanstructure = TRUE),
    treatment = "X", mediator = "M1", interaction = "XM"
  )
  expect_s3_class(four_way, "medfit::InteractionMediationData")
  expect_false(any(grepl("^(m|y)_", names(four_way@estimates))))
})

# ==============================================================================
# 4. Integration with probmed
# ==============================================================================

# Parametric-bootstrap P_med of the glm and lavaan routes for the same data.
# Returns the glm result, the lavaan result and the agreement tolerance, a
# quarter of the glm interval's own width: the routes differ only in the
# residual variance divisor and Monte Carlo draws (observed gap about a tenth
# of that), while a mixed-up coefficient moves P_med by more than the tolerance.
probmed_routes <- function(lav_md_fun = extract_simple) {
  d <- probmed_names_data() # nolint: object_usage_linter.
  glm_md <- fit_mediation(Y ~ X + M, M ~ X, data = d,
                          treatment = "X", mediator = "M")
  lav_md <- lav_md_fun(lavaan::sem("M ~ X\n Y ~ M + X", data = d))
  boot <- function(md) {
    probmed::pmed(md, method = "parametric_bootstrap", n_boot = 500, seed = 1)
  }
  r_glm <- boot(glm_md)
  list(glm = r_glm, lav = boot(lav_md),
       tol = 0.25 * (r_glm@ci_upper - r_glm@ci_lower))
}

routes_gap <- function(x) {
  c(estimate = abs(x$lav@estimate - x$glm@estimate),
    ci_lower = abs(x$lav@ci_lower - x$glm@ci_lower),
    ci_upper = abs(x$lav@ci_upper - x$glm@ci_upper))
}

test_that("pmed() parametric bootstrap runs on a lavaan object and matches glm", {
  skip_if_not_installed("probmed")
  skip_if_not_installed("MASS")

  x <- expect_no_error(probmed_routes())

  expect_gt(x$tol, 0)
  expect_true(all(routes_gap(x) < x$tol))
  expect_gt(x$lav@ci_upper, x$lav@ci_lower)
})

test_that("agreement test catches y_<M> and y_<X> swapped (planted defect)", {
  skip_if_not_installed("probmed")
  skip_if_not_installed("MASS")

  # Same rows, but the b path is filed under y_X and c' under y_M.
  local_mocked_bindings(
    .lavaan_probmed_alias_names = function(object, treatment, mediator, outcome) {
      c(a = paste0("m_", treatment),
        b = paste0("y_", treatment),
        c_prime = paste0("y_", mediator))
    }
  )
  x <- probmed_routes()

  expect_false(all(routes_gap(x) < x$tol))
})
