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
  # Term detection, rescaling and object assembly arrive in T4 and T5.
  stop("extraction from lmer fits is not implemented yet (cluster ", ctx$cluster,
       ")", call. = FALSE)
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
