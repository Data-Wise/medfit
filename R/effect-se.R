# Delta-method standard errors for mediation effects
#
# One gradient builder per mediation data class, shared by tidy() and
# confint() so the two cannot disagree (SPEC-tidy-effect-se-2026-09-23.md).
# Gradients are named over the alias rows every extractor adds to @vcov
# (a, b, c_prime; d1..dk; a1, b1, ..; theta3, b0).


#' Delta-Method Standard Errors for Mediation Effects
#'
#' @param x A mediation data object.
#' @param terms Character: canonical effect keys to return. Simple, serial and
#'   parallel objects provide `"nie"`, `"nde"`, `"te"`; interaction objects
#'   also provide `"cde"`, `"int_ref"`, `"int_med"`, `"pie"`.
#' @return Named numeric vector of standard errors, one per `terms`.
#' @keywords internal
#' @noRd
.effect_se <- function(x, terms) {
  grads <- .effect_gradients(x)
  checkmate::assert_character(terms, min.len = 1, .var.name = "terms")
  checkmate::assert_subset(terms, names(grads), .var.name = "terms")
  vc <- x@vcov
  vapply(terms, function(k) sqrt(.gradient_var(grads[[k]], vc)), numeric(1))
}


#' Variance of a Linear Combination of Parameters
#'
#' `t(g) %*% Sigma %*% g` over the sub-block of `vc` named by `g`.
#'
#' @param g Named numeric gradient.
#' @param vc Variance-covariance matrix with matching dimnames.
#' @return Numeric scalar.
#' @keywords internal
#' @noRd
.gradient_var <- function(g, vc) {
  nm <- names(g)
  missing_nm <- setdiff(nm, rownames(vc))
  if (length(missing_nm) > 0) {
    stop("vcov has no row for: ", paste(missing_nm, collapse = ", "),
         call. = FALSE)
  }
  as.numeric(t(g) %*% vc[nm, nm, drop = FALSE] %*% g)
}


#' Add Named Gradients, Aligning on Parameter Names
#'
#' @param ... Named numeric gradients.
#' @return Named numeric gradient over the union of names.
#' @keywords internal
#' @noRd
.add_gradients <- function(...) {
  gs <- list(...)
  allnm <- unique(unlist(lapply(gs, names)))
  out <- stats::setNames(numeric(length(allnm)), allnm)
  for (g in gs) out[names(g)] <- out[names(g)] + g
  out
}


#' Effect Gradients for a Mediation Data Object
#'
#' @param x A mediation data object.
#' @return Named list: canonical effect key -> named gradient over `@vcov`.
#' @keywords internal
#' @noRd
.effect_gradients <- function(x) {
  if (S7::S7_inherits(x, InteractionMediationData)) {
    return(.effect_gradients_interaction(x))
  }

  if (S7::S7_inherits(x, MediationData)) {
    a <- x@a_path
    b <- x@b_path
    g_nie <- c(a = b, b = a)
  } else if (S7::S7_inherits(x, SerialMediationData)) {
    # NIE = a * d1 * ... * dk * b: each factor's partial is the product of the others
    vals <- c(x@a_path, x@d_path, x@b_path)
    names(vals) <- c("a", paste0("d", seq_along(x@d_path)), "b")
    g_nie <- vapply(seq_along(vals), function(i) prod(vals[-i]), numeric(1))
    names(g_nie) <- names(vals)
  } else if (S7::S7_inherits(x, ParallelMediationData)) {
    # NIE = sum_j a_j * b_j
    k <- length(x@a_paths)
    g_nie <- c(stats::setNames(x@b_paths, paste0("a", seq_len(k))),
               stats::setNames(x@a_paths, paste0("b", seq_len(k))))
  } else {
    stop("No effect gradients for class ", class(x)[1], call. = FALSE)
  }

  g_nde <- c(c_prime = 1)
  list(nie = g_nie, nde = g_nde, te = .add_gradients(g_nie, g_nde))
}


#' Effect Gradients for an InteractionMediationData Object
#'
#' When the engine stored its own component covariance (the regmedint engine),
#' each key is a unit gradient on that row. Otherwise the four-way components
#' are differentiated under the Gaussian-outcome formulas, including the
#' covariate term in the INTref reference deviation.
#'
#' @param x An InteractionMediationData object.
#' @return Named list: canonical effect key -> named gradient over `@vcov`.
#' @keywords internal
#' @noRd
.effect_gradients_interaction <- function(x) {
  vc <- x@vcov
  rows <- c(cde = "cde", int_ref = "int_ref", int_med = "int_med", pie = "pie",
            nde = "nde", nie = "nie", te = "total_effect")
  if (all(rows %in% rownames(vc))) {
    return(lapply(rows, function(r) stats::setNames(1, r)))
  }

  a <- x@a_path          # beta1
  b <- x@b_path          # theta2
  t3 <- x@interaction    # theta3
  m_star <- x@m_star

  # Reference deviation (E[M | X = 0] minus m_star) and its covariate gradient.
  beta0 <- if ("b0" %in% rownames(vc)) unname(x@estimates[["b0"]]) else 0
  m_ref <- beta0
  cov_grad <- numeric(0)
  m_covs <- setdiff(x@mediator_predictors, x@treatment)
  if (length(m_covs) > 0 && !is.null(x@data)) {
    for (cv in m_covs) {
      pn <- paste0("m_", cv)
      if (cv %in% names(x@data) && is.numeric(x@data[[cv]]) &&
            pn %in% rownames(vc)) {
        cm <- mean(x@data[[cv]], na.rm = TRUE)
        m_ref <- m_ref + unname(x@estimates[[pn]]) * cm
        cov_grad[pn] <- t3 * cm
      }
    }
  }
  ref_dev <- m_ref - m_star

  g_cde <- c(c_prime = 1, theta3 = m_star)
  g_intmed <- c(theta3 = a, a = t3)
  g_pie <- c(b = a, a = b)
  g_intref <- c(theta3 = ref_dev)
  if ("b0" %in% rownames(vc)) g_intref["b0"] <- t3
  if (length(cov_grad)) g_intref <- .add_gradients(g_intref, cov_grad)

  list(
    cde = g_cde, int_ref = g_intref, int_med = g_intmed, pie = g_pie,
    nde = .add_gradients(g_cde, g_intref),
    nie = .add_gradients(g_intmed, g_pie),
    te = .add_gradients(g_cde, g_intref, g_intmed, g_pie)
  )
}
