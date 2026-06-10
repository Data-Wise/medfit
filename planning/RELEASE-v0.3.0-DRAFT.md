# Draft: rescope PR #33 as medfit v0.3.0

**Why:** PR #33 (`dev → main`) is titled "Release: medfit v0.2.0 (CRAN)" but
`main` is already at **v0.2.0** (on CRAN, awaiting acceptance) and `dev` has
advanced **40 commits** past it. So #33 actually ships the next minor — **v0.3.0**
— not v0.2.0. Re-scope it accordingly.

**Gate:** merge only **after CRAN accepts v0.2.0** (so `main` matches the
under-review CRAN tarball; then `main` moves to v0.3.0 as the next cycle).

> 🔺 **UPDATE 2026-06-10 — premise correction.** `main` is actually **stale at
> 0.1.0**, NOT 0.2.0 (the 0.2.x work never merged to `main`; it lives on `dev`
> and tags). The live CRAN submission is **0.2.1** (round-2 fixes) built from
> commit `27cc086`, on branch `feature/cran-round2`. So the real sequence is:
> **medfit 0.2.1 → accept → then this PR ships 0.3.0**. probmed (Imports
> `medfit (>= 0.3.0)`) is gated on the 0.3.0 CRAN release, per
> `planning/CASCADE-cran-flip-2026-06-03.md`. The round-2 fixes + MASS→Imports
> are already forward-ported onto `dev`, so 0.3.0 is CRAN-compliant.

---

## New PR #33 title

```
Release: medfit v0.3.0
```

## New PR #33 body

```markdown
## medfit v0.3.0

Next minor release. `main` is v0.2.0 (CRAN); this brings the accumulated `dev`
work forward as v0.3.0. **Do not merge until CRAN has accepted v0.2.0.**

### New features
- **Parallel mediation** — new `ParallelMediationData` S7 class (`X → M_j → Y`,
  independent mediators), built by `extract_mediation()` from lm/glm
  (`mediator_models`, `structure = "parallel"`/`"auto"`) and lavaan `sem()` fits.
  Total indirect effect `Σ aⱼ bⱼ`; `confint()` uses the full-covariance delta
  method so correlated `bⱼ` are handled correctly.
- **Treatment×mediator interaction** — new `InteractionMediationData` S7 class
  carrying VanderWeele's (2014) four-way decomposition (CDE / INTref / INTmed /
  PIE, with NDE = CDE+INTref, NIE = INTmed+PIE), built from lm/glm (`X:M` term)
  and lavaan fits; `decompose()` generic + `confint()` for paths/components/effects.
- **Family/link on `MediationData`** — new `family_m` / `family_y` properties so
  scale-free estimands (e.g. `probmed::pmed()`) simulate non-Gaussian potential
  outcomes on the correct link scale instead of discarding it. Backward compatible.

### Bug fixes
- `print(summary(x))` now shows the formatted summary for `MediationData`,
  `BootstrapResult`, and `SerialMediationData` (registered in `.onLoad()`; the
  `S3method` directives weren't activated once `print` joined S7 dispatch).

### Internal
- `R CMD check` clean (0 errors / 0 warnings / 0 notes); covr-safe S7 property
  defaults; `@usage NULL` on the S7 class docs.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Pre-merge checklist (apply when CRAN accepts v0.2.0)

- [ ] Confirm CRAN accepted v0.2.0 (main = released v0.2.0)
- [ ] `gh pr edit 33 --repo Data-Wise/medfit --title "Release: medfit v0.3.0" --body-file <this body>`
- [ ] Bump `dev` DESCRIPTION `Version: 0.2.0.9000` → `0.3.0`
- [ ] Stamp NEWS: `# medfit (development version)` → `# medfit 0.3.0 (YYYY-MM-DD)`
- [ ] Update `cran-comments.md` for 0.3.0
- [ ] Merge #33 → main; tag `v0.3.0`; GitHub release
- [ ] (optional) submit v0.3.0 to CRAN

## Downstream cascade (after v0.3.0 on main)

- **probmed**: revert `Remotes: data-wise/medfit@dev` → `data-wise/medfit`, bump
  pin to `medfit (>= 0.3.0)`, then PR `dev → main`.
- **manuscript**: un-comment the `pmed.qmd` §6 chunk (`eval: false` → `true`) and
  drop the placeholder numbers (verified: 0.681 / NIE 2.121 / binary 0.629).
- **RMediation**: Remotes→Imports flip (per ecosystem `.STATUS`).
