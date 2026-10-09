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
