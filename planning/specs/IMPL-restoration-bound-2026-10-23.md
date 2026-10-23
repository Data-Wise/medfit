# Implementation plan: bound the status -4 restoration (2026-10-23)

Design, decisions G1-G11 and the per-caller table: `tasks/PLAN-restoration-bound-2026-10-23.md` (not restated here).
This file is the build plan: the numerical solution, the technical solution, the verification harness and the
ordered tasks. **It supersedes that file's W1** (the `sum |lambda_i| * dist_i` allowance): the allowance below
needs no multipliers and is invariant to row scaling and dependent rows. Nothing is implemented yet.

Reviewed inputs: Codex adversarial review of `v0.11.1..dev` (finding: `slack <- if (restore) Inf`,
`R/sem-constraints.R:546`), Codex review of the design plan (7 findings), an `agent-skills` review of the plan (6
findings, folded), and an advisor pass on this file's numerical core.

---

## 1. Numerical solution

### 1.1 Setting and notation (natural units, as `.sem_polish` works)

At a rejected status -4 stall `x_s` (the point `.sem_polish_accept(restore = TRUE)` starts from):

- `u`   = `.sem_step_floor()`, the natural unit of each coordinate; `ax = rows %*% diag(u)`.
- `M`   = `act$ax[act$active_row, free, drop = FALSE]`: Jacobian of the active rows in natural units, **free
  coordinates only** (bound-active coordinates are held, exactly as `.sem_polish`'s `kkt()` does).
- `c_s` = `act$cval[act$active_row]`: the rows' values at `x_s` (the violation). Active inequality rows enter as
  equalities, the same convention `kkt()` uses.
- `g`   = `r$g * u` (gradient of the discrepancy `f`, natural units) and `H_L` = `.sem_lagrangian_hessian(...)`
  restricted to the free block (the Hessian of the objective plus `lambda_i * curvature(c_i)`).

`f` is the per-observation discrepancy (`fit@f`; the LR statistic is `n_obs * (f - f_ref)`), so the allowance and the
rise below are in `f` units and are compared with `r$f - res$objective`, the quantity `.sem_polish_accept` already
computes.

### 1.2 The allowance

The minimum-norm step onto the linearized rows is `delta = -M^+ c_s` (`M^+` the pseudo-inverse via SVD with the
rank cutoff `d > 1e-8 * max(d)`, the same cutoff the sign-check multiplier solve uses,
`R/sem-constraints.R:~677`). The quadratic model's rise along it is `g'delta + 0.5 delta' H_L delta`. Define

    allow = |g' delta| + 0.5 * |delta' H_L delta|          (absolute values: a conservative envelope)
    reject the restoration unless   r$f - res$objective  <=  k * allow + 1e-8

`k` is `.sem_restore_k`; `1e-8` is `.sem_restore_floor` (the ordinary polish slack `.sem_polish_f_slack`, so a
restoration that needs no move is not held to a stricter standard than an ordinary polish).

### 1.3 Why this form

1. **It is G3's "multiplier x violation", made exact.** With least-squares multipliers `lambda = -(M^+)' g`,
   `lambda' c_s = -g' M^+ c_s = g' delta`. So `|g' delta|` is `|lambda' c_s|`, the first-order cost of restoring
   feasibility, with no multipliers computed (at a rejected stall the sign check never runs, so none exist).
2. **It is an upper bound for what the restoration's own Newton step can cost.** `.sem_polish` takes the step
   `d*` that minimizes the model `g'd + 0.5 d' H_L d` subject to `M d = -c_s`. `delta` is feasible for that same
   problem, so the optimal model value at `d*` is at most the value at `delta`. A restoration cannot, to second order,
   cost more than `allow`; `k` pays for the cubic terms, the nonlinear rows' linearization error and the up-to-8
   Newton iterations.
3. **Invariances (each is a planted test, section 3.4).** Rescale row `i` by `s`: `M_i -> s M_i`, `c_i -> s c_i`, so
   `M^+ c` is unchanged. Duplicate or linearly dependent rows: the pseudo-inverse returns the same `delta` as the
   independent subset; no multiplier allocation exists to be representation-dependent. A different coordinate unit:
   `u` is already folded into `ax`, `g` and `H_L`, so `allow` is in `f` units.
4. **Bound-active coordinates are excluded by construction** (free columns only), which removes the design plan's
   open question of joint bound/constraint multipliers.

### 1.4 Edge cases and the fail-closed rule

| Situation | Behavior |
|---|---|
| No active row (`nrow(M) == 0`) | `allow = NA`: restoration rejected (there is nothing to restore onto). |
| `M` rank zero after the cutoff | `NA`: rejected. |
| Non-finite `M`, `c_s`, `g` or `H_L`; `.sem_eval()` returns `NULL` | `NA`: rejected. |
| `c_s` not in the range of `M` (rows inconsistent) | `delta` is the least-squares step; the gate rejects the point anyway. Not special-cased. |
| `allow = 0` (stall already on the rows) | the test reduces to `rise <= 1e-8`. |
| Restoration lowers `f` | always accepted by this check (rise is negative). |
| Active inequality with `cval` inside the window but satisfied | treated as an equality, as `kkt()` does; slightly conservative. |

`NA` never means accept. A rejected restoration returns the original `res` and `gate` unchanged (the existing
return path), so the start stays rejected and the design plan's caller semantics apply.

### 1.5 Calibrating `k` (one-sided, falsifiable)

Define the ratio `rho = rise / allow` per restoration attempt.

- **Lower bound (data).** `k >= 10 * max(rho)` over **legitimate** restorations. "Legitimate" is labeled by an
  independent oracle, never by the gate: the restored objective matches `tests/sim/oracle213.R` at the achieved `q`
  within `1e-6 * max(1, LR)`, and the floored oracle for `var-1e6-1e-6`. This is the repo's S6 rule (the threshold
  sits at least 10x above the largest accepted value, `gates.csv` row `stationarity`).
