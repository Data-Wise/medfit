# SPEC: Serial `te()` / `pm()` total-effect correctness

**Status:** DECIDED (b), implemented 2026-09-24 in b714e6e
**Date:** 2026-09-24
**Branch:** `feature/serial-total-effect` (off `origin/dev` 2b05958)
**Related:** `feature/docs-methods-math` (unmerged, no PR) documents `te()`/`pm()` as chain-only

---

## 1. Problem

`R/generics-effects.R` (`S7::method(te, SerialMediationData)`, `pm` right after):

```r
indirect <- x@a_path * prod(x@d_path) * x@b_path
te       <- indirect + x@c_prime
pm       <- indirect / te
```

For the standard serial specification

```
M1 ~ X + C
M2 ~ X + M1 + C
Y  ~ X + M1 + M2 + C
```

the total effect of X on Y is the sum over **all** directed X→Y paths:

```
TE = c' + a1*b1 + a2*b2 + a1*d*b2
       ^    ^       ^       ^ chain (what te() counts)
       |    X→M1→Y  X→M2→Y
       direct
```

`te()` drops every path that skips a link in the chain, so it is wrong
whenever any skip coefficient is nonzero. It can be either too small or too large.
`pm()` inherits the error, since both its numerator and denominator are off.

### Evidence (run 2026-09-24, n = 500, seed 1, OLS, same covariate set in every equation)

| Quantity | Value |
|---|---|
| `te(s)` (current) | **0.1287** |
| full sum of paths from `s@estimates` | 0.5400 |
| `coef(lm(Y ~ X + C))["X"]` (reduced form) | 0.5400 |

The current value is off by a factor of 4 on a routine data-generating process.

### What is correct today

- `nde()` = `c'`: correct as the direct effect (X→Y holding all mediators).
- `nie()` = `a * prod(d) * b`: correct as the **chain-specific** indirect effect
  (X→M1→…→Mk→Y). It is not the *total* indirect effect. That is a naming and
  documentation issue, not a numerical bug.
- `te()`, `pm()`: wrong as "total effect" / "proportion mediated".

## 2. Downstream audit (read-only, 2026-09-24)

| Package | Relationship | Uses serial `te()`/`pm()`? | Uses serial slots |
|---|---|---|---|
| probmed | `Imports: medfit (>= 0.3.0)` | **No.** It imports only `extract_mediation`; no `te(`/`pm(` in `R/`, `tests/`, `vignettes/` | none |
| RMediation | `Suggests: medfit (>= 0.2.0)` | **No** | `@a_path`, `@d_path`, `@b_path` only (`ci_serial_mediation_data`, chain-indirect CI) |

**No downstream package breaks under any option.** RMediation's serial CI
targets the chain-specific product, which stays unchanged.

Internal consumers that would change: `.tidy_serial_mediation_data()` and
`.glance_serial_mediation_data()` (`R/methods-tidy.R`),
`.quick_serial_mediation_data()` (`R/med.R`), and the chain-only assertions at
`tests/testthat/test-generics-effects.R:218,222`.

## 3. Where the skip-path coefficients live

| Source | Skip coefficients available? | How |
|---|---|---|
| `extract_mediation.lm/glm` (serial) | **Yes, already stored** | `@estimates` carries every coefficient with model prefixes: `m{j}_<X>` (a_j), `m{j}_<M_i>` (i < j−1), `y_<M_i>` (i < k). `@vcov` is block-diagonal over all of them. A term absent from a model is a structural zero. |
| `extract_mediation.lavaan` (serial) | **Recoverable at extraction, not reliably after** | `@estimates` is lavaan's `coef()` vector, whose names become user labels when the model uses `M2 ~ a2*X`. The extractor already has `param_table` (lhs/op/rhs) and `get_path()`, so skip paths must be resolved **during extraction** and stored under canonical aliases. |
| Direct `SerialMediationData(...)` construction | **No** | Only `a/d/b/c'` are guaranteed. Treating missing coefficients as zero would silently reproduce the bug. |

## 4. Options

### (a) Keep behavior, add a warning

`te()`/`pm()` keep returning chain + c'. They warn when skip paths are
detectably nonzero (lm/glm: via prefixed estimates) or can't be ruled out.

- ✅ No numbers change; no NEWS "behavior change".
- ❌ The function called `te()` keeps returning something that isn't the total effect.
  A warning on essentially every real serial fit becomes noise and gets
  suppressed. `nie + nde = te` holds only because both sides are wrong in the same way.
- Effort: ~1 hr.

### (b) Compute the full total effect

`te()` = `c' + Σ(all specific indirect effects)`, evaluated from stored
coefficients as the (X, Y) element of `(I − B)⁻¹`, where B is the recursive path
matrix over (X, M1, …, Mk, Y). This works for any k and any missing edges.

