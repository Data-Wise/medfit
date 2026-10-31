# 0.16 release scope: include bounded FIML

Status: scope/docs merged into dev through PR #366 (`c4b76fb5`) on 2026-10-30
after all six fast checks passed on the exact reviewed head. Post-merge dev
coverage and Codecov patch passed on the merge commit (run `41106465575`),
verified live at 2026-10-30 18:42 UTC. Release preparation remains. The proposed follow-up order
and cross-package boundaries are in
[the reconciled readiness plan](PLAN-FIML-release-and-missing-data-followups-2026-10-30.md).
The user accepted the next step after the recommendation to include bounded FIML
in 0.16. This supersedes earlier FIML exclusions from 0.16 in historical study,
implementation and merge records. It does not authorize a release, dev-to-main
merge, external submission or expensive CI now.

## Included

The completed bounded FIML integration from PR #364 (`a894e45e`) joins the
existing 0.16 development changes. Inclusion changes the release assignment;
it adds no new model, inference or optimizer guarantee.

- Exact `missing = "fiml"` opt-in through `fit_sem()` or native
  `fit_mediation()` engine arguments; listwise defaults stay unchanged.
- Three continuous observed variables, Gaussian random-X mediation, a free or
  exactly zero direct path, free means and independent positive disturbances.
- Explicit `fixed_x = FALSE`, mean structure, observed/model SEs, no weights,
  and the validated solver/start settings.
- Partial-row retention and documented row/pattern provenance; supported raw
  likelihood/AIC/BIC, unstandardized effects, covariance and normal intervals.
- Existing explicit refusals for unsupported operations remain part of the API.

Existing dev work includes D4 constrained covariance, sign-branch fitting and
boundary-oracle regressions. Reconcile the final dev diff and NEWS before release;
this scope note is not a claim that every dev change is automatically approved.
The coverage-scope maintenance PR #365 merged separately as `2c4bd65c`.

## Deferred

Broader SEM/FIML models, fixed-X FIML, weights, expected/sandwich SEs,
bootstrap/boot intervals, profile likelihood, MBCO, broader convenience APIs and
external-package adoption remain separate milestones. Local numerical acceptance
is not a global optimizer or inferential coverage guarantee.

## Completed evidence

The bounded implementation, independent likelihood/lavaan/covariance QA,
regression repairs and local final package gates passed before PR #364 merged.
The reviewed and merged trees were identical. Post-merge dev coverage run
41093099169 passed: 8,626 assertions, zero failures, three known warnings,
138 skips; hosted Codecov completed at 96.62% overall and 98.48% patch coverage.
The original plan retains source identities, limits and archived evidence.
This scope decision does not claim fresh numerical verification.

## Remaining acceptance before a separately authorized release

- Reconcile the full 0.16 change list and open issues against dev and NEWS.
- Preserve the explicit model/support limits, opt-in defaults and refusal rules
  in examples and release notes; render and inspect affected website/book pages.
- Make the version/date and associated references consistent only during
  authorized release preparation; this note does not bump DESCRIPTION.
- Complete release-local checks, independent numerical checks where applicable,
  and fresh release comments/reverse-dependency/URL/spelling checks if CRAN work
  is authorized. Maintainer/manual submission and existing submission holds remain.
- At release to main, require the full platform/R-CMD-check and OpenBLAS gates,
  coverage/Codecov and other required checks on the actual release candidate.
  Expensive CI stays deferred until that release stage is authorized.
- Review the live release PR and checks before any merge; verify main CI before
  tagging/publishing. No release merge, tag, deployment or submission is authorized
  by this scope decision.

## Immediate next step

PRs #365/#366 and the regression-oracle/minibook clarification PR #367 are merged
with author authorization. Post-#367 dev coverage and Codecov patch passed
(run `41147354533` at `fb879fac`; 8,789 passes, zero failures, five expected
warnings and 140 skips). Local merged branch/worktree cleanup is complete.
Review A2's proposed full teaching unit and remaining readiness
work in the reconciled plan; new diagnostics and missingmed adoption remain
separate milestones. Release preparation/execution needs its own authorization;
expensive CI remains deferred until release to main.

## Release-wording synchronization — 2026-10-30

README, NEWS, fit_sem roxygen/generated Rd and the models/native-guide/0.15
article now say "planned for unreleased 0.16" while retaining the released-0.15.0
absence and every support limit. The minibook preface distinguishes the bounded
FIML addition from the chapters' complete-data derivations. Current study/plan
headers supersede historical exclusions without rewriting dated evidence.

Focused documentation and FIML suites pass across seven files. R expressions in
fit-sem.R are identical before/after; loaded-package lint and whitespace checks
pass. The isolated current installation also passes lint. An initial standalone
lint/render used the older shared installation and produced context/dispatch
errors; using the isolated current package resolved them. No runtime statement
changed. Rd was generated with installed
roxygen 8.1.1 without changing the project's version pin.

Local HTML inspection covers homepage, NEWS, fit_sem help, three affected
articles and the minibook preface. Initial builds hit unwritable macOS caches;
the retry uses a session R cache and normal access to Quarto's cache. The first
article helper call used bare names; correct pkgdown IDs are articles/models,
articles/native-guide and articles/native-defaults-0-15. The first evaluated
article render loaded an older shared medfit; final article renders use an
isolated temporary library installed from this checkout. Logs remain under
/private/tmp/medfit-016-*. No website deployment, version bump or release occurred.

## Authorized dev integration — 2026-10-30

The author authorized merging PRs #365 and #366 when ready. Coverage-scope
PR #365 merged as `2c4bd65c` after all six reported checks passed. Its planning
reconciliation is retained here, with the earlier 0.16 exclusion superseded
by this scope decision. PR #366 subsequently merged as `c4b76fb5` after all six
fast checks passed at `02f908e3`; reviewed/merged trees matched. Local dev and
merged branch/worktree cleanup are complete, with 140 evidence files archived
and verified. Post-merge dev coverage
[run 41106465575](https://github.com/Data-Wise/medfit/actions/runs/41106465575)
completed successfully on `c4b76fb59b1d6248897a706bfd7e065533ba1739`: 8,626
passes, zero failures, three warnings and 140 skips. The reported
[Codecov patch status](https://app.codecov.io/gh/Data-Wise/medfit/commit/c4b76fb59b1d6248897a706bfd7e065533ba1739)
also passed; both results were verified live at 2026-10-30 18:42 UTC. Remote
feature branches remain retained. Metadata reconciliation is local only; no
separate push, release, dev-to-main merge or expensive CI is authorized.
