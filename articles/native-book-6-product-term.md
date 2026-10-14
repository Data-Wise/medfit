# Native engine book, chapter 6: the product term

Since 0.10.0 the native engine accepts a **product term** on the right
side of a regression: `y ~ x + m + x:m`. The product is how a
treatment-by-mediator interaction enters the model, and it is what the
four-way decomposition of [Chapter
7](https://data-wise.github.io/medfit/articles/native-book-7-four-way.md)
reads. This chapter follows a product through the engine: how the parser
reads it, how the engine builds its column, why the likelihood can treat
it as an ordinary exogenous variable, which models the engine therefore
accepts and why each exclusion exists, and what happens to the standard
errors and the model test. Every claim is checked against least squares,
against a hand computation or against a simulation whose result could
have come out the other way. The engine is experimental.

|  |  |
|----|----|
| **You need** | Chapters 1 to 5 (the RAM matrices, the mean structure, `fixed_x` and the factorization of Chapter 4, the information matrices and the sandwich of Chapter 5) and ordinary least squares |
| **You get** | the product grammar and its canonical name, where and why the engine builds the product column, a proof that the path estimates of a product model are equation-wise least squares (and what breaks that proof, rule by rule), why the expected information is refused, why the model test is reported as `NA` when a factor is endogenous, and the null simulation that keeps it when both factors are exogenous |
| **Time** | about 60 minutes |

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
library(generics)
```


    Attaching package: 'generics'

    The following objects are masked from 'package:base':

        as.difftime, as.factor, as.ordered, intersect, is.element, setdiff,
        setequal, union

``` r
rd <- function(x, d = 4) round(x, d)
quiet <- function(expr) suppressWarnings(suppressMessages(expr))
say <- function(expr) {
  tryCatch({
    expr
    "no error"
  }, error = function(e) conditionMessage(e))
}
d <- mediation_demo
n <- nrow(d)

# The model of this chapter: a treatment-by-mediator product in the outcome equation, a covariate in both
product_model <- "
  mediator1 ~ treatment + covariate1
  outcome_int ~ mediator1 + treatment + treatment:mediator1 + covariate1
"
```

Notation. The treatment is \\x\\ (`treatment`), the mediator \\m\\
(`mediator1`), the covariate \\c\\ (`covariate1`), the outcome \\y\\
(`outcome_int`) and the product \\p = x\\m\\. The structural equations
are

\\ m = \beta_0 + \beta_1 x + \gamma c + e_m, \qquad y = \theta_0 +
\theta_1 x + \theta_2 m + \theta_3 p + \delta c + e_y . \\

## 1. The grammar

### The `:` token

A product joins two observed variable names with `:` and no spaces:
`x:m`. The parser reads `:` as an operator between two names (a variable
name cannot contain a colon), after it has matched `:=` (a defined
parameter) and `level:` (a two-level block), so `a := b` and `level: 1`
keep their meaning. The product may carry a modifier like any term
(`t3*x:m` labels its coefficient), and it may appear only on the right
side of `~`.

What the parser stores is one row of the parameter table, like any
regressor:

``` r
parsed <- medfit:::.sem_parse("outcome_int ~ cp*treatment + mediator1 + t3*treatment:mediator1")
parsed$parameters[, c("lhs", "op", "rhs", "label")]
```

              lhs op                 rhs label
    1 outcome_int  ~           treatment    cp
    2 outcome_int  ~           mediator1
    3 outcome_int  ~ mediator1:treatment    t3

The right side of the third row is `mediator1:treatment`, not
`treatment:mediator1` as written. The parser replaces every product by
its **canonical name**, built by one helper, `.sem_product_name()`: the
two names sorted in the C locale (byte order, `sort(method = "radix")`)
and joined by `:`.

``` r
c(medfit:::.sem_product_name("treatment", "mediator1"),
  medfit:::.sem_product_name("mediator1", "treatment"),
  medfit:::.sem_product_name("b", "B"),
  medfit:::.sem_product_name("x", "X1"))
```

    [1] "mediator1:treatment" "mediator1:treatment" "B:b"
    [4] "X1:x"               

Byte order puts upper case before lower case (`B:b`). The ordinary
[`sort()`](https://rdrr.io/r/base/sort.html) uses the collation of the
session’s locale, which differs between machines, and then the name of a
coefficient (`outcome_int~mediator1:treatment`) would depend on where
the model was fitted. The C locale makes the name a function of the two
names alone.

### Why `x:m` and `m:x` are one term

The column of `x:m` is \\x_i m_i\\ and the column of `m:x` is \\m_i
x_i\\, the same numbers (floating-point multiplication is commutative).
Two spellings in one equation would put two identical columns in the
data, and the sample covariance matrix would be singular. lavaan, which
keeps the spelling as written, then stops with a message about a
covariance matrix that is not positive definite, which does not name the
cause. Because the parser rewrites each product to its canonical name
first, the duplicate is visible in the parameter table, and the engine
names it:

``` r
cat(say(fit_sem("outcome_int ~ treatment + mediator1 + treatment:mediator1 + mediator1:treatment", d)))
```

    'treatment:mediator1' and 'mediator1:treatment' in the equation for 'outcome_int' are the same product (canonical name 'mediator1:treatment'); keep one term per product

The same product in **two different equations** is not a duplicate: both
coefficients are free and both equations read one materialized column,
as any regressor that appears in two equations.

### What the grammar refuses

``` r
grammar <- c(
  `latent factor` = say(medfit:::.sem_parse("M =~ mediator1 + mediator2\noutcome ~ treatment:M")),
  `three-way` = say(medfit:::.sem_parse("outcome ~ treatment:mediator1:covariate1")),
  `x:x` = say(medfit:::.sem_parse("outcome ~ treatment:treatment")),
  `left side` = say(medfit:::.sem_parse("treatment:mediator1 ~ outcome")),
  `in a covariance` = say(medfit:::.sem_parse("outcome ~~ treatment:mediator1")),
  `with spaces` = say(medfit:::.sem_parse("outcome ~ treatment : mediator1"))
)
cat(sprintf("%s:\n  %s\n", names(grammar), grammar), sep = "\n")
```

    latent factor:
      the product 'treatment:M' involves a latent variable; products with latent variables are not supported in this version

    three-way:
      a three-way or higher product ('treatment:mediator1:covariate1') is not supported; products have exactly two observed variables (in 'outcome ~ treatment:mediator1:covariate1')

    x:x:
      the product 'treatment:treatment' of a variable with itself is not supported; products join two different variables (in 'outcome ~ treatment:treatment')

    left side:
      a product term ':' cannot be a left side ('treatment:mediator1'); products are right-side terms of a regression (in 'treatment:mediator1 ~ outcome')

    in a covariance:
      a product term ('treatment:mediator1') is only valid on the right side of a regression ('~'), not of '~~' (in 'outcome ~~ treatment:mediator1')

    with spaces:
      a product ':' needs a variable name on each side, written without spaces (x:m) (in 'outcome ~ treatment : mediator1')

A product of a latent variable has no data column (a latent variable is
not observed), so the column cannot be built; a latent product needs a
different estimator and is not in this version. A three-way product and
`x:x` are not two-way products of distinct variables. A product on a
left side or in a covariance statement would be a statement about the
product as a variable, and the engine does not let the user write one:
its variance, covariances and mean are filled in by the engine (Section
3).

## 2. Building the product column

The product is a **data-level** term: the engine computes the column
\\x_i m_i\\ and then fits a model in which that column is one more
observed variable. The helper is `.sem_materialize_products()`. It reads
the completed parameter table, and for each distinct product adds the
column under the canonical name:

``` r
tab <- medfit:::.sem_complete(medfit:::.sem_parse(product_model)$parameters)
mat <- medfit:::.sem_materialize_products(tab, d)
setdiff(names(mat$data), names(d))
```

    [1] "mediator1:treatment"

``` r
c(largest_difference = max(abs(mat$data[["mediator1:treatment"]] - d$treatment * d$mediator1)))
```

    largest_difference
                     0 

### Where in the pipeline, and why there

[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
runs these steps in order: parse, complete the table, read the
model-test verdict (Section 5), **build the product columns**, assign
the `fixed_x` moments, build the RAM, check that every variable is a
column, delete incomplete rows (listwise), **check any product column
the user supplied**, and form the sample moments.

The build comes before the `fixed_x` step for a concrete reason.
`.sem_assign_fixed_x()` (Chapter 4) computes the fixed moments from the
model’s columns, and when one of them is absent it returns the table
unchanged, leaving the fit to report the missing column. Without the
product column it would leave **every** fixed row of the fit without a
value, not only the product’s. Call it both ways:

``` r
tab_fx <- medfit:::.sem_complete(medfit:::.sem_parse(product_model)$parameters, fixed_x = TRUE)
unassigned <- function(t) sum(t$fixed_x & is.na(t$fixed))
c(fixed_rows = sum(tab_fx$fixed_x),
  unassigned_before_the_build = unassigned(medfit:::.sem_assign_fixed_x(tab_fx, d)),
  unassigned_after_the_build = unassigned(medfit:::.sem_assign_fixed_x(tab_fx, mat$data)))
```

                     fixed_rows unassigned_before_the_build
                              9                           9
     unassigned_after_the_build
                              0 

Building before listwise deletion is safe because a missing factor makes
the product missing (\\\text{NA} \times a = \text{NA}\\), so the row is
dropped either way. The fixed moments are computed on the complete rows
of the model’s columns, the product included. Check both on data with
three missing mediator values:

``` r
d_na <- d
d_na$mediator1[c(3, 50, 200)] <- NA
fit_na <- quiet(fit_sem(product_model, d_na, fixed_x = TRUE))
kept <- complete.cases(d_na[, c("treatment", "mediator1", "covariate1", "outcome_int")])
p_kept <- (d_na$treatment * d_na$mediator1)[kept]
fixed_tab <- fit_na@table[fit_na@table$fixed_x, c("lhs", "op", "rhs", "est")]
c(rows_used = fit_na@n_obs,
  product_mean_fixed = fixed_tab$est[fixed_tab$lhs == "mediator1:treatment" & fixed_tab$op == "~1"],
  product_mean_of_kept_rows = mean(p_kept),
  product_variance_fixed = fixed_tab$est[fixed_tab$lhs == "mediator1:treatment" &
                                           fixed_tab$rhs == "mediator1:treatment"],
  product_variance_of_kept_rows = mean((p_kept - mean(p_kept))^2))
```

                        rows_used            product_mean_fixed
                      397.0000000                     0.3028965
        product_mean_of_kept_rows        product_variance_fixed
                        0.3028965                     0.6957773
    product_variance_of_kept_rows
                        0.6957773 

### A product column the user already has

If `data` already has a column under either spelling
(`mediator1:treatment` or `treatment:mediator1`), the engine uses it
only if it equals the product **on the rows the fit uses**; otherwise it
stops and asks you to rename or drop it. The comparison waits until
after listwise deletion because before it the comparison would involve
the missing values: a column that differs from the product only on a row
the fit drops is accepted.

``` r
d_ok <- d_na
d_ok[["treatment:mediator1"]] <- d_na$treatment * d_na$mediator1
d_ok[["treatment:mediator1"]][3] <- 99           # row 3 has a missing mediator, so the fit drops it
d_bad <- d_ok
d_bad[["treatment:mediator1"]][4] <- 99          # row 4 is used
fit_ok <- quiet(fit_sem(product_model, d_ok))
c(same_estimates_as_the_built_column = max(abs(coef(fit_ok) - coef(quiet(fit_sem(product_model, d_na))))))
```

    same_estimates_as_the_built_column
                                     0 

``` r
cat(say(quiet(fit_sem(product_model, d_bad))))
```

    the column `treatment:mediator1` in `data` is not the product of mediator1 and treatment on the rows used: rename it, or drop it so medfit builds the product

### With `fixed_x`

The product is an exogenous observed variable (nothing in the model
explains it), so `fixed_x = TRUE` fixes its mean, its variance and its
covariances with the other exogenous variables at their sample values,
as for any other (Chapter 4). The factorization proof of Chapter 4 then
applies unchanged: the structural estimates and their standard errors
are the same with and without `fixed_x`.

``` r
fit_free <- quiet(fit_sem(product_model, d))
fit_fx <- quiet(fit_sem(product_model, d, fixed_x = TRUE))
shared <- intersect(names(fit_free@theta), names(fit_fx@theta))
fit_fx@table[fit_fx@table$fixed_x, c("lhs", "op", "rhs")]
```

                       lhs op                 rhs
    9            treatment ~~           treatment
    10           treatment ~~          covariate1
    11           treatment ~~ mediator1:treatment
    12          covariate1 ~~          covariate1
    13          covariate1 ~~ mediator1:treatment
    14 mediator1:treatment ~~ mediator1:treatment
    16           treatment ~1
    17          covariate1 ~1
    19 mediator1:treatment ~1                    

``` r
c(estimates = max(abs(fit_free@theta[shared] - fit_fx@theta[shared])),
  standard_errors = max(abs(sqrt(diag(fit_free@vcov))[shared] - sqrt(diag(fit_fx@vcov))[shared])))
```

          estimates standard_errors
       6.661338e-16    1.935591e-12 

The nine fixed rows are the three means, three variances and three
covariances of `treatment`, `covariate1` and the product.

## 3. The product in the likelihood

### What the RAM sees

After the column is built, the product is an observed variable with no
incoming path. Its row of \\A\\ is zero; its variance, its covariances
with the other exogenous variables and (with the mean structure) its
mean are free parameters, exactly as for `treatment` and `covariate1`:

``` r
ram <- fit_free@internals$ram
mats <- medfit:::.sem_ram_mats(ram, fit_free@theta)
dimnames(mats$a) <- list(ram$vars, ram$vars)
rd(mats$a[ram$obs, ram$obs], 3)
```

                        mediator1 treatment covariate1 outcome_int
    mediator1               0.000     0.581      0.448           0
    treatment               0.000     0.000      0.000           0
    covariate1              0.000     0.000      0.000           0
    outcome_int             0.584     0.212      0.356           0
    mediator1:treatment     0.000     0.000      0.000           0
                        mediator1:treatment
    mediator1                         0.000
    treatment                         0.000
    covariate1                        0.000
    outcome_int                       0.479
    mediator1:treatment               0.000

``` r
grep("mediator1:treatment", names(fit_free@theta), value = TRUE, fixed = TRUE)
```

    [1] "outcome_int~mediator1:treatment"
    [2] "treatment~~mediator1:treatment"
    [3] "covariate1~~mediator1:treatment"
    [4] "mediator1:treatment~~mediator1:treatment"
    [5] "mediator1:treatment~1"                   

The product has five parameters of its own: a variance, covariances with
`treatment` and `covariate1`, a mean, and its coefficient in the outcome
equation. The model does not know that the column is \\x\\m\\. Nothing
in the discrepancy, the gradient or the constraint machinery of Chapters
1 to 3 changes; that is the design. A product written as a model-implied
quantity (its variance and covariances as functions of the other
parameters) would change all of them, and lavaan does not do it either.

### Theorem: the path estimates are equation-wise least squares

Take a model that satisfies the engine’s validity rules 8 and 9 for
products (numbered in the grammar amendment; Section 4 states them):
recursive, no residual covariance between outcomes, and every regression
coefficient and intercept free and used once. (Whether the exogenous
block, the variances, covariances and means of the exogenous observed
variables, is free does not matter here: a restriction there touches
only those moments, not the equations. It matters for the model test,
Section 5.) Write \\z\\ for the exogenous observed variables (\\x\\,
\\c\\, \\p\\), \\\eta\\ for their moments, and \\\psi_m = (\beta_0,
\beta_1, \gamma, \sigma^2_m)\\, \\\psi_y = (\theta_0, \cdots, \delta,
\sigma^2_y)\\ for the parameters of the two equations.

**Step 1: the model’s density factors.** In the RAM, \\e_m\\ and \\e_y\\
are independent of each other and of \\z\\ (no residual covariance, and
an error is never correlated with an exogenous variable). So, under the
model, \\m\\ given \\z\\ is normal with mean \\\beta_0 + \beta_1 x +
\gamma c\\ and variance \\\sigma^2_m\\, and \\y\\ given \\(z, m)\\ is
normal with mean \\\theta_0 + \theta_1 x + \theta_2 m + \theta_3 p +
\delta c\\ and variance \\\sigma^2_y\\. For every row,

\\ f(z_i, m_i, y_i) = f(z_i;\\ \eta)\\ f(m_i \mid z_i;\\ \psi_m)\\ f(y_i
\mid z_i, m_i;\\ \psi_y) . \\

This is the chain rule of probability in the order of the recursive
model, applied to the model’s own density. It is an identity in the
parameters, true at every value of the data, whether or not the data
came from the model.

**Step 2: the parameters do not overlap.** Rule 9 is what guarantees
this: no label is shared between equations, no coefficient is fixed or
constrained, no residual covariance joins \\e_m\\ and \\e_y\\, and no
intercept is tied. So the log likelihood is \\\ell = \ell_z(\eta) +
\ell_m(\psi_m) + \ell_y(\psi_y)\\, a sum of functions of disjoint
parameter sets, and it is maximized by maximizing each term on its own.

**Step 3: each term is a Gaussian regression.** \\\ell_m(\psi_m) =
-\frac n2 \log(2\pi\sigma^2_m) - \frac{1}{2\sigma^2_m} \sum_i (m_i -
\beta_0 - \beta_1 x_i - \gamma c_i)^2\\. For any \\\sigma^2_m\\ the
coefficients that maximize it minimize the residual sum of squares: they
are the least-squares coefficients. Setting the derivative in
\\\sigma^2_m\\ to zero gives \\\hat\sigma^2_m = \text{RSS}/n\\. The same
holds for \\\ell_y\\, whose regressors include the column \\p\\. The
maximizer of \\\ell_z\\ is the sample mean and the divisor-\\n\\
covariance of \\z\\ (Chapter 4).

Hence the path coefficients and intercepts are the
[`lm()`](https://rdrr.io/r/stats/lm.html) coefficients equation by
equation, and the residual variances are \\\text{RSS}/n\\. Check:

``` r
lm_m <- lm(mediator1 ~ treatment + covariate1, d)
lm_y <- lm(outcome_int ~ mediator1 + treatment + I(treatment * mediator1) + covariate1, d)
cf <- coef(fit_free)
ols <- c(coef(lm_m), coef(lm_y), mean(residuals(lm_m)^2), mean(residuals(lm_y)^2))
sem <- cf[c("mediator1~1", "mediator1~treatment", "mediator1~covariate1",
            "outcome_int~1", "outcome_int~mediator1", "outcome_int~treatment",
            "outcome_int~mediator1:treatment", "outcome_int~covariate1",
            "mediator1~~mediator1", "outcome_int~~outcome_int")]
comparison <- data.frame(parameter = names(sem), native = rd(unname(sem), 6), least_squares = rd(unname(ols), 6))
comparison
```

                             parameter   native least_squares
    1                      mediator1~1 0.084384      0.084384
    2              mediator1~treatment 0.581425      0.581425
    3             mediator1~covariate1 0.448149      0.448149
    4                    outcome_int~1 0.194963      0.194963
    5            outcome_int~mediator1 0.583536      0.583536
    6            outcome_int~treatment 0.212185      0.212185
    7  outcome_int~mediator1:treatment 0.479323      0.479323
    8           outcome_int~covariate1 0.356363      0.356363
    9             mediator1~~mediator1 0.953565      0.953565
    10        outcome_int~~outcome_int 1.073923      1.073923

``` r
c(largest_difference = max(abs(sem - ols)))
```

    largest_difference
          1.554312e-15 

### What the product changes: the joint model

The proof used only the model’s factorization, not the truth of the
model. The model does make one claim the data contradict. It says
\\e_m\\ is independent of every exogenous variable, \\p\\ included, so
its implied covariance of \\m\\ and \\p\\ is the one transmitted through
the regressors of \\m\\:

\\ \operatorname{Cov}\_{\text{model}}(m, p) = \beta_1
\operatorname{Cov}(x, p) + \gamma \operatorname{Cov}(c, p) . \\

In the data \\p = x\\m\\ contains \\m\\, so \\p\\ is correlated with the
mediator’s error. The least-squares residual of \\m\\ is orthogonal to
\\x\\ and \\c\\, not to \\p\\. The difference between the sample and the
implied moments sits exactly there:

``` r
sigma_hat <- medfit:::.sem_implied(ram, fit_free@theta)
smp <- medfit:::.sem_sample(fit_free@data, ram)
resid_cov <- smp$s - sigma_hat
rd(resid_cov, 4)
```

                        mediator1 treatment covariate1 outcome_int
    mediator1              0.0000         0          0      0.2341
    treatment              0.0000         0          0      0.0000
    covariate1             0.0000         0          0      0.0000
    outcome_int            0.2341         0          0      0.2732
    mediator1:treatment    0.4885         0          0      0.2850
                        mediator1:treatment
    mediator1                        0.4885
    treatment                        0.0000
    covariate1                       0.0000
    outcome_int                      0.2850
    mediator1:treatment              0.0000

``` r
e_m <- residuals(lm_m)
c(sample_cov_m_p = smp$s["mediator1", "mediator1:treatment"],
  implied_cov_m_p = sigma_hat["mediator1", "mediator1:treatment"],
  sample_cov_residual_of_m_and_p = mean(e_m * (d$treatment * d$mediator1)))
```

                    sample_cov_m_p                implied_cov_m_p
                         0.6723246                      0.1838719
    sample_cov_residual_of_m_and_p
                         0.4884527 

The covariance part of the misfit is the \\(m, p)\\ entry, which is the
sample covariance of the mediator’s residual and the product, and the
entries that inherit it through the outcome equation. The minimized
discrepancy, and so the chi-square, measures this restriction, not a
misfit of either regression. Section 5 takes up the consequences.

When both factors are exogenous (`x:w`, with `w` a covariate), the
product is a function of exogenous variables only, the model makes no
such claim, and the joint model can be correct.

### Why a product turns the mean structure on

A product model always has the mean structure (Chapter 1): with a
product present,
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
frees the intercept of every observed variable whose intercept you did
not write, as if `meanstructure = TRUE`. The reason is the four-way
decomposition of Chapter 7. Its reference interaction needs \\E\[M \mid
X = 0\] = \beta_0 + \gamma \bar c\\, which contains the mediator’s
intercept \\\beta_0\\, and a covariance-only fit has no intercepts.
Leaving the choice to a later
[`extract_mediation()`](https://data-wise.github.io/medfit/reference/extract_mediation.md)
call would mean refitting, so the fit makes it, and refuses the
contradictory request:

``` r
cat(say(fit_sem(product_model, d, meanstructure = FALSE)))
```

    `meanstructure = FALSE`, but the model has a product term ('mediator1:treatment'); product models need the mean structure (the four-way decomposition needs the mediator intercept E[M | X = 0]); leave `meanstructure` unset or use `TRUE`

The slopes do not depend on the mean structure (Step 3 holds with or
without intercepts in the regressions, because the intercept only
absorbs the means), so nothing about Section 3’s estimates changes. The
product’s own mean is a free parameter, estimated at the sample mean of
the column:

``` r
c(estimated_mean = cf[["mediator1:treatment~1"]], sample_mean = mean(d$treatment * d$mediator1))
```

    estimated_mean    sample_mean
         0.3071202      0.3071202 

## 4. The supported model class: rules 8 and 9

The theorem of Section 3 needs two things: the regressors of each
equation must not be built from the equation’s own outcome (rule 8), and
the log likelihood must split into terms with disjoint parameters (rule
9). Outside that class the engine refuses a product model, naming the
feature. Rule 9’s message says the feature is “not yet supported with
products”; rule 8’s does not, because an outcome-derived regressor is
never valid. Each exclusion below is the place where the proof breaks,
and each is checked by fitting the same model with the product supplied
as a **precomputed data column** (`p`). The engine then sees an ordinary
variable, the rules do not run, and the gap between the native estimates
and least squares can be measured.

### Rule 8: no outcome-derived regressor

The engine builds a directed graph of the model: an edge \\a \to b\\ for
each regressor \\a\\ in \\b \sim a\\, an edge from each factor of a
product to the equation’s target, and \\\eta \to v\\ for each indicator
\\v\\ of a latent \\\eta\\. A product in the equation for \\t\\ is
refused when a factor is \\t\\ itself or a descendant of \\t\\:

``` r
rule8 <- c(
  `the target itself` = say(fit_sem("outcome ~ treatment + treatment:outcome", d)),
  `a descendant` = say(fit_sem("mediator1 ~ treatment\noutcome ~ mediator1\nmediator1 ~ treatment:outcome", d))
)
cat(sprintf("%s:\n  %s\n", names(rule8), rule8), sep = "\n")
```

    the target itself:
      In the equation for 'outcome', the product 'outcome:treatment' uses 'outcome', which is the target of its own equation (rule 8: no outcome-derived regressors).

    a descendant:
      In the equation for 'mediator1', the product 'outcome:treatment' uses 'outcome', which is downstream of the target 'mediator1' (rule 8: no outcome-derived regressors).

Such a regressor is a function of the equation’s error, so it is
correlated with it, and Step 3’s least squares is then inconsistent; no
standard error repairs that. A worked case: \\y = 0.3x + e\\ with \\x
\sim N(2, 1)\\ and \\e \sim N(0, 1)\\ independent, and the regression
\\y \sim x + x\\y\\. The true coefficient of \\x\\y\\ is 0, but
\\\operatorname{Cov}(x\\y, e) = \operatorname{Cov}(0.3x^2 + x\\e, e) =
E\[x\]\operatorname{Var}(e) = 2\\:

``` r
set.seed(17)
x8 <- rnorm(20000, 2)
e8 <- rnorm(20000)
y8 <- 0.3 * x8 + e8
xy8 <- x8 * y8
c(coefficient_of_x = coef(lm(y8 ~ x8 + xy8))[["x8"]], true_value = 0.3,
  coefficient_of_xy = coef(lm(y8 ~ x8 + xy8))[["xy8"]], cov_xy_e = cov(xy8, e8))
```

     coefficient_of_x        true_value coefficient_of_xy          cov_xy_e
           -0.1633402         0.3000000         0.3826317         2.0210726 

The least-squares coefficient of \\x\\ is far from 0.3 at \\n = 20000\\:
the bias does not shrink with the sample.

### Rule 9, recursion

The factorization of Step 1 follows the order of a recursive model. In a
model with a loop (\\m_2 \sim m_1\\ and \\m_1 \sim m_2\\) no such order
exists: the density of the endogenous block carries the Jacobian term
\\\log\|I - A\|\\ of the system (from the change of variables \\y = (I -
A)^{-1}(m + e)\\), which involves the coefficients of both equations, so
the log likelihood no longer splits by equation. In a recursive model
the variables can be ordered so that \\A\\ is strictly triangular,
\\\|I - A\| = 1\\, and the term vanishes; that is the step Step 1 relies
on. The engine refuses a loop anywhere in a product model:

``` r
loop_model <- "mediator1 ~ treatment + mediator2\nmediator2 ~ mediator1\noutcome ~ mediator1 + treatment:covariate1"
loop_error <- say(fit_sem(loop_model, d))
cat(loop_error)
```

    The model is not recursive: 'mediator2' is part of a loop of regressions (rule 9). This is not yet supported with products; it works without the product.

### Rule 9, residual covariances

With a free residual covariance between \\e\_{m_1}\\ and \\e\_{m_2}\\,
the two equations share a parameter and Step 2 fails: the joint maximum
likelihood estimator is then seemingly unrelated regression (SUR, a
generalized least squares estimator), which equals equation-wise least
squares only when the regressor sets are identical (with nested sets
only the equation with the smaller set keeps its least-squares
estimates). The gate `tests/sim/product-correlated-residuals.R` measures
the gap. One of its replications (the gate’s first seed, \\n = 500\\,
residual correlation 0.8), with the product as a precomputed column:

``` r
set.seed(18)
n9 <- 500
x9 <- rnorm(n9, 2)
cv <- rnorm(n9)
c2 <- rnorm(n9)
z9 <- matrix(rnorm(2 * n9), n9, 2) %*% chol(matrix(c(1, 0.8, 0.8, 1), 2))
m1 <- 0.7 * x9 + 0.5 * cv + z9[, 1]
m2 <- 0.5 * x9 + 0.5 * c2 + z9[, 2]
p <- x9 * m1
y9 <- 0.4 * m1 + 0.3 * m2 + 0.3 * x9 + 0.2 * p + rnorm(n9)
d9 <- data.frame(x = x9, cv, c2, m1, m2, y = y9, p)
sur_gap <- function(m2_rhs, residual_cov) {
  syn <- paste0("m1 ~ x + cv\nm2 ~ ", m2_rhs, "\ny ~ m1 + m2 + x + p", if (residual_cov) "\nm1 ~~ m2" else "")
  f <- quiet(fit_sem(syn, d9))
  m2_formula <- reformulate(strsplit(m2_rhs, " + ", fixed = TRUE)[[1]], "m2")
  ols <- c(coef(lm(m1 ~ x + cv, d9))[["x"]], coef(lm(m2_formula, d9))[["x"]],
           coef(lm(y ~ m1 + m2 + x + p, d9))[c("m1", "m2", "p")])
  max(abs(coef(f)[c("m1~x", "m2~x", "y~m1", "y~m2", "y~p")] - ols))
}
sur <- data.frame(
  regressors = c("identical", "identical", "non-nested", "non-nested", "nested"),
  residual_covariance = c("fixed at 0", "free", "fixed at 0", "free", "free"),
  largest_gap_to_least_squares = signif(c(sur_gap("x + cv", FALSE), sur_gap("x + cv", TRUE),
                                          sur_gap("x + c2", FALSE), sur_gap("x + c2", TRUE),
                                          sur_gap("x + cv + c2", TRUE)), 2)
)
sur
```

      regressors residual_covariance largest_gap_to_least_squares
    1  identical          fixed at 0                      2.3e-08
    2  identical                free                      4.4e-08
    3 non-nested          fixed at 0                      4.2e-07
    4 non-nested                free                      1.9e-03
    5     nested                free                      4.2e-04

Only the rows with a free residual covariance and different regressor
sets depart from least squares (in the nested row, `m2 ~ x + cv + c2`
contains the regressors of `m1`, and the larger equation moves). Over
the gate’s 10 seeds the departure is between \\10^{-4}\\ and \\2.8
\times 10^{-3}\\ in every seed, and the match rows stay below \\5.2
\times 10^{-7}\\ (`tests/sim/gates.csv`, row `product-corr`, run of
2026-10-14). Small, but not zero, and one design is not a proof, so the
product model refuses the covariance. Written with `x:m1`, the same
model stops:

``` r
sur_refused <- say(fit_sem("m1 ~ x + cv\nm2 ~ x + c2\ny ~ m1 + m2 + x + x:m1\nm1 ~~ m2", d9[setdiff(names(d9), "p")]))
cat(sur_refused)
```

    A product model cannot have a residual covariance (rule 9): 'm1 ~~ m2' relates two outcomes. This is not yet supported with products; it works without the product.

**The note.** *Completion* is the step in which the engine adds the rows
the user did not write (`.sem_complete()`): residual variances, the
variances, covariances and means of the exogenous variables, and a free
residual covariance between each pair of outcomes that no equation uses
as a predictor (lavaan does the same). In a product model that row would
be a residual covariance, so completion fixes it at 0 and says so once
(a design decision of 0.10.0). The same model without the product
estimates it:

``` r
h6 <- "mediator1 ~ treatment\noutcome ~ mediator1 + treatment + treatment:mediator1\nmediator2 ~ covariate1"
h6_message <- tryCatch(suppressWarnings(fit_sem(h6, d)), message = function(m) conditionMessage(m))
cat(h6_message)
```

    This model has a product term, so the residual covariance between outcomes (outcome ~~ mediator2) is fixed at 0 (rule 9: products need no residual covariances). The same model without the product estimates it.

``` r
h6_fit <- quiet(fit_sem(h6, d))
twin <- quiet(fit_sem(sub(" + treatment:mediator1", "", h6, fixed = TRUE), d, meanstructure = TRUE))
row_of <- function(f) {
  f@table[f@table$lhs == "outcome" & f@table$rhs == "mediator2", c("lhs", "op", "rhs", "free", "est")]
}
rbind(product_model = row_of(h6_fit), without_the_product = row_of(twin))
```

                            lhs op       rhs  free      est
    product_model       outcome ~~ mediator2 FALSE 0.000000
    without_the_product outcome ~~ mediator2  TRUE 0.270462

### Rule 9, shared, fixed and constrained coefficients

A label on two regression rows makes the two coefficients one parameter;
a fixed coefficient or a constraint (`==`, `<`, `>`, or a bound) takes a
coefficient out of its equation’s free set. In each case Step 2 fails:
the parameters of the equations are no longer disjoint, or an equation’s
coefficients are no longer free, and the maximizer is no longer least
squares. With the product as a column, the label `a` on the path from
the covariate in the mediator equation and on the path from the
treatment in the outcome equation gives one compromise value that is
neither equation’s least-squares coefficient:

``` r
d_col <- d
d_col$p <- d$treatment * d$mediator1
shared_model <- "mediator1 ~ treatment + a*covariate1\noutcome_int ~ mediator1 + a*treatment + p + covariate1"
shared_fit <- quiet(fit_sem(shared_model, d_col))
c(shared_a = coef(shared_fit)[["a"]], least_squares_mediator1_on_covariate1 = coef(lm_m)[["covariate1"]],
  least_squares_outcome_on_treatment = coef(lm_y)[["treatment"]])
```

                                 shared_a least_squares_mediator1_on_covariate1
                                0.4129924                             0.4481488
       least_squares_outcome_on_treatment
                                0.2121851 

``` r
rule9 <- c(
  `shared label` = say(fit_sem("mediator1 ~ a*treatment\noutcome ~ a*mediator1 + treatment:mediator1", d)),
  `fixed coefficient` = say(fit_sem("mediator1 ~ 0.5*treatment\noutcome ~ mediator1 + treatment:mediator1", d)),
  `constraint` = say(fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment:mediator1\na == b", d)),
  `bound` = say(fit_sem("mediator1 ~ lower(0)*treatment\noutcome ~ mediator1 + treatment:mediator1", d))
)
cat(sprintf("%s:\n  %s\n", names(rule9), rule9), sep = "\n")
```

    shared label:
      The label 'a' is used on more than one parameter, a regression among them (rule 9). This is not yet supported with products; it works without the product.

    fixed coefficient:
      The regression 'mediator1 ~ treatment' has a fixed coefficient (rule 9). This is not yet supported with products; it works without the product.

    constraint:
      A constraint (==, < or >) names the coefficient label 'a' (rule 9). This is not yet supported with products; it works without the product.

    bound:
      The row 'mediator1 ~ treatment' has a bound (rule 9: coefficients and intercepts are unconstrained). This is not yet supported with products; it works without the product.

A defined parameter (`:=`) is allowed: it is a function of the estimates
and constrains nothing.

### Rule 9, the intercept clause

Intercepts must be free, unlabeled or uniquely labeled, and in no
constraint. A fixed intercept is a regression through a fixed point:
with `mediator1 ~ 0*1` the mediator equation becomes least squares
**without** an intercept, whose slopes differ from Step 3’s, and \\E\[M
\mid X = 0\] = \beta_0\\ is then imposed instead of estimated. With the
product as a column, the native fit matches
[`lm()`](https://rdrr.io/r/stats/lm.html) without an intercept, not with
one:

``` r
fixed_int_model <- "mediator1 ~ treatment + covariate1\nmediator1 ~ 0*1\noutcome_int ~ mediator1 + treatment + p"
fixed_int <- quiet(fit_sem(fixed_int_model, d_col))
c(native_slope = coef(fixed_int)[["mediator1~treatment"]],
  lm_without_intercept = coef(lm(mediator1 ~ 0 + treatment + covariate1, d))[["treatment"]],
  lm_with_intercept = coef(lm_m)[["treatment"]])
```

            native_slope lm_without_intercept    lm_with_intercept
               0.6665923            0.6665923            0.5814254 

``` r
intercept_rule <- c(
  `fixed intercept` = say(fit_sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment:mediator1\noutcome ~ 0*1",
                                  d)),
  `shared intercept label` = say(fit_sem("mediator1 ~ k*1 + treatment\noutcome ~ k*1 + mediator1 + treatment:mediator1",
                                         d))
)
cat(sprintf("%s:\n  %s\n", names(intercept_rule), intercept_rule), sep = "\n")
```

    fixed intercept:
      The intercept 'outcome ~ 1' is fixed (rule 9, intercept clause: intercepts must be free and unconstrained). This is not yet supported with products; it works without the product.

    shared intercept label:
      The intercept 'mediator1 ~ 1' shares the label 'k' with another row (rule 9, intercept clause: intercepts must be free and unshared). This is not yet supported with products; it works without the product.

**A known limit outside product models.** Without a product, an
intercept may share a label with a path, as in `mediator1 ~ a*1`
together with `mediator1 ~ a*treatment` (the intercept and the slope are
then one parameter). The engine fits this on `mediation_demo`, and
agrees with lavaan, but on the same data shifted far from zero (Chapter
2’s `mid` data: means of 100 to 300) it stops with “reduced Hessian is
not positive definite”, although the model has a well-defined optimum
that lavaan finds. The same restriction written as a constraint,
`mediator1 ~ k*1` with `k == a`, fits on both:

``` r
shared_int <- "
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
  mediator1 ~ a*1
"
as_constraint <- sub("mediator1 ~ a*1", "mediator1 ~ k*1\n  k == a", shared_int, fixed = TRUE)
base <- d[, c("treatment", "mediator1", "outcome")]
mid <- transform(base, treatment = treatment + 100, mediator1 = mediator1 + 100, outcome = outcome + 300)
fit_base <- fit_sem(shared_int, base)
mid_error <- say(fit_sem(shared_int, mid))
fit_mid_k <- fit_sem(as_constraint, mid)
c(base_a = coef(fit_base)[["a"]], base_chisq = fit_base@n_obs * fit_base@f,
  mid_a_via_k_eq_a = coef(fit_mid_k)[["a"]], mid_chisq_via_k_eq_a = fit_mid_k@n_obs * fit_mid_k@f)
```

                  base_a           base_chisq     mid_a_via_k_eq_a
               0.2757514            3.1028129            0.9889709
    mid_chisq_via_k_eq_a
              23.7982324 

``` r
cat(mid_error)
```

    no start converged (5 tried); best attempt: status 3, stationarity NA; reduced Hessian is not positive definite

``` r
lv_base <- lavaan::sem(shared_int, base, meanstructure = TRUE)
lv_mid <- lavaan::sem(shared_int, mid, meanstructure = TRUE)
c(lavaan_base_a = lavaan::coef(lv_base)[["a"]], lavaan_base_chisq = lavaan::fitMeasures(lv_base, "chisq"),
  lavaan_mid_a = lavaan::coef(lv_mid)[["a"]], lavaan_mid_chisq = lavaan::fitMeasures(lv_mid, "chisq"))
```

              lavaan_base_a lavaan_base_chisq.chisq            lavaan_mid_a
                  0.2757514               3.1028129               0.9889709
     lavaan_mid_chisq.chisq
                 23.7982324 

Where it goes wrong is visible in the centered coordinates of Chapter 2.
That chapter’s map \\\theta = T(\phi + c_0)\\ with \\T = I + C\\ relies
on \\C^2 = 0\\ (\\C\\ has nonzero rows only at intercepts and nonzero
columns only at paths, so \\T^{-1} = I - C\\). When an intercept and a
path are one parameter, \\C\\ has a nonzero **diagonal** entry, \\C^2
\neq 0\\, and the round trip \\\theta \to \phi \to \theta\\ through the
helper `.sem_to_phi()` (which applies \\I - C\\) no longer returns
\\\theta\\:

``` r
round_trip <- function(f) {
  r <- f@internals$ram
  ctr <- medfit:::.sem_center_map(r, medfit:::.sem_sample(f@data, r))
  c(diagonal_of_C = max(abs(diag(ctr$c))), C_squared = max(abs(ctr$c %*% ctr$c)),
    round_trip_error = max(abs(f@theta - ctr$t %*% (medfit:::.sem_to_phi(f@theta, ctr) + ctr$c0))))
}
rbind(shared_label = round_trip(fit_base),
      separate_labels = round_trip(fit_sem(sub("a*1", "k*1", shared_int, fixed = TRUE), base)))
```

                    diagonal_of_C C_squared round_trip_error
    shared_label           0.5025 0.2525062       0.06962896
    separate_labels        0.0000 0.0000000       0.00000000

The engine already refuses the shift of Chapter 2 for this model, but
its acceptance gate (Chapter 3) still works in the centered coordinates;
which step of the gate then fails on the shifted data has not been
traced. Until it is, write such a restriction as a constraint
(`k == a`). A product model refuses the shared label anyway (the
intercept clause above).

## 5. Inference

### Observed, not expected, information

The covariance of the estimates comes from the information (Chapter 5).
By Steps 1 and 2 the Hessian of \\\ell\\ is block diagonal across
\\\eta\\, \\\psi_m\\ and \\\psi_y\\ for any data, so the standard errors
of the outcome equation come from the \\\psi_y\\ block alone.
Differentiate \\\ell_y\\ twice in the coefficients \\\kappa = (\theta_0,
\theta_2, \theta_1, \delta, \theta_3)\\ with regressor vector \\r_i =
(1, m_i, x_i, c_i, p_i)\\:

\\ -\frac{\partial^2 \ell_y}{\partial\kappa\\\partial\kappa^\top} =
\frac{1}{\sigma^2_y}\sum_i r_i r_i^\top, \qquad -\frac{\partial^2
\ell_y}{\partial\kappa\\\partial\sigma^2_y} = \frac{1}{\sigma^4_y}\sum_i
r_i e\_{y,i} . \\

The cross term is zero at the least-squares solution (the residuals are
orthogonal to every regressor). So

- the **observed** information is \\\frac{n}{\hat\sigma^2_y} \cdot
  \frac1n \sum_i r_i r_i^\top\\, the sample second moments, and its
  inverse is the least-squares covariance at the ML scale,
  \\\hat\sigma^2_y (R^\top R)^{-1}\\ with \\\hat\sigma^2_y =
  \text{RSS}/n\\;
- the **expected** information replaces \\\frac1n \sum_i r_i r_i^\top\\
  by its expectation **under the model**, \\E\_{\text{model}}\[r
  r^\top\] = \Sigma_r + \mu_r \mu_r^\top\\ with the implied \\\Sigma\\
  and \\\mu\\.

The two agree when the implied moments of \\r\\ equal the sample ones.
With an endogenous factor they do not: the \\(m, p)\\ entry is the
misfit of Section 3. Compute both by hand and compare with the engine’s
matrices, `.sem_info_observed()` and `.sem_info_expected()` (the fit
refuses `information = "expected"`, so the expected matrix is built from
the observed fit, as in Chapter 5):

``` r
theta <- fit_free@theta
info_o <- medfit:::.sem_info_observed(theta, ram, smp, NULL)
info_e <- medfit:::.sem_info_expected(theta, ram, smp, NULL)
y_par <- c("outcome_int~1", "outcome_int~mediator1", "outcome_int~treatment", "outcome_int~covariate1",
           "outcome_int~mediator1:treatment")
z_var <- c("mediator1", "treatment", "covariate1", "mediator1:treatment")
s2_y <- cf[["outcome_int~~outcome_int"]]
z_mat <- cbind(1, as.matrix(mat$data[, z_var]))
mu <- medfit:::.sem_implied_mean(ram, theta)[z_var]
second_moments_model <- rbind(c(1, mu), cbind(mu, sigma_hat[z_var, z_var] + tcrossprod(mu)))
se_table <- data.frame(
  term = y_par,
  observed_by_hand = sqrt(diag(s2_y * solve(crossprod(z_mat)))),
  observed_engine = sqrt(diag(solve(info_o)))[y_par],
  least_squares_ml_scale = sqrt(diag(vcov(lm_y) * (n - 5) / n))[c(1, 2, 3, 5, 4)],
  expected_by_hand = sqrt(diag(s2_y / n * solve(second_moments_model))),
  expected_engine = sqrt(diag(solve(info_e)))[y_par],
  row.names = NULL
)
se_table[-1] <- signif(se_table[-1], 5)
se_table
```

                                 term observed_by_hand observed_engine
    1                   outcome_int~1         0.074471        0.074471
    2           outcome_int~mediator1         0.072490        0.072490
    3           outcome_int~treatment         0.115170        0.115170
    4          outcome_int~covariate1         0.056575        0.056575
    5 outcome_int~mediator1:treatment         0.096418        0.096418
      least_squares_ml_scale expected_by_hand expected_engine
    1               0.074471         0.074095        0.074095
    2               0.072490         0.053062        0.053062
    3               0.115170         0.119200        0.119200
    4               0.056575         0.059226        0.059226
    5               0.096418         0.070576        0.070576

``` r
c(sample_E_m_p = mean(d$mediator1 * d$treatment * d$mediator1),
  model_E_m_p = second_moments_model[2, 5])
```

    sample_E_m_p  model_E_m_p
       0.7903590    0.3019063 

The observed information reproduces least squares; the expected
information gives other standard errors, because it uses the model’s
value of \\E\[m\\p\]\\, which the data contradict. The engine therefore
refuses `information = "expected"` whenever a factor of a product is
endogenous:

``` r
expected_error <- say(fit_sem(product_model, d, information = "expected"))
cat(expected_error)
```

    `information = "expected"` is not available for a model with a product of an endogenous variable (the product 'mediator1:treatment' has an endogenous factor ('mediator1')): the expected information assumes the product is not a function of the other variables, so its standard errors are wrong, the sandwich ones included. Use `information = "observed"` (the default) with `se_type = "sandwich"`.

### The sandwich

The product is not normal even when its factors are, so the model-based
standard errors lean on an assumption the data cannot meet; the fit
warns and recommends `se_type = "sandwich"`. With the observed
information as bread, the sandwich of Chapter 5 is \\A^{-1} B A^{-1}\\
with \\A\\ block diagonal across equations. Its coefficient block for
the outcome equation is \\(R^\top R)^{-1} \bigl(\sum_i e\_{y,i}^2 r_i
r_i^\top\bigr) (R^\top R)^{-1}\\, which is the HC0
heteroskedasticity-consistent covariance of
[`lm()`](https://rdrr.io/r/stats/lm.html) (the cross term with
\\\sigma^2_y\\ in \\A\\ is zero, as above). With the expected
information as bread the block is something else, which is why the
refusal covers the sandwich too:

``` r
fit_sw <- quiet(fit_sem(product_model, d, se_type = "sandwich"))
meat <- crossprod(medfit:::.sem_scores(theta, ram, smp))
expected_bread <- solve(info_e)
sw_table <- data.frame(
  term = y_par,
  native_sandwich = sqrt(diag(fit_sw@vcov))[y_par],
  lm_hc0 = sqrt(diag(sandwich::vcovHC(lm_y, type = "HC0")))[c(1, 2, 3, 5, 4)],
  expected_bread_sandwich = sqrt(diag(expected_bread %*% meat %*% expected_bread))[y_par],
  row.names = NULL
)
sw_table[-1] <- signif(sw_table[-1], 5)
sw_table
```

                                 term native_sandwich   lm_hc0
    1                   outcome_int~1        0.070883 0.070883
    2           outcome_int~mediator1        0.071734 0.071734
    3           outcome_int~treatment        0.118520 0.118520
    4          outcome_int~covariate1        0.056953 0.056953
    5 outcome_int~mediator1:treatment        0.097474 0.097474
      expected_bread_sandwich
    1                0.071324
    2                0.056904
    3                0.136530
    4                0.067129
    5                0.077082

### The model test

The global chi-square \\n \hat F\_{ML}\\ tests every restriction of the
joint model at once, and with an endogenous factor one of those
restrictions, \\\operatorname{Cov}(e_m, p) = 0\\, is false by
construction. The test then rejects whenever the sample is large enough,
although both regressions are right; a likelihood-ratio difference
between two such models
([`anova()`](https://rdrr.io/r/stats/anova.html)) and the MBCO test of
Chapter 5
([`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md))
inherit the same false restriction. The engine records the verdict when
it fits (`.sem_product_modeltest()`), warns once, reports the
chi-square, df and p-value as `NA`, and refuses both tests:

