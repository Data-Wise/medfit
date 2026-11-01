# Stage-0 FIML inference: release guard design

**Status: proposed for review; no code changes or release authorized.** The
next-release goal remains expanded FIML fitting for covariates, parallel and
serial models, subject to each variant's existing numerical and statistical
admission. This design addresses only the already-merged simple-model
source-fit intervals if their stage-0 admission remains pending, inconclusive
or failed. It does not run, change or waive an admission gate, timing pilot or
study and does not authorize activating expanded models.

## Current evidence and recommendation

At `0bd99134`, public `bootstrap_mediation()` dispatches a non-null named
`source_fit` to `.bootstrap_fiml()`; the latter validates the source, its ledger,
method, effect and simple topology, but neither dispatch nor those checks
consults statistical admission. This is static source inspection, not a runtime
receipt. Existing released bounded simple-model fitting and complete-data
bootstrap are separate capabilities and must remain available.

Recommend a small **release-bound, fail-closed guard** on the public
source-fit dispatch while stage 0 is unadmitted. It rejects both `parametric`
and `nonparametric` source-fit requests with a clear message that these intervals
are unavailable in that release. Place the check before the `.bootstrap_fiml()`
call and before package-initiated random draws, refits or workers. It applies to every non-null
`source_fit` and is not bypassed by an option, environment variable, runtime
flag or alternate public route. Do not claim that a source-validation ledger is
an admission decision. Existing calls without `source_fit`, including their
positional/callback contracts, and existing fitting/extraction remain unchanged.

## Integration and study-source provenance

The proposed default follows the established feature -> `dev` -> `main` PR
route, subject to separate approval and live release checks: prepare the guard
and release-facing docs/tests on a feature branch, review and integrate to
`dev`, then carry that exact guarded `dev` tree through the dev-to-main release
PR. Pin the feature PR head, dev candidate commit, release PR head and final
tree; independently verify guard presence and behavior at the actual candidate.
The public `source_fit` route on `dev` is guarded too after integration and
while admission remains deferred. This does not authorize a push, merge or release.

For a later study, first draft the intended stage, named model variant and
design. After any separately required authorization to prepare an isolated
**study source**, pin the candidate, study source and environment before
finalizing preregistration or obtaining outcomes. If an unguarded ancestor contains the exact inference/model
implementation to be studied, pin its immutable commit and prove parity with
the candidate. Otherwise derive a private study-only source from the exact
guarded candidate with a minimal, explicitly reviewed patch:

- For **stage 0**, remove only the stage-0 source-fit exposure guard needed to
  exercise its simple model, plus strictly necessary study-harness changes.
  Leave expanded-variant exposure guards intact.
- For a **named expanded variant**, after stage-0 admission and separate
  authorization to prepare that study source, remove only the exposure guards that prevent fitting,
  extraction or inference for that specific variant, plus any still-applicable
  stage-0 exposure guard and strictly necessary study-harness changes. Keep all
  other variant exposure guards and numerical validation/failure safeguards.
  An unimplemented variant cannot be studied by removing a guard; stop until
  its candidate implementation and required numerical evidence exist.

These patches must never enter `dev`, `main`, a release-bound branch, or a
published package. Preserve exact patch, hashes, tree and dependency
fingerprints. Independent QA compares study and candidate trees, accounts for
every difference, verifies relevant fitting, inference, failure and numerical
behavior is identical apart from the reviewed exposure restrictions and harness,
and verifies out-of-scope variants still refuse. If parity cannot be shown,
stop and assess a revised source before outcomes; do not infer admission for the
candidate. Freeze the final preregistration with the verified source and
environment fingerprints, design, and seed allocation; independent review and
maintainer approval precede separate authorization for confirmatory execution.
If a timing pilot is later considered, first freeze its cell/regime list and
pin and compare its source and environment; it requires its own authorization,
uses disjoint seeds, and informs feasibility only. Complete the confirmatory
preregistration after any pilot and before confirmatory execution authorization.
Isolated study sources are not public runtime bypasses. This plan
does not authorize creating, executing or publishing them. If stage 0 is later
admitted, remove its guard through a reviewed feature -> dev -> main path, with
admission/source evidence and branch reconciliation recorded.

If the exact release tree
cannot carry and verify this guard, exclude/revert the activation from that tree
and independently verify the full resulting diff. Do not revert PR #379 wholesale
without inspecting its mixed source, documentation, status and evidence files.
The maintainer must choose the actual release treatment. A release-bound guard
must be reconciled with the development branch explicitly, with provenance and
conflicts resolved; branch placement alone does not prove a release is guarded.

## Evaluation and error precedence

R evaluates the caller's `source_fit` expression to decide whether it is null;
that expression can itself use RNG, start work or fail. The guard cannot prevent
or promise to reverse caller-side effects. For an already evaluated non-null
source, preserve the existing `statistic_fn` conflict error first; otherwise
return the unavailable-in-this-release error before package-initiated source
validation, RNG, refits or worker creation. Thus an invalid non-null source plus
`statistic_fn` gets the existing conflict error; an invalid non-null source
without that conflict gets the release-guard error. A source expression that
throws propagates its own error. A null source continues through existing legacy
validation and dispatch. No promise is made about the contents or side effects
of arbitrary caller expressions. Exact message text is to be reviewed with docs.

## Conditional release checklist

Before a release candidate is prepared, inspect the exact proposed tree and
record the maintainer's stage-0 admission and release-scope decision:

- **Pending, inconclusive or failed:** guard or exclude both source-fit
  interval methods. Independent QA tests refusal through both method settings,
  named arguments and public dispatch/accessor paths; with already evaluated
  source objects check no package-initiated RNG advancement, worker start or
  refit occurs, and test the stated error precedence. Check supported fitting, extraction,
  and legacy bootstrap calls still work. Verify unavailable topology guards.
- **Admitted and explicitly included:** remove or omit the stage-0 release guard
  in the exact candidate, after admission evidence is tied to the relevant source
  and any later change is assessed. Independently verify both methods and
  supported effects/direct-path policies against the approved contract; do not
  require them to refuse. Scope each expanded variant separately: stage-0
  admission alone does not activate or admit the 11 future variants.
- **Evidence or branch state unclear:** keep the candidate blocked; neither a
  successful numerical fixture nor a plan status substitutes for admission or
  for an exact-candidate check.

For either branch, reconcile `bootstrap_mediation()` help/Rd, README, NEWS,
vignettes, guides and user-facing messages (including guidance that currently
directs users to `source_fit`) with actual release behavior; check rendered
outputs as required. Review tests, signatures and examples for stale claims.
Retain the Q10–Q13 stage ordering and the maintainer's separate release decision.

## Future implementation and verification owners

- **`medfit-implementer`:** after separate authorization, implement the selected
  release-bound treatment in the appropriate worktree and update docs/tests.
- **`medfit-oracle-qa`:** independently challenge each public path, method,
  source type, supported fitting and legacy callback path, including a planted
  bypass where feasible. Verify the scoped package-initiated work and error
  precedence when withheld; do not attribute caller-expression effects to medfit.
- **`medfit-docs` / `medfit-gates`:** reconcile visible guidance and run the
  applicable required tests, numerical checks, lint and release checks on the
  exact candidate, with recorded warnings, skips and provenance.
- **Maintainer:** approve scope and treatment; if checks fail or admission is
  unresolved without a verified exclusion, do not prepare/release the candidate.

This is a design for review. No runtime guard or test has been implemented or
executed by writing it; no pilot, admission gate or statistical study is run.
