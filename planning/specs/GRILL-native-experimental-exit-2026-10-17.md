# GRILL: exit criteria for the native engine's "experimental" label (0.11.0 plan T5)

**Status:** DECIDED 2026-10-17 by the author. Criteria file: `CRITERIA-native-experimental-exit-2026-10-17.csv`
(checked by `tests/testthat/test-experimental-criteria.R`). The label stays "experimental" in 0.11.0 (plan D3); it
drops at the first release where every criterion below holds and the author says so.

## Criteria

| Id | Criterion | Evidence |
|---|---|---|
| C1 | No open correctness issue on the native engine | `gh issue list --label correctness --state open` is empty. At decision time #213 is the only engine issue; its fix merged (#221) and it closes with the 0.11.0 release. |
| C2 | Every native gate registered and green | The 17 native gates in `tests/sim/gates.csv`; `Rscript tests/sim/run-gates.R` passes. `s7-lifecycle` (a package check) and `bootstrap-coverage` (the parametric bootstrap, added by T6c) are not native gates. |
| C3a | lavaan parity | `parity`, `fixed-x`, `factor` |
| C3b | OpenMx parity | `constrained`, `nonlinear-parity`, `nonlinear-profile` |
| C4a | API freeze, signatures | `fit_sem()`, `mbco_sem()`, `SEMFit` (properties), `extract_mediation(<SEMFit>)` |
| C4b | API freeze, grammar | the model syntax in `?medfit-syntax` |

## Decisions

- **G1 gate scope (D-T5-1):** register the three native gates that had no row (`nonlinear-parity`, `fixed-x`,
  `mean-constrained`); leave out `sem-mbco-k-size.R` (a sizing study with no pass/fail rule) and `coverage-2-1-1.R`
  (cluster mediation, not the native engine).
- **G2 freeze means signatures and grammar, not results (D-T5-2):** a numerical fix is not a break; renaming an
  argument, a `SEMFit` property or a syntax token is. SEMFit methods' output columns, `medfit.*` options and condition
  classes are not frozen by this list.
- **G3 the list cannot rot:** C2's gate set is compared with `gates.csv` in both directions, so adding or deleting a
  native gate without updating the criteria fails the test.

## Not decided here

Dropping the label (a release decision), the RMediation message (the author pastes it), and whether S7 1.0 forces a
CRAN submission (D1 of the 0.11.0 plan).
