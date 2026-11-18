# T6: few-clusters main run, results memo

Plan: `planning/PLAN-few-clusters-design-study-2026-11-16.md`, task T6. Date 2026-11-18.
Environment: Hopper array 4360337, R 4.4.0 on x86_64-pc-linux-gnu, lavaan 0.7.3, medfit 0.19.0.9000 installed from
worktree SHA `f3e5e967`. RNG L'Ecuyer-CMRG, seed `cell_id * 1e5 + rep`, replicates 501 to 1500 (disjoint from the T5
pilot's 1 to 500). MC B = 2000; P1 floor `eps` = 1e-3. Run instructions and metric definitions: `T6-README.md`.
Outputs: `T6-cells.csv` (one row per cell, arm, estimand and interval; 1,352 rows), `T6-parametrization.csv` (P0 and P1
side by side on the 49 P1 cells; 392 rows), `T6-manifest-sha256.txt`. The per-dataset rows stay outside git.

This memo reports results. The decision table and the U4 package are T8.

## Scope run

| Arm | Planned | Run |
|---|---|---|
| P0, lavaan defaults, delta and MC | 120 cells, R = 1000 | done: 120,000 datasets |
| P1, syntax floor on level-2 variances | cells with T5 inadmissible rate above 10% | done: 49 cells, 49,000 datasets |
| Cluster bootstrap (T7) | no-go until M2 is decided | not run |

Grid: J {10, 20, 30, 50, 100} x n {5, 20} x ICC_X {.05, .20, .40} x balance {equal, unequal} x NIE_B {.18, 0}.
Truths NIE_W = .20, NIE_B = .18 or 0.

## Acceptance check

| Criterion | Result |
|---|---|
| Every cell has R rows | yes: 1000 per cell and arm, 169,000 rows; 0 duplicated (rep, arm) keys |
| Failure categories add up | yes: lavaan_error + nonconverged + adapter_error + within_only + inadmissible + clean = R in every cell |
| MCSE reported | yes: `rate_fail_mcse`, `coverage_mcse`, `ccov_mcse`, `bias_mcse` in `T6-cells.csv`; `coverage_diff_mcse` in `T6-parametrization.csv` |

lavaan errors: 0. Coverage MCSE at p = .95 and R = 1000 is .0069, so the nominal band is (0.925, 0.975).

## Failure accounting (P0)

Mean category rate over cells, by J. `fail` = lavaan_error + nonconverged + adapter_error.

| J | nonconverged | adapter_error | within_only | inadmissible | clean | fail |
|---|---|---|---|---|---|---|
| 10 | .268 | .004 | .122 | .153 | .453 | .272 |
| 20 | .131 | .005 | .091 | .109 | .664 | .135 |
| 30 | .070 | .004 | .082 | .091 | .753 | .074 |
| 50 | .031 | .003 | .064 | .066 | .836 | .034 |
| 100 | .007 | .003 | .047 | .048 | .895 | .010 |

Largest failure rate in each J x (n, balance) group:

| J | n = 5 equal | n = 20 equal | n = 5 unequal | n = 20 unequal |
|---|---|---|---|---|
| 10 | .179 | .108 | **.930** | **.742** |
| 20 | .160 | .054 | **.789** | **.271** |
| 30 | .126 | .019 | **.552** | .099 |
| 50 | .097 | .003 | **.314** | .008 |
| 100 | .059 | 0 | .063 | 0 |

Cells per M8 band (failure below 5%, 5 to 20%, above 20%):

| Group | < 5% | 5-20% | > 20% |
|---|---|---|---|
| J = 10 | 8 | 8 | 8 |
| J = 20 | 14 | 4 | 6 |
| J = 30 | 16 | 6 | 2 |
| J = 50 | 20 | 2 | 2 |
| J = 100 | 20 | 4 | 0 |
| n = 20, equal | 27 | 3 | 0 |
| n = 20, unequal | 22 | 4 | 4 |
| n = 5, equal | 17 | 13 | 0 |
| n = 5, unequal | 12 | 4 | 14 |

Findings:

- **Unequal cluster sizes with n = 5 carry the failures.** 14 of the 24 cells above 20% are in that group; equal sizes
  never pass 20%. This confirms the T5 open item at R = 1000 and is the main input for the minimum-J advice.
- **Within-only and inadmissible are ICC-driven.** Mean within-only rate at ICC .05 is .266 (J = 10) to .142 (J = 100);
  at ICC .40 it is .015 at J = 10 and 0 from J = 30. Inadmissible at ICC .05 stays between .14 and .20 at every J, so
  more clusters do not cure a weak between level.
- Clean fits at ICC .05 are .080 (J = 10) to .687 (J = 100); at ICC .40, .792 to 1.000.

## Adapter warnings (evidence for U4(c), not a decision)

