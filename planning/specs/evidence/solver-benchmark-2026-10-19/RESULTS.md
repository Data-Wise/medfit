# Solver benchmark: results (design precommitted in 0fa69b1, `DESIGN.md`)

**Run:** 2026-10-19 on the Mac.
- Software: R 4.6.1, nloptr 2.2.1, Rsolnp 2.0.1 (private `rlib/`), `stats::nlminb`.
- Base seed 20261024; cell c uses 20261024 + c; 1,000 datasets per cell.
- Scripts: `bench.R`, `bench_fixtures.R`, `analyze.R`.
- Raw output: `bench_{A,B,C}.csv/.out`, `bench_fixtures.csv/.out`; analysis in `analysis_*.out`.

Every number below was produced by these scripts. "T" is Tier 0 (q = 0), Tier 1 (q ≠ 0) or the
stratum procedure (cell 15), as `DESIGN.md` defines.

## Decision (cells 5–11): Tier 1 becomes medfit's default for ab = q ≠ 0

The precommitted rule holds in every decision cell (`analysis_BC.out`):
- T1 has zero accepted-wrong answers;
- the paired one-sided 95% lower bound of success(T1) − success(AUG) is ≥ −0.005.

| Cell | Truth (a, b) | q | T1 success | T1 wrong | AUG success | Paired diff | Lower bound |
|---|---|---|---|---|---|---|---|
| 5 | (.3, .3) | .09 | 1.000 | 0 | .434 | .566 | .540 |
| 6 | (.3, .3) | .02 | 1.000 | 0 | .478 | .522 | .496 |
| 7 | (.3, .3) | .005 | 1.000 | 0 | .488 | .512 | .486 |
| 8 | (.3, .3) | −.02 | 1.000 | 0 | .520 | .480 | .454 |
| 9 | (.3, .3) | −.09 | 1.000 | 0 | .510 | .490 | .464 |
| 10 | (.1, .5) | .05 | 1.000 | 0 | .369 | .631 | .606 |
| 11 | (.1, .5) | −.05 | 1.000 | 0 | .455 | .545 | .519 |

T1's success is 1,000/1,000 in every cell; the Wilson 95% interval is [.996, 1]. In no cell did AUG
succeed where T1 failed (d01 = 0).

**The decision does not hinge on the strict acceptance rule.** AUG's strict failures are almost all
status −1 returned on correct, feasible fits (`unresolved`). Under the relaxed acceptance of
DEVIATION 2:
- AUG succeeds in .963–.995 of datasets;
- T1 still beats it in every cell;
- AUG also returns 5–37 wrong answers per 1,000.

## What the competitors do (cells 5–11)

| Method | Strict success | Accepted-wrong per 1,000 | Note |
|---|---|---|---|
| SLSQP (nloptr) | .644–.998 | 2–356 | Worst in cell 7 (q = .005, near the two-basin regime): 356 wrong answers with a success status. These are feasible fits on the wrong component or local minimum. |
| AUG (nloptr AUGLAG + LBFGS) | .369–.520 | 0–9 | Mostly unresolved (status −1); wrong 5–37 per 1,000 under the relaxed rule. |
| CSOLNP (Rsolnp 2.0.1, default control) | .000–.024 | 187–878 | Status 0, far from the optimum (median excess LR 3.8 in cells 9–11). This matches the earlier 2-variable toy failure. Not diagnosed beyond that. |
| T1 (chart + nlminb) | 1.000 | 0 | Median 0.02 s per dataset, the same as AUG. |

No method ever returned a value below the oracle (`below_oracle` = 0 throughout). The 1-D profile
oracle was therefore never beaten, which is the check that it is the minimum.

## Descriptive cells (q = 0: 1–4, 12–14; stratum: 15)

Source: `analysis_A.out`, from `bench_A.csv`.

