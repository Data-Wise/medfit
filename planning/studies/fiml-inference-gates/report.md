# Exact FIML screening-gate probabilities and planning revision

Date: 2026-10-31 MDT. Design calculations only: no fitted model, bootstrap,
Monte Carlo simulation, production edits, hosted CI, push or release.

## Reproduce

Historical reproduction command, from a repository root containing this packet
(not rerun during assembly):

```sh
Rscript --vanilla planning/studies/fiml-inference-gates/gate-probabilities.R
```

Uses base/recommended R only. The script writes five CSVs beside this report.
The checks independently invert the Clopper-Pearson bound through binomial tail
probabilities and verify the availability=1 special case of the joint gate.
They are mathematical design checks, not FIML acceptance tests.

## Exact results

The lower bound is qbeta(.05, x, n-x+1), with zero successes assigned bound zero.
With M=500, the .925 coverage floor needs 473 covering intervals; a genuinely
.95-covering procedure with availability 1 passes with probability **.703875**.
The .95 availability floor needs 484/500 returned intervals. Its exact pass
probabilities at true availability .97/.98/.99 are .665604/.974259/.999983.
These correct the original Opus normal approximations; the design concern holds.

For a prespecified IID population of datasets, let A~Bin(M,a) be returned
intervals and C|A~Bin(A,c) be covering returned intervals. This is a three-category
multinomial model with probabilities (1-a, a*(1-c), a*c). The calculation sums
P(A)*P(C exceeds both conditional-coverage and joint-coverage critical counts|A)
while enforcing the availability threshold. It accounts for the shared coverage
numerator, rather than multiplying three dependent gate probabilities.
Here c=.95 throughout:

| M | True availability a | Probability all three gates pass |
|---:|---:|---:|
| 500 | 0.97 | 0.376092 |
| 1000 | 0.97 | 0.740720 |
| 2000 | 0.97 | 0.953203 |
| 500 | 0.98 | 0.646571 |
| 1000 | 0.98 | 0.929267 |
| 2000 | 0.98 | 0.998245 |
| 500 | 0.99 | 0.716850 |
| 1000 | 0.99 | 0.941384 |
| 2000 | 0.99 | 0.998520 |
| 500 | 1 | 0.703875 |
| 1000 | 1 | 0.948890 |
| 2000 | 1 | 0.998693 |

At M=500,a=.98,c=.95, the per-cell probability is .646571. For six independent
identically performing cells, all-pass probability is .073063; for 12, .005338.
Those powers are **illustrations**, not a model of actual dependence. Cells and
methods may share samples/draws; no independence is presumed for final admission.
`families.csv` also reports a valid but often uninformative union-bound lower
bound, max(0,1-K*(1-p)). Product formulas cannot be used as exact family power
without an independence argument.

M=2000 gives per-cell power .998245 at a=.98,c=.95. For K=66 cells, the union-bound
lower bound is approximately .88418, requiring no independence. This is a
candidate cost illustration, not approval to quadruple the study. Its power is
much lower when true availability is .97; the reference performance assumptions
must be declared, not inferred from favorable pilot outcomes. Number of regular
statistical cells K is not the 132-cell *numerical oracle* count.

For a fixed dataset, if replicate failures are IID with probability q, strict
all-success availability is (1-q)^999. Availability .95/.98/.99 corresponds to
q=.0000513433/.0000202227/.0000100604. Across heterogeneous datasets, marginal
availability is E[(1-q_D)^999], not (1-E[q_D])^999. This relationship is not an
empirical estimate of medfit failure rates. Larger B can lower availability.

## Historical revision decisions and remaining blockers

This section records the pre-Q12/Q13 review payload. The final closeout below
and the paired plan own current decisions; the power targets are now agreed.

- Preserve all approved 11 model variants and Q7/Q8 sampling/failure rules.
- Preserve Q10 floors and M/B proposal as historical agreed screening choices;
  no statistical release clearance from the underpowered all-cells design.
- FI-B0 must establish a fixed cell/regime manifest and agreed decision power,
  with a resource cap, before confirmatory outcomes. Suggested >=.90 per-cell
  and >=.80 whole-manifest power are **proposals awaiting agreement**. M revision
  or a different release decision structure requires explicit pre-outcome review.
- Freeze cell/regime definitions before a timing pilot; use disjoint seeds,
  record timeouts/failures transparently, and forbid outcome-based cell removal.
- Gate regular axis nulls as regular. Classify expanded functionals by their
  complete gradient; exact joint singular points and local sequences get explicit
  limitations, not automatic ordinary-validity claims.
