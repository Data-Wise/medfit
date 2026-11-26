# Local-only tier for the heaviest tests and gates (2026-11-26)

Decision (maintainer, 2026-11-26): "disable shard-1 gate twolevel-equal-size alone takes 28 to 53 minutes for cran and
github; only local run; do the same for other time consuming tests; run then locally". This overrides the "no coverage
given up on release" line of `PLAN-ci-test-speed-2026-11-25.md` for the items below only.

**Rule.** An item is local-only when it alone costs more than about 300 s on a hosted runner. Seconds are measured, not
estimated: gates from `tests/sim/gate-seconds.csv` (median of four hosted runs, 2026-11-24 to 26; file arrives with
PR #561), test files from T0 of the CI test-speed plan (probe run 45728692964, ubuntu-24.04, `NOT_CRAN=true`).

| Kind | Item | Hosted seconds |
|---|---|---|
| gate | `twolevel-equal-size` | 1868 |
| gate | `twolevel-mbco-size` | 542 |
| gate | `four-way-kat` (script `four-way-known-answer.R`) | 348 |
| test | `test-fiml-g3-serial-two-cov.R` | 418 |
| test | `test-twolevel-equal-indirect.R` | 388 |
| test | `test-sem-fiml-oracles.R` | 380 |
| test | `test-twolevel-icc-h1-qa.R` | 344 |
| test | `test-twolevel-few-clusters-harness.R` | 340 |

Next below the line (not moved): `test-fiml-g3-serial-two-cov-defects.R` 277 s, `test-fiml-g3-parallel-covariates.R`
237 s, `product-fixed-var-colon` gate 137 s, `factor` 131 s, `product-fixed-var` 129 s. T0 published seconds only for the
eight slowest files; files not named there are below 182 s.

**Mechanism.** Tests: `skip_unless_local()`. Gates: `tests/sim/gates-local-only.txt` plus `run-gates.R --local-only`.
**Safeguards.** (1) `qc-monthly` passes `--local-only`: the monthly OpenBLAS run keeps all three gates. (2) The local
full run `scripts/check-local-full.sh` writes a receipt; a release needs a green receipt for the release commit.
(3) Gates workflow dispatch input `local_only` (follows PR #561's workflow edit). **Not verified on hosted CI any more:**
the OpenBLAS-runner result of the three gates on PRs to `main`, and the cross-platform (ubuntu, macOS, Windows) runs of
the five test files.