``` r
labeled <- "
  mediator1 ~ a*treatment + covariate1
  outcome_int ~ b*mediator1 + treatment + treatment:mediator1 + covariate1
"
fit_lab <- quiet(fit_sem(labeled, d, se_type = "sandwich"))
glance(fit_lab)[, c("nobs", "npar", "df", "chisq", "p_value", "logLik")]
```

    # A tibble: 1 × 6
       nobs  npar    df chisq p_value logLik
      <int> <int> <dbl> <dbl>   <dbl>  <dbl>
    1   400    19    NA    NA      NA -2446.

``` r
fit_lab_restricted <- quiet(fit_sem(sub(" + covariate1\n  outcome", "\n  outcome", labeled, fixed = TRUE), d,
                                    se_type = "sandwich"))
refusals <- c(anova = say(anova(fit_lab_restricted, fit_lab)), mbco_sem = say(mbco_sem(fit_lab, "a", "b")))
cat(sprintf("%s:\n  %s\n", names(refusals), refusals), sep = "\n")
```

    anova:
      anova() is not available for 'fit_lab_restricted', a model with a product term: the product 'mediator1:treatment' has an endogenous factor ('mediator1'). The model test and a likelihood-ratio contrast against another fit are not chi-square there. The coefficients and the sandwich standard errors (`se_type = "sandwich"`, observed information) are unaffected.

    mbco_sem:
      mbco_sem() is not available for a model with a product term: the product 'mediator1:treatment' has an endogenous factor ('mediator1'). The model test and a likelihood-ratio contrast against another fit are not chi-square there. The coefficients and the sandwich standard errors (`se_type = "sandwich"`, observed information) are unaffected.

