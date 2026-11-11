# Grill ledger: two-level (1-1-1) mediation, issue #394 (2026-11-10)

Target: `planning/specs/PLAN-multilevel-mediation-2026-11-10.md` section 9 (on branch
`claude/plan-multilevel-394-f40512`), with `RESEARCH-multilevel-mediation-2026-11-10.md` and
`LIT-multilevel-mediation-2026-11-10.md`. Every answer below was the recommended option; the maintainer
accepted each. Adverse review inputs: Codex review 1 (cluster-only covariates in the likelihood; promised
`bootstrap_mediation(x, cluster = )` cannot refit), review 2 (promised parametric call omitted `statistic_fn`), and
the literature review's five findings (contrast has no supporting source; fixed slopes differ from the random-slope
average `ab + sigma_ab`; latent vs manifest cluster means is a causal-story choice; no source for small-J, Heywood
or sandwich behavior; lavaan 0.7.3 already runs robust SE, FIML and a cluster bootstrap with `cluster =`).

| # | Question | Decision | Why |
|---|---|---|---|
| Q1 | Build order | Adapter first (guard, then lavaan adapter with the new class; native later) | Delivers the estimands and joint-covariance contrast in about 2 weeks; builds the class, generics, docs and tests native needs; lavaan serves as oracle for native; lavaan stays Suggests |
| Q2 | Class | One new `TwoLevelMediationData` for the adapter and the future native fitter, explicit level-qualified paths, `source` property | Matches D6 (1-1-1 class is new, not a `ClusterMediationData` extension); effects, covariance and docs are source-independent |
| Q3 | Estimand | `a_w*b_w` conditional on fixed slopes (`sigma_ab = 0` stated), latent cluster means for the between effect, manifest-mean option as a labeled alternative | Random-slope average is `ab + sigma_ab` (Kenny 2003, Bauer 2006); latent vs manifest means is a causal-story choice (Preacher 2010, Ludtke 2008) |
| Q4 | Contrast and `nie()` | `within - between`, documented as descriptive (delta method, joint covariance), not a test; `nie()` returns within by default, `level =` selects between or both | No read source supports the contrast as a named test; keeps the one-number expectation |
| Q5 | Treatment-by-mediator products | Refuse at both levels with a classed error in slice 1 | New four-way-style derivation and no oracle; consistent with D7/D13 and the R4 refuse-unadmitted rule |
| Q6 | Missing data | Adapter passes lavaan's `missing = "fiml"` through; native is listwise with loud row and cluster counts until a separate FIML milestone | lavaan accepted FIML with `cluster =`; medfit's FIML code is single-level |
| Q7 | Small J | Warn below 50 clusters, error below 10, documented as a judgment with editable constants | No source gives a threshold; Falk 2024 supports cluster resampling at 30-90 balanced normal clusters |
| Q8 | Heywood | Native `fit_sem()` errors (classed, ADR D-11); adapter flags `admissible = FALSE` with a warning | The adapter reports someone else's fit; a flag only protects consumers that check it |
| Q9 | S0 guard | Ship now as its own small PR: `extract_mediation(<lavaan>)` on a multi-level fit errors | Silent wrong-level extraction (N = total rows) is a correctness bug; the CLAUDE.md correctness exemption applies |
| Q10 | Release | Guard now; adapter in the next minor; native later; does not displace FIML admission | FIML admission waits on maintainer authorization, not engineering time |
| Q11 | Bootstrap API | (a) scalar `statistic_fn` callbacks in the public call for the parametric and the nonparametric/cluster routes; helper that builds the callback for within, between and contrast; end-to-end test of the exact public call incl. duplicate-cluster resamples; object-based dispatch (b) deferred as its own costed slice | Both Codex reviews: the object-based call cannot run today; (a) fits the function as it exists |

## Consequences for the plan

- Update plan sections 2, 3, 6 and 9 to these decisions; open questions are closed.
- Add the literature caveats to the docs plan: fixed-slope estimand, descriptive contrast, latent vs manifest means.
- Add to the S2 oracle list: lavaan `se = "robust.huber.white"`, `missing = "fiml"` and the cluster bootstrap as exposed options and as oracles.
- Add the cluster-only covariate fixture to S3 (Codex review 1) and the public-call bootstrap acceptance test to S2.
- Shared loadings across levels (Jak et al.) remain a testable restriction, not a default; needs a read before S5.

## S1 second grill (reopened after the Fable 5.2 adversarial review), 2026-11-10

