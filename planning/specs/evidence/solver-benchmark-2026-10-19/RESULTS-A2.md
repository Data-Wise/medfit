# Solver benchmark, addendum A2: results (design precommitted in f8e108a, `ADDENDUM-A2-DESIGN.md`)

**Run:** 2026-10-19 on the Mac (R 4.6.1, nloptr 2.2.1).
- Data: the A1 cells, same generators and seeds. That is 10,900 datasets in G1–G7 and E1–E7, plus
  600 in the invariance cells I1–I3.
- Scripts and outputs: `bench_a2.R` → `a2_1..16.csv`, analysed by `analyze_a2.R` in `analysis_a2.out`.
- Every method scored against the exact 1-D oracle. No method went below it (0 oracle misses).

## Results

| Method | Wrong (of 10,900) | Unresolved | Invariance > 1e-6 (of 600) | Robust by the fixed criteria |
|---|---|---|---|---|
| T: cold polish, 41-point grid, best 3 | 1 | 0 | not tested | no |
| TW: warm polish, 41-point grid, best 3 | 0 | 0 | 2 (max 5.9e-6) | no (invariance only) |
| TW11: warm, 11-point grid, best 1 | **69** | 0 | not tested | no |
| TW21: warm, 21-point grid, best 1 | **23** | 0 | not tested | no |
| TWr: TW with random inner starts | 0 | 0 | not tested | yes, where tested |
| NP: numerical profile + `optimize()` | 0 | 0 | **31 (max 0.93)** | no |
| PC: closed-form profile + `optimize()` | 0 | 0 | 0 (max 3e-13) | **yes** |
| TWs: TW on standardized data | 0 | 0 | 0 (max 2e-11) | **yes** |
| AUG8: AUGLAG, 8 starts | 54 | 1,376 | not tested | no |

The wrong answers of the coarse-grid variants are concentrated in a few cells:
- q near 0 (E1a, E1b: 3–29 per 300);
- the near-perfect fit (E7: 10 per 300);
- tiny n (E3b: 3–6 per 300).

## What this says about the author's concern

**1. The fix is not a lucky start.**
- TWr starts every inner fit at a random nuisance value and still has 0 wrong answers in 10,900.
  The *nuisance* start does not matter.
- What failed in A1 is narrower. The cold variant threw away the profile it had just computed and
  restarted the joint fit from the unconstrained MLE.
- "Warm start" is therefore not a tweak. It is the profile-then-polish logic itself: compute the
  profile over φ, then polish its minimizer.

**2. The real dependence is on the φ grid.**
- With 11 or 21 points and only the best point kept, the method misses the right basin in up to 0.6%
  of datasets, mostly near q = 0, where the profile has two close basins.
- With 41 points and the best 3 kept, it had no misses here.
- This is the fragility to guard against: correctness rests on the grid bracketing every basin, and
  41 points is a margin we observed, not a guarantee.

**3. Without standardization, scale breaks the numerical methods.**
- NP, the purely numerical profile, is correct on the original scale but fails badly on rescaled data
  (31/600, up to 0.93). Its inner fits, warm-started along the grid, stall when c′ is on a 1000×
  scale.
- Standardizing the data (TWs) removes every invariance failure. **D20 is answered: standardize.**

**4. The closed-form profile (PC) is the only method that needs no numerical start at all.** It is
correct everywhere tested and invariant to 3e-13. It exists only where c′ and the variances
concentrate out in closed form, which is the observed-variable model.

## Recommendation (replaces the Tier 1 parts of D16; answers D20)

| Model class | Method | Status label |
|---|---|---|
| Observed variables (closed-form profile exists) | **PC**: profile out c′ and the variances exactly, then a φ grid plus `optimize()` on every bracketed minimum, per sign | `charted`. It is exact up to grid resolution; the grid only has to bracket basins, and each is then solved to 1e-10. |
| Latent or general models | **TWs**: standardize; 41-point φ grid, inner fits at every point, warm polish from the best 3; then the **grid-refinement check** below | `charted`, or `local` if the check disagrees |
| Not chartable | Tier 2 AUGLAG multistart | `local` |

**Grid-refinement check (new; to implement and test in #63).** Rerun with an 81-point grid. If the
two answers differ by more than 1e-6·max(1, LR), report the smaller value and label it `local`.
- This turns the grid dependence from a silent risk into a flagged one.
- It is untested: the 81-point grid was not run in A2.

Do **not** use T (cold polish), NP without standardization, or a single best grid point.

**Is Tier 1 still better than the alternative?** Yes, by a wide margin. AUGLAG with 8 starts gave 54
wrong answers and 1,376 unresolved fits on the same data, where TWs and PC gave none.

## Status

| Claim | Status |
|---|---|
| The nuisance start does not affect TW's correctness (TWr: 0 wrong in 10,900) | verified numerically |
| A coarse φ grid with one candidate misses basins (TW11: 69, TW21: 23 wrong) | verified numerically |
| PC and TWs: 0 wrong, 0 unresolved, invariant within 1e-6 | verified numerically |
| NP is not scale-invariant without standardization | verified numerically |
| An 81-point refinement check catches grid misses | open (proposed, not run) |
| TWs behaviour in latent models | open (A2 covers the two-path observed model only) |

**Not examined:**
- latent models, where nuisance optimization may itself be multimodal (e.g. Heywood cases), so TWr's
  conclusion does not automatically carry over;
- constraints other than ab = q;
- n > 500;
- grids finer than 41 points.
