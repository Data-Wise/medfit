# PLAN: address the adversarial review of the native SEM engine docs

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Status** | **CLOSED 2026-10-08.** T1-T6 done. D-A decided (ledger K9). Closed by the author's decision after review round 5, without a sixth review (see the close-out below). |
| **Source** | Codex adversarial review of `origin/dev...HEAD` (2026-10-08, verdict needs-attention, 1 high, 3 medium, 1 low). Reviewed: [SPEC-sem-grammar-2026-10-08.md](SPEC-sem-grammar-2026-10-08.md) and [GRILL-native-sem-engine-medfit-2026-10-08.md](GRILL-native-sem-engine-medfit-2026-10-08.md). |
| **Branch** | `feature/native-sem-grill` (docs and evidence scripts only; no `R/` changes). |
| **Sizes** | XS 1 file, S 1-2 files, M 3-5 files. |

## Findings to tasks

| Finding | Severity | Task | Size | Needs author? |
|---|---|---|---|---|
| F1 allowlist does not lock the evaluation environment | high | T1 | S | no |
| F2 grammar leaves `lhs`, `expr`, `CONSTRAINT(...)` undefined | medium | T2 | S | no |
| F3 no failure contract for nonlinear constraints | medium | T3 | M | **yes: D-A** |
| F4 observed-information rule rests on one model | medium | T4 | S | no |
| F5 speed/optimizer claims not reproducible or broad | low | T5 | M | no |
| Close-out | | T6 | XS | no |

## Order

T1 and T2 first (same file, one commit), then T4 (wording only, ledger), then T3 after the author answers D-A, then T5, then T6. T1 and T2 are blockers for P1 (the parser); T3 blocks N3 and N7; T4 is a gate rule for N5; T5 is evidence hygiene and blocks nothing.

## T1: lock the evaluator boundary (F1)

**Why the review is right:** K2b checks names with `all.names()` but says nothing about what the names resolve to. A caller who rebinds `exp` (or `min`) in the calling environment passes the check and runs their function.

**Do:**
1. Reproduce the hole first: a planted caller-side `exp <- function(x) { side_effect(); base::exp(x) }` must pass an `all.names()`-only implementation. This is the positive control.
2. Spec section 4.2a "Evaluation environment": evaluate in `new.env(parent = emptyenv())`; bind each allowed function to its `base` or `stats` object explicitly (not by lookup); bind labels to numeric values only; never evaluate in or inherit from the caller, global, or package environment.
3. Validate the parsed call tree **before** evaluation, not just names: allowed node types are numeric literals, label symbols, calls to allowlisted functions, and `(`; reject strings, `::`, `:::`, `$`, `@`, `[`, `[[`, `<-`, `=`, `function`, formulas, `if`, backtick-quoted names, and any call whose head is not a bare allowlisted symbol.
4. Tests in the spec's section 8: caller-rebound `exp`; `base::system`; `get("system")`; `do.call`; `Recall`; a string literal; `(function() 1)()`. Each rejected with the first offending construct named; the rebound-`exp` case must pass the planted-defect check (red against the old design).

**Done when:** spec section 4.2 and section 8 contain the above; the ledger's K2b row points to section 4.2a.

## T2: complete the grammar (F2)

**Do:**
1. Define every nonterminal: `lhs` (a name, or a comma-separated name list under the extension), `expr`, `call`, `number`, `name`, and the directive.
2. `expr`: arithmetic subset of R with **R's own precedence and associativity** (`^` right-associative and above unary minus, so `-2^2` is `-4`; then `* /`; then `+ -`). State that the oracle for expression parsing is `parse(text = )` restricted to the T1 node types, so two implementations cannot disagree.
3. `call := name "(" [ expr { "," expr } ] ")"`, arity checked against the allowlist entry (for example `min`/`max` at least 1, `exp` exactly 1).
4. `CONSTRAINT(` delimiter rules: one balanced parenthesis pair, exactly one comparison operator at depth 0, no nesting, no trailing text, case-sensitive keyword.
5. A table of rejection cases with the pinned error text for each.

**Done when:** a reader can write the parser from the spec alone; a "two conforming parsers disagree" review question has no answer in the text.

## T3: nonlinear-constraint contract (F3)

