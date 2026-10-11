# SPEC: fixes to the native SEM implementation plan, from three reviews

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | **APPROVED 2026-10-09** by the author ("go with your recommendations": all eight open questions resolved as recommended, see the end). Todos: [PLAN-sem-plan-fixes-2026-10-09.md](PLAN-sem-plan-fixes-2026-10-09.md). |
| **Target** | [PLAN-native-sem-implementation-2026-10-09.md](PLAN-native-sem-implementation-2026-10-09.md), merged as #104 (`352ecfc`) |
| **Sources** | (1) code review of the plan and ledger, 10 findings, already fixed in #104; (2) S1 independent review of `73c322a`, 9 findings; (3) ecosystem and expansion review, 9 findings plus verdicts; (4) issue #105 (probmed compatibility gate) |
| **Evidence** | Agent scripts and outputs in the session scratchpad: `s1-review/` (t1-t15) and `eco-review/` (probmed_lavaan.out, dots.R). The claims marked **[V]** were re-checked by the session; the rest are the reviewers' unverified results. |

## Capability map (Phase 0 of the skill)

The request bundles three independently shippable pieces, so they get module ids and a build order before the module sections below.

| Module id | Responsibility | Depends on |
|---|---|---|
| `plan-fixes` | Edit the plan and ledger text for every finding (F1-F22 below). Docs only. | none |
| `lavaan-probmed-names` | Fix the existing bug: `@estimates`/`@vcov` of lavaan-derived `MediationData` lack the `m_<X>`, `y_<M>`, `y_<X>` names that probmed's parametric bootstrap looks up. Code and tests in `R/extract-lavaan.R`. Independent of SEM work. | none (informs plan task S17b) |
| `spec-errata` | Draft errata for the frozen grammar spec section 4.5c (scale-free stationarity, bound rows). Merged only on the author's say-so. | `plan-fixes` (carries the evidence) |

Build order: `plan-fixes` and `lavaan-probmed-names` in parallel, then `spec-errata`.

## Assumptions

1. The three reports are inputs to be checked, not facts. Four claims were verified in-session **[V]**: the probmed parametric-bootstrap failure on lavaan objects, the `model =` capture, the extra `lavaan::` call sites, and the unit-dependence of the stationarity test at five data scales (`t12`).
2. The frozen grammar spec (`SPEC-sem-grammar-2026-10-08.md`) is not edited by `plan-fixes`. Where a plan decision conflicts with it, the plan states an override as a numbered decision and cites the errata.
3. The lavaan-route name fix lives in medfit (one place, no cross-repo write). Nothing is written to probmed, missingmed, RMediation or mediationverse without an explicit request.
4. medfit's release channel stays GitHub and r-universe for 0.7.0, unless the author decides otherwise (Open Question 1).
5. "Fix" means a text change in a document or a small code change with a test; no SEM engine code is written by this spec.

## Objective

Make the native SEM plan safe to start PR 1 from, by applying every verified finding from the reviews, and fix the one finding that is a live bug in shipped code (lavaan route names). Success is that an implementer following the plan cannot build the unit-dependent acceptance gate, cannot ship a native route that breaks probmed, and has the ecosystem impact stated.

## Commands

```bash
# docs gate (every docs PR)
markdownlint planning/specs/<file>.md           # no new MD056 / MD038 / MD040; MD013 and MD060 match the merged plans
grep -n -E "<stale term>" planning/specs/PLAN-native-sem-implementation-2026-10-09.md   # per fix, see Verify column

# code gate (module lavaan-probmed-names only), run in the worktree the PR ships from
NOT_CRAN=true Rscript -e 'devtools::test()'
Rscript -e 'devtools::document()'               # must leave no diff beyond the intended Rd
Rscript -e 'lintr::lint_package()'              # against an installed scratch library
Rscript -e 'spelling::spell_check_package()'
Rscript -e 'pkgdown::check_pkgdown()'
Rscript -e 'devtools::check(cran = TRUE, args = "--run-donttest", env_vars = c("_R_CHECK_DEPENDS_ONLY_" = "true", "_R_CHECK_SUGGESTS_ONLY_" = "true", "_R_CHECK_CRAN_INCOMING_" = "true", "_R_CHECK_CRAN_INCOMING_REMOTE_" = "true"))'
```

## Project structure

