# SPEC: frozen grammar and parameter table for the native SEM engine ("medfit model syntax")

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Status** | DRAFT. Written by the medfit session (K1). Section 9 items 1-3 were accepted as proposed on 2026-10-08 ("do recommended"); the author's final approval of the whole spec is still pending. |
| **Task** | P0 grammar spec; precedes P1 (parser) and P2 (converters). |
| **Inherits** | Handoff J13-J17 (missingmed `docs/specs/HANDOFF-medfit-native-sem-engine-2026-10-08.md`) and this repo's ledger [GRILL-native-sem-engine-medfit-2026-10-08.md](GRILL-native-sem-engine-medfit-2026-10-08.md): K1 (spec lives here), K2/K2b (any math expression, allowlist-checked), K4 (name), K5c (raw data only). |
| **Evidence labels** | **[V]** verified by a command in this session; **[A]** assumed or proposed, needs the author's confirmation. |

## 1. Scope

This spec freezes **what the parser accepts and what table it returns**. It does not cover model completion (marker loadings, default variances), estimation, or the mediation checks (treatment, mediator and outcome present); those belong to P2, N1 and N4.

**Name (K4):** user docs call this **medfit model syntax**: a lavaan-style core plus extensions. Every extension is tagged "medfit extension" wherever it is documented. Docs and errors never say "lavaan syntax".

## 2. Oracle facts that shape the grammar [V]

Probe: `lavaan::lavParseModelString(model, as.data.frame. = TRUE)`, run on **lavaan 0.7-2 and 0.7-3 with identical results** for every row below (0.7-3 added the `:~` operator, which the probe does not use).

| Fact | Consequence for this spec |
|---|---|
| Output is a flat table `lhs, op, rhs, block, fixed, label, start, lower, upper, mod.idx`, plus `modifiers` and `constraints` attributes. `:=` and `==` live in `constraints`, not in rows. | Our table keeps constraints in a **separate** data frame (section 5). |
| `a < 2` and `cp > 0`, where the left side is a label and the right side a number, are **folded into `upper` / `lower` on the labeled row**. They are not in `constraints`. | Same rule in section 4.4; the oracle comparison must apply it to both sides. |
| `block` is 1 even without `level:`. With `level: 1` / `level: 2`, each statement gets block 1 or 2, and the `level:` lines themselves appear as rows with `op = ":"`. | Our table has a `level` column (J16); `level:` lines are consumed, not rows. |
| `y1, y2 ~ x` returns **one row, `y2 ~ x`; `y1` is silently dropped** with no error. | Comma shorthand cannot be checked against lavaan. It is an extension (section 6) with its own tests, and the docs must warn that lavaan misreads it. |
| `0*1` gives `m1 ~1` with `fixed = 0`: the intercept operator is `~1`, produced by the right side `1`. | Intercepts are in the grammar (section 4.1) so means round-trip, though v0 fits no mean structure (section 7). |

## 3. Lexical rules

1. Statements end at a newline or `;`. A statement continues onto the next line while its right side ends with `+`, `,`, `*`, or an open parenthesis.
2. Comments start with `#` or `!` and run to the end of the line.
3. Names: start with a letter or `.`, then letters, digits, `.`, `_`. Quoted names (backticks) are **not** supported in v0 (error naming the feature).
4. Numbers: decimal, optional sign and exponent. `NA` is allowed in `start()` only.
5. Whitespace is insignificant except inside names.

## 4. Core grammar (lavaan-compatible; checked against `lavParseModelString()`)

### 4.1 Statements

```
statement   := level_line | relation | defined | constraint
level_line  := "level:" integer
relation    := lhs op term ( "+" term )*
op          := "=~" | "~" | "~~" | "~1"        # "~1" is written  y ~ 1  with the 1 as the right side
term        := [ modifier "*" ] name
modifier    := number | label | "start(" number ")" | "lower(" number ")" | "upper(" number ")"
defined     := name ":=" expr                  # defined parameter
constraint  := expr ( "==" | "<" | ">" ) expr
label       := name                            # first lowercase use of a name followed by "*"
```

- `=~` defines a latent variable: `M =~ m1 + m2 + m3`.
- `~` is a regression; `~~` is a (co)variance; `y ~ 1` is an intercept.
- A modifier applies to the single term it precedes. A numeric modifier fixes the parameter. Several modifiers on one term, such as `start(.5)*lower(0)*x`, are not supported in v0 and error; use one modifier per term.
- A label shared by several rows constrains those parameters to be equal (lavaan behavior; tested on the oracle).

### 4.2 Constraints and defined parameters

`:=`, `==`, `<`, `>` take an `expr` over labels and numbers. Evaluation and safety are fixed by K2/K2b:

- Any expression built from the **math allowlist**: `+ - * / ^ ( )`, `exp log log10 sqrt abs min max sin cos tan pnorm qnorm`, numeric literals, and labels. The allowlist is checked with `all.names()` before any `eval`, and the first disallowed name is reported in the error. Anything else (`ifelse`, `system`, user functions, `[`, `$`) is rejected.
- Jacobians are central differences with relative step `eps^(1/3) * max(abs(x), 1)` (K3).
- `:=` right sides may reference labels and earlier `:=` names. Cycles error.