``` r
c(chisq_it_would_report = medfit:::.sem_chisq(fit_lab), df = fit_lab@df)
```

    chisq_it_would_report                    df
                 249.5948                1.0000 

(`.sem_chisq()` is the internal accessor that bypasses the `NA`; it is
shown here only to make the point: the number is far in the tail of
\\\chi^2\\ on 1 df.)

The test is not refused for every product. When both factors are
exogenous and the exogenous block is free (no statement on any exogenous
variance or covariance), the model makes no false restriction, and
asymptotic-robustness theory (Browne and Shapiro 1988; Satorra and
Bentler 1990) says the normal-theory test stays calibrated although the
product is not normal, provided the errors are independent of the
exogenous variables and the exogenous moments are free parameters. The
engine reports it. In this model the one restriction is the missing path
from the product `treatment:covariate1` to the mediator, so the test
(df 1) is a test of that path:

``` r
exo_model <- "
  mediator1 ~ treatment + covariate1
  outcome ~ mediator1 + treatment + covariate1 + treatment:covariate1
"
exo_fit <- quiet(fit_sem(exo_model, d))
glance(exo_fit)[, c("df", "chisq", "p_value")]
```

    # A tibble: 1 × 3
         df chisq p_value
      <dbl> <dbl>   <dbl>
    1     1 0.974   0.324

