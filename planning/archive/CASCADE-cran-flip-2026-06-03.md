# Pre-staged cascade: medfit Remotes→Imports flip

**Created:** 2026-06-03
**Trigger:** medfit 0.2.0 accepted to CRAN (watched by `medfit-cran-watch`,
`trig_018qiNZMTUP5Az2UGXyv6vRf`).
**Status:** ✅ STAGE 1 COMPLETE (2026-06-18) — medfit 0.2.1 accepted on CRAN; RMediation PR #7 merged; mediationverse committed to dev. Stage 2 (probmed) blocked on medfit 0.3.0 CRAN.

> ⚠️ **Why held:** removing the `Remotes:` pointer before medfit is on CRAN
> makes `R CMD check` unable to resolve `Imports: medfit`. Apply only *after*
> acceptance. This is a non-breaking availability change, not an API migration.

> 🔺 **UPDATE 2026-06-10 — this is a TWO-STAGE medfit release.** The CRAN
> submission in flight is **0.2.1** (round-2 fixes). But **probmed requires
> `medfit (>= 0.3.0)`** (it uses parallel/interaction/family features that only
> exist in 0.3.0, currently a GitHub-only release). So:
> - **medfit 0.2.1 on CRAN** unblocks the *Suggests-level* dependents only
>   (RMediation, medsim, mediationverse — they need `>= 0.2.0`).
> - **probmed is gated on medfit 0.3.0 reaching CRAN**, not 0.2.1. Sequence:
>   `medfit 0.2.1 → accept → medfit 0.3.0 → accept → probmed`.
> The probmed pin below is corrected to `>= 0.3.0`.

Companion: `planning/CRAN-POST-ACCEPTANCE-CHECKLIST.md` (the medfit-side steps
that run *before* this cascade: merge PR #33 → tag → release).

---

## Update order

1. **medfit 0.2.1** on CRAN (gate for the Suggests/`>= 0.2.0` dependents)
2. **RMediation** (`active/rmediation`, the v1.5.0 blocker — §0.5; Suggests, drop Remotes)
3. **mediationverse** (Imports floor `>= 0.2.0` — §2)
4. **medfit 0.3.0** on CRAN (gate for probmed — Ext A/B features)
5. **probmed** (Imports floor `>= 0.3.0`, drop Remotes — §1)
6. **medsim** (Suggests-only — optional, no urgency — §3)

---

## 1. probmed  `~/projects/r-packages/active/probmed`

- **Branch:** feature branch off the integration branch (verify current branch first).
- **GATE: medfit `0.3.0` on CRAN** (NOT 0.2.1). probmed already declares
  `Imports: medfit (>= 0.3.0)` because it uses 0.3.0-only features (parallel /
  interaction / family). Do this flip only after medfit **0.3.0** is accepted.
- **Change:** `medfit` is the *only* `Remotes:` entry, so remove the entire
  `Remotes:` block. Keep the `Imports:` floor at `medfit (>= 0.3.0)`.

### Diff

```diff
--- a/DESCRIPTION
+++ b/DESCRIPTION
@@ Imports:
 Imports:
     medfit (>= 0.3.0),
     methods,
     S7 (>= 0.2.1),
     stats
-Remotes:
-    data-wise/medfit@v0.3.0
 VignetteBuilder: knitr, quarto
```

### Apply

```bash
cd ~/projects/r-packages/active/probmed
git checkout -b chore/medfit-cran-imports
# edit DESCRIPTION per diff above (or sed/Edit)
Rscript -e 'devtools::document()'
R CMD build . && R CMD check --as-cran probmed_*.tar.gz   # expect Remotes-NOTE gone
git add DESCRIPTION NAMESPACE
git commit -m "chore(deps): medfit 0.3.0 on CRAN — drop Remotes, keep Imports >= 0.3.0"
gh pr create --base main --title "Depend on CRAN medfit 0.3.0 (drop Remotes)"
```

---

## 2. mediationverse  `~/projects/r-packages/active/mediationverse`

- **Branch:** currently on `dev` (integration) — DESCRIPTION edit allowed here.
- **Change:** Remotes has **four** entries; remove **only** the `Data-Wise/medfit,`
  line. medsim/medrobust/probmed are still off-CRAN, so they STAY. Pin floor.

### Diff

```diff
--- a/DESCRIPTION
+++ b/DESCRIPTION
@@ Imports:
 Imports:
     cli,
-    medfit
+    medfit (>= 0.2.0)
 Remotes:
-    Data-Wise/medfit,
     Data-Wise/medsim,
     Data-Wise/medrobust,
     Data-Wise/probmed
```

### Apply

```bash
cd ~/projects/r-packages/active/mediationverse   # already on dev
# edit DESCRIPTION per diff above
Rscript -e 'devtools::document()'
R CMD build . && R CMD check --as-cran mediationverse_*.tar.gz
git add DESCRIPTION NAMESPACE
git commit -m "chore(deps): medfit on CRAN — drop from Remotes, pin Imports >= 0.2.0"
git push origin dev
```

---

## 0.5 RMediation  `~/projects/r-packages/active/rmediation`  🎯 the v1.5.0 blocker

- **Branch:** `dev`. **Version:** 1.4.0 → bump to **1.5.0** on release.
- **Decision (2026-06-03):** keep medfit in **`Suggests:`**, do NOT promote to
  Imports. RMediation's medfit usage in `R/ci_medfit.R` is fully guarded with
  `requireNamespace("medfit", quietly = TRUE)` (lines 140/159/223) — the
  Suggests contract. Promoting to Imports would force the dependency on all
  users and orphan those guards. So the only required change is dropping the
  `Remotes:` line + pinning the floor.

### Diff

```diff
--- a/DESCRIPTION
+++ b/DESCRIPTION
@@ Suggests:
 Suggests:
     knitr,
-    medfit,
+    medfit (>= 0.2.0),
     OpenMx (>= 2.13),
     rmarkdown,
     testthat (>= 3.0.0)
-Remotes:
-    data-wise/medfit
 Encoding: UTF-8
```

### Apply

```bash
cd ~/projects/r-packages/active/rmediation   # already on dev
# edit DESCRIPTION per diff above; bump Version: 1.5.0; update NEWS.md
Rscript -e 'devtools::document()'
R CMD build . && R CMD check --as-cran RMediation_*.tar.gz   # Remotes-NOTE gone
# ci_medfit() + serial-medfit integration tests should pass against CRAN medfit 0.2.0
git add DESCRIPTION NEWS.md NAMESPACE
git commit -m "feat(deps): medfit on CRAN — drop Remotes, pin Suggests >= 0.2.0; v1.5.0"
git push origin dev
```

> Leave the `requireNamespace("medfit")` guards in place — they stay correct
> for a Suggests dependency.

---

## 3. medsim — deferred

`medfit` is **Suggests-only**; `R CMD check` tolerates the Remotes entry.
Drop `Data-Wise/medfit` from its `Remotes:` whenever convenient — no release pressure.

---

## Verification (per package, after applying)

- [ ] `R CMD check --as-cran` no longer shows a Remotes-related NOTE
- [ ] Package installs resolving `medfit` from CRAN (not GitHub)
- [ ] Tests pass against CRAN medfit (>= 0.2.0 for Suggests deps; >= 0.3.0 for probmed)
