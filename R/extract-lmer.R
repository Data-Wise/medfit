# Extraction of cluster-level mediation from lme4 mixed models
#
# This file implements the lmer method of extract_mediation() for the 2-1-1
# design: a treatment assigned to whole clusters, a mediator and outcome
# measured on individuals. lme4 is in Suggests, so the method is registered in
# .onLoad() behind requireNamespace(), like lavaan.
#
#   - Mediator model: M ~ X + covariates + (1 | cluster)
#   - Outcome model:  Y ~ X + (M - Mbar) + Mbar + covariates + (1 | cluster)

#' Extract Cluster-Level Mediation from lmer Models
#'
#' @inheritParams extract_mediation
#' @param object Fitted `lmerMod` mediator model `M ~ X + ... + (1 | cluster)`.
#' @param model_y Fitted `lmerMod` outcome model.
#' @param cluster Character name of the cluster variable, or `NULL` for the
#'   single grouping factor the two models share.
#' @param se_type `"model"` (lme4's model-based fixed-effect covariance).
#'   `"kr"` arrives with the fit engine.
#' @param vcov_fun Not used by the lmer method; supplying it is an error.
#' @noRd
.extract_mediation_lmer <- function(object, model_y, treatment, mediator,
                                    cluster = NULL, se_type = "model",
                                    vcov_fun = NULL, ...) {
  ctx <- .lmer_guard(object, model_y, treatment, mediator, cluster, se_type,
                     vcov_fun)
  terms <- .lmer_terms(object, model_y, ctx)
  .lmer_assemble(object, model_y, ctx, terms)
}

# Routing and design guards (Behavior 1-5). Returns the validated context.
.lmer_guard <- function(object, model_y, treatment, mediator, cluster,
                        se_type, vcov_fun) {
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_string(cluster, null.ok = TRUE, .var.name = "cluster")
  checkmate::assert_choice(se_type, c("model", "kr"), .var.name = "se_type")
  if (!is.null(vcov_fun)) {
    stop("`vcov_fun` is not used with lmer models; choose the covariance with ",
         "`se_type`", call. = FALSE)
  }
  if (se_type == "kr") {
    stop("se_type = \"kr\" arrives with the fit engine; use se_type = \"model\" ",
         "for now", call. = FALSE)
  }
  .lmer_check_class(object, "mediator model (`object`)")
  .lmer_check_class(model_y, "outcome model (`model_y`)")

  cluster <- .lmer_cluster(object, model_y, cluster)
  for (spec in list(list(object, "mediator model"), list(model_y, "outcome model"))) {
    .lmer_check_intercept(spec[[1]], spec[[2]], cluster)
  }

  # One row per analysis unit: both models must see the same rows (D12).
  ids <- lapply(list(object, model_y), function(fit) {
    as.character(lme4::getME(fit, "flist")[[cluster]])
  })
  if (length(ids[[1]]) != length(ids[[2]]) || !identical(ids[[1]], ids[[2]])) {
    stop("The mediator and outcome models must use the same rows and the same ",
         "cluster vector in the same order (complete cases of both models); ",
         "they differ in `", cluster, "`", call. = FALSE)
  }
  x <- lapply(list(`mediator model` = object, `outcome model` = model_y),
              .lmer_treatment, treatment = treatment)
  if (!isTRUE(all.equal(x[[1]], x[[2]], check.attributes = FALSE))) {
    stop("The treatment `", treatment, "` differs between the mediator and ",
         "outcome models; both must use the same rows", call. = FALSE)
  }
  within_var <- tapply(x[[1]], ids[[1]], function(v) length(unique(v)) > 1L)
  if (any(within_var)) {
    stop("Treatment `", treatment, "` varies within clusters; 1-1-1 designs ",
         "are not supported yet", call. = FALSE)
  }
  list(cluster = cluster, ids = ids[[1]], x = x[[1]], treatment = treatment,
       mediator = mediator)
}

