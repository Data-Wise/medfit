# BRAINSTORM: Three decisions before Ext C Phase 4

**Date:** 2026-08-22 · **Branch:** `feature/engine-adapter-architecture` (Phases 1–3 done, `9370d87`)
**Scope:** version/WARNING handling · `m_cde` default · PR split
**Not in scope:** re-opening any of the 9 locked grill decisions.

---

## TL;DR — the three answers

| # | Decision | Recommendation | Effort |
|---|---|---|---|
| 1 | Strict-check WARNING | **Bump to `0.4.0` + refresh `Date` on this branch** | 15 min |
| 2 | `m_cde` default | **Flip to `0`** (match lm *and* lavaan extractors) | 10 min |
| 3 | PR split | **Single PR, Phases 1–4** | — |

All three point the same way: they are cheap now and expensive later.

---

## The coupling nobody flagged yet

`NEWS.md` has **never** carried an `[Unreleased]` or `(development version)` section — verified
by `git log -S"Unreleased" -- NEWS.md` (zero hits) and by the file itself, which opens directly
on `# medfit 0.3.2 (2026-07-23)`. Every heading in the file is a *released* version.

The ORCHESTRATE plan's Phase 4.3 says "CHANGELOG `[Unreleased]` mirror only — no version
changes." **That section does not exist in this repo.** So Phase 4 cannot write a NEWS entry
without first answering decision #1. They are one decision, not two.

---

## Decision 1 — the strict-flavor WARNING

### What it actually says

```
Insufficient package version (submitted: 0.3.2, existing: 0.3.2)
The Date field is over a month old.        # DESCRIPTION Date: 2026-07-20
```

Reproduced identically on `dev`. Nothing to do with the adapter.

### Options

**A. Bump `Version: 0.4.0` + `Date: 2026-08-22` on this branch (Recommended)**
New exported capability (a second engine) is a minor bump under the package's own history
(`0.3.0` shipped classes, `0.3.1` shipped `weights=`/`se_type=`, both minor/patch bumps carrying
their feature). Silences the WARNING immediately, so every later strict check on this branch is a
clean 0/0/0 — no alarm fatigue, no "is that the known one?" on each run. Gives Phase 4's NEWS
entry a real heading. Version bumps are Claude Code's lane per `CLAUDE.md`.
*Risk:* if the eventual CRAN release lands as `0.4.0` with other features folded in, the NEWS
entry just grows — headings do not need re-cutting.

**B. Leave `0.3.2`, write NEWS under a new `# medfit (development version)` heading**
Zero release commitment; standard usethis idiom. But it introduces a heading convention the file
has never used, and the WARNING persists on every strict run until release.

**C. Leave everything, document the baseline (status quo)**
Already done in the ORCHESTRATE notes. Costs nothing now; costs a re-explanation every future
strict check, and still blocks the NEWS heading question.

**D. Bump to `0.3.2.9000`**
Silences the version half of the WARNING. But the repo has never used a `.9000` dev suffix, and
it reads as "unreleased dev build" in every downstream `packageVersion()` check across the
mediationverse cascade.

### Version-string blast radius (checked)

Only 2 files carry `0.3.2` as live data: `DESCRIPTION:4` and `NEWS.md:1`. Everything else is
prose in `cran-comments.md`, `CLAUDE.md`/`AGENTS.md` status blocks, and `planning/`. No test, CI
workflow, or badge asserts the version. A bump is genuinely a 2-line change plus a prose sweep.

---

## Decision 2 — `m_cde` default: `mean(M)` or `0`

### The premise correction, restated

The spec justified `mean(M)` as "matching `InteractionMediationData`'s existing `m_star`
convention." That rationale is false twice over:

1. **The lm/glm extractor defaults `m_star = 0`** (`R/extract-lm.R:119,153`).
2. **The lavaan extractor also defaults `m_star = 0`** — asserted directly in
   `test-extract-interaction-lavaan.R:38` and `test-extract-interaction-lm.R:33`
   (`expect_equal(imd@m_star, 0)`).

And regmedint itself has **no** default — `m_cde` is a required argument. So there is no
"regmedint convention" to honor either. `mean(M)` currently makes the new engine the odd one out
of three, against a rationale that describes something that does not exist.

### What is and is not affected

`CDE = θ₁ + θ₃·m*` and `INTref = θ₃·(E[M|X=0] − m*)` shift in exactly compensating directions.
So:

- **Invariant to `m*`:** `nde()`, `nie()`, `te()`, `pm()` — every headline effect.
- **Moves with `m*`:** the CDE/INTref split only — `decompose()` and
  `confint(parm = "components")`.

That bounds the blast radius: two engines on identical data agree on every reported effect and
disagree only on how the direct effect splits. Small — but it is exactly the kind of silent
cross-engine disagreement that costs trust the first time a user notices it.

### Options

**A. Flip the regmedint default to `0` (Recommended)**
One line in `.regmedint_build_args()`. Makes all three extractors agree. `engine_args$m_cde`
still gives the escape hatch, and the SE gradient already carries `m_star` correctly, so nothing
downstream changes. Two tests need their expected `m_star` updated.
*Cost:* `CDE` is then evaluated at `M = 0`, which is an extrapolation for a mediator that never
takes the value 0 (a 1–7 Likert scale, say).

