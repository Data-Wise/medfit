# PROPOSAL: documentation gaps after the factor-covariates merge (medfit dev, 2026-10-16)

**Scope:** delta audit on `dev` (`5885f8d`) after PR #215. The 2026-10-14 audit
(`planning/specs/PLAN-docs-audit-2026-10-14.md`, Batches 1-6 merged) is not repeated.
**Method:** `lib.docaudit` (signature checks pass: 11 of 22 exports checked, 11 variadic not checked; no
`error` or `warn` findings) plus grep of where factor covariates and recent options are documented.
Static only: no example was run and the live site was not fetched.

## Findings

| # | Gap | Where | Impact |
|---|---|---|---|
| G1 | Factor covariates (new in 0.11.0 candidate) have **no worked page**: only a Limits bullet, a cookbook-20 sentence, a refcard row and the `?"medfit-syntax"` section | `model-native.qmd`, `cookbook.qmd`, `refcard.qmd` | A user must read the Limits list to learn that `g` becomes `g_b`, `g_c` |
| G2 | The native entry pages never say categorical covariates work | `native-quickstart.qmd`, `native-tutorial.qmd`, `native-guide.qmd` ("Not covered: ... categorical outcomes") | Readers conclude they must hand-code dummies |
| G3 | `guide-glossary` has no entry for dummy, reference level or `g_b` naming; `guide-troubleshooting` lists none of the new factor errors (ordered factor, one level, invalid dummy name, `b*g`, constraint on a factor, `g:y` rule 8) | `guide-glossary.qmd`, `guide-troubleshooting.qmd` | The new messages are in `?"medfit-syntax"` only |
| G4 | `guide-changes` (what changed since CRAN 0.3.2) will not mention factor covariates, the opt-in covariate-mean variance, or the `AIC()`/`BIC()` refusal unless updated at release | `guide-changes.qmd` | Upgrader page goes stale at the 0.11.0 release |
| G5 | `models.qmd` capability table has no factor-covariate row | `models.qmd` | Page the Models menu opens on is silent |
| G6 | Scannability (info only): `methods.qmd` has 14 paragraphs over 110 words (up to 294); `native-book-2` section 5, `native-book-3` section 3 and `native-book-4` section 3 exceed 800 words with fewer than 3 H3s; `bootstrap.qmd` "Next Steps" is not last | those files | Dense, not wrong |
| G7 | Variadic exports (11 of 22) are not signature-checked | `fit_mediation()`, `bootstrap_mediation()`, ... | A wrong named argument in a doc call would pass |

## Offers (new material)

| Offer | Type | Effort | Why |
|---|---|---|---|
| A. **Cookbook recipe 21: a categorical covariate in a native fit** (fit, read `g_b`/`g_c` rows, label one dummy, `fixed_x = "g"`, the `g:m` product) | cookbook | ~1 hr | Closes G1, G2 with a runnable example the consistency tests already guard |
| B. **Model page `model-native-factors.qmd`** in the Models menu | vignette | ~2 hr | Longer treatment: reference levels, missing data, refits, four-way, the error table |
| C. **Troubleshooting and glossary rows** for the factor messages and terms | reference | ~30 min | Closes G3 |
| D. Release-time sweep: `guide-changes` and `models.qmd` rows | docs | ~20 min | Closes G4, G5; do at 0.11.0 prep, not before |
| E. Native tutorial step 10: "add a categorical covariate" | tutorial | ~1 hr | Closes G2 for learners; needs the tutorial's data (`mediation_demo` has no factor column) |
| F. Split the five longest `methods.qmd` paragraphs | prose | ~1 hr | Optional polish (G6) |
| G. Add a factor column to `mediation_demo` | data | decision | Would let every example above use bundled data; changes a shipped dataset and its known-answer tests, so a design decision |

## Recommendation

Do **A + C** together as one PR (about 1.5 hr; one Netlify-free GitHub Pages deploy). They close the two
discoverability gaps (G1-G3) with the least new surface. Hold **B** until A shows whether a page is needed, and
**D** until release prep. Decide **G** before **E**.

Cookbook examples need a factor: the data question (G) decides whether A builds one inline with
`transform(mediation_demo, group = ...)` or waits for a dataset change. Inline is fine for a recipe.
