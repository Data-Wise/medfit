# Post-CRAN-Acceptance Checklist — medfit 0.2.1

Actions to run **once CRAN accepts medfit 0.2.1**. Created 2026-06-01; updated 2026-06-10.

> 🔺 **UPDATE 2026-06-10:** the submission is now **0.2.1** (round-2 reviewer
> fixes: GLM acronym, references, `\value`, `\donttest`, MASS→Imports), not 0.2.0.
> This is a **two-stage** release: 0.2.1 unblocks the Suggests/`>= 0.2.0`
> dependents (RMediation, mediationverse, medsim); **probmed needs medfit
> 0.3.0 on CRAN** (a later submission — it imports 0.3.0-only features). See the
> corrected `planning/CASCADE-cran-flip-2026-06-03.md`. Also, per the 2026-06-03
> decision **RMediation KEEPS medfit in `Suggests`** (not Imports) — §3 below
> (the "Remotes→Imports flip") is superseded by the CASCADE doc; only the
> Remotes-drop + floor-pin applies.

Submission status: 0.2.1 checked clean (`--as-cran --run-donttest` +
`_R_CHECK_DEPENDS_ONLY_`/`_R_CHECK_SUGGESTS_ONLY_` = 0/0/0); win-builder R-devel
= 1 NOTE (author surnames). `submit_cran()` + email confirmation pending
(maintainer action). medfit on CRAN gates the downstream cascade.

---

## 1. Tag / release hygiene (medfit)

- [ ] **Refresh the `v0.2.0` tag to match the accepted source.** The current tag
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
- [ ] Confirm the CRAN page is live: https://CRAN.R-project.org/package=medfit
      (the README CRAN badge turns green once indexed, ~1 day).

## 2. Start the next dev cycle (medfit)

- [ ] On `dev`: bump `DESCRIPTION` to `Version: 0.2.0.9000` (development version).
- [ ] Add a fresh `# medfit (development version)` heading at the top of `NEWS.md`.
- [ ] `.STATUS`: mark medfit **on CRAN**; Blocker B fully shipped.

## 3. RMediation: `Remotes:` → `Imports` flip (v1.5.0) — THE downstream unblock

- [ ] DESCRIPTION: move `medfit` from `Suggests:` to `Imports:` with a floor:
      `medfit (>= 0.2.0)`.
- [ ] **Remove the `Remotes: data-wise/medfit` line** (CRAN forbids `Remotes:` in
      submitted packages — this is the whole reason the flip waited on CRAN).
- [ ] Replace any `requireNamespace("medfit", quietly = TRUE)` guards / conditional
      use with direct `medfit::` calls now that it is a hard dependency. (Check
      `R/ci_medfit.R` and `R/zzz.R`.)
- [ ] `R CMD check` + tests against **CRAN medfit** (not the GitHub Remotes build);
      confirm the serial CI path (`ci_serial_mediation_data()`) still resolves the
      `a`/`d1…`/`b` name contract — it does as of medfit 0.2.0 (verified this cycle).
- [ ] Version-bump RMediation → 1.5.0, update NEWS, release.
- [ ] Submit RMediation 1.5.0 to CRAN.
- [ ] (Related, independent) rename RMediation `develop` → `dev` for ecosystem
      naming consistency (long-tracked item; do alongside or separately).

## 4. Ecosystem doc sync

- [ ] `mediation-planning`: in `TODOS.md` + `MEDFIT-COVARIANCE-EXTRACTION-BLOCKERS-SPEC.md`,
      mark medfit on CRAN, Blocker B shipped, RMediation v1.5.0 unblocked/in-progress.
- [ ] `mediationverse` `STATUS.md`: medfit on CRAN; refresh per-package status.

## Gotchas carried from this cycle

- **`main` `strict: true`** ("require branches up to date") forces a back-merge
  (`main → dev`) + CI re-run on every `dev → main` PR. Consider relaxing it (keep
  the required `ubuntu-latest (release)` check) to end the back-merge cycle.
- **Verify release-critical things on the installed package**, not
  `pkgload::load_all(export_all = TRUE)` — the latter gave false negatives this
  cycle (S3 dispatch, `object_usage`). Use `devtools::test()` / `R CMD check`.
- The lm serial extractor lives behind `extract_mediation(..., mediator_models = ...)`;
  see `planning/specs/SPEC-lm-serial-extractor-2026-05-31.md`.
