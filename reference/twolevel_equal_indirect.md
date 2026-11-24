# Test equal indirect effects across the two levels of a native two-level fit

**\[experimental\]** Likelihood-ratio test of the null that the
within-level and the between-level indirect effects are equal, \\a_w b_w
= a_b b_b\\, for a native two-level fit from
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
with `cluster =`. The statistic is the free fit's likelihood against the
fit with that one nonlinear equality. It is a separate test: the
descriptive within-minus-between contrast of `nie(level = "contrast")`
is never reported by
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md) with a
p-value, and there is no Wald test of it here.

## Usage

``` r
twolevel_equal_indirect(
  object,
  a_within = "a_w",
  b_within = "b_w",
  a_between = "a_b",
  b_between = "b_b",
  n_starts = NULL,
  control = NULL,
  n_boot = 0L,
  seed = NULL
)
```

## Arguments

- object:

  A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
  from
  [`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
  with `cluster =` (a two-level model).

- a_within, b_within:

  The labels of the within-level (level 1) `a` and `b` regression paths.

- a_between, b_between:

  The labels of the between-level (level 2) `a` and `b` regression
  paths.

- n_starts, control:

  Optimizer settings for the constrained refit; `NULL` keeps the fit's
  own.

- n_boot:

  Number of parametric bootstrap replications of the statistic (default
  0, none). Each replication draws clustered data of the same cluster
  sizes from the constrained fit, refits both models and keeps the
  statistic; replications that do not resolve (an inadmissible,
  non-positive-definite or non-converged refit) are dropped, so the
  bootstrap p-value is conditional on admissible refits, and the number
  dropped is reported (`boot$n_dropped`). The bootstrap p-value is
  `(1 + #{LR* >= LR}) / (n_valid + 1)`; use it at a small number of
  clusters, where the between-level asymptotics are poor.

- seed:

  Optional integer seed for the bootstrap; the caller's random number
  state is restored.

## Value

An object of class `c("twolevel_equal_indirect", "htest")`: `statistic`
(`LR`, the scale of
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)),
`parameter` (`df = 1`), `p.value` (chi-square(1)), `method`,
`data.name`, `n_obs`, `n_clusters`, `level` (`c("within", "between")`),
`indirect` (the two indirect effects of the free fit and of the
constrained fit), `unresolved`, `note`, `near_singular`, `twin`, and
`boot` (`NULL`, or a list with `statistic`, `p.value`, `n_boot`,
`n_valid` and `n_dropped` when `n_boot > 0`). `twin` records what the
twin certificate did, for resolved and unresolved results: `tried` (a
twin refit was attempted), `replaced` (a twin replaced the kept fit),
`flipped` (read from the signs of the adopted fit's four path estimates
against the kept fit's, not from the start that produced it: `"within"`
or `"between"` when both paths of that pair changed sign, `"other"` once
for any other sign change, including a path that reaches or leaves zero,
and empty when no sign changed, as when the twin is another optimum in
the kept fit's sign pattern), `f_gain` (the kept discrepancy minus the
adopted one, 0 if none; the statistic drops by `n_obs * f_gain`) and
`unresolved` (a better inadmissible or covariance-stage twin made the
result unresolved). [`print()`](https://rdrr.io/r/base/print.html) does
not show it.

## Details

The null `a_w b_w = a_b b_b` is a smooth surface except where all four
paths are 0, where it is singular. Away from that point the
likelihood-ratio statistic is referred to chi-square(1), an asymptotic
law in the number of clusters `J` (the between-level paths rest on `J`
clusters). Near it, and when a level-2 variance is near the boundary,
the chi-square(1) law may not hold; no closed-form law is claimed. The
function warns when all four free-fit paths are within two standard
errors of 0 (class `medfit_warning_twolevel_equal_singular`) and when a
level-2 variance at the constrained fit is below 1% of its implied
between plus within variance.

The constrained surface has sign twins: flipping the signs of the within
pair \\(a_w, b_w)\\, the between pair \\(a_b, b_b)\\ or both leaves the
equality satisfied, at a worse likelihood. The optimizer's "the starts
disagree" warning is not raised when every disagreeing accepted start is
such a twin of the kept fit; the lowest-discrepancy start is kept. Any
other disagreement among the starts, and every other optimizer warning,
is signaled as usual.

After the refit the pair-sign twins of the kept fit are tried as well (a
twin certificate): each flip of a pair with no zero is fitted once from
the kept estimates with that flip, and the lowest discrepancy is kept.
It is a local search of up to three single-start solves, not a proof of
a global optimum: a twin refit that fails is skipped, and the search
runs at every `n_starts`, so a worse twin is not kept with
`n_starts = 1`, where no second start is compared. It changes the
statistic only when a twin ends lower. A twin that ends at an
inadmissible solution (a level-2 variance on its boundary) or with a
covariance matrix that is not positive definite, below the kept
discrepancy, makes the result unresolved, as it does with more starts.
When the better optimum has a level-2 variance on its boundary the
result is therefore unresolved or, with `n_starts = 1` in very small
samples (about 12 clusters), a non-global optimum, as before the
certificate. The row allows eight sign patterns; flipping pairs together
reaches the four of the kept fit's orbit. The other orbit does hold
local optima: a per-elimination oracle found local optima in both orbits
in 30 of 35 small cells (closest gap 0.02 LR). The kept orbit still won
every time that was tested (no win from the other orbit in 84 stress
cells, 114 QA cells with an all-orthant oracle and 715 constrained fits
from signed starts), so the coverage of the other orbit rests on the
free-fit-pattern and all-positive default starts: evidence, not a proof.
The pair flip is a symmetry of the constraint, not of the likelihood, so
the twins are separate local optima. Cost: a call takes about 3 to 4
times as long at `n_starts = 1`, about twice at the default and about
1.3 times at 30 starts; a bootstrap replicate costs about 2.5 times the
engine fits.

The guard admits the equality of any two a-then-b chains with the same
x, m and y at levels 1 and 2, so a serial `a*d` or `d*b` chain of the
same shape is admitted too; only the `a*b` indirect effect of a single
mediator has an oracle and a gate here.

The constrained fit is never trusted blindly: if it ends at an
inadmissible solution (a negative variance at either level, a covariance
matrix that is not positive definite, class
`medfit_warning_twolevel_inadmissible`), does not converge, or has a
lower discrepancy than the free fit, the result is **unresolved**
(`statistic` and `p.value` `NA`, `unresolved = TRUE`, the reason in
`note`) with a warning, never a likelihood-ratio number. If the fit
already carries a nonlinear constraint, or the four paths are not the
level-1 and level-2 regressions, the call is refused with class
`medfit_error_twolevel_unsupported`; a single-level fit is
`medfit_error_twolevel_required`.

## See also

[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md),
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
[`nie()`](https://data-wise.github.io/medfit/reference/nie.md)

## Examples

``` r
# \donttest{
set.seed(1)
id <- rep(1:40, each = 6)
x <- stats::rnorm(40)[id] + stats::rnorm(240)
m <- 0.5 * x + stats::rnorm(40)[id] + stats::rnorm(240)
y <- 0.4 * m + 0.2 * x + stats::rnorm(40)[id] + stats::rnorm(240)
d <- data.frame(cluster = id, X = x, M = m, Y = y)
fit <- fit_sem(
  "level: 1\n M ~ a_w*X\n Y ~ b_w*M + X\nlevel: 2\n M ~ a_b*X\n Y ~ b_b*M + X",
  data = d, cluster = "cluster"
)
twolevel_equal_indirect(fit)
#> 
#>  Likelihood-ratio test of equal indirect effects across the two levels
#> 
#> data:  a_w * b_w == a_b * b_b
#> LR = 0.30061, df = 1, p-value = 0.5835
#> 
#> 
#> Within vs between indirect effect: free fit 0.2095 vs 0.2978; clusters = 40
# }
```
