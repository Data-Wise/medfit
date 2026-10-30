# Revised bounded FIML integration-design review

> Current integration status (2026-10-30): production integration was subsequently
> authorized under the [bounded plan](../../PLAN-FIML-bounded-integration-2026-10-29.md).
> Local implementation and corrective independent QA/pre-docs gates pass at `0f40b73f`
> (numerical source `625e7280`). Documentation is verified locally after the
> explicitly authorized resume; corrective FINAL gates PASS on `32a7b98`
> (1,765 tests; built-package check OK; 96.20767% overall coverage). Earlier
> prospective wording below records its historical stage, not the current authority.
> FIML remains separate from 0.16; no push, release or expensive CI is authorized.
> See the [argument analysis](argument-design-analysis.md) for new/existing settings.

Date: 2026-10-29. Initial design: `9e6d95d9`; numerical prototype: `dee83cae`.
Reviewed scope: the accessor-contract revision and complete bounded design in
this documentation commit. Status: **static design PASS; no remaining actionable
findings identified within this scope**. Production implementation is still
unauthorized; FIML remains separate from 0.16.

## P2 resolution

The original design incorrectly listed `med()` as an indirect-effect accessor.
The [revised support matrix](integration-design.md#downstream-support-rules)
now uses the actual `paths`, `nie`, `nde`, `te`, `coef` and `vcov` APIs.
`med()` remains a data/formula-building convenience fitter and is deferred as
a FIML entry route. This resolves the P2 rather than adding another fitter.

The prospective acceptance criteria now require explicit calls after both
public fit routes, name/shape preservation, independent path/effect values and
full g'Vg checks for NIE/NDE/TE. They require the shared central gradient builder,
fixed-cp alias covariance, serialization/copy provenance, extracted summaries,
all tidy variants and normal confidence intervals. NIE origin behavior is
separated from known fixed cp = 0.

## Source checks and scope review

| Contract | Inspected owning source | Assessment |
| --- | --- | --- |
| Actual effect accessors | [generics-effects.R](../../../R/generics-effects.R), [methods-base.R](../../../R/methods-base.R) | NIE = ab, NDE = cp, TE = ab+cp; accessor names corrected |
| Uncertainty | [effect-se.R](../../../R/effect-se.R), [methods-tidy.R](../../../R/methods-tidy.R), [CI methods](../../../R/methods-base.R) | Central gradients remain authoritative; prospective independent gradient/covariance checks explicit |
| Deferred convenience routes | [med.R](../../../R/med.R), [methods-tidy.R](../../../R/methods-tidy.R) | med builds formulas; quick and extracted glance invoke pm; all explicitly deferred |
| Bootstrap advice and guard limits | [CI methods](../../../R/methods-base.R), [bootstrap.R](../../../R/bootstrap.R) | Require FIML-specific notices without unsupported bootstrap advice; opaque raw-data callbacks excluded from before-RNG guarantees |
| Opt-in/default preservation | [fit-sem.R](../../../R/fit-sem.R), [sem-fit.R](../../../R/sem-fit.R) | Appended option and mandatory explicit random X; no automatic NA routing or listwise fallback |
| Likelihood and ledger | [native methods](../../../R/methods-sem.R), [outcomes](../../../R/sem-outcomes.R) | FIML raw NLL and dedicated validation required; no invented complete-data discrepancy |
| Extracted provenance | [classes](../../../R/classes.R), [extraction](../../../R/extract-sem.R) | Dedicated subclass/context remains necessary; legacy results unchanged |

The first adopter is the internal native simple-mediation workflow, not an
unverified external commitment. The model boundary remains three continuous
observed variables with independent disturbances, random X and free/zero direct
path. The draft now states the ignorable-missingness qualification locally.
No inference-coverage, global-optimization or general-model guarantee is added.

SEMFit glance is explicitly distinct from extracted-object glance: the former
may report FIML likelihood/AIC/BIC with unavailable model tests; the latter is
deferred because its current implementation computes the deferred ratio pm.
This prevents accidental inheritance from contradicting the support whitelist.

## Verification and limitations

Reviewed the revised full design against the owning source contracts, including
the current inherited CI bootstrap recommendation and convenience-method call
chains. Markdown lint, local file/heading-link validation, recursive artifact
hashes, scoped secret-pattern scanning and diff whitespace checks pass.
Only study documentation, its manifest and status were changed.

No numerical script, acceptance fixture, production source, public API or package
test changed. No new numerical run, expensive CI, push or release was performed.
The 42-fit/13-edge/126-point and 61-assertion results remain the previously
verified prototype evidence. Future API acceptance tests described in the design
have **not** been implemented or executed.

## Readiness

Ready for a separate implementation/API-change authorization after user review
of the [revised contract](integration-design.md). That decision must activate an
implementation plan and the required independent QA/local gates. This static
PASS is not production readiness, permission to implement, or inclusion in 0.16.
