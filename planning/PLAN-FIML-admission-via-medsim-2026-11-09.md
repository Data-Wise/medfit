# Plan: FIML admission studies run through medsim (DRAFT, 2026-11-09)

Status: planning only. Nothing here is authorized to run. Section 5 of
`PLAN-FIML-next-release-model-expansion-2026-11-01.md` keeps every study, pilot and gate
deferred until the maintainer authorizes it; this plan says how the work would be run once
they do, and where the maintainer must decide first.

## Why this exists

Implementation and numerical verification of the bounded FIML models is merged (simple,
parallel and serial, 0-2 covariates, 14 variants). No coverage study exists for any of them,
and the Missing Effect simulations test MBCO with multiple imputation, not FIML intervals
(checked 2026-11-09). The only thing the studies unlock is lifting the `dev` guard on
source-fit bootstrap intervals. Delta Wald intervals are already available.

## What medsim offers (medsim 0.6.0.9000 on disk; 0.5.1 installed)

| Need | medsim piece | Fit |
|---|---|---|
| SLURM array on Hopper | `medsim_write_submit_script()`, fail-loud login-shell script, requeue, throttle | does NOT replace `stage0.sbatch` (see Status below): it lacks the module purge, thread exports, fingerprint, clean-tree and HEAD checks and loads a different R module (`-ytj2` vs `-fyqw`, a BLAS difference) |
| One chunk of cells | `medsim_run_chunk()` | replaces the loop in `run-chunk.R` |
| Combine and integrity audit | `medsim_combine_chunks()`, `medsim_audit_results()`, `medsim_check_results()` | adds to `check-complete.R`, whose `FAIL_STATUS` lacks `withheld` and `incomplete` (the adapter recodes them) |
| Coverage, power, bias tables | `medsim_analyze_coverage()`, `medsim_analyze_power()`, `medsim_tables()` | exploratory tables only (see below) |
| Caching | `medsim_cache_*` | resumable chunks |

## Constraints that shape the plan

1. **Denominator.** `medsim_analyze_coverage()` drops rows with a missing interval or truth and
   reports failures separately. The stage-0 rule (expected-record ledger, Q10-Q13) counts every
   attempted replication and treats an incomplete interval as a miss. The preregistered
   decision therefore uses a small medfit-side analysis script over the combined records, not
   `medsim_analyze_coverage()`. medsim is used for orchestration, chunk integrity and
   exploratory tables.
2. **Silent K = 1 fallback in medsim 0.5.1.** Successful saved rows cannot exclude a silent
   complete-case fallback. Pin one medsim commit, require effective-K receipts in each row, and
   state that in the preregistration.
3. **Shared-refit patch.** The 60-cell stage-0 design costs about 208 core-days only with the
   shared-refit patch (plan cap 250). It changes the studied code path, so the preregistration
   names it and the pinned commit, and `parity-check.R` is re-run inside the pinned Hopper
   environment.
4. **Hopper pitfalls recorded earlier.** Rscript over ssh needs `bash -lc "module load ..."`;
   array runs default to `N_CHUNKS = 1` and a hard-coded output directory can overwrite
   production chunks; two R modules exist with different BLAS.
5. **Guard.** The study overrides the stage-0 guard in-process, gated on a fingerprint file;
   the source on Hopper stays unmodified.

## Phases

| Phase | Work | Needs maintainer |
|---|---|---|
| P0 | Decide scope: stage 0 only, or also which expanded variants (see Feasibility). Approve thresholds (OPEN-10, Q10-Q13), budget, seed allocation. | **yes** |
| P1 | Adapter: a `medsim` method wrapping `fit_sem(missing = "fiml")` plus the two source-fit methods, and a scenario table built from `cells.R`; effective-K receipt per row. | no (code, local) |
| P2 | Parity: the medsim-run chunk reproduces the existing `run-chunk.R` rows on the 8-12 parity scenarios (identical records), plus a planted defect the audit must catch (a dropped chunk, a duplicated cell). Independent QA. | no |
| P3 | Pin the environment (`env-setup.sh`, module hash, package versions, fingerprint), re-run parity on Hopper, freeze the preregistration. | **yes (freeze, submit exact files)** |
| P4 | Pilot chunk, then the stage-0 array with `medsim_write_submit_script()`; `medsim_combine_chunks()` completeness audit. | **yes (submission)** |
| P5 | Analysis by the preregistered script; remediation rule if stage 0 fails (one round on fresh seeds, per G9). | maintainer reads result |
| P6 | Per-variant designs and runs for any expanded variant, each with its own grid, ledger and power. | **yes, per variant** |
| P7 | Admission decision, guard lift for admitted variants only, docs and release gates. | **yes** |

## Feasibility and the necessity question

- Stage 0 (simple model): about 208 core-days with the shared-refit patch, inside the 250 cap.
  One refit call of B = 999 takes about 114 s, independent of n.
- Expanded variants: the 14 variants each need their own grid and power. A naive repeat of the
  stage-0 grid per variant would be about 14 times stage 0, roughly 2,900 core-days, far over the
  cap. This is an order-of-magnitude upper bound, not a design: variants differ in cells and
  cost, and a reduced grid or fewer admitted variants would be cheaper. P0 must pick among:
  (a) admit stage 0 only; (b) a small set of priority variants; (c) a reduced grid; (d) do not
  admit expanded bootstrap intervals and keep them withheld.
- Necessity: the studies are needed only to lift the guard on bootstrap intervals. Release can
  ship all 14 variants with delta intervals and the bootstrap guard in place. Option (d) costs
  nothing and loses only an interval method whose coverage is not established.

## Recommendation

Authorize P1-P2 now (local, no cluster, no submission): they are cheap, reversible and make the
later decision concrete. Defer P3 onward until the maintainer picks the scope in P0. Prefer
(a) or (b) over a full per-variant program unless bootstrap intervals for the expanded models
are a release requirement.

## Open decisions for the maintainer

1. Scope option (a)-(d) above.
2. Acceptance of OPEN-10 (retained-row estimand, .10 empty probability, 228/72/60 classification).
3. Budget: keep the 250 core-day cap, or a separate cap per phase.
4. Whether to adopt medsim for the stage-0 harness (this plan) or keep the hand-written harness
   that has already had independent QA.

## Status (2026-11-09): P1 and P2 done locally, merged into this branch

Code: `planning/studies/fiml-stage0-hopper/medsim/` (adapter, receipts, attempted-denominator analysis with a single
gate, smoke runner, parity and planted-defect tests, README). Independent QA PASS (parity on five cells the implementer had not
used, hand-recomputed denominator, truth for all 60 cells, 11 of 12 planted defects caught; the four gaps it found are closed and
re-tested: complete-row consistency, one gate over ledger, receipts and truth, chunk-overwrite guard, combine in stop mode).
Defects 37/37 and parity 12/12 identical at B = 40 on the local macOS BLAS.

Findings that change this plan:

- medsim's generated submit script cannot replace `stage0.sbatch`; keep the hand-written script or re-implement its gates in a wrapper.
- Pin medsim 0.6.x (0.5.1 drops task-level errors silently). The silent single-imputation fallback is in medsim's own multiple-imputation
  methods, which the adapter never calls.
- `check-complete.R` must learn `withheld` and `incomplete` before any real run with refit failures (feeds PREREG P7).
- Not verified: Hopper or Slurm, OpenBLAS, full-size B = 999 timing and parity, the real HEAD-equals-fingerprint check.

Next (needs the maintainer): P0 scope decision, then P3 (pin the environment, rerun parity on Hopper, freeze the preregistration).
