# Plan: Codex adversarial engine review, triage and implementation (2026-10-20)

Source: Codex read-only review of `origin/dev` at `739cc60` (9 findings, no tests run, GitHub issues
unreachable). Triage below checked each claim against `origin/dev` source. Nothing is implemented yet.

## Triage

| # | Codex | Verified | Verdict |
|---|---|---|---|
| 1 | `anova()` returns an invalid p-value after warning | True: `.sem_anova_warn_boundary()` warns, `p` is still computed (`R/sem-anova.R:74-77, 353-360`) | **Design choice, not a bug.** It mirrors `mbco_sem()` (warn, keep the number). Real gap: the validity is only in warning text. Fix = structured flag, decide NA separately (D1). |
| 2 | Nesting check admits unprovable pairs | Code comment says necessary, not sufficient (#249) | **Valid, medium.** Limit/label rather than rewrite; ties to #249 comparison engines. |
| 3 | Dependent version floors too low | RMediation and missingmed both guard at runtime (`packageVersion("medfit") < "0.8.0"` stop; `>= "0.4.0"` engine list) | **Downgraded to low.** Floors are low on purpose (optional feature, core works on 0.2.0/0.3.1). Action is docs/DESCRIPTION wording only, in other repos (needs permission). |
| 4 | Nonlinear fit is local, not proven optimum | Code already warns on optima spread; gate is a rate | **Valid, medium.** Add a `converged_global = FALSE`-style label to results; no new solver. |
| 5 | Inequality multiplier sign is warn-only | True, but documented decision (grill-8, D8, D14) | **Contested.** Needs a defect test first: does any accepted fit sit on the wrong side? Revisit D8 only on evidence. |
| 6 | Bootstrap reproducibility depends on `ncores` | **Confirmed** (`R/bootstrap.R:378-403`: `sample.int()` inside `mclapply`; errors become silent `NA`) | **Valid, high-value, small.** Same as #247. |
| 7 | Numerical gates platform-limited | Matches #238 and the 0.11.0 decision log | **Known, tracked.** Fold into #238, no new work. |
| 8 | S7 class shape is a cross-package API | missingmed/probmed use `@a_path`, `@estimates`, `@vcov` | **Valid, process.** Add a dependent contract check before class changes. |
| 9 | Engines differ in estimand/uncertainty | Documented per engine; no single matrix | **Valid, docs.** One parity matrix in the models guide. |

## Work packages (medfit repo only unless marked)

Order by value per token. One PR per package; batch 1+2 if Codex finishes both together (feature-branch rule 4).

1. **W1 Bootstrap reproducibility (#247, finding 6).** Draw all resample indices in the parent before dispatch,
   so a fixed seed gives identical resamples for any `ncores`; stop turning refit errors into silent `NA`
   (count and report them). Test: same seed, `ncores = 1` vs `2` vs sequential gives identical estimates;
   planted defect = per-worker RNG must fail the test. Evidence: the test transcript in the PR body.
2. **W2 Structured validity for `anova()` (finding 1).** Add a `p_valid` column or attribute so callers read
   validity without parsing warning text; keep the number and the warning (no API break). Test with a boundary-null
   fixture (active bound on the tested parameter). Decision D1 below.
3. **W3 Nesting guard (finding 2, #249).** Document the necessary-not-sufficient limit in `?anova.SEMFit`; add a
   planted non-nested latent-structure pair the check must reject or flag. Larger comparison-engine work stays in #249.
4. **W4 Local-optimum label (finding 4).** Expose optimum spread / "best of n accepted starts" on `SEMFit`
   diagnostics and surface it in `summary()`; no solver change.
5. **W5 Parity matrix (finding 9).** One table in the models guide: engine x estimand, SE type, weights,
   families, missing data. Reuses `?extract_mediation` facts; a consistency test like `test-cookbook-consistency.R`.
6. **W6 Dependent-contract gate (finding 8).** A script/test that loads probmed and missingmed against the
   current class shape before any S7 change (feeds the #214 decision). Read-only on sibling repos.
7. **W7 Sign-check evidence (finding 5).** Defect test only: construct an active inequality where the multiplier
   sign is wrong and see whether the fit is accepted. If it is harmful, reopen D8 with that evidence; else close.
8. **Other repos (needs your per-action permission, drafts only):** RMediation and missingmed DESCRIPTION/doc
   wording for the version floors (finding 3). Folded into #238: finding 7.

## Decisions needed

- **D1 (recommend: keep number, add flag).** Return NA for an invalid boundary p-value, or keep it with a
  structured flag. Recommend the flag: NA breaks the `mbco_sem()` precedent and callers that already read the number.
- **D2 (recommend: defer).** Do W7 before any change to the warn-only sign rule; it was a deliberate grill decision.
- **D3.** Release target: W1-W6 are patch-level behavior/docs except the W2 column (minor-safe addition);
  suggest 0.11.1 batch. Not CRAN-bound (GitHub-only since 0.5.0).

## Execution notes

- Branch off `origin/dev` in a worktree per package; the current checkout is a stale branch.
- Implementation to Codex where its sandbox allows. Codex cannot write outside its session roots, so
  worktrees outside the repo need either the edits made by Claude or Codex started with that root writable.
- Tier per `pre-pr-testing.md`: W1-W4 code = full suite in the worktree; W5 docs = lint + consistency tests.
- Do not merge without asking; CI green first.

## Status (2026-10-20, evening)

- **W1 done:** PR #251 merged to dev (squash).
- **W2 done, in CI:** PR #252 (`p_valid` attribute, D1 = keep + flag); dev merged in, awaiting green CI.
- **W7 done, no PR:** 294 real `fit_sem()` fits (6 seeds x 7 inequality forms x 7 thresholds: `a+b<k`, `a+b>k`, `a-b>k`,
  `a*b>k`, `a*b<k`, `b+cp<k`, `a+cp>k`; script `/private/tmp/claude-501/w7.R`) gave 0 errors and 0 wrong-sign
  warnings. The wrong-sign accept exists only when the optimizer is mocked onto the equality point
  (`test-sem-constraints.R:368`, `:602`). Verdict: no evidence that the real solver lands there; keep D8 (warn-only).
  Falsifier: a seeded family where a real fit emits "moving into the feasible region would lower the objective".
- **Not started:** W3 (waits for #252, same file), W4, W5, W6.

## Final status (2026-10-21)

All packages closed and released in 0.11.1: W1 #251, W2 #252, W3 #254, W4 #255 (with #256), W5 #253, W6 #257, W7 closed by evidence (no PR). D1 = keep the p-value and add `p_valid`. Optimizer robustness layers 1-4 followed (#260-#262); plan in `planning/specs/PLAN-optimizer-robustness-2026-10-20.md`.
