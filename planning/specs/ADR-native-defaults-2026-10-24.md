---
decisions:
  - {id: E-1, title: "fixed_x defaults to TRUE: warn in 0.14.0, flip in 0.15.0", status: decided, date: 2026-10-24}
  - {id: E-2, title: "meanstructure defaults to TRUE on the same schedule as fixed_x", status: decided, date: 2026-10-24}
  - {id: E-3, title: "One default for fit_sem() and fit_mediation(engine = 'native')", status: decided, date: 2026-10-24}
  - {id: E-4, title: "compare_lr() supports fixed_x and a saturated mean structure", status: decided, date: 2026-10-24}
  - {id: E-5, title: "Only the default is lenient about statements on exogenous variables", status: decided, date: 2026-10-24}
  - {id: E-6, title: "Dependents get a [BREAKING] notice and pass the settings explicitly", status: decided, date: 2026-10-24}
  - {id: E-7, title: "Tests and gates that encode the old defaults pin them", status: decided, date: 2026-10-24}
  - {id: E-8, title: "Fix the pinned-parameter SE under a mean structure before the flip", status: decided, date: 2026-10-24}
  - {id: E-9, title: "Opt-in to the new defaults through options(medfit.native_defaults)", status: decided, date: 2026-10-24}
  - {id: E-10, title: "Unset is detected with missing(); fit_mediation() forwards only supplied settings", status: decided, date: 2026-10-24}
  - {id: E-11, title: "The fixed_x default fixes product columns too", status: decided, date: 2026-10-24}
  - {id: E-12, title: "Reliability under the new defaults is a 0.15.0 blocker", status: decided, date: 2026-10-24}
  - {id: E-13, title: "The fixed_x default resolves to an explicit subset (provenance)", status: decided, date: 2026-10-24}
  - {id: E-14, title: "Versioned resolution: 0.15.0 ignores the opt-in option", status: decided, date: 2026-10-24}
  - {id: E-15, title: "An oracle matrix gates the flip", status: decided, date: 2026-10-24}
---

# ADR: the native engine's defaults for `fixed_x` and `meanstructure`

**Date:** 2026-10-24. **Spec:** `planning/specs/SPEC-native-defaults-2026-10-24.md`.
**Evidence:** `planning/specs/evidence/native-defaults-2026-10-24/`, `BRAINSTORM-fixed-x-default-2026-10-24.md`.

## 1. Context

`fit_sem()` and `fit_mediation(engine = "native")` estimate the exogenous variances and covariances
(`fixed_x = FALSE`) and fit a mean structure only when the syntax asks for one (`meanstructure = NULL`). lavaan's
`sem()` and semopy hold exogenous variables at their sample moments; lavaan with `meanstructure = TRUE` estimates
the intercepts. OpenMx has no such option: an exogenous variance it is not given is a fixed zero, and the fit fails.
So medfit's defaults are the odd ones out, and every comparison in its docs passes `fixed.x = FALSE` to lavaan.

`fixed_x` is documented and gated to leave structural estimates, their SEs, chi-square and df unchanged; a
saturated mean structure left them and the log-likelihood unchanged on the cases measured (one observed model, the
frozen fixtures), not yet on weighted, constrained-intercept, latent, product or factor models (E-15). Both change
the parameter vector, `npar`, AIC and BIC; `fixed_x` also makes the log-likelihood conditional on the fixed block. The 0.11.0 API
freeze says exported signatures change only through a deprecation.

## 2. Decisions

**E-1. `fixed_x` defaults to TRUE, through a deprecation cycle.** 0.14.0 warns when the caller leaves `fixed_x`
unset and the model has an observed exogenous variable; 0.15.0 flips. Rejected: flipping in 0.14.0 as a breaking
change (breaks the freeze promise for no correctness gain); an opt-in option only (leaves medfit unlike lavaan
forever). Author, 2026-10-24 (brainstorm D1).

**E-2. `meanstructure` defaults to TRUE on the same schedule.** One message and one flip for both.
Measured: no dependent changes (six suites, per-test identical), the covariance-part estimates and the
log-likelihood are unchanged; 60 medfit tests fail, of which 15 are real (E-4, E-8). Rejected: `meanstructure` first as a 0.14.0 breaking change; dropping
the `meanstructure` change. Author, 2026-10-24 (grill Q1).

**E-3. One default for both entry points.** `fit_mediation(engine = "native")` resolves through `fit_sem()`. Rejected:
`fit_sem()` only (one model, two likelihoods). Author, 2026-10-24 (D2).

**E-4. `compare_lr()` accepts `fixed_x` and a saturated mean structure.** It refuses both today
(`.lr_unsupported()`), so after the flip it would refuse every default fit (14 tests fail under the
`meanstructure` flip alone). lavaan takes `fixed.x`/`meanstructure`; the OpenMx adapter writes fixed exogenous paths
and a means path. Rejected: keep refusing. Author, 2026-10-24 (D3); extended to the mean structure here.

