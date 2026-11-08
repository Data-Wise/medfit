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
1. **Cost exceeds the cap.** The API takes one effect per call, so each dataset does 3 refit calls
   (NIE, NDE, TE) at ~114 s: ~2.4 h per 25-dataset task, ~6,000 tasks = **~600 core-days against the 250 cap**.
   Either (a) a study-only patch that evaluates all three effects on one set of refits (~200 core-days, but
   it changes the studied source and needs parity proof and review), or (b) raise the cap, or (c) revise the
   design. Pilot timings: `../fiml-timing-pilot/REPORT.md`.
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
   (4 h tasks). Scratch size is small (CSV only) but has no backup: copy results off scratch.
6. **Missing before any run:** independent QA review of this harness, the frozen preregistration, a
   completeness checker, and the maintainer's approval. The earlier pilot's QA completeness check is also open.
