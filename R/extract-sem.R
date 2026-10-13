# The accessor seam between a fitted SEM and the mediation extractors.
#
# Internal. The workers in extract-lavaan.R (simple, serial, parallel and
# four-way extraction) read a fitted model only through an accessor list, never
# by calling lavaan directly. `.sem_accessors_lavaan()` fills the list from a
# lavaan fit; a native fit supplies its own list with the same fields, so the
# workers are shared instead of copied (plan section 2.4, Q6).
#
# Fields (all functions of no arguments unless noted):
#   param_table(standardized)  parameter table: lhs, op, rhs, label, est, se
#                              (est.std when standardized = TRUE)
#   coef(), vcov()             free-parameter estimates and their covariance
#   partable()                 parameter table with the label column
#   data()                     the model's data (matrix or data.frame)
#   weights()                  case weights over the rows of data(), or NULL
#   converged()                logical convergence flag
#   nobs()                     sample size (per group)
#   names(type)                variable names of a type ("ov", "ov.ord")

.sem_accessors_lavaan <- function(object) {
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("Package 'lavaan' is required for this method but is not installed.",
         call. = FALSE)
  }
  force(object)
  structure(
    list(
      param_table = function(standardized = FALSE) {
        if (standardized) lavaan::standardizedSolution(object) else lavaan::parameterEstimates(object)
      },
      coef = function() lavaan::coef(object),
      vcov = function() lavaan::vcov(object),
      partable = function() lavaan::parTable(object),
      data = function() lavaan::lavInspect(object, "data"),
      weights = function() {
        w <- object@Data@weights
        if (length(w) > 1L && !all(vapply(w, is.null, logical(1)))) {
          stop("sampling weights in a multi-group lavaan fit are not supported ",
               "by the four-way decomposition", call. = FALSE)
        }
        if (length(w) == 1L) w[[1L]] else NULL
      },
      converged = function() lavaan::lavInspect(object, "converged"),
      nobs = function() lavaan::lavInspect(object, "nobs"),
      names = function(type) lavaan::lavNames(object, type)
    ),
    class = "sem_accessors"
  )
}

# An accessor list passes through; anything else is taken to be a lavaan fit.
.sem_as_accessors <- function(object) {
  if (inherits(object, "sem_accessors")) object else .sem_accessors_lavaan(object)
}

# Accessor list for a native fit (`SEMFit`), with the same fields as the lavaan
# one so the extraction workers are shared. Names are those of `coef()`, lavaan's
# coefficient convention (the label when a row has one, else `lhs op rhs` without
# spaces), because the workers locate a path's covariance row by that name.
.sem_accessors_native <- function(object) {
  checkmate::assert_class(object, "medfit::SEMFit", .var.name = "object")
  tab <- object@table
  nm <- names(object@theta)
  coefs <- object@theta
  vc <- unname(object@vcov)
  dimnames(vc) <- list(nm, nm)
  ptab <- data.frame(
    lhs = tab$lhs, op = tab$op, rhs = tab$rhs, label = ifelse(is.na(tab$label), "", tab$label),
    est = tab$est, se = tab$se, stringsAsFactors = FALSE
  )
  obs <- object@internals$ram$obs
  structure(
    list(
      param_table = function(standardized = FALSE) {
        if (standardized) {
          stop("standardized estimates are not supported by engine = \"native\" in this version", call. = FALSE)
        }
        ptab
      },
      coef = function() coefs,
      vcov = function() vc,
      partable = function() ptab,
      data = function() object@data,
      weights = function() object@internals$weights,
      converged = function() object@converged,
      nobs = function() object@n_obs,
      names = function(type) if (identical(type, "ov")) obs else character()
    ),
    class = "sem_accessors"
  )
}

# `extract_mediation()` for a native fit: the shared lavaan-route workers read the
# fit through the native accessor list, so the structures, aliases and name
# conventions cannot drift from the lavaan route. Registered at source time (the
# class lives in this package).
S7::method(extract_mediation, SEMFit) <- function(object, treatment, mediator, ...) {
  out <- tryCatch(
    extract_mediation_lavaan(.sem_accessors_native(object), treatment = treatment, mediator = mediator, ...),
    error = function(e) {
      # The four-way decomposition reads the mediator intercept, which the native engine does not estimate
      # (free intercepts are outside this version); the lavaan wording would send the user to a lavaan option.
      if (grepl("meanstructure", conditionMessage(e), fixed = TRUE)) {
        stop("the four-way decomposition needs the mediator intercept, which engine = \"native\" does not ",
             "estimate in this version; use `decomposition = \"two_way\"`, or fit with a lavaan model that has ",
             "`meanstructure = TRUE`.", call. = FALSE)
      }
      stop(e)
    }
  )
  out@source_package <- "medfit"
  out
}