# Behavior 1: lmerMod and its subclasses; glmerMod gets the D7 error.
.lmer_check_class <- function(fit, what) {
  if (methods::is(fit, "glmerMod")) {
    stop("The ", what, " is a glmer fit. Non-Gaussian mixed models are not ",
         "supported: a * b_between on the link scale is not the natural ",
         "indirect effect (use a linear mixed model)", call. = FALSE)
  }
  if (!methods::is(fit, "lmerMod")) {
    stop("The ", what, " must be a linear mixed model fitted with ",
         "lme4::lmer()", call. = FALSE)
  }
  invisible(fit)
}

# Behavior 2: the single shared grouping factor, or the user's `cluster =`.
.lmer_cluster <- function(object, model_y, cluster) {
  groups <- list(mediator = names(lme4::getME(object, "flist")),
                 outcome = names(lme4::getME(model_y, "flist")))
  if (is.null(cluster)) {
    if (length(groups$mediator) != 1L || length(groups$outcome) != 1L ||
          !identical(groups$mediator, groups$outcome)) {
      stop("Cannot pick the cluster variable: the mediator model groups by (",
           paste(groups$mediator, collapse = ", "), ") and the outcome model by (",
           paste(groups$outcome, collapse = ", "), "). Name it with `cluster =`",
           call. = FALSE)
    }
    return(groups$mediator)
  }
  for (nm in names(groups)) {
    if (!cluster %in% groups[[nm]]) {
      stop("`cluster = \"", cluster, "\"` is not a grouping factor of the ", nm,
           " model (it groups by ", paste(groups[[nm]], collapse = ", "), ")",
           call. = FALSE)
    }
  }
  cluster
}

# Behavior 3: a random intercept for the cluster, or the corrected formula.
.lmer_check_intercept <- function(fit, what, cluster) {
  cnms <- lme4::getME(fit, "cnms")[[cluster]]
  if (!"(Intercept)" %in% cnms) {
    fml <- paste(deparse(stats::formula(fit)), collapse = " ")
    stop("The ", what, " has no random intercept for `", cluster, "`; add ",
         "`(1 | ", cluster, ")`, e.g. ", fml, " + (1 | ", cluster, ")",
         call. = FALSE)
  }
  invisible(fit)
}

# The treatment column on the rows a model used.
.lmer_treatment <- function(fit, treatment) {
  mf <- stats::model.frame(fit)
  if (!treatment %in% names(mf)) {
    stop("Treatment `", treatment, "` is not a variable of the model `",
         paste(deparse(stats::formula(fit)), collapse = " "), "`", call. = FALSE)
  }
  as.numeric(mf[[treatment]])
}

# Term detection by values (Behavior 6-8) -----------------------------------

# Relative tolerance for "exactly constant / exactly affine" checks on columns.
.lmer_tol <- function(x, tol = 1e-8) tol * max(1, max(abs(x)))

# TRUE when `x` is an exact affine function of `v` (with a nonzero slope).
# Returns the fit's intercept and slope, or NULL.
.affine_in <- function(x, v, tol = 1e-8) {
  if (stats::sd(x) == 0 || stats::sd(v) == 0) return(NULL)
  fit <- stats::lm.fit(cbind(1, v), x)
  if (max(abs(fit$residuals)) > .lmer_tol(x, tol)) return(NULL)
  list(intercept = unname(fit$coefficients[1]), slope = unname(fit$coefficients[2]))
}

# The cluster-mean column is found by value: constant within clusters and an
# exact affine function of the mediator's cluster mean on the model rows. The
# intercept and the treatment are never candidates. Returns the column name and
# the slope used to rescale its coefficient, or NULL.
.find_cluster_mean_term <- function(X, m, cl, exclude = character(), tol = 1e-8) {
  m_bar <- stats::ave(m, cl)
  for (nm in setdiff(colnames(X), c("(Intercept)", exclude))) {
    x <- X[, nm]
    if (max(abs(x - stats::ave(x, cl))) > .lmer_tol(x, tol)) next
    a <- .affine_in(x, m_bar, tol)
    if (!is.null(a)) return(list(term = nm, slope = a$slope))
  }
  NULL
}

