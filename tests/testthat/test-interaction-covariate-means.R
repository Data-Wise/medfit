# Tests for the covariate means that enter E[M | X = 0] in the single-mediator
# four-way decomposition (InteractionMediationData, lm/glm engine).
#
# The means are taken over the mediator model's design columns, so factor
# dummies (e.g. Gb, Gc) and transformed terms (e.g. log(C)) count, and the
# point estimate and the delta-method gradient use the same values.

gen_numeric_covs <- function() {
  set.seed(11)
  n <- 500
  C1 <- rnorm(n, 2)
  C2 <- runif(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.4 + 0.5 * X + 0.3 * C1 - 0.2 * C2 + rnorm(n)
  Y <- 0.1 * X + 0.3 * M + 0.25 * X * M + 0.2 * C1 + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C1 = C1, C2 = C2)
}

gen_factor_cov <- function(n = 4000, seed = 1) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, TRUE))
  x <- rbinom(n, 1, 0.5)
  m <- 0.5 * x + 1.5 * (g == "b") + 3 * (g == "c") + rnorm(n)
  y <- 0.2 * x + 0.3 * m + 0.5 * x * m + rnorm(n)
  data.frame(X = x, M = m, Y = y, G = g)
}

# NDE and INTref from the closed form, with covariate means taken over the
# mediator model matrix (treatment and intercept columns excluded).
manual_nde_intref <- function(fm, fy, m_star = 0) {
  mm <- model.matrix(fm)
  covs <- setdiff(colnames(mm), c("(Intercept)", "X"))
  bm <- coef(fm)
  m_ref <- unname(bm[["(Intercept)"]] + sum(bm[covs] * colMeans(mm[, covs, drop = FALSE])))
  t3 <- unname(coef(fy)[["X:M"]])
  int_ref <- t3 * (m_ref - m_star)
  c(nde = unname(coef(fy)[["X"]]) + t3 * m_star + int_ref, int_ref = int_ref)
}

# Central-difference gradient of NDE over the source rows of @vcov, rebuilt
# from perturbed model coefficients.
nde_numeric_gradient <- function(fm, fy, rows, h = 1e-6) {
  nde_at <- function(bm, by) {
    fm2 <- fm
    fy2 <- fy
    fm2$coefficients <- bm
    fy2$coefficients <- by
    manual_nde_intref(fm2, fy2)[["nde"]]
  }
  bm <- coef(fm)
  by <- coef(fy)
  vapply(rows, function(r) {
    up_m <- bm
    dn_m <- bm
    up_y <- by
    dn_y <- by
    nm <- sub("^[my]_", "", r)
    if (startsWith(r, "m_")) {
      up_m[[nm]] <- up_m[[nm]] + h
      dn_m[[nm]] <- dn_m[[nm]] - h
    } else {
      up_y[[nm]] <- up_y[[nm]] + h
      dn_y[[nm]] <- dn_y[[nm]] - h
    }
    (nde_at(up_m, up_y) - nde_at(dn_m, dn_y)) / (2 * h)
  }, numeric(1))
}

# ==============================================================================
# Numeric covariates: values pinned to the pre-fix implementation. The literals
# are the exact (hex) values on the development machine; the tolerance only
# absorbs cross-platform BLAS/compiler rounding. Bit-exactness on any platform
# is checked by the column-mean identity test below.
# ==============================================================================

test_that("numeric-covariate results are unchanged (extract_mediation)", {
  d <- gen_numeric_covs()
  o <- extract_mediation(lm(M ~ X + C1 + C2, d),
                         model_y = lm(Y ~ X * M + C1 + C2, d),
                         treatment = "X", mediator = "M", m_star = 0.5)
  expect_equal(o@nde, 0x1.ea832584f00ep-3, tolerance = 1e-12)
  expect_equal(o@int_ref, 0x1.15c8577f224acp-4, tolerance = 1e-12)
  expect_equal(o@total_effect, 0x1.04b01d4b4755bp-1, tolerance = 1e-12)
  se <- unname(medfit:::.effect_se(o, c("nde", "int_ref", "te")))
  expect_equal(se, c(0x1.7d5406caa8632p-4, 0x1.10583f79cac5ep-5,
                     0x1.89acf4a7f0d51p-4), tolerance = 1e-12)
})

test_that("numeric-covariate results are unchanged (fit_mediation)", {
  d <- gen_numeric_covs()
  o <- fit_mediation(formula_y = Y ~ X * M + C1 + C2,
                     formula_m = M ~ X + C1 + C2, data = d,
                     treatment = "X", mediator = "M", m_star = 0.5)
  expect_equal(o@nde, 0x1.ea832584f00ddp-3, tolerance = 1e-12)
  expect_equal(o@int_ref, 0x1.15c8577f224acp-4, tolerance = 1e-12)
  expect_equal(o@total_effect, 0x1.04b01d4b4755ap-1, tolerance = 1e-12)
  se <- unname(medfit:::.effect_se(o, c("nde", "int_ref", "te")))
  expect_equal(se, c(0x1.7d5406caa8632p-4, 0x1.10583f79cac5ep-5,
                     0x1.89acf4a7f0d52p-4), tolerance = 1e-12)
})

