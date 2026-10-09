# SPEC: frozen grammar and parameter table for the native SEM engine ("medfit model syntax")

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Status** | DRAFT. Written by the medfit session (K1). Section 9 items 1-3 were accepted as proposed on 2026-10-08 ("do recommended"); the author's final approval of the whole spec is still pending. Revised after the adversarial review: T1 (evaluator boundary, 4.2a) and T2 (full productions, 4.1 and 4.2b) done; T3 (nonlinear-constraint contract, 4.5a-f, K9) done. |
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

Every nonterminal is defined here. `{ x }` means zero or more, `[ x ]` optional, quoted strings are literal tokens.

```
statement   := level_line | intercept | relation | defined | constraint | directive
level_line  := "level:" integer
relation    := lhs rel_op term { "+" term }
rel_op      := "=~" | "~" | "~~"
intercept   := lhs "~" [ modifier "*" ] "1"     # stored as op "~1" with rhs ""
term        := [ modifier "*" ] name
lhs         := name                              # core
             | name { "," name }                 # medfit extension (section 6): comma shorthand
modifier    := number | label | "start(" number ")" | "lower(" number ")" | "upper(" number ")"
defined     := name ":=" expr
constraint  := expr cmp expr
cmp         := "==" | "<" | ">"                  # exactly one, at parenthesis depth 0
directive   := "CONSTRAINT(" expr cmp expr ")"   # medfit extension (section 6)
expr        := see 4.2b                          # arithmetic subset of R
label       := name                              # must not be a reserved word (below)
name        := letter_or_dot { letter | digit | "." | "_" }
number      := [ "-" | "+" ] digits [ "." digits ] [ ( "e" | "E" ) [ "-" | "+" ] digits ]
integer     := digits
```

**Reserved words.** A `label` may not equal an allowlisted function name (4.2a) or one of `start`, `lower`, `upper`, `level`, `CONSTRAINT`; the parser errors naming the clash. `~1` is not a token: an intercept is `lhs ~ [modifier *] 1`, matching how lavaan parses `m1 ~ 0*1` [V].

- `=~` defines a latent variable: `M =~ m1 + m2 + m3`.
- `~` is a regression; `~~` is a (co)variance; `y ~ 1` is an intercept.
- A modifier applies to the single term it precedes. A numeric modifier fixes the parameter. Several modifiers on one term, such as `start(.5)*lower(0)*x`, are not supported in v0 and error; use one modifier per term.
- A label shared by several rows constrains those parameters to be equal (lavaan behavior; tested on the oracle).

### 4.2 Constraints and defined parameters

`:=`, `==`, `<`, `>` take an `expr` over labels and numbers. Evaluation and safety are fixed by K2/K2b, tightened after the adversarial review (finding F1: checking names alone does not stop code execution, because a caller can rebind an allowlisted name such as `exp`).

#### 4.2a Evaluation environment (normative)

1. **Parse.** `parse(text = , keep.source = FALSE)` must yield exactly one expression; zero, several (`a; system("x")`), or a syntax error is rejected.
2. **Validate the call tree before any evaluation.** Allowed nodes only: a finite numeric literal; a symbol that is a declared label; a call whose head is a **bare symbol** in the allowlist below, with no named arguments and an argument count inside its arity. Everything else is rejected and the first offending construct is named: strings, `TRUE`/`NA`, `::`, `:::`, `$`, `@`, `[`, `[[`, `<-`, `=`, `function`, `if`, formulas, backtick names, calls whose head is not a bare symbol (`base::system(...)`, `get("system")(...)`, `(function() 1)()`), and a symbol that is an allowlisted function name used as a label.
3. **Evaluate in a locked environment.** `env <- new.env(parent = emptyenv())`; bind each allowlisted function **explicitly to its `base`/`stats` object** (`exp = base::exp`, `pnorm = stats::pnorm`, ...); bind each label to a numeric value; `eval(expr, env)`. Never evaluate in, or inherit from, the caller, global, or package environment.