All four answers were the recommended option (plan section 0.8 on branch `claude/plan-multilevel-394-f40512`).

| # | Question | Decision | Why |
|---|---|---|---|
| S1-Q1 | Degenerate between-level X or M | Within-only result: `between_identified = FALSE`, between paths and contrast `NA`, classed condition `medfit_between_unidentified`; triggers on ICC < 0.01, `NA` between SE, non-PD vcov or non-convergence; warning band at ICC < 0.05 | Centered or within-randomized X gives NA/huge between SEs or non-convergence; always erroring loses the valid within effects and a near-zero between variance would still slip through |
| S1-Q2 | `fixed.x` convention | Adapter reports and stores lavaan's setting; native two-level defaults to `fixed_x = FALSE` until a fixed-between-moment convention has an oracle; docs state the 3-4% narrower between SEs under `fixed.x = TRUE` | lavaan's between x variance under `fixed.x = TRUE` is not the ML estimate (0.681 vs 0.648 in one fixture) |
| S1-Q3 | Label shared across levels | Detect cross-level equality from the parameter table (shared free index), record `cross_level_equal`, contrast `NA` (constrained), keep within/between effects, key vcov rows by free index never by name | A shared label silently imposes equality (contrast 0 +/- 0, duplicate vcov names); refusing would block the intended shared loadings of S5 |
| S1-Q4 | `standardized = TRUE` | Refuse for two-level fits with a classed error | lavaan standardizes per level (0.312 vs 0.670 against raw 0.321, 0.690); a level-specific standardized estimand has no oracle |

Slice status after the second grill: S1 closed; S2 conditional GO once the review findings 1-6 are in the spec; S4 stays NO-GO until
tolerances and the fixed_x definition are in the spec; S5 stays NO-GO until the identification literature is read.

## Contrast and equality grill (maintainer, 2026-11-10 evening)

Both answers were the recommended option. They supersede S1-Q3's "contrast `NA` when a label is shared across levels" for the
one-equated case.

| # | Question | Decision | Why |
|---|---|---|---|
| C-Q1 | Contrast when only `a` or only `b` is equated across levels | The contrast is returned; it is `NA` (constrained) only when both `a` and `b` are equated | With one equated path the contrast is a(b_within - b_between), estimable and descriptive, with a delta-method SE from the joint vcov; it is exactly zero by constraint only when both are equated. The old comment "zero by constraint" was true only for that case |
| C-Q2 | Algebraic equalities (`a1 - a2 == 0`) | Detect numerically: `a` or `b` is recorded in `cross_level_equal` when its two alias rows of the joint vcov have \|correlation\| within 1e-8 of 1, as a third route beside the two label-based ones; docs state the tolerance and that a near-collinear pair can be flagged | Catches any form of equality, labeled or algebraic; without it a both-equated algebraic model shows a contrast of 0 with SE 0 as if it were an estimate |

Implementation (not started; for the next hardening or follow-up PR, test-first, with planted defects): `.twolevel_contrast_available()`
(`R/classes-twolevel.R`) becomes `isTRUE(between_identified) && !all(c("a", "b") %in% cross_level_equal)`; add the correlation
detector in the extraction (`R/extract-lavaan-twolevel.R`) with a test for `a1 - a2 == 0` in a fit and a planted near-collinear pair;
update `print`, `model-twolevel.qmd` ("contrast is descriptive"), the methods section, the troubleshooting row, `NEWS.md`, and the
`twolevel_statistic()` check that raises `medfit_error_twolevel_constrained`. Chapter 9 in the book repo mentions the contrast rule and
must follow.

### C-Q2 reopened after the Codex adversarial review (2026-11-10)

Codex (thread `01a1c8ae-dfda-7a11-8fa7-8d2f5b9cfb89`, verdict needs-attention) found that |correlation| near 1 does not imply equal paths: correlation
-1, or +1 between proportional unequal paths, would put both paths in `cross_level_equal` and silently turn an estimable contrast into `NA`.
Maintainer accepted the revision (recommended option). **C-Q2 now reads:** record `a` or `b` as equated when the estimated difference of its two
alias rows and the variance of that difference are both effectively zero (scale-aware tolerances set against the oracle fits); tests for
correlation -1, proportional paths and a just-inside-threshold unequal pair. C-Q1 is unchanged. The same review added: a b-only oracle for the
one-equated contrast SE, the book render against the release candidate as a release gate, and the full 0.16.0-style gate list in the release checklist.
