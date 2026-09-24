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


#' Effect Standard Errors, or NA Where `@vcov` Lacks the Rows
#'
#' For descriptive output (`tidy()`): an object built by hand without the
#' extractors' alias rows gets `NA` for an effect whose gradient refers to a
#' missing row, matching how `tidy()` already treats path SEs. `confint()`
#' calls `.effect_se()` instead, which errors.
#'
#' @inheritParams .effect_se
#' @return Named numeric vector of standard errors (`NA` where unavailable).
#' @keywords internal
#' @noRd
.effect_se_or_na <- function(x, terms) {
  # A hand-built object can lack what the gradients need (for a
  # JointMediationData, the prefixed source rows or `@data` for the covariate
  # means): report NA, as for a missing alias row, rather than stop.
  grads <- tryCatch(.effect_gradients(x), error = function(e) NULL)
  if (is.null(grads)) {
    return(stats::setNames(rep(NA_real_, length(terms)), terms))
  }
  checkmate::assert_subset(terms, names(grads), .var.name = "terms")
  vc <- x@vcov
  vapply(terms, function(k) {
    g <- grads[[k]]
    if (is.null(rownames(vc)) || !all(names(g) %in% rownames(vc))) {
      return(NA_real_)
    }
    sqrt(.gradient_var(g, vc))
  }, numeric(1))
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
  if (S7::S7_inherits(x, JointMediationData)) {
    return(.effect_gradients_joint(x))
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
  # Covariate means as in the extractor: design columns rebuilt from @data, so
  # factor dummies and transformed terms are included.
  m_covs <- setdiff(x@mediator_predictors, x@treatment)
  m_covs <- m_covs[paste0("m_", m_covs) %in% rownames(vc)]
  if (length(m_covs) > 0 && !is.null(x@data)) {
    c_bar <- .interaction_covariate_means(x@data, m_covs)
    for (cv in m_covs) {
      pn <- paste0("m_", cv)
      cm <- c_bar[[cv]]
      m_ref <- m_ref + unname(x@estimates[[pn]]) * cm
      cov_grad[pn] <- t3 * cm
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


#' Effect Gradients for a JointMediationData Object
#'
#' Analytic partials of the joint effects with respect to the prefixed source
#' rows of `@estimates` (`m<i>_`, `y_`). With `w_i = theta2_i + theta3_i`,
#' propagated treatment effects `B1_i = b1_i + sum_{j<i} d_ij B1_j` and
#' mediator means `mu0_i = b0_i + g_i'cbar + sum_{j<i} d_ij mu0_j`, the chain
#' rule through the recursion is carried by backward adjoints
#' `lambda_j = w_j + sum_{i>j} d_ij lambda_i` (NIE) and
#' `kappa_j = theta3_j + sum_{i>j} d_ij kappa_i` (NDE). Covariate means are
#' constants, so the SEs are conditional on the observed covariates.
#'
#' @param x A JointMediationData object.
#' @return Named list: `nie`, `nde`, `te`, `cde` -> named gradient over `@vcov`.
#' @keywords internal
#' @noRd
.effect_gradients_joint <- function(x) {
  .assert_joint_source_rows(x)
  pp <- .joint_parts(x, x@estimates)
  est <- x@estimates
  trt <- x@treatment
  meds <- x@mediators
  k <- length(meds)
  pre <- pp$pre
  covs <- pp$covs
  c_bar <- pp$c_bar
  d <- pp$d
  big_b1 <- pp$big_b1
  mu0 <- pp$mu0
  t3_rows <- pp$t3_rows
  t3 <- pp$t3
  w <- pp$w

  adjoint <- function(v) {
    out <- v
    for (j in rev(seq_len(k))) {
      later <- seq_len(k) > j
      out[j] <- v[j] + sum(d[later, j] * out[later])
    }
    out
  }
  lambda <- adjoint(w)
  kappa <- adjoint(unname(t3))

  # Keep only rows that exist (an absent row is a structural zero).
  keep <- function(g) g[names(g) %in% names(est)]
  d_rows <- function(mult, level) {
    out <- numeric(0)
    for (i in seq_len(k)) for (j in seq_len(i - 1L)) {
      out[paste0(pre[i], meds[j])] <- mult[i] * level[j]
    }
    out
  }

  g_nie <- keep(c(
    stats::setNames(lambda, paste0(pre, trt)),
    d_rows(lambda, big_b1),
    stats::setNames(big_b1, paste0("y_", meds)),
    stats::setNames(big_b1[match(x@interactions, meds)], t3_rows)
  ))
  g_cov <- unlist(lapply(seq_along(covs), function(c) {
    stats::setNames(kappa * c_bar[[c]], paste0(pre, covs[c]))
  }))
  g_nde <- keep(c(
    stats::setNames(1, paste0("y_", trt)),
    stats::setNames(mu0[match(x@interactions, meds)], t3_rows),
    stats::setNames(kappa, paste0(pre, "(Intercept)")),
    g_cov,
    d_rows(kappa, mu0)
  ))
  g_cde <- keep(c(stats::setNames(1, paste0("y_", trt)),
                  stats::setNames(unname(x@m_star[x@interactions]), t3_rows)))
  list(nie = g_nie, nde = g_nde, te = .add_gradients(g_nie, g_nde), cde = g_cde)
}


#' Building Blocks of the Joint Effects at a Given Estimate Vector
#'
#' Shared by the gradients and [joint_effects()]: reads the prefixed source
#' rows of `est` (`m<i>_`, `y_`) and returns the mediator-to-mediator
#' coefficients `d`, propagated treatment effects `big_b1`, mediator means at
#' X = 0 and the covariate means `mu0`, the product coefficients `t3` and the
#' NIE weights `w = theta2 + theta3`.
#'
#' @param x A JointMediationData object (structure, names, covariate means).
#' @param est Named estimate vector with the source rows.
#' @return A named list.
#' @keywords internal
#' @noRd
.joint_parts <- function(x, est) {
  trt <- x@treatment
  meds <- x@mediators
  k <- length(meds)
  g0 <- function(nm) if (nm %in% names(est)) unname(est[[nm]]) else 0
  pre <- paste0("m", seq_len(k), "_")
  covs <- .joint_cov_names(x@estimates, trt)
  c_bar <- .joint_covariate_means(x, covs)

  d <- matrix(0, k, k)
  for (i in seq_len(k)) for (j in seq_len(i - 1L)) d[i, j] <- g0(paste0(pre[i], meds[j]))
  big_b1 <- vapply(pre, function(p) g0(paste0(p, trt)), numeric(1), USE.NAMES = FALSE)
  mu0 <- vapply(seq_len(k), function(i) {
    g0(paste0(pre[i], "(Intercept)")) +
      sum(vapply(covs, function(cv) g0(paste0(pre[i], cv)), numeric(1)) * c_bar)
  }, numeric(1))
  for (i in seq_len(k)[-1L]) {
    j <- seq_len(i - 1L)
    big_b1[i] <- big_b1[i] + sum(d[i, j] * big_b1[j])
    mu0[i] <- mu0[i] + sum(d[i, j] * mu0[j])
  }
  t3_rows <- .joint_theta3_rows(x@estimates, trt, x@interactions)
  t3 <- stats::setNames(numeric(k), meds)
  t3[x@interactions] <- vapply(t3_rows, g0, numeric(1))
  w <- vapply(meds, function(m) g0(paste0("y_", m)), numeric(1)) + t3
  list(pre = pre, covs = covs, c_bar = c_bar, d = d, big_b1 = big_b1, mu0 = mu0,
       t3_rows = t3_rows, t3 = t3, w = w, theta1 = g0(paste0("y_", trt)))
}


#' Error Unless a JointMediationData Object Carries Its Source Rows
#'
#' The joint effects and their gradients are computed from the prefixed
#' per-equation rows of `@estimates` (`m1_`, ..., `mK_`, `y_`) that the
#' extractor stores. A hand-built object with only the path aliases cannot
#' give the NDE, so refuse it instead of treating the missing rows as zero.
#'
#' @param x A JointMediationData object.
#' @return `x`, invisibly.
#' @keywords internal
#' @noRd
.assert_joint_source_rows <- function(x) {
  k <- length(x@mediators)
  need <- c(paste0("m", seq_len(k), "_(Intercept)"), "y_(Intercept)")
  missing_rows <- setdiff(need, names(x@estimates))
  if (length(missing_rows) > 0L) {
    stop("This JointMediationData object has no per-equation source rows in ",
         "@estimates (missing: ", paste(missing_rows, collapse = ", "), "). ",
         "Joint effects and their standard errors need the rows ",
         "extract_mediation() stores; build the object with it.", call. = FALSE)
  }
  invisible(x)
}