``` r
restricted_fit <- quiet(fit_sem(paste0(exo_model, "covariate1 ~~ 1*covariate1\n"), d))
cat(medfit:::.sem_modeltest_text(restricted_fit@internals$ram$modeltest))
```

    the exogenous (co)variance 'treatment ~~ covariate1' is missing (the pairing rule leaves a covariance out once either variable has a '~~' statement)

The second fit fixes the variance of `covariate1` at 1. That is a `~~`
statement on an exogenous variable, so the engine’s pairing rule
(completion, which follows lavaan with `fixed.x = FALSE`) no longer
pairs `covariate1` with the other exogenous variables, and their
covariances, the product’s included, are silently fixed at 0; the
verdict names the first restriction it finds. A restriction anywhere in
the exogenous block (a fixed, labeled or bounded variance or covariance,
or a missing covariance) restricts the moments of a non-normal variable,
whose normal-theory test is not calibrated, so the test is reported as
`NA` there too.

### The null simulation

“Stays calibrated” is a claim that can fail, so the gate
`tests/sim/exo-product-null-colon.R` tests it: the true model \\m =
0.7x + e\\, \\y = 0.4m + 0.3x + 0.3w + 0.2x\\w + e'\\ is fitted as
`m ~ x; y ~ m + x + w + x:w` (df 2, \\n = 500\\, 1000 replications,
factors normal or centered exponential, a skewed distribution with
kurtosis 9). Under a calibrated test about 5% of the replications reject
at the 0.05 level. The **planted defect** fits the product \\x\\m\\
instead, an endogenous factor, where the test must not be calibrated.
The code below is the gate’s generator, run here with the same seeds:

