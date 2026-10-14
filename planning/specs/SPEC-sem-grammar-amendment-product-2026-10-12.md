# SPEC AMENDMENT (APPROVED): `:` product term in the native SEM grammar

| | |
|---|---|
| **Date** | 2026-10-12 |
| **Review** | Codex adversarial review 2026-10-12: 1 high finding (reversed products `x:m` and `m:x` unidentified), addressed by section 4 rule 7, evidence in section 1. Round 2 (high): C-locale sorting gives `m:x`, contradicting the `x:m` examples and the extraction contract; resolved by making `m:x` the canonical name for the pair, reconciling every example and test, and routing all consumers through one `.sem_product_name()` helper. Round 8 (high): the OLS and effect-safety guarantee exceeded the tested model class; checked (identical regressors max |SEM - OLS| = 0, non-nested with correlated residuals 7e-5) and resolved by rule 9 (a defined supported class, rejection outside it), decision 9 and a test row. Round 7 (high): the exemption must cover the whole exogenous mean/covariance block, not only product-column covariances; verified by simulation (skewed factors with fixed variances reject 38% at nominal 5%; any `~~` statement on a factor drops the exogenous covariances and rejects 25% even with normal factors); resolved in section 2a and decision 7. Round 6 (high): ordinary ML tests for exogenous-product models; checked by null simulation (rejection .055 and .056 at nominal .05, mean chi-square 2.00 and 2.05 on df 2), exemption kept but made conditional and gated. Round 5 (high): rule 8 omitted product-factor edges; fixed in rule 8. Round 4 (high): outcome-derived regressors (`y ~ x + x:y`) are endogenous and invalidate effects and SEs; resolved by rule 8 (reject the target and its descendants), decision 8, and an outcome-derived-regressor test row. Round 3 (high): sandwich SEs do not repair a product-induced misspecification of the joint model; verified on the native engine and resolved by section 2a (inferential scope), decision 7, and an inference-scope test row. Original round-1 trail: decision 6 in section 6, and the identity test row. |
| **Status** | **APPROVED 2026-10-12** by the author, as a whole, in chat ("approve"), after eight Codex adversarial-review rounds. Decisions 2, 7, 8, 9 were asked and answered as recommended; 3-6 took the recommended defaults. The frozen `SPEC-sem-grammar-2026-10-08.md` text is **not yet edited**; this amendment is the authority for the product term until the 0.10.0 plan folds it in. Takes effect in 0.10.0, not 0.9.0. `SPEC-sem-grammar-2026-10-08.md` is APPROVED and frozen; nothing here takes effect until the author approves this amendment as a whole. Gates the 0.10.0 release (four-way via native), not 0.9.0. |
| **Amends** | `SPEC-sem-grammar-2026-10-08.md` sections 3 (lexical rule 3), 4.1 (`term`), 5 (parameter table), 7 (not-supported list) |
| **Origin** | [GRILL-native-mean-structure-2026-10-12.md](GRILL-native-mean-structure-2026-10-12.md) G5 (author chose a `:` operator) and its first open question |
| **Evidence labels** | **[V]** verified by a command this session; **[A]** proposed, needs the author's decision |

## 1. Oracle fact [V]

Probe on lavaan 0.7.2 (`lavParseModelString` and `sem()`):

- `y ~ b*x:m + c*x` parses to a row with `rhs = "x:m"`, `label = "b"`: the product is an **ordinary term whose name contains a colon**.
- `sem("y ~ m + x + x:m\nm ~ x", d)` fits and reports `y ~ x:m`; `lavInspect(fit, "data")` has columns `y, m, x:m, x`: lavaan **materializes the product as a data column** and treats it as an observed exogenous variable. It is not a derived parameter and has no model-implied formula.
- `sem("y ~ m + x + x:m + m:x\nm ~ x", d)` **fails** with "sample covariance matrix is not positive-definite": lavaan does not treat `m:x` as `x:m`, so the two spellings become two identical columns. The cause is hidden behind a generic error. This draft rejects the input up front with a named error instead (section 4, rule 7).

## 2. Proposal

