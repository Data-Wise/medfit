# Sample size under missing values: n_obs and @data describe the rows the
# models used, not the rows supplied. The planted missing values below make
# nrow(data) (the old n_obs) differ from the fitted sample size.

sim_missing <- function(n = 200, seed = 4) {
  set.seed(seed)
  X <- rnorm(n)
  C <- rnorm(n)
  M1 <- 0.5 * X + 0.2 * C + rnorm(n)
  M2 <- 0.4 * X + 0.3 * M1 + rnorm(n)
  Y <- 0.6 * M1 + 0.3 * M2 + 0.2 * X + 0.1 * C + rnorm(n)
  data.frame(X, C, M1, M2, Y)
}

# One NA on the treatment in 5 rows, one on a covariate in 2 more rows.
plant_missing <- function(d) {
  d$X[1:5] <- NA
  d$C[6:7] <- NA
  d
}

test_that("fit_mediation() reports the rows the glm fits used", {
  d <- plant_missing(sim_missing())
  fit <- fit_mediation(Y ~ X + M1 + C, M1 ~ X + C,
    data = d, treatment = "X", mediator = "M1"
  )
  n_lm <- stats::nobs(stats::lm(Y ~ X + M1 + C, d))

  expect_equal(n_lm, 193L)
  expect_equal(fit@n_obs, n_lm)
  expect_equal(stats::nobs(fit), n_lm)
  expect_equal(nrow(fit@data), n_lm)
  expect_false(anyNA(fit@data[c("X", "M1", "C", "Y")]))
})

test_that("the estimates are those of the complete-case fit", {
  d <- plant_missing(sim_missing())
  fit_na <- fit_mediation(Y ~ X + M1 + C, M1 ~ X + C,
    data = d, treatment = "X", mediator = "M1"
  )
  fit_cc <- fit_mediation(Y ~ X + M1 + C, M1 ~ X + C,
    data = d[stats::complete.cases(d[c("X", "M1", "C", "Y")]), ],
    treatment = "X", mediator = "M1"
  )
  expect_equal(fit_na@estimates, fit_cc@estimates)
  expect_equal(fit_na@n_obs, fit_cc@n_obs)
})

test_that("a variable in only one formula leaves both models on the same rows", {
  d <- sim_missing()
  d$C[1:9] <- NA # C is in the outcome formula only
  fit <- fit_mediation(Y ~ X + M1 + C, M1 ~ X,
    data = d, treatment = "X", mediator = "M1"
  )
  expect_equal(fit@n_obs, 191L)
  expect_equal(nrow(fit@data), 191L)
  # The mediator model used the same 191 rows, not all 200.
  fit_cc <- fit_mediation(Y ~ X + M1 + C, M1 ~ X,
    data = d[!is.na(d$C), ], treatment = "X", mediator = "M1"
  )
  expect_equal(fit@estimates, fit_cc@estimates)
})

test_that("case weights follow the rows that are kept", {
  d <- plant_missing(sim_missing())
  w <- seq_len(nrow(d)) / nrow(d) + 0.5
  fit <- fit_mediation(Y ~ X + M1 + C, M1 ~ X + C,
    data = d, treatment = "X", mediator = "M1", weights = w
  )
  keep <- stats::complete.cases(d[c("X", "M1", "C", "Y")])
  fit_cc <- fit_mediation(Y ~ X + M1 + C, M1 ~ X + C,
    data = d[keep, ], treatment = "X", mediator = "M1", weights = w[keep]
  )
  expect_equal(fit@n_obs, sum(keep))
  expect_equal(fit@estimates, fit_cc@estimates)
})

test_that("fit_mediation() stops when no complete row remains", {
  d <- sim_missing()
  d$X <- NA_real_
  expect_error(
    fit_mediation(Y ~ X + M1, M1 ~ X, data = d, treatment = "X", mediator = "M1"),
    "No complete rows"
  )
})

test_that("the four-way decomposition uses the rows the fits used", {
  d <- plant_missing(sim_missing())
  fit <- fit_mediation(Y ~ X * M1 + C, M1 ~ X + C,
    data = d, treatment = "X", mediator = "M1"
  )
  expect_s7_class(fit, InteractionMediationData)
  expect_equal(fit@n_obs, 193L)
  expect_equal(nrow(fit@data), 193L)
})

