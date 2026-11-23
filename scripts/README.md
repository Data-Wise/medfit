# Website checks

After a local pkgdown build, run `Rscript scripts/fix-pkgdown-404.R docs`.
The Pages workflow runs this automatically before deployment. It removes the
invalid `/NA` source attribute that pkgdown 2.2.1 adds to inline MathJax
configuration on the 404 page; other script URLs are preserved.

Run `Rscript scripts/test-fix-pkgdown-404.R` to check the repair independently.
The repair is idempotent and does nothing when pkgdown produces a correct page.

## Local verification

| Command | Purpose |
| --- | --- |
| `scripts/check-local.sh --full-tests` | Source-mode testthat suite with `NOT_CRAN=true`. Record the counts for the final candidate. |
| `scripts/check-local.sh --tests-only` | Source-mode quick suite with `NOT_CRAN=false` and force-Suggests disabled. |
| `scripts/check-local.sh` | The quick suite, then a package build and check with vignettes and the repeated test pass disabled. |
| Separate strict installed-package check | Build the tarball and check with `--as-cran --run-donttest` and the required strict flavor settings. Record which checks ran, including vignettes and optional dependencies. |

The runner prints a different log path for each invocation. Follow that path
with `tail -f` to see progress by file and phase. Use `--full-tests` once on the
final source tree for the full suite. Link to that same successful log from the
gate and PR reports. Serial runs report per-file wall time and R-process CPU
time. If testthat
parallel mode is requested, the reporter labels replayed events separately
and records counts and the whole test phase duration.

Run `sh scripts/test-check-local.sh` to exercise the runner against a small
fixture package, including failing and interrupted runs.

A receipt is reusable only for the same verified tree, run mode and environment.
Check for `source_eligible=yes` and `run finish ... status=passed exit=0`.
The source marker checks that the checkout started and ended clean at the
same commit and tree. Also verify the command, R and dependency versions,
library paths, relevant environment options and test counts. Keep the checkout
and its inputs stable throughout the run. Changes to ignored inputs, fixtures,
helpers, test settings, dependencies or toolchain require a new receipt for
affected checks. A missing exit or an interrupted check is incomplete. A
quick-test or strict-check result serves its own gate.

The full suite runs the semopy fixture through `uv` when available. If the
default uv cache is outside the writable area, set `UV_CACHE_DIR` to a
writable directory before running the suite.

## Coverage scope

Hosted coverage runs on pulls targeting `main` and pushes to `main`, including
metadata-only changes. Regular `dev` PRs use local test evidence, lint and
risk-tier, plus pkgdown when applicable. Superseded coverage runs on a PR
remain cancellable.

Run the scope regressions locally:

```sh
python3 -m unittest discover -s .github/scripts -p test_coverage_scope.py
```

The checkout's `test-ci-workflows.R` suite also runs these regressions and checks
the workflow wiring. No hosted CI or R dependency installation is needed for the
scope tests. Expensive CI remains reserved for release to `main`.
