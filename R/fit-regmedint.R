# Fit Mediation Models Using the regmedint Engine
#
# This file implements the `engine = "regmedint"` adapter for fit_mediation():
# a translation layer from medfit's formula-based interface to
# regmedint::regmedint(), returning MediationData or InteractionMediationData.
#
# See planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md.

#' regmedint Engine for Mediation Fitting
#'
#' @description
#' Adapter from `fit_mediation()`'s formula interface to
#' `regmedint::regmedint()`. Dispatched from `fit_mediation()` when
#' `engine = "regmedint"`.
#'
#' The adapter (1) derives regmedint's arguments from the formulas, families,
#' and data (`engine_args` overrides any of them), (2) fits via
#' `regmedint::regmedint()`, and (3) maps the result onto medfit's classes:
#' [InteractionMediationData] when the outcome model carries a
#' treatment-by-mediator interaction, [MediationData] otherwise.
#'
#' ## Representability
#'
#' medfit's classes define the indirect effect as a product of regression
#' coefficients (`nie() = a * b`; `pie = b * a`, `int_med = theta3 * a`).
#' regmedint's closed-form effects coincide with those products only for a
#' **linear mediator model** and a **unit treatment contrast** (`a0 = 0`,
#' `a1 = 1` with an interaction; `a1 - a0 = 1` without). The adapter checks
#' these conditions and errors with guidance otherwise rather than returning an
#' object whose validator would reject the numbers (or, worse, one whose
#' `nie()` silently disagrees with regmedint).
#'
#' ## Standard errors
#'
#' For the interaction case the four-way components and the derived
#' NDE/NIE/TE are appended to `@estimates`, with their full covariance (and
#' the cross-covariances with the regression coefficients) appended to
#' `@vcov`; `confint()` uses that block when present. `regmedint::vcov()`
#' reports variances only, so the block is computed by reproducing
#' regmedint's own delta method over `(beta, theta, sigma^2)` -- see
#' `.regmedint_component_vcov()`. Its diagonal equals regmedint's reported
#' SEs for `cde`, `pnie`, `pnde`, `tnie`, `te`.
#'
#' @param formula_y Outcome model formula
#' @param formula_m Mediator model formula
#' @param data Data frame
#' @param treatment Treatment variable name
#' @param mediator Mediator variable name
#' @param family_y Family for outcome model
#' @param family_m Family for mediator model
#' @param engine_args Named list of regmedint-specific overrides:
#'   `interaction`, `cvar`, `mreg`, `yreg`, `a0`, `a1`, `m_cde`, `c_cond`.
#' @param ... Must be empty; regmedint takes no pass-through arguments.
#'
#' @return A MediationData or InteractionMediationData object
#' @keywords internal
#' @noRd
.adapter_regmedint <- function(formula_y,
                               formula_m,
                               data,
                               treatment,
                               mediator,
                               family_y,
                               family_m,
                               engine_args = list(),
                               ...) {
  if (!requireNamespace("regmedint", quietly = TRUE)) {
    stop(
      "engine = \"regmedint\" requires the 'regmedint' package. ",
      "Install it with install.packages(\"regmedint\").",
      call. = FALSE
    )
  }
  dots <- list(...)
  if (length(dots) > 0) {
    stop(
      "engine = \"regmedint\" does not accept additional arguments via `...` ",
      "(got: ", paste(names(dots), collapse = ", "), "). ",
      "Use `engine_args` for regmedint-specific settings.",
      call. = FALSE
    )
  }
  known <- c("interaction", "cvar", "mreg", "yreg", "a0", "a1", "m_cde", "c_cond")
  unknown <- setdiff(names(engine_args), known)
  if (length(unknown) > 0) {
    stop(
      "Unrecognized `engine_args` for engine = \"regmedint\": ",
      paste(unknown, collapse = ", "), ". Recognized names: ",
      paste(known, collapse = ", "), ".",
      call. = FALSE
    )
  }

  spec <- .regmedint_build_args(
    formula_y = formula_y, formula_m = formula_m, data = data,
    treatment = treatment, mediator = mediator,
    family_y = family_y, family_m = family_m, engine_args = engine_args
  )
  fit <- do.call(regmedint::regmedint, spec$args)

  if (spec$has_interaction) {
    .regmedint_to_interaction_mediation_data(fit, spec)
  } else {
    .regmedint_to_mediation_data(fit, spec)
  }
}


