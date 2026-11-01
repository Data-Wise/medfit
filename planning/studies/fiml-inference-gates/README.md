> **Current checkpoint (2026-11-01):** Local FI-B1/FI-B2 implementation, independent QA, docs and final gates PASS. Renewed suite: 1802 tests, 8983 passing expectations, zero failures/errors; coverage 96.31213% overall and 158/158 changed critical expressions; source supplement 497 tests, one skip; lint clean and package check OK. Statistical admission remains deferred. Implementation is local; integration requires separate authorization. Earlier failure, worker-limit and preregistration deviations are historical and retained below.
> Earlier status statements below are historical where inconsistent with this checkpoint.

> Execution update (2026-11-01 MST): planning PR #378 merged at `5e845007`.
> Bounded local implementation/verification is now separately authorized; see the
> [active plan](../../PLAN-FIML-bounded-inference-implementation-2026-11-01.md).
> Implementation: `medfit-implementer`; independent QA: `medfit-oracle-qa`.
> Bounded implementation/numerical QA/docs are committed locally; final gates are FAIL after the prescribed
> test-helper retry. The active plan records the two remaining assertions, exhausted allowance and deviations.
> Statistical admission and studies remain deferred; historical authorization statements below
> do not override this checkpoint. No implementation push/PR/merge/release is authorized.

# FIML roadmap planning evidence

Status: original packet merged via PR #377; reviewed FI-B0 integration authorized, 2026-10-31 MDT.
This is a planning packet, not an active implementation or an admission receipt.

## Current authority and reading order

1. [Roadmap current board](../../medfit-roadmap.md#current-board): priorities,
   11-variant scope, owners, delivery states and deferred capabilities.
2. [Paired plan](../../PLAN-FIML-inference-and-observed-models-2026-10-31.md):
   Q12/Q13 decisions, current bounded FI-B0 handoff and deferred admission gates.
   The [short checklist](../../DECISION-FI-B0-existing-model-inference-2026-10-31.md)
   supplies the reviewed implementation contract and numerical/resource defaults.
3. [Gate report](report.md): previously computed design probabilities and review
   history. Historical unapproved-target wording is superseded by Q12/Q13.

The source architecture snapshot is dev `f1aaf332`; the planning-branch parent
is `cc3fd887245fa01026439d4c103fc2be020d1a01`. No runtime source was changed.

## Evidence inventory and limitations

- `gate-probabilities.R` and five CSVs (`coverage`, `availability`, `joint`,
  `families`, `refit`): historical exact design calculations, not FIML model fits,
  coverage simulations or execution authorization. Not rerun for assembly.
- `opus-inference-original.json`, `opus-roadmap-original.json`,
  `opus-revision-review.json`: original read-only reviews, including limitations
  and unresolved findings. Anchors refer to their earlier payloads. They do not
  certify this assembled revision or close the future FI-B0 focused-review gate.
- `assembly-source.json`: source hashes before copying; originals remain in the
  design worktree. Raw reviews, script and CSVs are copied byte for byte.
- `preassembly-revised-documents.sha256`: original absolute-path receipt, preserved
  as historical provenance. It is not a current portable verification command.
- `revised-documents.sha256`: preserved historical checksums of the PR #377
  packet, verified against every pre-reconciliation file in `ff200ee9`. Verify
  this historical receipt in that snapshot, not against subsequently updated
  roadmap/plan/index files. Raw reviews, script, CSVs and this receipt are unchanged.
- `fi-b0-reconciliation.sha256`: current local checklist, roadmap, plan, status,
  CLAUDE and index checksums. From the repository root, verify with
  `shasum -a 256 -c planning/studies/fiml-inference-gates/fi-b0-reconciliation.sha256`.
  Each receipt excludes itself to avoid circular hash dependencies.

## Publication boundary

This packet proposes future work; it does not expand released FIML support.
Existing-model row-bootstrap and parameter-draw inference come first, followed
by each approved observed-Gaussian variant. The short FI-B0 contract is reviewed
locally with no blocking design findings; runtime validation has not occurred.
Bounded implementation needs separate authorization and owner assignment. Large
simulations/timing pilot and statistical resource agreement remain deferred;
Q10-Q13 statistical admission requirements remain unresolved for release.
No dates or versions are assigned. Hosted coverage remains main PRs/main pushes
only, expensive CI release-only, and the CRAN hold remains.

Local reconciliation/review is authorized; PR #377 publication is historical.
The maintainer authorized this follow-up for push, PR and merge into dev after
review and passing checks on 2026-10-31 MDT. Implementation, release, new
statistical calculations and experiments remain unauthorized.
