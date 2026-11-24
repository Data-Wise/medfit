# T8: the U4 package (few-clusters design study)

Plan: `planning/PLAN-few-clusters-design-study-2026-11-16.md`, task T8 and section 7. Date 2026-11-23.
Inputs: `T6-cells.csv`, `T6-parametrization.csv`, `T6-p1-cells.csv`, `T5-cells.csv` (recorded results, not edited;
`T6-cells.csv` hashes to `4a3334bb...` as in the T6 manifest). Rerun: from the repository root,
`Rscript planning/studies/few-clusters/T8-tables.R` (no RNG; two runs give identical files). Every table below is
generated from the CSVs; `T8-tables.md` renders all of them. Per-dataset rows are outside git, so a quantity that
needs them is labeled INFERENCE or not available.

Scope. The study ran the delta and MC arms on 120 cells at R = 1000 and the P1 floor arm on 49 cells (T6). The
cluster-bootstrap arm (T7) was dropped on 2026-11-21 (plan section 12, M2); beyond the six T5 pilot cells it was
**not run**, so the M8 kept/B cutoff (.9) has no evidence outside those six cells. The P1 arm is a lavaan proxy for the
native S4 question (plan section 5, M5) and does not settle the native parametrization.

## Files

| File | Content |
|---|---|
| `T8-tables.R` | the aggregation script |
| `T8-per-cell.csv` | (a) one row per cell, P0: flags, failure categories, verdict, coverage (delta, MC; unconditional and conditional) |
| `T8-decision-table.csv`, `T8-decision-matrix.csv` | (d) verdict per (n, balance, ICC_X, J), worst of the two NIE_B cells, with cell ids |
| `T8-min-j.csv`, `T8-min-j-all-icc.csv` | (d) minimum grid J below each cutoff |
| `T8-verdict-vs-coverage.csv` | (d) failure verdict against the proposed coverage flag |
| `T8-p0-p1.csv`, `T8-p0-p1-summary.csv`, `T8-p0-p1-by-j.csv` | (b) P0 against P1 |
| `T8-threshold-evidence-by-j.csv`, `T8-threshold-evidence-by-icc.csv` | (c) adapter-threshold evidence |
| `T8-p1-selection.csv` | (e) the P1 selection rule against T6 |
| `T8-tables.md` | all tables rendered, cell table with flagged rows in bold |
| `T8-manifest-sha256.txt` | hashes of the inputs, the script and the outputs |

## (a) Per-cell table

`T8-per-cell.csv` (120 rows). Flags are display choices, not study cutoffs: `small_J` = J <= 20 (48 cells),
`low_icc` = ICC_X .05 (40 cells; implied ICC_M .039, below the adapter's `icc_warn` .05), `unbalanced` = unequal cluster
sizes (60 cells); 8 cells carry all three. `T8-tables.md` marks every flagged cell id in bold. Failure rate `rate_fail`
is the T6 definition: lavaan error + non-convergence + adapter error (within-only and inadmissible fits are not
failures; they are returned with an object or a warning).

## (b) P0 against P1 (49 P1 cells, delta interval)

Decision of 2026-11-23: a floor-bound fit is **reported with a warning, not scored as a failure**. The headline is P1
unconditional coverage (`coverage_p1`; a missing interval counts as a miss); beside it the at-bound rate
(`at_bound_p1`) and the coverage of floor-bound fits; `sens_coverage_p1` (an at-bound fit counts as a miss) is a
worst-case column only. Medians over the 49 cells (`T8-p0-p1-summary.csv`), delta interval:

| Estimand | P0 coverage | **P1 coverage** | At-bound rate, median [min, max] | Floor-bound coverage (INFERENCE) | Off-floor coverage (INFERENCE) | Sensitivity (worst case) | P1 conditional (`ccov_p1`) |
|---|---|---|---|---|---|---|---|
| NIE_W | .828 | **.940** | .70 [.203, .982] | .938 [.899, .960] | .943 | .282 | .939 |
| NIE_B | .639 | **.824** | .70 [.203, .982] | .727 [.628, .969] | 1.000 | .300 | .996 |

Failure rates over the same cells (`T6-parametrization.csv`, `rate_fail_p0`, `rate_fail_p1`): P0 median .108, P1
median 0 (maximum .003). By J, the NIE_B P1 coverage (median over the P1 cells at that J) is .9050 (J = 10), .7805,
.8530, .7430, .7990 (J = 100) (`T8-p0-p1-by-j.csv`, `cov_p1`).

Derivation (INFERENCE). Floor-bound coverage = (`coverage_p1` - `sens_coverage_p1`) / `at_bound_p1`; off-floor
coverage = `sens_coverage_p1` / (1 - `at_bound_p1`). It is valid because `sens_coverage_p1` is the share of all R
datasets with a covering interval and no at-bound variance (`T6-cells.csv` aggregation, `fc_t6_summary()`), so the
difference is the share of datasets that are both at the bound and covered. It uses recorded columns only, not the
per-dataset rows (outside git). It reproduces the 2026-11-23 decision's medians (NIE_W .94, NIE_B .73, range .63 to
.97). Two checks on the recorded columns:

