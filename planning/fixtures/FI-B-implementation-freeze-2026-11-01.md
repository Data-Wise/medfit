# FI-B deterministic implementation fixture freeze

Frozen before the first test run, 2026-11-01. Statistical admission remains deferred.
The active execution plan links this manifest. No timing pilot or coverage study is included.

`fb_fixture(kind, direct)` in `tests/testthat/helper-fiml-bootstrap.R` generates 300
Gaussian records with seed 271, X mean .8 / SD 1.1, M intercept -.4 / a .5 /
residual SD .8, Y intercept .7 / b .6 / direct .25 (free) or 0 / residual SD .9.
Six source cells cross complete, MCAR, and observed-X MAR with free/zero direct paths.
Complete and MAR collect/retain 300 records. MAR uses the subsequent uniform draws
and probabilities plogis(-1.3 + .7 X), plogis(-1.1 - .6 X) for M/Y deletion.
MCAR independently samples the seven nonempty masks uniformly at seed 613 and
appends three all-empty records independent of record values: collected 303,
retained 300. Resampling uses seed 911 and exactly twelve draws per QA cell.
Parameter draws use seed 123 and a deterministic supplied-normal matrix in unit tests.

Implementation focused work per successful test-file execution: two source fits
(MAR free, MCAR zero), two actual row refits (MAR free, B=2), zero lavaan fits.
Injected failure/refit tests use mock refits, not optimizers. Gaussian tests use
B=8, plus supplied normals; no optimizer is used for draws. Invalid-input, covariance,
legacy, and accessor tests require zero extra fits. Maximum authorized implementation
attempts: one red run and up to two green/correction runs (at most 12 native source/refit
invocations total); focused legacy files may be run once after green and do not fit SEMs.
Independent QA owns the separately bounded six-cell/12-resample matrix (156 invocations).

Planned verification commands, all through the budget-recording runner:

- `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-bootstrap-fiml.R")'`
- `Rscript -e 'devtools::load_all(quiet=TRUE); testthat::test_file("tests/testthat/test-bootstrap.R")'`
- `Rscript -e 'devtools::load_all(quiet=TRUE); lintr::lint("R/bootstrap-fiml.R")'`

After the first green run, one additional focused run is declared to test mixed
success/failure output, stale stored bounds, and untruncated negative nuisance draws.
It reuses the two source fixtures and two real row refits (four native invocations),
bringing the cumulative implementation total to at most eleven native invocations
(one red source, two sources in the constructor correction, and two four-fit runs),
still below the original twelve-invocation ceiling. No extra matrix work is added.
The full required suite and independent oracle comparisons belong to later stages.
