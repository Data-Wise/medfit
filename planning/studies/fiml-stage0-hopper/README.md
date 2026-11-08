# Stage-0 study on Hopper: DRAFT for review (nothing here has been run on Hopper or submitted)

Status: draft, 2026-11-07. Not preregistered, not frozen. Submitting any job needs the maintainer's
explicit approval of the exact files, per `reference/research-repo-session-lessons.md`.

## Files
| File | Purpose |
| --- | --- |
| `cells.R` | 60-cell grid (2 n x 5 regimes x 3 missingness x 2 direct paths), truths, seed formula `7,000,000 + cell*10,000 + dataset` (disjoint from the pilot seeds 9100101..9101203) |
| `run-chunk.R` | One task: a cell and a dataset range; fit, then NIE/NDE/TE x both methods; one CSV row per bootstrap call incl. status, counts, estimate, interval, truth, failures. Locally smoke-tested at tiny size (B=10, 200 draws) |
| `env-setup.sh` | Builds the pinned R library on `/carc/scratch`, writes `env-fingerprint.txt` + sha256; syntax-checked only |
| `stage0.sbatch` | 6,000-task array (60 cells x 100 chunks of 25 datasets), 1 core each, throttle 96; syntax-checked only |

## Review items (blocking unless marked)
1. **Cost: addressed by a study-only shared-refit patch (needs review).** Without it each dataset runs
   three refit sets (~600 core-days, over the 250 cap). `shared-refits.R` caches each refit by its resampled
   rows (a call's resamples depend only on seed, B and n, so the NIE/NDE/TE calls use identical rows) and
   replays cached failures. Local evidence: `parity-check.R` shows shared == unpatched for all three effects
   in the original 8 scenarios, now 12 with the warning case (free/fixed-zero direct x MAR/MCAR-with-empty-rows x without/with injected refit failures;
   B=40, 6/40 failures observed in the injected case), and a planted defect (cache ignoring the rows) is caught
   (0/8 identical originally, 0/12 now). At B=999: first effect call 96 s, the other two 0.3 s each; process RSS ~0.5 GB (cache
   object.size reports 0.7 GB, an overcount from shared references). Estimated total ~208 core-days. Limits to
   review: parity was run at B=40 and nonparametric only (parametric makes no refits); re-run
   `parity-check.R` inside the pinned Hopper environment before use; the patch changes the studied code path
   and must be named in the preregistration with the pinned commit.
2. **Environment.** R is a spack module (`r/4.4.0-fyqw` and `-ytj2` both exist; BLAS differs risk). The
   module hashes in the scripts are guesses to confirm; CRAN packages (`nloptr`, `S7`, ...) are installed
   from source on the cluster, so versions drift unless pinned. Results from another BLAS than the
   local OpenBLAS runner need a stated parity check.
3. **Guard override** is in-process and gated on a fingerprint file; the package source on Hopper stays
   guarded. The study source (commit) must be named in the preregistration.
4. **Unresolved design inputs** (README of `../fiml-admission-design/`): collection cap for the all-empty
   cell (10 n here is a placeholder), failure/denominator policy, per-cell dataset count M=2,500 vs
   cost, expected-record ledger (this harness writes rows but no completeness check yet).
5. **Queue.** Fair-share was 0.13 on 2026-11-07; wall-clock is uncertain. 2-day job limit is not a problem
   (tasks request 2 h, about 50 min expected). Scratch size is small (CSV only) but has no backup: copy results off scratch.
6. **Independent QA (2026-11-07) and status of its findings.** Fixed locally: failure rows no longer crash
   the write (fixed 21-column schema, a failed dataset expands to all 6 rows); output is appended after every
   dataset with a wall-clock budget (`STAGE0_BUDGET_S`, default 6,000 s) and refuses to overwrite; commit and
   fingerprint hash are columns and the runner checks HEAD equals the fingerprinted commit; the sbatch checks
   HEAD and ignored files; sha256 file is overwritten, not appended; warnings are replayed on cache hits and
   `parity-check.R` keeps full records and adds a warning case (12/12 identical, planted defect 0/12);
   `check-complete.R` verifies 60 x 2,500 x 3 x 2 rows. **Still open (need Hopper or a decision):** confirm the module hashes (the dated 2026-11-01 package snapshot was verified reachable and is now used); re-run `parity-check.R` in the pinned Hopper
   environment as a gating job; time one chunk on Hopper (estimate 187-208 core-days leaves ~20% under the cap;
   a core 1.2x slower breaches it); check `MaxArraySize` (default 1001 would reject 6,000 tasks); per-call
   timeout/fork-kill is not implemented (the budget stops cleanly between datasets only).
7. **Missing before any run:** independent QA review of this harness, the frozen preregistration, a
   completeness checker, and the maintainer's approval. The earlier pilot's QA completeness check is also open.
