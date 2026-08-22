# BRAINSTORM: Next Features — medfit + mediationverse

**Date:** 2026-08-22 · **Depth:** default · **Focus:** feature
**Context:** medfit 0.3.2 CRAN-published (2026-07-23). Extensions A (parallel mediation) and
B (VanderWeele four-way interaction) complete across lm/glm + lavaan. Extension C (engine
adapters — CMAverse/tmle3) is already spec'd as the next roadmap item (see
`EXTENSIONS-PLAN-2026-06-03.md`) — **not re-litigated here**. This brainstorm covers what
comes *after/alongside* Ext C, grounded in the user's research areas (causal mediation,
sensitivity analysis, longitudinal/sequential mediation, mediation meta-analysis, collider
bias) as evidenced by their savant skill library.

**Decisions locked during this session:**
- New structures to prioritize: **longitudinal/time-varying mediation** + **multilevel/clustered
  mediation** (both selected over moderated-mediation-beyond-4-way and "Ext C is enough").
- `mediationverse` stays a **thin** bundling/docs hub — no new active features, no unified
  dispatcher, no meta-analysis tooling added there.

---

## Quick Wins (< 1 day each)

1. **`SPEC-engine-registry.md` + `SPEC-cmaverse-adapter.md`** — write the two specs Ext C is
   already blocked on (design exists in `medfit-roadmap.md` §7b–7c; just needs transcription
   into spec form + a worktree). This is the actual next mechanical action, not a new idea.
2. **`vcov` naming-contract doc** — Extensions A/B/(D/E below) all extend the same
   `estimates`/`vcov` naming convention; a one-page internal doc (`docs/dev/vcov-naming.md`)
   prevents each new class from re-deriving the convention from scratch.
3. **`mediationverse` pkgdown cross-links** — verify the meta-package's reference index
   already surfaces Ext A/B (parallel + interaction) now that they've shipped; likely stale
   since 0.1.0 predates both.

## Medium Effort (1–3 weeks each)

4. **Extension D — Multilevel/clustered mediation** (`MultilevelMediationData`)
   - **User story:** As a researcher with nested data (patients in clinics, students in
     schools), I want `extract_mediation()` to recognize a fitted `lme4`/`nlme` model and
     return random-effects a/b paths, so I can compute cluster-level and average indirect
     effects without hand-rolling the extraction.
   - **Scope:** 1-1-1 mediation (all levels random) first; 2-1-1/1-1-2 (level-2 treatment or
     outcome) as a follow-up, not this pass.
   - **Existing pattern to reuse:** same class-per-structure approach as
     `SerialMediationData`/`ParallelMediationData` — a new S7 class, not a modification to
     existing ones.
   - **Acceptance criteria:** validated against a known-answer multilevel mediation dataset
     (e.g. reproduce a published `MLmed`/`Mplus` 1-1-1 example); vcov naming contract extended
     for random-effect variance components; vignette showing lme4 input → class output.
   - **Risk:** REML vs ML fitting changes what's identifiable — needs an explicit
     `fit_mediation(..., reml = )` decision surfaced to the user, not silently defaulted.

5. **Extension E — Longitudinal / time-varying mediation** (`TimeVaryingMediationData` or
   similar name — TBD at spec time)
   - **User story:** As a researcher with repeated-measures treatment/mediator/outcome data
     (panel/longitudinal design), I want medfit to extract time-varying a/b/c′ paths across
     waves, so I can estimate cumulative or wave-specific indirect effects without switching
     to a separate g-methods package for the extraction step.
   - **Scope:** this is the largest new estimand medfit would take on — closer to Ext C
     (external-engine territory) than to A/B (closed-form). Likely needs its own
     engine-adapter-style wrapper (parametric g-formula via a `Suggests` package) rather than
     a pure closed-form class, since time-varying confounding is exactly the g-methods use
     case.
   - **Sequencing implication:** **should follow Ext C**, not run in parallel with it — Ext C's
     engine-registry pattern (adapter contract, `Suggests`-gated external engine) is the
     mechanism this extension would reuse. Doing D (multilevel) before E (longitudinal) avoids
     blocking on Ext C's registry work.
   - **Acceptance criteria:** validated against a published time-varying mediation example
     (e.g. reproduce a `gfoRmula`-style or `lavaan` growth-mediation result); explicit
     documentation of what confounding assumptions are required (sequential ignorability),
     since this is the estimand most likely to be misused if under-documented.
   - **Risk (biggest one in this brainstorm):** silently wrong estimates under time-varying
     confounding if the adapter doesn't enforce/document the sequential-ignorability
     assumption — this is a correctness risk, not just a UX one.