- Both interval branches use type-7 quantiles; add an explicit empty-record
  conditional-target argument/cell and prohibit retry-until-CI advice.
- Namespace FI-* IDs; define branch-specific delivery states and state/gate
  requirements, history/revert handling and a pinned/common roadmap base.
- Reconcile roadmap priorities and historical footer; keep release version
  unassigned, CRAN held, coverage main-only and expensive CI release-only.

## Original review provenance

`opus-inference-original.json` and `opus-roadmap-original.json` preserve the
original reviews, scoped coverage/skips, uncertainty, findings, recommendations,
usage and session resume hints. Their line anchors refer to pre-revision text.
Both used requested opus / effective claude-opus-5-5. Inference: 5 turns,
173029 ms, $0.6559034, 153635 reported tokens. Roadmap: 9 turns, 99323 ms,
$0.6437542, 138314 reported tokens. Both completed without cost/turn/Evidence
Lease exhaustion; no Evidence Lease supplied. No automatic resume occurred.

Revised plan/roadmap still require focused review; an explicit FI-B0 blocker is
not a resolved implementation contract. No new features are implemented.

## Focused Opus re-review and local follow-through

`opus-revision-review.json` preserves the full result and its coverage, skips,
uncertainty, recommendations, usage and session resume hint. Requested opus;
effective claude-opus-5-5; needs-attention, low uncertainty. It validated the
critical-count and shared-numerator code statically (no execution) and found
original statistical concerns resolved or explicitly blocked. Its three residual
findings were: pin the revised roadmap rather than parent cc3fd887, enumerate
all FI-B0 blockers in the task-index row, and show power below nominal coverage.

These were addressed locally after that review: a literal revised-roadmap
SHA-256 now appears in the plan with the uncommitted/non-merge limitation;
the acceptance row names API, policy, approved power/reference decision, pilot,
missingness argument, empty-row cell and manifest as mandatory gates. Exact
sensitivity calculations now include coverage .93/.94/.95/.96. At coverage .94
and availability .97, probability all three gates pass is:

| M | All-three pass probability |
|---:|---:|
| 500 | 0.148910 |
| 1000 | 0.320555 |
| 2000 | 0.532538 |

A method above the rejection floors can still have low admission power; the
reference alternatives and indifference region must be agreed before data.
These sensitivity numbers do not designate .94/.97 as an approved target.
Power studies cannot promise high admission exactly at a rejection boundary.

Re-review usage: 196075 reported tokens (10764 output), 11 reported turns,
107431 ms (106715 API), $0.642076. Configured max_turns=10; the tool nevertheless
reports 11 actual turns and turn_limit_reached=false; retain both rather than
silently normalizing. Cost/Evidence Lease exhaustion=false; lease=null.
Session e8244f23-97bf-469d-948a-84b9818c5867; resume hint recorded in JSON, not used.
The initial new-review call was rejected by automatic approval review for a
revised private-document export; explicit user approval then authorized this
single bounded re-review. No fallback or automatic continuation was launched.

Final follow-through checks are local only. The post-review bookkeeping and
sensitivity additions have not received a further external review. The focused
review therefore did not give unconditional clearance. FI-B0 agreement and
focused-review closure remain prerequisites; no production implementation,
model fitting, simulation, push, merge, release or expensive CI occurred.

## Roadmap closeout: Q12-Q13 (2026-10-31 MDT)

The user selected nominal-reference power (coverage .95 / availability .98),
>=90% per-cell and >=80% complete-stage pass probability, with sensitivity
reporting rather than a high-power promise below nominal performance. Admission
uses separately preregistered complete stages: existing simple-model inference
first, then each of the approved 11 variants. The earlier text calling these
choices unapproved describes the historical review payload, not current policy.

The roadmap and plan now record both decisions. Exact APIs, feasible stage
manifests/resource budgets, timing protocol and focused-review closure remain
future prerequisites. No additional calculation, experiment, implementation,
commit, push or publication was performed for this closeout.

## Planning-packet assembly (2026-10-31 MDT)

The report, original review JSON, calculation script and CSVs were copied into
the roadmap branch without rerunning calculations. Raw JSON, script and CSV
bytes are unchanged. The original absolute-path checksum receipt is retained as
`preassembly-revised-documents.sha256`; it describes the earlier worktree state,
not this assembled packet. The new `revised-documents.sha256` uses repository-
relative paths. See [the evidence index](README.md) for provenance and review
boundaries. No new external review or statistical acceptance is claimed.
