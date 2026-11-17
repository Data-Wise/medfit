# T4: harness QA (planted mutants and the X rescale)

Plan: `planning/PLAN-few-clusters-design-study-2026-11-16.md`, task T4. Date 2026-11-16.
Environment: R 4.6.2, lavaan 0.7.3, medfit 0.18.0.9000 installed from worktree SHA `50823235` into a scratch library.
Harness: `tests/sim/twolevel-few-clusters-lib.R` (`fc_paired_catch()`, `fc_mutant_shift()`, `fc_mutate_runs()`,
`fc_rescale_compare()` with `clean_both`; first attempt: `fc_coverage()`, `fc_band()`); driver
`tests/sim/twolevel-few-clusters.R`. Tests: `tests/testthat/test-twolevel-few-clusters-harness.R` ("T4: ...").

## Verdict

**Stop rule S1 triggered by the narrow mutant.** Under the baseline-paired criterion the truth mutant is caught in all
120 (cell, estimand) pairs; the narrow mutant is caught in 107 of 120. The 13 it leaves uncaught are all between-level
or contrast estimands in five over-covering cells (table below). The rescale criterion holds: coverage indicators are
identical on all 1077 datasets converged and admissible in both scalings. Nothing was weakened.

## Second design: baseline-paired criterion (current)

The first attempt (below) asked each mutant to move coverage outside the band (0.925, 0.975). It was replaced because
a fixed band answers the wrong question: a +.05 shift is small against between-level SEs of .07 to .21, and
over-covering null baselines (.98 to 1.00) land inside the band after narrowing. The user chose "compare against
baseline".

- **Criterion.** A mutant is caught in a (cell, estimand) when its coverage drops below the baseline's by more than
  3 paired MCSEs. The runs share seeds, so with d_i = I_base,i - I_mut,i over the same datasets,
  MCSE = sd(d_i) / sqrt(R_common). A dataset that did not converge, raised an adapter error, or has an NA interval in
  either run is dropped from both. A mutant that leaves any (cell, estimand) uncaught is S1.
- **Truth mutant.** Each estimand's truth shifts by 2 x its median SE in that cell, from the baseline run
  (`fc_mutant_shift()`). Shifts: nie_within .029 to .065, c_prime_within .050 to .109, nie_between .073 to 1.27,
  nie_contrast .079 to 1.28, c_prime_between .21 to 1.76. **Narrow mutant.** Intervals narrowed 20% about the
  estimate, as before.
- **No new runs.** Both mutants are post-processing of result rows. Check first: `fc_apply_mutant(base.csv, m)`
  equals the recorded `truth.csv` and `narrow.csv` row for row (max numeric gap 2.8e-17 and 6.8e-12; every other
  column identical, `fit_time` excluded). Both new mutants are therefore computed from `base.csv` with
  `fc_mutate_runs()`; no refit is needed, because neither mutant changes the data or the fit.
- Script: `_agents_workspace/fc-t4/analyze2.R`; outputs `paired-catch.csv`, `shift.csv`, `rescale-compare2.csv`
  (git-ignored).

### Results (24 J = 100 cells, arm p0, R = 500 before drops; R_common 317 to 500)

| Mutant | caught | uncaught |
|---|---|---|
| truth (2 x median SE) | 120 / 120 | 0 (smallest drop / MCSE 15.6) |
| narrow (20%) | 107 / 120 | 13 |

Uncaught under the narrow mutant:

| Cell | n | ICC_X | sizes | nie_b | Estimand | R | base | narrow | drop | paired MCSE |
|---|---|---|---|---|---|---|---|---|---|---|
| 1005 | 5 | .05 | equal | .18 | nie_between | 343 | 0.988 | 0.980 | 0.0087 | 0.0050 |
| 1005 | 5 | .05 | equal | .18 | nie_contrast | 343 | 0.991 | 0.988 | 0.0029 | 0.0029 |
| 1005 | 5 | .05 | equal | .18 | c_prime_between | 343 | 0.997 | 0.988 | 0.0087 | 0.0050 |
| 1035 | 5 | .05 | unequal | .18 | nie_between | 317 | 0.972 | 0.962 | 0.0095 | 0.0054 |
| 1035 | 5 | .05 | unequal | .18 | nie_contrast | 317 | 0.968 | 0.968 | 0 | 0 |
| 1035 | 5 | .05 | unequal | .18 | c_prime_between | 317 | 0.997 | 0.987 | 0.0095 | 0.0054 |
| 1065 | 5 | .05 | equal | 0 | nie_between | 329 | 1.000 | 1.000 | 0 | 0 |
| 1065 | 5 | .05 | equal | 0 | nie_contrast | 329 | 1.000 | 1.000 | 0 | 0 |
| 1065 | 5 | .05 | equal | 0 | c_prime_between | 329 | 1.000 | 0.994 | 0.0061 | 0.0043 |
| 1070 | 20 | .05 | equal | 0 | nie_between | 496 | 1.000 | 0.988 | 0.0121 | 0.0049 |
| 1095 | 5 | .05 | unequal | 0 | nie_between | 338 | 1.000 | 0.994 | 0.0059 | 0.0042 |
| 1095 | 5 | .05 | unequal | 0 | nie_contrast | 338 | 1.000 | 0.997 | 0.0030 | 0.0030 |
| 1095 | 5 | .05 | unequal | 0 | c_prime_between | 338 | 0.997 | 0.982 | 0.0148 | 0.0066 |

