# medfit 0.16.0 — release notes draft

Local draft only. Publish only after the reviewed release commit passes its release gates.

## Bounded FIML for partially observed mediation data

Opt into `missing = "fiml"` through `fit_sem()` or the native `fit_mediation()` engine arguments. Listwise deletion remains the default; missing values never select FIML automatically.

This first implementation supports exactly three continuous observed variables in Gaussian random-X simple mediation, with independent disturbances, free intercepts, and a direct path that is free or fixed exactly at zero. It assumes ignorable missingness under that joint model; choosing FIML does not establish MAR or protect against MNAR. Explicit `fixed_x = FALSE`, a mean structure, observed/model standard errors, no weights, and the validated solver settings are required.

Partially observed rows contribute their observed components without imputation; only rows empty on all model variables are dropped. Supported output includes coefficient/covariance and likelihood/AIC/BIC summaries, unstandardized extracted effects, and normal intervals subject to the documented zero-gradient limitation. Model tests, bootstrap, profile likelihood, MBCO, robust/expected-information SEs and broader model structures remain unavailable for these FIML objects. Source-fit `glance()` retains likelihood/IC fields; extracted-object `glance()`, `quick()` and `pm()` refuse. See `?fit_sem` and the bounded FIML native guide for exact settings and extraction limits.

A new minibook Chapter 8 explains partial-row likelihood arithmetic, missingness patterns, assumptions, explicit fitting routes and an executed exercise. Public help and guides distinguish supported normal inference from deferred operations; the native-guide example now uses continuous Gaussian random-X data.

## Native constrained SEM corrections

- Observed-information covariance and observed sandwich bread account for active nonlinear-constraint curvature. Expected-information SEs preserve their Fisher-information definition. Effective variance floors are included in tangent-space covariance. Active-boundary covariance is a local approximation, not the full boundary sampling law.
- One supported nonzero-product equality fits both sign branches and selects the best accepted result only after required branches are resolved or excluded by explicit bounds. Other constraint configurations retain local search. Branch coverage is not a global-optimum certificate. Residual diagnostics use an existing matching reference covariance without automatic refits.
- Accepted likelihoods are retained only for the documented typed non-positive-definite-information/negative-variance covariance failures. Other covariance errors propagate; singular information continues to warn with unavailable covariance.
- Independent boundary, FIML and affine/near-singular regression oracles strengthen validation. Source archives retain the nonlinear gate required by tests; a monthly semopy oracle supplements existing checks. Numerical acceptance does not establish universal inferential coverage or global optimization.

## Compatibility and maintenance

- Remove the already-obsolete `options(medfit.native_defaults)` message/class. The option has had no effect since 0.15.0; pass `fixed_x` and `meanstructure` explicitly.
- Hosted coverage runs on main-targeting PRs and main pushes, including metadata-only release changes. Development validation is local; other fast hosted checks remain. Release platform/OpenBLAS gates remain required at the release stage.

This is a GitHub release preparation, not a CRAN submission.