test_that("numeric-covariate point estimates match the column-mean formula exactly", {
  d <- gen_numeric_covs()
  fm <- lm(M ~ X + C1 + C2, d)
  fy <- lm(Y ~ X * M + C1 + C2, d)
  o <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  bm <- coef(fm)
  m_ref <- unname(bm[["(Intercept)"]])
  m_ref <- m_ref + unname(bm[["C1"]]) * mean(d$C1)
  m_ref <- m_ref + unname(bm[["C2"]]) * mean(d$C2)
  expect_identical(o@int_ref, unname(coef(fy)[["X:M"]]) * m_ref)
})

# ==============================================================================
# Factor covariate (regression test for silently skipped dummies)
# ==============================================================================

test_that("a factor covariate's dummies enter E[M | X = 0] (extract_mediation)", {
  d <- gen_factor_cov()
  fm <- lm(M ~ X + G, d)
  fy <- lm(Y ~ X * M + G, d)
  o <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")

  ref <- manual_nde_intref(fm, fy)
  expect_equal(o@nde, ref[["nde"]], tolerance = 1e-10)
  expect_equal(o@int_ref, ref[["int_ref"]], tolerance = 1e-10)
  expect_equal(o@nde, 0.8992192, tolerance = 1e-6)

  # g-computation oracle: predict M under X = 0 for every unit, then average
  # the outcome contrast X = 1 vs X = 0 at that mediator value.
  d0 <- transform(d, X = 0)
  d0$M <- predict(fm, newdata = d0)
  d1 <- transform(d0, X = 1)
  nde_g <- mean(predict(fy, newdata = d1) - predict(fy, newdata = d0))
  expect_equal(o@nde, nde_g, tolerance = 1e-10)

  # Simulated truth: E[M(0)] = (0 + 1.5 + 3) / 3, NDE = 0.2 + 0.5 * 1.5 = 0.95,
  # INTref = 0.5 * 1.5 = 0.75.
  se <- medfit:::.effect_se(o, c("nde", "int_ref"))
  expect_lt(abs(o@nde - 0.95), 4 * se[["nde"]])
  expect_lt(abs(o@int_ref - 0.75), 4 * se[["int_ref"]])
})

test_that("delta-method SE of NDE with a factor covariate matches central differences", {
  d <- gen_factor_cov()
  fm <- lm(M ~ X + G, d)
  fy <- lm(Y ~ X * M + G, d)
  o <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")

  rows <- grep("^[my]_", rownames(o@vcov), value = TRUE)
  g_num <- nde_numeric_gradient(fm, fy, rows)
  se_num <- sqrt(drop(t(g_num) %*% o@vcov[rows, rows] %*% g_num))
  expect_equal(medfit:::.effect_se(o, "nde")[["nde"]], se_num, tolerance = 1e-6)
  # The dummy rows carry a nonzero gradient (theta3 times the dummy mean).
  expect_true(all(abs(g_num[c("m_Gb", "m_Gc")]) > 0.1))
})

test_that("fit_mediation() with a factor covariate agrees with extract_mediation()", {
  d <- gen_factor_cov()
  fm <- lm(M ~ X + G, d)
  fy <- lm(Y ~ X * M + G, d)
  o_lm <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  o_fit <- fit_mediation(formula_y = Y ~ X * M + G, formula_m = M ~ X + G,
                         data = d, treatment = "X", mediator = "M")
  expect_equal(o_fit@nde, o_lm@nde, tolerance = 1e-8)
  expect_equal(o_fit@int_ref, o_lm@int_ref, tolerance = 1e-8)
  keys <- c("nde", "int_ref", "te")
  expect_equal(medfit:::.effect_se(o_fit, keys), medfit:::.effect_se(o_lm, keys),
               tolerance = 1e-8)
})

test_that("a transformed covariate term enters E[M | X = 0]", {
  set.seed(5)
  n <- 2000
  C <- rexp(n) + 0.5
  X <- rbinom(n, 1, 0.5)
  M <- 0.4 + 0.5 * X + 0.8 * log(C) + rnorm(n)
  Y <- 0.1 * X + 0.3 * M + 0.25 * X * M + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  fm <- lm(M ~ X + log(C), d)
  fy <- lm(Y ~ X * M + log(C), d)
  o <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  ref <- manual_nde_intref(fm, fy)
  expect_equal(o@nde, ref[["nde"]], tolerance = 1e-10)
  expect_equal(o@int_ref, ref[["int_ref"]], tolerance = 1e-10)
})

test_that("a poly() covariate works with and without caller-supplied data", {
  set.seed(6)
  n <- 2000
  C <- rnorm(n)
  X <- rbinom(n, 1, 0.5)
  M <- 0.5 * X + C + C^2 + rnorm(n)
  Y <- X + M + 0.3 * X * M + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  fm <- lm(M ~ X + poly(C, 2), d)
  fy <- lm(Y ~ X * M + poly(C, 2), d)
  ref <- manual_nde_intref(fm, fy)
  o_lm <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  o_fit <- fit_mediation(formula_y = Y ~ X * M + poly(C, 2),
                         formula_m = M ~ X + poly(C, 2), data = d,
                         treatment = "X", mediator = "M")
  expect_equal(o_lm@int_ref, ref[["int_ref"]], tolerance = 1e-10)
  expect_equal(o_fit@int_ref, ref[["int_ref"]], tolerance = 1e-8)
  keys <- c("nde", "int_ref")
  expect_equal(medfit:::.effect_se(o_fit, keys), medfit:::.effect_se(o_lm, keys),
               tolerance = 1e-8)
})