# The within column: zero cluster means and an exact affine function of
# M - cluster mean. The raw column: varies within clusters and is an exact
# affine function of M.
.find_within_term <- function(X, m, cl, exclude = character(), tol = 1e-8) {
  m_w <- m - stats::ave(m, cl)
  for (nm in setdiff(colnames(X), c("(Intercept)", exclude))) {
    x <- X[, nm]
    if (max(abs(stats::ave(x, cl))) > .lmer_tol(x, tol)) next
    a <- .affine_in(x, m_w, tol)
    if (!is.null(a)) return(list(term = nm, slope = a$slope))
  }
  NULL
}

.find_raw_term <- function(X, m, cl, exclude = character(), tol = 1e-8) {
  for (nm in setdiff(colnames(X), c("(Intercept)", exclude))) {
    x <- X[, nm]
    if (max(abs(x - stats::ave(x, cl))) <= .lmer_tol(x, tol)) next
    a <- .affine_in(x, m, tol)
    if (!is.null(a)) return(list(term = nm, slope = a$slope))
  }
  NULL
}

# Raw to within (R1): the raw parameterization carries (b_W, kappa) with
# b_B = b_W + kappa. `L` has the rows b_W and kappa of the linear map from the
# fixed effects; the within rows are J L with J = [[1, 0], [1, 1]], so the
# vcov follows as (J L) V (J L)'. Kept as its own function so tests can plant a
# defect (reading raw as within).
.raw_to_within <- function(L) {
  J <- matrix(c(1, 1, 0, 1), 2, 2)
  out <- J %*% L
  dimnames(out) <- dimnames(L)
  out
}

# Product guards (Behavior 7): any outcome-model column that is the product of
# a mediator term (M, its cluster mean or its within deviation) with another
# column, found by value.
.lmer_find_product <- function(X, m, cl, skip, tol = 1e-8, extra = NULL) {
  mv <- list(M = m, `cluster mean of M` = stats::ave(m, cl),
             `within-cluster M` = m - stats::ave(m, cl))
  # Multipliers: the design columns plus any other numeric model variable, so a
  # product written without its main effect (`M_w:C` without `C`) is found too.
  O <- X[, setdiff(colnames(X), "(Intercept)"), drop = FALSE]
  if (!is.null(extra)) {
    extra <- extra[, setdiff(names(extra), colnames(O)), drop = FALSE]
    O <- cbind(O, as.matrix(extra))
  }
  cand <- setdiff(colnames(X), c("(Intercept)", skip))
  for (nm in cand) {
    x <- X[, nm]
    if (stats::sd(x) == 0) next
    for (other in setdiff(colnames(O), nm)) {
      for (label in names(mv)) {
        z <- mv[[label]] * O[, other]
        if (stats::sd(z) == 0 || all(z == 0)) next
        fit <- stats::lm.fit(matrix(z, ncol = 1), x)
        if (max(abs(fit$residuals)) <= .lmer_tol(x, tol) &&
              abs(fit$coefficients[1]) > 0) {
          return(list(term = nm, mediator = label, other = other))
        }
      }
    }
  }
  NULL
}

