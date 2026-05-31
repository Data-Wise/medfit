# lm/glm Serial Mediation Extractor — Orchestration Plan

> **Branch:** `feature/lm-serial-extractor`
> **Base:** `dev`
> **Worktree:** `~/.git-worktrees/medfit/feature-lm-serial-extractor`
> **Spec:** `planning/specs/SPEC-lm-serial-extractor-2026-05-31.md`
> **Version Target:** medfit 0.1.0.9000 (dev) → folds into next release
> **Closes:** Blocker B item 4 (mediation-planning blockers spec, decision #2 "lavaan + lm in v1")

## Objective

Add a serial branch to the lm/glm `extract_mediation()` method that builds a `SerialMediationData`
from k+1 separately-fitted models (`X→M1→…→Mk→Y`), matching the shipped lavaan serial contract
(`a`, `d1…d{k-1}`, `b`, `c_prime`). In the same pass, fix the latent simple-lm alias bug so
`cov(b, c')` is preserved (not zeroed).

## Phase Overview

| Phase | Increment | Priority | Effort | Status |
|-------|-----------|----------|--------|--------|
| 1 | Shared alias-vcov helper + simple-lm `cov(b,c')` fix | High | ~1.5h | |
| 2 | Serial lm/glm extractor (`mediator_models` API, dispatch, validation) | High | ~3h | |
| 3 | Tests + docs (lm/lavaan vcov divergence) | High | ~2h | |
| 4 | Verify (R CMD check, lint green), roxygen, status update | Medium | ~1h | |

## Phase 1: Shared alias-vcov helper + simple-lm bug fix

**Scope:** Replace the diagonal-only alias copy in the simple lm path with a full source-row/column
copy, factored into a shared helper both the simple and serial paths use. Behavior-neutral for the
indirect effect; only fixes `cov(b, c')`.

- [ ] 1.1 Factor a shared `.copy_alias_vcov(vcov_src, source_idx, ...)` helper (mirror the
      `resolve_source_idx` + full row/column pattern in `R/extract-lavaan.R`).
- [ ] 1.2 Replace `extract-lm.R:227–236` diagonal-only alias copy with the full-block copy so
      `vcov[c("b","c_prime"), …]` reproduces `vcov(model_y)[c(mediator,treatment), …]`.
- [ ] 1.3 Regression test: indirect effect `a·b` unchanged; `cov(b,c')` now non-zero and equal to
      the source.

**Key files:** `R/extract-lm.R` (update), `R/extract-lavaan.R` (maybe extract shared helper),
`tests/testthat/test-extract-lm.R` (add regression test).

## Phase 2: Serial lm/glm extractor

**Scope:** New `.extract_serial_mediation_lm()` + serial dispatch in the lm/glm S7 methods, keyed on
`length(mediator) >= 2`, with the `mediator_models` list API.

- [ ] 2.1 Add `mediator_models = NULL` arg to the lm + glm `extract_mediation` methods; branch to the
      serial worker when `length(mediator) >= 2`.
- [ ] 2.2 `.extract_serial_mediation_lm(object, mediator_models, model_y, treatment, mediator, ...)`:
      resolve `a` (from `object`), `d_i` (from `mediator_models[[i]]`), `b`/`c_prime` (from `model_y`).
- [ ] 2.3 Build named `@estimates`/`@vcov`: per-model diagonal blocks, zero cross-model blocks, full
      within-`model_y` block (preserves `cov(b,c')`); aliases `a, d1…d{k-1}, b, c_prime`.
- [ ] 2.4 Ordering cross-check (Q2): `length(mediator_models) == k-1`; for each `i`, `mediator[i]`
      predicts `mediator[i+1]` in `mediator_models[[i]]`; `treatment`→`mediator[1]` in `object`;
      `mediator[k]`→response in `model_y`. Informative `stop()` on mismatch.
- [ ] 2.5 `@sigma_mediators` per-mediator (Q3): real SD for Gaussian, `NA` for non-Gaussian, whole
      slot `NULL` only if all non-Gaussian. Covariates document-only (Q1) — no restriction.

**Key files:** `R/extract-lm.R` (NEW worker + dispatch), reuse Phase-1 helper.

## Phase 3: Tests + docs

**Scope:** Cover the §6 acceptance criteria and document the engine divergence.

- [ ] 3.1 `tests/testthat/test-extract-lm-serial.R` (NEW): 2-/3-mediator chains, lm + glm, vcov block
      structure + `cov(b,c')`, ordering-error cases, covariate-tolerance (`M2 ~ M1 + X`), fidelity vs
      `coef()`.
- [ ] 3.2 roxygen `@details`: document the lm (block-diagonal among chain paths) vs lavaan (full
      covariance) divergence and its CI implication.
- [ ] 3.3 Vignette note (if an extraction/serial vignette exists) on same-data-different-CI by engine.

**Key files:** `tests/testthat/test-extract-lm-serial.R` (NEW), `R/extract-lm.R` (roxygen),
`vignettes/articles/*.qmd` (note).

## Phase 4: Verify, document-gen, status

- [ ] 4.1 `roxygen2::roxygenise()` (rd + namespace); confirm no DESCRIPTION roxygen-version churn.
- [ ] 4.2 `R CMD build` + `R CMD check` (tests): Status OK.
- [ ] 4.3 `lintr::lint_package()` == 0 (keep the just-cleared lint green).
- [ ] 4.4 Optional: RMediation serial integration smoke test (load both, feed lm-fit chain through
      `ci_serial_mediation_data()`).
- [ ] 4.5 Update spec §6 acceptance checkboxes + the blockers-spec item 4 status to DONE.

## Friction Prevention (from this session's experience)

- **CI is the source of truth, not `load_all`.** `pkgload::load_all` gave a *false green* on a
  contract test this session; only `R CMD check` (installed-package run) caught it. **Run
  `R CMD build` + `R CMD check` before every commit/PR**, not just `load_all`/`test_dir`.
- **`docs/` is gitignored** (pkgdown output) — never put tracked files there; specs/plans live in
  `planning/`.
- **`lintr` is installed locally** — run `lintr::lint_package()` and keep it at 0 (the repo lint
  baseline was just cleared; don't regress it). Reword code-like comments to prose; lowercase
  SEM locals; avoid alignment-to-paren indentation.
- **Context first**: read this file + the spec BEFORE coding.
- **Verify location**: confirm CWD is this worktree (`git worktree list`, `pwd`), not the main repo.
- **No autonomous phase jumps**: after each phase, STOP and confirm before the next.

## Acceptance Criteria (from spec §6)

- [ ] Serial call returns `SerialMediationData` (`@mediators`, `@d_path` length k-1).
- [ ] `@estimates`/`@vcov` named `a, d1…d{k-1}, b, c_prime`; dims match; symmetric.
- [ ] vcov block-diagonal across chain paths AND preserves `cov(b, c_prime)` (asserted vs `vcov(model_y)`).
- [ ] 2-/3-mediator; lm + glm; per-mediator `NA` sigma for non-Gaussian.
- [ ] Order cross-check with informative errors (test per failure mode).
- [ ] Extra covariates accepted; `d_i` read as predecessor coefficient (test with `M2 ~ M1 + X`).
- [ ] Simple-lm regression test: `cov(b,c')` now correct; indirect effect unchanged.
- [ ] `R CMD check` clean; tests green; `lintr::lint_package()` == 0.
- [ ] `@details`/vignette document the lm-vs-lavaan vcov divergence.

## Commit Strategy

- Conventional commits per phase:
  - Phase 1: `fix(extract-lm): preserve cov(b,c') in alias vcov (shared helper)`
  - Phase 2: `feat(extract-lm): serial mediation extractor via mediator_models`
  - Phase 3: `test(extract-lm): serial lm/glm coverage` + `docs(extract-lm): lm/lavaan vcov divergence`
  - Phase 4: `chore: regen docs; update spec status`
- End commit messages with the `Co-Authored-By` trailer.

## Verification (run after each phase)

```r
# Load (fast iteration) — but DO NOT trust this alone for contract changes
pkgload::load_all(".", export_all = TRUE)
testthat::test_dir("tests/testthat")

# Authoritative (run before each commit/PR) — mirrors CI
# R CMD build . --no-build-vignettes --no-manual
# R CMD check medfit_*.tar.gz --no-manual --no-vignettes --no-examples   # expect Status: OK

# Lint (keep at 0)
lintr::lint_package(".")
```

## Session Instructions

### Context
You are in the **medfit worktree** for the lm/glm serial extractor. The spec
(`planning/specs/SPEC-lm-serial-extractor-2026-05-31.md`) has full design detail; this file is the
phase plan. Start from `dev` (already contains the lavaan serial extractor and the cleared lint
baseline).

### How to Start
```bash
cd ~/.git-worktrees/medfit/feature-lm-serial-extractor
claude
```
On session start, paste:
> Read `ORCHESTRATE-lm-serial-extractor.md` and the spec at
> `planning/specs/SPEC-lm-serial-extractor-2026-05-31.md`. Start Phase 1.

### Phase-by-Phase
1. Read the current state of each file listed in the phase.
2. Implement per the spec design (mirror the lavaan serial extractor's patterns).
3. Run verification (including `R CMD check`) after each phase.
4. Commit in logical groups.
5. STOP and confirm before the next phase.
6. At merge: delete this `ORCHESTRATE-*.md` (working artifact), then PR `feature/lm-serial-extractor` → `dev`.
