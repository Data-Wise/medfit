#' medfit Model Syntax
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The model syntax read by [fit_sem()] and by `fit_mediation(engine =
#' "native")`. It is a lavaan-style core plus two extensions, each marked
#' "medfit extension" below. One statement per line (or separated by `;`).
#'
#' @section Core statements:
#' | Statement | Meaning |
#' |:--|:--|
#' | `y ~ x1 + x2` | regression of `y` on `x1` and `x2` |
#' | `f =~ y1 + y2 + y3` | latent variable `f` measured by the indicators |
#' | `y1 ~~ y2` | covariance; `y1 ~~ y1` a variance |
#' | `y ~ a*x` | label the path `a`; equal labels are one parameter |
#' | `y ~ 0.5*x` | fix the path at 0.5 |
#' | `y ~ start(0.3)*x`, `lower(0)*`, `upper(1)*` | starting value, lower and upper bound |
#' | `a == b`, `a + b == 1`, `cp == a*b` | equality constraint on labels; may be nonlinear |
#' | `a < b`, `a > 0` | inequality constraint; `label < number` is a bound |
#' | `ab := a*b` | defined parameter, with a delta-method standard error |
#'
#' Constraints may be nonlinear in the labels (`cp == a*b`, `a*b == 0.1`,
#' `a*b > 0.1`, `ab > 0` with `ab := a*b`), solved with the Jacobian recomputed at
#' every point; a model with one tries every start and keeps the best accepted
#' solution, warning when the starts disagree. A product of labels set to zero
#' (`a*b == 0`, `b1*b2*b3 == 0`) is instead solved exactly: one linear fit per
#' factor (`a == 0`, `b == 0`), keeping the smallest discrepancy. A sum of products
#' (`a1*b1 + a2*b2 == 0`) has no exact reduction, so it is best-effort: the fit is
#' the best of the starts tried, a disagreement warning means a better optimum may
#' exist, and `n_starts` raises the number of starts. Labels used in a constraint
#' or a definition must be defined in the model. A constraint with no free
#' parameter is an error. Exogenous variables are given free
#' variances and covariances, as lavaan does with `fixed.x = FALSE`; `fixed_x = TRUE`
#' (or a vector of names) in [fit_sem()] fixes the moments of the selected ones at the
#' sample values instead, as `fixed.x = TRUE` does. Unlike lavaan, which keeps an
#' explicit `x ~~ x` or `x ~ 1` free under `fixed.x = TRUE` and lets the degrees of
#' freedom move, medfit stops with an error when the model has a statement on a
#' selected variable's moments. Any
#' intercept statement (`y ~ 1`, or `1` as a term: `y ~ 1 + x`) turns the mean structure
#' on and frees every observed intercept the model does not write, as lavaan does;
#' `y ~ 0*1` then restricts the mean of `y` to 0 (one degree of freedom), and
#' `meanstructure = TRUE` in [fit_sem()] turns it on without any statement, and a product term
#' (`x:m`) always turns it on. A
#' latent variable's mean is fixed at 0; a free latent `~1` is an error. A repeated `1` for one
#' variable is an error.
#' A variable cannot appear on both sides of `~` or `=~` (`y ~ y`), and a path,
#' a (co)variance or an intercept takes one row: a repeated `y ~ x` is an error,
#' not a second row that competes for the label.
#'
#' @section medfit extensions:
#' * **Comma shorthand** (medfit extension). A comma-separated left side
#'   expands to one statement per name: `y1, y2 ~ x` means `y1 ~ x` and
#'   `y2 ~ x`. Commas on the right side are not supported; use `+`.
#'   **lavaan reads `y1, y2 ~ x` differently: it silently keeps only `y2`.**
#'   A model copied between the two packages can therefore change meaning
#'   without an error.
#' * **`CONSTRAINT(...)`** (medfit extension). A constraint line may be
#'   written `CONSTRAINT(a == b)`, equivalent to the bare `a == b`. The keyword
#'   is case-sensitive and starts the statement, one pair of parentheses
#'   encloses the whole constraint, it holds exactly one comparison, and no
#'   text follows the closing parenthesis.
#'
#' @section Expressions:
#' Both sides of a constraint and the right side of a definition are
#' arithmetic expressions in the labels, with `+ - * / ^`, parentheses, finite
#' numbers, and the functions `exp`, `log`, `log10`, `sqrt`, `abs`, `min`, `max`,
#' `sin`, `cos`, `tan`, `pnorm` and `qnorm`. Anything else is
#' rejected with the construct named.
#'
#' @examples
#' \donttest{
#' # Labeled paths and a defined parameter
#' fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\nab := a*b",
#'   data = mediation_demo
#' )@defined
#'
#' # Comma shorthand: one left-hand side per name
#' coef(fit_sem(
#'   "mediator1, mediator2 ~ treatment\noutcome ~ mediator1 + mediator2 + treatment",
#'   data = mediation_demo
#' ))[1:3]
#'
#' # An equality constraint, written with the CONSTRAINT() keyword
#' coef(fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nCONSTRAINT(a == b)",
#'   data = mediation_demo
#' ))[c("a", "b")]
#' }
#'
#' @seealso [fit_sem()], [SEMFit]
#' @name medfit-syntax
#' @aliases medfit_syntax
NULL