- Within-level intervals exist for every P1 fit (`availability_p1` .9998 on average), so the NIE_W floor-bound figure
  is a coverage of fits with an interval.
- **Between-level intervals do not exist for within-only fits.** For P1, `availability` equals `rate_clean` and
  `1 - rate_within_only - rate_fail` exactly (49 cells, to 1e-9), and `ccov_p1` = `coverage_p1` / `availability`. So the
  NIE_B floor-bound .73 counts floor-bound within-only fits as misses; it is mostly the within-only rate, not the
  floor (INFERENCE, bounded next). `at_bound` is computed for every converged fit, within-only included (`fc_analyze()`), so those fits sit in
  its denominator. Bounding the within-only fits that are off the floor by (1 - `at_bound_p1`)(1 - `off_floor_cov`)
  (NIE_B: at most .039 of datasets in any cell, `w_off_max`), the coverage of floor-bound NIE_B fits that have an interval is between a
  median .992 (lower bound; minimum over cells .784) and .994 (upper bound; `floor_bound_with_interval_cov_lo` and
  `_hi` in `T8-p0-p1.csv`). INFERENCE.
- **`ccov_p1` (.993 to .997 for the between effects) is not a statement about fits off the floor.** It is over every
  clean P1 fit with an interval (converged, identified, admissible); with `rate_inadmissible` = 0 in P1, that includes
  every identified fit at the floor. Cell 1001: at-bound rate .982, within-only .328, `ccov_p1` .993, so at most .018
  of its datasets are off the floor. The recorded columns cannot split `ccov_p1` by floor status. The T6 memo's reading
  (the interval is wide enough to cover almost always when the floor binds) is consistent with the bound above; the
  plan's 2026-11-23 sentence that it "describes the fits off the floor" is not supported by the code or the columns
  (it is the off-floor figure, `sens_coverage_p1` / (1 - `at_bound_p1`), that is about 1.0 for NIE_B). The decision
  itself (report with a warning; headline P1 unconditional coverage) is unaffected. Flagged for the maintainer.

Reading. P1 removes the failures and lifts coverage, mostly by returning intervals where P0 returns none or an
inadmissible fit. A reported P1 fit that sits on the floor carries the warning; the at-bound rate is the share of
datasets that get it (median .70, up to .98 at J = 10 and ICC .05).

## (c) Evidence on the adapter thresholds (no change proposed)

From `T8-threshold-evidence-by-j.csv` and `T8-threshold-evidence-by-icc.csv`. The T6 fits ran under the model-implied
ICC rule (T6 SHA `f3e5e967`, 2026-11-18); the h1 rule decided on 2026-11-22 can differ on the within-only and weak
calls in about 2% of boundary-heavy datasets, so the within-only and weak-warning rates below describe the earlier
rule.

**50 clusters (`min_clusters`).** The few-clusters warning fires in .728, .865 and .926 of datasets at J = 10, 20, 30 and
never at J >= 50 (`warn_few_clusters_mean`; the rise below 50 may be fits that fail before reaching the check, which
needs per-dataset rows). Maximum P0 failure by J (`rate_fail_max`): .930, .789, .552, .314, .063 (J = 10 to 100),
driven by unequal n = 5. In the other groups: equal n = 20 .108, .054, .019, .003, 0; equal n = 5 .179, .160, .126, .097, .059;
unequal n = 20 .742, .271, .099, .008, 0. At J = 50 every group but unequal n = 5 is below .10. NIE_W delta unconditional coverage sits inside
(.925, .975) in 5, 10, 14, 17, 20 of 24 cells at J = 10 to 100 (`nie_w_cells_in_band`); conditional NIE_W coverage is near
nominal at every J (median .941 to .947, `ccov_nie_w_delta_median`), so the shortfall is availability. J = 50 is
therefore not where failure falls below 20% for unequal n = 5 (that needs J = 100, section (d)). For equal sizes
failure is under 20% at every grid J (under 5% from J = 30 for n = 20; never for n = 5 at ICC .05); unequal n = 20
needs J = 30 for 20% and J = 50 for 5%.