## Long-term (future sessions)

6. **Collider-bias diagnostics as a companion, not a medfit feature** — your
   `collider-bias-toolkit` research angle is a *diagnostic/sensitivity* concern, which per
   medfit's own "infrastructure not effect sizes" principle belongs in **medrobust**
   (sensitivity bounds), not medfit itself. Flagging so it doesn't get scope-crept into medfit
   later — same reasoning that already kept P_med in probmed and DOP/MBCO in RMediation.
7. **`mediationverse` stays thin (confirmed this session)** — revisit only if a genuine
   cross-package need emerges (e.g. once Ext D/E ship, whether a unified vignette comparing
   "which structure do I need" across simple/serial/parallel/interaction/multilevel/
   longitudinal becomes valuable). Not scoped now.

## Recommended Next Step

→ **Item 1** (write `SPEC-engine-registry.md` + `SPEC-cmaverse-adapter.md`) — Ext C is already
the committed next extension and is only blocked on missing specs, not on anything from this
brainstorm. Do Ext D (multilevel) after Ext C ships, since D doesn't depend on the engine
registry; sequence Ext E (longitudinal) last, after Ext C's adapter pattern exists to reuse.

---

## Test-Plan Scaffolding (default-on)

Tier inference (new S7 class + extraction methods + external-engine touch for Ext E):

| Tier | Applies? | Reason |
|---|---|---|
| `unit` | ✅ | New class validators, new extraction methods per structure |
| `integration` | ✅ | `extract_mediation()` dispatch across lm/glm/lavaan/lme4 inputs |
| `dependency` | ✅ (Ext E only) | External g-methods package as `Suggests`, same pattern as Ext C's CMAverse |
| `e2e` / `dogfood` | ✅ | Full extract → fit → bootstrap → vignette round-trip per new class |
| `count-cascade` | N/A — no new command/skill/agent, this is package code | |

```r
# TODO(author): delete if not contract-bearing
test_that("MultilevelMediationData validator rejects mismatched a/b random-effect lengths", {
  expect_error(
    MultilevelMediationData(a_paths = c(0.5, 0.3), b_paths = c(0.2)),
    "must have equal length"
  )
})
```

```r
# TODO(author): delete if not contract-bearing
test_that("time-varying extraction documents sequential-ignorability assumption in output", {
  # placeholder — asserts the returned object/print method surfaces the assumption,
  # not just the point estimate, per the correctness risk noted in Ext E above
  expect_true(FALSE)  # red-first stub
})
```

## Documentation (default-on)

Doc-impact scoring (threshold ≥3, per `doc-impact-rubric.md`):

- [x] **Guide/vignette** — score 5 (new user-facing structure + new fitting workflow) — needed
  for both Ext D and Ext E.
- [x] **Refcard/README update** — score 4 (new exported class + generic methods change the
  package's surface area) — needed.
- [ ] **Demo** — N/A — score 1, no CLI/interactive demo surface in this package.
- [ ] **Mermaid diagram** — N/A — score 2 for Ext D (single new class, existing class-diagram
  pattern from A/B suffices); **reconsider for Ext E** if the adapter architecture (Ext C +
  E combined) grows complex enough to need a flow diagram — defer that call to spec time.

CHANGELOG `[Unreleased]` mirror only — no version/count-line changes (excluded per policy).

---

## Handoff

Two independent specs to write next, in this priority order:
1. `SPEC-engine-registry.md` / `SPEC-cmaverse-adapter.md` (Ext C — already committed, just needs writing)
2. `SPEC-multilevel-mediation-2026-08-22.md` (Ext D — this session's output)
3. `SPEC-longitudinal-mediation-2026-08-22.md` (Ext E — this session's output, sequenced after Ext C)

Suggested: `/craft:plan planning/specs/BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md`
to break this into a task sequence, or `/craft:grill` on Ext D specifically once you're ready
to stress-test its design before opening a worktree.
