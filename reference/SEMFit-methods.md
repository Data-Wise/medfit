# Methods for SEMFit objects

**\[experimental\]**

Accessors and display for a
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
returned by
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md).

## Arguments

- object, x:

  A [SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
  object

- ...:

  Additional arguments (ignored)

## Value

[`coef()`](https://rdrr.io/r/stats/coef.html) a named numeric vector;
[`vcov()`](https://rdrr.io/r/stats/vcov.html) a matrix;
[`nobs()`](https://rdrr.io/r/stats/nobs.html) an integer;
[`logLik()`](https://rdrr.io/r/stats/logLik.html) an object of class
`"logLik"`; [`summary()`](https://rdrr.io/r/base/summary.html) an object
of class `"summary.SEMFit"`;
[`print()`](https://rdrr.io/r/base/print.html) invisibly returns its
argument.

## Details

- [`coef()`](https://rdrr.io/r/stats/coef.html) returns the
  free-parameter estimates, named as in the parameter table (the label
  when the row has one).

- [`vcov()`](https://rdrr.io/r/stats/vcov.html) returns their
  covariance, projected onto the active constraints and bounds; rows for
  a pinned parameter are zero.

- [`nobs()`](https://rdrr.io/r/stats/nobs.html) returns the number of
  rows used after listwise deletion.

- [`logLik()`](https://rdrr.io/r/stats/logLik.html) returns the log
  likelihood with the means free; its `df` attribute counts the free
  parameters plus one mean per observed variable.

- [`summary()`](https://rdrr.io/r/base/summary.html) collects the
  estimates, standard errors and z statistics, the defined parameters,
  and the diagnostics: rows dropped, information type, degrees of
  freedom, retries, stationarity, active bounds and constraints,
  improper-solution flags and the multiplier sign check.

## See also

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md),
[SEMFit](https://data-wise.github.io/medfit/reference/SEMFit.md)