**ICC .05 and .01 (`icc_warn`, `icc_error`).** The grid has ICC_X .05, .20, .40 and no cell near .01 (M3 not adopted), so
the `icc_error` rule is observed only through sampling variation around a population ICC of .05. At ICC_X .05 the
within-only rate (`within_only_mean`) is .212 (.267 at J = 10, .142 at J = 100) against .028 and .003 at ICC .20 and
.40; the weak-between warning fires in .436 of datasets (`warn_between_weak_mean`) against .045 and .004. At ICC .05 the
between effects have unconditional NIE_B coverage .806 at J = 100 but conditional .991 (`cov_nie_b_delta_J100_median`,
`ccov_nie_b_delta_J100_median`): the between interval is rarely available (clean fits .687 at J = 100, `clean_J100`), and
more clusters do not remove that. At ICC .20 the within-only rate is .0003 at J = 100 and the two coverages agree (.962).

## (d) Decision table

Cutoffs (M8, fixed 2026-11-17): P0 failure rate (`rate_fail`) below 5% **use**, 5% to 20% **caution**, above 20% **do
not fit**. A cell is marked borderline when its rate is within 2 MCSE of a cutoff (a T8 display rule; `rate_fail_mcse`).
The kept/B < .9 cutoff applies only to the bootstrap arm, which was **not run** beyond the six T5 pilot cells (T7
dropped, 2026-11-21); the decision table is the delta/MC verdict only. For the six pilot cells, the mean kept refits
over 499 from the T5 memo table (not a CSV; the cutoff's statistic is not defined in the plan, so this is
illustration) are: NIE_W 1.000 (1024), .982 (1022), .914 (1004), .851 (1002), .914 (1021), .828 (1001); NIE_B 1.000,
.953, .623, .529, .767, .480. Below .9: NIE_W in 1002 and 1001; NIE_B in 1004, 1002, 1021 and 1001.

Verdict by (balance, n, ICC_X) and J, worst of the two NIE_B cells (`T8-decision-matrix.csv`; cell ids and both
rates in `T8-decision-table.csv`). U use, C caution, X do not fit, `*` borderline, then the worst P0 `rate_fail`:

| balance | n | ICC_X | J = 10 | J = 20 | J = 30 | J = 50 | J = 100 |
|---|---|---|---|---|---|---|---|
| equal | 5 | .05 | C* .179 | C .160 | C .126 | C .097 | C* .059 |
| equal | 5 | .20 | C .125 | C* .057 | U .031 | U .003 | U .000 |
| equal | 5 | .40 | U* .042 | U .004 | U .001 | U .000 | U .000 |
| equal | 20 | .05 | C .108 | C* .054 | U .019 | U .003 | U .000 |
| equal | 20 | .20 | U .012 | U .001 | U .000 | U .000 | U .000 |
| equal | 20 | .40 | U .000 | U .000 | U .000 | U .000 | U .000 |
| unequal | 5 | .05 | X .930 | X .789 | X .552 | X .314 | C* .063 |
| unequal | 5 | .20 | X .669 | X .297 | C .087 | U .020 | U .001 |
| unequal | 5 | .40 | X .325 | U* .046 | U .003 | U .000 | U .000 |
| unequal | 20 | .05 | X .742 | X .271 | C .099 | U .008 | U .000 |
| unequal | 20 | .20 | C .163 | U .007 | U .000 | U .000 | U .000 |
| unequal | 20 | .40 | U .028 | U .000 | U .000 | U .000 | U .000 |

Cell counts (`T8-per-cell.csv`, `verdict_failure`): 78 use, 24 caution, 18 do not fit; 9 are borderline (1001, 1005,
1035, 1065, 1067, 1072, 1081, 1095, 1112). All 18 do-not-fit cells are unequal-balance; 14 have n = 5. Equal-size cells
are never above 20%.