### 4.3 `level:` blocks (J16)

`level: k` sets the `level` column for the statements below it, until the next `level:` line. The parser accepts them. **Fitting a model with more than one level errors** with a message naming "two-level estimation is not implemented" (exact text pinned in tests).

### 4.4 Bound folding

A constraint of the form `label < number`, `label > number` (or the mirrored `number > label`) where `label` is a single parameter label becomes `upper` / `lower` on every row with that label, exactly as lavaan does [V]. Any other `<` or `>` (several labels, a function, a defined parameter) stays in the constraint table as a general inequality.

## 5. The parameter table (J14)

Two data frames, both plain `data.frame`s with documented column types.

**`parameters`** (one row per parameter specification):

| Column | Type | Meaning |
|---|---|---|
| `id` | integer | row number, 1-based |
| `lhs`, `op`, `rhs` | character | `op` in `=~`, `~`, `~~`, `~1`; for `~1` the `rhs` is `""` (our choice; lavaan stores `""` as well [V]) |
| `level` | integer | 1 unless set by `level:` (J16) |
| `fixed` | numeric | fixed value, or `NA` if free |
| `label` | character | `""` if none |
| `start`, `lower`, `upper` | numeric | `NA` if not given |

**`constraints`** (one row per `:=`, `==`, `<`, `>` that is not folded into a bound):

| Column | Type | Meaning |
|---|---|---|
| `op` | character | `:=`, `==`, `<`, `>` |
| `lhs`, `rhs` | character | expression text, allowlist-checked |
| `level` | integer | level of the line, 1 by default |

Converters (P2, not specified here): table to lavaan `ParTable` and to RAM matrices; round-trip against `lavaanify()` is their test.

## 6. Extensions (medfit extension; no lavaan oracle)

The handoff lists two dialect features without defining them. The definitions below were proposed by the medfit session and accepted by the author on 2026-10-08 (section 9, item 1).

| Extension | Proposed meaning | Why lavaan cannot check it |
|---|---|---|
| **Comma shorthand** | A comma-separated left side expands to one statement per name: `y1, y2 ~ x` means `y1 ~ x` and `y2 ~ x`. Commas on the right side are **not** supported; use `+`. | lavaan silently keeps only `y2` [V]; the docs and a planted-defect test must make this visible. |
| **CONSTRAINT-style expressions** | Constraint lines may also be written as a directive, `CONSTRAINT(expr op expr)`, equivalent to the bare `expr op expr`; `op` in `==`, `<`, `>`. | Not lavaan syntax (semopy-style directive, per the syntax ledger). |

Both extensions are tested separately (section 8) and documented under a "medfit extensions" heading.

## 7. Errors and unsupported syntax

Unsupported operators error **by name**, never silently: `<~`, `~*~`, `|~`, `:~`, `|` (thresholds), `%`, and group or class blocks (`group:`, `class:`, `block:`). Mean structure (`~1` rows) parses but v0 estimation errors if any intercept is free, naming the feature. Undefined labels in constraints, duplicate `:=` names, label-versus-variable name clashes, and a malformed modifier each have a pinned error message with a regex in the tests.

## 8. Test plan

| Layer | Oracle | Cases |
|---|---|---|
| Core grammar (section 4) | `lavParseModelString()` on lavaan >= 0.7-3; compare `lhs, op, rhs, level (= block), fixed, label, start, lower, upper` and the constraint set after applying bound folding to both sides | the models in section 2, a simple mediation, serial and parallel mediation, latent mediator, equal-label constraints, `:=` indirect effects, two-level syntax |
| Extensions (section 6) | own expected tables | comma expansion; `CONSTRAINT(...)` equivalence; **planted defect:** the oracle drops `y1` and our parser must not |
| Safety (K2b) | allowlist | planted `system("...")`, `file.remove`, `ifelse`, `[` in a constraint: all rejected, first disallowed name reported |
| Errors (section 7) | pinned regexes | every row of section 7 |
| Level (section 4.3) | own | parses; fitting errors with the pinned message |

Positive controls follow the repo rule: a defect planted in the parser (for example dropping the bound-folding step) must turn a test red.

## 9. Decisions on the draft's open items (2026-10-08)

1. **Extension definitions (section 6): accepted as proposed.**
2. **One modifier per term in v0: accepted** (lavaan allows several; revisit if a user needs them).
3. **Math allowlist (section 4.2): accepted as proposed**, including `pnorm`, `qnorm` and trig.
4. **Probe re-run on lavaan >= 0.7-3: done**, identical to 0.7-2 (section 2).

The author said "do recommended" for these; none was answered item by item, so each acceptance is the recommended option, not a separate ruling. Anything still to confirm is the whole-spec approval in the status line.