``` r
gate_chisq <- function(seed, xdist, endogenous = FALSE, n = 500) {
  set.seed(seed)
  if (xdist == "norm") {
    x <- rnorm(n)
    w <- rnorm(n)
  } else {
    x <- rexp(n) - 1
    w <- rexp(n) - 1
  }
  m <- 0.7 * x + rnorm(n)
  y <- 0.4 * m + 0.3 * x + 0.3 * w + 0.2 * (x * w) + rnorm(n)
  term <- if (endogenous) "x:m" else "x:w"
  tryCatch({
    f <- suppressWarnings(fit_sem(paste0("m ~ x\ny ~ m + x + w + ", term), data.frame(x, w, m, y)))
    c(medfit:::.sem_chisq(f), f@df)
  }, error = function(e) c(NA_real_, NA_real_))
}
cores <- if (.Platform$OS.type == "windows") 1L else min(2L, parallel::detectCores())
null_cell <- function(xdist, endogenous) {
  r <- do.call(rbind, parallel::mclapply(1:1000, gate_chisq, xdist = xdist, endogenous = endogenous, mc.cores = cores))
  p_val <- pchisq(r[, 1], r[1, 2], lower.tail = FALSE)
  data.frame(factors = xdist, product = if (endogenous) "x:m (endogenous)" else "x:w (exogenous)", df = r[1, 2],
             fitted = sum(!is.na(r[, 1])), reject_05 = mean(p_val < 0.05), mean_chisq = round(mean(r[, 1]), 3))
}
null_sim <- rbind(null_cell("norm", FALSE), null_cell("exp", FALSE), null_cell("norm", TRUE), null_cell("exp", TRUE))
null_sim
```

      factors          product df fitted reject_05 mean_chisq
    1    norm  x:w (exogenous)  2   1000     0.055      2.002
    2     exp  x:w (exogenous)  2   1000     0.056      2.048
    3    norm x:m (endogenous)  2   1000     0.147      3.059
    4     exp x:m (endogenous)  2   1000     0.126      2.919

