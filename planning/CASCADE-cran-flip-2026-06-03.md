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
2. **RMediation** (`stable/rmediation`, the v1.5.0 blocker — §0.5; Suggests, drop Remotes)
3. **probmed**, **mediationverse** (§1–2)
4. **medsim** (Suggests-only — optional, no urgency — §3)

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

## 0.5 RMediation  `~/projects/r-packages/stable/rmediation`  🎯 the v1.5.0 blocker

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
cd ~/projects/r-packages/stable/rmediation   # already on dev
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
- [ ] Tests pass against CRAN medfit 0.2.0
