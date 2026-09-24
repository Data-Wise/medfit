# Joint natural effects of multiple mediators with treatment-by-mediator
# products (VanderWeele and Vansteelandt 2014). Routing lives in
# .extract_mediation_lm_impl(); this file holds the joint-branch guards and the
# worker. Spec: planning/specs/SPEC-joint-mediator-interactions-2026-09-23.md


#' Split multi-mediator product hits into supported and unsupported terms
#'
#' A product is supported only when it sits in the outcome model, involves the
#' treatment and exactly one mediator, and is written with `:` or `*` (an
#' order-2 term). Everything else -- products in a mediator model,
#' mediator-by-mediator, three-way, covariate products, function-wrapped terms
#' such as `I(X * M2)` -- is unsupported.
#'
#' @param hits `"<response>: <term>"` labels from [.find_product_terms()].
#' @param model_y Outcome model.
#' @param treatment,mediators Variable names.
#' @return `list(interactions = <mediators with a supported product, in
#'   mediator order>, unsupported = <labels>)`.
#' @keywords internal
.partition_joint_products <- function(hits, model_y, treatment, mediators) {
  resp_y <- deparse(stats::formula(model_y)[[2L]])
  prefix <- paste0(resp_y, ": ")
  tt <- stats::terms(model_y)
  order2 <- attr(tt, "term.labels")[attr(tt, "order") == 2L]
  interactions <- character(0)
  unsupported <- character(0)
  for (hit in hits) {
    term <- if (startsWith(hit, prefix)) substring(hit, nchar(prefix) + 1L) else NA
    parts <- if (!is.na(term) && term %in% order2) {
      strsplit(term, ":", fixed = TRUE)[[1L]]
    } else {
      character(0)
    }
    med <- setdiff(parts, treatment)
    if (length(parts) == 2L && treatment %in% parts && length(med) == 1L &&
          med %in% mediators) {
      interactions <- c(interactions, med)
    } else {
      unsupported <- c(unsupported, hit)
    }
  }
  list(interactions = mediators[mediators %in% interactions],
       unsupported = unsupported)
}


#' Error on product terms the joint branch does not support
#'
#' @param hits Unsupported `"<response>: <term>"` labels.
#' @keywords internal
.stop_on_unsupported_joint_products <- function(hits) { # nolint: object_length_linter.
  if (length(hits) == 0L) return(invisible(NULL))
  stop(paste0(
    "Multi-mediator (serial or parallel) extraction supports only ",
    "treatment-by-mediator product terms in the outcome model, written with ",
    "':' or '*' (e.g. Y ~ X * M2 + M1). Unsupported product term(s) found: ",
    paste(hits, collapse = ", "), ". Products in a mediator model, ",
    "mediator-by-mediator, three-way, covariate and function-wrapped ",
    "products such as I(X * M) would be reported as main effects that ignore ",
    "the interaction. Refit without them."
  ), call. = FALSE)
}


# Error with the shared joint-branch prefix.
.stop_joint <- function(...) {
  stop(paste0("Joint mediation effects (multi-mediator fit with a ",
              "treatment-by-mediator product): ", ...), call. = FALSE)
}


# Covariate terms of a model: term labels involving neither the treatment nor a
# mediator.
.joint_covariate_terms <- function(model, vars) {
  labs <- attr(stats::terms(model), "term.labels")
  keep <- vapply(labs, function(lab) {
    v <- tryCatch(all.vars(str2lang(lab)), error = function(e) lab)
    !any(v %in% vars)
  }, logical(1))
  sort(labs[keep])
}


