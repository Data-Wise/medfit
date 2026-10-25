---
name: medfit-risk-tier
description: How to make a medfit branch mergeable - decide the risk tier from the diff, write the seven-item admission checklist, run the suite and lint with counts, and triage CI failures (lint, risk-tier, R-CMD-check, gates, pkgdown). Use before opening a medfit PR and whenever a medfit PR check fails - "CI failed", "lint failed", "risk-tier", "gates timed out", "prepare the PR".
---

# medfit risk tier and CI

## 1. Risk tier
`git diff --name-only origin/dev...HEAD` against `tests/sim/risk-files.txt`. Any hit makes the PR high-risk: the
`risk-tier` workflow (`tests/sim/risk-tier.R`, rules in `tests/sim/risk-lib.R`) requires one body line per item,
ticked `- [x] N. ...` or `- [ ] N. n/a: <reason>`:

1. independent oracle
2. reliability cell
3. planted defect
4. metamorphic invariance
5. fault injection
6. registration (`tests/sim/gates.csv` row with `oracle` and `mutants`; `tests/sim/structures.csv`)
7. platform run (the OpenBLAS gates runner)

An `n/a` needs a real reason (for example, "the gates run on the release PR to `main`; dev is gated locally"). A new
structure needs at least items 1, 2 and 3 for real (`test-gate-coverage.R` enforces registration).

## 2. Evidence
- Full suite with counts:
  `NOT_CRAN=true Rscript -e 'r <- as.data.frame(devtools::test(reporter="silent", stop_on_failure=FALSE)); cat(nrow(r), sum(r$nb), sum(r$failed), sum(r$error), sum(r$skipped))'`
- Local gate for `dev` work: `scripts/check-local.sh`.
- A failure blocks only if it fails on the branch and passes on `dev`. Reproduce on `dev` first. A failure that
  also fails on `dev` is not hidden: name it in the PR body as a pre-existing failure with the `dev` reproduction, and
  do not call the PR mergeable until the author accepts that waiver or `dev` is green again.

## 3. Lint
CI runs `lintr::lint_package()` and fails on new findings; the live one is the 120-column `line_length_linter`.
Wrap at argument boundaries, aligned under the call's opening parenthesis, or assign to a local variable. A
multi-line function body needs braces (`brace_linter`).

## 4. CI triage
Read before fixing: `gh pr checks <n> --repo Data-Wise/medfit`, then `gh run view <run-id> --log-failed`.

| Check | Usual cause | Fix |
|---|---|---|
| lint | long lines, missing braces | wrap; never reformat untouched code |
| risk-tier | checklist line missing or malformed | edit the PR body (`gh pr edit --body-file`) |
| gates (rest/reliability) | only on PRs to `main`; runner pinned to ubuntu-24.04 (#312) | read the gate CSV; never re-run speculatively |
| pkgdown | an article chunk errors | fix the chunk; never `eval: false` |
| R-CMD-check | runs on `main` only | reproduce with `devtools::check()` |

## 5. PR body
Summary of the change, the evidence block (command and counts, planted defects), the checklist when high-risk, and
the generated-with footer from the session. PRs go to `dev`; merging is the author's decision.