**Decision D-A (author):** what the engine does with a nonlinear constraint. **Recommended default: allow, warn once ("solution may depend on starting values"), multi-start.** Alternatives: reject and point to the separate `a == 0` / `b == 0` solves (N7); allow silently (today's draft).

**Do, under the recommended default:**
1. Classify each constraint at parse time as linear (affine in the labels) or nonlinear. Method: the K3 central-difference Jacobian at three random points; affine if the Jacobian agrees to a stated tolerance.
2. Linear equalities and inequalities: supported, one solve, no warning.
3. Nonlinear equalities and inequalities: supported with a one-time warning, `n_starts = 5` perturbed starts (including the user's), best feasible objective kept, and the result reports which start won and the spread of objectives across starts.
4. Feasibility gate: a solution with any equality residual above `1e-6` is not accepted; the fit reports non-convergence naming the constraint.
5. Pattern note: `a*b == 0` gets a message pointing to the separate-solves route (N7), since the ledger measured SLSQP reaching the better solution from 6 of 10 starts.
6. Tests: planted `a*b == 0` from the stalled start (0, 0) recovers the better solution via multi-start; an infeasible constraint set errors; a linear constraint gives no warning.

**Done when:** spec section 4.2 states the classes and diagnostics; ledger records K9 for D-A.

## T4: make the observed-information rule provisional (F4)

**Do:**
1. Ledger and spec: mark J9's "observed by default" as **provisional until the N5 gate passes**; if the gate fails the default reverts to expected until resolved.
2. Define the N5 SE gate: at least 5 model structures (observed path, latent mediator, parallel, serial, one constrained), n in {50, 200, 1000}, at least 20 seeds each, against OpenMx with the `S * n/(n - 1)` convention; pass criterion: max relative SE difference below 1e-3 for observed information in every cell, with improper-solution cells reported separately, not dropped.
3. Keep `p0.R`/`p0b.R` as the seed of that gate (T5 moves them into the repo).

**Done when:** the P0 facts section says "one model, one seed, provisional" and points to the gate definition.

## T5: reproducible, broader evidence (F5)

**Do:**
1. Copy the scripts from the session scratchpad into `planning/specs/evidence/native-sem-2026-10-08/`: `ram.R`, `bench.R`, `cons.R`, `speed.R`, `speed2.R`, `p0.R`, `p0b.R`, `probe.R`. Make each self-contained (no scratchpad paths or environment variables) and add a README with package versions (R 4.6.1, nloptr 2.2.1, alabama 2025.1.0, ucminf 1.2.3, OpenMx 2.22.11, lavaan 0.7-2 and 0.7-3), commands, seeds, and expected numbers.
2. Broaden the grid before keeping the ranking claim: add two model shapes (three-variable observed with covariates; parallel two-mediator), random-start grid for the unconstrained solvers, and n in {50, 200, 1000}.
3. Reword the ledger's research table to the fixture it supports until the broader run is done: "on this fixture" for every timing and ranking.

**Done when:** a fresh checkout reproduces the ledger's numbers from the README; the ledger's claims name their fixture.

## T6: close-out

1. Re-run `/codex:adversarial-review --base origin/dev` with the same focus text.
2. Accept when no finding is high and every medium is either fixed or recorded as a decision with its reason.
3. Commit in two commits: spec (T1, T2, T3) and ledger plus evidence (T4, T5).

## Time

About 90 minutes of drafting for T1, T2, T4 (30 min), T3 (30 min after D-A), T5 (40 min including the broader runs), T6 (10 min).

## Parked, not part of this plan

The earlier Codex finding on `R/extract-joint.R:162-167` (row names do not prove shared subjects) concerns code already on `dev` (PR #76). It is unverified and belongs in its own issue and fix, not on this docs branch.

## T6 close-out (2026-10-08)

**Acceptance rule:** no high finding, and every medium fixed or recorded as a decision with its reason.

| Review round | Findings | Disposition | Commit |
|---|---|---|---|
| 1 (grammar spec and ledger) | 1 high, 3 medium, 1 low | all fixed (T1-T5) | `c134b3d`, `4d4e116`, `7a888cb`, `cd7a0eb` |
| 2 | 4 medium (`fname` and literals, linearity check, spread blind spot, runner) | all fixed | `7d23e69` |
| 3 | 1 medium (start validity must be positive definiteness) | fixed | `63e5a7b` |
| 4 | 2 medium (optimizer termination and KKT, result-domain guard) | both fixed | `b0e61a3` |
| 5 | 1 medium (inequality KKT multiplier signs) | fixed | `73c322a` |

**No high finding after round 1.** Every medium raised in rounds 1-5 is fixed, with a prototype run behind each fix and the outputs saved in `evidence/native-sem-2026-10-08/results/`.

**What is not confirmed:** the round 5 fix (`73c322a`) has **not** been re-reviewed; the author closed T6 instead of running a sixth review. Each round found a smaller issue in the text added the round before, so a sixth review may find another.

**Known gaps recorded in the spec rather than fixed (carried to the implementation plan):**
- Several simultaneous active inequalities and degenerate active sets: checked only on random NNLS problems, not on a fitted model (spec 4.5c, "Not covered").
- The KKT threshold `1e-3` is provisional, calibrated on two problems; re-check in N3 (spec 4.5c).
- The N5 SE tolerance `1e-3` is a proposal, calibrated on the first gate run (ledger K10).
- The optimizer reliability claim rests on 30 datasets per cell, and a mismatch is not split into "solver stalled" versus "lavaan on another local solution" (ledger research table).
- J6 (L-BFGS for unconstrained fits) was the least reliable solver from random starts: 93.3% against 100% for nlminb and 98.5% for SLSQP. Flagged for the author, not changed.
- The first Codex finding on `R/extract-joint.R:162-167` (row names do not prove shared subjects) concerns code already on `dev` (PR #76), is unverified, and is not part of this branch.

**Whole-spec approval:** given by the author on 2026-10-08; the grammar spec's status line now says APPROVED.

**Still needs the author:** the release assignment for Ext D versus native (both may claim 0.6.0).
