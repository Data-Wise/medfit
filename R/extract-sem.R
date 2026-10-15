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

# Canonical name of the treatment-by-mediator product in a native fit's regressions, or NA when the model has none.
# `interaction` (optional) must be a product written with `:`; either order resolves to the stored `m:x` name.
.sem_native_interaction <- function(object, treatment, mediator, interaction = NULL) {
  checkmate::assert_string(interaction, null.ok = TRUE, .var.name = "interaction")
  tab <- object@table
  stored <- tab$rhs[tab$op == "~" & grepl(":", tab$rhs, fixed = TRUE)]
  canon <- .sem_product_name(treatment, mediator)
  if (!is.null(interaction)) {
    parts <- strsplit(interaction, ":", fixed = TRUE)[[1L]]
    if (length(parts) != 2L || !all(nzchar(parts))) {
      stop("`interaction` for a native fit must be the product written with `:`, as in '", treatment, ":", mediator,
           "'; a precomputed data column is fitted as an ordinary variable.", call. = FALSE)
    }
    if (!identical(.sem_product_name(parts[1L], parts[2L]), canon)) {
      stop("`interaction` ('", interaction, "') is not the product of the treatment '", treatment,
           "' and the mediator '", mediator, "'.", call. = FALSE)
    }
  }
  if (canon %in% stored) canon else NA_character_
}

# A product other than treatment:mediator that involves the treatment or the mediator changes the effects without
# changing a coefficient the a, b, c' and four-way formulas read, so it is refused on every single-mediator route.
.sem_stop_other_products <- function(object, treatment, mediator) {
  tab <- object@table
  prod <- unique(tab$rhs[tab$op == "~" & grepl(":", tab$rhs, fixed = TRUE)])
  prod <- setdiff(prod, .sem_product_name(treatment, mediator))
  hit <- prod[vapply(strsplit(prod, ":", fixed = TRUE), function(f) any(f %in% c(treatment, mediator)), logical(1))]
  if (length(hit)) {
    fac <- .sem_factor_of_product(object@internals$factors, hit[1L])
    if (!is.null(fac)) {
      stop("the native extraction does not support the product '", hit[1L], "': it comes from the factor `", fac,
           "`, so the effects differ by `", fac, "` and averaging over `", fac, "` is not supported. Fit the model ",
           "without the product, or compute the effects within each level of `", fac, "`.", call. = FALSE)
    }
    stop("the native extraction does not support the product '", hit[1L], "': a product involving the treatment ",
         "or the mediator other than '", .sem_product_name(treatment, mediator), "' changes the effects without ",
         "changing a coefficient the extraction reads. Remove it, or fit the model with lm/glm.", call. = FALSE)
  }
  invisible(NULL)
}

# The factor a product term was expanded from (one of its sides is a generated dummy), or NULL.
.sem_factor_of_product <- function(factors, product) {
  sides <- strsplit(product, ":", fixed = TRUE)[[1L]]
  for (v in names(factors)) {
    if (any(sides %in% factors[[v]]$dummies)) {
      return(v)
    }
  }
  NULL
}

# `extract_mediation()` for a native fit: the shared lavaan-route workers read the
# fit through the native accessor list, so the structures, aliases and name
# conventions cannot drift from the lavaan route. Registered at source time (the
# class lives in this package).
S7::method(extract_mediation, SEMFit) <- function(object, treatment, mediator, ...) {
  args <- list(...)
  # Four-way route: a treatment-by-mediator product in the outcome equation, written `x:m` and stored under its
  # canonical name (`x:m` and `m:x` are one term), is read through the accessor seam by the shared worker. Estimate
  # names, `outcome_predictors` and `source_package` therefore carry the canonical `m:x` where the lavaan route
  # keeps the spelling the user wrote.
  if (length(mediator) == 1L) {
    checkmate::assert_string(treatment, .var.name = "treatment")
    checkmate::assert_string(mediator, .var.name = "mediator")
    asked <- args$interaction
    decomposition <- match.arg(args$decomposition, c("auto", "four_way", "two_way"))
    int <- .sem_native_interaction(object, treatment, mediator, asked)
    .sem_stop_other_products(object, treatment, mediator)
    args$interaction <- if (is.null(asked)) NULL else int
    if (is.na(int) && (identical(decomposition, "four_way") || !is.null(asked))) {
      stop("the four-way decomposition of a native fit needs the treatment-by-mediator product in the outcome ",
           "equation: add `", treatment, ":", mediator, "` to it, for example `y ~ ", treatment, " + ", mediator,
           " + ", treatment, ":", mediator, "`. Native products are written in the model syntax, not as a ",
           "precomputed data column.", call. = FALSE)
    }
  } else if (!is.null(args$interaction)) {
    stop("`interaction` applies to a single mediator.", call. = FALSE)
  }
  out <- do.call(extract_mediation_lavaan,
                 c(list(.sem_accessors_native(object), treatment = treatment, mediator = mediator), args))
  out@source_package <- "medfit"
  out
}
