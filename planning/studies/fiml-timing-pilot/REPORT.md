# FIML stage-0 timing pilot: report, 2026-11-07

Feasibility only. Source `3826c9ac` (clean tree), manifest `MANIFEST.md`, local machine,
sequential single worker, guard override in-process. Raw log: `_agents_workspace/fiml-timing-pilot/pilot-log.csv` (git-ignored).

## What happened
- 12 cells planned (3 datasets each, three timed units per dataset). Cells 1-9 and cell 10 dataset 1
  completed cleanly; cell 10 dataset 2 completed but its refit call logged 4,632.86 s; the remaining
  22 units (cell 10 dataset 2 parametric onward, cells 11-12) are logged `unattempted_total_cap`.
- **The 4,632.86 s value is not a compute time.** The lid was closed: `pmset` shows Clamshell Sleep at
  16:44:19, and the call resumed after wake (~18:00). The child process was suspended, so the cell cap
  could not fire in time, and the total cap then tripped from wall-clock. Exclude it from timing.
- Not run: cell 10 dataset 3, cells 11-12 (both all-empty cells with fixed-zero direct path), and
  parametric for cell 10 dataset 2. The pilot therefore did **not** cover the fixed-zero all-empty
  cells. No independent QA completeness check against the caps has been done yet.

## Clean timings (85 clean units of 86 logged ok; every ok refit call had 999/999 successes, every draw call 20,000/20,000)
| Unit | Mean | Range |
| --- | ---: | ---: |
| FIML fit | 0.16 s | n/a |
| Row-refit call, B=999, free direct (n=200 / 500) | 119 s / 120 s | 116-123 s |
| Row-refit call, B=999, fixed-zero direct (n=200 / 500) | 105 s / 105 s | 101-107 s |
| Parameter-draw call, 20,000 draws | 3.63 s | 3.5-3.9 s |

Cost does not depend on n (200 vs 500) in this slice. Overall clean refit mean 114 s (28 calls).

## Preliminary extrapolation (arithmetic on the log, not a result)
Proposed stage 0: 60 cells x 2,500 datasets, one refit call per dataset per effect.
- One effect per refit call: 60 x 2,500 x ~114 s ~ 1.7e7 s ~ 198 core-days; ~11 days on 18 ideal cores.
- If NIE, NDE and TE each need their own refit call: ~3x that (~590 core-days; ~33 days on 18 ideal cores).
  Whether refits can be shared across effects is a design question the pilot does not answer.
- Draw calls add ~5e5 s total, negligible.
- Real multi-core scaling (BLAS threading, memory) was not measured. Eleven later variants multiply this.

## Corrections after independent QA (2026-11-07)
- The log labels the sleep-suspended call (cell 10, dataset 2, nonparametric, seed 9101002, 4,632.86 s) `ok`;
  it is **contaminated**, so 85 units are valid, not 86. The log has no contamination flag (the file is git-ignored);
  treat that row as invalid.
- Total elapsed was 7,941 s against the 7,200 s total cap (a 741 s overrun) and cell 10 exceeded its 15 min cap;
  both overruns come from the suspension, since a suspended process cannot be killed on time.
- Pilot used R 4.6.2 and source `3826c9ac`; Hopper will use R 4.4.0 and another commit, so cluster timings are unmeasured.
- Cost is the draw-call mean 3.63 s (range 3.48-3.82 s); the QA-checked totals (198 and 593 core-days) are correct arithmetic.

## Disposition
By the plan's gate, an unaffordable or unexpected pilot stops here: any redesign needs review and
separate authorization, and the 2 h pilot cap was not cleanly honored (suspended by sleep). Decisions
for the maintainer are in the session summary.
