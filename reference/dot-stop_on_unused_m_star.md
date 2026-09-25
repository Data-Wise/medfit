# Error when `m_star` was supplied but no four-way decomposition is run

`m_star` only enters the four-way decomposition, which needs a single
mediator and a treatment-by-mediator product. A value supplied for any
other fit would be dropped silently, so refuse it. The check keys on
whether the argument was given at the call site, as in
[`fit_mediation()`](https://data-wise.github.io/medfit/reference/fit_mediation.md).

## Usage

``` r
.stop_on_unused_m_star(treatment, mediator)
```

## Arguments

- treatment, mediator:

  Variable names, used in the suggested formula.
