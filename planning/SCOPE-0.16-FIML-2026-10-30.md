# 0.16 release scope: include bounded FIML

Status: scope decision recorded locally on 2026-10-30; release preparation pending.
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
The coverage-scope maintenance PR #365 is a separate pending change.

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
- Update current release wording in README, NEWS, roxygen/Rd and the website
  articles from "separate/not assigned to 0.16" to "planned for unreleased
  0.16". Check the study index, design and completed implementation summaries;
  preserve dated historical evidence while marking the old exclusion superseded.
  Search the minibook and all help/site sources for conflicting scope claims.
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

Finish fast CI and review for coverage PR #365; merging it needs separate
permission. Then synchronize the release wording listed above in a bounded docs
change before preparing a 0.16 release candidate. The present scope decision is
local and unpushed; publication requires per-instance authorization.
