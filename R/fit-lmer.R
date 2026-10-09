# lmer engine for cluster-level mediation (2-1-1)
#
# fit_mediation(engine = "lmer", cluster = ) prepares the data, fits the two
# linear mixed models and hands them to extract_mediation(), so the effects and
# SEs come from the same code as the extract route (route identity).
#
#   - Mediator model: M ~ X + covariates + (1 | cluster)
#   - Outcome model:  Y ~ X + M_cwc + M_cm + covariates + (1 | cluster), with
#     level-1 covariates split the same way and level-2 covariates untouched.

# Is `pkg` installed? A named function so tests can mock the absence.
.pkg_available <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

.assert_pkg <- function(pkg, what) {
  if (!.pkg_available(pkg)) {
    stop("Package '", pkg, "' is required for ", what, "; install it with ",
         "install.packages(\"", pkg, "\").", call. = FALSE)
  }
  invisible(TRUE)
}

#' lmer Engine for Cluster-Level Mediation
#'
#' @inheritParams fit_mediation
#' @param cluster Character name of the cluster variable in `data`.
#' @param se_type `"model"` (the lmer engine's only value so far).
#' @param ... Must be empty: arguments never reach `lmer()`.
#' @return A [ClusterMediationData] object.
#' @keywords internal
#' @noRd
.fit_mediation_lmer <- function(formula_y, formula_m, data, treatment, mediator,
                                cluster, se_type = "model", engine_args = list(),
                                ...) {
  if (...length() > 0L) {
    stop("engine = \"lmer\" takes no extra arguments; unused: ",
         paste(names(list(...)), collapse = ", "),
         ". Use `engine_args` for random slopes and REML.", call. = FALSE)
  }
  .assert_pkg("lme4", "engine = \"lmer\"")
  checkmate::assert_string(cluster, .var.name = "cluster")
  checkmate::assert_choice(cluster, choices = names(data),
                           .var.name = "cluster (must be in data)")
  args <- .lmer_engine_args(engine_args)

  # Drop incomplete rows once, so both models and the cluster means use the same
  # rows (D12).
  vars <- unique(c(all.vars(formula_y), all.vars(formula_m), cluster))
  absent <- setdiff(vars, names(data))
  if (length(absent)) {
    stop("Variables not found in `data`: ", paste(absent, collapse = ", "),
         call. = FALSE)
  }
  dat <- data[stats::complete.cases(data[, vars, drop = FALSE]), , drop = FALSE]
  if (nrow(dat) < 2L) stop("No complete rows remain after dropping missing values.",
                           call. = FALSE)
  cl <- dat[[cluster]]

  # Level-1 covariates: numeric variables that vary within some cluster.
  roles <- c(treatment, mediator, all.vars(formula_y[[2]]),
             all.vars(formula_m[[2]]), cluster)
  covs <- setdiff(union(all.vars(formula_y[-2]), all.vars(formula_m[-2])), roles)
  varies <- function(v) {
    is.numeric(v) && any(tapply(v, cl, function(z) length(unique(z)) > 1L))
  }
  lvl1 <- Filter(function(nm) varies(dat[[nm]]), covs)

  # <M>_cm, <M>_cwc, <C>_cm, <C>_cwc on the remaining rows.
  to_split <- c(mediator, lvl1)
  new_cols <- c(paste0(to_split, "_cm"), paste0(to_split, "_cwc"))
  clash <- intersect(new_cols, names(dat))
  if (length(clash)) {
    stop("`data` already has column(s) the engine creates: ",
         paste(clash, collapse = ", "), ". Rename them.", call. = FALSE)
  }
  for (nm in to_split) {
    dat[[paste0(nm, "_cm")]] <- stats::ave(dat[[nm]], cl)
    dat[[paste0(nm, "_cwc")]] <- dat[[nm]] - dat[[paste0(nm, "_cm")]]
  }

  fml_y <- .lmer_outcome_formula(formula_y, mediator, lvl1, cluster, args$random_y)
  fml_m <- .lmer_mediator_formula(formula_m, cluster, args$random_m)
  fit_m <- lme4::lmer(fml_m, data = dat, REML = args$REML)
  fit_y <- lme4::lmer(fml_y, data = dat, REML = args$REML)
  extract_mediation(fit_m, model_y = fit_y, treatment = treatment,
                    mediator = mediator, cluster = cluster, se_type = se_type)
}

# Validate `engine_args`: only random_y, random_m and REML are accepted.
.lmer_engine_args <- function(engine_args) {
  allowed <- c("random_y", "random_m", "REML")
  bad <- setdiff(names(engine_args), allowed)
  if (length(bad)) {
    stop("Unknown `engine_args` for engine = \"lmer\": ",
         paste(bad, collapse = ", "), ". Recognized: ",
         paste(allowed, collapse = ", "), ".", call. = FALSE)
  }
  out <- list(random_y = NULL, random_m = NULL, REML = TRUE)
  out[names(engine_args)] <- engine_args
  checkmate::assert_flag(out$REML, .var.name = "engine_args$REML")
  for (nm in c("random_y", "random_m")) {
    f <- out[[nm]]
    if (!is.null(f) && !(inherits(f, "formula") && length(f) == 2L)) {
      stop("`engine_args$", nm, "` must be a one-sided formula such as ~ M.",
           call. = FALSE)
    }
  }
  out
}

# A random-effect term (1 + slopes | cluster).
.lmer_re_term <- function(slopes, cluster) {
  sprintf("(1 + %s | %s)", paste(slopes, collapse = " + "), cluster)
}

# Rewrite the outcome formula: the mediator and level-1 covariates become their
# within-cluster deviation plus cluster mean; a random slope on the mediator or
# a level-1 covariate is moved to the within term. Any other term that involves
# the mediator is refused (products are not supported).
.lmer_outcome_formula <- function(formula_y, mediator, lvl1, cluster, random_y) {
  tt <- stats::terms(formula_y)
  if (attr(tt, "intercept") == 0L) {
    stop("The outcome model needs an intercept.", call. = FALSE)
  }
  labs <- attr(tt, "term.labels")
  split_var <- c(mediator, lvl1)
  new <- unlist(lapply(labs, function(l) {
    if (l %in% split_var) return(c(paste0(l, "_cwc"), paste0(l, "_cm")))
    if (mediator %in% all.vars(stats::reformulate(l)[[2]])) {
      stop("The term `", l, "` involves the mediator `", mediator, "`; ",
           "products and transformations of the mediator are not supported ",
           "(it must enter as a plain linear term).", call. = FALSE)
    }
    l
  }))
  re <- if (is.null(random_y)) {
    sprintf("(1 | %s)", cluster)
  } else {
    sl <- all.vars(random_y)
    sl <- ifelse(sl %in% split_var, paste0(sl, "_cwc"), sl)
    .lmer_re_term(sl, cluster)
  }
  fml <- stats::reformulate(c(unique(new), re), response = formula_y[[2]])
  environment(fml) <- environment(formula_y)
  fml
}

# The mediator model keeps its fixed part and gains the cluster intercept (and
# any random slopes on level-1 terms).
.lmer_mediator_formula <- function(formula_m, cluster, random_m) {
  labs <- attr(stats::terms(formula_m), "term.labels")
  re <- if (is.null(random_m)) {
    sprintf("(1 | %s)", cluster)
  } else {
    .lmer_re_term(all.vars(random_m), cluster)
  }
  fml <- stats::reformulate(c(labs, re), response = formula_m[[2]])
  environment(fml) <- environment(formula_m)
  fml
}