- **Upper bound (basin gap).** `k * allow` must stay below the smallest objective gap between the best optimum and an
  inferior basin observed on the fixtures, else the bound could pass a basin jump. (T3 corrected the first draft of
  this criterion, a fixed `1e-3 * max(1, f)` materiality line: legitimate restorations from stalls 0.1 natural units
  short of the row cost up to 1.5e-2 in `f`, well above that line, because the cost is proportional to the violation.
  The bound is proportional too, so the comparison that matters is with the gap between basins.) The planted bad
  cases are built at `rho >= 100 * k`, so they are caught by construction; this half is a measurement on real
  inferior-basin stalls.
- **If the interval is empty** (`10 * max(rho_legit) * allow > materiality` somewhere) the rise bound cannot
  separate the cases and G8 applies: an incumbent check (restored `f` against the best accepted start or the
  unconstrained fit within a tolerance; no incumbent fails closed).
- `k` is a constant in `R/sem-constraints.R` (`.sem_restore_k`), mirrored in `gates.csv` (section 3.5). T3 results
  (section 6) put the decision between 4 and 10. **Decided 2026-10-23 (G12): `k = 4`, margin 3.** The S6 margin of 10 is relaxed to 3 because `rho` is a structural ratio (the rise cannot exceed the quadratic-model value except by cubic terms and extra Newton steps), measured 0.9948 to 0.9998 on two OpenBLAS builds, not a noisy measurement; `k = 4` keeps `k / margin = 1.33`, a 33% allowance above the largest observed `rho`, and 4.2x below the nearest known inferior-basin gap. Recorded in `tests/sim/gates.csv` (`tol_est = 4`, `tol_se = 3`).

### 1.6 What this bound does and does not catch (state in the PR body)

