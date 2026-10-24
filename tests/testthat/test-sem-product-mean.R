# Native SEM engine: any product term turns the saturated mean structure on (0.10.0 plan U5, GRILL H5), in both
# `fit_sem()` and `fit_mediation(engine = "native", model = )`, because the four-way decomposition needs
# E[M | X = 0]. No-product models are unchanged; `meanstructure = FALSE` with a product is an error.

pmn_data <- function(n = 400L, seed = 7L) {
  set.seed(seed)
  d <- data.frame(x = rbinom(n, 1, 0.5), c = rnorm(n))
  d$m <- 0.3 + 0.5 * d$x + 0.2 * d$c + rnorm(n)
  d$y <- 0.2 * d$x + 0.4 * d$m + 0.6 * d$x * d$m + 0.1 * d$c + rnorm(n)
  d
}
pmn_model <- "m ~ x + c\ny ~ m + x + x:m + c"
pmn_plain <- "m ~ x + c\ny ~ m + x + c"

test_that("a product model with no intercept statement fits the mean structure (fit_sem)", {
  quiet_product_advisories({
    fit <- fit_sem(pmn_model, pmn_data(), fixed_x = FALSE, meanstructure = NULL)
    expect_true(fit@internals$ram$has_mean)
    expect_true(all(c("m~1", "y~1", "x~1", "c~1") %in% names(coef(fit))))
    # an explicit TRUE is the same fit
    explicit <- fit_sem(pmn_model, pmn_data(), meanstructure = TRUE, fixed_x = FALSE)
    expect_equal(coef(explicit), coef(fit), tolerance = 1e-10)
  })
})

test_that("the same holds through fit_mediation(engine = 'native', model = )", {
  quiet_product_advisories({
    # the call returns the extracted object, so a spy on the completed table sees the mean structure
    d <- pmn_data()
    orig <- .sem_complete
    seen <- character()
    local_mocked_bindings(.sem_complete = function(...) {
      out <- orig(...)
      seen <<- c(seen, if ("~1" %in% out$op) "mean" else "cov")
      out
    })
    expect_no_error(fit_mediation(data = d, engine = "native", model = pmn_model, treatment = "x", mediator = "m"))
    expect_true(length(seen) > 0L && all(seen == "mean"))
    seen <- character()
    expect_no_error(fit_mediation(data = d, engine = "native", model = pmn_plain, treatment = "x", mediator = "m"))
    expect_true(length(seen) > 0L && all(seen == "cov"))
    expect_error(
      fit_mediation(
        data = d, engine = "native", model = pmn_model, treatment = "x", mediator = "m",
        engine_args = list(meanstructure = FALSE)
      ),
      "product models need the mean structure"
    )
    expect_no_error(fit_mediation(
      data = d, engine = "native", model = pmn_plain, treatment = "x", mediator = "m",
      engine_args = list(meanstructure = FALSE)
    ))
  })
})

test_that("a no-product model is unchanged: covariance-only by default", {
  fit <- fit_sem(pmn_plain, pmn_data(), fixed_x = FALSE, meanstructure = NULL)
  expect_false(fit@internals$ram$has_mean)
  expect_false(any(grepl("~1", names(coef(fit)), fixed = TRUE)))
})

test_that("meanstructure = FALSE with a product errors, naming the reason", {
  expect_error(
    fit_sem(pmn_model, pmn_data(), meanstructure = FALSE),
    "model has a product term \\('m:x'\\).*need the mean structure.*E\\[M \\| X = 0\\]"
  )
  expect_error(.sem_complete(.sem_parse(pmn_model)$parameters, meanstructure = FALSE), "product term")
  expect_no_error(fit_sem(pmn_plain, pmn_data(), meanstructure = FALSE))
})

test_that("the default product fit carries the mediator intercept the four-way worker needs", {
  quiet_product_advisories({
    # Extraction (U7) still refuses decomposition = "four_way" with the version-gate message on a native fit, so the
    # check is that the fit holds an estimated E[M | X = 0] intercept, which is what the worker reads.
    fit <- fit_sem(pmn_model, pmn_data())
    expect_true(fit@internals$ram$has_mean)
    expect_true(is.finite(coef(fit)[["m~1"]]))
    expect_gt(unname(sqrt(diag(vcov(fit)))[["m~1"]]), 0)
  })
})

test_that("planted defect: dropping the product trigger leaves the default fit covariance-only", {
  fx_skip_covr()
  mutant <- sem_mutate(
    .sem_complete, "isTRUE(meanstructure) || product_model || any(written)",
    "isTRUE(meanstructure) || any(written)"
  )
  tab <- mutant(.sem_parse(pmn_model)$parameters)
  expect_false("~1" %in% tab$op)
  good <- .sem_complete(.sem_parse(pmn_model)$parameters)
  expect_true("~1" %in% good$op)
})