Coverage here is over the R_common datasets kept, so it differs from the unconditional per-cell table below.

Why these pass. A narrowed interval can only lose coverage, so d_i is 0 or 1 and, with m discordant datasets,
drop / MCSE = sqrt(m (R - 1) / (R - m)); the mutant is caught only when m >= 9. In these cells the between-level
and contrast intervals are wide against the distance to the truth (the ICC_X = .05 cells with n = 5, and the null
nie_b = 0 cells, over-cover at .97 to 1.00 on the kept datasets), so narrowing by 20% moves 0 to 5 truths out of an
interval. The criterion is doing what it says: in these cells a 20% narrowing has no detectable effect on coverage
at R of about 330, so the harness cannot show that it would catch such a defect there. Resolving it (more reps for
these cells, a larger narrowing, or scoping the narrow mutant to cells where it has power) is a design decision for
the orchestrator; the criterion was not changed.

### Metamorphic rescale (X x 10), stated criterion

Criterion: coverage indicators identical on the datasets converged and admissible in both scalings with no adapter
error (`clean_both`); boundary-cell flips and the estimate gap are reported separately.

- **Criterion holds.** 1077 of 1200 datasets (24 cells x reps 1 to 50) are `clean_both`; indicators differ on 0.
- Off the clean set (123 datasets: cells 1005 26, 1035 34, 1065 31, 1095 28, 1070 2, 1075 1, 1100 1): 24 flag flips
  and 17 indicator flips, all in the four n = 5, ICC_X = .05 cells (1005, 1035, 1065, 1095), as in the first attempt.
- Estimate gap |10 est' - est| / se on the clean set: median 1.3e-4, 99th percentile 2.4e-3, max 0.027 (cell 1035);
  62 above 1e-3. The identity holds to optimizer precision, not to 1e-3 SE, at J = 100.

### Tests and planted defects

`tests/testthat/test-twolevel-few-clusters-harness.R`: 29 tests, 190 expectations, 0 failed, 0 errors, 0 skipped
(`NOT_CRAN=true`); lintr clean on the lib and the test file. New tests: the paired criterion on a hand-built
R = 400 case (drop .03, paired MCSE .0085: caught; the unpaired MCSE .0174 would miss it; a coverage gain never
caught), the drop rule (ten datasets dropped from both runs), the SE-scaled shift (medians .1 and .5, shifts .2 and
1.0), `clean_both`, and both mutants caught on calibrated intervals. Planted defects, each caught by `expect_failure()`
in the test file and again by editing the lib, running the file and restoring it:

| Defect (planted in the lib) | Failing test |
|---|---|
| unpaired MCSE sqrt(p_b q_b / R + p_m q_m / R) | paired criterion |
| wrong sign, d = I_mut - I_base | paired criterion; mutants on calibrated intervals |
| shift not scaled (fixed .05) | SE-scaled shift |
| no drop rule (all rows kept) | paired criterion |

In-file defects also cover a global (not per-cell) median SE and a negative shift.

## First attempt: fixed +.05 truth shift and the band criterion (replaced)

Kept as recorded. It was replaced by the paired criterion above for the reasons given there.

### Verdict (first attempt)

**Stop rule S1 triggered.** Both mutants move every within-level cell (nie_within, c_prime_within) out of the band,
but at J = 100 several between-level and contrast cells stay inside (0.925, 0.975) under a mutant. Nothing was
weakened. The cause is design power plus a conservative baseline, not a harness defect (see "Why the mutants pass").

### Commands

```sh
export R_LIBS=<scratch lib> CELLS=1005,1010,...,1120 ARMS=p0 CORES=6
REPS=500 OUT=base.csv                  Rscript tests/sim/twolevel-few-clusters.R   # 937.7 s
REPS=500 MUTANT=truth  OUT=truth.csv   Rscript tests/sim/twolevel-few-clusters.R   # 949.3 s
REPS=500 MUTANT=narrow OUT=narrow.csv  Rscript tests/sim/twolevel-few-clusters.R   # 938.2 s
REPS=50  SCALE_X=10    OUT=rescale.csv Rscript tests/sim/twolevel-few-clusters.R   # 118.7 s
```

Cells: the 24 J = 100 cells, 1005 to 1120 by 5 (n in {5, 20}; ICC_X in {.05, .20, .40}; equal and unequal sizes;
true between NIE .18 and 0). Arm p0. R = 500 per cell.

