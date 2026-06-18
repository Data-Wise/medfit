# Post-CRAN-Acceptance Checklist — medfit 0.2.1

Actions to run **once CRAN accepts medfit 0.2.1**. Created 2026-06-01; updated 2026-06-18.

> ✅ **UPDATE 2026-06-18: medfit 0.2.1 ACCEPTED ON CRAN.** Stage 1 cascade
> complete (RMediation PR #7, mediationverse dev). Stage 2 (probmed) blocked
> on medfit 0.3.0 CRAN.

~~Submission status: 0.2.1 checked clean; submit_cran() + email confirmation pending.~~
**Accepted 2026-06-18.**

---

## 1. Tag / release hygiene (medfit)

- [ ] **Refresh the `v0.2.1` tag to point at `feature/cran-round2` HEAD** (the submitted source). The accepted source lives on that branch; a tag on its tip makes the CRAN submission traceable. The current tag
      (`0b58ca8`) predates the CRAN-prep commits; `main` HEAD has the accepted
      source (delta is metadata-only: `.Rbuildignore`, `inst/CITATION`, wording).
      From a **clean shell** (branch-guard blocks `--force` from dev/main-pinned
      Claude sessions):
      ```sh
      git fetch origin
      git tag -f v0.2.0 origin/main
      git push origin v0.2.0 --force      # tag ref, not a branch
      ```
      The existing GitHub release follows the tag name automatically.
- [x] Confirm the CRAN page is live: https://CRAN.R-project.org/package=medfit ✅

## 2. Start the next dev cycle (medfit)

- [x] `.STATUS`: marked medfit on CRAN ✅ (2026-06-18)
- [x] `NEWS.md`: 0.2.1 entry added ✅
- [x] `README.md`: citation updated to 0.2.1 + CRAN URL ✅
- [ ] Tag `v0.2.1` on `feature/cran-round2` HEAD (traceability)

## 3. RMediation v1.5.0 — THE downstream unblock

- [x] `Remotes: data-wise/medfit` line removed ✅
- [x] `Suggests: medfit (>= 0.2.0)` pinned ✅ (kept in Suggests — guards intact)
- [x] `R CMD check --strict` (noSuggests + suggests-only + --run-donttest) = 0/0/1 (expected NOTE) ✅
- [x] CI all green (macOS/Windows/Ubuntu/coverage/pkgdown) ✅
- [x] Version bumped → 1.5.0, NEWS updated ✅
- [x] PR #7 open (`dev → main`) ✅
- [ ] **Merge PR #7** → tag `v1.5.0` → GitHub release → submit 1.5.0 to CRAN

## 4. Ecosystem doc sync

- [x] `ECOSYSTEM-HEALTH-2026-06-03.md` dashboard updated ✅
- [x] `CASCADE-cran-flip-2026-06-03.md` status updated ✅
- [x] mediationverse `Remotes:` drop committed to dev ✅
- [ ] medsim: drop `Data-Wise/medfit` from Remotes (low urgency)

## Gotchas carried from this cycle

- **`main` `strict: true`** ("require branches up to date") forces a back-merge
  (`main → dev`) + CI re-run on every `dev → main` PR. Consider relaxing it (keep
  the required `ubuntu-latest (release)` check) to end the back-merge cycle.
- **Verify release-critical things on the installed package**, not
  `pkgload::load_all(export_all = TRUE)` — the latter gave false negatives this
  cycle (S3 dispatch, `object_usage`). Use `devtools::test()` / `R CMD check`.
- The lm serial extractor lives behind `extract_mediation(..., mediator_models = ...)`;
  see `planning/specs/SPEC-lm-serial-extractor-2026-05-31.md`.
