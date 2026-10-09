# SPEC: frozen grammar and parameter table for the native SEM engine ("medfit model syntax")

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Status** | DRAFT. Written by the medfit session (K1). Section 9 items 1-3 were accepted as proposed on 2026-10-08 ("do recommended"); the author's final approval of the whole spec is still pending. Revised after the adversarial review: T1 (evaluator boundary, 4.2a) and T2 (full productions, 4.1 and 4.2b) done; T3 (nonlinear-constraint contract, 4.5a-f, K9) done. Review round 5 (1 medium: inequality KKT omitted multiplier signs) addressed in 4.5c and 4.5f. Review round 4 (2 mediums: optimizer termination and stationarity not required, no result-domain guard on expressions) addressed in 4.2a step 4, 4.5c, 4.5d, 4.5f. Review round 3 (1 medium: start validity must be positive definiteness, not a finite or bounded objective) addressed in 4.5b and 4.5f. Review round 2 (4 medium findings) addressed: `fname`, literal forms and hex (4.1, 4.2a), syntactic linearity (4.5a), valid starts and the failure-or-spread warning rule (4.5b, 4.5d), runner failure propagation (evidence `run-all.sh`). |
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
4. Numbers: decimal literals as R reads them (`.5` and `1.` are valid; no `L`, hex, or `i` suffix). A sign belongs to a modifier (`snumber`) or to the unary operator in an expression, never to the literal. `NA` is allowed in `start()` only.
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
modifier    := snumber | label | "start(" snumber ")" | "lower(" snumber ")" | "upper(" snumber ")"
defined     := name ":=" expr
constraint  := expr cmp expr
cmp         := "==" | "<" | ">"                  # exactly one, at parenthesis depth 0
directive   := "CONSTRAINT(" expr cmp expr ")"   # medfit extension (section 6)
expr        := see 4.2b                          # arithmetic subset of R
label       := name                              # must not be a reserved word (below)
name        := letter_or_dot { letter | digit | "." | "_" }
number      := ( digits [ "." [ digits ] ] | "." digits ) [ ( "e" | "E" ) [ "-" | "+" ] digits ]   # unsigned; as R: .5 and 1. are valid
snumber     := [ "-" | "+" ] number                                                            # modifiers only; expressions use unary minus
fname       := "exp" | "log" | "log10" | "sqrt" | "abs" | "min" | "max" | "sin" | "cos" | "tan" | "pnorm" | "qnorm"   # the function rows of the 4.2a table
integer     := digits
digits      := digit { digit }
digit       := "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
letter      := "A" .. "Z" | "a" .. "z"
letter_or_dot := letter | "."
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
2. **Validate the call tree before any evaluation.** Allowed nodes only: a finite double literal (`5L`, `1i`, `Inf` and `1e999` are rejected, and hexadecimal literals such as `0x10` are rejected by a pre-parse check that ignores names like `a0x1`); a symbol that is a declared label; a call whose head is a **bare symbol** in the allowlist below, with no named arguments and an argument count inside its arity. Everything else is rejected and the first offending construct is named: strings, `TRUE`/`NA`, `::`, `:::`, `$`, `@`, `[`, `[[`, `<-`, `=`, `function`, `if`, formulas, backtick names, calls whose head is not a bare symbol (`base::system(...)`, `get("system")(...)`, `(function() 1)()`), and a symbol that is an allowlisted function name used as a label.
3. **Evaluate in a locked environment.** `env <- new.env(parent = emptyenv())`; bind each allowlisted function **explicitly to its `base`/`stats` object** (`exp = base::exp`, `pnorm = stats::pnorm`, ...); bind each label to a numeric value; `eval(expr, env)`. Never evaluate in, or inherit from, the caller, global, or package environment.
4. **Guard the result (review round 4).** Every evaluation, whether of a constant subexpression at build time or at an optimizer iterate, must return **exactly one finite real double**. Anything else (`Inf`, `NaN`, a length other than one, a non-double) is an error naming the expression, the value returned and the label values, and the evaluation never reaches the optimizer or the Jacobian. R's own `NaNs produced` warnings are suppressed in favor of this error. [V] (`06`): `1/0`, `0/0`, `(-1)^.5`, `log(-1)`, `sqrt(-1)`, `exp(1000)`, `qnorm(2)` and `1/(a - 1.5)` at `a = 1.5` were all rejected (8 of 8); `log(1)`, `1/a`, `sqrt(b)`, `(-8)^2` and `0*a` were accepted (5 of 5). In R these operations return `NaN` and not a complex value; complex values arise only from the `1i` literal, which is already rejected.