| J | few_clusters | between_weak | between_unidentified | inadmissible | lavaan warning | negative level-2 variance |
|---|---|---|---|---|---|---|
| 10 | .728 | .090 | .122 | .273 | .545 | .545 |
| 20 | .865 | .131 | .091 | .194 | .331 | .330 |
| 30 | .926 | .162 | .082 | .165 | .240 | .239 |
| 50 | 0 | .194 | .064 | .124 | .159 | .158 |
| 100 | 0 | .230 | .047 | .091 | .102 | .101 |

- The few-clusters warning fires below 50 clusters and never at J >= 50, as coded. Below 50 its rate rises with J,
  in step with the falling failure rate; a failed fit plausibly never reaches the warning (not checked per row).
- The between-weak warning also rises with J (.09 to .23). The likely reason is the same (more fits reach the check);
  T8 should confirm it on the per-dataset rows before reading it as a property of the warning.
- The lavaan warning and the negative level-2 variance flag agree to within .001: the lavaan warnings in this grid are
  Heywood cases.

## Coverage (P0)

Median over the 24 cells at each J, with [min, max] and the count of cells inside (0.925, 0.975). Unconditional
coverage counts a missing interval as a miss.

| Estimand, interval | J = 10 | J = 20 | J = 30 | J = 50 | J = 100 |
|---|---|---|---|---|---|
| NIE_W delta | .796 [.065, .953] 5 | .907 [.195, .955] 10 | .931 [.421, .965] 14 | .944 [.644, .961] 17 | .946 [.884, .963] 20 |
| NIE_W MC | .806 [.065, .958] 5 | .915 [.199, .957] 11 | .931 [.424, .967] 14 | .945 [.646, .960] 20 | .948 [.888, .966] 20 |
| NIE_B delta | .636 [.038, .989] 2 | .875 [.139, .995] 2 | .911 [.256, .999] 3 | .939 [.424, .995] 8 | .940 [.639, .998] 9 |
| NIE_B MC | .649 [.038, .971] 6 | .897 [.140, .987] 5 | .933 [.257, .990] 9 | .952 [.429, .986] 15 | .954 [.648, .984] 15 |
| Contrast delta | .647 [.038, .985] 4 | .885 [.138, .993] 5 | .915 [.257, .996] 3 | .942 [.424, .989] 9 | .946 [.640, .993] 13 |
| Contrast MC | .648 [.038, .966] 7 | .903 [.140, .981] 8 | .931 [.257, .987] 9 | .952 [.429, .989] 17 | .953 [.648, .978] 17 |
| c'_W delta | .808 [.067, .949] 5 | .911 [.206, .963] 10 | .939 [.425, .961] 14 | .944 [.646, .958] 20 | .949 [.889, .957] 20 |
| c'_B delta | .632 [.038, .881] 0 | .889 [.140, .932] 4 | .915 [.254, .946] 11 | .940 [.428, .969] 16 | .947 [.647, .963] 20 |

**Low unconditional coverage is missing intervals, not bad intervals, at the within level.** Over all P0 cells,
NIE_W delta coverage and the availability rate correlate at .999, and coverage divided by availability has median .944
(range .917 to .965). Conditional coverage over clean fits (J >= 50, where every cell has at least 100 clean fits):

| Estimand, interval | J = 50 | J = 100 |
|---|---|---|
| NIE_W delta | .947 [.920, .967] | .946 [.934, .963] |
| NIE_W MC | .949 [.928, .973] | .949 [.936, .967] |
| NIE_B delta | .992 [.913, 1.000] | .982 [.923, 1.000] |
| NIE_B MC | .985 [.929, 1.000] | .972 [.932, 1.000] |
| c'_B delta | .956 [.928, 1.000] | .953 [.933, 1.000] |

At J <= 30 at least one cell per J has fewer than 100 clean fits, so `ccov` is NA there; 11 NIE_B cells are NA in all.

**Between-level intervals over-cover when they exist.** NIE_B delta coverage by J x ICC:

| J | NIE_B = 0: ICC .05 / .20 / .40 | NIE_B = .18: ICC .05 / .20 / .40 |
|---|---|---|
| 10 | .229 / .724 / .947 | .224 / .708 / .897 |
| 20 | .465 / .908 / .993 | .459 / .887 / .909 |
| 30 | .596 / .964 / .995 | .601 / .907 / .927 |
| 50 | .730 / .990 / .994 | .715 / .927 / .929 |
| 100 | .834 / .990 / .984 | .793 / .939 / .931 |

Under the null (NIE_B = 0) the delta interval covers .98 to .99 once ICC >= .20: the product's delta SE is too large
near zero, the known behavior of the delta method at a product null. MC is closer to nominal (table above). Under
NIE_B = .18 the cells sit near or just below the band.