#' Validate a multi-mediator fit for the joint-effects branch
#'
#' Enforces every precondition of the closed-form joint effects and returns the
#' structure implied by the mediator models. Each failure names its cause.
#'
#' @param med_models List of the K mediator models, in `mediators` order.
#' @param model_y Outcome model.
#' @param treatment,mediators Variable names.
#' @param structure `"auto"`, `"serial"` or `"parallel"` as supplied.
#' @param decomposition As supplied to [extract_mediation()].
#' @param vcov_fun As supplied to [extract_mediation()].
#' @return `"serial"` or `"parallel"`.
#' @keywords internal
.check_joint_fit <- function(med_models, model_y, treatment, mediators,
                             structure, decomposition, vcov_fun) {
  k <- length(mediators)
  if (decomposition == "two_way") {
    .stop_joint("decomposition = 'two_way' would report main-effect paths ",
                "that ignore the product term(s). Drop the argument, or refit ",
                "without the products.")
  }
  if (!identical(vcov_fun, stats::vcov)) {
    .stop_joint("a non-default `vcov_fun` is not supported, because the ",
                "cross-equation covariance assumes ordinary least squares. ",
                "Use the default, or bootstrap nonparametrically.")
  }
  if (length(med_models) != k) {
    .stop_joint(sprintf("expected %d mediator models (object plus ", k),
                "`mediator_models`), got ", length(med_models), ".")
  }
  all_models <- c(med_models, list(model_y))
  labels <- c(mediators, .get_response_var(model_y))

  # Responses must match the stated mediator order.
  resp <- vapply(med_models, .get_response_var, character(1))
  if (!identical(unname(resp), mediators)) {
    .stop_joint("the mediator models' responses (",
                paste(resp, collapse = ", "), ") must match `mediator` (",
                paste(mediators, collapse = ", "), "), in order.")
  }

  # Gaussian family with identity link, intercept, no weights.
  for (i in seq_along(all_models)) {
    m <- all_models[[i]]
    if (inherits(m, "glm")) {
      fam <- stats::family(m)
      if (fam$family != "gaussian" || fam$link != "identity") {
        .stop_joint(sprintf("the %s model uses family %s(link = \"%s\"); ",
                            labels[i], fam$family, fam$link),
                    "only Gaussian models with the identity link are supported.")
      }
    }
    if (!"(Intercept)" %in% names(stats::coef(m))) {
      .stop_joint(sprintf("the %s model has no intercept; ", labels[i]),
                  "every model must include one.")
    }
    w <- stats::weights(m)
    if (!is.null(w) && !all(w == 1)) {
      .stop_joint(sprintf("the %s model is weighted; ", labels[i]),
                  "weighted fits are not supported.")
    }
  }

  # Every mediator enters the outcome model.
  absent <- setdiff(mediators, names(stats::coef(model_y)))
  if (length(absent) > 0L) {
    .stop_joint("every mediator must appear in the outcome model, because ",
                "the joint indirect effect runs through all of them; missing: ",
                paste(absent, collapse = ", "), ".")
  }

  # Numeric 0/1 treatment (unit contrast).
  x <- stats::model.frame(model_y)[[treatment]]
  if (!is.numeric(x) || !all(x %in% c(0, 1))) {
    .stop_joint(sprintf("treatment '%s' must be numeric and coded 0/1.", treatment))
  }

  # Identical rows in every model.
  rows <- lapply(all_models, function(m) rownames(stats::model.frame(m)))
  if (!all(vapply(rows[-1L], identical, logical(1), rows[[1L]]))) {
    .stop_joint("all models must be fit to the same rows (model-frame row ",
                "names differ). Fit every model to the same complete cases.")
  }

  # Identical covariate sets.
  vars <- c(treatment, mediators)
  covs <- lapply(all_models, .joint_covariate_terms, vars = vars)
  for (i in seq_along(covs)[-1L]) {
    if (!identical(covs[[i]], covs[[1L]])) {
      diff <- union(setdiff(covs[[i]], covs[[1L]]), setdiff(covs[[1L]], covs[[i]]))
      .stop_joint(sprintf("every model must carry the same covariates; the %s ",
                          labels[i]),
                  sprintf("and %s models differ in: %s.", labels[1L],
                          paste(diff, collapse = ", ")))
    }
  }

  # Mediator order: model i may use only earlier mediators.
  uses_earlier <- FALSE
  for (i in seq_len(k)) {
    used <- unique(unlist(lapply(attr(stats::terms(med_models[[i]]), "term.labels"),
                                 function(lab) all.vars(str2lang(lab)))))
    later <- intersect(used, mediators[seq_len(k) >= i])
    if (length(later) > 0L) {
      .stop_joint(sprintf("the %s model uses %s, which comes at or after ",
                          mediators[i], paste(later, collapse = ", ")),
                  sprintf("%s in `mediator`; `mediator` must list the ", mediators[i]),
                  "mediators in causal order.")
    }
    if (any(mediators[seq_len(i - 1L)] %in% used)) uses_earlier <- TRUE
  }
  inferred <- if (uses_earlier) "serial" else "parallel"
  if (structure != "auto" && structure != inferred) {
    .stop_joint(sprintf("structure = '%s' conflicts with the mediator models, ", structure),
                sprintf("which imply '%s'.", inferred))
  }
  inferred
}


