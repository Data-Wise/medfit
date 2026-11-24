# Contributing to medfit

medfit is the foundation package of the mediationverse: it provides S7 classes, extraction, fitting and
bootstrap infrastructure, and leaves effect-size methods to the packages built on it. Read
[the architecture guide](https://data-wise.github.io/medfit/articles/guide-architecture.html) for how the pieces fit together.

## Branches

| Branch | Role |
|---|---|
| `main` | released code; changed by pull request only |
| `dev` | integration branch; start work from here |
| `feature/*` | one change each, opened as a pull request to `dev` |

Use conventional commit messages (`feat:`, `fix:`, `docs:`, `test:`, `chore:`). Squash-merge feature
pull requests into `dev`; release pull requests from `dev` to `main` use a merge commit.

## Check your change locally first

Use the local gates for `dev`. The hosted `R-CMD-check` matrix runs automatically on pull requests
to `main` and pushes to `main`, including merges.

```bash
scripts/check-local.sh            # quick tests, then R CMD check on a built tarball
scripts/check-local.sh --tests-only
scripts/check-local.sh --full-tests
```

In R:

```r
devtools::document()   # after changing roxygen comments
devtools::test()
lintr::lint_package()
```

Use `--full-tests` on the final candidate to include tests that require `NOT_CRAN=true`.
Record the test counts and link to the run log in the pull request.
See [local verification](https://github.com/Data-Wise/medfit/blob/dev/scripts/README.md#local-verification) for the run modes and receipt guidance.
Verify a numeric claim against an independent oracle (lavaan, a hand calculation, a fit without
the feature) and plant a defect the test must catch.

## What the hosted checks do

| Check | Runs on | Notes |
|---|---|---|
| `lint` | pull requests | pinned to `ubuntu-24.04`; timeout 35 minutes (a cold package cache compiles OpenMx from source) |
| `pkgdown` | pull requests | pinned to `ubuntu-24.04`; articles evaluate their code, so an article that breaks fails here; not run for changes only under `planning/`, `tests/` or `.claude/` |
| `risk-tier` | pull requests to `dev` and `main` | a change to the objective, parameters, constraints, bounds or solver path needs the admission checklist in the pull request body |
| `R-CMD-check`, `test-coverage` | pull requests to `main` and pushes to `main` | platform matrix and hosted coverage. The matrix also supports manual dispatch. |
| `gates` | pull requests to `main` and manual dispatch | two simulation shards, `gates (rest)` and `gates (reliability)` |
| `qc-monthly` | `dev` pull requests labeled `run-qc`, schedule and manual dispatch | runs the simulation gates on the selected ref |

Pinning to `ubuntu-24.04` fixed a stall where `setup-r` hung at `apt-get update` on a newer image. If a
hosted job stalls in its setup step, rerun it once; a second failure is a real problem.

## Documentation

Articles in `vignettes/articles/` are Quarto files that evaluate their code at site build; chunk options
use the hash-pipe form (`#| label: my-chunk`, lowercase `true`/`false`). Every `guide-*.qmd` must be in the
articles index and the Guides menu of `_pkgdown.yml`; `tests/testthat/test-guide-pages.R` checks this.
Every classed condition the package signals (`medfit_error_*`, `medfit_warning_*`) must be named in the
docs; `tests/testthat/test-condition-docs.R` checks this, so add a row to the
[Troubleshooting guide](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html) with a new condition.

Update `NEWS.md` under the development heading for any user-visible change. Spelling is US English.

## Breaking changes

Open an issue with the `[BREAKING]` prefix, keep a deprecation period of at least two months with
`lifecycle::deprecate_warn()`, and document the migration path. A correctness fix that replaces a wrong
result with the right one skips the deprecation period but needs a NEWS behavior-change note.