| Function | Arity |
|---|---|
| `+` `-` | 1 or 2 |
| `*` `/` `^` | 2 |
| `(` | 1 |
| `exp` `log10` `sqrt` `abs` `sin` `cos` `tan` `pnorm` `qnorm` | 1 |
| `log` | 1 or 2 |
| `min` `max` | at least 1 |

`pnorm` and `qnorm` take their first argument only, so `lower.tail` and `log.p` (which would need named or logical arguments) are not available.

**Verified [V]** with a scratchpad prototype (script: `planning/specs/evidence/native-sem-2026-10-08/06-evaluator-prototype.R`, output in `results/`): a caller-side `exp <- function(x) { flag <<- TRUE; base::exp(x) }` passes an `all.names()`-only check and runs when evaluated in the caller's scope (`flag` becomes `TRUE`); the locked evaluator returns the correct value (`exp(1) + 2 = 4.718282`) and `flag` stays `FALSE`. All 22 evaluator-level inputs in the section 7 rejection table (every row except the `<=`/`>=`/`!=`, `CONSTRAINT(...)` and right-side-comma rows, which belong to the statement parser and were not prototyped) were rejected with the construct named; nine valid expressions (`-2^2`, `2^-1`, `a*b`, `exp(a)/sqrt(b+1)`, `min(a, b, 3)`, `log(a, 2)`, `pnorm(a) - 0.5`, `1e-3*a`, `a^2 + b^2`) evaluated to R's own values.

#### 4.2b Expression grammar

`expr` is the arithmetic subset of R with **R's own precedence and associativity**; the oracle for it is `parse(text = )` restricted to the node types in 4.2a, so two implementations cannot disagree:

```
expr    := sum
sum     := product { ( "+" | "-" ) product }
product := unary { ( "*" | "/" ) unary }
unary   := ( "-" | "+" ) unary | power
power   := atom [ "^" unary ]                  # right-associative; binds tighter than unary minus on its left
atom    := number | label | call | "(" expr ")"
call    := fname "(" [ expr { "," expr } ] ")"
```