- Extraction: lm/glm adds canonical aliases from the prefixed coefficients it
  already stores (implemented, so vcov rows exist for the SE gradient). lavaan
  resolves `X→Mj`, `Mi→Mj` (non-adjacent), and `Mi→Y` (i < k) through
  `get_path()` and adds them as canonical aliases to `@estimates`/`@vcov` (same
  `.expand_vcov_with_aliases()` mechanism as a/d/b/c').
  **Canonical alias names are an open sub-decision (D3).**
- Directly constructed objects with no skip information: `te()`/`pm()` return
  `NA_real_` with a warning ("skip-path coefficients unavailable"). Assuming zero
  is not allowed.
- `nie()`: stays **chain-specific** (RMediation's CI targets it; the value is
  unchanged). A new `nie(x, type = c("chain", "total"))` argument (**D1**) or a
  separate helper exposes total indirect = `te − c'`.
- `pm()`: **total indirect / total effect** (**D2**). Under the alternative,
  "chain share of total", it would change name semantics silently.
- `tidy()`/`glance()`/`coef(type="effects")` for serial: keep `nie` (chain) and
  **add** `nie_total` / `indirect_total` (additive, no rename), so
  `nie_total + nde = te`. `quick()` is unchanged apart from `pm()`.
- Nonlinear glm (non-identity link): the sum of products is not a total effect on
  a natural scale. **The simple `MediationData` `te()` already computes
  `a*b + c'` link-naively**, so (b) inherits the same convention for
  consistency. Documented, no new guard (a guard would be a separate cross-class
  decision).
- Release: 0.3.2 is on CRAN, and this changes returned numbers → a **correctness
  fix** with a prominent NEWS entry. It is not a breaking API change (signatures stay the same),
  so the 2-month `[BREAKING]` process doesn't apply. No downstream caller exists.
- Effort: ~4–6 hr (lavaan aliasing, the `(I−B)⁻¹` helper, tidy/glance/quick,
  tests, docs).

### (c) Deprecate `te()`/`pm()` for serial via lifecycle

`te()`/`pm()` on serial objects emit `lifecycle::deprecate_warn()` and later
`deprecate_stop()`.

- ✅ Removes the wrong answer without committing to a replacement.
- ❌ Adds `lifecycle` to Imports (not there today). Triggers the full CLAUDE.md
  breaking-change process (a `[BREAKING]` issue, a 2-month window). Leaves serial
  users with **no** total effect, even though the correct one is computable from
  data medfit already stores. The generics are also well-defined for serial; the
  implementation is what's wrong.
- Effort: ~2 hr plus the deprecation window.

## 5. Recommendation

**(b)**, with the fallbacks above: return NA plus a warning when skip paths are
unknown, keep `nie()` chain-specific by default, and define `pm()` = total
indirect / total.

Reasons:

1. It is a correctness bug. The coefficients needed for the right answer are already in
   `@estimates` for lm/glm and one `get_path()` call away for lavaan.
2. Zero downstream callers, so fixing the numbers costs nothing in the ecosystem.
   (c)'s deprecation machinery protects no one.
3. (a) keeps shipping a known-wrong "total effect" behind a warning.

## 6. Open sub-decisions (only if (b))

| ID | Question | Default proposed |
|---|---|---|
| D1 | Total indirect via `nie(x, type = "total")` or a new exported helper? | `type` argument, default `"chain"` (no value change for existing callers) |
| D2 | `pm()` = total-indirect/total, or chain/total? | total-indirect / total |
| D3 | Canonical alias names for skip paths in `@estimates` | **Done:** `a{j}` for X→Mj (j ≥ 2), `b{i}` for Mi→Y (i < k), `d{i}_{j}` for non-adjacent Mi→Mj; `a`, `d{i}`, `b`, `c_prime` unchanged |
| D4 | Effect SEs for full `te` (delta method over all paths)? | **In scope (revised):** dev already has delta-method serial SEs (`R/effect-se.R`), so the `te` gradient was rewritten as `inv[Y,t] * inv[f,X]`, verified against lavaan `:=` SEs |
| D5 | Sequence with `feature/docs-methods-math` | Land docs first as-is. This PR then rewrites the "chain-only" wording to "full total effect" |

## 7. Verification plan (b)

- **Known answer that can fail:** OLS, same covariates in every equation, k = 2 and
  k = 3 → `te(s) == coef(lm(Y ~ X + C))["X"]` to 1e-10. Fails on current code
  (0.129 vs 0.540 above).
- **Structural zeros:** a model omitting `X` from `M2` and `M1` from `Y` →
  `te` reduces to the chain + c'. This is the only case where the old and new values agree.
- **lavaan parity:** the same data fit in lavaan with **labeled** skip paths
  (`M2 ~ a2*X + d*M1`) → `te` matches the lm result (labels must not break lookup).
- **Fallback:** a hand-built `SerialMediationData` with no skip info → `NA` + warning.
- **Additivity:** `nie(type="total") + nde == te`; tidy/glance rows sum.
- Update `test-generics-effects.R:218,222` (the current assertions encode the bug).
- Full `devtools::test()` + `R CMD check --as-cran` + strict flavors before the PR.