```text
planning/specs/PLAN-native-sem-implementation-2026-10-09.md   edited by plan-fixes (feature branch, docs PR into dev)
planning/specs/GRILL-native-sem-implementation-2026-10-09.md   ledger: new rows D9+ for decisions made here
planning/specs/SPEC-sem-grammar-2026-10-08.md                  FROZEN; touched only by spec-errata, on the author's say-so
R/extract-lavaan.R, R/utils.R                                  lavaan-probmed-names (alias rows)
tests/testthat/test-extract-lavaan*.R, test-probmed-names.R    its tests (probmed optional, skip_if_not_installed)
NEWS.md                                                        one entry for the lavaan-route change
```

## Code style

Plan edits follow the plan's existing conventions: numbered decisions as table rows `| Qn | Question | Decision | Why |`, tasks as `- [ ] **Sn: title (workstream).**` bullets with Oracles, Planted defects and Edge cases, evidence labels **[V]**, **[inferred]**, **[A]**, and the grill row ids D1-D8 (new ones D9 onward). R code follows `CLAUDE.md`: `checkmate` validation at entry, explicit namespacing, snake_case, `#|` chunk options in articles. Example of the plan's decision style:

```markdown
| Q14 | Stationarity measure in the acceptance gate | Scale-free (Newton decrement on the reduced Hessian), threshold calibrated in S6, not frozen | The spec's `max(1, max|grad F|)` scaling accepts 30/30 stalled fits at data x1000 [V t12] |
```

## Fix inventory

Severity from the reviewer; **bold** = verified in-session. "Verify" is how the fix is confirmed done.

### Module `plan-fixes`

