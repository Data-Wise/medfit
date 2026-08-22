# Tests for fit_mediation(engine = "regmedint") -- the regmedint adapter
# (Extension C). Mirrors spec section 6 acceptance criteria.

skip_if_not_installed("regmedint")

# --- Shared fixture -----------------------------------------------------------

regmedint_data <- function(n = 300, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
  d$M <- 0.5 * d$X + 0.2 * d$C + rnorm(n)
  d$Y <- 0.3 * d$X + 0.4 * d$M + 0.25 * d$X * d$M + 0.1 * d$C + rnorm(n)
  d$Yb <- rbinom(n, 1, plogis(-0.5 + 0.3 * d$X + 0.4 * d$M + 0.25 * d$X * d$M))
  d
}

# Standard errors implied by a normal-approximation confint() matrix.
ci_se <- function(ci) unname((ci[, 2] - ci[, 1]) / (2 * stats::qnorm(0.975)))

# --- Spec 6.2: no-interaction -> MediationData ---------------------------------

test_that("no-interaction formula returns MediationData matching regmedint nde/nie", {
  d <- regmedint_data()
  fit <- fit_mediation(Y ~ X + M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  ref <- regmedint::regmedint(
    data = d, yvar = "Y", avar = "X", mvar = "M", cvar = "C",
    a0 = 0, a1 = 1, m_cde = mean(d$M), c_cond = mean(d$C),
    mreg = "linear", yreg = "linear", interaction = FALSE
  )

  expect_s7_class(fit, MediationData)
  expect_false(S7::S7_inherits(fit, InteractionMediationData))
  expect_equal(fit@source_package, "regmedint")
  expect_equal(as.numeric(nde(fit)), unname(coef(ref)[["pnde"]]))
  expect_equal(as.numeric(nie(fit)), unname(coef(ref)[["pnie"]]))
  expect_equal(unname(fit@a_path), unname(coef(ref$mreg_fit)[["X"]]))
  expect_equal(unname(fit@b_path), unname(coef(ref$yreg_fit)[["M"]]))
  expect_equal(fit@n_obs, nrow(d))
  expect_true("C" %in% fit@mediator_predictors)
})

test_that("no-interaction regmedint fit agrees with the glm engine on the same model", {
  d <- regmedint_data()
  rm_fit <- fit_mediation(Y ~ X + M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  glm_fit <- fit_mediation(Y ~ X + M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "glm"
  )
  expect_equal(rm_fit@estimates, glm_fit@estimates)
  expect_equal(rm_fit@vcov, glm_fit@vcov)
})

# --- Spec 6.3: interaction -> InteractionMediationData ------------------------

test_that("X:M formula returns InteractionMediationData matching the section-3 mapping", {
  d <- regmedint_data()
  fit <- fit_mediation(Y ~ X * M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  ref <- regmedint::regmedint(
    data = d, yvar = "Y", avar = "X", mvar = "M", cvar = "C",
    a0 = 0, a1 = 1, m_cde = mean(d$M), c_cond = mean(d$C),
    mreg = "linear", yreg = "linear", interaction = TRUE
  )
  eff <- coef(ref)

  expect_s7_class(fit, InteractionMediationData)
  expect_equal(fit@source_package, "regmedint")
  expect_equal(fit@m_star, mean(d$M))
  # Section-3 mapping
  expect_equal(fit@cde, unname(eff[["cde"]]))
  expect_equal(fit@int_ref, unname(eff[["pnde"]] - eff[["cde"]]))
  expect_equal(fit@int_med, unname(eff[["tnie"]] - eff[["pnie"]]))
  expect_equal(fit@pie, unname(eff[["pnie"]]))
  expect_equal(fit@nde, unname(eff[["pnde"]]))
  expect_equal(fit@nie, unname(eff[["tnie"]]))
  expect_equal(fit@total_effect, unname(eff[["te"]]))
  # Generic methods read the same numbers
  expect_equal(as.numeric(nde(fit)), unname(eff[["pnde"]]))
  expect_equal(as.numeric(nie(fit)), unname(eff[["tnie"]]))
  expect_equal(as.numeric(te(fit)), unname(eff[["te"]]))
  # Product-form invariants hold exactly (validator), not approximately
  expect_equal(fit@pie, fit@a_path * fit@b_path)
  expect_equal(fit@int_med, fit@interaction * fit@a_path)
  expect_equal(fit@cde, fit@c_prime + fit@interaction * fit@m_star)
})

test_that("interaction case agrees with the glm engine when m_star is aligned", {
  d <- regmedint_data()
  rm_fit <- fit_mediation(Y ~ X * M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  # glm engine defaults to m_star = 0; regmedint engine uses mean(M). Align the
  # glm side via extract_mediation(m_star = ) on the same regressions.
  glm_fit <- extract_mediation(
    lm(M ~ X + C, data = d), model_y = lm(Y ~ X * M + C, data = d),
    treatment = "X", mediator = "M", data = d, m_star = mean(d$M)
  )
  expect_equal(decompose(rm_fit), decompose(glm_fit))
})

# --- Spec 6.4: component SEs from regmedint's vcov() ---------------------------

test_that("stored component SEs reproduce regmedint's reported SEs (Gaussian Y)", {
  d <- regmedint_data()
  fit <- fit_mediation(Y ~ X * M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  ref <- regmedint::regmedint(
    data = d, yvar = "Y", avar = "X", mvar = "M", cvar = "C",
    a0 = 0, a1 = 1, m_cde = mean(d$M), c_cond = mean(d$C),
    mreg = "linear", yreg = "linear", interaction = TRUE
  )
  # regmedint::vcov() is diagonal-only, so only its SEs are comparable.
  se_ref <- sqrt(diag(unclass(vcov(ref))))

  expect_message(ci <- confint(fit, parm = "components"), "delta-method")
  expect_equal(ci_se(ci)[c(1, 4)], unname(se_ref[c("cde", "pnie")]))

  ci_eff <- suppressMessages(confint(fit, parm = "effects"))
  expect_equal(ci_se(ci_eff), unname(se_ref[c("pnde", "tnie", "te")]))

  # The stored block is what confint() read, and it is a coherent covariance:
  # Var(nde) = Var(cde) + Var(int_ref) + 2 Cov(cde, int_ref).
  comp <- c("cde", "int_ref", "int_med", "pie", "nde", "nie", "total_effect")
  expect_true(all(comp %in% rownames(fit@vcov)))
  expect_true(all(comp %in% names(fit@estimates)))
  vc <- fit@vcov
  expect_equal(vc["nde", "nde"],
               vc["cde", "cde"] + vc["int_ref", "int_ref"] + 2 * vc["cde", "int_ref"])
  expect_equal(vc["nie", "nie"],
               vc["pie", "pie"] + vc["int_med", "int_med"] + 2 * vc["pie", "int_med"])
  expect_true(isSymmetric(unname(vc)))
  # Cross-covariances with the coefficient block are populated, not zero.
  expect_equal(vc["pie", "a"], vc["pie", "m_X"])
  expect_false(vc["pie", "a"] == 0)
})

test_that("Gaussian-outcome SEs coincide with medfit's own delta method (cross-check)", {
  d <- regmedint_data()
  rm_fit <- fit_mediation(Y ~ X * M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  glm_fit <- extract_mediation(
    lm(M ~ X + C, data = d), model_y = lm(Y ~ X * M + C, data = d),
    treatment = "X", mediator = "M", data = d, m_star = mean(d$M)
  )
  expect_equal(
    ci_se(suppressMessages(confint(rm_fit, parm = "components"))),
    ci_se(suppressMessages(confint(glm_fit, parm = "components")))
  )
  expect_equal(
    ci_se(suppressMessages(confint(rm_fit, parm = "effects"))),
    ci_se(suppressMessages(confint(glm_fit, parm = "effects")))
  )
})

test_that("logistic outcome with interaction maps and carries regmedint SEs", {
  d <- regmedint_data()
  fit <- fit_mediation(Yb ~ X * M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M",
    family_y = binomial(), engine = "regmedint"
  )
  ref <- regmedint::regmedint(
    data = d, yvar = "Yb", avar = "X", mvar = "M", cvar = "C",
    a0 = 0, a1 = 1, m_cde = mean(d$M), c_cond = mean(d$C),
    mreg = "linear", yreg = "logistic", interaction = TRUE
  )
  expect_s7_class(fit, InteractionMediationData)
  expect_equal(fit@cde, unname(coef(ref)[["cde"]]))
  expect_equal(fit@nde, unname(coef(ref)[["pnde"]]))
  expect_equal(fit@nie, unname(coef(ref)[["tnie"]]))
  expect_null(fit@sigma_y)
  # SE parity on every quantity regmedint reports -- this is the path where
  # the sigma^2 terms of the log-link delta method matter.
  se_ref <- sqrt(diag(unclass(vcov(ref))))
  ci <- suppressMessages(confint(fit, parm = "effects"))
  expect_equal(ci_se(ci), unname(se_ref[c("pnde", "tnie", "te")]))
  ci_c <- suppressMessages(confint(fit, parm = "components"))
  expect_equal(ci_se(ci_c)[c(1, 4)], unname(se_ref[c("cde", "pnie")]))
})

# --- Class selection / engine_args overrides -----------------------------------

test_that("engine_args$interaction overrides formula-based auto-detection", {
  d <- regmedint_data()
  forced_off <- fit_mediation(Y ~ X * M, M ~ X,
    data = d, treatment = "X", mediator = "M", engine = "regmedint",
    engine_args = list(interaction = FALSE)
  )
  expect_s7_class(forced_off, MediationData)
  expect_false(S7::S7_inherits(forced_off, InteractionMediationData))

  forced_on <- fit_mediation(Y ~ X + M, M ~ X,
    data = d, treatment = "X", mediator = "M", engine = "regmedint",
    engine_args = list(interaction = TRUE)
  )
  expect_s7_class(forced_on, InteractionMediationData)
})

test_that("engine_args m_cde / c_cond / cvar overrides reach regmedint", {
  d <- regmedint_data()
  fit <- fit_mediation(Y ~ X * M + C, M ~ X + C,
    data = d, treatment = "X", mediator = "M", engine = "regmedint",
    engine_args = list(m_cde = 1, c_cond = 0.5)
  )
  ref <- regmedint::regmedint(
    data = d, yvar = "Y", avar = "X", mvar = "M", cvar = "C",
    a0 = 0, a1 = 1, m_cde = 1, c_cond = 0.5,
    mreg = "linear", yreg = "linear", interaction = TRUE
  )
  expect_equal(fit@m_star, 1)
  expect_equal(fit@cde, unname(coef(ref)[["cde"]]))
  expect_equal(fit@int_ref, unname(coef(ref)[["pnde"]] - coef(ref)[["cde"]]))

  # cvar override narrows the covariate set (formula_m must agree)
  fit2 <- fit_mediation(Y ~ X + M, M ~ X,
    data = d, treatment = "X", mediator = "M", engine = "regmedint",
    engine_args = list(cvar = character(0))
  )
  expect_s7_class(fit2, MediationData)
})

test_that("interaction without covariates works", {
  d <- regmedint_data()
  fit <- fit_mediation(Y ~ X * M, M ~ X,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  expect_s7_class(fit, InteractionMediationData)
  expect_equal(fit@outcome_predictors, c("X", "M", "X:M"))
})

test_that("rows with missing values are dropped (glm-engine parity)", {
  d <- regmedint_data()
  d$Y[1:5] <- NA
  fit <- fit_mediation(Y ~ X + M, M ~ X,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  expect_equal(fit@n_obs, nrow(d) - 5L)
  expect_equal(nrow(fit@data), nrow(d) - 5L)
})

# --- Spec 6.5: non-binary treatment -> clear error -----------------------------

test_that("continuous or factor treatment without a0/a1 override errors clearly", {
  d <- regmedint_data()
  d$Xc <- rnorm(nrow(d))
  d$Xf <- factor(d$X)
  expect_error(
    fit_mediation(Y ~ Xc + M, M ~ Xc,
      data = d, treatment = "Xc", mediator = "M", engine = "regmedint"
    ),
    "numeric 0/1"
  )
  expect_error(
    fit_mediation(Y ~ Xf + M, M ~ Xf,
      data = d, treatment = "Xf", mediator = "M", engine = "regmedint"
    ),
    "numeric 0/1"
  )
})

test_that("a0/a1 overrides outside the representable contrast error clearly", {
  d <- regmedint_data()
  expect_error(
    fit_mediation(Y ~ X * M, M ~ X,
      data = d, treatment = "X", mediator = "M", engine = "regmedint",
      engine_args = list(a0 = 1, a1 = 2)
    ),
    "a0 = 0, a1 = 1"
  )
  expect_error(
    fit_mediation(Y ~ X + M, M ~ X,
      data = d, treatment = "X", mediator = "M", engine = "regmedint",
      engine_args = list(a0 = 0, a1 = 2)
    ),
    "unit contrast"
  )
  expect_error(
    fit_mediation(Y ~ X + M, M ~ X,
      data = d, treatment = "X", mediator = "M", engine = "regmedint",
      engine_args = list(a0 = 0)
    ),
    "supplied together"
  )
})

# --- Other guard rails --------------------------------------------------------

test_that("logistic mediator model is refused as not representable", {
  d <- regmedint_data()
  d$Mb <- rbinom(nrow(d), 1, plogis(d$M))
  expect_error(
    fit_mediation(Y ~ X + Mb, Mb ~ X,
      data = d, treatment = "X", mediator = "Mb",
      family_m = binomial(), engine = "regmedint"
    ),
    "linear \\(Gaussian\\) mediator"
  )
})

test_that("unmappable family, unknown engine_args, dots, weights, sandwich all error", {
  d <- regmedint_data()
  base <- list(formula_y = Y ~ X + M, formula_m = M ~ X, data = d,
               treatment = "X", mediator = "M", engine = "regmedint")
  expect_error(do.call(fit_mediation, c(base, list(family_y = Gamma()))),
               "engine_args = list\\(yreg")
  expect_error(do.call(fit_mediation, c(base, list(engine_args = list(foo = 1)))),
               "Unrecognized `engine_args`")
  expect_error(do.call(fit_mediation, c(base, list(control = list()))),
               "does not accept additional arguments")
  expect_error(do.call(fit_mediation, c(base, list(weights = rep(1, nrow(d))))),
               "does not support `weights`")
  expect_error(do.call(fit_mediation, c(base, list(se_type = "sandwich"))),
               "se_type = \"model\" only")
})

test_that("formula shapes regmedint cannot express are refused", {
  d <- regmedint_data()
  # mediator-model covariates must match the outcome model's
  expect_error(
    fit_mediation(Y ~ X + M + C, M ~ X,
      data = d, treatment = "X", mediator = "M", engine = "regmedint"
    ),
    "same covariates"
  )
  # transformed covariate terms are not data columns
  expect_error(
    fit_mediation(Y ~ X + M + log(abs(C)), M ~ X + log(abs(C)),
      data = d, treatment = "X", mediator = "M", engine = "regmedint"
    ),
    "main-effect covariate"
  )
  # factor covariates
  d$G <- factor(sample(c("a", "b"), nrow(d), TRUE))
  expect_error(
    fit_mediation(Y ~ X + M + G, M ~ X + G,
      data = d, treatment = "X", mediator = "M", engine = "regmedint"
    ),
    "numeric covariates"
  )
})

test_that("print works for both regmedint-sourced classes", {
  d <- regmedint_data()
  simple <- fit_mediation(Y ~ X + M, M ~ X,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  inter <- fit_mediation(Y ~ X * M, M ~ X,
    data = d, treatment = "X", mediator = "M", engine = "regmedint"
  )
  expect_output(print(simple), "MediationData")
  expect_output(print(inter), "InteractionMediationData")
})
