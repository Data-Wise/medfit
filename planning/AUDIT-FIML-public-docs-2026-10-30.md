# Bounded FIML public documentation audit

As of 2026-10-30, base `efbba665`; local audit for planned unreleased 0.16.
This is a source/content audit and local rendering receipt, not deployment or release clearance.

## Owning runtime contract

- `R/sem-fiml-interface.R:18-54`: exactly X -> M -> Y, free or exactly zero direct path, no extra topology, constraints, ties, starts, bounds or correlated disturbances.
- `R/sem-fiml-interface.R:94-113`: explicit random-X, mean structure, observed/model SEs, no weights, empty controls, three starts per solver; numeric plain columns. Numeric type checking does not prove a continuous Gaussian data-generating model or ignorable missingness.
- `R/sem-fiml.R:51-90`: retain any observed model component, drop only all-empty model rows; adapter subsets model variables before retention.
- `R/sem-fiml-interface.R:74-87` and `R/sem-fiml.R`: outcome binding, genuine accepted attempts, local numerical acceptance; no global-optimum or inferential-coverage guarantee.
- `R/methods-tidy.R` (`.glance_mediation_data`), `R/med.R` (`.quick_mediation_data`), `R/generics-effects.R` (`pm`): extracted FIML glance/quick/pm refusal. Source SEMFit glance retains likelihood/IC, with model tests unavailable (`R/methods-sem.R`).
- `R/bootstrap.R:207-208`, `R/methods-base.R:213`, `R/methods-sem.R:353`: object-aware bootstrap and non-normal-interval refusals; supported normal intervals are distinct. Opaque callbacks and external-first dispatch are outside package guard guarantees.
- `R/sem-mbco.R:128`, `R/compare-lr.R:342`, `R/sem-anova.R:18`: MBCO/comparison/model-test refusals before refits.

## Confirmed gaps and repairs

| Surface | Before | Repair |
|---|---|---|
| README | Short FIML summary omitted extracted quick/pm/glance exceptions and missingness/model conditions | Explicit bounded assumptions and source-fit/extracted-object distinction; link to authoritative guide |
| tidy/glance help | Unqualified glance promise and bootstrap recommendation for mediation classes | FIML exception; normal path/effect intervals retained; source SEMFit glance distinguished |
| bootstrap help | Lists supported mediation classes without inherited FIML exception | Object-aware FIML refusal including plugin, with callback boundary |
| quick and pm help | Lists MediationData without inherited FIML exception | Explicit refusal and supported-summary alternatives |
| mbco_sem and compare_lr help | No bounded FIML exception near entry-point contract | Explicit refusal before refit/external comparison |
| extraction article | Universal shared-interface statement included bootstrap | Operation-specific limits and exact FIML route distinction |
| interval guide | General bootstrap/MBCO recommendations lacked FIML qualification | Normal-only FIML inference exception and no coverage guarantee |
| Methods article | Says three numeric variables without continuous qualification | State continuous numeric variables, matching statistical model |

Roxygen changes regenerate the six affected Rd topics. No production expressions, exports, defaults, support guards, workflows or version pins change. Existing public-API FIML tests exercise the documented refusals; no implementation-mirroring prose test is introduced.

## Existing current public surfaces

| Surface | Disposition |
|---|---|
| `R/fit-sem.R`, `man/fit_sem.Rd` | Current comprehensive settings, assumptions, row retention, likelihood/IC, inference/refusals, ledger and limits |
| `R/fit-glm.R`, `man/fit_mediation.Rd` | Current engine_args routing and top-level se_type distinction |
| `R/sem-syntax-help.R`, `man/medfit-syntax.Rd` | Current listwise/general-syntax boundary and FIML subset |
| `R/classes.R`, `man/SEMFit.Rd` | Current unavailable discrepancy/test df and row-count semantics |
| `R/methods-sem.R`, `man/SEMFit-methods.Rd` | Current source-fit likelihood/IC, normal intervals and model-test limits |
| `book/index.qmd`, `book/chapters/08-fiml.qmd` | Current three continuous variables, Gaussian/ignorability conditions, opt-in, extraction, patterns/empty rows, local gates/refusals, checked exercise |
| `book/chapters/01-mean-structure.qmd` through `07-four-way.qmd` | Complete-data derivations explicitly scoped by preface; preserve completed teaching work |
| `NEWS.md` | Existing bounded milestone/current 0.16 inclusion preserved; add concrete generic-help clarification |

## Article-by-article inventory

Inventory searches cover FIML/full-information/missing-data/listwise and broad shared-interface/inference claims; topical pages are checked for routes that could imply FIML support. Already-scoped complete-data, other-engine and dated historical examples are preserved rather than rewritten. This is not a new numerical certification of every article.

| Article | Disposition |
|---|---|
| `bootstrap.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `computation-algorithms.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `cookbook.qmd` | Versioned recipes use complete-data/other-engine workflows; no FIML opt-in or broad FIML support claim. |
| `example-gpa.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `extraction.qmd` | Confirmed gap repaired above; affected article rendered locally. |
| `getting-started.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `guide-changes.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `guide-glossary.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `guide-intervals.qmd` | Confirmed gap repaired above; affected article rendered locally. |
| `guide-troubleshooting.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `introduction.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `lavaan-comparison.qmd` | Current explicit bounded-FIML/default-route or released-version distinction; unchanged. |
| `methods.qmd` | Confirmed gap repaired above; affected article rendered locally. |
| `model-cluster.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-glm-families.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-interaction.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-joint.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-lavaan.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-native-constraints.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-native-factors.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-native-latent.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-native-multi.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-native.qmd` | Current explicit bounded-FIML/default-route or released-version distinction; unchanged. |
| `model-parallel.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-regmedint.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-serial.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-simple.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `model-weights.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `models.qmd` | Current explicit bounded-FIML/default-route or released-version distinction; unchanged. |
| `native-defaults-0-15.qmd` | Current explicit bounded-FIML/default-route or released-version distinction; unchanged. |
| `native-guide.qmd` | Current explicit bounded-FIML/default-route or released-version distinction; unchanged. |
| `native-quickstart.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `native-tutorial.qmd` | Current explicit bounded-FIML/default-route or released-version distinction; unchanged. |
| `quality-control.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `refcard.qmd` | Explicitly describes 0.13.0; historical scope preserved, no FIML claim. |
| `syntax-crosswalk.qmd` | Topology/engine/default-route examples do not opt into bounded FIML; no confirmed FIML discrepancy in targeted audit. |
| `whats-new-0-11.qmd` | Dated 0.11 historical article; no FIML claim. |

## Verification and limits

Exact commands, source/package/artifact identities, example execution, local links, test/spelling results and API scan coverage are recorded in `_agents_workspace/fiml-docs-audit/docs.md`. No live-site currency claim is made. Main-only hosted coverage and deferred expensive CI remain unchanged. Release candidate checks, wider FIML models/inference, diagnostics APIs and missingmed adoption remain separate.
