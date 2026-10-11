# HANDOFF: RMediation MBCO on medfit's `mbco_sem()`

**For:** a separate Claude session rooted in `~/projects/r-packages/active/RMediation` (grill G7). Do not run this from the medfit session: it makes no cross-repo writes.
**Date:** 2026-10-11 | **From:** medfit 0.8.0 grill, decisions G3, G3b, G7 (`GRILL-medfit-0-8-0-2026-10-11.md`)
**Basis:** read-only inspection of RMediation `dev` (clean at the time, HEAD `7c588d4`) and medfit `dev` (`67b6db8`). File and line facts below are from that read; re-verify before relying on them.

> **REVISION 2026-10-11 (grill G10): this handoff is partly superseded and is now blocked.** RMediation will register `mbco()` on **(SEMFit, SEMFit)**, built on medfit's `anova()` (W4, G9) and W3's zero-product branch split, instead of the path-label route in section 1 item 1. Same `h0`/`h1` meaning as the OpenMx pair; `mbco_sem(fit, a, b)` stays a medfit convenience that RMediation does not call. **Do not start this work until `anova()` for `SEMFit` and W3 are merged in medfit dev**; the medfit session will say when. Sections 0, 2 (oracle and planted defects), 3 (release constraints) and 5 still apply. Parity test addition: `mbco(h0 = SEMFit fitted with `a1*b1 == 0`, h1 = full SEMFit)` on `memory_exp` must give 0.083100 (the min-of-two answer), and the same call without W3's branch split gives 221.05 (planted defect).

## 0. Decision the user must confirm first: the rebase is smaller than G3 assumed

G3 said "rebase RMediation's MBCO on `mbco_sem()`", expecting to drop OpenMx and the hard lavaan import. Reading both sides shows the two functions are **not interchangeable**:

| | RMediation `mbco()` | medfit `mbco_sem()` |
|---|---|---|
| Input | two fitted OpenMx `MxModel`s, `h0` and `h1` (`R/mbco.R`: "h0 must be an MxModel") | one `SEMFit` from `fit_sem()`, plus the labels `a` and `b` of two free `~` paths |
| Hypothesis | any nested pair; df from `mxCompare` | only `a*b = 0` |
| Test types | `asymp`, `parametric` bootstrap, `semi` bootstrap (`mbco_asymp.R`, `mbco_parametric.R`, `mbco_semi.R`) | asymptotic only |
| How the null is solved | the user's own `h0` (a nonlinear `ind == 0` null lands at the wrong branch, rmediation#35 finding 2) | two linear refits (`a == 0`, `b == 0`), statistic is the smaller diffLL, df = 1, never solves the nonlinear null |
| Result | `MBCOResult(statistic, df, p_value, type)` | `htest`-class `mbco_sem` |

Consequences:
- A `SEMFit` cannot be built from an `MxModel`, so the OpenMx path **stays** for users who bring `MxModel`s and for both bootstrap types. OpenMx is already in Suggests (`DESCRIPTION`), so there is no hard dependency to remove.
- The achievable change is **additive**: a second route into `mbco()` for medfit `SEMFit` objects (min-of-two LRT), which avoids the nonlinear-null trap for the common `a*b` case. It does not remove OpenMx.
- The hard `lavaan` Import is a **separate** matter: the survey found it is mostly used for `lav_matrix_vech_reverse` in `ci.R:165`, `pMC.R:63`, `qMC.R:61`, `utils_validation.R:100`, not MBCO. Treat it as an independent cleanup ticket, not part of this change.

**Ask the user: is the additive scope acceptable, or is the goal (remove OpenMx) worth a breaking API change?** Recommendation: additive. The breaking alternative drops `type = "parametric"` and `"semi"` and every `MxModel` caller.

## 1. Proposed scope (additive)

1. Add an S7 method for `mbco()` whose `h0`/`h1` carry a medfit `SEMFit`, or a clearly named sibling (decide with the maintainer), that calls `medfit::mbco_sem(fit, a, b)` and wraps the result in `MBCOResult(statistic = ..., df = 1, p_value = ..., type = "asymp")`.
2. medfit stays in **Suggests**, behind `requireNamespace("medfit", quietly = TRUE)` with a version check (`>= 0.8.0` for the API below); an informative error otherwise.
3. Docs: Rd and NEWS entry; state that the min-of-two route covers `a*b = 0` only, and that bootstrap types still need OpenMx.
4. Optional, tracked by rmediation#35: fix the Rd example's shifted labels (`endVar` starts with `"x"`, so labels shift to a2, cp, a1).

