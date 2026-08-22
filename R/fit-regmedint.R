# Fit Mediation Models Using the regmedint Engine
#
# This file implements the `engine = "regmedint"` adapter for fit_mediation():
# a translation layer from medfit's formula-based interface to
# regmedint::regmedint(), returning MediationData or InteractionMediationData.
#
# See planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md.

#' regmedint Engine for Mediation Fitting
#'
#' Adapter from `fit_mediation()`'s formula interface to
#' `regmedint::regmedint()`. Dispatched from `fit_mediation()` when
#' `engine = "regmedint"`.
#'
#' @param formula_y Outcome model formula
#' @param formula_m Mediator model formula
#' @param data Data frame
#' @param treatment Treatment variable name
#' @param mediator Mediator variable name
#' @param family_y Family for outcome model
#' @param family_m Family for mediator model
#' @param engine_args Named list of regmedint-specific overrides
#' @param ... Additional arguments (currently unused)
#'
#' @return A MediationData or InteractionMediationData object
#' @keywords internal
#' @noRd
.adapter_regmedint <- function(formula_y,
                               formula_m,
                               data,
                               treatment,
                               mediator,
                               family_y,
                               family_m,
                               engine_args = list(),
                               ...) {
  if (!requireNamespace("regmedint", quietly = TRUE)) {
    stop(
      "engine = \"regmedint\" requires the 'regmedint' package. ",
      "Install it with install.packages(\"regmedint\").",
      call. = FALSE
    )
  }
  # Phase 1 (dispatch extension) ships the switch arm and the Suggests guard
  # only; the translation layer lands in Phase 2 of the orchestrate plan.
  stop("engine = \"regmedint\" is not yet implemented.", call. = FALSE)
}
