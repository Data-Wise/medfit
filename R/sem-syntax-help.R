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
#' | `a == b`, `a + b == 1` | equality constraint on labels |
#' | `a < b`, `a > 0` | inequality constraint; `label < number` is a bound |
#' | `ab := a*b` | defined parameter, with a delta-method standard error |
#'
#' Constraints must be linear in the labels. Labels used in a constraint or a
#' definition must be defined in the model. A constraint with no free parameter,
#' or a nonlinear one, is an error. Exogenous variables are given free
#' variances and covariances, as lavaan does with `fixed.x = FALSE`. Mean
#' structures (`y ~ 1`) are not supported, except that `y ~ 0*1` is accepted.
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
#' @seealso [fit_sem()], [SEMFit]
#' @name medfit-syntax
#' @aliases medfit_syntax
NULL
