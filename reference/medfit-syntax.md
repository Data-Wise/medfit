# medfit Model Syntax

**\[experimental\]**

The model syntax read by
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
and by `fit_mediation(engine = "native")`. It is a lavaan-style core
plus two extensions, each marked "medfit extension" below. One statement
per line (or separated by `;`).

## Core statements

|  |  |
|----|----|
| Statement | Meaning |
| `y ~ x1 + x2` | regression of `y` on `x1` and `x2` |
| `f =~ y1 + y2 + y3` | latent variable `f` measured by the indicators |
| `y1 ~~ y2` | covariance; `y1 ~~ y1` a variance |
| `y ~ a*x` | label the path `a`; equal labels are one parameter |
| `y ~ 0.5*x` | fix the path at 0.5 |
| `y ~ start(0.3)*x`, `lower(0)*`, `upper(1)*` | starting value, lower and upper bound |
| `a == b`, `a + b == 1` | equality constraint on labels |
| `a < b`, `a > 0` | inequality constraint; `label < number` is a bound |
| `ab := a*b` | defined parameter, with a delta-method standard error |

Constraints must be linear in the labels. Labels used in a constraint or
a definition must be defined in the model. A constraint with no free
parameter, or a nonlinear one, is an error. Exogenous variables are
given free variances and covariances, as lavaan does with
`fixed.x = FALSE`. Mean structures (`y ~ 1`) are not supported, except
that `y ~ 0*1` is accepted.

## medfit extensions

- **Comma shorthand** (medfit extension). A comma-separated left side
  expands to one statement per name: `y1, y2 ~ x` means `y1 ~ x` and
  `y2 ~ x`. Commas on the right side are not supported; use `+`.
  **lavaan reads `y1, y2 ~ x` differently: it silently keeps only
  `y2`.** A model copied between the two packages can therefore change
  meaning without an error.

- **`CONSTRAINT(...)`** (medfit extension). A constraint line may be
  written `CONSTRAINT(a == b)`, equivalent to the bare `a == b`. The
  keyword is case-sensitive and starts the statement, one pair of
  parentheses encloses the whole constraint, it holds exactly one
  comparison, and no text follows the closing parenthesis.

## Expressions

Both sides of a constraint and the right side of a definition are
arithmetic expressions in the labels, with `+ - * / ^`, parentheses,
finite numbers, and the functions `exp`, `log`, `log10`, `sqrt`, `abs`,
`min`, `max`, `sin`, `cos`, `tan`, `pnorm` and `qnorm`. Anything else is
rejected with the construct named.

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)

## Examples

``` r
# \donttest{
# Labeled paths and a defined parameter
fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\nab := a*b",
  data = mediation_demo
)@defined
#>   name expr       est         se
#> 1   ab  a*b 0.3253207 0.08016376

# Comma shorthand: one left-hand side per name
coef(fit_sem(
  "mediator1, mediator2 ~ treatment\noutcome ~ mediator1 + mediator2 + treatment",
  data = mediation_demo
))[1:3]
#> mediator1 ~ treatment mediator2 ~ treatment   outcome ~ mediator1 
#>             0.4559961             0.2879984             0.5202186 

# An equality constraint, written with the CONSTRAINT() keyword
coef(fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nCONSTRAINT(a == b)",
  data = mediation_demo
))[c("a", "b")]
#>         a         b 
#> 0.6673103 0.6673103 
# }
```