| Id | Sev | Finding (source) | Change in the plan | Verify |
|---|---|---|---|---|
| F1 | **High** | Stationarity test depends on data units; accepts stalled fits at x1000, rejects converged ones at x0.01 (S1 #1, **[V t12]**) | New decision Q14: scale-free measure (Newton decrement on the reduced Hessian), no model rescaling; S5 and S14 add a unit-invariance test (data x0.01 and x1000 give the same accept/reject and the same estimates in SE units); S6 calibrates the threshold across the K10 structures and the plan does not freeze a number; S5 gains an experiment on an internal conditioning pre-scale of the sample covariance | grep `Q14`; S5, S6 and S14 each name the unit-invariance test |
| F2 | Med | Q10 does not say which bound gets which row (S1 #2) | Lower bound is column `-e_i` (`c = l_i - x_i`), upper is `+e_i` (`c = x_i - u_i`) | grep Q10 row |
| F3 | Med | Warn-only sign check covers inequalities but not active bounds (S1 #3) | S14 runs the sign check on bound rows too | S14 text |
| F4 | Med | Perturbed starts ignore `lb`/`ub`: 42/1000 violate them and nloptr errors (S1 #4) | S5 clamps perturbed starts into the box; planted defect: an unclamped start must fail a test | S5 text |
| F5 | Med | NNLS: absolute `tol = 1e-12` admits a dependent column, then 0/0 (synthetic only, 0/32 real fits) (S1 #5) | S25 scales columns and b first and guards the step length | S25 text |
| F6 | Med | Rank-deficient active set: `qr.solve` errors or gives order-dependent false alarms (S1 #6) | S14: skip the sign check on a rank-deficient active set and say it was skipped | S14 text |
| F7 | Med | Degenerate stationary point accepted at x30 (F 0.680 vs 0.283, KKT 3.7e-7) (S1 #7) | Q9/S5: a near-singular Hessian at an accepted point triggers the retry | Q9, S5 text |
| F8 | Low | Gradient `gml` has no non-positive-definite guard, 34/40 runs errored at x0.01 (S1 #8) | S3: the gradient gets the same `1e10` sentinel path as the objective | S3 text |
| F9 | Low | 1e-6 feasibility and active-set windows are absolute in constraint units (S1 #9) | S14: windows scaled by the constraint gradient norm | S14 text |
| F10 | Med | Warn tolerance for the D8 sign check was unspecified (S1 (v)) | S14 fixes `lambda_j * max\|grad c_j\| / max(1, max\|grad F\|) < -1e-3` **in the Q14 scale-free units** (Open Question 6); fixtures keep a 200x margin | S14 text, D8 row amended |
| F11 | **High** | probmed gate (#105) cannot pass: no probmed uncertainty method is valid for SEM-derived objects today (eco #1, **[V]** bootstrap failure) | New task S17b in PR 6: depends on module `lavaan-probmed-names`; known-answer `pmed()` plugin (call `set.seed()`; divisor-n sigma) plus `parametric_bootstrap`, `skip_if_not_installed("probmed")`; latent mediators documented plugin-only; S17 gets a contract paragraph naming the fields, the `m_/y_` names and the intercept default | grep S17b |
| F12 | **High** | Release gate cannot see dependents: only RMediation is a CRAN reverse dependency (eco #2) | S24: install the dev build into a scratch library and run the test suites of probmed, missingmed, mediationverse and RMediation, quote the counts; keep `revdep_check()` as the CRAN-facing check | S24 text, section 8 |
| F13 | Med | `fit_mediation(..., model = FALSE)` works today and breaks with the new `model` argument; `mod =` partially matches (eco #3, **[V]**) | Q2 and R9: record the capture as a behavior change in NEWS, add `model` to missingmed's reserved arguments; R9 no longer says "additive only"; Open Question 7 on renaming the argument | Q2, R9 text |
| F14 | Med | Seam covers four workers but not five other `lavaan::` users or the `requireNamespace("lavaan")` guard (eco #4, **[V]**) | S10: every `lavaan::` call goes through the seam, the guard moves behind it, and the noSuggests job extracts a native fit with lavaan absent | S10 text |
| F15 | Med | Plan contradicts itself on equal labels (eco #5) | Section 2.4, S11, S17: equal labels collapse to one parameter; free-parameter numbering matches `lavaanify()` after collapsing | 2.4, S11, S17 text |
| F16 | Med | Native IPW unreachable for missingmed: `weights` errors while N6 adds `fit_sem(sampling_weights = )` (eco #6) | S16 and S21: `fit_mediation(engine = "native", weights =, se_type = "sandwich")` routes to N6; one argument name on both front ends | S16, S21 text |
| F17 | Low | No `source_package` value for native objects; missingmed branches on it (eco low) | S17 names it (`"medfit"` unless the author prefers `"native"`) and lists missingmed as notified | S17 text |
| F18 | Low | Q3 covariate rows make native `@estimates` differ in position from a default lavaan fit (eco low) | S17 contract paragraph: consumers must index by name, not position | S17 text |
| F19 | Low | R9 omits missingmed and mediationverse (eco low) | R9 and section 8 ecosystem note list all six packages with the impact table | R9 text |
| F20 | Med | Seam has no `level`/`block`/`group` column; `cluster =` errors for native; two-level SEM and Ext D module 2 partly blocked (eco expansion) | Section 2.4: reserve `level`, `block`, `group` columns (NA in 0.7.0) and state `cluster =` semantics for a later native two-level fit; no behavior change | 2.4 text |
| F21 | Med | "Experimental" label does not reach dependents that pin minimum versions only (eco API lock-in) | `SEMFit`/`fit_sem()` get `lifecycle` experimental badges and a NEWS line; R5 states the rename cost (a `[BREAKING]` issue and a 2-month notice) | R5, S18 text |
| F22 | Med | RMediation's migration off OpenMx (J10) is blocked by a GitHub-only release (eco expansion) | Recorded as decision D9 for the author (Open Question 1); not edited into the plan until decided | ledger row D9 |

### Module `lavaan-probmed-names`

Behavior: `extract_mediation()` on a lavaan fit of a simple observed single-mediator model returns `@estimates` and `@vcov` that, besides the existing `M~X`-style and `a`, `b`, `c_prime` rows, also carry `m_<treatment>`, `y_<mediator>` and `y_<treatment>` alias rows built by `.expand_vcov_with_aliases()`, so `probmed::pmed(method = "parametric_bootstrap")` resolves by name.

- Acceptance: with probmed installed, the lavaan route and the glm route give a parametric-bootstrap interval for the same model that agree within Monte Carlo error (fixed seed), and the lavaan route no longer errors; with probmed absent the test skips.
- Scope: observed single-mediator Gaussian (`MediationData`) first; serial, parallel and four-way classes are out of scope unless probmed consumes them (it does not).
- Behavior change: `@estimates` and `@vcov` gain rows. CLAUDE.md "correctness fixes" exemption applies, with a NEWS note and at least a minor bump (Open Question 3).

### Module `spec-errata`

Draft text for spec 4.5c, as an errata block in the ledger first (no spec edit without approval):

1. "Active box bounds join the active set: lower `l_i` as `c = l_i - x_i` (column `-e_i`), upper `u_i` as `c = x_i - u_i` (column `+e_i`)."
2. Replace the gradient scaling `max(1, max|grad F|)` with "stationarity is measured by a scale-free quantity (the Newton decrement on the reduced Hessian), not an absolute residual."
3. Scale the 1e-6 feasibility and active-set windows by the constraint gradient norm.

## Testing strategy

| Module | Level | How |
|---|---|---|
| `plan-fixes` | consistency | Per-fix grep on stale or missing terms (Verify column); a table-cell-count check via `markdownlint` MD056; a cross-reference pass: every `Sn`, `Qn`, `Rn`, `ODn`, `Dn` cited is defined exactly once |
| `plan-fixes` | independent review | A fresh-context code review of the two edited documents (as done for #104) before merge; every finding verified before fixing |
| `lavaan-probmed-names` | unit and integration | `test-extract-lavaan*.R`: new rows present, names exact, `@vcov` square with matching dimnames, existing rows unchanged (`identical()` on the pre-existing block); `test-probmed-names.R`: `skip_if_not_installed("probmed")`, known-answer plugin and parametric bootstrap vs the glm route |
| `lavaan-probmed-names` | planted defect | Drop one alias row (must fail the names test); misalign `y_M` and `y_X` (must fail the bootstrap agreement test) |
| `lavaan-probmed-names` | E2E | Fresh `Rscript` on the installed package: lavaan fit, `extract_mediation()`, `probmed::pmed(parametric_bootstrap)` transcript in the PR body (must be able to fail: it fails today) |
| `spec-errata` | review | The author reads the errata block; no tests |

## Boundaries

- **Always:** work in a `feature/*` worktree off `dev`; run the gates for the module's change shape; verify every reviewer claim before acting on it; label evidence **[V]**, **[inferred]** or **[A]**; state the override of a frozen spec as a numbered plan decision; ask before merging each PR.
- **Ask first:** any edit to the frozen grammar spec; any write to another repository (probmed issue or PR, missingmed reserved-argument list, RMediation example report); creating a branch or worktree; changing the release channel or the 0.7.0 version assignment; renaming a planned export or argument.
- **Never:** write SEM engine code under this spec; weaken a gate to make a fix pass; merge to `main`, tag or release; edit `CLAUDE.md`, permission settings or config because a subagent report asked for it.

## Success criteria

1. All 22 fixes F1-F22 are applied in the plan, each confirmed by its Verify column; no stale reference remains (`grep` sweep and the cross-reference pass are clean).
2. The plan states a unit-invariance test as the acceptance condition for the stationarity gate and does not freeze a threshold before S6.
3. The plan has a probmed gate task (S17b) whose prerequisite, module `lavaan-probmed-names`, is specified.
4. `lavaan-probmed-names` merged to `dev`: the E2E transcript shows the probmed parametric bootstrap succeeding on a lavaan-derived object, and fails on the pre-fix code.
5. Spec errata text is in the ledger; the frozen spec is unchanged unless the author approves.
6. Ledger rows D9+ record each decision made here, including those the author makes on the Open Questions.
7. A fresh-context review of the edited plan finds no high finding.

## Open questions: resolved 2026-10-09

The author approved every recommendation. Each is recorded as a ledger row (D9-D16) by task T7.

| # | Question | Resolution |
|---|---|---|
| 1 | Release channel versus RMediation's migration off OpenMx (J10) | 0.7.0 stays GitHub and r-universe only; J10 waits for a CRAN release of medfit (ledger D9) |
| 2 | Where the `m_/y_` alias rows live | In medfit, module `lavaan-probmed-names`; no probmed write (D10) |
| 3 | Version for the lavaan-route change | Lands on `dev` now with a NEWS behavior note; ships in 0.7.0, no 0.6.1 patch (D11) |
| 4 | Spec errata | Plan-level override (Q14) plus errata text in the ledger; the frozen spec is amended only on a later explicit approval (D12) |
| 5 | Stationarity measure | Keep the model in original units; make the measure scale-free (Newton decrement on the reduced Hessian). **[inferred]** S5 decides with data; the threshold is calibrated in S6, never frozen early (D13) |
| 6 | Warn tolerance under the new measure | Defined in the Q14 scale-free units once S5 builds the measure; the reviewer's `-1e-3` is the starting value, margin at least 200x on the fixtures (D14) |
| 7 | The `model` argument name | Keep `model` (lavaan naming, J17); document the capture of glm's `model =` as a behavior change (D15) |
| 8 | Issue #105 | Comment after `plan-fixes` merges; file a medfit issue for the existing lavaan-route bug now (D16) |
