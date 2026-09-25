# Mediationverse Ecosystem Health — updated 2026-06-18

Snapshot of all packages in `~/projects/r-packages/active/`. Originally audited 2026-06-03; updated 2026-06-18 post CRAN acceptance.

## Dashboard

| Package | Version | CRAN | tests | NEWS✓ | pkgdown | medfit dep | Health |
|---------|---------|------|-------|-------|---------|------------|--------|
| **medfit** | 0.3.1 (CRAN: 0.2.1) | ✅ 0.2.1 on CRAN | 584+ | ✓ | ✓ | — (is the dep) | 🟢 |
| **rmediation** | 1.5.0 | ✅ on CRAN (→1.5.0 PR #7 open) | 87 | ✓ | ✓ | Suggests ✅ CRAN | 🟢 |
| **medsim** | 0.1.1 | dev | 193 | ✓ | ✓ | Suggests + Remotes⚠️ | 🟢 |
| **medrobust** | 0.1.0.9000 | dev (P0, CRAN prep) | 25 | ✗ drift | ✓ | none | 🟡 |
| **probmed** | 0.0.0.9000 | dev (blocked: needs medfit 0.3.0 CRAN) | 3 | ✓ | ✓ | Imports + Remotes⚠️ | 🟡 thin tests |
| **mediationverse** | 0.0.0.9000 | dev | 1 | ✗ drift | ✓ | Imports ✅ CRAN | 🟡 thin tests + drift |

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

### 🟢 Post-CRAN cascade — Stage 1 COMPLETE (2026-06-18)
- ✅ **RMediation** — `Remotes:` dropped, `Suggests: medfit (>= 0.2.0)` pinned; PR #7 open (`dev→main`), CI all green; strict check 0/0/1 (expected NOTE only). Release v1.5.0 pending merge + CRAN submit.
- ✅ **mediationverse** — `Data-Wise/medfit` dropped from `Remotes:`, `Imports: medfit (>= 0.2.0)` pinned; committed to dev.
- ⏸ **medsim** — low urgency; `Data-Wise/medfit` still in `Remotes:`, drop whenever convenient.
- ⏸ **probmed** — blocked on medfit **0.3.0 on CRAN** (Imports `>= 0.3.0`; Stage 2).

## Resolved (2026-06-03 session)
- ✅ medsim `.STATUS` created.
- ✅ mediationverse `.STATUS` refreshed.
- ✅ Boards (`PROJECTS.md` ×2) updated with current versions/status.
- ✅ rmediation moved `stable/` → `active/`.

## Resolved (2026-06-18 session)
- ✅ medfit 0.2.1 accepted on CRAN — gate cleared.
- ✅ medfit docs/NEWS/README/site updated to record release.
- ✅ RMediation 1.5.0 — Remotes dropped, PR #7 open, CI + strict check green.
- ✅ mediationverse — Remotes drop committed to dev.

## Next health actions
1. Merge RMediation PR #7 → tag v1.5.0 → submit 1.5.0 to CRAN.
2. Reconcile mediationverse + medrobust NEWS/README ↔ DESCRIPTION versions.
3. Expand mediationverse + probmed test suites.
4. Clear medrobust TODOs ahead of its CRAN prep.
5. Stage 2: medfit 0.3.0 CRAN submission → probmed cascade.