**B. Keep `mean(M)`, document the asymmetry loudly**
Statistically the better default in isolation — `mean(M)` is always in-range and scale-free.
*But:* that argument applies just as strongly to the lm/glm and lavaan engines, which already
default to 0. Keeping it fixes the statistics in one engine of three and calls the result a
convention.

**C. Promote `m_star` to a first-class `fit_mediation()` argument, default `0`**
The structurally correct answer, and it closes a **pre-existing gap**: `m_star` is currently
unreachable through `fit_mediation()` for the glm engine at all — `...` routes to `stats::glm()`,
not to `extract_mediation()`, so a `fit_mediation(Y ~ X*M, ...)` user can never set the reference
level. This is not a grill re-open: decision #9 rejected a `decomposition=` argument, a different
thing.
*Cost:* signature change on an exported function + threading through the glm path + docs + tests.
~1.5 hr, and it widens the PR beyond "add an engine."

**D. Default `mean(M)` in both engines**
Consistent and statistically defensible, but changes the behavior of two shipped, CRAN-released
extractors. Breaking change for anyone reading `@cde` today. Rejected.

### Recommended sequencing

**A now, C as its own follow-up.** A costs ten minutes and removes the inconsistency. C is a real
improvement, is independently useful (it fixes the glm gap), and deserves its own diff rather
than riding along inside an engine-adapter PR.

---

## Decision 3 — PR split

The grill filed this under *Open Questions*: "adjust if a single PR reads cleaner once the diff
exists." The diff now exists.

```
R/ code           667 lines   (fit-regmedint.R 581, fit-glm.R 39, methods-base.R 15, utils.R 21, generics 11)
tests/            415 lines
plan + spec       250 lines
man/ generated     50 lines
                 ─────────
                1384 insertions, 3 deletions, across 14 files
```

Phase 4 adds an estimated 150–250 lines: a vignette section, a NEWS entry, and zero `_pkgdown.yml`
changes (see below).

### Options

**A. One PR, Phases 1–4 (Recommended)**
The docs are *about* the code in the same diff — a reviewer reading the vignette section can check
it against the adapter on the same screen. Splitting means PR 1 merges a user-facing engine into
`dev` with no NEWS entry and no vignette, which is precisely the drift `CLAUDE.md`'s "run docs sync
after merging feature PRs to dev" exists to clean up afterward. One CI cycle instead of two; the
worktree closes once instead of being kept alive or recreated. ~1.6k lines is a normal size for
this repo (Ext A and Ext B each shipped comparable diffs).

**B. Two PRs as originally planned**
Defensible if you want the correctness-bearing change reviewed without doc prose in the way. The
plan's own rationale for splitting was "down from the original 3-PR CMAverse plan" — i.e. an
artifact of a larger design that no longer exists.

**C. Three PRs (dispatch / adapter / docs)**
Rejected. Phase 1 alone is a stub that errors on use; merging it is merging dead code.

---

## Phase 4 scope, now that it is mapped

Answers to the plan's own open questions, from the actual repo:

- **4.1 vignette** — `vignettes/articles/extraction.qmd` is the only article covering the four-way
  decomposition; `getting-started.qmd` and `introduction.qmd` are the two that mention
  `fit_mediation()`. Extend `extraction.qmd` (engine + mapping) and add the `engine =` choice to
  `getting-started.qmd`. These are **articles**, not built vignettes, so they do not run under
  `R CMD check` — cheap to extend, and no check-time regmedint dependency.
- **4.2 `_pkgdown.yml`** — **no change needed.** `fit_mediation` (line 124) and
  `InteractionMediationData` (line 117) are already listed; the adapter is `@noRd`/internal and
  ships no new exported symbol. Confirmed, closing that open question.
- **4.3 NEWS** — blocked on decision #1 (see the coupling section above).
- **4.4 roxygen** — already done and verified each phase; `RoxygenNote` unchanged.

---

## Consolidated action list

### Quick Wins (< 30 min)

1. **Flip `m_cde` default to `0`** — one line + two test expectations. Removes the only
   cross-engine inconsistency in the package.
2. **Bump `Version: 0.4.0`, `Date: 2026-08-22`** — 2 live lines, then `grep -rn "0\.3\.2"` sweep
   over the prose files.
3. **Decide the PR shape** — no code, just stop planning a second PR.

### Medium Effort (1–2 hrs)

4. **Phase 4 proper** — `extraction.qmd` section, `getting-started.qmd` engine mention, NEWS
   entry under the new heading. ~30–40 min once #2 unblocks the heading.

### Long-term (future sessions)

5. **Promote `m_star` to a `fit_mediation()` argument** (decision 2, option C) — closes the
   pre-existing glm-engine gap where the reference level is unreachable. Its own spec + PR.

---

## Recommended Next Step

→ **Start with #1 (flip `m_cde` to `0`).** It is ten minutes, it is the only item that changes
reported numbers, and doing it before Phase 4 means the vignette is written once against the
final behavior rather than written and then corrected.
