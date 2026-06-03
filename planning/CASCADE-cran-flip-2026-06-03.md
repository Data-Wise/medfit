# Pre-staged cascade: medfit Remotes→Imports flip

**Created:** 2026-06-03
**Trigger:** medfit 0.2.0 accepted to CRAN (watched by `medfit-cran-watch`,
`trig_018qiNZMTUP5Az2UGXyv6vRf`).
**Status:** ⏳ HELD — do NOT apply until the CRAN page returns 200 / acceptance email arrives.

> ⚠️ **Why held:** removing the `Remotes:` pointer before medfit is on CRAN
> makes `R CMD check` unable to resolve `Imports: medfit`. Apply only *after*
> acceptance. This is a non-breaking availability change, not an API migration.

Companion: `planning/CRAN-POST-ACCEPTANCE-CHECKLIST.md` (the medfit-side steps
that run *before* this cascade: merge PR #33 → tag → release).

---

## Update order

1. **medfit** on CRAN (gate — Phase 0)
2. **RMediation** (external repo, not staged here — the v1.5.0 blocker)
3. **probmed**, **mediationverse** (below)
4. **medsim** (Suggests-only — optional, no urgency)

---

## 1. probmed  `~/projects/r-packages/active/probmed`

- **Branch:** currently on `main` → create a feature branch first (PR-only repo).
- **Change:** `medfit` is the *only* `Remotes:` entry, so remove the entire
  `Remotes:` block. Pin the floor in `Imports:` to `medfit (>= 0.2.0)`.

### Diff

```diff
--- a/DESCRIPTION
+++ b/DESCRIPTION
@@ Imports:
 Imports:
-    medfit,
+    medfit (>= 0.2.0),
     methods,
     S7 (>= 0.2.1),
     stats
-Remotes:
-    data-wise/medfit
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
git commit -m "chore(deps): medfit on CRAN — drop Remotes, pin Imports >= 0.2.0"
gh pr create --base main --title "Depend on CRAN medfit (drop Remotes)"
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

## 3. medsim — deferred

`medfit` is **Suggests-only**; `R CMD check` tolerates the Remotes entry.
Drop `Data-Wise/medfit` from its `Remotes:` whenever convenient — no release pressure.

---

## Verification (per package, after applying)

- [ ] `R CMD check --as-cran` no longer shows a Remotes-related NOTE
- [ ] Package installs resolving `medfit` from CRAN (not GitHub)
- [ ] Tests pass against CRAN medfit 0.2.0