**E-5. Only the default is lenient.** When the default (not the user) fixes a variable the model writes a statement
on, that variable stays free with a note; an explicit `fixed_x = TRUE` still errors. Rejected: error for both (the
flip would break models that are valid today). Author, 2026-10-24 (D4).

**E-6. Dependents.** A `[BREAKING]` issue with the 2-month notice; RMediation passes the settings explicitly.
Measured: RMediation's MBCO statistics agree to 1e-12 under the flip, so only the warning reaches it. Author,
2026-10-24 (D5).

**E-7. Pin the old defaults where a baseline depends on them.** Gates and frozen fixtures pass the old values;
new tests cover the new defaults. Rejected: re-baseline everything (loses the link to the 0.8.0 and 0.9.0 frozen
values, which the measurement shows still agree by name to 1e-8). Author, 2026-10-24 (D6).

**E-8. Fix the pinned-parameter SE under a mean structure first.** With a mean structure, a parameter
fixed by `b == 0` gets SE 5.6e-18 and a z-statistic; without one it gets 0 and `NA`. It reproduces on today's
build with an explicit `meanstructure = TRUE`, so it is a bug now and would reach every constrained default fit
after the flip. It is the first task of the 0.14.0 work. Rejected: a separate patch PR now. Author, 2026-10-24
(grill Q7, against the recommendation).

**E-9. Opt-in through a package option.** `options(medfit.native_defaults = "0.15")` switches both defaults and
silences the warning during 0.14.x; removed in 0.16.0. Passing the values explicitly also silences it (the warning
fires only when a setting is unset). Rejected: no switch (dependents cannot run their suites under the future
defaults). Author, 2026-10-24 (grill Q2).

**E-10. Unset is `missing()`.** `fit_sem()` checks `missing(fixed_x)` and `missing(meanstructure)`, so an explicit
`meanstructure = NULL` keeps its meaning (follow the syntax); `fit_mediation()` forwards a setting only when the
caller put it in `engine_args`, the pattern medfit uses for `m_star`. Rejected: a sentinel object in the formals;
dropping `NULL`'s meaning. Author, 2026-10-24 (grill Q3).

**E-11. Products are fixed too.** The `fixed_x` default fixes every observed exogenous column, `x:m` product
columns included, as `fixed_x = TRUE` does today. Rejected: products free under the default. Author, 2026-10-24
(grill Q5). VERIFY in the 0.15.0 PR that lavaan's `fixed.x = TRUE` treats the product column the same way
(the recommendation assumed it).

**E-12. Reliability is a blocker.** 0.15.0 merges only when the reliability gate under the new defaults is
non-inferior to the last green run (rule of D-8). Rejected: a follow-up run. Author, 2026-10-24 (grill Q6).

**E-13. Provenance: the default resolves to a subset.** An implicit `fixed_x = TRUE` becomes, inside
`fit_sem()`, the explicit character vector of observed exogenous columns (products and factors included) minus those
the model writes a `~~` or `~1` statement on; an empty vector means `FALSE`. That carries E-5's lenience without a
flag through the internals, and refits see the same subset. Rejected: a default-origin flag passed through
completion (touches every internal call). Codex review, 2026-10-24; approved by the author, 2026-10-24.

**E-14. Versioned resolution.** 0.14.x: unset takes the old value unless `medfit.native_defaults` is set.
0.15.0: unset takes the new value unconditionally and the option is ignored with an obsolete note. An explicit
value is never overwritten. Rejected: the first sketch, which re-derived unset values from the option in both
releases and so would have undone the flip. Codex review, 2026-10-24; approved by the author, 2026-10-24.

**E-15. An oracle matrix gates the flip.** The four setting combinations crossed with weights and sandwich
SEs, fixed and constrained intercepts, a latent mediator, a four-way product, a factor covariate and a named subset,
against lavaan or a stated oracle, before 0.15.0. Rejected: relying on the existing suites, which pass unchanged in
the dependents but need not exercise the new defaults. Codex review, 2026-10-24; approved by the author, 2026-10-24.

## 3. Consequences

- Default fits match lavaan's default `sem()` in the structural estimates, standard errors, df and chi-square, and
  in the conditional logLik. `AIC()` and `BIC()` keep medfit's own parameter count (the observed means that are not
  fixed, whether or not they are in the parameter vector), which equals lavaan's count under
  `meanstructure = TRUE` for any `fixed_x`; against a default `lavaan::sem()` (no mean structure) medfit's AIC is
  larger by 2k and its BIC by k log n (k = observed means not fixed). The docs stop
  passing `fixed.x = FALSE`.
- Every default fit's parameter vector, names and retry seed change in 0.15.0. Well-identified fits give the same
  estimates; which random start wins can change, and with it a start-spread warning.
- Two releases of work: 0.14.0 carries the fixes (E-4, E-8, the refit settings), the warning and the test pinning;
  0.15.0 carries the flip and the doc rewrite.

## 4. What would change this decision

- A dependent whose results move under the flip (none today).
- A gate whose acceptance rate drops under the new defaults (not measured yet; a 0.15.0 criterion).
- lavaan changing its own defaults.