#' Normalize `m_star` for the joint branch
#'
#' A scalar applies to every interacting mediator; a named vector must name
#' exactly the interacting mediators. The result is always named.
#'
#' @param m_star As supplied.
#' @param interactions Mediators carrying a product, in mediator order.
#' @param supplied Logical: was `m_star` given at the call site?
#' @keywords internal
.normalize_joint_m_star <- function(m_star, interactions, supplied) {
  if (!supplied) m_star <- 0
  checkmate::assert_numeric(m_star, any.missing = FALSE, finite = TRUE,
                            min.len = 1L, .var.name = "m_star")
  if (is.null(names(m_star))) {
    if (length(m_star) != 1L) {
      .stop_joint("`m_star` must be a scalar or a vector named by the ",
                  "interacting mediators (", paste(interactions, collapse = ", "),
                  ").")
    }
    return(stats::setNames(rep(unname(m_star), length(interactions)), interactions))
  }
  unknown <- setdiff(names(m_star), interactions)
  if (length(unknown) > 0L) {
    .stop_joint("`m_star` names a mediator without a treatment-by-mediator ",
                "product: ", paste(unknown, collapse = ", "),
                ". Interacting mediators: ", paste(interactions, collapse = ", "), ".")
  }
  missing_nm <- setdiff(interactions, names(m_star))
  if (length(missing_nm) > 0L) {
    .stop_joint("`m_star` must name every interacting mediator; missing: ",
                paste(missing_nm, collapse = ", "), ".")
  }
  m_star[interactions]
}


# Covariate coefficient names of a joint object: first-mediator source rows
# other than the intercept and the treatment (that model uses no mediator).
.joint_cov_names <- function(est, treatment) {
  covs <- sub("^m1_", "", grep("^m1_", names(est), value = TRUE))
  setdiff(covs, c("(Intercept)", treatment))
}


# Outcome source rows of the treatment-by-mediator products, in the order of
# `interactions` (either spelling, X:M or M:X).
.joint_theta3_rows <- function(est, treatment, interactions) {
  vapply(interactions, function(m) {
    cand <- paste0("y_", c(paste0(treatment, ":", m), paste0(m, ":", treatment)))
    hit <- cand[cand %in% names(est)]
    if (length(hit) == 0L) NA_character_ else hit[1L]
  }, character(1), USE.NAMES = FALSE)
}


#' Sample means of the covariate design columns of a joint object
#'
#' Rebuilds the design from `@data` (the outcome model frame, whose `terms`
#' attribute gives factor dummies the extractor's column names). Falls back to
#' plain numeric columns for a hand-built `data`.
#'
#' @param x A JointMediationData object.
#' @param covs Covariate coefficient names.
#' @return Named numeric vector (length 0 when there are no covariates).
#' @keywords internal
.joint_covariate_means <- function(x, covs) {
  if (length(covs) == 0L) return(stats::setNames(numeric(0), character(0)))
  dat <- x@data
  if (is.null(dat)) {
    stop("JointMediationData has no @data; covariate means are unavailable.",
         call. = FALSE)
  }
  mm <- tryCatch(stats::model.matrix(attr(dat, "terms"), dat),
                 error = function(e) NULL)
  if (!is.null(mm) && all(covs %in% colnames(mm))) {
    return(colMeans(mm[, covs, drop = FALSE]))
  }
  if (all(covs %in% names(dat)) && all(vapply(dat[covs], is.numeric, logical(1)))) {
    return(colMeans(dat[covs]))
  }
  stop("cannot rebuild covariate means for: ", paste(covs, collapse = ", "),
       call. = FALSE)
}


#' Propagate mediator means down a serial chain
#'
#' The joint effects need each mediator's mean given the treatment and
#' covariates only. For a serial chain, where `M2 ~ X + M1 + C`, iterated
#' expectations give reduced-form coefficients by recursion:
#' \eqn{\beta^*_{1i} = \beta_{1i} + \sum_{j<i} d_{ij} \beta^*_{1j}}{b1i* = b1i + sum(dij * b1j*)},
#' and likewise for the intercept and covariate coefficients. For parallel
#' mediators every `d` is 0, so raw and propagated coefficients coincide.
#'
#' @param b0,b1 Numeric vectors (length K): raw intercepts and treatment
#'   coefficients.
#' @param gamma K x p matrix of raw covariate coefficients (p may be 0).
#' @param d K x K strictly lower-triangular matrix: `d[i, j]` is the coefficient
#'   of mediator j in the model for mediator i.
#' @return `list(b0, b1, gamma)` of propagated coefficients.
#' @keywords internal
.propagate_mediator_means <- function(b0, b1, gamma, d) {
  k <- length(b0)
  for (i in seq_len(k)[-1L]) {
    j <- seq_len(i - 1L)
    b0[i] <- b0[i] + sum(d[i, j] * b0[j])
    b1[i] <- b1[i] + sum(d[i, j] * b1[j])
    gamma[i, ] <- gamma[i, ] + colSums(d[i, j] * gamma[j, , drop = FALSE])
  }
  list(b0 = b0, b1 = b1, gamma = gamma)
}


