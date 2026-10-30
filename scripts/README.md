# Website checks

After a local pkgdown build, run `Rscript scripts/fix-pkgdown-404.R docs`.
The Pages workflow runs this automatically before deployment. It removes the
invalid `/NA` source attribute that pkgdown 2.2.1 adds to inline MathJax
configuration on the 404 page; other script URLs are preserved.

Run `Rscript scripts/test-fix-pkgdown-404.R` to check the repair independently.
The repair is idempotent and does nothing when pkgdown produces a correct page.

## Coverage scope

The coverage workflow starts on pushes to `dev`/`main` and PR updates targeting
`dev`. A lightweight job skips R coverage only when **every changed path** is
`.STATUS`, `CLAUDE.md`, `AGENTS.md`, or a Markdown file under `planning/`.
Code, tests, dependencies, workflow changes, executable documentation, and unknown
paths still run coverage. Planning scripts and data are not exempt. Pushes to
`main` always run coverage, including release/version and metadata-only changes.
The release R-CMD-check and OpenBLAS workflows are unchanged.

The scope check compares the full push range or the entire PR against its merge
base. Deletions and both sides of renames count. Missing history, malformed event
input, an empty diff, or a failed scope job conservatively runs coverage. A
metadata-only run reports a skipped coverage job; it does not upload a new
Codecov report. Superseded PR runs remain cancellable.

Run the scope regressions locally:

```sh
python3 -m unittest discover -s .github/scripts -p test_coverage_scope.py
```

The checkout's `test-ci-workflows.R` suite also runs these regressions and checks
the workflow wiring. No hosted CI or R dependency installation is needed for the
scope tests. Expensive CI remains reserved for release to `main`.
