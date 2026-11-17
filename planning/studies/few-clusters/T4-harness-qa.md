# T4: harness QA (planted mutants and the X rescale)

Plan: `planning/PLAN-few-clusters-design-study-2026-11-16.md`, task T4. Date 2026-11-16.
Environment: R 4.6.2, lavaan 0.7.3, medfit 0.18.0.9000 installed from worktree SHA `50823235` into a scratch library.
Harness: `tests/sim/twolevel-few-clusters-lib.R` (`fc_coverage()`, `fc_band()`, `fc_rescale_x()`,
`fc_rescale_compare()`, `fc_truth(scale_x = )`); driver `tests/sim/twolevel-few-clusters.R` (new `SCALE_X`).
Tests: `tests/testthat/test-twolevel-few-clusters-harness.R` ("T4: ...").

## Verdict

**Stop rule S1 triggered.** Both mutants move every within-level cell (nie_within, c_prime_within) out of the band,
but at J = 100 several between-level and contrast cells stay inside (0.925, 0.975) under a mutant. Nothing was
weakened. The cause is design power plus a conservative baseline, not a harness defect (see "Why the mutants pass").

## Commands

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

## Definitions

- Coverage is unconditional: a row with an NA interval (adapter error, non-converged fit) counts as a miss.
  MCSE = sqrt(p (1 - p) / R).
- Band call: `outside` if the coverage is outside (0.925, 0.975); `ambiguous` if it is inside but within 2 MCSE of an
  edge; `inside` otherwise.
- Mutant `truth`: every truth shifted by +.05. Mutant `narrow`: every delta interval narrowed 20% about its center.
- Determinism check: the truth and narrow runs equal the base run in every column except their own (truths, or
  lo/hi). TRUE for both.

Baseline health (12000 rows): 0 lavaan errors, 121 adapter errors, 88 non-converged, 1060 inadmissible,
570 between-unidentified, 691 rows with an NA interval.

## Band calls (count of the 24 cells)

| Estimand | base amb/in/out | truth amb/in/out | narrow amb/in/out |
|---|---|---|---|
| nie_within | 13 / 8 / 3 | 0 / 0 / 24 | 2 / 0 / 22 |
| c_prime_within | 9 / 12 / 3 | 0 / 0 / 24 | 4 / 0 / 20 |
| nie_between | 9 / 3 / 12 | 6 / 0 / 18 | 9 / 3 / 12 |
| c_prime_between | 11 / 9 / 4 | 19 / 1 / 4 | 4 / 0 / 20 |
| nie_contrast | 10 / 5 / 9 | 11 / 4 / 9 | 12 / 1 / 11 |

Mutant cells called `inside` (the S1 cases):

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

## Why the mutants pass

1. **The truth shift is small against the between-level SE.** With a median between SE of .07 to .21, a .05 shift
   lowers nominal coverage only to .89 to .94; at R = 500 (MCSE about .01) that cannot leave the band reliably.
   The within estimands (SE .015 to .05) all leave it. The contrast truth also moves by .05 (checked in the CSVs),
   but its SE carries the between-level variance, so its predicted coverage is .89 to .94 and its truth-mutant calls
   (11/4/9) barely differ from base (10/5/9).
2. **The null between-level NIE is conservative.** With nie_b = 0 the delta interval for a product of two paths, one
   of them zero, over-covers (base .98 to 1.00). Narrowing it 20% brings it to about .95, inside the band.
3. **Some baselines are already far outside.** In n = 5, ICC_X = .05 cells (1005, 1035, 1065, 1095) base coverage of
   the between estimands is about .68, so a mutant "outside" there carries no information.

## Metamorphic rescale (X x 10)

Derivation: X = u + e, so X k scales both level components and leaves every ICC unchanged. At each level a and c'
become a / k and c' / k; b is unchanged. So every estimand (nie_within, nie_between, nie_contrast, c_prime_within,
c_prime_between) and its truth divide by k, and under ML invariance the delta interval divides by k exactly.
The adapter's ICC thresholds and `.twolevel_pair_equal()` (relative variance test) are scale-free.

Result over 1200 datasets (24 cells x reps 1 to 50):

- 1176 datasets have identical coverage indicators and flags. Median |k est' - est| / se = 1.3e-4; max 0.259.
- 24 datasets differ in a flag; 17 of them also flip at least one coverage indicator (nie_within 12, nie_between 8,
  nie_contrast 8, c_prime_within 12, c_prime_between 8 indicator flips in total).
- **All 24 are in the four n = 5, ICC_X = .05 cells** (1005, 1035, 1065, 1095), where the fit sits on a boundary.
  The flags that change: converged (lavaan's optimizer is not scale-free: its starts and convergence tolerance are
  absolute), admissible / neg_l2_var (a level-2 variance near 0 crosses 0), and between_identified (the ICC of the
  fitted between block straddles its threshold). 19 of the 24 are a converged or adapter-error switch, which makes
  the interval NA on one side only. No flag or indicator flips in the other 20 cells.

The rescale identity therefore holds wherever the fit is interior; flips come from lavaan's absolute optimizer
tolerances on near-boundary fits, not from the harness truths, which scale exactly (`fc_truth(scale_x = )`,
tested with a planted unscaled-truth defect).

## Per-cell coverage (R = 500; coverage (MCSE) band)

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