#' Stacked-OLS covariance of several equations fit to the same rows
#'
#' Diagonal blocks are each model's [stats::vcov()]. Off-diagonal blocks are
#' \eqn{\hat\sigma_{ef} (X_e'X_e)^{-1} X_e'X_f (X_f'X_f)^{-1}}{s_ef (Xe'Xe)^-1 Xe'Xf (Xf'Xf)^-1},
#' with the residual cross-product divided by
#' \eqn{\sqrt{(n - p_e)(n - p_f)}}{sqrt((n - pe)(n - pf))}, so the formula
#' reduces to `vcov()` on the diagonal. A block is exactly zero when one
#' equation's residual lies in the other's column space (serial chains with
#' shared covariates; the outcome against every mediator).
#'
#' @param models List of fitted lm/glm (Gaussian identity) models.
#' @param prefixes Character prefixes for the stacked coefficient names.
#' @return Named covariance matrix of the stacked coefficients.
#' @keywords internal
.stacked_ols_vcov <- function(models, prefixes) {
  info <- lapply(models, function(m) {
    r <- stats::residuals(m, type = "response")
    df <- m$df.residual
    v <- stats::vcov(m)
    list(x = stats::model.matrix(m), r = r, df = df, v = v,
         inv = v / (sum(r^2) / df))
  })
  nms <- unlist(Map(function(m, p) paste0(p, names(stats::coef(m))), models, prefixes))
  blocks <- lapply(seq_along(info), function(e) {
    lapply(seq_along(info), function(f) {
      if (e == f) return(info[[e]]$v)
      s_ef <- sum(info[[e]]$r * info[[f]]$r) / sqrt(info[[e]]$df * info[[f]]$df)
      s_ef * info[[e]]$inv %*% crossprod(info[[e]]$x, info[[f]]$x) %*% info[[f]]$inv
    })
  })
  out <- do.call(rbind, lapply(blocks, function(row) do.call(cbind, row)))
  dimnames(out) <- list(nms, nms)
  out
}