| File | rows | sha256 |
|---|---|---|
| base.csv | 12000 | `256fdbda6fe55ef0d208155c164ff4780f0ec0efb0be573f65dc9d06eb5172ac` |
| truth.csv | 12000 | `9e40d14b62d4b7b2b47a0533cc00299d577fc906cfd379cef1154eb91b4d9ae9` |
| narrow.csv | 12000 | `3dc4f1f033f6a3f957b4449c0b600de84172c3c2fe72c05f3190518cf4474d09` |
| rescale.csv | 1200 | `60fa30340390e9f821e21bcae08836e01241ddd99ce1cd6334a71157ab04e5fc` |

The CSVs stay in `_agents_workspace/fc-t4/` (git-ignored).

### Definitions

- Coverage is unconditional: a row with an NA interval (adapter error, non-converged fit) counts as a miss.
  MCSE = sqrt(p (1 - p) / R).
- Band call (`fc_band()`): `ambiguous` if the coverage is within 2 MCSE of either edge of (0.925, 0.975), on either
  side; otherwise `inside` or `outside` by the point coverage. An `ambiguous` call can sit just outside the band.
- Mutant `truth`: every truth shifted by +.05. Mutant `narrow`: every delta interval narrowed 20% about its center.
- Determinism check: the truth and narrow runs equal the base run in every column except their own (truths, or
  lo/hi). TRUE for both.

Baseline health (12000 rows): 0 lavaan errors, 121 adapter errors, 88 non-converged, 1060 inadmissible,
570 between-unidentified, 691 rows with an NA interval.

### Band calls (count of the 24 cells)

| Estimand | base amb/in/out | truth amb/in/out | narrow amb/in/out |
|---|---|---|---|
| nie_within | 13 / 8 / 3 | 0 / 0 / 24 | 2 / 0 / 22 |
| c_prime_within | 9 / 12 / 3 | 0 / 0 / 24 | 4 / 0 / 20 |
| nie_between | 9 / 3 / 12 | 6 / 0 / 18 | 9 / 3 / 12 |
| c_prime_between | 11 / 9 / 4 | 19 / 1 / 4 | 4 / 0 / 20 |
| nie_contrast | 10 / 5 / 9 | 11 / 4 / 9 | 12 / 1 / 11 |

S1 count by point coverage (mutant coverage in (0.925, 0.975), whatever the call), 120 cell-estimands per mutant:

| Mutant | cells inside | nie_within | c_prime_within | nie_between | c_prime_between | nie_contrast |
|---|---|---|---|---|---|---|
| truth | 31 | 0 | 0 | 4 | 14 | 13 |
| narrow | 14 | 0 | 0 | 7 | 0 | 7 |

Those called `inside` outright (not `ambiguous`):

| Mutant | Cell | Estimand | base | mutant | median SE | predicted truth coverage |
|---|---|---|---|---|---|---|
| truth | 1030 | nie_contrast | 0.956 | 0.946 | 0.068 | 0.886 |
| truth | 1050 | nie_contrast | 0.938 | 0.948 | 0.080 | 0.904 |
| truth | 1055 | nie_contrast | 0.940 | 0.946 | 0.095 | 0.918 |
| truth | 1070 | nie_contrast | 0.990 | 0.946 | 0.099 | 0.920 |
| truth | 1100 | c_prime_between | 0.940 | 0.952 | 0.213 | 0.944 |
| narrow | 1080 | nie_between | 0.988 | 0.956 | 0.043 | |
| narrow | 1085 | nie_between | 0.990 | 0.950 | 0.050 | |
| narrow | 1090 | nie_between | 0.982 | 0.950 | 0.050 | |
| narrow | 1120 | nie_between | 0.984 | 0.950 | 0.038 | |

Predicted truth coverage is Phi(1.96 - d) - Phi(-1.96 - d) with d = .05 / median SE.

### Why the mutants pass

1. **The truth shift is small against the between-level SE.** With a median between SE of .07 to .21, a .05 shift
   lowers nominal coverage only to .89 to .94; at R = 500 (MCSE about .01) that cannot leave the band reliably.
   The within estimands (SE .015 to .05) all leave it. The contrast truth also moves by .05 (checked in the CSVs),
   but its SE carries the between-level variance, so its predicted coverage is .89 to .94 and its truth-mutant calls
   (11/4/9) barely differ from base (10/5/9).
2. **The null between-level NIE is conservative.** With nie_b = 0 the delta interval for a product of two paths, one
   of them zero, over-covers (base .98 to 1.00). Narrowing it 20% brings it to about .95, inside the band.
3. **Some baselines are already far outside.** In n = 5, ICC_X = .05 cells (1005, 1035, 1065, 1095) base coverage of
   the between estimands is about .68, so a mutant "outside" there carries no information.

### Metamorphic rescale (X x 10)

Derivation: X = u + e, so X k scales both level components and leaves every ICC unchanged. At each level a and c'
become a / k and c' / k; b is unchanged. So every estimand (nie_within, nie_between, nie_contrast, c_prime_within,
c_prime_between) and its truth divide by k, and under ML invariance the delta interval divides by k exactly.
The adapter's ICC thresholds and `.twolevel_pair_equal()` (relative variance test) are scale-free.

Result over 1200 datasets (24 cells x reps 1 to 50):

