# PROPOSAL: 0.11.0 latent means for the native engine (brainstorm, 2026-10-14)

Nothing below is decided. Inputs: `planning/specs/BRAINSTORM-native-mean-structure-2026-10-12.md` (section 3), `GRILL-native-mean-structure-2026-10-12.md` (G2, G6, G7), the guard in `R/sem-model.R:236-250`.

## What exists today (verified in the repo)

- A latent variable's mean is **fixed at 0** (lavaan's default); a latent `~ 0*1` is accepted and dropped; any other latent `~1` errors with "latent means are planned for a later release".
- Observed intercepts and means work (0.9.0); `fixed_x`, the `:` product and four-way work (0.9.0, 0.10.0).
- G7, probed on lavaan 0.7.2: with `meanstructure = TRUE` and no `~1` written, indicator intercepts are free and latent means fixed at 0; a free `M ~ 1` with **all** indicator intercepts free is unidentified (lavaan fits, then warns the information matrix cannot be inverted); the identified form fixes one indicator intercept.

## The honest question first: what would latent means buy?

In a **single-group** mediation model, freeing a latent mean while fixing a marker indicator's intercept is a re-parametrization: the fit, the paths and the SEs do not change. The payoff would be (a) constraints or tests that name a latent mean (`eta ~ 1` equals a value), and (b) groups or time, which medfit does not have. So the demand check from 0.10.0 (a concrete consumer) applies again.

## Quick Wins (< 30 min)

1. **Demand check**: ask whether probmed, RMediation or any user needs a named latent mean; write the answer in a GRILL file. If nobody does, defer the whole release.
2. **Improve the error text** (no new feature): tell the user the single-group equivalent (fix a marker indicator's intercept, write the latent loading structure) instead of "planned for a later release".
3. **Re-run the G7 probe** on the current lavaan to confirm it still holds.

## Medium Effort (1-2 hrs)

- [ ] **Identification check at table completion**: a free latent `~1` needs exactly one fixed or constrained indicator intercept per latent variable; the error names the latent variable (the intercept analogue of `.sem_check_scale()`).
- [ ] **RAM and information**: latent mean entries in `m0`/`pos_m`, extended centered coordinates (`.sem_center_map()`), df and the moment count (latent means add parameters, not moments).
- [ ] **Oracle gate**: a 3-indicator latent mediator with a free `M ~ 1` and the marker intercept fixed; compare estimates, SEs, logLik against lavaan and OpenMx (the gate pattern from the constrained and mean-structure gates, with `MUTANT=` switches).

## Long-term (future sessions)

- [ ] **Latent products** (`eta1:x`): needs latent-variable interaction machinery (product indicators or LMS); rule 8 and 9 stay as written and stop latent products.
- [ ] **Groups and invariance**: only if medfit ever grows multi-group; latent means are the reason to want it.
- [ ] **Four-way with a latent mediator**: needs latent products first.

## Options compared

| Option | Cost | Risk | Value |
|---|---|---|---|
| A. Defer 0.11.0, ship 0.10.1 only | XS | None | Matches the single-group value above |
| B. Identification check plus free latent `~1` (marker form) | M | Medium (centered-coordinate gates) | Named latent means in constraints; lavaan parity |
| C. B plus latent mean in `anova()`/MBCO policy | L | Medium-high | Only useful once B has a consumer |

## Recommended Next Step

→ **Quick win 1 (the demand check), then decide A vs B.** Without a named consumer the release is a re-parametrization with real numerical risk (centered coordinates, df counting, the identification gate). If a consumer exists, do B behind the same gates as 0.9.0 (frozen fixture bit-identical with the flag off, lavaan and OpenMx parity, a planted defect per rule).

## Open questions for the author

1. Is there a concrete consumer of a named latent mean today (probmed, RMediation, you)?
2. If not, should 0.11.0 be something else (factor covariates, a bootstrap helper), and latent means move to 1.0?
3. Marker-indicator form only, or also the lavaan "fixed latent variance, free all intercepts and means" form?
