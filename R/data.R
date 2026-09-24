#' Simulated Mediation Data for Examples
#'
#' A simulated dataset for demonstrating medfit's simple, serial, parallel,
#' and treatment-by-mediator interaction workflows with one running example.
#' The data are **simulated**: they describe no real study, population, or
#' finding.
#'
#' The variables follow a fictional workplace-training story, used only so the
#' examples read concretely: randomized assignment to a training program
#' (`treatment`) raises skill confidence (`mediator1`), which builds task
#' mastery (`mediator2`); the assignment also triggers supervisor check-ins
#' (`mediator3`); `outcome` is job performance.
#'
#' @format A data frame with 400 rows and 8 variables:
#' \describe{
#'   \item{treatment}{Integer, 0/1. Randomized treatment assignment.}
#'   \item{mediator1}{Numeric. First mediator; affected by `treatment`.}
#'   \item{mediator2}{Numeric. Serial mediator; affected by `treatment` and
#'     `mediator1`.}
#'   \item{mediator3}{Numeric. Parallel mediator; affected by `treatment` only.}
#'   \item{covariate1}{Numeric. Continuous confounder of the mediator-outcome
#'     relations.}
#'   \item{covariate2}{Integer, 0/1. Binary confounder of the mediator-outcome
#'     relations.}
#'   \item{outcome}{Numeric. Outcome with no product terms; use it for the
#'     simple, serial, and parallel models.}
#'   \item{outcome_int}{Numeric. `outcome` plus a `treatment` by `mediator1`
#'     interaction; use it only for models with that interaction: the four-way
#'     decomposition with a single mediator, or joint effects with several
#'     mediators ([JointMediationData]).}
#' }
#'
#' @details
#' All errors are independent standard normal. The generating equations are
#' \deqn{M_1 = 0.5X + 0.3C_1 + 0.3C_2 + e_1}{M1 = 0.5X + 0.3C1 + 0.3C2 + e1}
#' \deqn{M_2 = 0.2X + 0.5M_1 + 0.2C_1 + e_2}{M2 = 0.2X + 0.5M1 + 0.2C1 + e2}
#' \deqn{M_3 = 0.5X + e_3}{M3 = 0.5X + e3}
#' \deqn{Y = 0.2X + 0.4M_1 + 0.3M_2 + 0.3M_3 + 0.3C_1 + 0.2C_2 + e_4}{
#'   Y = 0.2X + 0.4M1 + 0.3M2 + 0.3M3 + 0.3C1 + 0.2C2 + e4}
#' and `outcome_int` adds \eqn{0.5 X M_1}{0.5 X M1}.
#'
#' Because the covariates confound the mediator-outcome relations, every model
#' should adjust for both `covariate1` and `covariate2`. A model that omits a
#' downstream mediator estimates reduced-form coefficients rather than the
#' structural ones above: for example, the simple model `outcome ~ treatment +
#' mediator1 + covariates` has limiting coefficients 0.55 for `mediator1` and
#' 0.41 for `treatment`. For a serial model, include `mediator1` in the outcome
#' model as well; the serial indirect effect \eqn{a \times d \times b}{a * d * b}
#' is then the effect through the chain `mediator1` to `mediator2` only.
#'
#' @source Simulated for package demonstration; not drawn from or representing
#'   any real study. The generating script is `data-raw/mediation_demo.R` in
#'   the package source repository.
#'
#' @examples
#' data(mediation_demo)
#' str(mediation_demo)
#'
#' # Simple mediation, adjusting for both covariates
#' fit <- fit_mediation(
#'   formula_y = outcome ~ treatment + mediator1 + covariate1 + covariate2,
#'   formula_m = mediator1 ~ treatment + covariate1 + covariate2,
#'   data = mediation_demo,
#'   treatment = "treatment",
#'   mediator = "mediator1"
#' )
#' nie(fit)
"mediation_demo"