# Everything Behavior 6-8 needs from the outcome model: the within/raw/mean
# term names, the linear map L from the fixed effects to (c_prime, b_within,
# b_between) with the affine rescaling folded in, and whether every level-1
# covariate is cluster-mean centered. Errors name the offending term.
.lmer_terms <- function(object, model_y, ctx, tol = 1e-8) {
  cl <- ctx$ids
  m <- as.numeric(lme4::getME(object, "y"))
  X <- lme4::getME(model_y, "X")
  beta <- lme4::fixef(model_y)
  trt <- ctx$treatment
  if (!trt %in% colnames(X)) {
    stop("Treatment `", trt, "` is not a fixed effect of the outcome model; ",
         "the direct effect needs it", call. = FALSE)
  }
  m_bar <- stats::ave(m, cl)

  # Identifiability (P6): the between effect needs cluster means that differ.
  if (stats::sd(m_bar) <= 1e-8 * max(1, stats::sd(m))) {
    stop("There is no between-cluster variation in the mediator `", ctx$mediator,
         "` (every cluster has the same mean), so the between-cluster effect ",
         "is not identifiable", call. = FALSE)
  }

  mean_t <- .find_cluster_mean_term(X, m, cl, exclude = trt, tol = tol)
  within_t <- .find_within_term(X, m, cl, exclude = trt, tol = tol)
  raw_t <- .find_raw_term(X, m, cl, exclude = trt, tol = tol)
  if (!is.null(within_t) && !is.null(raw_t)) {
    stop("The outcome model has both a within-cluster term (`", within_t$term,
         "`) and a raw mediator term (`", raw_t$term, "`); keep one of them ",
         "next to the cluster mean", call. = FALSE)
  }
  found <- c(mean_t$term, within_t$term, raw_t$term)
  mf <- stats::model.frame(model_y)
  mf_num <- mf[vapply(mf, function(v) is.numeric(v) && !is.matrix(v), logical(1))]
  prod <- .lmer_find_product(X, m, cl, skip = c(trt, found), tol = tol,
                             extra = mf_num)
  if (!is.null(prod)) {
    stop("The outcome model has the product term `", prod$term, "` of the ",
         prod$mediator, " with `", prod$other, "`; treatment-by-mediator and ",
         "covariate-by-mediator products are not supported (the natural ",
         "indirect effect would depend on the covariate level)", call. = FALSE)
  }
  if (is.null(mean_t)) {
    near <- .lmer_near_miss(X, m_bar, cl, c(trt, found), tol)
    if (!is.null(near)) {
      stop("The cluster mean must be computed on the rows the models use ",
           "(complete cases): `", near, "` is constant within clusters and ",
           "correlates above 0.99 with the cluster mean of `", ctx$mediator,
           "` but is not an exact affine function of it", call. = FALSE)
    }
    stop("The outcome model has no cluster-mean term for `", ctx$mediator,
         "`; add the cluster mean, e.g. `", ctx$mediator, "_cwc + ",
         ctx$mediator, "_cm` with `", ctx$mediator, "_cm = ave(", ctx$mediator,
         ", ", ctx$cluster, ")`", call. = FALSE)
  }
  if (is.null(within_t) && is.null(raw_t)) {
    stop("The outcome model has a cluster-mean term (`", mean_t$term, "`) but ",
         "no within-cluster or raw mediator term next to it", call. = FALSE)
  }

  param <- if (!is.null(within_t)) "within" else "raw"
  first <- if (param == "within") within_t else raw_t
  p <- length(beta)
  row <- function(nm, scale = 1) {
    r <- stats::setNames(numeric(p), names(beta))
    r[nm] <- scale
    r
  }
  L2 <- rbind(b_within = row(first$term, first$slope),
              b_between = row(mean_t$term, mean_t$slope))
  if (param == "raw") {
    rownames(L2) <- c("b_within", "kappa")
    L2 <- .raw_to_within(L2)
    rownames(L2) <- c("b_within", "b_between")
  }
  L <- rbind(c_prime = row(trt), L2)

  .lmer_check_slopes(object, model_y, ctx, trt, mean_t$term, first$term, param)

  list(parameterization = param, within_term = within_t$term,
       raw_term = raw_t$term, mean_term = mean_t$term, L = L,
       covariates_centered = .lmer_covariates_centered(
         X, cl, setdiff(colnames(X), c("(Intercept)", trt, found)), tol
       ))
}