Out of scope: removing OpenMx; the lavaan Import cleanup; anything needing medfit's nonlinear constraints (medfit W3), which this change does not depend on.

## 2. Parity test (must be able to fail)

Oracle data: RMediation's `memory_exp` (the dataset medfit's own known answers use). Build the correct OpenMx linear nulls (a1 = 0 and b1 = 0, labels checked, see rmediation#35) and compare:

| Quantity | Expected | Tolerance |
|---|---|---|
| diffLL for `a1 == 0` | 221.045546 | 1e-6 |
| diffLL for `b1 == 0` | 0.083100 | 1e-6 |
| new route's statistic | 0.083100 (the minimum) | 1e-6 |
| df | 1 | exact |

(These are medfit's S19 known answers, `tests/testthat/test-sem-mbco.R:34-36`.) Planted defects, each must turn the test red:
- Taking the **larger** diffLL (the wrong nonlinear branch): statistic 221.05 vs 0.0831.
- The shifted-label model from the Rd example as written: `mxCompare` gives 0.060332, so the test also proves the labels are right.
- A medfit older than 0.8.0 installed: the route must error informatively, not return a number.
- A boundary null (Codex review, G9): `mbco(h0 = SEMFit with `a == 0`, h1 = SEMFit with `a > 0`)` must not return an ordinary chi-square p-value; it must warn that the statistic is a mixture of chi-squares or refuse, exactly as `mbco_sem()` does for an active bound at the null (`R/sem-mbco.R:140-165`). Planted defect: remove the boundary check in `anova()` and the test must turn red.

Run the full parity test only when OpenMx and medfit >= 0.8.0 are installed (`skip_if_not_installed` for both), so CRAN-style checks skip it.

## 3. Release constraints (D9, G3b)

- Do the work on a feature branch off RMediation's integration branch (verify with `git branch -a`; `dev` at survey time).
- RMediation 1.7.0 is on CRAN. This change needs medfit >= 0.8.0, which is **GitHub-only** until a CRAN release. On the dev branch a `Remotes: Data-Wise/medfit` line is acceptable for testing; **strip it before any CRAN submission**, and do not release RMediation to CRAN until a medfit release carrying `mbco_sem()` is on CRAN.
- Keep `Suggests: medfit (>= 0.2.0)` for CRAN-built behavior unless the new route requires a bump; a bumped Suggests pin that CRAN cannot satisfy fails incoming checks.
- Strict flavors before any submit: `--run-donttest` plus `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, and the two `_CRAN_INCOMING_` variables (see the RMediation project notes).

## 4. What medfit provides, and what it does not

Provides in 0.8.0: `mbco_sem(fit, a, b, n_starts = NULL, control = NULL)`, the `mbco_sem`/`htest` result with `statistic`, `parameter`, `p.value`, `tests` (one row per refit), experimental lifecycle badge. A fit made with `sampling_weights` is refused, as is a non-converged fit.
Does not provide (in 0.8.0 as scoped today): bootstrap MBCO or conversion from an `MxModel`; a general two-model LRT for `SEMFit`s is planned in W4 (G9) but is not a dependency of this change. If the maintainer later wants `type = "parametric"` on the SEMFit route, that is a medfit feature request (now planned in medfit W4 as `anova()` / a two-model LRT for `SEMFit`, grill G9; asymptotic only at first, a bootstrap LRT would follow), not a RMediation task.

## 5. Definition of done

- New route implemented, documented, NEWS entry; OpenMx path unchanged and its tests green.
- Parity test above present, with the four planted defects demonstrably red when each mechanism is removed.
- Strict-flavor `devtools::check()` clean or with only pre-existing notes, counts reported.
- No CRAN submission; the medfit-on-CRAN dependency recorded in `.STATUS`.
- Report back to the medfit session with: branch name, commit, test counts, and any API mismatch found.
