# Plan: bound the status -4 restoration and propagate "unresolved" (2026-10-23)

> **W1 is superseded** by `planning/specs/IMPL-restoration-bound-2026-10-23.md` (the allowance is `|g'delta| + 0.5|delta'H_L delta|` with `delta = -M^+ c`, no multipliers). Everything else here (G1-G11, the caller table, W2-W6) stands; the implementation plan holds the numerical solution, the harness and the task list.

Source: Codex adversarial review of `v0.11.1..dev` (1 high finding), then a Codex review of the first version of this
plan (verdict REVISE; 7 findings). Grill answers (author, 2026-10-23) are fixed below. Nothing is implemented.

## The defect

`.sem_polish_accept()` (`R/sem-constraints.R:539-552`) sets `slack <- if (restore) Inf else .sem_polish_f_slack`.
A status -4 restoration (called from `R/sem-optim.R:~424` with `restore = !gate$accepted`) is therefore accepted
whenever the gate (feasibility, stationarity, curvature) passes, whatever the objective rise. Several starts that
restore into the same inferior basin then agree without a warning, and the LR comes out inflated.
Exposure on real data is unmeasured; no wrong accepted fit has been reproduced yet.

## Decisions (author, 2026-10-23)

| # | Decision |
|---|---|
| G1 | Evidence = both layers: a mocked planted-defect test and seeded real fits on the #276 floor fixtures (on the CI runner, OpenBLAS). Add a real bound only if real fits reach the hole; otherwise a cheap safeguard. |
| G2 | A restoration over the bound is rejected: the original rejected -4 result stays, that start is unresolved. |
| G3 | The bound is multiplier-based (`k * abs(lambda) * violation + 1e-8`). **Codex found this underspecified; W1 defines it before any code.** |
| G4 | `mbco_sem()` and `compare_lr()` return an explicit unresolved result instead of a hard error. |
| G5 | Release: next planned release, GitHub-only, no patch release, no CRAN (#83). |
| G6 | Out of scope: gate redesign, the normal polish slack (1e-8), the older 9-finding plan (W3-W6 of `PLAN-engine-adversarial-review-2026-10-20.md`), edits to other repos. |
| G7 | A dropped zero-product branch with a surviving branch: return the lowest survivor with `incomplete = TRUE` and a warning; `mbco_sem()`/`compare_lr()` read the flag and treat the LR as unresolved (not a hard error, not silent). The flag lives in `@internals` (a documented field, no new `SEMFit` property, so no class, validator, refcard or S4-registration change); W5 adds the field in `.sem_fit_branches()`'s return and the readers in `mbco_sem()`/`compare_lr()`, with a test that fails if the flag is dropped on the way into the object. |
| G8 | If W2 shows legitimate and bad restorations overlap (no `k` separates them): fall back to an incumbent check (restored objective vs the best accepted start, or the unconstrained fit, within a tolerance; no incumbent = fail closed), not a looser `k`. |
| G9 | The `mbco_sem()` error-to-result change ships under the CLAUDE.md correctness-fix exemption: next minor release, NEWS behavior-change note, no deprecation period, after a read-only check of RMediation and probmed usage of `mbco_sem()`. |
| G10 | The planted test defines "materially worse" as an objective rise of at least `max(1e-3 * abs(f), 1e3 * roundoff)` of the restored fit's discrepancy (set independently of the W1 formula, so a mis-scaled allowance cannot make the plant pass; revisit the constants with the W2 data), and the test asserts separately that the rise exceeds the W1 allowance and exceeds roundoff, so old code passes only through the `Inf` slack and new code fails only through the bound. |
| G11 | W2 runs on the CI runner (OpenBLAS, where #276 failed) and locally, to see whether restoration data differs by BLAS. **Correction (T3, 2026-10-23): local R links Homebrew OpenBLAS 0.3.34, not reference BLAS**; the two runs are two OpenBLAS builds. A reference-BLAS point needs the #274 container. |
| G12 | **Open.** `k` for the allowance: 10 (S6 rule as written; margin 1.7x to the nearest known inferior-basin gap) or 4 (margin 4x above the largest legitimate rho, 4.2x to the gap, S6 margin relaxed with the structural argument). See IMPL section 6. |

## Findings from the plan review, and how the plan answers them

| Codex | Answer |
|---|---|
| 1 Critical: bound undefined for several, dependent or rescaled rows | W1 defines it row-wise and scale-paired (below). |
| 2 Critical: `k = 2` is a heuristic, reach is 1 natural unit | W2 calibrates `k` from recorded restoration paths; wide restorations get a separate rule, decided from W2 data. |
| 3 High: "unresolved" differs per caller | W3 specifies it per caller (table below). |
| 4 High: planted test can pass for the wrong reason | W4 uses the real gate and a before/after pair on the same replacement point. |
| 5 Medium: clean real fits prove little | W2 logs per-attempt data; the report states what a clean run does not prove. |
| 6 Medium: success criterion is circular | Independent evidence: a denser start search or a reparameterized oracle. |
| 7 Medium: no caller-level tests | W4 adds them. |

## Work packages (order matters; one PR for W1-W4, one for W5 only if separate review helps)

**W1. Define the quantity (no code).** Write down, in this file's appendix:
- Row set: every active equality and inequality row at the stalled point. The existing multiplier solve (`R/sem-constraints.R:~665`) stacks the bound rows into the same system, so a bound-active coordinate soaks up part of the gradient. Either solve the multipliers again without the bound rows, or include the bound rows in the sum with their own distances; do not take multipliers from the joint solve and sum over constraint rows only.
- Residual: the row's unit-length distance `|cval| / ||a*u||` (`R/sem-constraints.R:356-370`), paired with the
  multiplier for that same normalized row, so rescaling a constraint cannot change the bound.
- Allowance: `sum_i |lambda_i| * dist_i`, evaluated at the stalled point; `k` a calibrated safety factor.
- Dependent rows: the minimum-norm multipliers (`R/sem-constraints.R:674`) are non-unique, so use the total
  `sum |lambda_i| * dist_i` only if it is invariant to the allocation; otherwise fail closed.
- Multiplier unavailable or rank-deficient: the restoration is rejected (fail closed), never accepted by default.

**W2. Instrument, read-only.** A script under `tests/sim/` runs the #276 floor fixtures
(`var-1e6-1e-6`, `qhat+0.2`, plus the grid) and logs per restoration attempt: status, accepted flag, objective
before/after, rise, `dist` per row, multipliers at both endpoints, restoration distance, active rows, chosen start,
`optimum$status`, spread. The quantities exist only as locals inside `.sem_polish_accept()` (`R/sem-optim.R:430-432` keeps just `gate$f` and `gate$theta`), so the script wraps that function with `trace()` (or `testthat::local_mocked_bindings`) to record them; the wrapper adds no behavior and no package code changes. Run on the CI runner (OpenBLAS). Outputs: the distribution of rise versus the W1
allowance, and whether any accepted restoration rose far beyond it. Calibrate `k` and decide whether wide
restorations (distance near 1) need a separate rule. Independent check: rerun suspicious fits with a denser start
search; a lower objective there proves a wrong accept.

**W3. Specify unresolved per caller.**

| Caller | Today | After |
|---|---|---|
| `.sem_optim` best-of-starts (`R/sem-optim.R:436-502`) | rejected start excluded; one accepted start warns | unchanged; a restoration rejected by the bound counts as rejected, and the existing spread warning still fires |
| plain `fit_sem()` / `fit_mediation(engine = "native")` when every start's restoration is now rejected (`R/sem-optim.R:462`) | accepted today through the `Inf` slack | stops with "no start converged" (or the existing message); a user-visible change named in NEWS. W2 counts how many fixture fits depend on a restoration whose rise exceeds the allowance |
| `.sem_fit_branches()` (`R/sem-fit.R:240-263`) | a failed branch is dropped silently unless all fail | record dropped branches; the result carries an `incomplete` flag and a warning, because a minimum over surviving branches can look valid |
| `mbco_sem()` (`R/sem-mbco.R:152`) | any failed refit stops with an error | the row gets `converged = FALSE`, `diff_ll = NA`, and the failure text in a column; no `stop()`. With any unresolved row the **statistic, p-value and reference `lr` are `NA`** (never `min(diff_ll, na.rm = TRUE)`: that is the min-over-survivors answer G7 forbids). `converged = TRUE` is no longer hardcoded (`R/sem-mbco.R:181`); update the doc at `R/sem-mbco.R:45`; `.mbco_warn_boundary()` must skip a failed refit. `.lr_reference()` (`R/compare-lr.R:183`) carries `lr = NA` with `accepted = FALSE`, and the comparison statuses that test `lr` must treat `NA` as `unresolved`, not raise an `NA` condition |
| `compare_lr()` `.lr_reference()` (`R/compare-lr.R:180`) | calls `mbco_sem()`, so a refit failure is an error | `accepted = FALSE` flows to the existing `"unresolved"` verdict (`R/compare-lr.R:63-67`); neither side is blamed |

`tests$converged` already exists and `.lr_reference()` already reads it, so the schema needs no new column except
the failure text. The old error message ("the null may lie outside the parameter space") moves into that text.
**This changes `mbco_sem()` from error to result: NEWS entry, and check dependents' use first (RMediation, probmed).**

**W4. Tests (before code).**
- Planted unit test with the **real** `.sem_gate()`: construct a replacement that passes the gate but has a
  materially worse objective; assert old behavior accepts it only because of `Inf`, new behavior rejects it only
  because of the allowance. Guard against the case where the plant fails the gate and duplicates
  `tests/testthat/test-sem-polish.R:139`.
- Planted cases: one equality under row rescaling (bound unchanged), two independent active rows, dependent rows,
  nonlinear inequality plus equality, multipliers unavailable, a legitimate restoration just below and just above
  the boundary (the existing test only covers a 0.05-unit stall, `test-sem-polish.R:112`).
- Caller-level: best-of-starts selection and spread, `.sem_fit_branches()` incomplete flag, `mbco_sem()` returns
  an unresolved row, `compare_lr()` returns `"unresolved"`, one nested `anova()` comparison whose LR must not change.

**W5. Implement.** The allowance in `.sem_polish_accept()` (restore path only), the `mbco_sem()` and
`.sem_fit_branches()` changes, NEWS, `?mbco_sem` and `?compare_lr` wording.

**W6. Verify.** Targeted floor and likelihood gates first (the 144/144 floor gate must still pass), then the full
suite in the worktree (`pre-pr-testing.md`: code change = full suite, counts in the PR body). Rerun W2 after the
change and diff per-attempt data; an aggregate 144/144 alone can hide a changed rejection masked by another start.

## What a clean W2 run does not prove

Only that no accepted result changed for those seeds, fixtures, runner image and BLAS. It does not show the hole is
unreachable elsewhere, that `k` is safe, scale invariance, validity for several active rows, validity near reach 1,
or equivalence on other platforms. The PR body must say so.

## Risks

- A bound that is too tight rejects restorations #276 needed (the `var-1e6-1e-6` wrong-branch fits). W2 data and
  the floor gate guard this.
- Turning `mbco_sem()` errors into rows changes behavior for callers that relied on `stop()`; the correctness-fix
  exemption in CLAUDE.md applies (ship with NEWS note and a minor bump), but dependents must be checked first.
- Fail-closed on missing multipliers may reject fits that pass today; W2 counts how many.

## Execution notes

- Branch `fix/restoration-bound` off `origin/dev`; worktree optional for W1-W2 (read-only), recommended for W5.
- Codex may review W5's diff (`adversarial-review --base dev`) before the PR; Codex cannot write outside its session roots.
- Do not merge without asking; CI green first.