It catches a restoration whose objective **rises** by more than the violation explains: a path that jumps basins
(reach up to one natural unit permits it) or lands on a worse point after a long flat-direction step. It does **not**
catch a stall that already sits in an inferior basin: restoring from there costs a small, explained rise and returns
a feasible, stationary but non-global point. That case belongs to the existing machinery (best-of-starts, the
dominance rule of #213 `R/sem-optim.R:~441`, the spread warning) and to G8's incumbent check. The plan does not claim
otherwise, and the evidence run (T3) reports how many accepted restorations are of each kind.

### 1.7 Numerical pitfalls (from this repo's own notes)

- Linux (OpenBLAS) and macOS (reference BLAS) differ at about 1e-9: every frozen expectation uses a 1e-6 tolerance;
  check bit identity locally only as an extra, never as the pass rule.
- SLSQP stops about 3e-5 short along flat tangents; a restoration test point must not assume a tighter stall.
- Do not edit `R/` while a background Rscript run is reading it (Rscript reads source files incrementally).
- Smoke-run CSVs become the newest baseline for `run-gates.R`; delete them.

---

## 2. Technical solution

### 2.1 Code (all in `R/sem-constraints.R` unless stated)

```r
# Restoration bound (#276 follow-up). Constants next to .sem_restore_reach.
.sem_restore_k <- 4          # calibrated in T3, mirrored in tests/sim/gates.csv
.sem_restore_floor <- 1e-8

.sem_restore_allowance <- function(theta, ram, smp, lb, ub, cons) {
  act <- .sem_active_set(theta, ram, smp, lb, ub, cons)
  r <- .sem_eval(theta, ram, smp, deriv = TRUE)
  free <- act$free
  m <- act$ax[act$active_row, free, drop = FALSE]
  cval <- act$cval[act$active_row]
  if (is.null(r) || !nrow(m)) {
    return(NA_real_)
  }
  hx <- .sem_hess_f(theta, ram, smp) * outer(act$u, act$u)
  gx <- r$g * act$u
  if (!all(is.finite(c(m, cval, hx, gx)))) {
    return(NA_real_)
  }
  sv <- svd(m)
  keep <- sv$d > 1e-8 * max(sv$d)
  if (!any(keep)) {
    return(NA_real_)
  }
  delta <- -drop(sv$v[, keep, drop = FALSE] %*% (crossprod(sv$u[, keep, drop = FALSE], cval) / sv$d[keep]))
  hl <- .sem_lagrangian_hessian(hx, gx, act, cons, theta)[free, free, drop = FALSE]
  abs(sum(gx[free] * delta)) + 0.5 * abs(drop(crossprod(delta, hl %*% delta)))
}
```

`.sem_polish_accept()` (`R/sem-constraints.R:539-552`) changes only in the restore branch:

```r
slack <- .sem_polish_f_slack
if (restore) {
  allow <- .sem_restore_allowance(res$solution, ram, smp, lb, ub, cons)
  if (is.na(allow)) return(list(res = res, gate = gate))            # fail closed
  slack <- .sem_restore_k * allow + .sem_restore_floor
}
...
gate$restore <- list(rise = r$f - res$objective, allow = allow, k = .sem_restore_k, accepted = <the result>)
```

The ordinary polish path (`restore = FALSE`) is untouched (G6). The `.sem_restore_reach` comment above
`.sem_polish_accept` is rewritten: the objective rise is now capped by `k * allow`, not left to the gate alone.

### 2.2 Diagnostics channel

~~`gate$restore` rides in `attempts[[i]] <- gate`~~ **Dropped:** no `gate$restore` field was added; the trace hook (below) reads everything from the entry arguments, so the package carries no diagnostics code for it.

**T1 decision (2026-10-23): `attempts` does not reach the returned fit.** `.sem_optim()` returns `attempts` in its
result list (`R/sem-optim.R:544`), but `.sem_as_semfit()` (`R/fit-sem.R:139-141`) keeps only `status, decrement, retries,
active_bounds, active_constraints, improper, sign_check, se_type, optimum` in `@diagnostics`; `optimum` holds the
start counts and spread, not per-attempt data. So per-attempt restoration data is read with a `trace()` hook on
`.sem_polish_accept` (entry tracer saves the original `res` and `gate`; exit reads `returnValue()`), as
`tests/sim/restoration-instrument.R` does. The gate script (T5) uses the same hook, so no new exported surface and no
change to `SEMFit`. Two traps found while building it: the profile gate reloads the package at its top
(`pkgload::load_all`), which discards a trace, so the instrument patches that line out of the evaluated copy; and
the tracer's exit expression runs in the function frame, where `res` is already the modified copy, hence the entry
tracer.

### 2.3 Callers (specified in the design plan's W3 table; build tasks here)

| Change | File | Notes |
|---|---|---|
| `mbco_sem()` returns an unresolved row instead of `stop()`; statistic, p-value, reference `lr` are `NA` when any row is unresolved; `converged` no longer hardcoded | `R/sem-mbco.R:~150-181`, doc at `:45` | `.mbco_warn_boundary()` skips a failed refit; keep the old failure text in a new `note` column |
| `.lr_reference()` carries `lr = NA`, `accepted = FALSE`; statuses that test `lr` treat `NA` as `unresolved` | `R/compare-lr.R:~180-200` | machinery for the verdict exists (`:63-67`) |
| `.sem_fit_branches()` records dropped branches and sets `incomplete` in `@internals` with a warning | `R/sem-fit.R:~240-273` | readers in `mbco_sem()` and `compare_lr()`; no new `SEMFit` property (no class/refcard/S4 change) |
| plain `fit_sem()` error when every start is rejected | `R/sem-optim.R:462` | message unchanged; NEWS names the case |

### 2.4 Docs

NEWS behavior-change entry (G9: correctness-fix exemption, minor bump; dependents RMediation and probmed checked
read-only first); `?mbco_sem` and `?compare_lr` unresolved wording; `?"medfit-syntax"` / the native model page only if
a message they quote changes (the repo has a test that triggers every quoted message); a short methods note in
`vignettes/articles/methods.qmd` giving section 1.2-1.3 (every formula lives there).

---

## 3. Verification harness

Conventions (from `tests/sim/run-gates.R` header): verdicts come from a gate's results CSV against `gates.csv`, never
from an exit status alone; `MUTANT=<name>` plants a defect and the gate must then exit 1; `--mutants` proves the driver
rejects "exits 0 but bad" results; results older than `--max-age` are stale. Any gate in `gates.csv` is picked up by
the `gates (rest)` shard automatically (`.github/workflows/gates.yaml:52`), which is required on `main`: keep the new
gate under a few minutes.

### 3.1 Exploratory run (T3, not a gate)

`tests/sim/restoration-instrument.R`: a read-only script that records every restoration attempt across the #276
fixtures (`var-1e6-1e-6`, `qhat+0.2`, the 24-fixture x 6-`q` grid of `sem-nonlinear-profile-gate.R`), on the CI runner
(OpenBLAS) and locally (macOS), G11. Per attempt: fixture, `q_tag`, status, gate accepted before/after, `f` before and
after, rise, `allow`, `rho`, `k * allow`, restoration distance (natural units), active rows, chosen start,
`optimum$status`, spread, and the oracle label. It is not registered in `gates.csv`.

### 3.2 The gate (T5): `tests/sim/sem-restoration-gate.R`

Writes `tests/sim/results/sem-restoration-gate-<date>.csv`. Two row families:

- **Observed rows** (from the same fixture grid, `FAST=1` shrinks it): one row per restoration attempt, with the
  oracle label. Checks: (a) no accepted restoration has an objective above the oracle by more than
  `1e-6 * max(1, LR)` (independent of the bound); (b) the separation interval of section 1.5 is non-empty
  (`10 * max(rho_legit) <= k`, `k * allow <= materiality`).
- **Planted rows** (deterministic, real `.sem_gate`, no gate mock): each plants a replacement point through a mocked
  `.sem_polish` only, so the real feasibility/stationarity/curvature gate still decides. Cases:
  1. **rescale**: one equality row multiplied by `s` in {1e-3, 1, 1e3}: `allow` unchanged to 1e-9 relative.
  2. **two rows**: two independent active rows: `allow` equals the hand value from `delta = -M^+ c`.
  3. **dependent rows**: a duplicated row: `allow` equals the independent subset's.
  4. **rank zero / non-finite**: `allow = NA`, the restoration is rejected (fail closed).
  5. **bad jump**: a feasible, stationary point with rise `>= 100 * k * allow` (and `>= max(1e-3 * abs(f), 1e3 *
     roundoff)`, G10): old code (`Inf` slack) accepts it, new code rejects it.
  6. **boundary pair**: a legitimate restoration at `rho = 0.9 k` accepted and one at `rho = 1.1 k` rejected.
  7. **curvature**: a case where the `0.5 delta' H_L delta` term decides the verdict (so `nocurv` is detectable).

### 3.3 Mutants (each must make the gate exit 1)

| `MUTANT=` | Defect | Caught by |
|---|---|---|
| `infslack` | restore slack back to `Inf` | planted bad jump (case 5) |
| `rawdist` | allowance from an unscaled row value | rescale invariance (case 1) |
| `nocurv` | drop the `0.5 delta' H_L delta` term | curvature case (7) |
| `nopinv` | solve with a plain inverse / no rank cutoff | dependent rows (case 3) |
| `nafailopen` | treat `NA` allowance as accept | rank-zero case (4) |
| `kx100` | `k` multiplied by 100 | bad jump (5) and the materiality half of the separation check |

### 3.4 Unit and caller tests (`tests/testthat/`)

- `test-sem-restore-bound.R`: `.sem_restore_allowance()` on the hand fixture of `test-sem-polish.R` (the 0.05-unit
  stall), the invariance cases above at unit scale, and the existing refusal case kept.
- Caller-level: best-of-starts selection and spread with a rejected restoration; `.sem_fit_branches()` sets and
  readers see `incomplete`; `mbco_sem()` returns `NA` statistic with an unresolved row; `compare_lr()` returns
  `"unresolved"` with `reference$accepted = FALSE`; one nested `anova()` whose LR must not change.
- Skips for Suggests (lavaan/OpenMx) follow the repo pattern.

### 3.5 Registration (T6)

- `tests/sim/gates.csv`: a `restoration` row: `expected_rows`, `min_pass`, `tol_est` = `k`, `tol_se` = materiality,
  source text with the baseline numbers and the separation margin.
- `tests/sim/run-gates.R`: the per-gate column list (near line 128), the pass-rule block (follow the
  `nonlinear-profile` block, `:378-403`), `--mutants` entries (four "exits 0 but bad" mutations plus a control), and a
  `--fast` check that `gates.csv` `tol_est` for `restoration` equals `.sem_restore_k` (pattern: `.sem_stat_tol`,
  `:743-765`), so the constant and the gate cannot drift apart.
- Required existing gates stay green: `nonlinear-profile` 144/144 (the #276 floor rows), `compare-lr`, `reliability`.

---

## 4. Tasks

Branch `fix/restoration-bound` off `origin/dev`; worktree optional for T0-T3 (read-only), recommended from T4. One PR
for T4-T8 (batching per the repo's PR-count convention); T0-T3 may land as a docs/sim PR first. Tier per
`pre-pr-testing.md`: code = full suite in the worktree, counts in the PR body; the gates dispatched on GitHub CI
(memory: use GitHub CI, not local, for the long runs).

| # | Task | Acceptance | Depends |
|---|---|---|---|
| T0 | **DONE 2026-10-23.** Verify the identity `lambda' c_s = g' delta` numerically | on one fixture, `abs(g'delta)` equals `abs(lambda' c_s)` from the sign-check solve to 1e-8 relative; record in the PR | - |
| T1 | **DONE 2026-10-23** (section 2.2). Decide the diagnostics channel | written note: `attempts` surfaced or not; if not, trace-wrapper design | - |
| T2 | **DONE 2026-10-23** (commit 7597fb9). Write `tests/sim/restoration-instrument.R` | runs locally on `FAST` fixtures; per-attempt CSV with every column of section 3.1; `NA` on early returns, no error | T1 |
| T3 | **DONE 2026-10-23** (section 6; `k` decision G12 open). Run T2 on the CI runner and locally; calibrate `k` | report: `rho_legit` max, materiality margin, count of restorations by kind (section 1.6), runner vs local difference; `k` chosen or G8 triggered | T2 |
| T4 | **DONE 2026-10-23.** Implement `.sem_restore_allowance()` and the slack change | unit tests of 3.4 pass; ordinary polish path byte-identical; `gate$restore` diagnostics present | T0, T3 |
| T5 | **DONE 2026-10-23.** Write `sem-restoration-gate.R` with planted rows and mutants | each mutant exits 1, the control exits 0, 1e-6 tolerances only | T4 |
| T6 | **DONE 2026-10-23.** Register the gate (3.5) | `run-gates.R --fast` and `--mutants` green; `gates (rest)` shard time still within budget | T5 |
| T7 | **DONE 2026-10-23** (section 8). Callers: `mbco_sem()`, `.lr_reference()`, `.sem_fit_branches()` flag | caller-level tests of 3.4 pass; dependents' `mbco_sem()` usage checked read-only | T4 |
| T8 | Docs: NEWS, `?mbco_sem`, `?compare_lr`, methods article section | doc-consistency tests pass; `devtools::document()` clean; US spelling | T7 |
| T9 | Verify: full suite in the worktree, dispatched gates, rerun T2 and diff per-attempt data | counts in the PR body; floor gate 144/144 on the runner; a changed rejection masked by another winning start is visible in the diff | T6, T8 |
| T10 | Codex adversarial review of the diff (`adversarial-review --base dev`) | findings triaged before the PR opens | T9 |

## 5. Risks and limits

- A `k` that is too tight rejects restorations #276 needed (`var-1e6-1e-6`). T3 data and the 144/144 floor gate guard it.
- The rise bound is blind to a stall that already sits in an inferior basin (section 1.6); it is one layer, not the
  whole defense. Say so in the PR body.
- A clean T3/T9 run shows only that nothing changed for those seeds, fixtures, runner image and BLAS: it does not show
  the hole is unreachable elsewhere, that `k` is safe in general, or equivalence on other platforms.
- `mbco_sem()` error-to-result is a behavior change (G9): NEWS note, dependents checked first.
- Fail-closed on missing multipliers is gone (no multipliers are used); fail-closed now means rank zero, no active row
  or non-finite inputs. T3 counts how many fixture fits hit those.
- Release: next planned release, GitHub-only, no CRAN (#83).

---

## 6. T3 results (2026-10-23)

Data: `tests/sim/results/restoration-instrument-local-macos-openblas0.3.34-2026-10-23.csv` (macOS, Homebrew OpenBLAS
0.3.34) and `restoration-instrument-ci-ubuntu-openblas0.3.26-2026-10-23.csv` (`ubuntu-latest`, run 39978758574,
Ubuntu OpenBLAS 0.3.26). Both are the full 24-fixture x 6-`q` grid of the profile gate through the instrument.

**T0 (identity).** On the `test-sem-polish.R` fixture with stalls of 0.01, 0.05, 0.3 and 1 natural units,
`g'delta` equals `lambda'c` from the sign-check multiplier solve to 1e-16 relative.

| | local | runner |
|---|---|---|
| restoration attempts | 14 | 14 |
| fixtures with any restoration | `var-1e6-1e-6` only | `var-1e6-1e-6` only |
| polished and kept by the unmodified code | 11 | 12 |
| polish returned nothing (rejected anyway) | 3 | 2 |
| kept restorations with rise > 1e-8 | 6 | 6 |
| `rho` range of those | 0.9963 to 0.9998 | 0.9948 to 0.9996 |
| max `|rise - allow| / allow` of those | 3.7e-3 | 5.2e-3 |
| kept restorations that lowered `f` | 5 | 6 |
| stalls in an inferior basin (`f` above the best by > 0.1) | 2 (smallest gap 1.454) | 2 (smallest gap 0.251) |
| max `10 * allow` over the kept rises | 0.150 | 0.149 |

Findings:

1. **No real fit reached the hole.** Every kept restoration has `rise <= allow` (above the 1e-8 floor; the single
   `rho = 1.15` row is a rise of 8.5e-12, far under the floor). Nothing the unmodified code accepted would be rejected
   by a bound of `k >= 1`. G1's real-fit layer therefore reports "hole not reached on these fixtures, this BLAS pair";
   the bound is a safeguard, not a fix for an observed wrong result (G1's cheap-safeguard branch).
2. **`rise` tracks `allow` to 0.5%.** A legitimate restoration costs essentially its first-order amount, so the
   bound is nearly tight at `k = 1`; the safety factor only pays for the cubic terms and the later Newton iterations.
3. **Restorations are rare and concentrated.** All 28 attempts are on the floor fixture (`var-1e6-1e-6`), 4 to 5 of
   the 6 `q` tags; no other fixture restores. The calibration set is 6 positive-rise points per platform on one
   fixture: thin. The seed and scale of that fixture are fixed by the gate, so more evidence needs a variant run (T3b).
4. **The two platforms differ in which starts stall where** (the runner's inferior-basin stall is 0.251 above the best,
   the local one 1.454; different restorations are logged), the known cross-platform spread of #238, but every kept
   restoration is legitimate on both.
5. **The premise "macOS is reference BLAS" in G11 is wrong.** This machine's R links Homebrew OpenBLAS 0.3.34; the
   runner links OpenBLAS 0.3.26. The two runs are two OpenBLAS builds, not reference versus OpenBLAS. A reference-BLAS
   data point needs the #274 container.
6. **Stalls in inferior basins exist** (two per platform; `f` 5.0 to 9.1 against 3.74 to 3.75) and the polish returned
   nothing for them: the restoration declined, so the rise bound never applied. This is section 1.6 observed.

**`k` (open decision G12).** The S6 rule (`k >= 10 * max rho`) gives `k = 10`. But `10 * allow` reaches 0.15 and the
smallest inferior-basin gap on the runner is 0.251, a margin of 1.7x, so `k = 10` leaves the bound close to useless
against a basin jump of that size. `rho` is a structural ratio (the rise cannot exceed the model value except by cubic
terms and extra iterations), observed within 0.5% of 1, not a noisy measurement, so S6's 10x margin is not obviously
the right one. Options: `k = 10` (S6 as written, margin 1.7x to the nearest known basin gap), or `k = 4`
(4x above the largest legitimate `rho`, margin 4.2x to the basin gap; needs the S6 margin relaxed with this
argument written into `gates.csv`).

**What this does not show.** Only that nothing the unmodified code accepted would be rejected on these 24 fixtures x 6
`q` values, two OpenBLAS builds and the one fixture that restores. It does not show the hole is unreachable elsewhere,
nor that `k = 4` or 10 is safe on other data.

---

## 7. T4-T6 as built (2026-10-23)

- **T4.** `.sem_restore_allowance()`, `.sem_restore_k = 4`, and the capped slack in `.sem_polish_accept()`
  (`R/sem-constraints.R`); an `NA` allowance refuses the restoration. The ordinary polish path is unchanged.
  `tests/testthat/test-sem-restore-bound.R`: 23 expectations (hand value on one and two rows, scale and duplicate-row
  invariance, rank zero and no active row give `NA` and a refused restoration, the boundary on either side of `rho / k`,
  the curvature term, a far-worse restoration refused with the gate mocked). Planted-defect check: with `k = Inf` the
  far-worse test fails.
- **T5.** `tests/sim/sem-restoration-gate.R` (12 rows: 8 planted, 4 observed) with the shared observation code in
  `tests/sim/restoration-common.R` (also used by the instrument). All six mutants exit 1 (`infslack`, `rawdist`,
  `nocurv`, `nopinv`, `nafailopen`, `kx100`); the control exits 0. Two defects found in the first draft of the gate
  itself: the planted far-worse size was derived from the package's `k`, so `kx100` scaled the plant up and passed
  (the circularity G10 warned about; the plant and the `k == gates.csv` check now use the gates.csv value), and
  evaluating the profile gate in the global environment overwrote the gate's own variables and made it read `MUTANT`
  (now evaluated in `rst_env` with `MUTANT` and `FAST` set explicitly).
- **T6.** `gates.csv` row `restoration` (12 rows, `tol_est` 4, `tol_se` 3); `run-gates.R`: column list, verdict rule
  (re-derives the hand-value tolerances, the far-worse ratio above 100, curvature, separation and basin gap from the
  recorded numbers), `mutate()` kinds (`tolerance`, `failed`, `missing`), the script map and the `--fast` tie of
  `tol_est` to `.sem_restore_k`. `run-gates.R --mutants --only restoration`: every mutation rejected, control passes.
- Local evidence: 947 expectations pass in the related test files (`NOT_CRAN=true`), `lintr::lint_package()` after
  `load_all()` reports 0 lints. The `--fast` tie check and the CI `gates (rest)` shard were not run locally.
- Not done: T7 (callers), T8 (docs, NEWS), T9 (full verification, dispatched gates), T10 (Codex diff review). The gate's
  planted far-worse case mocks the gate (a worse stationary point cannot be built on demand); the real gate is
  exercised by the legitimate restorations and the boundary rows.

---

## 8. T7 as built (2026-10-23)

- **`.sem_fit_branches()`** (`R/sem-fit.R`): a skipped zero-product branch while another wins sets `incomplete = TRUE`
  in the returned fit (stored in `@internals$incomplete`, added to the list in `.sem_as_semfit()`) and warns
  ("... branches did not converge (...); ... not certified"). A complete branch fit carries `incomplete = FALSE`; a
  fit with no branches has no such field (readers use `isTRUE()`). Every branch failing is still the old error.
- **`mbco_sem()`** (`R/sem-mbco.R`): a refit that cannot be fitted is a row (`converged = FALSE`, `f` and `diff_ll`
  `NA`, the failure text in a new `note` column), a warning repeats the text, and `statistic` and `p.value` are `NA`
  (never the minimum over the refits that worked). A new `unresolved` element says so. A fit that itself has
  `incomplete = TRUE` is unresolved the same way (all rows `converged = FALSE`). A complete result has `converged`
  TRUE, empty `note` and `unresolved = FALSE`. Behavior change: the refit error of a null the constraints rule out
  (`a > 0.3` with the null `a = 0`) is now an unresolved row with the same text in `note`; the existing test was
  updated and the roxygen text and `man/mbco_sem.Rd` regenerated.
- **Only an optimizer failure is unresolved.** The first version turned every refit error into a row, and four existing
  tests (`test-sem-factor-product.R`, `-defects.R`, `-refit.R`) failed: they rely on `mbco_sem()` stopping for a
  model or data error (the rule-9 refusal of a label constraint with products, a missing factor column). So the two
  optimizer failures ("no start converged", "no branch of the zero-product constraints converged") now raise the
  classed condition `medfit_error_no_convergence` (`.sem_no_convergence()` in `R/sem-optim.R`), and `mbco_sem()`
  turns exactly that class into a row; any other refit error keeps its old wrapped message and still stops. A test
  pins both sides.
- **`compare_lr()`** (`R/compare-lr.R`): `.lr_reference()` returns `lr = NA` and `accepted = FALSE` when any refit is
  unresolved, which `.lr_assess()` already turns into verdict `"unresolved"` for every run, blaming neither side. The
  end-to-end check runs lavaan against a failing medfit refit and gets an `"unresolved"` comparison, not an error.
- **`anova()`**: unchanged; a test pins its LR to the discrepancy difference.
- **Tests** (`tests/testthat/test-sem-unresolved.R`, 11 expectations groups): they were written first and failed for
  the right reasons against the old code (a dropped branch was silent, a failed refit stopped), then pass; the
  planted-defect case shows the minimum over the survivors would hide the failure.
- **Dependents (read-only, G9).** Only `missingmed` uses `mbco_sem()` (`R/mbco_sem.R:~430-460`). It already requires
  `nrow(tab) == 2`, `tab$converged %in% TRUE` and finite `tab$f`, and raises "Unresolved or incomplete a = 0 / b = 0
  refits" otherwise, and it collects warnings into the error text. The new rows (extra `note` column, extra
  `unresolved` element, a warning instead of a refit error) keep that path working: it still ends in an error, with the
  refit's own failure text now among the collected warnings. probmed, RMediation, medrobust, medsim and mediationverse
  do not mention `mbco_sem` or `compare_lr`. Not run against missingmed's tests (cross-repo).
- **Other effects.** `planning/specs/CRITERIA-native-experimental-exit-2026-10-17.csv` (row C2) now lists the
  `restoration` gate, because `test-experimental-criteria.R` requires every native gate in `gates.csv` to be named there.
  Full unit suite (`NOT_CRAN=true`, `testthat::test_dir`): 6781 passed, 1 failed; the one failure (`the dotted tidy()
  argument names still work and warn`, a `lifecycle::expect_deprecated` in `test-methods-tidy.R`) also fails on a clean
  `origin/dev` export under the same invocation (6714 passed, 1 failed) and passes when the file is run alone, so it is
  an artifact of that invocation, not of this branch. `lintr::lint_package()` after `load_all()`: 0 lints.

## 9. T8 as built (docs, 2026-10-23)

- `NEWS.md`: stale "no objective-rise limit" wording fixed; bullets for the cap (k = 4, ratio 0.995 to 0.9998, fail
  closed on NA), and a **Behavior change (correctness fix)** bullet for `mbco_sem()` / `.sem_fit_branches()` /
  `compare_lr()` unresolved results.
- `R/compare-lr.R` roxygen (`?compare_lr`): when medfit has no accepted reference; `man/compare_lr.Rd` regenerated.
- `vignettes/articles/methods.qmd`: restoration-cap derivation after the polish paragraph; MBCO paragraph on
  unresolved refits. `computation-algorithms.qmd`: polish paragraph points to the cap.
- `tests/testthat/test-restore-docs.R`: article k equals `.sem_restore_k` (planted k = 40 rejected), gates.csv k, NEWS
  phrases, help pages (skipped under `load_all()`).

## 10. T9 results (verification, 2026-10-23, HEAD e68cf07 + this commit)

- **Full suite (local, macOS, `devtools::test()`):** 6789 passed, 0 failed, 0 errors, 2 skipped, 1 warning.
- **`gates.yaml` dispatched on `fix/restoration-bound` (run 39993779320):** `gates (rest)` success (includes the
  `restoration` row), `gates (reliability)` success.
- **Instrument on the capped code (runner, ubuntu OpenBLAS 0.3.26, run 39993768454):** 14 attempts, 12 polished, all
  12 kept, 0 refused by the cap. Rows with a positive rise have rho = rise/allow in 0.9957 to 0.9996, far below
  k = 4; the other rows have a negative rise (the restoration improved the objective). Data:
  `tests/sim/results/restoration-instrument-ci-ubuntu-openblas0.3.26-capped-2026-10-23.csv`.
- **Versus the pre-cap runner file:** same 14-attempt size and the same family of stalls (8 of 12 polished rises
  match to 3 digits), but 4 stalls differ at the 1e-3 to 1e-2 level (1.99e-2 and 1.16e-2 here, against 1.49e-2 and
  8.59e-3 before) and the attempt order shifted. The cap refuses nothing here, so the cap does not explain the
  difference; the likely cause is the hardware of the runner that picked up the job (floating-point stall points move
  at 1e-9). Not proved. It does not change the conclusion: no restoration the old code kept is refused, on either run.
- Not covered: reference BLAS (needs the #274 container), other seeds and scales of the floor fixture (T3b).