#' Derive regmedint() arguments from fit_mediation()'s inputs
#'
#' Implements the spec's argument-bridging table: every regmedint argument is
#' auto-derived from the formulas / families / data, and any entry of
#' `engine_args` replaces the derived value. Ends with the representability
#' check described in `.adapter_regmedint()`.
#'
#' @return A list with `args` (ready for `do.call(regmedint::regmedint, .)`),
#'   `has_interaction`, `int_term`, `cvar`, `data` (complete cases on the
#'   variables used), `outcome`, `treatment`, `mediator`.
#' @keywords internal
#' @noRd
.regmedint_build_args <- function(formula_y, formula_m, data, treatment, mediator,
                                  family_y, family_m, engine_args) {
  # --- Variables from the formulas ---
  outcome <- all.vars(formula_y[[2]])
  if (length(outcome) != 1L) {
    stop("formula_y must have a single response variable.", call. = FALSE)
  }
  if (!identical(all.vars(formula_m[[2]]), mediator)) {
    stop(sprintf("formula_m must have the mediator '%s' as its response.", mediator),
         call. = FALSE)
  }
  labs_y <- attr(stats::terms(formula_y), "term.labels")
  labs_m <- attr(stats::terms(formula_m), "term.labels")
  int_term <- .find_interaction_term_formula(formula_y, treatment, mediator)

  # --- interaction: auto-detect from formula_y, engine_args overrides ---
  has_interaction <- if ("interaction" %in% names(engine_args)) {
    checkmate::assert_flag(engine_args$interaction, .var.name = "engine_args$interaction")
    engine_args$interaction
  } else {
    !is.na(int_term)
  }

  # --- cvar: remaining main-effect terms of formula_y ---
  cvar <- if ("cvar" %in% names(engine_args)) {
    checkmate::assert_character(engine_args$cvar, any.missing = FALSE, null.ok = TRUE,
                                .var.name = "engine_args$cvar")
    as.character(engine_args$cvar)
  } else {
    setdiff(labs_y, c(treatment, mediator, int_term))
  }
  not_cols <- setdiff(cvar, names(data))
  if (length(not_cols) > 0) {
    stop(
      "engine = \"regmedint\" supports only main-effect covariate terms that ",
      "are columns of `data`; formula_y contains: ",
      paste(not_cols, collapse = ", "), ".",
      call. = FALSE
    )
  }
  non_num <- cvar[!vapply(data[cvar], is.numeric, logical(1))]
  if (length(non_num) > 0) {
    stop(
      "regmedint requires numeric covariates; convert to 0/1 indicator columns: ",
      paste(non_num, collapse = ", "), ".",
      call. = FALSE
    )
  }
  expected_m <- c(treatment, cvar)
  if (!setequal(labs_m, expected_m)) {
    stop(
      "regmedint fits the mediator model with the same covariates as the ",
      "outcome model. Expected formula_m terms: ",
      paste(expected_m, collapse = " + "), "; found: ",
      paste(labs_m, collapse = " + "), ".",
      call. = FALSE
    )
  }

  # --- mreg / yreg from the family objects ---
  mreg <- .regmedint_reg_type(family_m, engine_args$mreg, "mreg")
  yreg <- .regmedint_reg_type(family_y, engine_args$yreg, "yreg")

  # --- Complete cases on the variables actually used (glm-engine parity) ---
  used <- c(outcome, treatment, mediator, cvar)
  cc <- stats::complete.cases(data[used])
  if (!any(cc)) {
    stop("No complete cases on the variables used by the mediation model.",
         call. = FALSE)
  }
  data_cc <- data[cc, , drop = FALSE]

  # --- a0 / a1: 0/1 for a numeric 0/1 treatment, otherwise explicit error ---
  has_a0 <- "a0" %in% names(engine_args)
  has_a1 <- "a1" %in% names(engine_args)
  if (has_a0 != has_a1) {
    stop("engine_args `a0` and `a1` must be supplied together.", call. = FALSE)
  }
  if (has_a0) {
    checkmate::assert_number(engine_args$a0, .var.name = "engine_args$a0")
    checkmate::assert_number(engine_args$a1, .var.name = "engine_args$a1")
    a0 <- engine_args$a0
    a1 <- engine_args$a1
  } else {
    x <- data_cc[[treatment]]
    if (!(is.numeric(x) && all(x %in% c(0, 1)))) {
      stop(
        sprintf("Treatment '%s' must be a numeric 0/1 variable for engine = \"regmedint\" ", treatment),
        sprintf("(found %s with %d distinct values). ", class(x)[1], length(unique(x))),
        "Recode it as 0/1, or pass engine_args = list(a0 = <control>, a1 = <treated>).",
        call. = FALSE
      )
    }
    a0 <- 0
    a1 <- 1
  }

  .regmedint_check_representable(a0, a1, mreg, has_interaction)

  # --- m_cde / c_cond: evaluation points for the CDE ---
  # m_cde defaults to 0, matching the `m_star = 0` default of both other
  # extractors (R/extract-lm.R, R/extract-lavaan.R) so all three engines report
  # the CDE/INTref split at the same reference level. c_cond keeps the sample
  # means, which is also what the lm extractor uses for E[M | X = 0].
  m_cde <- if ("m_cde" %in% names(engine_args)) {
    checkmate::assert_number(engine_args$m_cde, .var.name = "engine_args$m_cde")
    engine_args$m_cde
  } else {
    0
  }
  c_cond <- if ("c_cond" %in% names(engine_args)) {
    checkmate::assert_numeric(engine_args$c_cond, len = length(cvar), any.missing = FALSE,
                              null.ok = length(cvar) == 0L, .var.name = "engine_args$c_cond")
    engine_args$c_cond
  } else if (length(cvar) > 0) {
    unname(colMeans(data_cc[cvar]))
  } else {
    NULL
  }

  args <- list(
    data = data_cc,
    yvar = outcome,
    avar = treatment,
    mvar = mediator,
    cvar = if (length(cvar) > 0) cvar else NULL,
    a0 = a0,
    a1 = a1,
    m_cde = m_cde,
    c_cond = c_cond,
    mreg = mreg,
    yreg = yreg,
    interaction = has_interaction,
    casecontrol = FALSE,
    na_omit = FALSE
  )

  list(
    args = args,
    has_interaction = has_interaction,
    int_term = int_term,
    cvar = cvar,
    data = data_cc,
    outcome = outcome,
    treatment = treatment,
    mediator = mediator
  )
}