SE ratio (median model SE over empirical SD, delta), median [min, max]: NIE_W .99 [.85, 1.26]; c'_W .99 [.91, 1.26];
NIE_B .47 [.02, 1.80]; contrast .51 [.02, 1.74]; c'_B .55 [.03, 1.53]. The between-level ratios are pulled down by
cells where a few wild estimates inflate the empirical SD; they are not a usable summary at small J and are reported
for completeness only.

Bias: at J >= 50, |bias| / MCSE > 3 in one cell each for c'_B, c'_W, NIE_B and the contrast, and in none for NIE_W.
At J < 50 the only flagged estimand is NIE_W (4 cells). Relative bias per cell is in `rel_bias_median`.

MC: `mc_fail` is defined on the 507 MC rows (NIE_W, NIE_B, contrast); median .013, mean .159, max .962. The mean
is pulled up by the small-J, low-ICC cells; per-cell values are in `T6-cells.csv`. Median time per dataset: fit 1.12 to 1.22 s,
MC 0.11 s, flat in J.

## P1 (floor) against P0, 49 cells

Coverage difference P1 - P0 (delta), median [min, max]: NIE_W +.099 [.009, .740]; NIE_B +.216 [.016, .594];
contrast +.216 [.017, .593]; c'_W +.100 [.008, .754]; c'_B +.212 [.011, .574].

| | P0 | P1 |
|---|---|---|
| failure rate, median (max) | .108 | 0 (.003) |
| unconditional coverage, median: NIE_W / NIE_B / c'_B | | .940 / .824 / .813 |
| SE ratio, between level, median | .15 | .48 |
| fit time ratio P1 / P0, median [range] | | 0.6 [0.5, 5.7] |

The floor binds often: the share of P1 fits with a level-2 variance at the bound has median .70 (range .203 to .982).
Sensitivity coverage, which counts an at-bound fit as a miss, has median .28 to .30 per estimand. P1 conditional
coverage of the between effects is .993 to .997 at every J: when the floor binds the interval is wide enough to cover
almost always.

By J (NIE_B delta, medians over the P1 cells at that J):

| J | cells | P0 coverage | P1 coverage | P1 conditional | P1 sensitivity | P1 at bound |
|---|---|---|---|---|---|---|
| 10 | 17 | .618 | .905 | .994 | .190 | .804 |
| 20 | 12 | .615 | .781 | .997 | .332 | .656 |
| 30 | 12 | .785 | .853 | .995 | .519 | .475 |
| 50 | 4 | .484 | .743 | .996 | .150 | .851 |
| 100 | 4 | .657 | .799 | .993 | .299 | .699 |

Reading: P1 removes failures and lifts unconditional coverage, but most of the gain comes from fits that sit on the
floor and report conservative intervals. Whether an at-bound fit counts as a usable answer is the P1 question for the
maintainer (below); the sensitivity column is the answer under "no".

## P1 selection stability

P1 cells were chosen from the T5 inadmissible rate (> .10). Against the T6 rate: 44 agree above, 70 agree below,
6 cells fall below .10 in T6, none rise above it. The six are all unequal-balance cells:

| cell | J | n | ICC | T5 | T6 |
|---|---|---|---|---|---|
| 1032 | 20 | 5 | .05 | .169 | .092 |
| 1036 | 10 | 20 | .05 | .142 | .084 |
| 1092 | 20 | 5 | .05 | .155 | .092 |
| 1096 | 10 | 20 | .05 | .142 | .077 |
| 1099 | 50 | 20 | .05 | .107 | .078 |
| 1106 | 10 | 20 | .20 | .104 | .096 |

The T5 rates came from R = 500 (MCSE about .014 at .10), so the flips are within 1 to 5 MCSE; 1106 is borderline in
both runs. The P1 results for these cells stay valid as data; T8 should state the selection rule it uses.

## Notes for T8

- Build the decision table under the M8 cutoffs (failure 5% and 20%, kept/B below .9) from `T6-cells.csv`.
- Report unconditional and conditional coverage side by side; the within-level story is availability.
- Correct the T5 memo's scope table, which says "MC B = 1000"; the driver comment says T5 used 2000. Check the T5
  manifest before editing.
- State the P1 selection rule (T5 or T6 rate) and cite the six cells above.

## Open for the maintainer

- **M2** (bootstrap scope): T7 stays no-go until decided; T6 gives no new evidence on bootstrap cost.
- **M5** (identification ICC source): the within-only rate tracks the population ICC closely; the sample-ICC columns
  are in the per-dataset rows if T8 needs them.
- **P1 interpretation:** count an at-bound fit as a usable estimate (P1 coverage) or as a failure (sensitivity
  coverage)? The two answers differ by about .5 in coverage, so S4b's floor-versus-unconstrained choice depends on it.
- **Unequal n = 5:** P0 failure above 20% up to J = 50 in this design; decide whether the guidance names a minimum J
  for unequal small clusters or recommends P1 there.
