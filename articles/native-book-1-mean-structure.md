# Native engine book, chapter 1: the mean structure

This is the first of five chapters that open the native engine and show
every matrix it works with. The engine is experimental. The chapters, in
order:

1.  **The mean structure** (this chapter): the RAM form, the implied
    means, the discrepancy and its gradient, and the moment count.
2.  [Scale and
    conditioning](https://data-wise.github.io/medfit/articles/native-book-2-scale.md):
    why the engine fits in centered coordinates and when it may shift
    the data.
3.  [Constrained
    estimation](https://data-wise.github.io/medfit/articles/native-book-3-constraints.md):
    constraint rows, the solver, the acceptance gate and the Newton
    polish.
4.  [Fixed exogenous
    variables](https://data-wise.github.io/medfit/articles/native-book-4-fixed-x.md):
    `fixed_x`, the conditional likelihood and the comparison refusals.
5.  [Inference](https://data-wise.github.io/medfit/articles/native-book-5-inference.md):
    information, the sandwich, MBCO and
    [`anova()`](https://rdrr.io/r/stats/anova.html).

Each chapter fits real models to the bundled `mediation_demo` data,
prints the matrices the engine builds, derives the formulas that produce
them, and checks the numbers against lavaan and OpenMx. Each chapter
runs on its own.

|  |  |
|----|----|
| **You need** | medfit 0.9.0 or later; matrix algebra and the normal likelihood at the level of a first course in multivariate statistics |
| **You get** | the RAM matrices of a fitted model, the implied mean and covariance computed by hand, the discrepancy and its gradient derived and checked, and the moment and degrees-of-freedom count |
| **Time** | about 40 minutes |

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
f3 <- function(x) formatC(x, format = "f", digits = 3)
f4 <- function(x) formatC(x, format = "f", digits = 4)
mx <- function(x, d = 4) round(x, d)
```

## 1. The model

We use the smallest mediation model: a treatment, one mediator and an
outcome. Two lines of syntax write the paths, and two more write the
intercepts. An **intercept statement** (`y ~ 1`) turns on the mean
structure: the model then describes the means of the observed variables
as well as their covariances. Every observed intercept the text does not
write is added and left free, so one intercept line would be enough; the
second only makes the model explicit.

``` r
syntax <- "
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
  mediator1 ~ 1
  outcome ~ 1
"
fit <- fit_sem(syntax, mediation_demo)
ram <- fit@internals$ram
theta <- fit@theta
n <- fit@n_obs
round(theta, 4)
```

                       a                    b                   cp
                  0.4560               0.7134               0.0406
    mediator1~~mediator1     outcome~~outcome treatment~~treatment
                  1.1585               1.1804               0.2500
             mediator1~1            outcome~1          treatment~1
                  0.1552               0.2311               0.5025 

`theta` is the **parameter vector**: the free parameters in the order
the engine keeps them. There are 9 of them: three paths, three variances
and three intercepts. `treatment` is **exogenous**: no path in the model
points to it, so its own mean and variance are parameters, and its
“intercept” is its mean. The engine also keeps the model as a **RAM
specification** (`fit@internals$ram`), which the next section opens.

## 2. The RAM form: A, S, F and m

RAM stands for reticular action model. It writes every structural
equation model with four matrices. Put all the variables of the model,
observed and latent, in one vector \\v\\ of length \\n_v\\. Then the
model says

\\ v = A\\v + m + e, \qquad \operatorname{E}(e) = 0, \quad
\operatorname{Cov}(e) = S\_{\text{ram}} . \\

The pieces are:

- \\A\\, the **path matrix** (\\n_v \times n_v\\). Entry \\A\_{r c}\\ is
  the effect of variable \\c\\ on variable \\r\\: a one-headed arrow
  from \\c\\ to \\r\\.
- \\m\\, the **intercept vector** (length \\n_v\\). Entry \\m_r\\ is the
  intercept of variable \\r\\’s equation. An exogenous variable’s
  equation is just its mean, so its intercept is its mean.
- \\S\_{\text{ram}}\\, the **covariance matrix of the errors** (\\n_v
  \times n_v\\). Its diagonal holds the residual variances (or, for an
  exogenous variable, its variance); an off-diagonal entry is a
  two-headed arrow.
- \\F\\, the **selection matrix** (\\p \times n_v\\, with \\p\\ the
  number of observed variables). Each row has one 1 and picks one
  observed variable out of \\v\\.

We read the real matrices of our fit. The helper `.sem_ram_mats()`
builds \\A\\ and \\S\_{\text{ram}}\\ from the parameter vector (it puts
each free parameter where the specification says), and `.sem_ram_m()`
builds \\m\\:

``` r
mats <- medfit:::.sem_ram_mats(ram, theta)
A <- mats$a
Sram <- mats$s
m <- medfit:::.sem_ram_m(ram, theta)
Fsel <- diag(ram$nv)[ram$obs_idx, , drop = FALSE]
dimnames(A) <- dimnames(Sram) <- list(ram$vars, ram$vars)
names(m) <- ram$vars
dimnames(Fsel) <- list(ram$obs, ram$vars)
cat("A (row = target, column = source)\n")
```

    A (row = target, column = source)

``` r
mx(A)
```

              mediator1 treatment outcome
    mediator1    0.0000    0.4560       0
    treatment    0.0000    0.0000       0
    outcome      0.7134    0.0406       0

``` r
cat("\nS_ram\n")
```


    S_ram

``` r
mx(Sram)
```

              mediator1 treatment outcome
    mediator1    1.1585      0.00  0.0000
    treatment    0.0000      0.25  0.0000
    outcome      0.0000      0.00  1.1804

``` r
cat("\nm\n")
```


    m

``` r
mx(m)
```

    mediator1 treatment   outcome
       0.1552    0.5025    0.2311 

``` r
cat("\nF\n")
```


    F

``` r
Fsel
```

              mediator1 treatment outcome
    mediator1         1         0       0
    treatment         0         1       0
    outcome           0         0       1

Read \\A\\ one row at a time. The row `mediator1` has 0.4560 in the
`treatment` column: that is the path \\a\\. The row `outcome` holds
\\b\\ = 0.7134 and \\c'\\ = 0.0406. Every other entry is a structural
zero, a path the model does not have. In \\S\_{\text{ram}}\\ the
diagonal is the two residual variances and the variance of `treatment`;
the off-diagonal entries are zero because the model has no correlated
errors.

Here every variable is observed, so \\F\\ is the identity and does
nothing. It earns its place when the model has a latent variable, which
sits in \\v\\ but not in the data. A mediator measured by two indicators
shows it:

``` r
latent <- fit_sem("
  M =~ mediator1 + mediator2
  M ~ a * treatment
  outcome ~ b * M + treatment
", mediation_demo, meanstructure = TRUE)
rl <- latent@internals$ram
Fl <- diag(rl$nv)[rl$obs_idx, , drop = FALSE]
dimnames(Fl) <- list(rl$obs, rl$vars)
Fl
```

              mediator1 mediator2 treatment outcome M
    mediator1         1         0         0       0 0
    mediator2         0         1         0       0 0
    treatment         0         0         1       0 0
    outcome           0         0         0       1 0

\\F\\ has four rows (the four observed variables) and five columns
(those four plus the latent `M`); the `M` column is all zeros. From now
on we return to the observed model, where \\F = I\\.

## 3. The implied mean and covariance

A fitted model is a claim about the **moments** of the observed
variables: their means \\\mu\\ and covariance matrix \\\Sigma\\. We
derive both from the RAM equation.

**Step 1: solve for \\v\\.** Move \\A v\\ to the left: \\(I - A)v = m +
e\\. The matrix \\I - A\\ is invertible when the model has no feedback
loop. The engine gives a parameter vector that makes it singular (or
that makes the implied covariance not positive definite) a large finite
discrepancy, so the optimizer steps back from it. Write \\B = (I -
A)^{-1}\\, so

\\ v = B\\(m + e). \\

**Step 2: take the expectation.** \\B\\ and \\m\\ are constants and
\\\operatorname{E}(e) = 0\\, so \\\operatorname{E}(v) = B\\m\\.

**Step 3: take the covariance.** \\\operatorname{Cov}(v) = B
\operatorname{Cov}(e) B^\top = B\\S\_{\text{ram}}\\B^\top\\, because
\\\operatorname{Cov}(M x) = M \operatorname{Cov}(x) M^\top\\ for a
constant matrix \\M\\ and the constant \\m\\ adds nothing to a
covariance.

**Step 4: select the observed variables.** The data contain only the
observed rows of \\v\\, which is what multiplying by \\F\\ does:

\\ \mu(\theta) = F\\(I - A)^{-1} m, \qquad \Sigma(\theta) = F\\(I -
A)^{-1} S\_{\text{ram}} (I - A)^{-\top} F^\top . \\

Now push the numbers through. First \\B\\:

``` r
B <- solve(diag(ram$nv) - A)
mx(B)
```

              mediator1 treatment outcome
    mediator1    1.0000    0.4560       0
    treatment    0.0000    1.0000       0
    outcome      0.7134    0.3659       1

Column `treatment` of \\B\\ reads: a one-unit change in `treatment`
moves `mediator1` by \\a\\ = 0.4560 and `outcome` by \\a b + c'\\ =
0.3659. That is the total effect, the sum of the indirect path \\a b\\ =
0.3253 and the direct path. \\B\\ collects every path from one variable
to another.

``` r
mu <- drop(Fsel %*% B %*% m)
Sigma <- Fsel %*% B %*% Sram %*% t(B) %*% t(Fsel)
cat("mu\n")
```

    mu

``` r
mx(mu)
```

    mediator1 treatment   outcome
       0.3843    0.5025    0.5257 

``` r
cat("\nSigma\n")
```


    Sigma

``` r
mx(Sigma)
```

              mediator1 treatment outcome
    mediator1    1.2105    0.1140  0.8682
    treatment    0.1140    0.2500  0.0915
    outcome      0.8682    0.0915  1.8036

``` r
# the engine's own helpers, and the largest absolute difference from the hand computation
c(
  mean = max(abs(medfit:::.sem_implied_mean(ram, theta) - mu)),
  cov = max(abs(medfit:::.sem_implied(ram, theta) - Sigma))
)
```

    mean  cov
       0    0 

The last two numbers are the largest absolute differences between our
matrix product and the engine’s helpers, so they would be large if
either side had an error. This model has as many free parameters as
observed moments (Section 6 counts them) and is identified, so it can
match any sample means and covariances. Compare with the sample moments:

``` r
x <- as.matrix(fit@data[, ram$obs])
xbar <- colMeans(x)
S <- cov(x) * (n - 1) / n
cat("sample mean\n")
```

    sample mean

``` r
mx(xbar)
```

    mediator1 treatment   outcome
       0.3843    0.5025    0.5257 

``` r
cat("\nsample covariance (divisor n)\n")
```


    sample covariance (divisor n)

``` r
mx(S)
```

              mediator1 treatment outcome
    mediator1    1.2105    0.1140  0.8682
    treatment    0.1140    0.2500  0.0915
    outcome      0.8682    0.0915  1.8036

``` r
c(mean = max(abs(mu - xbar)), cov = max(abs(Sigma - S)))
```

            mean          cov
    1.110223e-16 2.220446e-16 

The model reproduces the sample mean and covariance to rounding. An
identified model with as many free parameters as observed moments (zero
degrees of freedom) is **saturated**: it reproduces every data set this
way, so it cannot be rejected.

## 4. The discrepancy

The engine finds \\\theta\\ by maximum likelihood. This section derives
the function it minimizes, including the term the mean structure adds.

**Setup.** The data are \\n\\ rows \\x_1, \dots, x_n\\, each a vector of
the \\p\\ observed variables, assumed independent and multivariate
normal with mean \\\mu\\ and covariance \\\Sigma\\. The density of one
row is

\\ f(x_i) = (2\pi)^{-p/2} \|\Sigma\|^{-1/2} \exp\left\\ -\tfrac12 (x_i -
\mu)^\top \Sigma^{-1} (x_i - \mu) \right\\. \\

**Step 1: the log likelihood.** Rows are independent, so the log
likelihood is the sum of the log densities:

\\ -2 \log L = n p \log 2\pi + n \log\|\Sigma\| + \sum\_{i=1}^n (x_i -
\mu)^\top \Sigma^{-1} (x_i - \mu). \\

**Step 2: split each deviation.** Write \\x_i - \mu = (x_i - \bar x) +
d\\, with \\\bar x\\ the sample mean and \\d = \bar x - \mu\\ the gap
between the sample mean and the model’s mean. Expanding the quadratic
form gives three terms:

\\ \sum_i (x_i - \bar x)^\top \Sigma^{-1} (x_i - \bar x) + 2\\ d^\top
\Sigma^{-1} \sum_i (x_i - \bar x) + n\\ d^\top \Sigma^{-1} d . \\

The middle term is zero, because deviations from the sample mean sum to
zero (\\\sum_i (x_i - \bar x) = 0\\).

**Step 3: turn the first sum into a trace.** A scalar equals its own
trace, and \\\operatorname{tr}(u^\top M u) = \operatorname{tr}(M u
u^\top)\\, so \\\sum_i (x_i - \bar x)^\top \Sigma^{-1} (x_i - \bar x) =
\operatorname{tr}\bigl(\Sigma^{-1} \sum_i (x_i - \bar x)(x_i - \bar
x)^\top\bigr) = n \operatorname{tr}(\Sigma^{-1} S)\\, with \\S\\ the
sample covariance with divisor \\n\\ (the engine’s choice, which is the
maximum likelihood estimate).

**Step 4: collect.**

\\ -2 \log L = n \left\[ p \log 2\pi + \log\|\Sigma\| +
\operatorname{tr}(\Sigma^{-1} S) + d^\top \Sigma^{-1} d \right\]. \\

**Step 5: scale to a discrepancy.** The engine minimizes the function
that is this bracket with the saturated value subtracted. The saturated
model sets \\\mu = \bar x\\ and \\\Sigma = S\\, giving \\d = 0\\ and a
bracket of \\p \log 2\pi + \log\|S\| + \operatorname{tr}(I) = p\log
2\pi + \log\|S\| + p\\. Subtracting it leaves

\\ F\_{ML}(\theta) = \log\|\Sigma\| + \operatorname{tr}(\Sigma^{-1} S) -
\log\|S\| - p + \underbrace{(\bar x - \mu)^\top \Sigma^{-1} (\bar x -
\mu)}\_{\text{mean term}}, \qquad -2\log L = n \left( F\_{ML} +
\log\|S\| + p + p \log 2\pi \right). \\

Two facts follow. First, \\F\_{ML} \ge 0\\, with equality exactly when
the model reproduces the sample mean and covariance (a saturated model
always does). The proof is short. The mean term is a quadratic form in a
positive definite matrix, so it is nonnegative. For the rest, let
\\\lambda_1, \dots, \lambda_p\\ be the eigenvalues of \\\Sigma^{-1} S\\,
all positive because \\S\\ is positive definite (the engine requires
it). \\\Sigma^{-1} S\\ is similar to the symmetric matrix
\\\Sigma^{-1/2} S \Sigma^{-1/2}\\, so all \\\lambda_j = 1\\ means
\\\Sigma = S\\. Then \\\log\|\Sigma\| - \log\|S\| = -\sum_j
\log\lambda_j\\ and \\\operatorname{tr}(\Sigma^{-1} S) = \sum_j
\lambda_j\\, so the covariance part equals \\\sum_j (\lambda_j - \log
\lambda_j - 1)\\. Each term is nonnegative, because \\\log \lambda \le
\lambda - 1\\, and it is zero only at \\\lambda = 1\\. Second, \\n
F\_{ML}\\ is the likelihood-ratio statistic against the saturated model,
since the saturated model’s \\-2\log L\\ is the bracket with \\F\_{ML} =
0\\; that is why it is the model chi-square. Without a mean structure
the means are free, \\d = 0\\, and the mean term is absent: that is the
whole of the extension.

**Worked instance.** Our free model is saturated, so \\F\_{ML} = 0\\ and
there is nothing to see. Fix the outcome’s intercept at zero with
`outcome ~ 0*1` and the model can no longer match the outcome mean.
Section 6 returns to what the restriction means; for now it gives a
nonzero \\F\_{ML}\\ to take apart.

``` r
syntax0 <- sub("outcome ~ 1", "outcome ~ 0*1", syntax, fixed = TRUE)
fit0 <- fit_sem(syntax0, mediation_demo)
ram0 <- fit0@internals$ram
th0 <- fit0@theta
Sigma0 <- medfit:::.sem_implied(ram0, th0)
mu0 <- medfit:::.sem_implied_mean(ram0, th0)
d <- xbar - mu0
Sinv <- solve(Sigma0)
p <- length(xbar)

cov_part <- log(det(Sigma0)) + sum(diag(Sinv %*% S)) - log(det(S)) - p
mean_part <- drop(t(d) %*% Sinv %*% d)
c(covariance = cov_part, mean = mean_part, total = cov_part + mean_part, engine = fit0@f)
```

    covariance       mean      total     engine
    0.01130355 0.01073159 0.02203514 0.02203514 

The gap vector \\d = \bar x - \mu\\ shows where the restriction bites:

``` r
mx(d)
```

    mediator1 treatment   outcome
       0.0000    0.0000    0.1138 

The model matches the sample means of `mediator1` and `treatment` (their
intercepts are free) and misses the outcome mean by 0.114. Both parts of
the discrepancy are positive, which is worth a moment. The paths \\b\\
and \\c'\\ appear in the covariance and in the outcome mean at once, so
the optimizer moves them away from the values that match the covariance
exactly (compare \\b\\ = 0.7287 here with 0.7134 in the free fit) to
close part of the mean gap, and pays for it in the covariance part. The
two terms trade off; their sum is what is minimized.

The log likelihood follows from the same pieces. Summing the log density
row by row, with no shortcut, must agree with
[`logLik()`](https://rdrr.io/r/stats/logLik.html), which uses the
formula in step 5:

``` r
ll_rows <- sum(vapply(seq_len(n), function(i) {
  di <- x[i, ] - mu0
  -0.5 * (p * log(2 * pi) + log(det(Sigma0)) + drop(t(di) %*% Sinv %*% di))
}, numeric(1)))
ll_formula <- -0.5 * n * (fit0@f + log(det(S)) + p + p * log(2 * pi))
c(row_by_row = ll_rows, formula = ll_formula, logLik = as.numeric(logLik(fit0)))
```

    row_by_row    formula     logLik
     -1492.468  -1492.468  -1492.468 

## 5. The gradient

The optimizer needs \\\partial F\_{ML} / \partial \theta_k\\. The engine
supplies it analytically. This section derives it in four steps, and
then checks each factor against finite differences.

**Step 1: the matrix calculus.** For a symmetric positive definite
\\\Sigma\\, \\\partial \log\|\Sigma\| = \operatorname{tr}(\Sigma^{-1}
\partial\Sigma)\\ and \\\partial \Sigma^{-1} = -\Sigma^{-1}
(\partial\Sigma) \Sigma^{-1}\\. The first is Jacobi’s formula; the
second follows from differentiating \\\Sigma\Sigma^{-1} = I\\. By the
cyclic property of the trace, \\d^\top \Sigma^{-1} d =
\operatorname{tr}(\Sigma^{-1} d d^\top)\\, so the mean term can be
treated as a trace too. Write \\S\_{\text{eff}} = S + d d^\top\\, so
that holding \\d\\ fixed,

\\ \partial F\_{ML} = \operatorname{tr}\bigl(\Sigma^{-1}
\partial\Sigma\bigr) - \operatorname{tr}\bigl(\Sigma^{-1}
S\_{\text{eff}} \Sigma^{-1} \partial\Sigma\bigr) + (\text{change through
} d). \\

**Step 2: the change through \\d\\.** \\d = \bar x - \mu\\, so
\\\partial d = -\partial\mu\\ (the sample mean does not depend on
\\\theta\\) and \\\partial (d^\top \Sigma^{-1} d)\|\_{\Sigma\\
\text{fixed}} = -2\\ (\partial\mu)^\top \Sigma^{-1} d\\. Together:

\\ \frac{\partial F\_{ML}}{\partial \theta_k} =
\operatorname{tr}\bigl(W\\ \partial_k \Sigma\bigr) - 2\\ (\partial_k
\mu)^\top \Sigma^{-1} d, \qquad W = \Sigma^{-1} - \Sigma^{-1}
S\_{\text{eff}} \Sigma^{-1}. \\

**Step 3: the derivative of \\B\\.** To get \\\partial_k\Sigma\\ and
\\\partial_k\mu\\ we need how \\B = (I - A)^{-1}\\ moves. Differentiate
\\B (I - A) = I\\: \\(\partial B)(I - A) - B\\\partial A = 0\\, so
\\\partial B = B\\(\partial A)\\B\\.

**Step 4: the derivative of the moments.** Let \\e_r\\ be the \\r\\th
unit vector.

- A path entry \\A\_{r c}\\ has \\\partial A = e_r e_c^\top\\, hence
  \\\partial B = B e_r e_c^\top B\\. Then \\\partial \mu = F B e_r \\(B
  m)\_c\\ and \\\partial \Sigma\_{\text{full}} = B e_r e_c^\top B\\
  S\_{\text{ram}} B^\top + \text{its transpose}\\, where
  \\\Sigma\_{\text{full}} = B S\_{\text{ram}} B^\top\\ is the covariance
  of all of \\v\\.
- An intercept \\m_j\\ moves \\\mu\\ by \\F B e_j\\ and does not touch
  \\\Sigma\\.
- A variance or covariance entry \\(S\_{\text{ram}})\_{r c}\\ has
  \\\partial \Sigma\_{\text{full}} = B e_r e_c^\top B^\top\\ (plus its
  transpose when \\r \neq c\\, because the matrix is symmetric and the
  two entries are one parameter) and does not touch \\\mu\\.

Two parameters with the same label are one parameter, so their
contributions add. The engine’s `.sem_dsigma()` and `.sem_dmu()` return
these derivatives; we check them against central differences of
`.sem_implied()` and `.sem_implied_mean()`, which know nothing about the
algebra above:

``` r
central <- function(f, theta, k, h = 1e-6) {
  up <- dn <- theta
  up[k] <- theta[k] + h
  dn[k] <- theta[k] - h
  (f(up) - f(dn)) / (2 * h)
}
dsig <- medfit:::.sem_dsigma(th0, ram0)
dmu <- medfit:::.sem_dmu(th0, ram0)
err_sigma <- vapply(seq_along(th0), function(k) {
  max(abs(dsig[[k]] - central(function(t) medfit:::.sem_implied(ram0, t), th0, k)))
}, numeric(1))
err_mu <- vapply(seq_along(th0), function(k) {
  max(abs(dmu[, k] - central(function(t) medfit:::.sem_implied_mean(ram0, t), th0, k)))
}, numeric(1))
signif(cbind(sigma = err_sigma, mu = err_mu), 2) |> `rownames<-`(names(th0))
```

                           sigma      mu
    a                    7.8e-11 4.6e-11
    b                    5.7e-11 3.1e-11
    cp                   6.4e-11 2.9e-11
    mediator1~~mediator1 8.2e-11 0.0e+00
    outcome~~outcome     8.2e-11 0.0e+00
    treatment~~treatment 9.3e-11 0.0e+00
    mediator1~1          0.0e+00 6.9e-12
    treatment~1          0.0e+00 3.6e-11

Each row is a free parameter and each entry is the largest absolute
discrepancy between the analytic derivative and the finite difference,
so a wrong derivative would show as a number near the size of the
derivative itself. Now the whole gradient. At the optimum it must
vanish. At another point it must match a finite difference of
\\F\_{ML}\\ itself, so we test it at the engine’s starting value, where
the gradient is large:

``` r
smp <- medfit:::.sem_sample(fit0@data, ram0)
grad_formula <- function(theta) {
  Sg <- medfit:::.sem_implied(ram0, theta)
  mug <- medfit:::.sem_implied_mean(ram0, theta)
  Si <- solve(Sg)
  dg <- smp$xbar - mug
  W <- Si - Si %*% (smp$s + tcrossprod(dg)) %*% Si
  ds <- medfit:::.sem_dsigma(theta, ram0)
  dm <- medfit:::.sem_dmu(theta, ram0)
  vapply(seq_along(theta), function(k) {
    sum(W * ds[[k]]) - 2 * drop(crossprod(dm[, k], Si %*% dg))
  }, numeric(1))
}
start <- medfit:::.sem_default_start(ram0, smp)
fml <- function(t) medfit:::.sem_fml(t, ram0, smp)
fd <- vapply(seq_along(start), function(k) central(fml, start, k), numeric(1))
signif(cbind(
  formula = grad_formula(start),
  finite_difference = fd,
  engine = medfit:::.sem_grad(start, ram0, smp)
), 4) |> `rownames<-`(names(start))
```

                            formula finite_difference     engine
    a                    -1.949e-01           -0.1949 -1.949e-01
    b                    -1.823e+00           -1.8230 -1.823e+00
    cp                   -4.062e-01           -0.4062 -4.062e-01
    mediator1~~mediator1 -1.548e+00           -1.5480 -1.548e+00
    outcome~~outcome     -9.868e-01           -0.9868 -9.868e-01
    treatment~~treatment -8.000e+00           -8.0000 -8.000e+00
    mediator1~1          -6.798e-18            0.0000 -3.455e-17
    treatment~1          -1.027e-17            0.0000  4.524e-17

``` r
c(at_start_vs_fd = max(abs(grad_formula(start) - fd)),
  at_optimum = max(abs(grad_formula(th0))))
```

    at_start_vs_fd     at_optimum
      1.019632e-09   4.024558e-16 

The three columns agree. The last two rows, the intercepts of
`mediator1` and `treatment`, are zero for a reason worth seeing. The
default start sets these two intercepts so that the implied means of
`mediator1` and `treatment` equal their sample means, which leaves a gap
only in the outcome: \\d = d_y e_y\\. With every variable observed,
\\\Sigma^{-1} = (I - A)^\top S\_{\text{ram}}^{-1} (I - A)\\. The outcome
causes nothing, so \\(I - A) e_y = e_y\\, and its residual is
uncorrelated with the others, so \\S\_{\text{ram}}^{-1} e_y = e_y /
s_y\\ with \\s_y\\ its residual variance. Hence \\\Sigma^{-1} d = (d_y /
s_y)(I - A)^\top e_y\\, and the gradient of intercept \\m_j\\, which is
\\-2\\(B e_j)^\top \Sigma^{-1} d\\ by Step 2 and Step 4, equals
\\-2\\(d_y / s_y)\\ e_j^\top B^\top (I - A)^\top e_y = -2\\(d_y/s_y)\\
e_j^\top e_y = 0\\ for every \\j\\ other than the outcome. At the
optimum every component of the gradient is numerically zero: the fit
sits at a stationary point.

## 6. Counting moments and degrees of freedom

The data summarize to \\p\\ means and \\p(p+1)/2\\ distinct variances
and covariances, so a model with a mean structure faces \\p(p+3)/2\\
**observed moments**. Here \\p = 3\\ gives 9 moments. The **degrees of
freedom** are the moments minus the free parameters,

\\ \text{df} = \frac{p(p+1)}{2} + p - q , \\

with \\q\\ the number of free parameters after equality constraints
(Chapter 3). The free model has \\q\\ = 9, so df = 0: saturated, as
Section 3 found. Fixing the outcome intercept removes one parameter and
no moment:

``` r
data.frame(
  model = c("all intercepts free", "outcome ~ 0*1"),
  moments = c(medfit:::.sem_moments(ram), medfit:::.sem_moments(ram0)),
  free_parameters = c(ram$q, ram0$q),
  df = c(fit@df, fit0@df),
  chisq = round(c(n * fit@f, n * fit0@f), 4)
)
```

                    model moments free_parameters df  chisq
    1 all intercepts free       9               9  0 0.0000
    2       outcome ~ 0*1       9               8  1 8.8141

So `y ~ 0*1` is a one-degree-of-freedom **restriction**, and its
chi-square is \\n F\_{ML}\\ = 8.814, the number Section 4 took apart.
What does it test? With the outcome intercept at zero, the outcome mean
is no longer free: the RAM equation forces \\\mu_y = b\\\mu\_{m} +
c'\\\mu_x\\, the mean carried by the mediator and the treatment through
the paths. The data can contradict that, and the restriction asks
whether they do. [`anova()`](https://rdrr.io/r/stats/anova.html), the
subject of Chapter 5, turns the same quantity into a p-value:

``` r
anova(fit0, fit)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

         Df  Chisq Chisq diff Df diff Pr(>Chisq)
    fit   0 0.0000
    fit0  1 8.8141     8.8141       1   0.002989 **
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

A Wald test of the same hypothesis reads the free fit’s intercept and
its standard error, \\z = \hat m_y / \operatorname{SE}(\hat m_y)\\:

``` r
est <- theta["outcome~1"]
se <- sqrt(diag(fit@vcov))["outcome~1"]
c(intercept = unname(est), se = unname(se), wald_chisq = unname((est / se)^2),
  lr_chisq = n * fit0@f)
```

     intercept         se wald_chisq   lr_chisq
    0.23110834 0.07741603 8.91188286 8.81405616 

The Wald and likelihood-ratio statistics are two standard ways to test
one parameter. They agree in large samples and differ in finite ones:
here 8.912 against 8.814.

## 7. Cross-checks: lavaan and OpenMx

Both packages fit the restricted model to the same data. lavaan reports
the chi-square, the degrees of freedom and the log likelihood directly.
We set `meanstructure = TRUE` and `fixed.x = FALSE` so that it estimates
the exogenous mean and variance the way the native engine does (Chapter
4 explains the alternative).

``` r
lv <- lavaan::sem("
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
  outcome ~ 0 * 1
", data = mediation_demo, meanstructure = TRUE, fixed.x = FALSE)
est_lv <- lavaan::coef(lv)
est_mf <- coef(fit0)
common <- intersect(names(est_lv), names(est_mf))
data.frame(
  quantity = c("chisq", "df", "logLik"),
  medfit = c(n * fit0@f, fit0@df, as.numeric(logLik(fit0))),
  lavaan = c(lavaan::fitMeasures(lv, "chisq"), lavaan::fitMeasures(lv, "df"),
             lavaan::fitMeasures(lv, "logl"))
)
```

          quantity       medfit       lavaan
    chisq    chisq     8.814056     8.814056
    df          df     1.000000     1.000000
    logl    logLik -1492.467976 -1492.467976

``` r
c(coefficients_compared = length(common),
  largest_absolute_difference = max(abs(est_lv[common] - est_mf[common])))
```

          coefficients_compared largest_absolute_difference
                   8.000000e+00                5.694416e-10 

The second result is the largest absolute difference over the
coefficients the two fits share.

OpenMx fits the same model on the raw data. Its RAM interface mirrors
the matrices of Section 2: `mxPath` with `arrows = 1` fills \\A\\,
`arrows = 2` fills \\S\_{\text{ram}}\\, and a path from `"one"` fills
\\m\\. The outcome’s intercept path is fixed at 0.

``` r
suppressMessages(library(OpenMx))
mxOption(NULL, "Number of Threads", 1)
dat <- mediation_demo[, c("mediator1", "treatment", "outcome")]
vars <- names(dat)
mod <- mxModel(
  "restricted", type = "RAM", manifestVars = vars,
  mxPath(from = "treatment", to = "mediator1", values = 0.4, labels = "a"),
  mxPath(from = c("mediator1", "treatment"), to = "outcome", values = 0.5, labels = c("b", "cp")),
  mxPath(from = vars, arrows = 2, values = 1, labels = paste0("v_", vars)),
  mxPath(from = "one", to = c("mediator1", "treatment"), values = 0, labels = c("m_m", "m_t")),
  mxPath(from = "one", to = "outcome", free = FALSE, values = 0),
  mxData(dat, type = "raw")
)
run <- mxRun(mod, silent = TRUE)
smry <- summary(run)
est_mx <- stats::setNames(smry$parameters$Estimate, smry$parameters$name)
mx_map <- c(a = "a", b = "b", cp = "cp", "mediator1~~mediator1" = "v_mediator1",
            "outcome~~outcome" = "v_outcome", "treatment~~treatment" = "v_treatment",
            "mediator1~1" = "m_m", "treatment~1" = "m_t")
data.frame(quantity = "-2 log L", medfit = -2 * as.numeric(logLik(fit0)),
           OpenMx = smry$Minus2LogLikelihood)
```

      quantity   medfit   OpenMx
    1 -2 log L 2984.936 2984.936

``` r
c(largest_absolute_difference = max(abs(est_mx[mx_map] - est_mf[names(mx_map)])))
```

    largest_absolute_difference
                   1.050627e-06 

``` r
c(OpenMx_degreesOfFreedom = smry$degreesOfFreedom, data_values_n_times_p = n * p,
  free_parameters = nrow(smry$parameters), saturated_moments = medfit:::.sem_moments(ram0),
  medfit_df = fit0@df)
```

    OpenMx_degreesOfFreedom   data_values_n_times_p         free_parameters
                       1192                    1200                       8
          saturated_moments               medfit_df
                          9                       1 

The two `-2 log L` values agree; the coefficients agree less closely
than lavaan’s, a difference in where the two optimizers stop.

The last line shows that OpenMx’s `degreesOfFreedom` is a different
count. For raw data OpenMx subtracts the number of free parameters from
the number of observed data values, \\n p\\. The chi-square degrees of
freedom compare against the saturated model, which has \\p(p+3)/2\\
parameters, so they are the saturated moments minus the free parameters,
the engine’s `fit0@df`.

## 8. The information is a sum

One more consequence of the mean structure, used in Chapter 5. The
**score** of one row is the gradient of its log density with respect to
\\\theta\\. The **expected information** of \\n\\ independent rows is
\\n\\ times the covariance matrix of one row’s score (its definition;
for a likelihood regular enough to differentiate under the integral it
also equals the expected negative Hessian, Chapter 5). Under normality
it is the sum of a covariance part and a mean part with no cross term:

\\ I\_{kl} = \frac{n}{2} \operatorname{tr}\bigl(\Sigma^{-1}
\partial_k\Sigma\\ \Sigma^{-1} \partial_l\Sigma\bigr) + n\\ (\partial_k
\mu)^\top \Sigma^{-1} (\partial_l \mu). \\

Why. Write \\u = x_i - \mu\\, so \\u \sim N(0, \Sigma)\\.
Differentiating the log density \\-\tfrac12\bigl\[\log\|\Sigma\| +
u^\top \Sigma^{-1} u\bigr\]\\ (the same calculus as Section 5, with
\\\partial u = -\partial\mu\\) gives the score of one row in two parts,

\\ s_k = \underbrace{(\partial_k\mu)^\top \Sigma^{-1} u}\_{\text{mean
part, linear in } u} + \underbrace{\tfrac12\bigl\[u^\top \Sigma^{-1}
(\partial_k\Sigma)\\ \Sigma^{-1} u -
\operatorname{tr}(\Sigma^{-1}\partial_k\Sigma)\bigr\]}\_{\text{covariance
part, quadratic in } u}. \\

Cross term: the covariance of a linear and a quadratic function of \\u\\
involves third-order moments of \\u\\, which are zero because the normal
distribution is symmetric about its mean. Mean part:
\\\operatorname{Cov}\bigl((\partial_k\mu)^\top \Sigma^{-1} u,\\
(\partial_l\mu)^\top \Sigma^{-1} u\bigr) = (\partial_k\mu)^\top
\Sigma^{-1} (\partial_l\mu)\\, since \\\operatorname{Cov}(u) = \Sigma\\.
Covariance part: for symmetric \\M, N\\, the normal moment identity
\\\operatorname{Cov}(u^\top M u,\\ u^\top N u) =
2\operatorname{tr}(M\Sigma N\Sigma)\\ with \\M =
\tfrac12\Sigma^{-1}\partial_k\Sigma\\\Sigma^{-1}\\ and \\N =
\tfrac12\Sigma^{-1}\partial_l\Sigma\\\Sigma^{-1}\\ gives
\\\tfrac12\operatorname{tr}(\Sigma^{-1}\partial_k\Sigma\\\Sigma^{-1}\partial_l\Sigma)\\.
Multiplying by \\n\\ gives the two terms above. Check the result against
the engine, which computes the same two terms:

``` r
sigma_inv <- solve(Sigma0)
cov_info <- 0.5 * n * outer(seq_along(th0), seq_along(th0), Vectorize(function(k, l) {
  sum(diag(sigma_inv %*% dsig[[k]] %*% sigma_inv %*% dsig[[l]]))
}))
mean_info <- n * crossprod(dmu, sigma_inv %*% dmu)
info_hand <- cov_info + mean_info
info_engine <- medfit:::.sem_info_expected(th0, ram0, smp, NULL)
c(difference = max(abs(info_hand - info_engine)), largest_entry = max(abs(info_engine)))
```

       difference largest_entry
     4.547474e-13  3.200160e+03 

The hand-built information matches the engine’s. Its inverse estimates
the covariance matrix of the estimates; the engine’s default uses the
observed information instead (Chapter 5 compares the two), and Chapter 2
shows why the inverse needs a change of coordinates when the means are
large.

## Check yourself

1.  In the RAM form, which matrix would you change to add a correlation
    between two residuals? Which to add a path from the treatment to a
    new mediator? (Answer: \\S\_{\text{ram}}\\, then \\A\\.)
2.  A model with \\p = 4\\ observed variables, a mean structure and 12
    free parameters has how many degrees of freedom? (Answer: \\4 \cdot
    5 / 2 + 4 - 12 = 2\\.)
3.  Why is the middle term in Step 2 of Section 4 zero, and what would
    break if \\\bar x\\ were replaced by some other center? (Answer:
    deviations from the sample mean sum to zero; for another center the
    cross term would not vanish and the likelihood would not split into
    a covariance part and a mean part.)

## Where next

[Chapter
2](https://data-wise.github.io/medfit/articles/native-book-2-scale.md)
asks what happens to this machinery when the variables sit far from zero
relative to their spread, and shows why the engine fits in centered
coordinates.
