# Native SEM engine: parameter counts under explicit equality constraints.
# An explicit equality removes a free parameter exactly as a shared label does, so model df, logLik() df, AIC and
# BIC must agree between the two spellings. Oracles: the shared-label or fixed-value model that says the same
# thing (same likelihood, same count), and lavaan's df. Planted defect: counting every parameter regardless of
# the equalities, the original behavior (explicit `a == b` gave df 0, logLik df 9, AIC 2 above its twin).

df_data <- function(n = 500, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = stats::rnorm(n))
  d$M <- 0.5 * d$X + stats::rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(n)
  d
}

df_base <- "M ~ a*X\nY ~ b*M + cp*X"

# model df, logLik df, AIC and BIC in one list
df_counts <- function(syntax, data = df_data()) {
  fit <- fit_sem(syntax, data, fixed_x = FALSE, meanstructure = NULL)
  ll <- stats::logLik(fit)
  list(df = fit@df, ll_df = attr(ll, "df"), aic = stats::AIC(ll), bic = stats::BIC(ll), ll = as.numeric(ll), fit = fit)
}

# (explicit-equality syntax, the model that spells the same restriction without an equality, expected model df)
df_pairs <- list(
  list("a == b", "M ~ a*X\nY ~ a*M + cp*X", 1),
  list("a == 0.5", "M ~ 0.5*X\nY ~ b*M + cp*X", 1),
  list("a == b\ncp == a", "M ~ a*X\nY ~ a*M + a*X", 2),
  list("a == b\nb == a", "M ~ a*X\nY ~ a*M + cp*X", 1),
  list("a == b\nb == cp\na == cp", "M ~ a*X\nY ~ a*M + a*X", 2)
)

test_that("an explicit equality counts like the model that spells it without one", {
  for (pr in df_pairs) {
    explicit <- df_counts(paste0(df_base, "\n", pr[[1L]]))
    twin <- df_counts(pr[[2L]])
    info <- gsub("\n", " ; ", pr[[1L]])
    expect_identical(explicit$df, pr[[3L]], info = info)
    expect_identical(explicit$df, twin$df, info = info)
    expect_identical(explicit$ll_df, twin$ll_df, info = info)
    expect_equal(explicit$ll, twin$ll, tolerance = 1e-6, info = info)
    expect_equal(explicit$aic, twin$aic, tolerance = 1e-6, info = info)
    expect_equal(explicit$bic, twin$bic, tolerance = 1e-6, info = info)
  }
})

test_that("a linear combination removes one parameter, an inequality none", {
  expect_identical(df_counts(paste0(df_base, "\na + b == 0.5"))$df, 1)
  # an inactive inequality leaves the count alone: the model is saturated, df 0
  ineq <- df_counts(paste0(df_base, "\na + b < 5"))
  plain <- df_counts(df_base)
  expect_identical(ineq$df, 0)
  expect_identical(ineq$ll_df, plain$ll_df)
})

test_that("model df and logLik df follow the equalities, not the parameter vector", {
  fit <- df_counts(paste0(df_base, "\na == b"))$fit
  # six free parameters in the vector, one removed by the equality: five effective, three means
  expect_identical(length(fit@theta), 6L)
  expect_identical(attr(stats::logLik(fit), "df"), 8L)
  expect_match(paste(utils::capture.output(print(fit)), collapse = "\n"), "5 free, 1 df", fixed = TRUE)
})

test_that("a model identified only by an equality fits instead of tripping the df guard", {
  # 7 free parameters and 6 moments, but `cov == 0` removes one: just identified
  syntax <- paste0(df_base, "\nM ~~ cov*Y\ncov == 0")
  res <- df_counts(syntax)
  expect_identical(res$df, 0)
  expect_true(res$fit@converged)
  # the same likelihood as the model without that covariance
  expect_equal(res$ll, df_counts(df_base)$ll, tolerance = 1e-6)
  expect_identical(res$ll_df, df_counts(df_base)$ll_df)
})

test_that("a model with too many parameters still errors when no equality rescues it", {
  expect_error(
    fit_sem(paste0(df_base, "\nM ~~ cov*Y"), df_data(), fixed_x = FALSE, meanstructure = NULL),
    "more free parameters \\(7\\) than observed moments \\(6\\)"
  )
})

test_that("model df equals lavaan's df for explicit equalities", {
  skip_if_not_installed("lavaan")
  for (extra in c("a == b", "a == 0.5", "a + b == 0.5", "a == b\ncp == a", "a + b < 5")) {
    lav <- lavaan::fitMeasures(lavaan::sem(paste0(df_base, "\n", extra), data = df_data(), fixed.x = FALSE), "df")[[1L]]
    expect_equal(df_counts(paste0(df_base, "\n", extra))$df, lav, info = gsub("\n", " ; ", extra))
  }
})

test_that("planted defect: counting every parameter regardless of the equalities reproduces the old counts", {
  testthat::local_mocked_bindings(.sem_eq_rank = function(eq) 0L)
  buggy <- df_counts(paste0(df_base, "\na == b"))
  twin <- df_counts("M ~ a*X\nY ~ a*M + cp*X")
  expect_identical(buggy$df, 0)
  expect_identical(buggy$ll_df, 9L)
  expect_gt(abs(buggy$aic - twin$aic), 1)
})
