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
**Why (corrected by D9):** omitting a mediator that is a *descendant* of the retained regressors
folds its path in cleanly, but the folded coefficients are reduced-form, not the structural paths.
Omitting an *ancestor* mediator confounds the fit. The original "every sub-model is exactly
correctly specified" claim was false for the serial demo; see D9.
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

**Decision (targets corrected by D9):** replace "byte-identical `.rda`" with (a) `data-raw/mediation_demo.R` pins `RNGkind()`
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
(the floor that keeps D4's 3-SE test non-vacuous). ~~c′ = 0.2 (~1.5 SE) is deliberately small,
giving one honest "CI covers zero" demo.~~ **Withdrawn (D9):** no medfit demo estimates the
structural c′; the fitted c′ is 0.26–0.41.
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

### D8 — guard multi-mediator extraction against product terms (confirmed 2026-09-23)

**Finding:** multi-mediator `extract_mediation()` returns before any interaction check. On the
lm path the `length(mediator) >= 2` branch (`R/extract-lm.R:208`) runs ahead of
`.find_interaction_term()` (`:247`), and the lavaan path has the same ordering (multi-mediator
branch near `R/extract-lavaan.R:145`, interaction check at `:175`). A serial fit whose outcome model
has a treatment × mediator1 term (coefficient 0.82, n = 5000) returns a main-effects
`SerialMediationData`, with no error or warning. This was reproduced on 0.3.2 and the 0.4.0 source
(lm path). The lavaan path has now also been run: the guard's lavaan tests fail on the pre-fix code.
**Decision:** (a) **guard now:** error when a multi-mediator (serial or parallel) extraction
finds product terms involving the treatment or any mediator in the outcome or mediator models, on
both the lm and lavaan paths, with tests (a serial and a parallel case, each on both paths). (b)
**Spec later:** a separate spec for serial mediation with exposure–mediator and mediator–mediator
product terms, citing only verified published literature.
**Why:** medfit currently returns wrong numbers silently; an error costs little and turns
the silent failure into a loud one. Full support is a methods feature that needs its own design.
**Status:** (a) **merged to `dev` as `aa3362c`** (PR #62, 2026-09-23). 7 tests; CI passed on 6
platforms plus lint and coverage; strict CRAN check 0/0/1 (the Date-field NOTE `dev` also has). (b) is
still open (see Open questions).
**Relation to this spec:** independent of the dataset PRs, and should ship first. Once it lands,
fitting `outcome_int` with serial mediators errors instead of silently dropping the interaction,
so D1's rule that serial demos use `outcome` is enforced by code.
**Rejected:** a warning instead of an error (a warning is easy to miss and the result is still
wrong); implementing full support now (out of scope, needs a methods spec).

### D9 — adversarial-review corrections (2026-09-23)

Two independent reviews (opencode `big-pickle`, read-only; one from this session and one from
the session that wrote the spec) reached the same critical finding. The numbers below are
confirmed by an n = 2×10⁶ simulation of the D6 DGP.

**R1 — the serial demo must include mediator1 in the outcome model (critical).** medfit's
documented serial outcome form is `Y ~ X + Mk + covariates` (`R/extract-lm.R:23–24`), and the serial worker
reads only `coef_y[mediators[k]]` (`:760`). Under D6, mediator1 causes both mediator2 (0.5) and
the outcome (0.4). So `outcome ~ treatment + mediator2 + C` omits a common cause, and
plim b(mediator2) = 0.46 against a true 0.30 (+53%). **Fix:** the serial demo fits
`outcome ~ treatment + mediator1 + mediator2 + covariate1 + covariate2`. The extractor only requires `Mk` in
`model_y`; the simulation recovers b(mediator2) = 0.300. Document that `SerialMediationData`'s a·d·b is the
**chain-specific** indirect effect (its class has only a/d/b/c′ slots, so the mediator1 → outcome
and treatment → mediator2 paths are not represented), not the total indirect effect.

**R2 — known-answer targets are per-demo reduced-form values, not D6's structural paths
(high).** Every omitted downstream mediator folds into the retained coefficients. D4's test
compares against these plims (simulation, n = 2×10⁶):

| Demo (all adjust for covariate1, covariate2) | Target coefficients |
|---|---|
| simple `outcome ~ treatment + mediator1 + C` | b = 0.55, c′ = 0.41 (covariate1 0.36, covariate2 0.20) |
| parallel `outcome ~ treatment + mediator1 + mediator3 + C` | b1 = 0.55, b3 = 0.30, c′ = 0.26 |
| serial `outcome ~ treatment + mediator1 + mediator2 + C` | b(mediator2) = 0.30, b(mediator1) = 0.40, c′ = 0.35 |
| interaction `outcome_int ~ treatment * mediator1 + C` | θ1 = 0.41, θ2 = 0.55, θ3 = 0.50 |

The a and d paths (the mediator equations) are structural in every demo. The four-way components
of the interaction demo are therefore built from these reduced-form θ1/θ2 (for example
PIE = θ2·β1 = 0.275), and the test targets them, not structural values. The test file records
both sets, with a comment explaining why they differ. At n = 250 a 3-SE window (~0.18 for b) is
wider than the 0.15–0.25 structural-vs-reduced-form gaps, so testing against structural values
would pass a mislabeled estimand.

**R3 — withdraw the "CI covers zero" c′ demo; scope the floor (high).** The fitted c′ is
0.26–0.41 in every demo, and no medfit structure extracts the all-mediator model where c′ = 0.2.
The |est/SE| ≥ 3 floor applies only to the **named paths** (a, a3, d, b per demo, θ3). Covariate coefficients
are exempt: covariate2 → mediator1 (t ≈ 2.4) and treatment → mediator2 (t ≈ 1.5) would fail it at n = 250.

**R4 — make seed selection auditable (medium).** The named-path t-values sit near 4 (a,
a3, θ3), so a first seed passes the floor only ~35–45% of the time. `data-raw` records `RNGkind()`,
the seed, the retry count, the generating R version (bitwise reproducibility is not guaranteed
across R versions; `sample()` changed in 3.6.0), and a per-path t table. Retries are triggered
**only** by the floor, never after looking at the known-answer test. The known-answer test is the
real cross-version gate.

**R5 — spec text PR 1 would be graded against (medium).** The spec's §4 `\examples` call omits the covariates
(D3 forbids that, and it also runs during `R CMD check`), and §5 still promised a byte-identical `.rda`. Both are corrected in
the spec alongside this entry.

**R6 — regmedint constraints on the interaction demo.** `formula_m` terms must equal
treatment + covariates exactly (`R/fit-regmedint.R:185–194`), so the D3 covariates go in both
formulas. Treatment must be numeric 0/1, which D6 satisfies.

**Rejected finding:** "the @examples claim is 9 files, not 10" — 10 `R/*.R` files have `rnorm()`
inside `@examples` (recounted).

## Resulting column set (supersedes spec §3 table)

`treatment` (binary, randomized) · `mediator1` · `mediator2` (serial child of `mediator1`) ·
`mediator3` (parallel, depends on `treatment` only) · `covariate1` (continuous) · `covariate2`
(binary) · `outcome` (no X:M term) · `outcome_int` (with `treatment:mediator1`) — **8 columns**.

## Open questions

- **Spec §3–§5** still describe the old 7-column shape; update them from this ledger when
  implementation starts.
- **n = 250 vs 400:** R4's thin floor margins (a-path t ≈ 4) would widen at n ≈ 400 (t ≈ 5), making
  seed retries rare. Changes the spec's stated n; not decided.
- **Out of scope, flagged:** a dead `fit_mediation()` stub at `R/aab-generics.R:169`
  (`stop("not yet implemented")`) loses to `R/fit-glm.R:132` only through alphabetical load order
  (no `Collate`). *(Resolved: the `.Rbuildignore` NEWS exclusion and the duplicate `.code-workspace`
  pattern, fixed in `dd9e883`.)*
- **D8(b) spec:** not yet written. It gets its own `SPEC-*.md` (serial mediation with
  exposure–mediator and mediator–mediator product terms), separate from this dataset spec.