- 1176 datasets have identical coverage indicators and flags.
- 24 datasets differ in a flag; 17 of them also flip at least one coverage indicator (nie_within 12, nie_between 8,
  nie_contrast 8, c_prime_within 12, c_prime_between 8 indicator flips in total).
- **All 24 are in the four n = 5, ICC_X = .05 cells** (1005, 1035, 1065, 1095), where the fit sits near a boundary.
  14 of them switch convergence or adapter error (the interval is NA on one side only); the rest switch
  admissible / neg_l2_var (a level-2 variance near 0 crosses 0) or between_identified. Likely mechanisms, not
  checked: lavaan's optimizer starts and stopping rule are not scale-free, and the fitted between-block ICC sits
  near the adapter's threshold.
- NA gaps: 19 datasets, of which 5 have identical flags (both sides errored the same way) and 14 are the switches.
- **Gap on the 1171 clean datasets with an estimate** (identical flags and indicators): median 1.3e-4 SE, 90th
  percentile 6.9e-4, 99th 4.4e-3, max 0.244 (cell 1065 rep 22, an inadmissible fit). 79 exceed the 1e-3 SE
  tolerance of the unit test (J = 50, ICC .4); outside the four boundary cells the max is 4.4e-3 SE. The gaps
  above 1e-2 (9 datasets) are all in the four boundary cells, 8 of them inadmissible fits.
  This is a separate finding: the estimate identity holds to optimizer precision, not to 1e-3 SE, across the
  J = 100 grid. No indicator flips on the clean set.

The rescale identity therefore holds wherever the fit is interior; flips come from near-boundary fits (likely lavaan's
optimizer), not from the harness truths, which scale exactly (`fc_truth(scale_x = )`,
tested with a planted unscaled-truth defect).

### Per-cell coverage (R = 500; coverage (MCSE) band)

