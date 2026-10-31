# FIML roadmap planning evidence

Status: assembled locally on `codex/roadmap-reconciliation`, 2026-10-31 MDT.
This is a planning packet, not an active implementation or an admission receipt.

## Current authority and reading order

1. [Roadmap current board](../../medfit-roadmap.md#current-board): priorities,
   11-variant scope, owners, delivery states and deferred capabilities.
2. [Paired plan](../../PLAN-FIML-inference-and-observed-models-2026-10-31.md):
   Q12/Q13 decisions, sampling/inference contracts and unresolved FI-B0 gates.
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
- `revised-documents.sha256`: current repository-relative packet checksums. From
  the repository root, verify with
  `shasum -a 256 -c planning/studies/fiml-inference-gates/revised-documents.sha256`.
  The receipt excludes itself to avoid a circular hash dependency.

## Publication boundary

This packet proposes future work; it does not expand released FIML support.
Existing-model row-bootstrap and parameter-draw inference come first, followed
by each approved observed-Gaussian variant. FI-B0 exact API, missingness argument,
manifest, resource/pilot agreement and focused-review closure remain pending.
No dates or versions are assigned. Hosted coverage remains main PRs/main pushes
only, expensive CI release-only, and the CRAN hold remains.

Local assembly/review is authorized. Push, PR, publication, implementation,
new calculations and experiments are not authorized by this packet.
