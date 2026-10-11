# Minimum-of-Two Likelihood-Ratio Test for an Indirect Effect (MBCO)

**\[experimental\]**

Tests the null hypothesis that the indirect effect \\a b\\ is zero in a
model fitted by
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).
The model is refitted twice, with \\a = 0\\ and with \\b = 0\\; each is
a linear equality constraint, so each refit is a single solve. The
statistic is the smaller of the two likelihood-ratio statistics,
referred to a chi-square distribution with one degree of freedom (the
minimum-of-two LRTs; see the Methods and Formulas article). The
nonlinear constraint \\a b = 0\\ is never solved, because a nonlinear
solver can stop at the branch with the larger statistic.

## Usage

``` r
mbco_sem(fit, a, b, n_starts = NULL, control = NULL)
```

## Arguments

- fit:

  A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
  from
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
  fitted without sampling weights.

- a, b:

  Character strings: the labels of the two free regression paths whose
  product is the indirect effect (for example `"a"` and `"b"` in
  `"M ~ a*X"` and `"Y ~ b*M"`). They must be different, and each must be
  a labeled `~` row of the fit; a variance, a loading, an unlabeled path
  and a defined parameter are refused.

- n_starts, control:

  Passed to the optimizer for the two refits, as in
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).
  `NULL`, the default, uses the settings `fit` was made with, so a
  better optimum in the full fit than in a refit cannot inflate the
  statistic; an explicit value overrides them.

## Value

An object of class `c("mbco_sem", "htest")`: `statistic` (the smaller
diffLL), `parameter` (`df = 1`), `p.value`, `method`, `data.name`,
`n_obs`, and `tests`, a data frame with one row per refit (`constraint`,
the minimized discrepancy `f`, `diff_ll` equal to `n_obs * (f - fit@f)`,
and `converged`, always `TRUE` because a refit that does not converge is
an error). It prints with the standard `htest` layout.

## Details

A fit made with `sampling_weights` is refused: the weighted discrepancy
is not a likelihood, so its difference is not chi-square. So is a fit
that did not converge, since its discrepancy is the reference both
refits are measured against. A refit that fails the acceptance gate of
the optimizer is an error rather than a statistic.

Inequality constraints in the model matter only when they put the null
on the boundary of the parameter space. If a bound or an inequality that
involves the tested parameter is active at its refit (`a > 0` with the
null `a = 0`), the function warns that the statistic is a mixture of
chi-squares, not chi-square(1), and that the p-value is not valid. A
bound the null sits inside (`a < 0.2`), an inactive inequality and one
on another parameter are not mentioned. A null the constraints rule out
(`a > 0.3` with the null `a = 0`) is an error that says so.

Only a product of two labeled paths is tested. A serial indirect effect
(a product of three paths) or a sum of products is not. If `a` and `b`
are tied by an equality (`a == b`), the two refits impose the same
restriction and the two `diff_ll` values coincide.

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
# }
```