#' Map a stats family to a regmedint model-type string
#' @keywords internal
#' @noRd
.regmedint_reg_type <- function(family, override, which = c("mreg", "yreg")) {
  which <- match.arg(which)
  if (!is.null(override)) {
    checkmate::assert_string(override, .var.name = paste0("engine_args$", which))
    return(override)
  }
  fam <- if (is.character(family)) family else family$family
  # regmedint pairs a linear mediator model with linear or logistic outcome
  # models only; other regmedint yreg types need a different mreg.
  map <- c(gaussian = "linear", binomial = "logistic")
  if (!fam %in% names(map)) {
    stop(
      sprintf("Cannot map family '%s' to a regmedint %s type ", fam, which),
      sprintf("(auto-mapped families: %s). ", paste(names(map), collapse = ", ")),
      sprintf("Pass engine_args = list(%s = \"<regmedint type>\").", which),
      call. = FALSE
    )
  }
  unname(map[[fam]])
}


#' Representability check: can regmedint's effects live in medfit's classes?
#' @keywords internal
#' @noRd
.regmedint_check_representable <- function(a0, a1, mreg, has_interaction) { # nolint: object_length_linter.
  if (!identical(mreg, "linear")) {
    stop(
      "engine = \"regmedint\" can return MediationData / InteractionMediationData ",
      "only for a linear (Gaussian) mediator model: regmedint's closed-form effects ",
      sprintf("for mreg = \"%s\" are not products of regression coefficients, ", mreg),
      "which is what medfit's nie() / pie compute. ",
      "Call regmedint::regmedint() directly for this model.",
      call. = FALSE
    )
  }
  if (has_interaction && !(a0 == 0 && a1 == 1)) {
    stop(
      "InteractionMediationData's four-way components are defined for the unit ",
      "treatment contrast a0 = 0, a1 = 1 (regmedint's PNIE = (theta2*beta1 + ",
      "theta3*beta1*a0)*(a1 - a0) equals b * a only there). ",
      sprintf("Got a0 = %s, a1 = %s. ", format(a0), format(a1)),
      "Recode the treatment to 0/1, or call regmedint::regmedint() directly.",
      call. = FALSE
    )
  }
  if (!has_interaction && !isTRUE(all.equal(a1 - a0, 1))) {
    stop(
      "MediationData's effects are per unit of treatment; regmedint scales its ",
      sprintf("effects by (a1 - a0) = %s. ", format(a1 - a0)),
      "Use a unit contrast (a1 - a0 = 1), or call regmedint::regmedint() directly.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}


#' regmedint fit (no interaction) -> MediationData
#'
#' regmedint's natural effects without an interaction are exactly the
#' product-of-coefficients quantities medfit computes live (`nde = c'`,
#' `nie = a * b`), so the object is built from regmedint's own fitted
#' `lm`/`glm` models through the existing lm/glm extractor.
#' @keywords internal
#' @noRd
.regmedint_to_mediation_data <- function(fit, spec) {
  obj <- extract_mediation(
    fit$mreg_fit,
    model_y = fit$yreg_fit,
    treatment = spec$treatment,
    mediator = spec$mediator,
    outcome = spec$outcome,
    data = spec$data,
    decomposition = "two_way"
  )
  eff <- .regmedint_effects(fit)
  .regmedint_assert_mapping(
    c(nde = unname(obj@c_prime), nie = unname(obj@a_path * obj@b_path)),
    c(nde = eff[["pnde"]], nie = eff[["pnie"]])
  )
  obj@source_package <- "regmedint"
  obj
}


#' regmedint fit (with interaction) -> InteractionMediationData
#'
#' Four-way mapping (spec section 3): `cde = cde`, `int_ref = pnde - cde`,
#' `int_med = tnie - pnie`, `pie = pnie`, `nde = pnde`, `nie = tnie`,
#' `total_effect = te`, `m_star = m_cde`. The component covariance is the
#' linear map of regmedint's `vcov()`.
#' @keywords internal
#' @noRd
.regmedint_to_interaction_mediation_data <- function(fit, spec) { # nolint: object_length_linter.
  model_m <- fit$mreg_fit
  model_y <- fit$yreg_fit
  treatment <- spec$treatment
  mediator <- spec$mediator
  int_term <- .find_interaction_term(model_y, treatment, mediator)
  if (is.na(int_term)) {
    stop("Internal error: regmedint outcome model has no interaction term.",
         call. = FALSE)
  }

  coef_m <- stats::coef(model_m)
  coef_y <- stats::coef(model_y)
  beta0  <- if ("(Intercept)" %in% names(coef_m)) unname(coef_m[["(Intercept)"]]) else 0
  beta1  <- unname(coef_m[[treatment]])
  theta1 <- unname(coef_y[[treatment]])
  theta2 <- unname(coef_y[[mediator]])
  theta3 <- unname(coef_y[[int_term]])
  m_star <- spec$args$m_cde

  eff <- .regmedint_effects(fit)
  cde     <- eff[["cde"]]
  pie     <- eff[["pnie"]]
  int_med <- eff[["tnie"]] - eff[["pnie"]]
  int_ref <- eff[["pnde"]] - eff[["cde"]]
  nde     <- eff[["pnde"]]
  nie     <- eff[["tnie"]]
  total   <- eff[["te"]]

  # Product-form identities the class validator enforces; any mismatch here is
  # a mapping bug (or a representability gap), never a tolerance issue.
  .regmedint_assert_mapping(
    c(cde = theta1 + theta3 * m_star, int_med = theta3 * beta1, pie = theta2 * beta1),
    c(cde = cde, int_med = int_med, pie = pie)
  )

  # --- Regression-coefficient block + path aliases (lm-extractor layout) ---
  names_m <- paste0("m_", names(coef_m))
  names_y <- paste0("y_", names(coef_y))
  estimates <- stats::setNames(c(coef_m, coef_y), c(names_m, names_y))
  n_m <- length(coef_m)
  n_src <- n_m + length(coef_y)
  vcov_src <- matrix(0, n_src, n_src, dimnames = list(names(estimates), names(estimates)))
  vcov_src[seq_len(n_m), seq_len(n_m)] <- stats::vcov(model_m)
  vcov_src[(n_m + 1):n_src, (n_m + 1):n_src] <- stats::vcov(model_y)

  alias_src <- c(
    a = paste0("m_", treatment),
    b = paste0("y_", mediator),
    c_prime = paste0("y_", treatment),
    theta3 = paste0("y_", int_term)
  )
  alias_val <- c(a = beta1, b = theta2, c_prime = theta1, theta3 = theta3)
  if ("(Intercept)" %in% names(coef_m)) {
    alias_src["b0"] <- "m_(Intercept)"
    alias_val["b0"] <- beta0
  }
  source_idx <- vapply(alias_src, function(nm) match(nm, rownames(vcov_src)), integer(1))
  estimates[names(alias_val)] <- alias_val
  vcov_coef <- .expand_vcov_with_aliases(
    vcov_src, source_idx = source_idx, aliases_to_add = names(alias_src)
  )

  # --- Component block: linear map of regmedint's delta-method vcov ---
  comp <- c(cde = cde, int_ref = int_ref, int_med = int_med, pie = pie,
            nde = nde, nie = nie, total_effect = total)
  cv <- .regmedint_component_vcov(
    model_m, model_y, treatment = treatment, mediator = mediator,
    int_term = int_term, cvar = spec$cvar, m_star = m_star,
    c_cond = spec$args$c_cond, yreg = spec$args$yreg
  )
  estimates <- c(estimates, comp)
  n_coef <- nrow(vcov_coef)
  n_all <- n_coef + length(comp)
  vcov_all <- matrix(0, n_all, n_all, dimnames = list(names(estimates), names(estimates)))
  vcov_all[seq_len(n_coef), seq_len(n_coef)] <- vcov_coef
  vcov_all[(n_coef + 1):n_all, (n_coef + 1):n_all] <- cv$comp
  # Cross-covariances: each coefficient-block column (original or alias) maps
  # to one stacked source parameter.
  src_of <- stats::setNames(rownames(vcov_coef), rownames(vcov_coef))
  src_of[names(alias_src)] <- unname(alias_src)
  cross <- cv$cross[, unname(src_of), drop = FALSE]
  vcov_all[(n_coef + 1):n_all, seq_len(n_coef)] <- cross
  vcov_all[seq_len(n_coef), (n_coef + 1):n_all] <- t(cross)

  # --- Metadata ---
  converged <- (if (inherits(model_m, "glm")) isTRUE(model_m$converged) else TRUE) &&
    (if (inherits(model_y, "glm")) isTRUE(model_y$converged) else TRUE)

  InteractionMediationData(
    a_path = beta1, b_path = theta2, c_prime = theta1, interaction = theta3,
    cde = cde, int_ref = int_ref, int_med = int_med, pie = pie,
    nde = nde, nie = nie, total_effect = total, m_star = m_star,
    estimates = estimates, vcov = vcov_all,
    sigma_m = .extract_sigma(model_m), sigma_y = .extract_sigma(model_y),
    treatment = treatment, mediator = mediator, outcome = spec$outcome,
    mediator_predictors = names(coef_m)[names(coef_m) != "(Intercept)"],
    outcome_predictors = names(coef_y)[names(coef_y) != "(Intercept)"],
    data = spec$data, n_obs = as.integer(nrow(spec$data)),
    converged = converged, source_package = "regmedint"
  )
}


#' regmedint point estimates as a plain named numeric vector
#' @keywords internal
#' @noRd
.regmedint_effects <- function(fit) {
  eff <- stats::coef(fit)
  stats::setNames(as.numeric(eff), names(eff))
}


#' Component covariance: regmedint's delta method, reproduced in full
#'
#' `regmedint::vcov()` reports variances only (its off-diagonal entries are
#' `NA`), so the `Var(int_ref) = Var(pnde) + Var(cde) - 2 Cov(pnde, cde)`
#' route of the spec is not available. This helper instead applies the same
#' delta method regmedint uses internally -- over the parameter vector
#' `(beta, theta, sigma^2)` with `Sigma = bdiag(vcov(mreg), vcov(yreg),
#' 2 sigma^4 / df)` -- to the four-way components directly. The gradients below
#' are regmedint's `Gamma_pnde - Gamma_cde`, `Gamma_tnie - Gamma_pnie`, etc.
#' specialized to the representable case (`a0 = 0`, `a1 = 1`, linear mediator
#' model, no exposure-covariate interactions). `kappa` switches on the
#' `sigma^2` terms that appear for log-link outcomes (logistic / poisson);
#' they vanish for a linear outcome. The diagonal therefore reproduces
#' regmedint's reported SEs for `cde`, `pnie`, `pnde`, `tnie`, `te` exactly
#' (tested), while also supplying the `int_ref` / `int_med` entries and every
#' cross-covariance.
#'
#' @return A list: `comp` (7x7 covariance of `cde, int_ref, int_med, pie, nde,
#'   nie, total_effect`) and `cross` (7 x p covariance between those components
#'   and the stacked regression coefficients named `m_*` / `y_*`).
#' @keywords internal
#' @noRd
.regmedint_component_vcov <- function(model_m, model_y, treatment, mediator, int_term,
                                      cvar, m_star, c_cond, yreg) {
  coef_m <- stats::coef(model_m)
  coef_y <- stats::coef(model_y)
  names_m <- paste0("m_", names(coef_m))
  names_y <- paste0("y_", names(coef_y))
  pnames <- c(names_m, names_y, "sigma_sq")
  n_m <- length(coef_m)
  n_y <- length(coef_y)

  # --- Sigma = bdiag(vcov(mreg), vcov(yreg), Var(sigma^2)) ---
  sigma_sq <- stats::sigma(model_m)^2
  sigma_mat <- matrix(0, length(pnames), length(pnames), dimnames = list(pnames, pnames))
  sigma_mat[seq_len(n_m), seq_len(n_m)] <- stats::vcov(model_m)
  sigma_mat[n_m + seq_len(n_y), n_m + seq_len(n_y)] <- stats::vcov(model_y)
  sigma_mat["sigma_sq", "sigma_sq"] <- 2 * sigma_sq^2 / model_m$df.residual

  # --- Coefficients (VanderWeele notation) ---
  has_b0 <- "(Intercept)" %in% names(coef_m)
  beta0  <- if (has_b0) unname(coef_m[["(Intercept)"]]) else 0
  beta1  <- unname(coef_m[[treatment]])
  beta2  <- if (length(cvar) > 0) unname(coef_m[cvar]) else numeric(0)
  theta2 <- unname(coef_y[[mediator]])
  theta3 <- unname(coef_y[[int_term]])
  kappa  <- if (identical(yreg, "linear")) 0 else 1
  beta2_c <- if (length(cvar) > 0) sum(beta2 * c_cond) else 0

  # --- Jacobian of (cde, int_ref, int_med, pie) wrt (beta, theta, sigma^2) ---
  comp4 <- c("cde", "int_ref", "int_med", "pie")
  g <- matrix(0, 4, length(pnames), dimnames = list(comp4, pnames))
  m_x <- paste0("m_", treatment)
  y_x <- paste0("y_", treatment)
  y_m <- paste0("y_", mediator)
  y_xm <- paste0("y_", int_term)

  g["cde", y_x] <- 1
  g["cde", y_xm] <- m_star

  g["pie", y_m] <- beta1
  g["pie", m_x] <- theta2

  g["int_med", y_xm] <- beta1
  g["int_med", m_x] <- theta3

  if (has_b0) g["int_ref", "m_(Intercept)"] <- theta3
  for (j in seq_along(cvar)) g["int_ref", paste0("m_", cvar[j])] <- theta3 * c_cond[j]
  g["int_ref", y_m] <- kappa * theta3 * sigma_sq
  g["int_ref", y_xm] <- beta0 + beta2_c + kappa * sigma_sq * (theta2 + theta3) - m_star
  g["int_ref", "sigma_sq"] <- kappa * 0.5 * theta3 * (2 * theta2 + theta3)

  # --- Aggregate to the 7 stored components ---
  l <- rbind(
    diag(4),
    nde = c(1, 1, 0, 0),
    nie = c(0, 0, 1, 1),
    total_effect = c(1, 1, 1, 1)
  )
  rownames(l)[1:4] <- comp4
  lg <- l %*% g
  comp <- lg %*% sigma_mat %*% t(lg)
  cross <- (lg %*% sigma_mat)[, c(names_m, names_y), drop = FALSE]
  dimnames(comp) <- list(rownames(l), rownames(l))
  rownames(cross) <- rownames(l)
  list(comp = comp, cross = cross)
}


#' Internal guard: regmedint's effects must equal medfit's product forms
#' @keywords internal
#' @noRd
.regmedint_assert_mapping <- function(medfit_vals, regmedint_vals) {
  tol <- 1e-8 * max(1, abs(regmedint_vals))
  bad <- names(medfit_vals)[abs(medfit_vals - regmedint_vals) > tol]
  if (length(bad) > 0) {
    stop(
      "Internal mapping error for engine = \"regmedint\": regmedint's ",
      paste(bad, collapse = ", "),
      " does not equal medfit's product-of-coefficients form. Please report this.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}
