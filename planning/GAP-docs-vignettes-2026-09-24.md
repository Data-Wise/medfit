# Documentation and vignette gap analysis (2026-09-24)

Scope: all Rd pages (from roxygen in `R/`), the four articles under
`vignettes/articles/`, `README.md`, and `_pkgdown.yml`, audited against the
code on `dev` at `2b05958`. Branch: `feature/docs-methods-math`.

Status key: **fixed** (in the #79 branch, or later directly on `dev` where a commit is cited) · **open** (not addressed).

## 1. Math documentation

| Gap | Status |
|---|---|
| No single place for the math across classes | **fixed**: new `vignettes/articles/methods.qmd` (Methods and Formulas): notation, every class's estimands, covariance per engine, delta-method gradients, bootstrap, engines, assumptions, verified references |
| INTref formula missing from `?InteractionMediationData` | **fixed** |
| Joint NDE formula missing from `?JointMediationData` | **fixed** |
| `?decompose`: no formulas, no example, no references, Joint method undocumented | **fixed** |
| Effect-extractor pages cover simple/serial only; `NDE = c'` wrong for interaction/joint | **fixed** |

## 2. Rd accuracy

| Gap | Status |
|---|---|
| `?extract_mediation` `@return` says always `MediationData` | **fixed** |
| lm/glm method arguments (`model_y`, `mediator_models`, `structure`, `decomposition`, `m_star`, `vcov_fun`) on no public page | **fixed**: listed in `?extract_mediation` |
| Hidden lm roxygen stale (`mediator_models` "serial only"; covariance "independent by construction") | **fixed** |
| `?extract_mediation_lavaan`: `decomposition`, `interaction`, `m_star` undocumented; `@return` omits interaction | **fixed** |
| `nde`/`te`/`pm` claim `BootstrapResult` support; phantom "CI attributes" in `@return` | **fixed** |
| `?SerialMediationData` calls `a*d*b` "the total indirect effect"; `te()`/`pm()` silently chain-only | **fixed**: docs in #79; `te()`/`pm()` now sum every path (#81) |
| `glance()`, `coef()`, `vcov()`, `confint()`, `nobs()` undocumented | **fixed**: `?tidy.S7_object` |
| `confint()` error advertises "specific parameter names" (unsupported) | **fixed** (message) |
| `?fit_mediation`: no link-scale caveat, no identity-link requirement for the four-way model, no references | **fixed** |
| `?bootstrap_mediation` never says intervals are percentile | **fixed** |
| `?med`: `boot = TRUE` behavior undocumented; `?quick` accepted classes | **fixed** |
| `?medfit-package` lists two classes | **fixed** |

## 3. Articles

| Gap | Status |
|---|---|
| getting-started: `confint(result, type = "effects")` silently returns path CIs | **fixed** (`parm =`) |
| getting-started / README: tidy output shows `NA` effect SEs | **fixed** (regenerated from a live run) |
| introduction: `BootstrapResult(converged = TRUE)` errors; `lavaan_fit` undefined; "three classes" | **fixed** |
| extraction: class lists stale; "multiple mediators" listed as future | **fixed** |
| extraction: parallel `cov(a_j, a_j') = 0` presented as by construction (contradicts the methods article) | **fixed** |
| bootstrap: accepted classes omit Joint; hand-rolled delta method with `cov_ab <- 0` | **fixed** (uses `confint(parm = "effects")`) |
| Stale "Development Status" phase lists (getting-started, introduction, README) | **fixed** |
| No worked example of `weights` / `se_type = "sandwich"` | **fixed** (`1f32a25`): getting-started "Case Weights and Robust Standard Errors" (stabilized IPW, live output) |
| No worked `tidy()`/`glance()` on parallel or interaction objects; no `decompose()` on a joint object | **fixed** (`1f32a25`, `2823952`): parallel and interaction `tidy()`/`glance()`, and joint `decompose()` with an `m_star` comparison (extraction article) |
| Articles are `eval: false` with hand-written output, so drift is never caught | **fixed** (`b888ffe`): articles evaluate at site build; pkgdown CI runs on PRs to dev. Turning it on caught 3 broken examples |

## 4. README / pkgdown

| Gap | Status |
|---|---|
| Feature and class lists omit parallel, interaction, joint, regmedint, weights/sandwich, `mediation_demo` | **fixed** |
| README tidy/glance/quick output stale | **fixed** (live run) |
| Relative `planning/` links do not resolve on the pkgdown home page | **fixed** (absolute GitHub URLs) |
| Methods article not in navbar or README | **fixed** |

## 5. Code findings surfaced by the audit (not fixed in a docs PR)

- `te()`/`pm()` for `SerialMediationData` added `c'` to the chain-only effect,
  so they were not the total effect when paths skip a mediator. **Fixed** in
  #81: they now sum every path; `nie(type = "total")` added.
- Four-way NDE ignored factor covariates in `E[M | X = 0, cbar]`. **Fixed** in
  #78 (design-column means, case-weighted when weights are supplied).
- lm/glm `@vcov` for parallel mediators omits `Cov(a_j, a_j')`; documented.