test_that("extract_mediation() drops the rows the user's models dropped", {
  d <- plant_missing(sim_missing())
  fm <- stats::lm(M1 ~ X + C, d)
  fy <- stats::lm(Y ~ X + M1 + C, d)

  simple <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M1", data = d)
  expect_equal(simple@n_obs, 193L)
  expect_equal(nrow(simple@data), 193L)

  # Without `data` the model frame is used, and gives the same n.
  expect_equal(
    extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M1")@n_obs,
    193L
  )

  # na.exclude pads residuals() back to full length; n must not follow it.
  fm_ex <- stats::lm(M1 ~ X + C, d, na.action = stats::na.exclude)
  fy_ex <- stats::lm(Y ~ X + M1 + C, d, na.action = stats::na.exclude)
  expect_equal(
    extract_mediation(fm_ex, model_y = fy_ex, treatment = "X", mediator = "M1", data = d)@n_obs,
    193L
  )

  # Multi-mediator structures.
  fm2 <- stats::lm(M1 ~ X + C, d)
  par <- extract_mediation(fm2,
    model_y = stats::lm(Y ~ X + M1 + M2 + C, d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(stats::lm(M2 ~ X + C, d)),
    structure = "parallel", data = d
  )
  expect_equal(par@n_obs, 193L)
  expect_equal(nrow(par@data), 193L)

  ser <- extract_mediation(fm2,
    model_y = stats::lm(Y ~ X + M1 + M2 + C, d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(stats::lm(M2 ~ X + M1 + C, d)),
    structure = "serial", data = d
  )
  expect_equal(ser@n_obs, 193L)
  expect_equal(nrow(ser@data), 193L)
})

test_that("extract_mediation() warns when the models used different rows", {
  d <- sim_missing()
  d$C[1:9] <- NA
  fm <- stats::lm(M1 ~ X, d)
  fy <- stats::lm(Y ~ X + M1 + C, d)
  expect_warning(
    ex <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M1", data = d),
    "different sets of rows"
  )
  expect_equal(ex@n_obs, 191L)
})

test_that("complete data keeps n_obs = nrow(data) and the data untouched", {
  d <- sim_missing()
  fit <- fit_mediation(Y ~ X + M1 + C, M1 ~ X + C,
    data = d, treatment = "X", mediator = "M1"
  )
  expect_equal(fit@n_obs, nrow(d))
  expect_equal(fit@data, d, ignore_attr = TRUE)
})

test_that("med() reports the rows used", {
  d <- plant_missing(sim_missing())
  names(d)[names(d) == "M1"] <- "M"
  fit <- med(d, treatment = "X", mediator = "M", outcome = "Y", covariates = "C")
  expect_equal(stats::nobs(fit), 193L)
})

test_that("the native engine reports the rows it used", {
  d <- plant_missing(sim_missing())
  model <- "M1 ~ a*X + C\nY ~ b*M1 + cp*X + C\nnie := a*b"
  fit <- fit_mediation(
    data = d, treatment = "X", mediator = "M1", engine = "native", model = model
  )
  expect_equal(fit@n_obs, 193L)
  expect_equal(nrow(fit@data), 193L)
})

test_that("the lmer engine reports the rows it used", {
  skip_if_not_installed("lme4")
  skip_if_not_installed("pbkrtest")
  set.seed(8)
  g <- rep(1:30, each = 8)
  d <- data.frame(g = g, X = (g %% 2), C = rnorm(240))
  d$M1 <- 0.5 * d$X + rnorm(30)[g] * 0.5 + rnorm(240)
  d$Y <- 0.4 * d$M1 + 0.2 * d$X + rnorm(30)[g] * 0.5 + rnorm(240)
  d$C[c(3, 90)] <- NA
  d$M1[17] <- NA
  fit <- suppressMessages(suppressWarnings(fit_mediation(
    Y ~ X + M1 + C, M1 ~ X + C,
    data = d, treatment = "X", mediator = "M1", engine = "lmer", cluster = "g"
  )))
  expect_equal(fit@n_obs, 237L)
})