**Minimum J for unequal n = 5 (`T8-min-j.csv`, `T8-min-j-all-icc.csv`).** Smallest grid J at which every cell at that
J and above is below the cutoff, over all ICC levels and both NIE_B values: below 20%, **J = 100**, the grid maximum
(at J = 50 the worst cells are 1034 and 1094, .278 and .314); below 5%, **none on the grid** (J = 100 gives .060 for
cell 1035 and .063 for cell 1095, borderline). By ICC: ICC .05 below 20% at J = 100, never below 5%; ICC .20 below
20% at J = 30 and below 5% at J = 50; ICC .40 below 5% at J = 20 (cell 1112, .046, is borderline). The grid is
J = 10, 20, 30, 50, 100, so a minimum between two grid points is not resolved. Per the 2026-11-23 decision this guidance
does **not** recommend P1 for unequal n = 5. For information only: 16 of the 30 unequal n = 5 cells are P1 cells; their P1
failure rate is at most .003 and their at-bound rates are .284 to .956 (`T6-cells.csv`, `arm = p1`, `at_bound`).

**Coverage beside the failure verdict (a PROPOSAL for the maintainer; M8 fixes no coverage cutoff).** Unconditional
and conditional coverage are in `T8-per-cell.csv` (`cov_*` and `ccov_*`; conditional is `NA` below 100 clean fits).
Because unconditional coverage is availability times conditional coverage, it tracks the failure rate: of the 120
cells, none has NIE_W delta coverage of .925 or more while its failure verdict is caution or do not fit
(`T8-verdict-vs-coverage.csv`). A coverage rule of "NIE_W delta unconditional coverage at least .925, the lower end of
the nominal band at R = 1000" would downgrade 12 of the 78 use cells to caution (1007, 1012, 1013, 1021, 1044, 1052,
1056, 1073, 1081, 1084, 1104, 1112; coverage .886 to .924, MCSE about .008, so several are within one or two MCSE of the
edge). It is shown for the maintainer to adopt or drop; the verdicts above use failure only.

## (e) The P1 selection rule

P1 ran in the cells whose T5 pilot rate `inadmissible` (`T5-cells.csv`, replicates 1 to 500) exceeded .10 (M7, fixed on
2026-11-17 before T6): 49 cells, listed in `T6-p1-cells.csv`. That rate is the overlapping one: a fit counts whenever it is
not admissible, within-only fits included. `T6-cells.csv` carries the same definition on the T6 replicates as
`inadmissible_t5`, and `rate_inadmissible` is the exclusive category (identified and not admissible).
`T8-p1-selection.csv` compares them for all 120 cells:

- Under the selection's own definition, 49 selected cells stay above .10 in T6 (`t6_overlap`); none falls to .10 or
  below. One cell rises above: **1099** (J = 50, n = 20, ICC .05; T5 .098, T6 .107), which was not selected.
- Under the exclusive T6 rate, five selected cells fall to .10 or below: **1032, 1036, 1092, 1096, 1106** (T6 exclusive
  .092, .084, .092, .077, .096).
- The T6 memo's "six cells fall below .10" table (1032, 1036, 1092, 1096, 1099, 1106) compares the overlapping rate on T6
  data (its "T5" column, `inadmissible_t5`) with the exclusive T6 rate; it does not compare the pilot with T6, and
  1099 was never in P1. The memo carries a dated correction.
- **Cell 1106** (J = 10, n = 20, ICC .20, unequal): T5 pilot .102 (`T6-p1-cells.csv`; the memo's .104 is the T6 overlapping
  rate), T6 overlapping .104, T6 exclusive .096. Within about one MCSE (.013) of the cutoff on every definition:
  **borderline**; its P1 result stays valid as data.

## Maintainer items from T8

- The 2026-11-23 basis sentence about conditional coverage (section (b)) misreads `ccov_p1`; the decision stands.
- M9 (the gaps plan's Q8 and D-11 wording) is untouched; U4's "Q8 and D-11 unchanged" holds.
- The coverage proposal in section (d) is optional.
- T7 is later work, not a release gate (2026-11-21); there is no bootstrap evidence for the decision table beyond six
  cells.
