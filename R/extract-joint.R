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


#' Extract joint natural effects from lm/glm models (worker)
#'
#' Placeholder until the worker lands (PLAN T4).
#'
#' @keywords internal
.extract_joint_mediation_lm <- function(med_models, model_y, treatment,
                                        mediators, structure, interactions,
                                        m_star, outcome = NULL, data = NULL) {
  stop(errorCondition("Joint mediation effects are not implemented yet.",
                      class = "medfit_joint_not_implemented", call = NULL))
}
