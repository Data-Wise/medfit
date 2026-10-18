# Minimum-of-k Likelihood-Ratio Test for an Indirect Effect (MBCO)

Tests the null hypothesis that an indirect effect, the product of two or
more labeled paths (\\a b\\, or a serial \\a d b\\), is zero in a model
fitted by
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).
The product is zero exactly when one factor is, so the model is refitted
once per path with that path set to zero; each is a linear equality
constraint, so each refit is a single solve. The statistic is the
smallest of the likelihood-ratio statistics, referred to a chi-square
distribution with one degree of freedom (the minimum-of-k LRTs; see the
Methods and Formulas article). The nonlinear constraint \\a b = 0\\ is
never solved, because a nonlinear solver can stop at the branch with the
larger statistic.

## Usage

``` r
mbco_sem(
  object,
  a,
  b,
  n_starts = NULL,
  control = NULL,
  fit = lifecycle::deprecated(),
  paths = NULL
)
```

## Arguments

- object:

  A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
  from
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
  fitted without `weights`.

- a, b:

  Character strings: the labels of the two free regression paths whose
  product is the indirect effect (for example `"a"` and `"b"` in
  `"M ~ a*X"` and `"Y ~ b*M"`). They must be different, and each must be
  a labeled `~` row of the fit; a variance, a loading, an unlabeled path
  and a defined parameter are refused. For a product of more than two
  paths pass them all as `paths`, or as a character vector in `a` with
  `b` missing.

- n_starts, control:

  Passed to the optimizer for the two refits, as in
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).
  `NULL`, the default, uses the settings `object` was made with, so a
  better optimum in the full fit than in a refit cannot inflate the
  statistic; an explicit value overrides them.

- fit:

  **\[deprecated\]** Renamed `object`; the old name still works with a
  warning.

- paths:

  Character vector of two or more labels: the paths whose product is the
  indirect effect (`c("a", "d", "b")`). `NULL`, the default, uses `a`
  and `b`.

## Value

An object of class `c("mbco_sem", "htest")`: `statistic` (the smallest
diffLL), `parameter` (`df = 1`), `p.value`, `method`, `data.name`,
`n_obs`, and `tests`, a data frame with one row per refit (`constraint`,
the minimized discrepancy `f`, `diff_ll` equal to `n_obs * (f - fit@f)`,
and `converged`, always `TRUE` because a refit that does not converge is
an error). It prints with the standard `htest` layout.

## Details

A fit made with `weights` is refused: the weighted discrepancy is not a
likelihood, so its difference is not chi-square. So is a fit that did
not converge, since its discrepancy is the reference both refits are
measured against. A refit that fails the acceptance gate of the
optimizer is an error rather than a statistic.

Inequality constraints in the model matter only when they put the null
on the boundary of the parameter space. If a bound or an inequality that
involves the tested parameter is active at its refit (`a > 0` with the
null `a = 0`), the function warns that the statistic is a mixture of
chi-squares, not chi-square(1), and that the p-value is not valid. A
bound the null sits inside (`a < 0.2`), an inactive inequality and one
on another parameter are not mentioned. A null the constraints rule out
(`a > 0.3` with the null `a = 0`) is an error that says so.

Only a product of labeled paths is tested; a sum of products (several
parallel indirect effects together) is not. If two of the paths are tied
by an equality (`a == b`), their refits impose the same restriction and
their `diff_ll` values coincide. The test is conservative: under a null
where only one factor is zero its size is at most the nominal level, and
with more than one zero factor it is smaller still.

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)

## Examples

``` r
# \donttest{
fit <- fit_sem(
  "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment",
  data = mediation_demo
)
mbco_sem(fit, "a", "b")
#> 
#>  Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect
#> 
#> data:  a * b = 0
#> MBCO = 17.557, df = 1, p-value = 2.788e-05
#> 

# a serial indirect effect, the product of three paths
serial <- fit_sem(
  paste0("mediator1 ~ a*treatment\nmediator2 ~ d*mediator1 + treatment\n",
         "outcome ~ b*mediator2 + treatment"),
  data = mediation_demo
)
mbco_sem(serial, paths = c("a", "d", "b"))
#> 
#>  Minimum-of-3 likelihood-ratio tests (MBCO) for an indirect effect
#> 
#> data:  a * d * b = 0
#> MBCO = 17.557, df = 1, p-value = 2.788e-05
#> 
# }
```