#' Extract joint natural effects from lm/glm models (worker)
#'
#' Called by [.extract_mediation_lm_impl()] after [.check_joint_fit()] has
#' validated the models. Evaluates the unit-contrast (0 -> 1) effects at the
#' sample covariate means (VanderWeele and Vansteelandt 2014):
#' NIE = \eqn{\sum_i (\theta_{2i} + \theta_{3i}) \beta^*_{1i}}{sum((t2i + t3i) * b1i*)},
#' NDE = \eqn{\theta_1 + \sum_i \theta_{3i} E[M_i \mid X = 0, \bar c]}{t1 + sum(t3i * E[Mi | X = 0, cbar])},
#' CDE = \eqn{\theta_1 + \sum_i \theta_{3i} m^*_i}{t1 + sum(t3i * mi*)}.
#'
#' `@estimates` holds every model's coefficients as prefixed source rows
#' (`m1_`, ..., `mK_`, `y_`) plus path aliases (`a1..aK`, `dij`, `b1..bK`,
#' `theta3_<mediator>`, `c_prime`); `@vcov` is the stacked-OLS covariance of
#' the source rows, with alias rows duplicating their source rows. K = 1 is
#' accepted internally (reduction test only).
#'
#' @param med_models List of the K mediator models, in causal order.
#' @param model_y Outcome model.
#' @param treatment,mediators,outcome Variable names (`outcome` auto-detected
#'   when NULL).
#' @param structure `"serial"` or `"parallel"`.
#' @param interactions Mediators carrying a treatment product, in order.
#' @param m_star Numeric vector named by `interactions`.
#' @param data Optional data frame; defaults to the outcome model frame.
#' @return A `JointMediationData` object.
#' @keywords internal
.extract_joint_mediation_lm <- function(med_models, model_y, treatment,
                                        mediators, structure, interactions,
                                        m_star, outcome = NULL, data = NULL) {
  k <- length(mediators)
  all_models <- c(med_models, list(model_y))
  coefs <- lapply(all_models, stats::coef)
  if (anyNA(unlist(coefs))) {
    .stop_joint("a model has aliased (NA) coefficients; remove the collinear terms.")
  }
  cm <- coefs[seq_len(k)]
  cy <- coefs[[k + 1L]]
  get0 <- function(v, nm) if (nm %in% names(v)) unname(v[[nm]]) else 0

  # Covariate coefficients: the first mediator model uses no other mediator.
  cov_names <- setdiff(names(cm[[1L]]), c("(Intercept)", treatment))
  c_bar <- colMeans(stats::model.matrix(med_models[[1L]])[, cov_names, drop = FALSE])

  # Raw mediator coefficients, then propagate down the chain.
  b0 <- vapply(cm, get0, numeric(1), nm = "(Intercept)")
  b1 <- vapply(cm, get0, numeric(1), nm = treatment)
  gamma <- matrix(vapply(cm, function(v) vapply(cov_names, get0, numeric(1), v = v),
                         numeric(length(cov_names))),
                  nrow = k, byrow = TRUE, dimnames = list(mediators, cov_names))
  d <- matrix(0, k, k, dimnames = list(mediators, mediators))
  for (i in seq_len(k)) {
    for (j in seq_len(i - 1L)) d[i, j] <- get0(cm[[i]], mediators[j])
  }
  prop <- .propagate_mediator_means(b0, b1, gamma, d)
  a_total <- stats::setNames(prop$b1, mediators)
  m_at_zero <- stats::setNames(prop$b0 + drop(prop$gamma %*% c_bar), mediators)

  # Outcome coefficients.
  theta1 <- get0(cy, treatment)
  theta2 <- stats::setNames(vapply(mediators, get0, numeric(1), v = cy), mediators)
  int_names <- vapply(interactions, function(m) {
    .find_interaction_term(model_y, treatment, m)
  }, character(1))
  theta3 <- stats::setNames(unname(cy[int_names]), interactions)
  th3_all <- stats::setNames(numeric(k), mediators)
  th3_all[interactions] <- theta3

  nie <- sum((theta2 + th3_all) * a_total)
  nde <- theta1 + sum(theta3 * m_at_zero[interactions])
  cde <- theta1 + sum(theta3 * m_star[interactions])

  # Estimates: prefixed source rows plus path aliases.
  prefixes <- c(paste0("m", seq_len(k), "_"), "y_")
  src <- unlist(Map(function(v, p) stats::setNames(v, paste0(p, names(v))), coefs, prefixes))
  alias_src <- c(
    stats::setNames(paste0("m", seq_len(k), "_", treatment), paste0("a", seq_len(k))),
    stats::setNames(paste0("y_", mediators), paste0("b", seq_len(k))),
    stats::setNames(paste0("y_", int_names), paste0("theta3_", interactions)),
    c(c_prime = paste0("y_", treatment))
  )
  for (i in seq_len(k)) {
    for (j in seq_len(i - 1L)) {
      alias_src[paste0("d", i, j)] <- paste0("m", i, "_", mediators[j])
    }
  }
  alias_src <- alias_src[alias_src %in% names(src)]
  full <- c(names(src), alias_src)
  sel <- match(full, names(src))
  v_src <- .stacked_ols_vcov(all_models, prefixes)
  estimates <- stats::setNames(unname(src[sel]), c(names(src), names(alias_src)))
  vcov <- v_src[sel, sel, drop = FALSE]
  dimnames(vcov) <- list(names(estimates), names(estimates))

  # Metadata.
  if (is.null(outcome)) outcome <- .get_response_var(model_y)
  if (is.null(data)) {
    data <- tryCatch(stats::model.frame(model_y), error = function(e) NULL)
  }
  is_glm <- vapply(all_models, inherits, logical(1), what = "glm")
  converged <- all(vapply(all_models, function(m) {
    if (inherits(m, "glm")) isTRUE(m$converged) else TRUE
  }, logical(1)))

  JointMediationData(
    structure = structure, mediators = mediators, treatment = treatment,
    outcome = outcome, interactions = interactions,
    a_total = a_total, b_paths = theta2, theta3 = theta3, c_prime = theta1,
    cde = cde, nde = nde, nie = nie, total_effect = nde + nie,
    m_star = m_star[interactions],
    estimates = estimates, vcov = vcov,
    data = data, n_obs = as.integer(stats::nobs(model_y)),
    converged = converged,
    source_package = if (any(is_glm)) "stats::glm" else "stats::lm"
  )
}
