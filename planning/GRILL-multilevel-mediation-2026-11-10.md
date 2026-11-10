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
