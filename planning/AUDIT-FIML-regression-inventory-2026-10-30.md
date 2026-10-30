# FIML regression inventory

Date: 2026-10-30. Source inspected: dev `a250fdf7`. Static inventory only;
no numerical fits, package tests, benchmarks or CI were run for this audit.
No production or test code changed. This audits A1 in
[the readiness plan](PLAN-FIML-release-and-missing-data-followups-2026-10-30.md);
it does not authorize implementation or add release requirements.

## Verdict

Promote missing independent public-API checks, rather than repeat the entire
42-fit prototype study. Two proposed groups already have substantial production
coverage: no-complete-row fitting and actual no-overlap rejection. Singletons
are also exercised by an existing fixture. These facts reduce the new work;
they do not establish independent numerical agreement for every fixture.

## Evidence by proposed group

| Group | Existing production evidence | Remaining bounded work |
|---|---|---|
| Observed-X MAR | `tests/testthat/test-sem-fiml.R:1` uses deterministic row-index masks; `tests/sim/sem-fiml-gate.R:64` uses two deterministic masks. Neither missingness mechanism depends on observed X. | Promote an observed-X-dependent fixture, preserving X for missingness decisions; compare independent likelihood and lavaan estimates/full covariance for free/zero direct paths. This validates computation under that simulated design, not MAR in observed data. |
| No complete rows | `test-sem-fiml.R:170` fits a no-complete-row dataset with singleton and pair observations. Gate seed 613 has pair observations only and compares independent row likelihood plus lavaan estimates/full covariance for both direct-path forms. | Retain the gate. Add neither a redundant basic fit nor a duplicate four-fit oracle suite. Strengthen explicit row/pattern/rank assertions where absent, and account for the separately required common-parameter objective check. |
| Seven patterns, singletons, empty rows | `test-sem-fiml.R:170` exercises all three singleton and all three pair patterns. Base tests exercise complete rows; `:27` and `:245` test empty-row exclusion/provenance. These occur across different fixtures. | One identified fixture containing all seven nonempty patterns plus an empty row, with explicit pattern counts and independent numerical checks. Avoid claiming singleton handling is wholly untested. |
| Affine transport | No location/scale transport assertion in the inspected production FIML tests or gate. The prototype acceptance script has separate shifted and rescaled cases and transport checks. | A declared joint location/scale transformation with back-transported coefficients, intercepts and full covariance, plus the observed-coordinate likelihood Jacobian. Cover both direct-path parameterizations. |
| Near-singular / unidentified | `test-sem-fiml.R:198` uses actual disjoint (X,M) versus Y observations and requires rank-deficiency text plus retained attempts/calls. `:478` plants invalid information matrices after real solver calls; it is a guard test, not a near-singular data oracle. | Add a genuinely near-singular but estimable public-API fixture with independent information/geometry evidence. Strengthen the existing no-overlap test's exact numerical stage/reason and independently deficient rank, including the zero-direct-path variant; reuse its existing evidence-retention assertions. |

## Exact mask reconstruction

A lightweight independent reconstruction of the index masks (no fitting, no R
execution) gave these counts, in X/M/Y order, where 1 means observed:

| Fixture | Pattern counts |
|---|---|
| Base unit fixture, 240 rows | 011:48, 101:48, 110:48, 111:96 |
| Unit no-complete fixture, 240 rows | 001:32, 010:32, 011:48, 100:32, 101:48, 110:48 |
| Gate seed 613, 240 nonempty rows | 011:80, 101:80, 110:80 |

The gate appends one all-empty row. These counts follow the inspected masks;
they are not runtime assertions from the package. No single inspected production
fixture contains all seven nonempty patterns together.

## Independent evidence that should be preserved

- `tests/sim/sem-fiml-gate.R:37` constructs structural means/covariance and
  computes Gaussian likelihood row by row, independently of the production RAM
  objective and standardization. Its four fitted cells check this at medfit's
  returned coefficients; they do not directly compare the production objective
  and oracle at a predeclared common off-optimum parameter vector.
- `test-sem-fiml.R:91` and the gate compare lavaan observed-information full
  covariance, including off-diagonal entries, with matched random-X means and
  free/zero direct paths. Preserve these checks and their fixed limits.
- `test-sem-fiml.R:39` already checks both public routes, covariance aliases,
  provenance and effect propagation. Reuse route equivalence checks selectively;
  there is no need to repeat every expensive numerical cell through both routes.
- `test-sem-fiml.R:115`, `:220`, and the subsequent fault-injection tests protect
  refusal behavior, no-RNG guards, evidence binding and genuine solver records.
  The comparison article's `test-lavaan-comparison.R:38` additionally checks
  FIML row retention; it does not close the numerical fixture gaps above.

## Proposed next authorized implementation

1. Freeze a fixture manifest and oracle mappings/limits before candidate fits,
   following A1. Include input identities, expected rows/patterns, independent
   rank/conditioning, transformations and exact deliberate-refusal contract.
2. Reuse the existing pair-only oracle gate and no-overlap control. Add the
   missing MAR, combined-pattern, affine and near-singular fixtures; strengthen
   the existing controls rather than copying them wholesale.
3. Check the production objective against an independent row likelihood at
   fixed shared parameters as well as fitted optima. Require the existing
   estimate 1e-5, standardized full-covariance 1e-3 and NLL 1e-7 limits from A1.
   Record failures without post-hoc tolerance relaxation.
4. Run independent numerical QA, discriminating planted-defect checks and the
   applicable local gates in a separately authorized implementation worktree.
   Expensive CI remains deferred until release to main.

No new defect was established by this static inventory. Existing green coverage
is historical evidence; this audit makes no fresh numerical pass claim.