.lmer_near_miss <- function(X, m_bar, cl, skip, tol) {
  for (nm in setdiff(colnames(X), c("(Intercept)", skip))) {
    x <- X[, nm]
    if (stats::sd(x) == 0) next
    if (max(abs(x - stats::ave(x, cl))) > .lmer_tol(x, tol)) next
    if (abs(stats::cor(x, m_bar)) > 0.99) return(nm)
  }
  NULL
}

# Level-1 covariates (columns that vary within clusters) are cluster-mean
# centered when they have zero cluster means, or when a column constant within
# clusters is their exact affine cluster-mean companion (P10).
.lmer_covariates_centered <- function(X, cl, cols, tol) {
  lvl1 <- Filter(function(nm) {
    x <- X[, nm]
    max(abs(x - stats::ave(x, cl))) > .lmer_tol(x, tol)
  }, cols)
  all(vapply(lvl1, function(nm) {
    x <- X[, nm]
    if (max(abs(stats::ave(x, cl))) <= .lmer_tol(x, tol)) return(TRUE)
    any(vapply(setdiff(cols, nm), function(other) {
      o <- X[, other]
      max(abs(o - stats::ave(o, cl))) <= .lmer_tol(o, tol) &&
        !is.null(.affine_in(o, stats::ave(x, cl), tol))
    }, logical(1)))
  }, logical(1)))
}

# Random slopes (Behavior 7): a slope on the within term is accepted; a slope
# on the raw term, the cluster-mean term or the treatment errors.
.lmer_check_slopes <- function(object, model_y, ctx, trt, mean_term, first_term,
                               param) {
  slopes <- function(fit) {
    setdiff(lme4::getME(fit, "cnms")[[ctx$cluster]], "(Intercept)")
  }
  bad <- function(sl, what, why) {
    stop("A random slope on ", what, " (`", sl, "`) is not supported: ", why,
         call. = FALSE)
  }
  for (sl in slopes(model_y)) {
    if (sl == trt) {
      bad(sl, "the treatment", "it is constant within clusters")
    }
    if (sl == mean_term) {
      bad(sl, "the cluster-mean term",
          "the cluster mean has no within-cluster variation to carry a slope")
    }
    if (sl == first_term && param == "raw") {
      bad(sl, "the raw mediator term",
          "use the within-cluster term for a random slope")
    }
  }
  if (trt %in% slopes(object)) {
    bad(trt, "the treatment", "it is constant within clusters")
  }
  invisible(NULL)
}

# Object assembly (Behavior 9) -------------------------------------------------

# Intercept SD of a model's random effect for `cluster`.
.lmer_tau <- function(fit, cluster) {
  vc <- lme4::VarCorr(fit)[[cluster]]
  sqrt(unname(vc["(Intercept)", "(Intercept)"]))
}

# TRUE when lme4 reports no optimizer failure or convergence message.
.lmer_converged <- function(fit) {
  conv <- fit@optinfo$conv
  isTRUE(conv$opt == 0) && length(conv$lme4$messages) == 0L
}

# The response name of an lmer fit.
.lmer_response <- function(fit) {
  all.vars(stats::formula(fit)[[2]])[1]
}