| cell | n | ICC_X | sizes | nie_b | estimand | R | base | truth | narrow |
|---|---|---|---|---|---|---|---|---|---|
| 1005 | 5 | 0.05 | equal | 0.18 | c_prime_between | 500 | 0.684 (0.021) outside | 0.684 (0.021) outside | 0.678 (0.021) outside |
| 1005 | 5 | 0.05 | equal | 0.18 | c_prime_within | 500 | 0.910 (0.013) ambiguous | 0.764 (0.019) outside | 0.838 (0.016) outside |
| 1005 | 5 | 0.05 | equal | 0.18 | nie_between | 500 | 0.678 (0.021) outside | 0.672 (0.021) outside | 0.672 (0.021) outside |
| 1005 | 5 | 0.05 | equal | 0.18 | nie_contrast | 500 | 0.680 (0.021) outside | 0.684 (0.021) outside | 0.678 (0.021) outside |
| 1005 | 5 | 0.05 | equal | 0.18 | nie_within | 500 | 0.892 (0.014) outside | 0.604 (0.022) outside | 0.814 (0.017) outside |
| 1010 | 20 | 0.05 | equal | 0.18 | c_prime_between | 500 | 0.968 (0.008) ambiguous | 0.960 (0.009) ambiguous | 0.914 (0.013) ambiguous |
| 1010 | 20 | 0.05 | equal | 0.18 | c_prime_within | 500 | 0.950 (0.010) inside | 0.446 (0.022) outside | 0.890 (0.014) outside |
| 1010 | 20 | 0.05 | equal | 0.18 | nie_between | 500 | 0.958 (0.009) ambiguous | 0.914 (0.013) ambiguous | 0.916 (0.012) ambiguous |
| 1010 | 20 | 0.05 | equal | 0.18 | nie_contrast | 500 | 0.952 (0.010) inside | 0.972 (0.007) ambiguous | 0.916 (0.012) ambiguous |
| 1010 | 20 | 0.05 | equal | 0.18 | nie_within | 500 | 0.954 (0.009) inside | 0.072 (0.012) outside | 0.892 (0.014) outside |
| 1015 | 5 | 0.2 | equal | 0.18 | c_prime_between | 500 | 0.966 (0.008) ambiguous | 0.960 (0.009) ambiguous | 0.916 (0.012) ambiguous |
| 1015 | 5 | 0.2 | equal | 0.18 | c_prime_within | 500 | 0.938 (0.011) ambiguous | 0.856 (0.016) outside | 0.858 (0.016) outside |
| 1015 | 5 | 0.2 | equal | 0.18 | nie_between | 500 | 0.936 (0.011) ambiguous | 0.876 (0.015) outside | 0.876 (0.015) outside |
| 1015 | 5 | 0.2 | equal | 0.18 | nie_contrast | 500 | 0.948 (0.010) inside | 0.962 (0.009) ambiguous | 0.884 (0.014) outside |
| 1015 | 5 | 0.2 | equal | 0.18 | nie_within | 500 | 0.932 (0.011) ambiguous | 0.580 (0.022) outside | 0.850 (0.016) outside |
| 1020 | 20 | 0.2 | equal | 0.18 | c_prime_between | 500 | 0.956 (0.009) inside | 0.922 (0.012) ambiguous | 0.888 (0.014) outside |
| 1020 | 20 | 0.2 | equal | 0.18 | c_prime_within | 500 | 0.950 (0.010) inside | 0.482 (0.022) outside | 0.874 (0.015) outside |
| 1020 | 20 | 0.2 | equal | 0.18 | nie_between | 500 | 0.936 (0.011) ambiguous | 0.842 (0.016) outside | 0.866 (0.015) outside |
| 1020 | 20 | 0.2 | equal | 0.18 | nie_contrast | 500 | 0.942 (0.010) ambiguous | 0.930 (0.011) ambiguous | 0.884 (0.014) outside |
| 1020 | 20 | 0.2 | equal | 0.18 | nie_within | 500 | 0.940 (0.011) ambiguous | 0.074 (0.012) outside | 0.870 (0.015) outside |
| 1025 | 5 | 0.4 | equal | 0.18 | c_prime_between | 500 | 0.954 (0.009) inside | 0.930 (0.011) ambiguous | 0.888 (0.014) outside |
| 1025 | 5 | 0.4 | equal | 0.18 | c_prime_within | 500 | 0.946 (0.010) inside | 0.854 (0.016) outside | 0.880 (0.015) outside |
| 1025 | 5 | 0.4 | equal | 0.18 | nie_between | 500 | 0.946 (0.010) inside | 0.852 (0.016) outside | 0.876 (0.015) outside |
| 1025 | 5 | 0.4 | equal | 0.18 | nie_contrast | 500 | 0.954 (0.009) inside | 0.960 (0.009) ambiguous | 0.878 (0.015) outside |
| 1025 | 5 | 0.4 | equal | 0.18 | nie_within | 500 | 0.946 (0.010) inside | 0.646 (0.021) outside | 0.880 (0.015) outside |
| 1030 | 20 | 0.4 | equal | 0.18 | c_prime_between | 500 | 0.944 (0.010) ambiguous | 0.904 (0.013) ambiguous | 0.864 (0.015) outside |
| 1030 | 20 | 0.4 | equal | 0.18 | c_prime_within | 500 | 0.952 (0.010) inside | 0.506 (0.022) outside | 0.876 (0.015) outside |
| 1030 | 20 | 0.4 | equal | 0.18 | nie_between | 500 | 0.954 (0.009) inside | 0.854 (0.016) outside | 0.902 (0.013) ambiguous |
| 1030 | 20 | 0.4 | equal | 0.18 | nie_contrast | 500 | 0.956 (0.009) inside | 0.946 (0.010) inside | 0.912 (0.013) ambiguous |
| 1030 | 20 | 0.4 | equal | 0.18 | nie_within | 500 | 0.950 (0.010) inside | 0.106 (0.014) outside | 0.866 (0.015) outside |
| 1035 | 5 | 0.05 | unequal | 0.18 | c_prime_between | 500 | 0.632 (0.022) outside | 0.632 (0.022) outside | 0.626 (0.022) outside |
| 1035 | 5 | 0.05 | unequal | 0.18 | c_prime_within | 500 | 0.878 (0.015) outside | 0.798 (0.018) outside | 0.828 (0.017) outside |
| 1035 | 5 | 0.05 | unequal | 0.18 | nie_between | 500 | 0.616 (0.022) outside | 0.606 (0.022) outside | 0.610 (0.022) outside |
| 1035 | 5 | 0.05 | unequal | 0.18 | nie_contrast | 500 | 0.614 (0.022) outside | 0.626 (0.022) outside | 0.614 (0.022) outside |
| 1035 | 5 | 0.05 | unequal | 0.18 | nie_within | 500 | 0.878 (0.015) outside | 0.578 (0.022) outside | 0.802 (0.018) outside |
| 1040 | 20 | 0.05 | unequal | 0.18 | c_prime_between | 500 | 0.954 (0.009) inside | 0.958 (0.009) ambiguous | 0.906 (0.013) ambiguous |
| 1040 | 20 | 0.05 | unequal | 0.18 | c_prime_within | 500 | 0.956 (0.009) inside | 0.486 (0.022) outside | 0.874 (0.015) outside |
| 1040 | 20 | 0.05 | unequal | 0.18 | nie_between | 500 | 0.930 (0.011) ambiguous | 0.882 (0.014) outside | 0.874 (0.015) outside |
| 1040 | 20 | 0.05 | unequal | 0.18 | nie_contrast | 500 | 0.930 (0.011) ambiguous | 0.962 (0.009) ambiguous | 0.878 (0.015) outside |
| 1040 | 20 | 0.05 | unequal | 0.18 | nie_within | 500 | 0.954 (0.009) inside | 0.084 (0.012) outside | 0.886 (0.014) outside |
| 1045 | 5 | 0.2 | unequal | 0.18 | c_prime_between | 500 | 0.946 (0.010) inside | 0.928 (0.012) ambiguous | 0.872 (0.015) outside |
| 1045 | 5 | 0.2 | unequal | 0.18 | c_prime_within | 500 | 0.948 (0.010) inside | 0.824 (0.017) outside | 0.880 (0.015) outside |
| 1045 | 5 | 0.2 | unequal | 0.18 | nie_between | 500 | 0.952 (0.010) inside | 0.898 (0.014) ambiguous | 0.888 (0.014) outside |
| 1045 | 5 | 0.2 | unequal | 0.18 | nie_contrast | 500 | 0.950 (0.010) inside | 0.970 (0.008) ambiguous | 0.902 (0.013) ambiguous |
| 1045 | 5 | 0.2 | unequal | 0.18 | nie_within | 500 | 0.954 (0.009) inside | 0.620 (0.022) outside | 0.898 (0.014) ambiguous |
| 1050 | 20 | 0.2 | unequal | 0.18 | c_prime_between | 500 | 0.944 (0.010) ambiguous | 0.936 (0.011) ambiguous | 0.882 (0.014) outside |
| 1050 | 20 | 0.2 | unequal | 0.18 | c_prime_within | 500 | 0.940 (0.011) ambiguous | 0.454 (0.022) outside | 0.872 (0.015) outside |
| 1050 | 20 | 0.2 | unequal | 0.18 | nie_between | 500 | 0.922 (0.012) ambiguous | 0.820 (0.017) outside | 0.862 (0.015) outside |
| 1050 | 20 | 0.2 | unequal | 0.18 | nie_contrast | 500 | 0.938 (0.011) ambiguous | 0.948 (0.010) inside | 0.866 (0.015) outside |
| 1050 | 20 | 0.2 | unequal | 0.18 | nie_within | 500 | 0.944 (0.010) ambiguous | 0.094 (0.013) outside | 0.888 (0.014) outside |
| 1055 | 5 | 0.4 | unequal | 0.18 | c_prime_between | 500 | 0.952 (0.010) inside | 0.940 (0.011) ambiguous | 0.880 (0.015) outside |
| 1055 | 5 | 0.4 | unequal | 0.18 | c_prime_within | 500 | 0.948 (0.010) inside | 0.888 (0.014) outside | 0.904 (0.013) ambiguous |
| 1055 | 5 | 0.4 | unequal | 0.18 | nie_between | 500 | 0.932 (0.011) ambiguous | 0.866 (0.015) outside | 0.882 (0.014) outside |
| 1055 | 5 | 0.4 | unequal | 0.18 | nie_contrast | 500 | 0.940 (0.011) ambiguous | 0.946 (0.010) inside | 0.882 (0.014) outside |
| 1055 | 5 | 0.4 | unequal | 0.18 | nie_within | 500 | 0.940 (0.011) ambiguous | 0.606 (0.022) outside | 0.882 (0.014) outside |
| 1060 | 20 | 0.4 | unequal | 0.18 | c_prime_between | 500 | 0.934 (0.011) ambiguous | 0.906 (0.013) ambiguous | 0.854 (0.016) outside |
| 1060 | 20 | 0.4 | unequal | 0.18 | c_prime_within | 500 | 0.950 (0.010) inside | 0.436 (0.022) outside | 0.904 (0.013) ambiguous |
| 1060 | 20 | 0.4 | unequal | 0.18 | nie_between | 500 | 0.944 (0.010) ambiguous | 0.842 (0.016) outside | 0.884 (0.014) outside |
| 1060 | 20 | 0.4 | unequal | 0.18 | nie_contrast | 500 | 0.942 (0.010) ambiguous | 0.922 (0.012) ambiguous | 0.890 (0.014) outside |
| 1060 | 20 | 0.4 | unequal | 0.18 | nie_within | 500 | 0.946 (0.010) inside | 0.090 (0.013) outside | 0.910 (0.013) ambiguous |
| 1065 | 5 | 0.05 | equal | 0 | c_prime_between | 500 | 0.658 (0.021) outside | 0.658 (0.021) outside | 0.654 (0.021) outside |
| 1065 | 5 | 0.05 | equal | 0 | c_prime_within | 500 | 0.878 (0.015) outside | 0.818 (0.017) outside | 0.814 (0.017) outside |
| 1065 | 5 | 0.05 | equal | 0 | nie_between | 500 | 0.658 (0.021) outside | 0.656 (0.021) outside | 0.658 (0.021) outside |
| 1065 | 5 | 0.05 | equal | 0 | nie_contrast | 500 | 0.658 (0.021) outside | 0.656 (0.021) outside | 0.658 (0.021) outside |
| 1065 | 5 | 0.05 | equal | 0 | nie_within | 500 | 0.902 (0.013) ambiguous | 0.578 (0.022) outside | 0.842 (0.016) outside |
| 1070 | 20 | 0.05 | equal | 0 | c_prime_between | 500 | 0.938 (0.011) ambiguous | 0.936 (0.011) ambiguous | 0.880 (0.015) outside |
| 1070 | 20 | 0.05 | equal | 0 | c_prime_within | 500 | 0.946 (0.010) inside | 0.494 (0.022) outside | 0.872 (0.015) outside |
| 1070 | 20 | 0.05 | equal | 0 | nie_between | 500 | 0.992 (0.004) outside | 0.958 (0.009) ambiguous | 0.980 (0.006) ambiguous |
| 1070 | 20 | 0.05 | equal | 0 | nie_contrast | 500 | 0.990 (0.004) outside | 0.946 (0.010) inside | 0.972 (0.007) ambiguous |
| 1070 | 20 | 0.05 | equal | 0 | nie_within | 500 | 0.956 (0.009) inside | 0.078 (0.012) outside | 0.888 (0.014) outside |
| 1075 | 5 | 0.2 | equal | 0 | c_prime_between | 500 | 0.958 (0.009) ambiguous | 0.962 (0.009) ambiguous | 0.910 (0.013) ambiguous |
| 1075 | 5 | 0.2 | equal | 0 | c_prime_within | 500 | 0.972 (0.007) ambiguous | 0.872 (0.015) outside | 0.902 (0.013) ambiguous |
| 1075 | 5 | 0.2 | equal | 0 | nie_between | 500 | 1.000 (0.000) outside | 0.942 (0.010) ambiguous | 0.978 (0.007) ambiguous |
| 1075 | 5 | 0.2 | equal | 0 | nie_contrast | 500 | 0.994 (0.003) outside | 0.970 (0.008) ambiguous | 0.956 (0.009) inside |
| 1075 | 5 | 0.2 | equal | 0 | nie_within | 500 | 0.962 (0.009) ambiguous | 0.632 (0.022) outside | 0.888 (0.014) outside |
| 1080 | 20 | 0.2 | equal | 0 | c_prime_between | 500 | 0.940 (0.011) ambiguous | 0.936 (0.011) ambiguous | 0.886 (0.014) outside |
| 1080 | 20 | 0.2 | equal | 0 | c_prime_within | 500 | 0.938 (0.011) ambiguous | 0.520 (0.022) outside | 0.882 (0.014) outside |
| 1080 | 20 | 0.2 | equal | 0 | nie_between | 500 | 0.988 (0.005) outside | 0.718 (0.020) outside | 0.956 (0.009) inside |
| 1080 | 20 | 0.2 | equal | 0 | nie_contrast | 500 | 0.982 (0.006) ambiguous | 0.784 (0.018) outside | 0.916 (0.012) ambiguous |
| 1080 | 20 | 0.2 | equal | 0 | nie_within | 500 | 0.936 (0.011) ambiguous | 0.098 (0.013) outside | 0.868 (0.015) outside |
| 1085 | 5 | 0.4 | equal | 0 | c_prime_between | 500 | 0.952 (0.010) inside | 0.936 (0.011) ambiguous | 0.882 (0.014) outside |
| 1085 | 5 | 0.4 | equal | 0 | c_prime_within | 500 | 0.960 (0.009) ambiguous | 0.830 (0.017) outside | 0.878 (0.015) outside |
| 1085 | 5 | 0.4 | equal | 0 | nie_between | 500 | 0.990 (0.004) outside | 0.770 (0.019) outside | 0.950 (0.010) inside |
| 1085 | 5 | 0.4 | equal | 0 | nie_contrast | 500 | 0.976 (0.007) ambiguous | 0.886 (0.014) outside | 0.922 (0.012) ambiguous |
| 1085 | 5 | 0.4 | equal | 0 | nie_within | 500 | 0.956 (0.009) inside | 0.608 (0.022) outside | 0.880 (0.015) outside |
| 1090 | 20 | 0.4 | equal | 0 | c_prime_between | 500 | 0.948 (0.010) inside | 0.922 (0.012) ambiguous | 0.890 (0.014) outside |
| 1090 | 20 | 0.4 | equal | 0 | c_prime_within | 500 | 0.936 (0.011) ambiguous | 0.492 (0.022) outside | 0.856 (0.016) outside |
| 1090 | 20 | 0.4 | equal | 0 | nie_between | 500 | 0.982 (0.006) ambiguous | 0.664 (0.021) outside | 0.934 (0.011) ambiguous |
| 1090 | 20 | 0.4 | equal | 0 | nie_contrast | 500 | 0.980 (0.006) ambiguous | 0.724 (0.020) outside | 0.932 (0.011) ambiguous |
| 1090 | 20 | 0.4 | equal | 0 | nie_within | 500 | 0.942 (0.010) ambiguous | 0.078 (0.012) outside | 0.888 (0.014) outside |
| 1095 | 5 | 0.05 | unequal | 0 | c_prime_between | 500 | 0.674 (0.021) outside | 0.676 (0.021) outside | 0.664 (0.021) outside |
| 1095 | 5 | 0.05 | unequal | 0 | c_prime_within | 500 | 0.872 (0.015) outside | 0.774 (0.019) outside | 0.808 (0.018) outside |
| 1095 | 5 | 0.05 | unequal | 0 | nie_between | 500 | 0.676 (0.021) outside | 0.676 (0.021) outside | 0.672 (0.021) outside |
| 1095 | 5 | 0.05 | unequal | 0 | nie_contrast | 500 | 0.676 (0.021) outside | 0.676 (0.021) outside | 0.674 (0.021) outside |
| 1095 | 5 | 0.05 | unequal | 0 | nie_within | 500 | 0.878 (0.015) outside | 0.554 (0.022) outside | 0.818 (0.017) outside |
| 1100 | 20 | 0.05 | unequal | 0 | c_prime_between | 500 | 0.940 (0.011) ambiguous | 0.938 (0.011) ambiguous | 0.864 (0.015) outside |
| 1100 | 20 | 0.05 | unequal | 0 | c_prime_within | 500 | 0.952 (0.010) inside | 0.462 (0.022) outside | 0.880 (0.015) outside |
| 1100 | 20 | 0.05 | unequal | 0 | nie_between | 500 | 0.990 (0.004) outside | 0.938 (0.011) ambiguous | 0.972 (0.007) ambiguous |
| 1100 | 20 | 0.05 | unequal | 0 | nie_contrast | 500 | 0.990 (0.004) outside | 0.966 (0.008) ambiguous | 0.972 (0.007) ambiguous |
| 1100 | 20 | 0.05 | unequal | 0 | nie_within | 500 | 0.960 (0.009) ambiguous | 0.088 (0.013) outside | 0.894 (0.014) outside |
| 1105 | 5 | 0.2 | unequal | 0 | c_prime_between | 500 | 0.956 (0.009) inside | 0.952 (0.010) inside | 0.872 (0.015) outside |
| 1105 | 5 | 0.2 | unequal | 0 | c_prime_within | 500 | 0.950 (0.010) inside | 0.836 (0.017) outside | 0.872 (0.015) outside |
| 1105 | 5 | 0.2 | unequal | 0 | nie_between | 500 | 1.000 (0.000) outside | 0.936 (0.011) ambiguous | 0.978 (0.007) ambiguous |
| 1105 | 5 | 0.2 | unequal | 0 | nie_contrast | 500 | 0.992 (0.004) outside | 0.966 (0.008) ambiguous | 0.958 (0.009) ambiguous |
| 1105 | 5 | 0.2 | unequal | 0 | nie_within | 500 | 0.940 (0.011) ambiguous | 0.580 (0.022) outside | 0.882 (0.014) outside |
| 1110 | 20 | 0.2 | unequal | 0 | c_prime_between | 500 | 0.934 (0.011) ambiguous | 0.918 (0.012) ambiguous | 0.856 (0.016) outside |
| 1110 | 20 | 0.2 | unequal | 0 | c_prime_within | 500 | 0.926 (0.012) ambiguous | 0.458 (0.022) outside | 0.854 (0.016) outside |
| 1110 | 20 | 0.2 | unequal | 0 | nie_between | 500 | 0.992 (0.004) outside | 0.728 (0.020) outside | 0.944 (0.010) ambiguous |
| 1110 | 20 | 0.2 | unequal | 0 | nie_contrast | 500 | 0.988 (0.005) outside | 0.804 (0.018) outside | 0.936 (0.011) ambiguous |
| 1110 | 20 | 0.2 | unequal | 0 | nie_within | 500 | 0.932 (0.011) ambiguous | 0.096 (0.013) outside | 0.876 (0.015) outside |
| 1115 | 5 | 0.4 | unequal | 0 | c_prime_between | 500 | 0.954 (0.009) inside | 0.928 (0.012) ambiguous | 0.874 (0.015) outside |
| 1115 | 5 | 0.4 | unequal | 0 | c_prime_within | 500 | 0.964 (0.008) ambiguous | 0.862 (0.015) outside | 0.918 (0.012) ambiguous |
| 1115 | 5 | 0.4 | unequal | 0 | nie_between | 500 | 0.990 (0.004) outside | 0.752 (0.019) outside | 0.936 (0.011) ambiguous |
| 1115 | 5 | 0.4 | unequal | 0 | nie_contrast | 500 | 0.970 (0.008) ambiguous | 0.902 (0.013) ambiguous | 0.910 (0.013) ambiguous |
| 1115 | 5 | 0.4 | unequal | 0 | nie_within | 500 | 0.958 (0.009) ambiguous | 0.668 (0.021) outside | 0.894 (0.014) outside |
| 1120 | 20 | 0.4 | unequal | 0 | c_prime_between | 500 | 0.934 (0.011) ambiguous | 0.908 (0.013) ambiguous | 0.882 (0.014) outside |
| 1120 | 20 | 0.4 | unequal | 0 | c_prime_within | 500 | 0.950 (0.010) inside | 0.476 (0.022) outside | 0.888 (0.014) outside |
| 1120 | 20 | 0.4 | unequal | 0 | nie_between | 500 | 0.984 (0.006) ambiguous | 0.714 (0.020) outside | 0.950 (0.010) inside |
| 1120 | 20 | 0.4 | unequal | 0 | nie_contrast | 500 | 0.968 (0.008) ambiguous | 0.734 (0.020) outside | 0.932 (0.011) ambiguous |
| 1120 | 20 | 0.4 | unequal | 0 | nie_within | 500 | 0.942 (0.010) ambiguous | 0.090 (0.013) outside | 0.892 (0.014) outside |
