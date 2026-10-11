# PROPOSAL: more articles for the medfit site

**Status:** decided 2026-10-10 (see Decision below); nothing built.
**Context:** PR 1 adds the Models menu and 8 model pages; PR 2 adds 6 more (cluster, lavaan, three native pages, native extras). This list is what could come after, or alongside. Each idea says what it would hold, where the content already lives, and what it costs.

## What the site has and lacks

| Reader question | Covered by | Gap |
|---|---|---|
| "How do I run model X?" | Models pages, Cookbook | being closed by PR 1 and PR 2 |
| "Which interval should I use?" | Bootstrap article (method by method) | no decision page that compares all interval types |
| "I got an error. What now?" | nothing | 191 `stop()` calls in `R/`, none explained outside the help |
| "I use CRAN 0.3.2. What changed?" | NEWS (900 lines) | no migration page; two results changed (serial `te()`/`pm()`, `confint()` paths) |
| "How do I report this?" | nothing | no write-up or table guidance |
| "What do NIE, CDE, INTref mean?" | spread over Methods | no glossary |
| "How do I plot it?" | nothing | no plotting page; `ggplot2` is not a dependency |
| "What is in `mediation_demo`?" | `?mediation_demo` only | no tour with the known true values |

## Quick wins (under 30 minutes each)

1. **Glossary and symbols** — NIE, NDE, TE, PM, CDE, INTref, INTmed, PIE, `a`, `b`, `c'`, `m_star`; one table, each term linked to its model page. Content exists in Methods and the model pages.
2. **Tour of `mediation_demo`** — the 8 variables, which are confounders, which outcome goes with which model, and the true structure it was simulated from. Content is in `R/data.R` and `data-raw/`.
3. **Find your model as a flowchart** — a decision diagram on the Models landing page (ask: one mediator or several? product term? clusters? latent?) leading to a page. Pure presentation, no new claims.

## Medium effort (1-2 hours each)

| # | Article | What it holds | Source | Risk |
|---|---|---|---|---|
| 4 | **What changed since CRAN 0.3.2** | the behavior changes in 0.4.0 to 0.7.0 as a migration list: serial `te()` and `pm()` now sum every path, `confint(parm = "paths")` finds rows by name, the `model` argument, new classes | NEWS, pinned issue #83 | low; every item already verified in NEWS |
| 5 | **Troubleshooting: errors and warnings** | the 15 to 20 messages a user is most likely to hit, each with its cause and fix (row mismatch in joint models, `offset()` in `lmer`, treatment not 0/1, non-Gaussian four-way, too few clusters, `na.exclude`) | `stop()` and `warning()` text in `R/` | medium; wording must track the code, so add a test that each quoted message still exists |
| 6 | **Which interval? Delta, parametric, nonparametric, plugin, Kenward-Roger** | one decision table by model type and sample size, with a runnable comparison on one dataset | Bootstrap article, Methods, cluster evidence | medium; avoid claiming coverage the tests do not show |
| 7 | **Reporting your results** | how to read NIE, NDE, TE and PM; a results table from `tidy()`; a model sentence; what to state about assumptions | model pages, Methods | low |
| 8 | **Plot your results** | a forest plot of effects and a histogram of bootstrap draws, in base R, with an optional `ggplot2` version behind an `eval` guard | `tidy()`, `BootstrapResult@boot_estimates` | low; no new dependency if base R is used |
| 9 | **Missing data and `na.action`** | listwise deletion, why `na.exclude` needed a fix (0.8.0), what each engine does with missing values | `NEWS`, #128 | low |
| 10 | **Native syntax guide** | a gentle walk through `?"medfit-syntax"`: labels, constraints, `:=`, `CONSTRAINT()`, the comma-shorthand difference from lavaan | `R/sem-syntax-help.R` | low; overlaps PR 2 pages 11-14, so write it as their shared reference |

## Long-term (future sessions)

| # | Article | Why it waits |
|---|---|---|
| 11 | **From other tools** — lavaan, the `mediation` package, RMediation, PROCESS — a side-by-side of the same model in each | needs the other packages installed and outputs checked against them; strongest as a comparison, weakest if one tool's numbers drift |
| 12 | **Cluster designs in depth** — when 2-1-1 applies, few clusters, Kenward-Roger versus the cluster bootstrap, what the own and spillover split means | the evidence for the cluster bootstrap on this design is thin (the methods article says so); write after more simulation |
| 13 | **Simulation studies with medfit** — repeating a fit over simulated data, a coverage check, links to `medsim` | depends on `medsim`'s state |
| 14 | **Build on medfit** — a developer guide for dependents: the S7 classes, `extract_mediation()` methods, `@vcov` alias rows, the bootstrap hooks (what probmed does) | audience is small; useful to the ecosystem and to the maintainer |
| 15 | **Teaching with medfit** — a short lesson plan and exercises on `mediation_demo` | lowest priority; outside the package's stated purpose |
| 16 | **FAQ** | assemble last, from the questions that actually arrive |

## Ranking

| Rank | Article | Impact | Effort | Why |
|---|---|---|---|---|
| 1 | **#4 What changed since CRAN 0.3.2** | high | 1 h | CRAN stays on 0.3.2, two results changed, and the README already warns about it |
| 2 | **#5 Troubleshooting** | high | 2 h | the only page a user lands on after a failure |
| 3 | **#6 Which interval?** | high | 2 h | the question after every fit, and the answer is currently spread over three articles |
| 4 | #1 Glossary | medium | 20 min | every other page links to it |
| 5 | #2 `mediation_demo` tour | medium | 25 min | makes every example reproducible by sight |
| 6 | #8 Plot your results | medium | 1.5 h | a showcase page, no new dependency |
| 7 | #7 Reporting | medium | 1.5 h | |
| 8 | #3 Flowchart | medium | 25 min | |
| 9 | #9, #10 | low | 1-2 h | |

## Conventions for every new article

- Quarto article under `vignettes/articles/`, named for its job (`guide-*.qmd` for how-to and reference pages, `model-*.qmd` for model pages).
- The same front matter and a facts table at the top; short sections; one recommended path first; a "Limits" section.
- Code runs at site build; suggested packages behind `eval:` guards; low `n_boot`.
- Added to the `articles:` index, the menu, `.rforge.yaml` and the consistency test in the same PR.
- A claim that a message, argument or number appears in the package gets a test or a rendered check, as the model pages do.

## Recommended next step

Start with **#4 What changed since CRAN 0.3.2**, then **#5 Troubleshooting** and **#6 Which interval?**, as one PR of three pages under a new "Guides" group in the menu. They answer the three questions a reader asks after the first run (what changed, why it failed, which interval) and each is checkable against NEWS or the code. Add the glossary in the same PR, because all three link to it.

## Decision (2026-10-10, the author took the recommendation)

The three-page **guides PR** is next after PR 2, in this order of PRs:

1. **PR 1** (in progress, branch `docs/model-pages`): navbar menus, the Models landing page and the first 8 model pages, then the home page and Getting Started rewrite once `docs/readme-outputs` merges.
2. **PR 2**: the cluster and structural equation model pages (pages 9-14 of the gap analysis).
3. **Guides PR**: **What changed since CRAN 0.3.2**, **Troubleshooting**, and **Which interval?**, as a new "Guides" group in the menu and the articles index, plus the **Glossary** they all link to.

Everything else in this proposal stays on the list, unscheduled. Each guide gets the conventions above, including a test or rendered check for every quoted message, argument or number.