| Function | Arity |
|---|---|
| `+` `-` | 1 or 2 |
| `*` `/` `^` | 2 |
| `(` | 1 |
| `exp` `log10` `sqrt` `abs` `sin` `cos` `tan` `pnorm` `qnorm` | 1 |
| `log` | 1 or 2 |
| `min` `max` | at least 1 |

`pnorm` and `qnorm` take their first argument only, so `lower.tail` and `log.p` (which would need named or logical arguments) are not available.

**Verified [V]** with a scratchpad prototype (script: `planning/specs/evidence/native-sem-2026-10-08/06-evaluator-prototype.R`, output in `results/`): a caller-side `exp <- function(x) { flag <<- TRUE; base::exp(x) }` passes an `all.names()`-only check and runs when evaluated in the caller's scope (`flag` becomes `TRUE`); the locked evaluator returns the correct value (`exp(1) + 2 = 4.718282`) and `flag` stays `FALSE`. Evidence run (`06-evaluator-prototype.R`): **28 of 28** rejection inputs were rejected with the construct named (the rows of the section 7 table that the evaluator handles, plus the literal forms `5L`, `0x10`, `1i`, `1e`, `Inf`, `1e999`); **14 of 14** valid expressions, including `.5 + a`, `1. * a`, `1e3*a`, `2E-2*a`, `a^.5`, evaluated and equal R's own evaluation of the same text to 1e-14. The rows not prototyped (`<=`/`>=`/`!=`, `CONSTRAINT(...)`, right-side comma) belong to the statement parser.

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

