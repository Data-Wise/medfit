# Bounded FIML minibook unit

Status: T1-T3 documentation, independent content review, full HTML render and
USER-verified visual acceptance PASS; T4 final local gates pending. Authorized 2026-10-30. Base: dev `bc6fbf60`.
Branch: `codex/fiml-minibook-unit`. Docs only; no production edits, push, PR,
release, dev-to-main merge or expensive CI.

## Task and acceptance

- [x] T1: Draft one self-contained worked unit and register it in book navigation.
  Teach a partial-row numerical Gaussian likelihood, observed patterns/overlap,
  fitting/extraction, ignorable-missingness assumptions, supported/refused inference,
  and one attempt-first exercise with an executed checked answer. Preserve all seven
  complete-data chapters. Link from the preface; no support/API changes.
- [x] T2: Review numerical examples and every support claim against current source,
  canonical Methods and Formulas, and existing regression evidence. Correct any
  mathematical/support errors before rendering. Distinguish teaching examples from
  production implementation and independent review from self-review.
- [x] T3: Install this checkout in an isolated library; record package/source identity.
  Execute examples; render the entire HTML book successfully and inspect actual output,
  including math, tables, code/results, exercise/solution and surrounding text. An
  exit-1 render is not a pass. Track new files before building. Use Quarto's normal
  cache with authorized access; do not repeat ineffective cache overrides.
- [ ] T4: Run docs consistency, package/book spelling, relevant FIML checks and final
  local gates (including the orchestrator-required full suite and lint), save exact
  counts/exit codes. No expensive hosted/platform/OpenBLAS CI. Reconcile status and
  commit locally; no publication. Each failed stage has at most one corrective retry,
  then stops for authorization under the orchestrator.

## Writing scope

Book register: tutorial (inferred from existing worked chapters, not configured in
Tome). Voice register: applied/methods. House style: plain US English, concrete
numbers before generalization, a short prerequisites/payoff card, one salience
statement, attempt-first prompts and checked solutions; retain rigorous assumptions.
Use existing chapter style without adding an unrelated scaffold configuration.

Tome native draft preflight is blocked: this checkout has no configured Tome book
research file/outline, and the default Python lacks PyYAML. Apply the inspected Tome
teaching/evidence guidance through the medfit docs pipeline; do not claim a native
Tome stage run or invent external citation support. Read actual local sources.
Canonical general formulas remain in `vignettes/articles/methods.qmd`; link there,
and use explicitly worked numerical calculations in the unit. No new research claim.

## Pipeline and evidence

Docs-only: medfit-docs -> independent bounded content review -> final medfit-gates.
Reports: `_agents_workspace/fiml-minibook-unit/{docs,review,gates}.md`.
Each report ends with exactly one `Verdict: PASS` or `Verdict: FAIL`.
Source/runtime evidence and render receipt stay in that ignored workspace. The
new unit, navigation/preface link, NEWS and this plan/status are scoped deliverables.

## Docs stage receipt — 2026-10-30

New Chapter 8, navigation, preface link and NEWS drafted without changing the
seven complete-data chapters. Independent review caught a binary-X fitting fixture;
the new chapter now generates continuous Gaussian random-X data with independent
Gaussian disturbances and preserved RNG state. Changed-area independent re-review
passes. Expected retained N is 399 of 401 supplied rows; one mask intersection and
the appended row are all-empty. Both supported entry points agree; independent
row-wise likelihood agrees with the fit to 4.55e-13.

All chapter chunks execute with checked arithmetic/refusal/exercise and exact RNG
preservation. Focused docs checks: 89 tests, 897 passed assertions, zero failures,
errors or warnings, one help-availability skip. Package and direct QMD spelling
pass after one corrective spelling retry. Full final HTML book render exits0:
preface plus eight chapters, nine pages. Static output/numerical/link checks pass.
User explicitly visually accepted final Chapter 8 at 18:31 MDT; this is USER-verified,
not agent visual inspection (browser file policy blocked the latter). Source and
output hashes, commands, initial findings and final reports remain in
`_agents_workspace/fiml-minibook-unit/`. Final local gates are still required.
