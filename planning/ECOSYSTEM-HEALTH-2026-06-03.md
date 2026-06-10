# Mediationverse Ecosystem Health — 2026-06-03

Snapshot of all packages in `~/projects/r-packages/active/`. Audited this date.

## Dashboard

| Package | Version | CRAN | tests | NEWS✓ | pkgdown | medfit dep | Health |
|---------|---------|------|-------|-------|---------|------------|--------|
| **medfit** | 0.2.0 | ⏳ submitted, awaiting | 203 | ✓ | ✓ | — (is the dep) | 🟢 |
| **rmediation** | 1.4.0 | ✅ on CRAN (→1.5.0 staged) | 87 | ✓ | ✓ | Suggests + Remotes | 🟢 |
| **medsim** | 0.1.1 | dev | 193 | ✓ | ✓ | Suggests + Remotes | 🟢 |
| **medrobust** | 0.1.0.9000 | dev (P0, CRAN prep) | 25 | ✗ drift | ✓ | none | 🟡 |
| **probmed** | 0.0.0.9000 | dev | 3 | ✓ | ✓ | Imports + Remotes | 🟡 thin tests |
| **mediationverse** | 0.0.0.9000 | dev | 1 | ✗ drift | ✓ | Imports + Remotes | 🟡 thin tests + drift |

## Issues found (prioritized)

### 🔴 Documentation drift
- **mediationverse** — NEWS top entry `0.1.0` and README references `0.1.0`, but
  DESCRIPTION is `0.0.0.9000`. NEWS/README are *ahead* of the version. Reconcile
  before any release. (`.STATUS` updated 2026-06-03 to flag this.)
- **medrobust** — NEWS top `0.1.0` vs DESCRIPTION `0.1.0.9000`; README cites `0.1.0`.
  Minor dev-suffix drift; align before CRAN prep.

### 🟡 Test coverage gaps
- **mediationverse** (1 `test_that`) and **probmed** (3) are very thin vs medfit (203),
  medsim (193), rmediation (87). Both are pre-1.0 — expand before their releases.

### 🟡 Code hygiene
- **medrobust** — 6 TODO/FIXME in `R/` (only package with meaningful density); it's
  prepping for CRAN (P0), so worth clearing.

### 🟢 Post-CRAN cascade (tracked, not a defect)
- Dangling `Remotes: …/medfit` in **4 packages** (probmed, mediationverse [Imports];
  medsim, rmediation [Suggests]). Drop on medfit CRAN acceptance — diffs pre-staged in
  `CASCADE-cran-flip-2026-06-03.md`. RMediation keeps Suggests (guarded), NOT Imports.

## Resolved this session
- ✅ medsim `.STATUS` created (was the only package missing one).
- ✅ mediationverse `.STATUS` refreshed (was stale: "start medfit CRAN prep" — already done).
- ✅ Boards (`PROJECTS.md` ×2) updated with current versions/status.
- ✅ rmediation moved `stable/` → `active/` (now ecosystem-discoverable).

## Next health actions
1. Reconcile mediationverse + medrobust NEWS/README ↔ DESCRIPTION versions.
2. Expand mediationverse + probmed test suites.
3. Clear medrobust TODOs ahead of its CRAN prep.
4. On medfit CRAN acceptance → run the staged cascade.
