# FIML and missing-data argument analysis

Date: 2026-10-29. Scope: the local bounded integration at `625e7280`, not a
released API or a 0.16 commitment. This note explains choices; it adds no new
implementation requirements beyond the [active plan](../../PLAN-FIML-bounded-integration-2026-10-29.md).

## Recommendation

Keep one explicit `missing` selector on `fit_sem()`, defaulting to listwise, and
forward it through native `fit_mediation()` engine_args. Keep statistical model
choices separate from missing-row handling. Do not infer a new estimator merely
because data contain NA, silently change fixed_x, or fall back after failure.

FIML evaluates each row's observed components; it does not impute values. The
bounded implementation assumes a Gaussian joint random-X model and ignorable
missingness (such as MAR with the usual ignorability conditions). Choosing an
argument does not establish those assumptions or repair nonignorable missingness.

## New and existing arguments

| Argument | Listwise/default behavior | Bounded explicit FIML | Reason and cost |
| --- | --- | --- | --- |
| New `missing` | Omission selects `listwise` | Exact scalar `fiml`; explicit complete-data FIML keeps the same limits | Transparent opt-in; appending the formal preserves old positional calls; no abbreviations or overlapping booleans |
| Existing `fixed_x` | Existing TRUE/default/subset resolution remains | Caller must explicitly supply FALSE | Joint modeling of X differs from conditioning on it; a silent override would change the statistical model |
| Existing `meanstructure` | Existing TRUE/default and NULL/FALSE behavior remains | TRUE required | Matches the validated free-intercept model; zero-mean/covariance-only FIML is not mathematically impossible, but is not validated here |
| Existing `information` | Existing choices remain | Observed only | Expected-information support needs its own missing-pattern derivation and checks |
| Existing `se_type` | Existing choices remain | Model only | Robust/sandwich inference requires independent validation; correct likelihood alone is insufficient |
| Existing `weights` / deprecated alias | Existing behavior remains | Non-NULL weights rejected, even unit weights | Weight interpretation, objective normalization and covariance scaling need an explicit contract; weighted FIML is not inherently impossible |
| Existing `n_starts` | NULL retains the existing five-start listwise rule | NULL or 3; three groups per each of two solvers | Reproduces the frozen local protocol; report six groups separately from actual calls (normally nine with refinements) |
| Existing `control` / syntax starts | Existing controls remain | Empty control; syntax-supplied starts rejected | Avoid unvalidated solver changes; this is an initial engineering restriction, not a mathematical property of FIML |
| Existing `model`, `data` | Existing topology and listwise selection remain | Three numeric observed variables, simple mediation, free/zero cp; retain any-observed model row | Extra columns do not select rows; all-empty model rows alone are dropped; arbitrary names/labels cannot redirect roles |

The strict start/control boundary is the main usability tradeoff. After this
milestone, validated tolerances or iteration limits could be opened individually
with tests for acceptance, failure evidence and reproducibility. Do not open an
unrestricted control passthrough merely to reduce initial error messages.

## Alternatives considered

1. **Recommended: one selector on the native fit entry point.** Familiar missing-
   data terminology, no new fitter, preserved defaults and explicit engine_args
   forwarding. The small public API does not imply broad model support.
2. A top-level `fit_mediation(missing=...)` policy across engines could be useful
   later, but first needs defined GLM/lmer/other-engine semantics and capability
   checks. A uniform argument name without uniform behavior would mislead callers.
3. Separate `fit_fiml()`, `fiml=TRUE`, or an additional `na.action` switch would
   duplicate policy choices and invite contradictory combinations. They are not
   needed for this adopter. Imputation is a different workflow, not another FIML
   flag. Extra synonyms such as `ml` can wait for a demonstrated user need.

## Reporting and downstream behavior matter as much as inputs

Expose the chosen method, random-X policy, retained/dropped row counts, original
positional row ledger and missingness patterns. `nobs()` counts retained rows,
not observed cells or complete cases. Store raw total likelihood with constants;
do not put it in the complete-data discrepancy field or imply an available model
test. Restrict comparisons to compatible likelihood contexts.

Distinguish bad argument types, FIML fit failures, and deferred methods. Generic
type validation may raise ordinary checkmate/base errors before the FIML adapter;
adapter/numerical failures preserve stage/reason/parent and completed calls.
Deferred operations refuse before package-controlled refits, RNG or workers.
Opaque raw-data callbacks and calls first dispatched through external model
classes remain outside those guarantees.

Keep the source parameter labels on SEMFit, but map extracted a/b/c_prime aliases
by topology. If a source label collides with an alias, retain original named
coefficients/covariance in validated fit_context; do not let a string represent
two coordinates or duplicate the authoritative effect-gradient implementation.

## Owning sources and next decision

- [fit_sem and native forwarding](../../../R/fit-sem.R)
- [FIML boundary, provenance and outcome adapter](../../../R/sem-fiml-interface.R)
- [Validated numerical kernel](../../../R/sem-fiml.R)
- [Reviewed support and acceptance contract](integration-design.md)
- [Technical history](technical-record.md)

The next decision is whether the locally verified bounded implementation is ready
for branch review after all pipeline stages pass. Broader controls, new SE types,
weights, fixed-X FIML, extra topologies and cross-engine policies are separate
milestones, not implied by this implementation authorization.
