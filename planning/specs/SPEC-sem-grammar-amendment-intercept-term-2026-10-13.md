# SPEC AMENDMENT (APPROVED): intercept as a term in a regression, `y ~ 1 + x`

| | |
|---|---|
| **Date** | 2026-10-13 |
| **Status** | **APPROVED 2026-10-13** by the author, in chat ("approved"), as a whole with the recommended defaults: D1 `y ~ 1 + 1 + x` is an error, D2 either position of the `1` is accepted. Not reviewed by an adversarial pass (small, ten-line parser change); 0.9.0 T2 may implement it. |
| **Amends** | `SPEC-sem-grammar-2026-10-08.md` section 4.1 (`intercept`, `relation`), the lexical rule on a number on the right side, and the error text at `R/sem-parse.R:173-177` |
| **Origin** | [GRILL-native-mean-structure-2026-10-12.md](GRILL-native-mean-structure-2026-10-12.md) G11; Opus review M-A of [PLAN-native-mean-structure-2026-10-12.md](PLAN-native-mean-structure-2026-10-12.md) |
| **Evidence labels** | **[V]** verified by a command this session; **[A]** proposed, needs the author's decision |

## 1. Why

The 0.8.0 parser rejects `outcome ~ 1 + treatment` with "an intercept must be its own statement (e.g. 'y ~ 1')". lavaan writes the intercept inside the regression, so (a) lavaan model strings do not paste into `fit_sem()` once 0.9.0 supports intercepts, and (b) the lavaan-comparison article's intercept probe (`tests/testthat/test-lavaan-comparison.R:44`) cannot flip to Supported.

## 2. Oracle facts [V]

`lavaan::lavParseModelString()` on lavaan 0.7.2:

| Input | Rows |
|---|---|
| `y ~ 1 + x` | `y ~1 ""`, `y ~ x` |
| `y ~ x + 1` | `y ~ x`, `y ~1 ""` (position does not matter) |
| `y ~ 0*1 + x` | `y ~1` with `fixed = 0`, `y ~ x` |
| `y ~ a*1 + x + b*z` | `y ~1` with `label = a`, `y ~ x`, `y ~ z` with `label = b` (a modifier belongs to its own term) |
| `y1 + y2 ~ 1 + x` | the intercept and the regression for each left side |
| `y ~ 1 + 0*x` | `y ~1` free, `y ~ x` fixed at 0 |
| `y ~ 1 + 1 + x` | one `y ~1` row (lavaan collapses the repeated `1` silently) |
| `y ~~ 1 + x`, `f =~ 1 + a` | `~~` errors; `=~` reads `1` as a fixed loading of `f` on itself (a different thing) |

## 3. Proposal

A `~` statement's right side may contain the literal `1` as one term, in any position, with the same optional `modifier*` as any term. The statement is the same as two statements: `y ~ 1 + x` equals `y ~ 1` followed by `y ~ x`. Nothing downstream changes: the parser emits the same rows (op `~1`, rhs `""`) it emits for a stand-alone `y ~ 1`.

Grammar (replaces the `intercept`/`relation` split for `~` only):

```
relation  := lhs_list "~" term { "+" term }
term      := [ modifier "*" ] ( name | "1" )      # "1" only on the right of "~"
intercept := lhs "~" [ modifier "*" ] "1"         # unchanged: the one-term case
```

Rules:

1. `1` is valid only as a term of `~`. On `~~`, `=~` and in a product the existing errors stay; the message for a number other than `1` is unchanged ("a number on the right side is only valid as the intercept '~ 1'").
2. A modifier before `1` applies to the intercept row alone; a modifier before another term applies to that term.
3. Several left sides (`y1 + y2 ~ 1 + x`) give one intercept row per left side, like the other terms.
4. A second `1` for the same left side, in this statement or another, is an error (the existing "a second row would compete" rule at `R/sem-parse.R:403`), not lavaan's silent collapse [A, decision D1].
5. The right side `1` alone is the existing case and parses as before.

## 4. Decisions needed from the author

- **D1 (decided: error, 2026-10-13).** `y ~ 1 + 1 + x`: error, or collapse silently as lavaan does? An error is consistent with the engine's rule that a repeated parameter row is a mistake (`y ~ x` twice errors today), and the repeated `1` can only be a typo.
- **D2 (decided: accept, 2026-10-13).** Accept the intercept-first and intercept-last orders alike (lavaan does). Restricting to one position adds a rule with no benefit.

## 5. Impact

- `R/sem-parse.R`: remove the "must be its own statement" error; split the `1` term into an intercept row. About ten lines.
- Frozen spec sections 4.1 and the lexical rule: edit the intercept production and the one error message.
- `R/sem-syntax-help.R`: one line and one example.
- Not affected: RAM, likelihood, mean structure (0.9.0 T2 onward consumes the same `~1` rows).
- Behavior change: none for models that parse today, since the combined form errors in 0.8.0.

## 6. Test plan

- Parser: each row of the table in section 2 gives the stated rows; `~~` and `=~` with `1` keep their errors; `y ~ 1 + 1 + x` errors (D1); `y ~ 1` and `y ~ 1 + x` plus a separate `y ~ 1` error as a duplicate.
- Equivalence: `fit_sem("y ~ 1 + x")` and `fit_sem("y ~ 1\ny ~ x")` give identical parameter tables (0.9.0, once mean structure lands).
- Planted defect: a parser that drops the intercept term while keeping the regression row must fail the equivalence test.
- The lavaan-comparison probe `fit_sem("outcome ~ 1 + treatment", d)` flips the row to Supported.

## 7. Out of scope

`1` on the right of `~~` or `=~`, `y ~ 0 + x` (lavaan parses it to an `y ~1` row too [V]; the native parser keeps rejecting a bare `0` term, so the error message for a number other than `1` is unchanged), and `+` inside modifiers.
