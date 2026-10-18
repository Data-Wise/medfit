# PROPOSAL: medfit 0.10.1 (brainstorm, 2026-10-14)

State at start: `dev` = `main` + docs audit + AIC/BIC guard (#206) + NEWS bullet (#210); 0.10.0 released (GitHub and r-universe only; CRAN has 0.3.2). Nothing below is decided.

## Quick Wins (< 30 min)

1. ~~`mbco_sem()` refit passes `fixed_x`~~ **already shipped** (`2d991da`, #178: `R/sem-mbco.R:152-160` passes the fit's fixed set to every refit). The V8 open-item note in `tasks/todo.md` was stale and is corrected in this revision. Revision per the Codex review (2026-10-14).
2. **Stamp the 0.10.1 header** in NEWS and DESCRIPTION at release prep (the #210 bullet sits under "development version").
3. **Triage the 3 skipped tests and 42 warnings** from the audit (Q9): list each, mark expected vs not. Read-only.
4. **Track the pandoc `--mathjax` deprecation** (Q6): one line in `.STATUS`; a future pandoc could break math site-wide.

## Medium Effort (1-2 hrs)

- [ ] **Covariate-mean term in the four-way variance** (Codex finding, chapter 7 Q-series). Add `(theta3 * gamma)^2 * Var(c) / n` to INT_ref, NDE and TE so the SEs are population-average. Decision needed: opt-in argument (default stays conditional, matches lavaan `:=` and the glm route) or new default. Effect on `mediation_demo` is about 0.08%, so default-conditional costs little. Oracle: nonparametric bootstrap SE.
- [ ] **Factor covariates in `fit_sem()`**: today a factor errors with "model variables must be numeric: g" and the user dummy-codes by hand. Option: expand with `model.matrix` before the fit (reference level dropped, names documented), or keep the error and point to the recipe. Touches the parse/materialize path, so needs the frozen gate and the product-column rules (a factor times a mediator is a product of several columns).
- [ ] **`bootstrap_mediation()` helper for four-way**: recipe 20 builds the `int_ref` statistic by hand. A small documented wrapper (or a recipe line) removes that boilerplate.
- [ ] **Doc-drift guard for error-message tables** (Q7): the Troubleshooting guard pins messages (#202); extend to the native model page's limits table.

## Long-term (future sessions)

- [ ] **0.11.0 latent means** (already planned after 0.10.x).
- [ ] **CRAN submission decision** — on hold per GRILL-0.8.0-release R1; triggers: probmed CRAN prep needs newer medfit, or a user report of the 0.3.2 bugs (#83). Before submitting: strict checks, `cran-comments.md` resync.
- [ ] **Categorical treatment in native four-way** (currently a two-level treatment contrast).
- [ ] **Guard for `AIC(sem_fit, lm_fit)`**: base-R dispatches on the first argument only, so a cross-class call that starts with an `lm` never reaches the SEMFit method. Documented limit; a real fix needs an S3 wrapper on `stats::AIC`, which is out of scope.

## Options compared (the one real decision)

| Option | Cost | Risk | Notes |
|---|---|---|---|
| A. Covariate-mean term, **opt-in** argument | S-M | Low | SEs unchanged by default; lavaan/glm parity kept |
| B. Covariate-mean term, **new default** | S-M | Medium | Changes SEs by about 0.08%; breaks parity with lavaan `:=`; needs a NEWS behavior note |
| C. Document only | XS | None | Already done (chapter 7, `?extract_mediation`) |

## Recommended Next Step

→ **Option A (covariate-mean term, opt-in) as the 0.10.1 content**, with the oracle the nonparametric bootstrap and no default result changed. On its own it is a thin patch release, so the real question is open question 2 below: tag 0.10.1 for this alone, or batch it with the next feature. Leave factor expansion for 0.11.0 unless you want the UX fix now.

## Open questions for the author

1. Opt-in argument name and default for the covariate-mean term (A vs B)?
2. Is a patch release worth tagging for the covariate-mean term alone (the `mbco_sem()` item is already shipped), or batch it into the next feature release?
3. Factor covariates: expand automatically, or keep the error plus the recipe?
