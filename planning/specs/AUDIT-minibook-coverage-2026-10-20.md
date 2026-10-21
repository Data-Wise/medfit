# Native-engine minibook coverage audit (2026-10-20)

Scope: the seven `native-book-*.qmd` chapters against this worktree's native SEM code, `NEWS.md`, `CLAUDE.md`, `R/sem-syntax-help.R`, and the native GRILL/PLAN/RESEARCH specs. Status describes coverage **before** this audit; † marks a gap filled in the chapters by this edit. Ranked by potential to mislead a reader. File:line points to the owning implementation or contract.

| Item | File:line | Chapter | Status | Suggested paragraph |
|---|---|---|---|---|
| † Optimum diagnostic and local-optimum limit | `R/sem-optim.R:460` | 3 | missing | Explain `unique`, `certified`, `agreed`, `disagreed`, `single`, and why agreement does not prove a global optimum. |
| † `anova()` nonzero fixed-row guard | `R/sem-anova.R:147` | 5 | missing | Explain why an unmatched nonzero fixed RAM row defeats nesting despite parameter counts. |
| † Boundary `p_valid` attribute | `R/sem-anova.R:75` | 5 | missing | Read the named `p_valid` flag; a boundary comparison retains a p-value but marks it invalid. |
| † Categorical covariate expansion and limits | `R/sem-syntax-help.R:60` | 6 | missing | Give dummy names and references, product expansion, and unsupported categorical roles. |
| † Nonlinear variance floor and extra starts | `R/sem-optim.R:285` | 3 | missing | Explain the relative floor, unconstrained and sign-flipped starts, and an active-floor warning. |
| † Native HC0 versus glm HC3 | `NEWS.md:520` | 5 | partial | Note that the native sandwich uses HC0 while the glm mediation engine defaults to HC3. |
| † Multiplier sign outcomes | `R/sem-constraints.R:616` | 3 | partial | Explain why active inequality signs warn and a wrong-side active bound rejects. |
| † Zero-product branch cap and fresh starts | `R/sem-fit.R:215` | 3 | partial | State that all factor combinations are tried from clean starts, with a 64-branch cap. |
| † Jacobi-scaled eigenvalue gate | `R/sem-optim.R:15` | 3 | partial | State the `1e-4` scaled-eigenvalue threshold alongside the decrement. |
| † Nonlinear Jacobian and Lagrangian curvature at solution | `R/sem-constraints.R:350` | 3 | partial | Say that active derivatives are refreshed and constraint curvature enters the reduced Hessian. |
| SLSQP natural units and unit-length rows | `R/sem-constraints.R:46` | 3 | documented | Keep the `x = theta/u` transformation and normalized linear-row example. |
| Independent equalities and implied inequalities | `R/sem-constraints.R:243` | 3 | documented | Keep the LICQ explanation and all-row acceptance check. |
| Acceptance status, residual, decrement | `R/sem-constraints.R:327` | 3 | documented | Keep the three gate checks and their failing examples. |
| Newton KKT polish | `R/sem-constraints.R:459` | 3 | documented | Keep the hand step and renewed acceptance-gate explanation. |
| Centered mean coordinates and shift refusal | `R/sem-fit.R:190` | 2 | documented | Keep the intercept constraint caveat and refused-shift example. |
| `fixed_x` moment treatment | `R/sem-fit.R:59` | 4 | documented | Keep full and selective fixed-moment examples. |
| Product grammar and supported rules 8/9 | `R/sem-syntax-help.R:92` | 6 | documented | Keep canonical naming, least-squares proof, and rule refusals. |
| Four-way extraction and weighted means | `R/extract-sem.R:1` | 7 | documented | Keep the hand component and weighted-covariate calculations. |
| Case-weighted ML and sandwich | `R/sem-sandwich.R:3` | 5 | documented | Keep weight rescaling, score construction, and likelihood limit for `anova()`. |
| Listwise deletion | `R/sem-fit.R:79` | 6 | documented | Keep the product-column and missing-row example. |
| Product model-test and expected-information limits | `R/sem-fit.R:153` | 6 | documented | Keep endogenous-factor refusal and exogenous-factor calibration example. |
| MBCO exact zero-product split | `R/sem-mbco.R:3` | 5 | documented | Keep one linear refit per factor and the minimum test statistic. |

No test file was changed. The table records the high-value audited contracts; it is not a claim that every internal helper has a reader-facing paragraph.
