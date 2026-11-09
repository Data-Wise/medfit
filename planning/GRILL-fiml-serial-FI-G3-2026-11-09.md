# GRILL: serial FIML (FI-G3) open questions, 2026-11-09

Target: `planning/specs/SPEC-fiml-serial-FI-G3-2026-11-09.md` section 8. Interrogated one question at a time with the maintainer; a Recommended answer was offered for each. Two answers override the recommendation (Q1, Q2) and enlarge the scope.

| # | Question | Decision | vs recommendation | Consequence |
|---|---|---|---|---|
| Q1 | Shortcut policy | Admit the saturated graph (a2, b1 free; only X->Y fixable) AND the pure chain (a2 = b1 = 0) | overrides (rec: saturated only) | Plan registry needs an amendment; variants roughly double (about 6); the pure chain is overidentified (df 2 with a free direct path), so the saturation oracle covers only the saturated variant and the chain needs lavaan/OpenMx oracles, its own planted defects and gate rows |
| Q2 | Residual independence | Require all three residual zeros written (`M1 ~~ 0*M2`, `M1 ~~ 0*Y`, `M2 ~~ 0*Y`); omission refused | overrides (rec: omission OK) | Consistent with parallel; parser refuses an omitted statement with a classed error; refusal tests for each omitted pair; the spec's "lavaan default frees it" rationale must cite the lavaan version (0.7.3 frees none; 0.6.x behavior unverified) |
| Q3 | Omitted `Y ~ X` at k = 0 | Admit as fixed 0; refuse for k >= 1 | as recommended | One small k = 0 special case, same as three-variable and parallel |
| Q4 | Path rows reported | All estimated paths per variant (saturated: a, a2, d, b1, b, c_prime; chain: a, d, b, +c_prime if free) | as recommended | tidy() and confint(parm = "paths") both map every displayed row (Codex finding 1); alias vector varies by variant |
| Q5 | Admission-target effects | nie (chain), nie_total, nde, te; per-path specific indirect effects deferred | as recommended | nie_total needs its own confint row (Codex second-pass finding); for the chain variant nie_total = nie |
| Q6 | Covariate as treatment (k >= 1) | Allow, as FI-G1 and FI-G2 slices 3-4 | as recommended | Serial extraction tests for a covariate named as treatment |
| Q7 | Reversed mediator order in extract_mediation() | Refuse with a classed error naming the fitted order | as recommended | One refusal test |
| Q8 | Exact-origin rule | Per effect: chain NIE NA when at least two of (a, d1, b) are exactly 0; nie_total NA when a = a2 = b = b1 = 0 | as recommended | Per-effect helper; avoids the [0,0] defect class fixed in #383 |
| Q9 | Never-jointly-observed pairs | Keep the existing rank gate and document it | as recommended | No pre-check; a test pins the numerical-stage refusal; docs note the difference from parallel |
| Q10 | Parity cadence | Two-install parity run once per slice | as recommended | About 10 background minutes per slice; Hopper harness commit stays on `ba50f998` |
| Q11 | print() | Print the chain and covariates; may slip | as recommended | Cosmetic, can land after the main slices |

## Open items carried forward

- Recheck the lavaan residual-covariance claim on lavaan 0.6.x (probe here: 0.7.3 frees none for serial or parallel, with or without missing data). The parallel spec should cite the version.
- Amend the plan's variant registry for the pure chain before slice work starts.
- Spec sections 3-7 need the pure-chain variant added (tables, parameter counts, oracles, defects, gate rows); the agent's spec describes the saturated graph only.
- Codex adversarial review, two passes (`.codex` agent file and spec): 5 findings, all fixed in the spec and `.codex/agents/medfit-gates.toml`; the tracked `.claude/agents/medfit-gates.md` twin still needs the package-check condition (PR to dev).
