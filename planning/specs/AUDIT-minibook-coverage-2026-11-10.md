# Native-engine minibook coverage audit (2026-11-10)

Scope: the eight `book/chapters/0N-*.qmd` chapters against the native SEM code and `NEWS.md` changes since the last audit
(`AUDIT-minibook-coverage-2026-10-20.md`). Method, as in that audit: list
`git log --since=2026-10-20 -- R/sem-*.R R/fit-sem.R R/extract-sem.R R/compare-lr*.R R/native-defaults.R NEWS.md`, decide for each
behavior change whether a chapter documents it (**documented**), documents part of it (**partial**) or does not (**missing**), and
fill the gaps. Status describes coverage **before** this edit; † marks a gap filled by this edit. File:line points to the owning
implementation or contract; the chapter column gives the chapter and, for a documented row, the line that carries it after this edit.
Chapters 9 and 10 and the preface are owned by other tasks (two-level and cluster chapters) and are not touched here.

| Item | File:line | Chapter | Status | Suggested paragraph |
|---|---|---|---|---|
| † `compare_lr()`: engine comparison, verdicts, evidence-only warnings (0.12.0, #278-#280); `fixed_x` and a saturated mean structure (0.14.0, #319, #321) | `R/compare-lr.R:344` | 5 (line 575) | missing | What the LR comparison is, the run statuses and verdicts, why it warns only on observed evidence, which models it accepts; a live run whose reference equals the hand statistic and lavaan's chi-square. |
| † Nonzero-product sign branches and `search_evidence` (0.16.0, #361) | `R/sem-nonzero.R:2`, `R/fit-sem.R:239` | 3 (line 378) | missing | Why `a*b == q` fits both signs; hand profile oracle; `charted` versus `local` coverage; a bound that proves one branch empty; charted is not a global certificate. |
| † Branch map and raw cap (D3, 0.14.1, #339) | `R/sem-outcomes.R:50` | 3 (line 344) | partial | The cap and "raw combinations" were stated; the map (`raw_count`, `factor_counts`, `unique_count`, IDs), its hand count and that it is not an equivalence certificate were not. |
| † Pinned parameter has exact zero SE under a mean structure (0.14.0, #315) | `R/sem-se.R:21` | 3 (line 1172) | partial | Pinned coordinates have an exactly zero covariance row was stated; that the same holds with a mean structure and that `tidy()` then gives `NA` statistic and p-value was not. |
| † Bound-slope floor `max(1e-12, 1e-10 * ‖g‖)` (0.12.0, #238) | `R/sem-constraints.R:351` | 3 (line 686) | partial | The inward-slope rejection was stated; the roundoff floor that keeps it from rejecting a correct fit was not. |
| Status -4 accepted, restoration and its capped rise (0.13.0, #276, #300) | `R/sem-constraints.R:552` | 3 (lines 579, 650, 659) | documented | Kept; `test-native-book.R` already pins the cap constant. |
| Unresolved `mbco_sem()` rows and failed refits (0.13.0, #300) | `R/sem-mbco.R:43` | 5 (line 617) | documented | Kept. |
| Dropped zero-product branch is a classed error (0.13.0, #303) | `R/sem-fit.R:325` | 3 (line 190) | documented | Kept, with the failed-branch ledger example. |
| Outcome ledger on fits, branches and MBCO (D1, 0.14.1, #336) | `R/sem-outcomes.R:410` | 3, 5 | documented | Kept. |
| Literal zero/nonzero certificates, `medfit_sem_infeasible`, `medfit_sem_empty_union` (D2, #338) | `R/sem-outcomes.R:96` | 3 (line 287) | documented | Kept. |
| Covariance-stage evidence `medfit_sem_covariance_error` and retained MBCO likelihood (D4, #340) | `R/sem-outcomes.R:241` | 5 (line 674) | documented | Kept. |
| Root-ledger validation, `medfit_error_ledger` (#342) | `R/sem-outcomes.R:490` | 5 (line 732) | documented | Kept. |
| Native defaults flip, `fixed_x` lenient subset, AIC and BIC counts (0.15.0, #347) | `R/native-defaults.R:8` | 1, 4 (line 577), preface | documented | Kept; every chapter pins the 0.14.x settings in its setup wrapper. |
| `options(medfit.native_defaults)` removed (0.16.0, #351) | `R/native-defaults.R` | 4 (line 620), preface | documented | Kept. |
| Constrained covariance: curvature, floors, tangent covariance, typed diagnostics (0.16.0, #358) | `R/sem-se.R` | 3 (line 1172), 5 | documented | Kept; guarded by the existing curvature test in `test-native-book.R`. |
| Bounded FIML, widened to covariates, parallel and serial forms; source-fit interval route withheld (#364, #379, #382-#392) | `R/fit-sem.R:200-235` | 8 (lines 21, 233, 292), preface | documented | Kept by pointer to the native guide; the chapter states "bounded, not statistically admitted" and no free-parameter counts. No numbers were added. |
| Internal refits pass `meanstructure` and `fixed_x` explicitly (R-6, #316) | `R/sem-mbco.R` | none | not needed | Internal plumbing that removed a spurious default-change warning; no reader-visible contract remains. |
| `medfit_warning_default_change` and the 0.14 opt-in | `R/native-defaults.R` | none | not needed | Retired in 0.15.0; the preface describes the current defaults. |
| Two-level lavaan extraction, `TwoLevelMediationData`, `twolevel_statistic()` (#394, #396-#403) | `R/extract-lavaan.R` | 9 | not in this task | Owned by the chapter 9 task. |
| Cluster 2-1-1 mediation | `R/extract-lmer.R` | 10 | not in this task | Owned by the chapter 10 task. |

Not verified in this audit (omitted from the chapters, left to the cited NEWS entries): the #320 counts of engine
statistics above medfit's reference (18 of 60, 13 of 60), the 557-row native-defaults oracle matrix, and any historical
gradient-norm figure for the #238 failure.

Evidence for the new paragraphs: `compare_lr()`'s reference equals the hand statistic `n * (F_r - F)` of the smaller linear refit and
lavaan's `chisq` for `a == 0` (17.5574) under the pinned settings and the 0.15.0 defaults; the nonzero-product discrepancies equal a
one-dimensional profile over `a` computed from `lm` residuals; the branch map equals a hand enumeration of the factor choices.
