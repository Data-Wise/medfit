# FIML readiness plan: grill and Claude adversarial review

Status note (2026-10-31): historical review; its A1/A2/A3 recommendations
subsequently completed and shipped in 0.16.0. Current priorities are in
[the roadmap current board](medfit-roadmap.md#current-board). This annotation
does not reclassify Claude's original verdict or imply a fresh external review.

Date: 2026-10-30. Scope: planning only; no production changes, numerical test
runs, benchmarks, pushes or expensive CI. Target:
[reconciled plan](PLAN-FIML-release-and-missing-data-followups-2026-10-30.md),
[0.16 scope](SCOPE-0.16-FIML-2026-10-30.md), and current roadmap edits.

## Verdict

Claude's original verdict was **needs-attention**, identifying three medium and
three low planning concerns, no source/test defect. The substantive planning
concerns were corrected locally below. The corrected plan is suitable for a
scope decision, not implementation or release authorization. Claude has not
re-reviewed the corrections; its original verdict is not relabeled PASS.

The plan now separates existing release gates from optional new regression/teaching
work. It assigns fitting to medfit, workflow/diagnostics to missingmed, reuses
mice, and does not confer new RMediation/FIML inference support. missingmed's
consumer checkpoint remains distinct from FIML adoption and medfit's release.

## Findings and dispositions

Line references below refer to the original reviewed plan, before correction.

1. **Medium: A1/A2 release-blocker ambiguity** (plan lines 60-96).
   Accepted. Added an explicit gate rule: A3 and truthful shipped-feature docs
   remain required; extra A1 fixtures and a new A2 minibook unit do not become
   0.16 prerequisites without a scope decision. A failed experiment is not
   automatically a release blocker; a demonstrated correctness defect is.
2. **Medium: circular tolerance selection and generic refusal acceptance**
   (plan lines 78-96). Accepted. Require a committed pre-run fixture manifest,
   independent reference conditioning, unchanged oracle limits and affine
   transport back to base units. Condition metrics and the existing 1e-4 gate
   are named. The unidentified control must reach the specific rank-deficient
   observable-moment Jacobian refusal with typed numerical error and attempts;
   earlier unrelated errors do not count. No new fixture has been run.
3. **Medium: undated CI/local evidence** (scope lines 1-8).
   Accepted in part. Added a timestamp, exact run link/final-result rule and
   local archive path/SHA-256. The earlier merge/check assertions were verified
   through live GitHub queries in this session, but are historical evidence
   after that observation. An ignored local archive is not portable tracked
   evidence; that limit is explicit rather than uploading rendered/session data.
4. **Low: unbounded benchmark and undefined first-baseline regression**
   (plan lines 176-198). Accepted. Eight medfit cells, one warm-up and three
   timed repeats are proposed; all masks/values/order freeze before timing.
   Named model/likelihood/information matching is required before interpreting
   lavaan timings. First measurement establishes the baseline; a future paired
   comparison needs a predeclared material-change criterion. The missingmed
   study remains a separate bounded design, not a Cartesian expansion.
5. **Low: unrelated untracked `.codex/` might be staged accidentally**
   (plan lines 240-243). Not an introduced defect; existing instructions already
   require narrow staging. Added an explicit preservation note. Do not change
   global ignore rules or publish those files as part of this planning task.
6. **Low: roadmap's 0.15.0 release statement not fully read by reviewer**
   (roadmap lines 3-4). Verified, not a defect: `.STATUS` version field explicitly
   records 0.15.0 RELEASED, tag `v0.15.0` at `e068d75`, release PR #349 and main CI.
   Also corrected the old shim-removal candidate: NEWS and .STATUS record #351
   as already removed on dev. The historical roadmap body remains marked as such.

## Direct follow-up checks by Codex

- Read `R/sem-fiml.R:300-347`: optimizer acceptance precedes the observable-moment
  rank gate; both rank/information failures retain completed attempts.
- Read `R/sem-fiml-interface.R:148-176`: adapter propagates the typed FIML error,
  numerical stage, reason, parent, attempts and solver calls. `R/sem-optim.R:27`
  defines the existing 1e-4 singularity tolerance.
- Read missingmed `R/run.R:41-93`: MI completes all imputations, fits serially,
  carries warnings and refuses nonconverged fits. This is not a FIML route.
- Read missingmed `R/pool.R:1-140` and `R/MDMediationResult.R:1-27`: Rubin pooling
  and FMI/RIV refer to individual coefficient/path rows, not the indirect effect.
- Read missingmed `R/ipw_run.R:218-259`: returned fit stores final weights and
  original specification. Earlier `.ipw_weights_info` exposes pre-trim details
  internally; a future no-refit public report needs a separate capture design,
  not an assumption that every diagnostic already survives in a fitted object.
- Read missingmed `R/sensitivity_mnar.R:1-100`: delta is conditional, realized
  MSP is reported, imputation method controls units/routing, failed rungs and
  tipping-point limitations already have explicit semantics.
- Read missingmed `tasks/plan.md:1-42` and `docs/ROADMAP.md`: D4/D5/T5 remain open
  in local records. No missingmed owner file was edited or gate closed here.

These are static checks, not newly executed consumer tests. A generic typed error
alone cannot prove that the intended unidentified-design guard was exercised.

## Claude coverage and limitations (original review)

Examined: full new plan; scope/roadmap diffs; production FIML kernel and four-fit
oracle gate; DESCRIPTION; status/planning grep; missingmed plan grep and keyword
counts in pool/IPW/sensitivity files. C's missingmed behavior was **not** independently
source-verified by Claude. Its coverage record named `planning/.STATUS`; the
actual release statement was independently checked in root `.STATUS` by Codex.

Skipped: missingmed run/roadmap; untracked draft PR report; original completed
integration plan; `.codex/`; testthat FIML bodies; vignettes/minibook; local archive
receipt. Medium uncertainty. No numerical test, benchmark, source verification
of external literature, or full cross-package correctness review was performed.

Claude recommended a quick focused follow-up on missingmed pooling/sensitivity,
the refusal guard and status release field. Codex inspected those directly as
listed above. No automatic Claude retry, model chain or budget expansion occurred.

## Review identity and usage

- Tool: dedicated read-only `claude_adversarial_review`, standard profile,
  medium effort. Requested model `sonnet`; effective `claude-sonnet-5-5`.
- Job `cbf4bc50-b904-4339-b2de-0deaab1e5a29`; reviewed working-tree fingerprint
  `f91afae30e4a4db8390f32499b5335b80d814de326056928a9e244020716e9a9`.
- Completed in 49,966 ms (API 49,258 ms); reported 13 turns; 193,604 total tokens,
  6,693 output tokens; cost $0.229316. Configured turn budget 12/finalize 9;
  despite reported 13 turns the tool explicitly returned `turn_limit_reached=false`.
- Evidence Lease: none; `evidence_lease_exhausted=false`;
  `cost_budget_exhausted=false`; exit 0; no context drift reported.
- Session `37973d31-c851-4447-9a43-1b2d7cc09a38`; manual resume hint:
  `claude --resume 37973d31-c851-4447-9a43-1b2d7cc09a38` (not executed).
- Full original structured result/usage retained locally at
  `_agents_workspace/fiml-readiness-claude-adversarial-2026-10-30.json`.

## Historical recommended scope decision (completed)

Start a bounded medfit production-test coverage inventory and FIML teaching
unit proposal. Authorize only uncovered regression cases and exact teaching
additions after that inventory. Keep new diagnostic APIs, missingmed adoption,
parallelism and broader FIML inference separate; do not postpone 0.16 for them.
