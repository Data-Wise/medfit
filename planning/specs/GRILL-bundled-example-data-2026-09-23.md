# GRILL: bundled example data (mediation_demo)

**Date:** 2026-09-23 · **Target:** [SPEC-bundled-example-data-2026-09-23.md](SPEC-bundled-example-data-2026-09-23.md)
**Sweep facts:** `extract_mediation()` supports serial (`R/extract-lm.R:859`), parallel (`:1108`),
and X:M interaction (`:617`, plus the regmedint engine `R/fit-regmedint.R:469`); medfit has no
moderated-mediation (W-moderated path) fitting. Shared root of §7: one equation can make only one
model correctly specified.

## Decision ledger

### D1 — §7.1: the `moderator` column

**Decision:** drop `moderator`; add `outcome_int`, generated with a real `treatment:mediator1`
term. `outcome` stays interaction-free.
**Why:** every demo fits the model its data came from; no column exists that no medfit function uses.
**Rejected:** one outcome with X:M (simple demo misspecified); keep for future moderated mediation
(YAGNI); no interaction demo (0.4.0's four-way feature gets no example).

### D2 — §7.2: serial vs parallel

**Decision:** `mediator2 ~ treatment + mediator1` (serial child); add `mediator3 ~ treatment` only.
Serial demo: treatment → mediator1 → mediator2. Parallel demo: mediator1 + mediator3. Simple demo:
treatment → mediator1. One DGP, one `outcome` (and `outcome_int`, D1).
**Why:** in a linear Gaussian DGP, omitting a mediator folds its path into the remaining
coefficients with an error still independent of the regressors, so every sub-model is exactly
correctly specified.
**Rejected:** serial-only (parallel demo biased); parallel-only (serial demo shows d ≈ 0); two
`mediator2` columns (needs an outcome per variant — columns multiply).

### D3 — covariates

**Decision:** `covariate1`/`covariate2` are real mediator–outcome confounders; `treatment` is
randomized (independent of covariates). Every documented example, article demo, and `\examples`
call adjusts for both covariates — including the spec's §4 item 3 example, which currently omits them.
**Why:** realistic, and it is the conditional-ignorability lesson medfit users need. Leaving
covariates out of any demo would bias it silently and break D2's correct-specification argument.
**Rejected:** outcome-only predictors (can't show why adjustment matters); adjusted-vs-unadjusted
article (extra upkeep, deferred); no covariates (no realistic adjusted fit).

### D4 — acceptance guarantee

**Decision:** replace "byte-identical `.rda`" with (a) `data-raw/mediation_demo.R` pins `RNGkind()`
+ `set.seed()`, and regenerating gives `identical()` data-frame values; (b) a known-answer
testthat test: covariate-adjusted fits on the shipped data recover the true paths within ~3 SE.
**Implementation note:** `data-raw/` is Rbuildignored, so tests cannot read the true values from
it at check time. The test hard-codes them, with a comment pointing at the `data-raw` block
that defines them; the two must be kept in sync.
**Why:** catches a wrong DGP (sign error, missing X:M term), not just drift; bytes vary with
serialization/compression across R versions without any real defect.
**Rejected:** values only (DGP bugs ship); byte-identical (fragile, checks nothing); known-answer
only (no proof `data-raw` still regenerates the shipped data).

### D5 — implementation split

**Decision:** two PRs. PR 1: `data-raw/`, `data/mediation_demo.rda`, `R/data.R`, `LazyData: true`,
`^data-raw$` in `.Rbuildignore`, the known-answer test (D4), `NEWS.md`, the `getting-started` article,
and the two README fixes. PR 2: `introduction`/`extraction` articles plus the simple-model `@examples`.
**Why:** PR 1 stays reviewable and lets the dataset's numbers settle before three more surfaces
depend on them.
**Rejected:** one PR (article number churn hides DGP mistakes); data-only PR 1 (nothing
user-facing); separate README PR (extra cycle for two one-line fixes).

### D6 — true effect sizes

**Decision:** moderate effects, standardized-scale errors (SD 1), randomized 50/50 `treatment`:

| Equation | Terms |
|---|---|
| `mediator1` | 0.5·treatment + 0.3·covariate1 + 0.3·covariate2 |
| `mediator2` | 0.2·treatment + 0.5·mediator1 + 0.2·covariate1 |
| `mediator3` | 0.5·treatment |
| `outcome` | 0.2·treatment + 0.4·mediator1 + 0.3·mediator2 + 0.3·mediator3 + 0.3·covariate1 + 0.2·covariate2 |
| `outcome_int` | `outcome` terms + 0.5·treatment×mediator1 |

`data-raw` asserts that on the shipped data, every nonzero path except c′ has |estimate/SE| ≥ 3
(the floor that keeps D4's 3-SE test non-vacuous). c′ = 0.2 (~1.5 SE) is deliberately small,
giving one honest "CI covers zero" demo.
**Seed disclosure:** if the first seed misses the floor, the retry is recorded in the `data-raw`
comment block (seed chosen to meet a stated detectability floor, not to hit particular estimates).
**Why:** realistic magnitudes; a path near 0 would make its known-answer check pass for any estimate.
**Rejected:** large ≈0.7 effects (unrealistically clean, no near-null contrast); no floor (a bad
seed makes D4 vacuous without anyone noticing); exact-zero c′ (can't be sign-checked).

### D7 — cover story

**Decision:** remapped workplace-training story, used only in `R/data.R` and article prose (column
names stay generic): `treatment` = randomized assignment to a training program; `mediator1` =
skill confidence; `mediator2` = task mastery (built on confidence → serial); `mediator3` =
supervisor check-ins (triggered by assignment alone → parallel); `covariate1` = prior performance
rating; `covariate2` = full-time status; `outcome` = job performance; `outcome_int` = job
performance where confidence pays off more for trained employees. `@source` states it is simulated
and describes no real study.
**Why:** every arrow in the DGP has a plausible reading, which keeps the article prose concrete.
**Rejected:** abstract only (dry, can't motivate paths); health story (invites "is this real?");
education story (full prose rewrite, no gain).

## Resulting column set (supersedes spec §3 table)

`treatment` (binary, randomized) · `mediator1` · `mediator2` (serial child of `mediator1`) ·
`mediator3` (parallel, depends on `treatment` only) · `covariate1` (continuous) · `covariate2`
(binary) · `outcome` (no X:M term) · `outcome_int` (with `treatment:mediator1`) — **8 columns**.

## Open questions

- **Spec §3–§5** still describe the old 7-column shape; update them from this ledger when
  implementation starts.