Consequences pinned by tests: `-2^2` is `-4`; `2^3^2` is `512`; `2^-1` is `0.5`. Comparison operators never occur inside an `expr`: a constraint line is split at its single depth-0 `==`, `<`, or `>`, and `<=`, `>=`, `!=` are rejected by name (lavaan's `<` already means "at most").

#### 4.2c Other rules

- Jacobians are central differences with relative step `eps^(1/3) * max(abs(x), 1)` (K3).
- `:=` right sides may reference labels and earlier `:=` names. Cycles error.
- **Nonlinear constraint classes and diagnostics** are specified in 4.5a-f (K9).

### 4.3 `level:` blocks (J16)

`level: k` sets the `level` column for the statements below it, until the next `level:` line. The parser accepts them. **Fitting a model with more than one level errors** with a message naming "two-level estimation is not implemented" (exact text pinned in tests).

### 4.4 Bound folding

A constraint of the form `label < number`, `label > number` (or the mirrored `number > label`) where `label` is a single parameter label becomes `upper` / `lower` on every row with that label, exactly as lavaan does [V]. Any other `<` or `>` (several labels, a function, a defined parameter) stays in the constraint table as a general inequality.

### 4.5 Nonlinear constraints (K9, adversarial-review finding F3)

Decided 2026-10-08 (D-A, recommended option): nonlinear equalities and inequalities are **allowed, with a one-time warning**, solved from several starts, and checked for feasibility and agreement across starts. This section is the full contract.

#### 4.5a Classification (at model-build time, once per constraint)

A constraint `lhs cmp rhs` is reduced to `h(x) = lhs - rhs`. It is **linear** if the central-difference Jacobian (K3 step) of `h` at three fixed pseudo-random points (seeded, drawn uniformly from [-2, 2] per parameter) agrees across the points to within `1e-6 * max(1, max|J|)`; otherwise **nonlinear**.

**Verified [V]** on seven expressions with 5 parameters: `a+b-0.5`, `a-2*b` and `a*0+b` classify linear; `a*b`, `exp(a)-1`, `a^2` and `abs(a)-b` classify nonlinear. Known limit: a function that is nonlinear only in a region the three points miss (for example a kink outside [-2, 2]) is classified linear; the feasibility gate (4.5c) still applies to it.

#### 4.5b Solve policy

| Class | Starts | Warning |
|---|---|---|
| Linear equalities and inequalities | one solve from the user's start | none |
| Any nonlinear constraint | `n_starts = 5`: the user's start plus four perturbations `x0 + N(0, (0.5 * max(|x0|, 1))^2)` per coordinate, drawn with a seed derived from the model so reruns are identical | once per fit: "constraint `<text>` is nonlinear; the solution may depend on starting values" |

`engine_args` may set `n_starts` (integer, at least 1). Among starts that satisfy 4.5c, the lowest objective wins.

#### 4.5c Feasibility gate

A start is **feasible** only if every equality has `abs(h(x)) <= 1e-6` and every inequality is satisfied to `1e-6` at its solution. If no start is feasible the fit reports non-convergence, naming the first violated constraint and its residual. (Verified [V]: the contradictory pair `a == 1`, `a == 2` returned nloptr status -4 with max residual 1.70 and is rejected by this gate.)

#### 4.5d Agreement diagnostics (attached to the fit)

| Field | Content |
|---|---|
| `n_starts`, `n_feasible` | starts run and starts passing 4.5c |
| `winner` | index of the winning start (1 is the user's) |
| `objective_spread` | max minus min objective among feasible starts |

If `objective_spread` exceeds `1e-6` (relative to the winning objective, with an absolute floor of `1e-6`), the fit warns once: "starts reached different solutions (spread `<value>`); the reported fit is the best of `<n_feasible>`". The spread is the only signal for a start that stalls **at a feasible point**: [V] the start (0, 0, 0, .5, .5) on `a*b == 0` returned F = 1.029 with residual 0.0 (feasible) against the best F = 0.0952, so the feasibility gate alone cannot catch it.

#### 4.5e What the multi-start does and does not guarantee

Measured [V] on `a*b == 0` (n = 300, observed three-variable model, 60 random user starts): the better solution (`a` = 0, F = 0.095154) was reached from **34 of 60** with one start and **56 of 60** with five starts. Five starts raise the odds; they do **not** guarantee the global solution (4 of 60 still missed). `a*b == 0` has two legitimate local solutions (`a` = 0 and `b` = 0, F = 0.0952 and 0.1061), so it will always raise the spread warning; the message adds: "for `a*b == 0` solve `a == 0` and `b == 0` separately and keep the better (medfit MBCO, N7)".

#### 4.5f Tests (planted defects, each must turn red when its mechanism is removed)

1. Linearity: the seven-expression table above gives the stated classes; planting a sign error in the Jacobian difference flips at least one.
2. Stalled start: `a*b == 0` from (0, 0, 0, .5, .5) with `n_starts = 1` returns F near 1.03 and raises **no** spread warning (a single start has nothing to compare; the test documents why `n_starts = 1` is unsafe for nonlinear constraints, and the one-time nonlinearity warning is the only signal); with `n_starts = 5` and the model-derived seed it returns F within `1e-6` of 0.095154 (verified [V] with seed 1, where start 3 won) and the spread warning fires.
3. Agreement warning: fires on `a*b == 0` and does not fire on the linear `a + b == 0.5` (all starts agree).
4. Feasibility: `a == 1` with `a == 2` errors naming a constraint and the residual.
5. No-warning path: a linear constraint produces no warning and runs one solve.
6. Reproducibility: two runs of the same model give identical start perturbations and the same winner.

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
| **CONSTRAINT-style expressions** | Constraint lines may also be written as the directive `CONSTRAINT(expr cmp expr)` (production in 4.1), equivalent to the bare `expr cmp expr`. Rules: the keyword is case-sensitive and starts the statement; exactly one balanced parenthesis pair encloses the whole constraint; exactly one `cmp` at depth 0 inside it; no nested `CONSTRAINT`; no text after the closing parenthesis. Both sides are `expr` (4.2b) and go through the same evaluator (4.2a). | Not lavaan syntax (semopy-style directive, per the syntax ledger). |

Both extensions are tested separately (section 8) and documented under a "medfit extensions" heading.

## 7. Errors and unsupported syntax

Unsupported operators error **by name**, never silently: `<~`, `~*~`, `|~`, `:~`, `|` (thresholds), `%`, and group or class blocks (`group:`, `class:`, `block:`). Mean structure (`~1` rows) parses but v0 estimation errors if any intercept is free, naming the feature. Undefined labels in constraints, duplicate `:=` names, label-versus-variable name clashes, and a malformed modifier each have a pinned error message with a regex in the tests.

**Rejection cases** (each is a test; the error names the first offending construct, wording pinned by regex):

| Input | Rejected because |
|---|---|
| `a; system("x")` | not a single expression |
| `1 +` | does not parse |
| `base::system("x")`, `get("system")("x")`, `(function() 1)()` | call head is not a bare allowlisted symbol |
| `do.call(...)`, `Recall(a)`, `ifelse(...)`, `if (a) 1 else 2` | function not in the allowlist |
| `a[1]`, `a$b`, `a <- 3`, `a = 3`, `~a` | operator not in the allowlist |
| `"abc"`, `TRUE`, `NA` | disallowed literal |
| `exp(a, b)`, `log(x = a)` | wrong arity; named argument |
| `exp` (used as a label), `` `a b` ``, `unknown * a` | reserved word as label; unknown label |
| `a <= 2`, `a >= 2`, `a != 2` | comparison operator not supported |
| `CONSTRAINT(a == 1) + 2`, `CONSTRAINT(CONSTRAINT(a == 1))`, `CONSTRAINT(a == 1, b == 2)` | trailing text; nesting; more than one `cmp` or a comma at depth 0 |
| `y1 ~ x, y2` | comma on the right side |

## 8. Test plan

| Layer | Oracle | Cases |
|---|---|---|
| Core grammar (section 4) | `lavParseModelString()` on lavaan >= 0.7-3; compare `lhs, op, rhs, level (= block), fixed, label, start, lower, upper` and the constraint set after applying bound folding to both sides | the models in section 2, a simple mediation, serial and parallel mediation, latent mediator, equal-label constraints, `:=` indirect effects, two-level syntax |
| Extensions (section 6) | own expected tables | comma expansion; `CONSTRAINT(...)` equivalence; **planted defect:** the oracle drops `y1` and our parser must not |
| Safety (4.2a) | locked evaluator | every row of the section 7 rejection table; **planted defect (positive control):** a caller-side rebinding of `exp` must change the result of an `all.names()`-only implementation and must **not** change the locked evaluator's result or run the caller's function |
| Expression grammar (4.2b) | `parse(text = )` restricted to the 4.2a node types | `-2^2`, `2^3^2`, `2^-1`, `a*b`, `exp(a)/sqrt(b+1)`, `min(a, b, 3)`, `log(a, 2)`, `pnorm(a) - 0.5`, `1e-3*a`: values equal R's own evaluation of the same text |
| Errors (section 7) | pinned regexes | every row of section 7 |
| Level (section 4.3) | own | parses; fitting errors with the pinned message |

Positive controls follow the repo rule: a defect planted in the parser (for example dropping the bound-folding step) must turn a test red.

## 9. Decisions on the draft's open items (2026-10-08)

1. **Extension definitions (section 6): accepted as proposed.**
2. **One modifier per term in v0: accepted** (lavaan allows several; revisit if a user needs them).
3. **Math allowlist (section 4.2): accepted as proposed**, including `pnorm`, `qnorm` and trig.
4. **Probe re-run on lavaan >= 0.7-3: done**, identical to 0.7-2 (section 2).

The author said "do recommended" for these; none was answered item by item, so each acceptance is the recommended option, not a separate ruling. Anything still to confirm is the whole-spec approval in the status line.