| Cell | Setting | T | AUG (strict / relaxed) | SLSQP (wrong, all below the oracle) | CSOLNP (wrong) |
|---|---|---|---|---|---|
| 1 | two-path, (0, 0) | 1.000 | .584 / .996 | 145 | 49 |
| 2 | two-path, (0, .39) | 1.000 | .668 / .996 | 1 | 241 |
| 3 | two-path, (.39, 0) | 1.000 | .667 / .999 | 4 | 248 |
| 4 | two-path, (.14, 0) | 1.000 | .567 / .993 | 100 | 50 |
| 12 | chain, (0, 0, 0) | 1.000 | .461 / .986 | 464 | 139 |
| 13 | chain, (.39, 0, 0) | 1.000 | .548 / .986 | 400 | 76 |
| 14 | chain, (.39, .39, 0) | 1.000 | .525 / .984 | 107 | 462 |
| 15 | parallel, b1 b2 = b3 b4, n = 200 | 1.000 (vs best known) | .876 / .977 | 0 | 129 |

**What the table shows**

- **T (Tier 0 branch fits; in cell 15, both charts plus the stratum) is exact in every q = 0 cell.**
  It takes under 1 ms per dataset there, because each branch fit is a small, smooth, unconstrained problem.
- **Every SLSQP error at q = 0 lies *below* the closed-form oracle.** These fits are feasible to
  1e-8 but sit in the tolerance slab, at a lower F than the restricted minimum. This is the
  tolerance inequality of the companion's Proposition 6.3, seen in a solver. The error is largest
  where two or more paths are zero (cells 1, 12, 13: 145–464 per 1,000), which is where the null
  set is singular.
- **CSOLNP's errors at q = 0 lie above the oracle**, as in the decision cells: it stops early.
- **Cell 15:** the reference is the best known value (DEVIATION 3), not a proven minimum. T matched
  it in all 1,000 datasets, and no method beat T.

## Deterministic fixtures (`bench_fixtures.out`)

| Fixture | Reference | T | AUG | SLSQP | CSOLNP |
|---|---|---|---|---|---|
| D1-RQ1 (memory, two-path) | 72.5436 | 72.54357 ✓ | ✓ | ✓ | ✓ |
| D1-RQ2 (memory, one product) | 0.0831 | 0.08310 ✓ | ✓ | ✓ | ✓ |
| D1-RQ3 (b1 b2 = b3 b4) | 25.8283 | 25.82825 ✓ | ✓ | ✓ | 25.82862 ✗ |
| D2 (â ≈ 1e-6, q = .05) | 1.81641 (1-D oracle) | 1.81641 ✓ | unresolved strict; 3.7e31 relaxed ✗ | 7.2e30 ✗ | 47,333 ✗ |

D2's failures come from the projected starts b = q/a, which are absurd when â ≈ 0; T's chart grid
avoids that.
The design requires T to succeed on every fixture, and it does.

## Deviations from `DESIGN.md`

1. **Parallel model variance-profiled.** The objective uses n log det(E′E/n) + n log(RSS_Y/n), so the
   parameters are (a1, a2, c′, b1, b2). It is the same −2 log L, with the variances profiled out.
   *Reason:* fewer free parameters for the multistart oracle. Affects cell 15 and D1-RQ2/RQ3 only.
2. **Relaxed acceptance, as a sensitivity analysis.** A fit is accepted if it is finite and feasible
   (|g| ≤ 1e-8·max(1, |q|)), whatever its status. *Reason:* AUGLAG returns status −1 on correct,
   feasible fits. Strict results come first and decide; relaxed results are reported beside them.
3. **Best-known reference for the parallel cell.** The reference is the minimum over the oracle and
   every method's feasible value. Every such value is a feasible point, so the reference is still the
   best known. Affects cell 15 only.

## Status

| Claim | Status |
|---|---|
| T1 meets the precommitted rule in cells 5–11 | verified numerically (this run) |
| SLSQP returns wrong answers with success status, up to 36% near the two-basin regime | verified numerically |
| CSOLNP (Rsolnp 2.0.1 `csolnp`, default control) fails on this problem class | verified numerically; cause not diagnosed (iteration limits suspected, not tested) |
| T exact in every descriptive q = 0 cell; matches the best known in the stratum cell | verified numerically |
| SLSQP at q = 0 falls below the restricted minimum (tolerance slab), worst where ≥ 2 paths are zero | verified numerically |

**Not examined:**
- csolnp with non-default control;
- the old `solnp()`;
- OpenMx (outside this benchmark);
- n other than 100 (200 in cell 15);
- latent-variable models.
