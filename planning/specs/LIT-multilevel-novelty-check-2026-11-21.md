# Novelty check: which open multilevel questions could yield new results

> **Superseded in part (2026-11-21):** the open items of section 6 are closed in [LIT-multilevel-novelty-check-complete-2026-11-21.md](LIT-multilevel-novelty-check-complete-2026-11-21.md), which also lists corrections to this note.

**Date:** 2026-11-21 · **Status:** research note, docs only (no code, no release) · **Branch:** `dev` ·
**Builds on:** [LIT-multilevel-sem-gaps-2026-11-11.md](LIT-multilevel-sem-gaps-2026-11-11.md) (gaps G1 to G13, ideas I1 to I10)

This note records a targeted check of five candidate contributions that came out of the 2026-11-21 theory triage of
`PLAN-multilevel-remainder-2026-11-18.md`. It uses the same three labels as the 2026-11-11 review:

- **SOURCE**: a statement a source's text supports. The reading depth of each source is stated in section 2.
- **INFERENCE**: this note's reading, including every "no source found" claim (absence from a search is weak evidence).
- **UNVERIFIED**: a statement taken from a model-generated answer (NotebookLM or a fetch summary) that was not checked
  against the source text.

## 1. Verdicts

| # | Candidate | Verdict | What it would be |
|---|---|---|---|
| 1 | Sign-orthant structure of `a_w*b_w = a_b*b_b` and a global-optimum certificate (#504) | Supporting lemma, not a paper | A short lemma plus a software certificate. Nothing found on this structure (INFERENCE from one search). |
| 2 | LR/MBCO test of equal indirect effects across levels (IG3 T-B) | Incremental | A difference test exists (Rockwood thesis); no two-level MBCO with the nonlinear constraint found (INFERENCE). |
| 3 | LR law with a product null, a boundary level-2 variance and a level-specific statistic | Open, hard | The single-level law is known (UNVERIFIED sources, section 3). The joint extension is the open part (G3). |
| 4 | Small-J inference for between-level indirect effects (T6/T8) | Guidance and validation contribution; the grid itself is partly known | Honest failure accounting, the floor arm, the native two-level model class. Not new theory. |
| 5 | Individual versus spillover split of the 2-1-1 indirect effect | Reparametrization, not a theorem | An exact `decompose()` that takes cluster size, plus an assumptions note. |

Recommendation: do not write a stand-alone paper from candidates 4 or 5 yet. The only open theory question is the joint
boundary-variance LR law (candidate 3), and it should wait until #504 and IG3 settle.

## 2. Sources and how deeply each was read

| Source | Where | Depth | Used for |
|---|---|---|---|
| Hox et al. 2014, *Frontiers in Psychology* (PMC3912451) | web fetch | first ~40,000 of ~66,000 characters: methods, results, discussion | Candidate 4 |
| McNeish 2017, *SEM* | Zotero PDF | abstract and the simulation-design section; results tables not read | Candidate 4 |
| Li and Beretvas 2013, *SEM* | Zotero PDF | abstract and the inadmissible-solutions section; other sections not read | Candidate 4 |
| Cheng and Li, arXiv 2404.18256 v3 | web fetch (HTML to start of section 4.1) and the Zotero supplement | main text partly; supplement: outcome model (s6) and Remark 4 only (of 4,815 lines) | Candidate 5 |
| Tofighi and Kelley 2020; Tofighi 2020 | web search snippets | snippet only | Candidates 2 and 3 |
| Rockwood thesis; Lachowicz, Sterba and Preacher 2015 | web search snippets | snippet only | Candidate 2 |
| Bentler et al. 2011; Fukasaku et al. 2025 | Consensus abstracts | abstract only | Candidate 1 |
| Preacher 2015 survey | NotebookLM answer | not read (UNVERIFIED) | Candidate 5 |
| Chernoff 1954; Drton 2009 | NotebookLM answer ("LRT and PMED") | not read (UNVERIFIED) | Candidate 3 |

Not reached: the local Zotero library holds more (Preacher 2010 and 2011, Hox 2013, Blalock 1984, VanderWeele 2010),
all unread here. A cited arXiv preprint (2606.13305) surfaced in a search result could not be confirmed and is not cited.

## 3. Candidate 3: the product-null LR law

The "LRT and PMED" notebook (UNVERIFIED) gives the LR statistic for `H0: ab = 0` as `min(Z_a^2, Z_b^2)`. Away from the
origin it is chi-square(1). At the origin with independent path estimators the limiting rejection rate is `alpha^2`
(.0025 at .05); with correlated estimators it cites Drton's theory of LR tests under singularities. The `alpha^2`
figure follows from independence of `Z_a` and `Z_b`; this was checked algebraically, but the attributions to Chernoff
and Drton were not checked against the sources. The open part is unchanged from G3: the joint law when a level-2
variance sits on its boundary and the statistic is level-specific.

## 4. Candidate 4: how T6 compares

| | McNeish 2017 | Li and Beretvas 2013 | T6 (`studies/few-clusters/T6-results-memo.md`) |
|---|---|---|---|
| Model | 2-1-1 or 1-1-1 (which one not confirmed) | upper-level mediation with measurement error | 1-1-1 two-level, within and between indirect effects, contrast |
| Clusters | 10, 15, 25, 50, 100 | 20, 40, 80 | 10, 20, 30, 50, 100 |
| Balance | unbalanced | not read | equal and unequal |
| Intervals | delta, PRODCLIN, Monte Carlo | Empirical-M | delta and Monte Carlo |
| Failures | keeps only replications where all methods converged | reports inadmissible rates by G | explicit failure categories; unconditional and conditional coverage |
| Null cells | not confirmed | yes (`ab = 0` cells) | yes (`NIE_B = 0`) |
| Small-sample correction | REML with Kenward-Roger in the multilevel model | none | none (no Kenward-Roger or bootstrap arm; T7 dropped for this release) |

What stays distinct in T6: the failure accounting and the conditional-versus-unconditional split, the "missing intervals,
not bad intervals" result at the within level, the at-bound conservatism of the floor arm, and the native model class.
Whether T8's decision table raises this to a guidance paper is open.

## 5. Candidate 5: the individual and spillover split

In the Cheng and Li supplement the outcome working model (s6) is linear in the individual's own mediator and the mean of
the others' mediators, with treatment-specific coefficients `beta1_a` and `beta2_a`. Remark 4 concerns "bonus" robustness
and states no closed form for the individual or spillover effect (in the lines read). In that parametrization the
individual mediation effect is `a * beta1` and the spillover effect is `a * beta2` (INFERENCE, not stated in the source).

Relation to medfit's `(b_within, b_between)` for a cluster of size `n`, with the outcome mean
`b_within * (M_ij - Mbar_j) + b_between * Mbar_j`:

- `beta1 = b_within * (n - 1) / n + b_between / n`
- `beta2 = (n - 1) / n * (b_between - b_within)`
- individual + spillover = `a * b_between` exactly, for any `n`

So the `decompose()` rule "own = `a * b_within`, spillover = `a * (b_between - b_within)`" is the `n -> infinity` limit,
and the finite-`n` version needs the cluster size. This is a contextual-effect reparametrization (Blalock 1984 is in the
Zotero library, unread here), not a theorem. It was derived by hand and has not been run against `decompose()` or a
simulation.

Assumptions note: NotebookLM reports (UNVERIFIED) that the Preacher 2015 survey states that, in a 2-1-1 design with
within-cluster centering, the indirect effect exists only at the between-cluster level and the within slope is not part
of mediation. medfit's label "own = `a * b_within`" is an individual mediation effect only under the interference
counterfactual of Cheng and Li (the individual's own mediator shifted, others' held at control). The docs should state that
assumption, together with sequential ignorability and, for the spillover part, cross-world independence. The latent-mean
SEM route targets the true cluster mean and is a different estimand; that bridge remains open.

## 6. Open items

- Read McNeish's results tables and Li and Beretvas's remaining sections before calling the T6 grid new.
- Check the Chernoff 1954 and Drton 2009 attributions in the "Probability Asymptotic" notebook before citing them in the
  IG3 scope note.
- Check the decomposition in section 5 against `decompose()` and a small simulation before any code change.
- The serial (product-of-three) null at two levels (IG5s) was not searched.
- The #504 sign-orthant question (8 sign patterns, 4 reached by the certificate) is tracked in the `feature/504-twin-certificate`
  QA, not here.