The exogenous product rejects 5.5% and 5.6% of the time, within the
gate’s band of \\0.05 \pm 0.02\\ (the Monte Carlo standard error of a
rate near 0.05 over 1000 replications is 0.007), with a mean chi-square
near its df of 2. The endogenous product rejects two to three times as
often at the same sample size, although its regressions are correct.
These are the gate’s recorded values (`tests/sim/gates.csv`, row
`product-null-colon`, run of 2026-10-14). The companion gate
`tests/sim/exo-product-fixed-var.R` runs the same design with a
restricted exogenous block (variances fixed, or covariances dropped by
the pairing rule) and records rejection rates far above 0.05 there,
which is why a restricted exogenous block also reports `NA`.

## Summary

| Question | Answer | The check on this page |
|----|----|----|
| What does `x:m` mean? | the column \\x\\m\\, under the canonical name `m:x` (C-locale order) | the parsed table; the duplicate refused |
| When is the column built? | before `fixed_x` and listwise deletion; a user’s column is compared after deletion | the unassigned fixed rows; a column differing on a dropped row accepted |
| What is it in the likelihood? | an exogenous observed variable with free moments | its zero row of \\A\\ and its five parameters |
| Why are the paths least squares? | the density factors by equation with disjoint parameters (rules 8 and 9) | [`lm()`](https://rdrr.io/r/stats/lm.html) equation by equation |
| What breaks outside the class? | an outcome-derived regressor is biased; a residual covariance gives SUR; shared or fixed coefficients tie equations | the \\x\\y\\ regression; the SUR gap; the shared-label compromise |
| Which information? | observed (least squares); expected uses the false implied \\E\[m\\p\]\\ | both rebuilt by hand; the sandwich equals HC0 |
| The model test? | `NA` with an endogenous factor or a restricted exogenous block; reported otherwise | the null simulation with its planted defect |

## Check yourself

1.  In `y ~ x + m + x:m` with `m ~ x`, which factor of the product makes
    the model test invalid, and why does the same problem not arise for
    `y ~ x + w + x:w` with `w` a covariate? (Answer: `m`, because it is
    a regression target, so \\p\\ contains its error while the model
    sets \\\operatorname{Cov}(e_m, p) = 0\\. A product of two exogenous
    variables contains no error of the model.)
2.  Section 3’s proof never used that \\p = x\\m\\. Where would it fail
    if \\p\\ were built from the **outcome** \\y\\? (Answer: nowhere in
    the algebra, which is why rule 8 is needed: the factorization still
    gives least squares, but least squares of \\y\\ on a function of
    \\y\\ is inconsistent, as the \\x\\y\\ example showed.)
3.  Why may a product appear in two equations but not twice in one?
    (Answer: in one equation the two columns would be identical, so the
    sample covariance is singular; in two equations each coefficient is
    a separate free parameter that reads the same column.)
4.  The observed and expected information agree for the just-identified
    mediation model of Chapter 5. Why do they not agree here, although
    the regressions are right? (Answer: the expected information uses
    the model’s \\E\[r r^\top\]\\, and the model’s \\E\[m\\p\]\\ is
    wrong, since the joint model misfits exactly at \\(m, p)\\.)

## References

Browne, M. W., & Shapiro, A. (1988). Robustness of normal theory methods
in the analysis of linear latent variate models. *British Journal of
Mathematical and Statistical Psychology*, 41, 193-208.

Satorra, A., & Bentler, P. M. (1990). Model conditions for asymptotic
robustness in the analysis of linear relations. *Computational
Statistics & Data Analysis*, 10, 235-249.

## Where next

[Chapter
7](https://data-wise.github.io/medfit/articles/native-book-7-four-way.md)
uses the product to split the total effect of a binary treatment into
four parts, derives each part and its standard error, and checks them
against lavaan and a hand computation.