# Build the ClusterMediationData object. `@estimates` carries the four alias
# rows (a, c_prime, b_within, b_between) and each model's fixed effects with an
# `m_`/`y_` prefix. `@vcov` is T V T' for the linear map T from the stacked
# fixed effects to that vector and V = blockdiag(V_m, V_y), so every block
# between the mediator model and the outcome block is exactly zero (D4).
.lmer_assemble <- function(object, model_y, ctx, terms) {
  trt <- ctx$treatment
  if (!identical(.lmer_response(object), ctx$mediator)) {
    stop("`mediator = \"", ctx$mediator, "\"` is not the response of the ",
         "mediator model (`", .lmer_response(object), "`)", call. = FALSE)
  }
  beta_m <- lme4::fixef(object)
  beta_y <- lme4::fixef(model_y)
  if (!trt %in% names(beta_m)) {
    stop("Treatment `", trt, "` is not a fixed effect of the mediator model ",
         "(a coefficient dropped as aliased?)", call. = FALSE)
  }
  pm <- length(beta_m)
  py <- length(beta_y)
  nm_m <- paste0("m_", names(beta_m))
  nm_y <- paste0("y_", names(beta_y))
  V <- matrix(0, pm + py, pm + py)
  V[seq_len(pm), seq_len(pm)] <- as.matrix(lme4::vcov.merMod(object))
  V[pm + seq_len(py), pm + seq_len(py)] <- as.matrix(lme4::vcov.merMod(model_y))

  # Alias map: a reads the treatment coefficient of the mediator model; the
  # outcome paths read terms$L (rescaling and the raw-to-within map included).
  A <- matrix(0, 4, pm + py,
              dimnames = list(c("a", "c_prime", "b_within", "b_between"), NULL))
  A["a", match(trt, names(beta_m))] <- 1
  A[c("c_prime", "b_within", "b_between"), pm + seq_len(py)] <-
    terms$L[c("c_prime", "b_within", "b_between"), names(beta_y), drop = FALSE]
  Tm <- rbind(A, diag(pm + py))
  est_all <- c(beta_m, beta_y)
  names_all <- c(rownames(A), nm_m, nm_y)
  estimates <- stats::setNames(drop(Tm %*% est_all), names_all)
  vc <- Tm %*% V %*% t(Tm)
  dimnames(vc) <- list(names_all, names_all)
  # Structural zeros: the mediator block and the outcome block are independent.
  vc[c("a", nm_m), c("c_prime", "b_within", "b_between", nm_y)] <- 0
  vc[c("c_prime", "b_within", "b_between", nm_y), c("a", nm_m)] <- 0

  sizes <- as.integer(table(factor(ctx$ids, levels = unique(ctx$ids))))
  ClusterMediationData(
    a_path = unname(estimates[["a"]]), b_within = unname(estimates[["b_within"]]),
    b_between = unname(estimates[["b_between"]]),
    c_prime = unname(estimates[["c_prime"]]),
    estimates = estimates, vcov = vc,
    treatment = trt, mediator = ctx$mediator, outcome = .lmer_response(model_y),
    cluster = ctx$cluster,
    n_obs = as.integer(stats::nobs(model_y)),
    n_clusters = length(sizes), cluster_sizes = sizes,
    parameterization = terms$parameterization,
    covariates_centered = terms$covariates_centered,
    se_type = "model",
    reml = isTRUE(lme4::isREML(object)) && isTRUE(lme4::isREML(model_y)),
    converged = .lmer_converged(object) && .lmer_converged(model_y),
    sigma_m = stats::sigma(object), sigma_y = stats::sigma(model_y),
    tau_m = .lmer_tau(object, ctx$cluster),
    tau_y = .lmer_tau(model_y, ctx$cluster),
    source_package = "lme4"
  )
}

# Register the lmer method for lme4's merMod class (lmerMod, glmerMod and
# their subclasses), so a glmerMod reaches the D7 error instead of S7's
# "can't find method". Called from .onLoad() behind requireNamespace("lme4").
#' @noRd
.register_lmer_method <- function() {
  if (requireNamespace("lme4", quietly = TRUE)) {
    mer_class <- tryCatch({
      S7::as_class(methods::getClass("merMod", where = asNamespace("lme4")))
    }, error = function(e) {
      NULL
    })
    if (!is.null(mer_class)) {
      S7::method(extract_mediation, mer_class) <- function(
        object,
        model_y,
        treatment,
        mediator,
        cluster = NULL,
        se_type = c("model", "kr"),
        vcov_fun = NULL,
        ...) {
        .extract_mediation_lmer(
          object = object, model_y = model_y, treatment = treatment,
          mediator = mediator, cluster = cluster, se_type = match.arg(se_type),
          vcov_fun = vcov_fun
        )
      }
    }
  }
}