**The product is a data-level transformation, not a likelihood-level derived variable.** Following lavaan, a product such as `x:m` (canonically `m:x`, rule 7) is an observed exogenous variable whose column the engine builds as `x * m` before fitting. Consequences:

- The RAM, ML discrepancy, constraints, and (0.9.0) mean structure need **no change**. The product has a free variance, free covariances with the other exogenous variables, and (with mean structure) a free mean, like any exogenous variable.
- In the **supported model class** (rule 9) path coefficients equal the equation-by-equation OLS estimates [V, section 2a]; outside it nothing is claimed and the model is rejected. The joint normality of (X, M, XM) is violated by construction, so the **sandwich covariance is the safer SE choice** and the docs say so [A: warn once when `se_type != "sandwich"` and a product is present; decide in section 6]. **The sandwich repairs standard errors only; it does not repair model tests** (section 2a).
- Rejected alternative (GRILL G5 option 2 as originally worded): treating the product as a model-implied derived quantity. It would make the variance and covariances of the product functions of theta and move four-way into the likelihood; lavaan does neither, and the grill's open question about "how it enters the likelihood" is answered by "it does not".

### 2a. Inferential scope (review finding, high) [V]

Codex's counterexample, checked on the 0.8.0 native engine with a precomputed product column (`m ~ x; y ~ x + m + xm`, n = 20000, `m = .7 x + e`, `y = .4 m + .3 x + .2 x m + e'`):

| X distribution | `m~x` | `y~m` | `y~xm` | global chi-square (df 1) |
|---|---|---|---|---|
| normal, mean 2 (uncentered) | .70134 = OLS | .39265 = OLS | .19990 = OLS | **22113.7** (p = 0) |
| normal, mean 0 (centered) | .70134 = OLS | .39244 = OLS | .19990 = OLS | 4.89 (p = .027) |
| exponential minus 1, plus 0 (centered, skewed) | not run | not run | not run | 1.65 (p = .198) |

(Seed 17; estimates to five places; the equal-to-OLS columns were compared in the first two rows only.)

- **Cause.** The product is treated as exogenous, but it is a function of `m`. The unchanged RAM therefore implies `Cov(e_m, xm) = 0` (`m` is independent of the product given `x`). In the data `Cov(e_m, xm) = E[x e^2]`, which is about `E[x]` when `e` is standard normal and independent of `x`: nonzero when X is uncentered, near zero when centered. The restriction is part of the model, so the global test rejects even though both conditional regressions are correct.
- **What is safe, in the supported model class only (rules 8 and 9):** the coefficients (equal to equation-wise OLS, so effects and four-way components are unaffected) and, with `se_type = "sandwich"`, their SEs. **Supported class (rule 9):** recursive; no residual covariance between observed endogenous variables; every regression coefficient free and used once (no shared labels, no fixed coefficient values, no `==`, `<`, `>` constraint touching a coefficient); and rule 8 holds. `:=` defined parameters are allowed (they are functions of the coefficients). Outside the class a model with a product is **rejected**, naming the first violating feature.
- **Why the class is needed (round 8, high) [V].** The OLS equality is exact in a recursive model with uncorrelated residuals. With correlated residuals it is the SUR/GLS estimator, which equals OLS only when the regressor sets are nested or identical, and shared or fixed coefficients change it outright. Checked on the native engine (`.../product-correlated-residuals.R`, n = 20000, uncentered X so the product restriction is violated): identical regressors in the two mediator equations give max |SEM - OLS| = 0 with `m1 ~~ m2` free; non-nested regressors (`m1 ~ x + cv`, `m2 ~ x + c2`) give 7e-5, against about 0.017 of sampling error. So any leakage of the product misfit into the equations without a product is small in these designs, but it is **not zero and one design is not a proof**, which is why the claim is confined to the class where equality is exact and the rest is rejected until a reference gate covers it.
- **What is not:** the global chi-square and p-value, fit indices, `anova()`, and `mbco_sem()` (a likelihood-ratio contrast under a common misspecification is not chi-square). The sandwich does not change this.
- **Scope of the problem.** The covariance restriction arises only when a **factor of the product is itself a regression target** (appears as a left side of `~`, like `m`). A product of two purely exogenous variables (`x:w`) implies no such restriction.
- **Exogenous products and non-normality (review finding, high; checked [V]).** Multiplication makes the product non-normal (for independent standard-normal factors `E[p^4] = 9`, not 3), so Codex asked whether the normal-theory test is still calibrated. Asymptotic-robustness theory says yes when the exogenous covariances are free and the errors are independent of the exogenous variables, which is how the engine completes the model. Null simulation on the native engine (script `planning/specs/evidence/native-mean-structure-2026-10-12/exo-product-null.R`; `m ~ x; y ~ m + x + w + p` with `p = x*w`, `m = .7x + e`, df = 2, n = 500, 1000 replications):

  | Exogenous factors | rejection at .05 | rejection at .01 | mean chi-square (df 2) |
  |---|---|---|---|
  | normal | 0.055 | 0.011 | 2.00 |
  | centered exponential (skewed) | 0.056 | 0.010 | 2.05 |

  Both are within about one Monte Carlo standard error (about 0.007 at .05) of nominal. Verified for this design only: one overidentified model, one sample size, mild skew, no heavy tails and no heteroskedastic errors. The exemption therefore holds **conditionally**, and round 7 (high) showed the condition must cover the **whole exogenous block**, not only the product column. Companion simulation (`.../exo-product-fixed-var.R`, same design, 1000 replications, n = 500, every restriction below is TRUE in the data-generating process, so any rejection above nominal is test miscalibration):

  | Factors | Exogenous block | df | rejection at .05 | mean chi-square |
  |---|---|---|---|---|
  | normal | free | 2 | 0.055 | 2.00 |
  | normal | variances fixed at 1, covariances free | 4 | 0.051 | 3.96 |
  | normal | variances fixed, covariances dropped by completion | 7 | **0.249** | 10.88 |
  | centered exponential | free | 2 | 0.056 | 2.05 |
  | centered exponential | variances fixed at 1, covariances free | 4 | **0.383** | 9.54 |
  | centered exponential | variances fixed, covariances dropped by completion | 7 | **0.693** | 27.57 |

  Fixing the variance of a skewed exogenous variable makes the normal-theory test reject 38% of the time (the variance estimator's asymptotic variance is `(kurtosis - 1)/n`, not `2/n`); and **writing any `~~` statement for a factor silently drops the covariances among the factors and the product column** (the existing pairing rule, `R/sem-model.R:80-88`, which follows lavaan with `fixed.x = FALSE`), which breaks the test even with normal factors (df 7, not 4). The supported configuration is therefore: **the exogenous observed variables' variances and covariances (including every product column) are all present, free, unlabeled, unbounded, and absent from every constraint expression, and the errors are independent of the exogenous variables.** The check runs on the completed parameter table. The same miscalibration affects any model with skewed exogenous variables and a restricted exogenous block, product or not; that is existing engine behavior outside this amendment, and the docs mention it.
- **Centering reduces but does not guarantee validity** (it depends on `E[x e^2]`, which also reflects skew and heteroskedasticity); the docs recommend centering and do not claim it fixes the test.

**Policy (recommended; decision 7):** when a product has an endogenous factor, or the exogenous observed variables' variance/covariance block is restricted in any way (a variance or covariance missing, fixed, labeled, bounded, or named in a constraint expression, including a covariance left out by the pairing rule), (a) warn once at fit, naming the product, the restriction, and that effects and sandwich SEs are unaffected; (b) `anova()` and `mbco_sem()` **refuse**, naming the product; (c) `glance()` reports the chi-square, df, p-value and fit indices as `NA` with a note, and `summary()` prints "model test not valid with a product of an endogenous variable". Products of exogenous variables are unrestricted.

## 3. Grammar change

```
term         := [ modifier "*" ] operand
operand      := name | product
product      := name ":" name          # medfit extension (new)
```

- `product` appears **only on a right side** (`term`). It is not allowed as an `lhs`, on either side of `=~` (no latent products in v1), or inside an `expr`.
- Left side of `:` and right side of `:` are distinct observed names. `x:x` and three-way products (`x:m:w`) are rejected, naming the feature.
- A modifier applies to the whole product: `b*x:m` labels the coefficient of the product term (the lavaan reading [V]).
- Lexical rule 3 (names) is unchanged: `x:m` is two names joined by the operator, not a name containing a colon. **Tokenization order:** `:=` is matched first, then `level:` (a reserved word followed by `:`), then `:` as the product operator. `a:=b` stays a defined parameter; `a :b` with whitespace around the colon is rejected (no implicit joins) [A].
- Reserved words are unchanged; `level` cannot be a variable, so `level:1` is never a product.

## 4. Semantics

1. The table row for `y ~ b*x:m` has `rhs = "m:x"` (the canonical form of rule 7; lavaan keeps the spelling as written, `"x:m"` [V]) and coefficient name `y~m:x` (or the label).
2. Before fitting, `fit_sem()` (and `fit_mediation(engine = "native", model = )`) builds each distinct product column under its canonical name, `data[["m:x"]] <- data[["x"]] * data[["m"]]`, **after listwise deletion**, so no incomplete row enters a product. Both factors must be numeric observed variables present in the data.
3. If `data` already has a column named `m:x` (canonical) **or `x:m`** (its reversal), it is used only if it equals `x * m` exactly; otherwise an error names the column and both options (rename it or drop it).
4. A product of a latent variable (a name defined by `=~`) errors: "products with latent variables are not supported in v1".
5. Centering is the user's responsibility and is documented: the effect of X at M = 0 (and `E[M | X = 0]` in four-way) depend on where X and M are centered.
6. Weights do not enter the product; the weighted moments treat the product column as any other column.
7. **Product identity (review finding, high).** `x:m` and `m:x` are the same product. After parsing, every product is **canonicalized by sorting its two factor names in the C locale**, and the table's `rhs`, the coefficient name (`y~m:x` for the pair `x`, `m`, since `m` sorts before `x`), and the materialized column all use the canonical form, whatever order the user wrote. The canonical name is a function of the two names, `.sem_product_name(a, b)`, and **one helper serves the parser, the materializer, and every consumer** (`extract_mediation()`, the four-way extractor, `tidy()` lookups); no consumer hard-codes a spelling. Consequences:
   - Two terms with the same canonical product **in one equation** (`y ~ x:m + m:x`, or `x:m + b*m:x`) are a duplicate: error naming both spellings as written and the canonical name. Modifiers are not compared; any duplicate is an error, so conflicting labels and fixed values cannot slip through.
   - The same canonical product in **different equations** (`y ~ x:m`, `z ~ m:x`) is allowed and shares one materialized column; the coefficients are separate parameters, as for any regressor reused across equations.
   - Rewriting a product written `x:m` to `m:x` in output is deliberate and documented; a label (`b*x:m`) is the way to name the coefficient.
   - Canonicalization does not depend on the data, so the parameter table is the same with or without data attached.
9. **Supported model class (review round 8, high).** A model that contains any product is rejected unless it is in the class of section 2a: recursive; no `~~` statement between two observed endogenous variables (residual covariance); no label used on more than one regression row; no fixed regression coefficient (`b*x` with numeric `b`, or `0*x`); no `==`, `<`, or `>` constraint (or bound folded from one) whose expression names a regression label; and rule 8 holds. The error names the model feature and says it is not yet supported with products, not that it is invalid. The check runs on the parsed table. Models with no product are unaffected (they keep every 0.8.0 capability).
8. **No outcome-derived regressors (review finding, high) [V].** A product in the equation for target `t` is rejected if either factor is `t` or a **descendant of `t`** in the directed graph of the model (an edge `a -> b` for each plain regressor `a` in `b ~ a`, **an edge `f -> b` from each of the two factors `f` of every product term `f:g` in `b ~ f:g`** (the product column itself is not a node), and `eta -> indicator` for each `eta =~ indicator`). The graph is built from the whole parsed table before any product is checked, so a dependency that exists only through a product is seen: in `y ~ x:z; z ~ w:y` the edges are `x -> y`, `z -> y`, `w -> z`, `y -> z`, so `z` is a descendant of `y` and `x:z` in `y`'s equation is rejected (it is also a cycle `y -> z -> y`, which this rule reports by the same error). The error names the equation, the product, and the offending factor ("`x:y` uses `y`, the target of its own equation"; "`x:z` uses `z`, which is downstream of the target `y` through `z ~ y`"). Such a regressor is built from the outcome, so it is correlated with the equation's error, and neither OLS-equality nor sandwich SEs make it consistent. Evidence (seed 17, n = 20000, `y = .3 x + e`, `x ~ N(2, 1)`): the true coefficients of `y ~ x + xy` are `x` = .3 and `xy` = 0, `lm()` returns `x` = -0.163 and `xy` = 0.383, and `Cov(xy, e)` = 2.02, which is `E[x] Var(e)` = 2 as predicted. The check runs on the parsed table, so it applies whether or not data is attached.

## 5. Impact on the frozen spec

| Frozen section | Change |
|---|---|
| 3 (lexical rule 3, names) | Add a note: `:` is the product operator, tokenized after `:=` and `level:`. |
| 4.1 productions | Replace `term` as above; add `operand`, `product`. |
| 5 (parameter table) | No new columns; `rhs` may contain `name:name`. |
| 7 (not supported) | The frozen spec does not list interaction terms (grep found no mention); add latent products, `x:x`, and 3-way products as unsupported. |
| 6 (medfit extensions) | Tag the product "medfit extension" in docs only if the lavaan oracle disagrees after the 0.10.0 probe on 0.7-3 [V pending]. It matches lavaan 0.7.2 today, so it is a **core** form, not an extension. |

## 6. Decisions needed from the author

**Resolved 2026-10-12 (author, in chat):** decisions 2, 7, 8, 9 were answered as recommended. Decisions 3, 4, 5, 6 take the recommended defaults (stated to the author, no objection). Decision 1: **approved** by the author on 2026-10-12.

1. Approve the amendment as a whole (the frozen spec's own rule).
2. **Product as data transformation (this draft, recommended) vs. derived quantity.** The draft follows lavaan and leaves the engine untouched; the alternative is a much larger change.
3. Warn when a product is present and `se_type != "sandwich"`? Recommended: yes, once per fit, naming the reason (SEs only; see decision 7 for model tests).
4. Strictness of the exact-equality rule for a pre-existing product column (section 4.3); alternative: tolerance 1e-12.
5. v1 limit to two-way products of observed variables; 3-way and latent products later.
6. Canonical order (rule 7): C-locale sort of the factor names (recommended: data-independent, same table with or without data) vs. keeping the first-written order and rejecting the reversal as a duplicate (no renaming, but `y ~ x:m` and `z ~ m:x` would then name one column two ways).
7. **Model-test policy for a product with an endogenous factor (section 2a).** Recommended: warn once, refuse `anova()` and `mbco_sem()`, and report chi-square and fit indices as `NA` in `glance()`/`summary()`. Alternatives: warn only (leaves a known-invalid p-value one call away); refuse the fit unless `se_type = "sandwich"` (strict, and still does not fix the test); or suppress ordinary ML tests for **all** product models (Codex's round-5 recommendation). The last is not recommended: the section 2a simulation shows the exogenous-product test is calibrated, so suppressing it would discard a valid test; revisit if the exogenous-product gate ever fails.
8. **Rule 8 reach.** Recommended: reject the target and **all its descendants** (covers `y ~ x:z` with `z ~ y`, and indicators of a latent target). Alternative: reject only the target itself (the cheap direct case), leaving downstream products as a documented user risk; it misses real outcome-derived regressors.
9. **Reject or merely warn outside the supported class (rule 9).** Recommended: **reject** in 0.10.0 (conservative; the simulation shows small leakage, so relaxing later is plausible once a reference gate for correlated residuals and cross-equation restrictions passes). Cost: moderated parallel mediation with `m1 ~~ m2` and a product in the outcome equation is not available in 0.10.0. Alternative: allow with a warning that the coefficient-safety assurance does not apply (keeps the model fittable, leaves users without an assurance).

## 7. Test plan

| Tier | Content |
|---|---|
| unit | Parser: `y ~ x:m` (row `rhs` is `m:x`), `y ~ b*x:m`, `x:m` inside an expression (error), `x:x` (error), `x:m:w` (error), `eta:x` with `eta =~` (error), `a:=b` still a defined parameter, `level:1` unaffected, spacing cases. |
| oracle | lavaan parity on the same model with `x:m`: table rows (after canonicalizing lavaan's `rhs`, which keeps the written order), estimates, SEs, with and without `sampling.weights` (the sandwich). |
| regression | A fit with an explicit user-built product column (`m:x`) equals the materialized fit exactly; a mismatched pre-existing column errors. |
| integration | `fit_mediation(engine = "native", model = )` with a product; `extract_mediation()` finds the product coefficient through `.sem_product_name(treatment, mediator)` (the input to four-way), for both argument orders and for a model written with `x:m` or `m:x`. |
| identity (rule 7) | `y ~ x:m + m:x` errors naming both spellings (planted defect: skipping canonicalization must turn it into a singular-covariance failure, the lavaan behavior [V]); `y ~ a*x:m + b*m:x` errors (conflicting labels); `y ~ x:m`, `z ~ m:x` is accepted, shares one column, and both coefficients are named `y~m:x` and `z~m:x`; `x:m` alone and `m:x` alone both yield `y~m:x`; `.sem_product_name("x", "m") == .sem_product_name("m", "x") == "m:x"`; a pre-existing `x:m` column is checked like `m:x`; the table is identical with and without data; planted defect: a consumer hard-coding `y~x:m` must fail the extraction test. |
| supported class (rule 9) | each of these with a product is rejected naming the feature, with no data attached: residual covariance `m1 ~~ m2`; a label shared across two regression rows (including across equations); a fixed coefficient (`y ~ 0.3*x`); `a == b` and `a < 1` on regression labels; a nonrecursive loop; each accepted when the product is removed (no regression of 0.8.0 behavior); `:=` defined parameters accepted alongside a product; reference gate: `product-correlated-residuals.R` records max |SEM - OLS| and the distance to truth in the identical-regressor and non-nested designs, so relaxing the rule later has a baseline; planted defect: dropping the residual-covariance check must let `m1 ~~ m2` fit with a product. |
| outcome-derived regressors (rule 8) | `y ~ x + x:y` and `y ~ x + y:x` error naming the equation, product, and factor; `y ~ x:z; z ~ w:y` errors (product-factor edges); a longer chain through products (`y ~ x:z; z ~ w:u; u ~ v:y`) errors; each of these with no data attached; `y ~ x:z` with `z ~ y` errors as downstream; `y ~ x:z` with `z ~ w` (not downstream) is accepted; an indicator of a latent target in a product errors; the check runs on the parsed table with no data attached; population gate: with the rule 8 data-generating process the unrestricted `lm()` fit is shown to be biased (`xy` far from 0), which is why the model is rejected rather than fitted; planted defect: removing the descendant search must let `y ~ x:z` with `z ~ y` fit. |
| inference scope (section 2a) | Population counterexample as a gate: with the section 2a data-generating process, uncentered X gives chi-square far above the critical value while `m~x`, `y~m`, `y~xm` equal equation-wise `lm()` to 1e-8 (the test asserts both, so the effects stay trusted and the global test stays flagged); the warning names the product; `anova()` and `mbco_sem()` refuse with the product named; `glance()` chi-square, p-value and indices are `NA`; **exogenous-product null gate:** the section 2a simulation (1000 replications, n = 500, normal and centered-exponential factors) must give a rejection rate in [0.03, 0.07] at nominal .05 and a mean chi-square within 0.15 of its df; the restricted-block cases are treated as unsupported (warning, refusals, `NA` indices): `x ~~ 1*x` with `w ~~ 1*w` (dropped covariances, df 7), the same with the covariances written out (fixed variances, df 4), a labeled factor variance, and a covariance named in a constraint; the simulation gate also records that the skewed fixed-variance case rejects at about 38% and the dropped-covariance case at about 25% (normal) and 69% (skewed), which is why they are refused rather than tested; planted defect: removing the endogenous-factor check must let `anova()` run and fail the refusal test. |
| planted defect | Product built before listwise deletion (must fail on a data set with NAs); product built with the wrong factor order or from centered copies (must fail the equality test). |

## 8. Out of scope

Latent products, higher-order products, automatic centering, and four-way itself (0.10.0 plan, which consumes the product coefficient through the shared helper).