`fname` is defined in 4.1 as the function names of the 4.2a table (operators excluded). Consequences pinned by tests: `.5` and `1.` are valid literals; `-2^2` is `-4`; `2^3^2` is `512`; `2^-1` is `0.5`. Comparison operators never occur inside an `expr`: a constraint line is split at its single depth-0 `==`, `<`, or `>`, and `<=`, `>=`, `!=` are rejected by name (lavaan's `<` already means "at most").

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

#### 4.5a Classification (syntactic, conservative; at model-build time, once per constraint)

Review round 2 replaced the three-point numeric check, which could call a constraint linear when its nonlinearity lay outside the sampled points. Classification now walks the **validated expression tree** (4.2a) after `:=` names are substituted by their definitions. An expression is **linear** only if it is provably linear by these rules; anything else is **nonlinear**:

| Node | Linear when |
|---|---|
| number, or any subtree with no label | always (a constant) |
| label | always |
| `(e)`, unary `+` or `-` | `e` is linear |
| `e1 + e2`, `e1 - e2` | both linear |
| `e1 * e2` | both linear **and at most one contains a label** |
| `e1 / e2` | `e2` has no label and `e1` is linear |
| any other call (`exp`, `abs`, `min`, `^`, ...) with a label inside | never |

The rule errs in one direction only: an expression that is linear in fact but not provably so (`a*b - a*b + a`, `a^1`) is called nonlinear, which costs a warning and five starts and **never** a missed safeguard. Nothing depends on the region sampled.

**Verified [V]** (`04b-constraint-contract.R`): all 16 test expressions classify as expected, including `(a-b)*(a+b)`, `a/b`, `min(a, b)`, `2*(a+b)/3`, `exp(1)*a` and `1e3*a - b`, and `abs(a - 50) - b` (a kink the old three-point check missed) is nonlinear.

#### 4.5b Solve policy

| Class | Starts | Warning |
|---|---|---|
| Linear equalities and inequalities | one solve from the user's start | none |
| Any nonlinear constraint | `n_starts = 5`: the user's start plus four perturbations `x0 + N(0, (0.5 * max(|x0|, 1))^2)` per coordinate, drawn with a seed derived from the model so reruns are identical. A perturbed start must have a **positive-definite implied covariance** (smallest eigenvalue above `1e-10`, the test the objective applies before it returns its sentinel): redraw up to 20 times, otherwise reuse the user's start | once per fit: "constraint `<text>` is nonlinear; the solution may depend on starting values" |

**Validity is a property of the covariance, never of the objective value** (review round 3): the implementation returns the finite sentinel `1e10` for a non-positive-definite covariance, so a finiteness test admits invalid starts, and a magnitude threshold such as `F < 1e9` rejects valid ones. [V] (`04b`, three rules on the same starts): the negative-variance start has F = 1e10 and passes `is.finite` but fails `pd_ok`; a positive-definite start with variances 1e-9 has F = 2.19e9 and fails `F < 1e9` but passes `pd_ok`.\n\n[V] Without the validity rule, one of the four perturbed starts in the evidence run had a negative variance (objective 1e10) and made nloptr error, so the failure warning below would have fired on routine runs.

`engine_args` may set `n_starts` (integer, at least 1). Among starts that satisfy 4.5c, the lowest objective wins.

#### 4.5c Acceptance gate (review rounds 1-4: feasibility alone is not convergence)

A start is **accepted** only if **all three** hold at its solution:

1. **Termination.** nloptr status is `1` (success), `3` (ftol reached) or `4` (xtol reached). Status `2` (`stopval`) is never requested; `5` (max evaluations), `6` (max time) and every negative code (`-1` failure, `-2` invalid arguments, `-3` out of memory, `-4` roundoff-limited, `-5` forced stop) are failures.
2. **Feasibility.** Every equality has `abs(h(x)) <= 1e-6` and every inequality is satisfied to `1e-6`.
3. **Stationarity (KKT with multiplier signs).** Normalize every inequality to `c(x) <= 0` (`lhs < rhs` becomes `lhs - rhs`; `lhs > rhs` becomes `rhs - lhs`; equalities stay `h(x) = 0`). The **active set** is every inequality with `c(x) >= -1e-6` (inactive inequalities get multiplier zero, which is complementary slackness). Let `J_c` be the K3 central-difference Jacobian rows of the active inequalities and `J_h` those of the equalities. Find the multipliers by non-negative least squares on `A = [J_c', J_h', -J_h']` (columns of `A` are gradients; `J_h` appears twice with opposite signs so equality multipliers `mu = z+ - z-` are free while inequality multipliers `lambda` stay `>= 0`): minimize `|| A z + grad F ||` over `z >= 0` (Lawson-Hanson active set, about 20 lines of base R, no dependency). Then `KKT = max|grad F + A z| / max(1, max|grad F|)`, and the start needs `KKT <= 1e-3`. With no active constraint the measure is the scaled full gradient. A free-sign least-squares multiplier is **not** acceptable for inequalities: it can cancel a gradient that a feasible descent direction still exploits (review round 5).

A start that errors or fails any condition is a **failed start**. If no start is accepted the fit errors, naming the strongest failure (status, residual, KKT) for the best attempt. [V] The contradictory pair `a == 1`, `a == 2` returned status `-4` with maximum residual 1.70 and is rejected.

**Evidence and calibration** (`04b`; equality constraints only). Converged solutions: `a*b == 0`, 60 starts, all status 3, KKT between 1.6e-11 and 6.7e-8 for both genuine local solutions (`a` = 0 and `b` = 0); `exp(a) + b == 1.5`, 5 starts, status 3 or 4, KKT 1.8e-8 to **2.8e-5**, the largest on an xtol-terminated start whose objective equals the others to 1e-10. The stalled start (0, 0, 0, .5, .5) on `a*b == 0`: status **-4**, residual 0, F = 1.029, KKT **1.0**. The first draft used `1e-6` and wrongly rejected the 2.8e-5 start; `1e-3` sits 35 times above the largest converged value and 1000 times below the stall. **The threshold is provisional**, calibrated on two problems, and is to be re-checked in plan task N3 with the same discipline as the N5 SE tolerance (K10).

**What each condition is shown to do.** Status alone catches the real stalled start (-4). I could **not** produce a feasible, successfully terminated, non-stationary point: SLSQP with loose tolerances (`1e-1` to `1e-3`) still landed at the right solution with KKT 4.3e-4. So for equality constraints the KKT condition is defense in depth whose independent value is demonstrated only on a stubbed result (a stall mislabeled as status 4). For inequality constraints its sign condition is demonstrated on a real solver output (the wrong-sign point above, which status and residual would accept). KKT also cannot tell a local solution from the global one: the `b = 0` solution passes it, and only the spread (4.5d) exposes that.

**Inequality evidence [V]** (`04b`). The NNLS step matched an independent bounded optimizer on 50 random problems (largest excess residual 1.8e-15, no negative entries). The reviewer's planted case, `F(x) = x` with `x <= 0` at `x = 0` (a feasible descent direction exists): free-sign multipliers give KKT = 0 and **accept** it; non-negative multipliers give KKT = 1 and **reject** it. The mirror case `F(x) = -x` (a true constrained minimizer) gives KKT = 0 and is accepted. Real runs on the three-variable model: `a + b <= 0.2` (active at the optimum) via nloptr SLSQP gives status 3, KKT 1.3e-9; `a + b >= 0.2` (inactive) gives status 4, `c(x) = -0.44`, KKT 5.6e-9. **Wrong-sign point from a real solve:** the equality solution `a + b == 0.2` judged against the inequality `a + b >= 0.2` is feasible and active (`c(x) = -1.4e-17`); the free-sign rule gives KKT = 1.9e-9 and **accepts** it, although moving into the feasible interior lowers F; the non-negative rule gives KKT = 0.43 and **rejects** it.

**Not covered.** Several simultaneous active inequalities and degenerate active sets (linearly dependent gradients, where the multipliers are not unique though the residual is well defined) were checked only through the random NNLS problems, not on a fitted model. Inequality constraints are therefore supported with the contract above, with those two cases flagged for the N3 test suite.

#### 4.5d Agreement diagnostics (attached to the fit)

| Field | Content |
|---|---|
| `n_starts`, `n_accepted` | starts run and starts accepted by 4.5c |
| `winner` | index of the winning start (1 is the user's) |
| `objective_spread` | max minus min objective among accepted starts |

**Warning rule** (review round 2, finding F3-b): the fit warns once if **either** (i) at least one start failed 4.5c or errored (`n_accepted < n_starts`), **or** (ii) `objective_spread > max(1e-6, 1e-6 * abs(F_best))`, where `F_best` is the winning objective. The message names which condition fired, the values, and "the reported fit is the best of `<n_accepted>`". If no start is feasible the fit errors (4.5c).

Why both conditions: the spread alone is blind when a single start survives. [V] Rule-level cases (`04b`): one feasible start of five at a poor local solution (F = 1.03): the spread-only rule is silent, the new rule warns; four feasible and agreeing plus one failed: spread-only silent, new rule warns; five feasible and agreeing: silent under both; five feasible at two local solutions: warns under both. Integration runs: `a*b == 0` warns (five feasible, spread 1.1e-2); `exp(a) + b == 1.5` is silent (five feasible, spread 1.9e-11).

A start that stalls **at a feasible point** is now a failed start under 4.5c rather than a candidate: [V] the start (0, 0, 0, .5, .5) on `a*b == 0` returned F = 1.029 with residual 0.0 (feasible) against the best F = 0.0952, status -4, KKT 1.0. With `n_starts = 1` it is rejected and the fit **errors** ("no start converged") instead of returning F = 1.029; with `n_starts = 5`, 4 of 5 are accepted, F = 0.0952 wins, and the failure warning fires. The spread still matters for the case KKT cannot see: starts that all converge to different local solutions.

#### 4.5e What the multi-start does and does not guarantee

Measured [V] on `a*b == 0` (n = 300, observed three-variable model, 60 random user starts): the better solution (`a` = 0, F = 0.095154) was reached from **34 of 60** with one start and **56 of 60** with five starts. (Re-measured after the valid-start rule: unchanged, 34/60 and 56/60.) Five starts raise the odds; they do **not** guarantee the global solution (4 of 60 still missed). `a*b == 0` has two legitimate local solutions (`a` = 0 and `b` = 0, F = 0.0952 and 0.1061), so it will always raise the spread warning; the message adds: "for `a*b == 0` solve `a == 0` and `b == 0` separately and keep the better (medfit MBCO, N7)".

#### 4.5f Tests (planted defects, each must turn red when its mechanism is removed)

1. **Linearity (4.5a):** the 16-expression table gives the stated classes. Planted defect: treating `e1 * e2` as linear when both sides contain labels must flip `a*b` and `(a-b)*(a+b)`; treating an unknown call as linear must flip `abs(a)-b` and `min(a, b)`.
2. **Stalled start:** `a*b == 0` from (0, 0, 0, .5, .5): with `n_starts = 1` the start is rejected (status -4, KKT 1.0) and the fit **errors** "no start converged" naming status and KKT; with `n_starts = 5` and the pinned seed 4 of 5 starts are accepted, F is within `1e-6` of 0.095154, and the failure warning fires (verified [V] with seed 1). Planted defect: replacing the acceptance gate by the residual-only gate must make the single-start fit return F = 1.029 silently.
3. **Warning rule (4.5d), unit level:** the five stubbed cases above, each with its stated old-rule and new-rule outcome. Planted defect: restoring the spread-only rule must turn the "one feasible start" and "four feasible plus one failed" cases red.
4. **Warning rule, integration:** `a*b == 0` warns on spread; `exp(a) + b == 1.5` is silent with `n_accepted = 5`.
5. **Valid starts (4.5b):** a perturbation that yields a non-positive-definite implied covariance is redrawn; planted defects: removing the redraw must make a start fail with a negative variance on the evidence seed, and replacing the positive-definite test by `is.finite(F)` must admit the negative-variance start (F = 1e10) while replacing it by `F < 1e9` must reject the 1e-9-variance start (F = 2.19e9); the three-rule table in the `04b` output is the fixture.
6. **Feasibility (4.5c):** `a == 1` with `a == 2` errors naming a constraint and the residual.
7. **No-warning path:** a provably linear constraint produces no warning and runs one solve.
8. **Reproducibility:** two runs of the same model give identical start perturbations and the same winner.
9. **Acceptance gate (4.5c), unit level:** the six stubbed solver results: converged and xtol-terminated-converged are accepted; max-evaluations (status 5), the real stall (status -4, KKT 1.0), a stall mislabeled as status 4 (rejected by KKT only) and a successful but infeasible result (residual 1e-3) are rejected, each naming its reason. Planted defects: removing the status test must admit status 5; removing the KKT test must admit the mislabeled stall; the KKT threshold must keep the 2.8e-5 converged start (the first draft's `1e-6` rejected it).
10. **Result-domain guard (4.2a step 4):** the eight non-finite or non-real expressions are rejected naming the expression, value and labels; the five valid boundary expressions are accepted. Planted defect: removing the guard must let `1/0` and `0/0` reach the optimizer.
11. **Inequality KKT (4.5c):** the NNLS-versus-bounded-optimizer check; the reviewer's planted case rejected with non-negative multipliers (KKT = 1) and accepted with free-sign ones (KKT = 0); the mirror case accepted; the real-run wrong-sign point rejected (0.43). Planted defect: replacing the NNLS step by free-sign least squares must turn the planted and wrong-sign cases red.

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
| `"abc"`, `TRUE`, `NA`, `5L`, `1i`, `Inf`, `1e999` | disallowed literal (only finite double literals) |
| `0x10` | hexadecimal literals are not supported (rejected before parsing; `a0x1` as a label is fine) |
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
| Safety (4.2a) | locked evaluator | every row of the section 7 rejection table; **planted defects (positive controls):** removing the result-domain guard must let `1/0` through; a caller-side rebinding of `exp` must change the result of an `all.names()`-only implementation and must **not** change the locked evaluator's result or run the caller's function |
| Expression grammar (4.2b) | `parse(text = )` restricted to the 4.2a node types | `-2^2`, `2^3^2`, `2^-1`, `a*b`, `exp(a)/sqrt(b+1)`, `min(a, b, 3)`, `log(a, 2)`, `pnorm(a) - 0.5`, `1e-3*a`, `.5 + a`, `1. * a`, `1e3*a`, `2E-2*a`, `a^.5`: values equal R's own evaluation of the same text (14 of 14 verified [V]) |
| Errors (section 7) | pinned regexes | every row of section 7 |
| Level (section 4.3) | own | parses; fitting errors with the pinned message |

Positive controls follow the repo rule: a defect planted in the parser (for example dropping the bound-folding step) must turn a test red.

## 9. Decisions on the draft's open items (2026-10-08)

1. **Extension definitions (section 6): accepted as proposed.**
2. **One modifier per term in v0: accepted** (lavaan allows several; revisit if a user needs them).
3. **Math allowlist (section 4.2): accepted as proposed**, including `pnorm`, `qnorm` and trig.
4. **Probe re-run on lavaan >= 0.7-3: done**, identical to 0.7-2 (section 2).

The author said "do recommended" for these; none was answered item by item, so each acceptance is the recommended option, not a separate ruling. Anything still to confirm is the whole-spec approval in the status line.
