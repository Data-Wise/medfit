# Native engine book, chapter 4: fixed exogenous variables

In a mediation model the treatment and the covariates are **exogenous**:
nothing in the model explains them. Their means, variances and
covariances are parameters of the joint model, and they carry no
information about the paths. The `fixed_x` argument of
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
stops estimating them and holds them at their sample values, as lavaan’s
`fixed.x = TRUE` does. This chapter shows exactly what that changes (the
parameter count and the likelihood) and what it does not (the estimates
and standard errors of the structural parameters, that is the paths, the
residual variances and the intercepts of the other variables; the
degrees of freedom; and the chi-square), proves why, and shows which
comparisons the engine then refuses.

|  |  |
|----|----|
| **You need** | Chapters 1 to 3 (the RAM matrices, the discrepancy, the moment count) and the multivariate normal density |
| **You get** | the moments `fixed_x` fixes and where they go in the RAM matrices, the factorization argument for equal structural estimates and standard errors (and what changes when only some exogenous variables are fixed), the conditional log likelihood derived and computed by hand, its parameter count, and the refusals with their messages |
| **Time** | about 45 minutes |

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
d <- mediation_demo
n <- nrow(d)

# Two exogenous variables (treatment and covariate1) and two outcomes (mediator1 and outcome)
full <- "
  mediator1 ~ a * treatment + covariate1
  outcome ~ b * mediator1 + cp * treatment + covariate1
"
restricted <- paste0(full, "cp == 0\n")   # one restriction, so that df = 1 and the chi-square is not zero
```

## 1. Which moments are fixed

A variable is **exogenous** here if it appears only as a predictor,
never as the target of a path (`treatment` and `covariate1`). With
`fixed_x = TRUE` every such variable is selected; a character vector
selects a subset. The selected variables’ means, variances and the
covariances among the exogenous variables that involve a selected one
become **fixed moments**: the engine gives them the sample values
(divisor \\n\\, so \\S\_{ff} = \frac1n\sum_i (x_i - \bar x)(x_i - \bar
x)^\top\\, the matrix of Chapter 1) and no longer treats them as
parameters.

``` r
fx <- fit_sem(full, d, meanstructure = TRUE, fixed_x = TRUE, information = "expected")
fx@internals$fixed_x
```

    [1] "treatment"  "covariate1"

``` r
tidy(fx)[, c("term", "estimate", "std_error", "fixed_x")]
```

    # A tibble: 14 × 4
       term                   estimate std_error fixed_x
       <chr>                     <dbl>     <dbl> <lgl>
     1 a                        0.581     0.0986 FALSE
     2 mediator1~covariate1     0.448     0.0483 FALSE
     3 b                        0.573     0.0531 FALSE
     4 cp                       0.204     0.109  FALSE
     5 outcome~covariate1       0.356     0.0565 FALSE
     6 mediator1~~mediator1     0.954     0.0674 FALSE
     7 outcome~~outcome         1.07      0.0759 FALSE
     8 mediator1~1              0.0844    0.0696 FALSE
     9 outcome~1                0.197     0.0740 FALSE
    10 treatment~~treatment     0.250    NA      TRUE
    11 treatment~~covariate1   -0.0700   NA      TRUE
    12 covariate1~~covariate1   1.04     NA      TRUE
    13 treatment~1              0.502    NA      TRUE
    14 covariate1~1             0.0174   NA      TRUE   

The last five rows are the fixed moments (the variances and covariance
of the two exogenous variables, and, because this fit has a mean
structure, their two means). They are flagged `fixed_x = TRUE` and have
no standard error, because they are no longer estimates; the engine
keeps them in its parameter table (`fx@table`). Check that they are the
sample moments:

``` r
exo <- c("treatment", "covariate1")
xm <- as.matrix(d[, exo])
s_ff <- cov(xm) * (n - 1) / n
tab <- fx@table
fixed_tab <- tab[tab$fixed_x, c("lhs", "op", "rhs", "est")]
fixed_tab$sample_value <- vapply(seq_len(nrow(fixed_tab)), function(i) {
  row <- fixed_tab[i, ]
  if (row$op == "~1") colMeans(xm)[[row$lhs]] else s_ff[row$lhs, row$rhs]
}, numeric(1))
c(largest_difference = max(abs(fixed_tab$est - fixed_tab$sample_value)))
```

    largest_difference
          8.326673e-16 

``` r
fixed_tab[, c("est", "sample_value")] <- rd(fixed_tab[, c("est", "sample_value")], 6)
fixed_tab
```

              lhs op        rhs       est sample_value
    8   treatment ~~  treatment  0.249994     0.249994
    9   treatment ~~ covariate1 -0.069969    -0.069969
    10 covariate1 ~~ covariate1  1.039839     1.039839
    12  treatment ~1             0.502500     0.502500
    13 covariate1 ~1             0.017352     0.017352

In the RAM matrices of Chapter 1 these entries of \\S\_{\text{ram}}\\
and \\m\\ become constants, in the same place a fixed value such as
`y ~ 0.5*x` would sit; the parameter vector no longer has a slot for
them.

## 2. Parameters, moments and degrees of freedom

Counting moments (Chapter 1): \\p(p+1)/2\\ distinct variances and
covariances, plus \\p\\ means with a mean structure. With \\k\\ fixed
variables, the fixed moments are removed from the *count of moments*
(the engine does not ask the model to explain them) as well as from the
*count of parameters*. Each removal is the same size, so the difference,
the degrees of freedom, does not change. Four fits to the restricted
model:

``` r
fits <- list(
  free_cov = fit_sem(restricted, d),
  fixed_cov = fit_sem(restricted, d, fixed_x = TRUE),
  free_mean = fit_sem(restricted, d, meanstructure = TRUE),
  fixed_mean = fit_sem(restricted, d, meanstructure = TRUE, fixed_x = TRUE)
)
data.frame(
  fit = names(fits),
  parameters = vapply(fits, function(f) length(f@theta), numeric(1)),
  equality_rank = vapply(fits, function(f) f@internals$eq_rank, numeric(1)),
  fixed_moments = vapply(fits, function(f) f@internals$ram$n_fixed_x, numeric(1)),
  moments = vapply(fits, function(f) medfit:::.sem_moments(f@internals$ram), numeric(1)),
  df = vapply(fits, function(f) f@df, numeric(1)),
  chisq = vapply(fits, function(f) round(f@n_obs * f@f, 6), numeric(1)),
  row.names = NULL
)
```

             fit parameters equality_rank fixed_moments moments df    chisq
    1   free_cov         10             1             0      10  1 3.491141
    2  fixed_cov          7             1             3       7  1 3.491141
    3  free_mean         14             1             0      14  1 3.491141
    4 fixed_mean          9             1             5       9  1 3.491141

With three variances and covariances fixed (covariance structure) the
parameter count falls by 3 and the moment count by 3; with the two means
added it falls by 5 and 5. The degrees of freedom (1, from the one
restriction `cp == 0`) and the chi-square are identical in all four.

## 3. Why the estimates and standard errors do not change

This section proves the claim in the title for `fixed_x = TRUE`, checks
it, and then shows what changes when only some exogenous variables are
fixed.

**Setup.** Take `fixed_x = TRUE`, so that \\x\\, the vector of the \\k\\
fixed variables, holds every exogenous variable, and let \\y\\ be the
vector of all other observed variables. No error of \\y\\ is correlated
with \\x\\: such a covariance would be a statement about a fixed
variable, which the engine refuses (Section 5). In the RAM form, a
variable with no incoming path is its own error plus its intercept: \\x
= m_x + e_x\\. So \\x \sim N(\mu_x, \Sigma\_{xx})\\ with \\\mu_x = m_x\\
and \\\Sigma\_{xx} = S\_{\text{ram},xx}\\, and nothing in the model
touches these. Given \\x\\, the rest of the model is linear: \\y = (I -
A\_{y y})^{-1}(m_y + A\_{y x}\\x + e_y)\\, so

\\ y \mid x \\\sim\\ N\bigl(c + \Gamma x,\\ \Psi\bigr), \qquad \Gamma =
(I - A\_{y y})^{-1} A\_{y x}, \quad c = (I - A\_{y y})^{-1} m_y, \quad
\Psi = (I - A\_{y y})^{-1} S\_{y y} (I - A\_{y y})^{-\top}. \\

Here \\A\_{y y}\\ and \\A\_{y x}\\ are the blocks of \\A\\, \\S\_{y y}\\
is the error covariance of \\y\\, and \\c\\, \\\Gamma\\ and \\\Psi\\
depend only on the **structural parameters** \\\psi\\ (the paths, the
residual variances, the intercepts of \\y\\) and not on \\\eta = (\mu_x,
\Sigma\_{xx})\\.

**Step 1: factor the density.** For each row, \\f(x_i, y_i) = f(y_i \mid
x_i;\\ \psi)\\ f(x_i;\\ \eta)\\, the definition of a conditional
density. Taking logs and summing over rows,

\\ \ell(\psi, \eta) = \ell_c(\psi) + \ell_m(\eta), \\

where \\\ell_c\\ is the conditional log likelihood of \\y\\ given \\x\\
and \\\ell_m\\ the marginal one of \\x\\. The two parts have no
parameter in common: this identity holds for every value of \\(\psi,
\eta)\\.

**Step 2: maximize.** Because \\\ell\\ is a sum of a function of
\\\psi\\ and a function of \\\eta\\, it is maximized by maximizing each
separately. The maximizer of \\\ell_m\\ is the sample mean and the
divisor-\\n\\ covariance matrix of \\x\\ (the standard result for the
normal distribution). The maximizer \\\hat\psi\\ of \\\ell_c\\ does not
involve \\\eta\\ at all. So the free fit’s structural estimates are
\\\hat\psi\\. The fixed fit holds \\\eta\\ at \\\hat\eta\\ and maximizes
the same \\\ell\\ over \\\psi\\, which is \\\ell_c(\psi)\\ plus a
constant: the same \\\hat\psi\\.

**Step 3: the information.** The cross second derivatives
\\\partial^2\ell/\partial\psi\\\partial\eta^\top\\ are zero, because
\\\partial\ell/\partial\psi = \partial\ell_c/\partial\psi\\ does not
depend on \\\eta\\. The information matrix is therefore block diagonal,
and its \\\psi\\ block is the information of \\\ell_c\\ alone. The
covariance of \\\hat\psi\\ is the inverse of that block, the same
whether or not the \\\eta\\ block is present. So the standard errors of
the structural estimates agree between the two fits. The minimized
discrepancy is the same too: the fixed fit’s discrepancy is the free
discrepancy of Chapter 1 with \\\eta\\ set to \\\hat\eta\\, and the free
optimum has \\\eta = \hat\eta\\ by Step 2, so the two minima are the
value of one function at one point. Hence the chi-square agrees.

Now check each step on our data. The estimates and standard errors of
the structural parameters:

``` r
free <- fit_sem(full, d, meanstructure = TRUE, information = "expected")
shared <- intersect(names(free@theta), names(fx@theta))
c(estimates = max(abs(free@theta[shared] - fx@theta[shared])),
  standard_errors = max(abs(sqrt(diag(free@vcov))[shared] - sqrt(diag(fx@vcov))[shared])))
```

          estimates standard_errors
       4.440892e-16    2.498002e-16 

The estimates and standard errors agree to rounding. Step 3 is the claim
that the information has no cross block; look at the free fit’s
information between the fixed moments and the structural parameters, in
the engine’s raw coordinates, for both kinds of information:

``` r
ram <- free@internals$ram
smp <- medfit:::.sem_sample(free@data, ram)
info_e <- medfit:::.sem_info_expected(free@theta, ram, smp, NULL)
info_o <- medfit:::.sem_info_observed(free@theta, ram, smp, NULL)
moment_names <- c("treatment~~treatment", "treatment~~covariate1", "covariate1~~covariate1",
                  "treatment~1", "covariate1~1")
structural <- setdiff(rownames(info_e), moment_names)
cross <- function(m) max(abs(m[moment_names, structural]))
cross_table <- data.frame(
  information = c("expected", "observed"),
  cross_block_largest_entry = c(cross(info_e), cross(info_o)),
  largest_entry_of_the_matrix = c(max(abs(info_e)), max(abs(info_o)))
)
cross_table$orders_of_magnitude_below <- round(log10(cross_table$largest_entry_of_the_matrix /
                                                       cross_table$cross_block_largest_entry), 1)
cross_table
```

      information cross_block_largest_entry largest_entry_of_the_matrix
    1    expected              1.011261e-13                    3324.189
    2    observed              9.436680e-09                    3324.189
      orders_of_magnitude_below
    1                      16.5
    2                      11.5

The cross block has 5 \\\times\\ 9 entries. Its largest entry is 16.5
orders of magnitude below the largest entry of the matrix for the
expected information and 11.5 for the observed one (which the engine
computes by finite differences of the gradient, so it carries a
numerical error that the expected one does not). Both are zero to
numerical precision, as Step 3 says.

### Fixing a subset

With `fixed_x = "treatment"`, only the moments that involve `treatment`
are fixed: its mean, its variance and its covariance with `covariate1`.
The variance and the mean of `covariate1` stay free. The structural
parameters keep their estimates and standard errors; the free moments of
`covariate1` keep their estimates but not their standard errors:

``` r
subset_fit <- fit_sem(full, d, meanstructure = TRUE, fixed_x = "treatment", information = "expected")
both <- intersect(names(free@theta), names(subset_fit@theta))
own_moments <- c("covariate1~~covariate1", "covariate1~1")
se_change <- sqrt(diag(subset_fit@vcov))[both] - sqrt(diag(free@vcov))[both]
c(structural_estimates = max(abs(subset_fit@theta[structural] - free@theta[structural])),
  structural_standard_errors = max(abs(se_change[structural])),
  covariate1_moment_estimates = max(abs(subset_fit@theta[own_moments] - free@theta[own_moments])))
```

           structural_estimates  structural_standard_errors
                   6.661338e-16                2.081668e-16
    covariate1_moment_estimates
                   2.220446e-16 

``` r
signif(se_change[own_moments], 3)
```

    covariate1~~covariate1           covariate1~1
                 -0.001380              -0.000482 

The reason is the information of the exogenous block itself. In the free
fit the standard error of a free moment \\j\\ is \\\sqrt{(I^{-1})\_{j
j}}\\ over the whole exogenous block, and that block is not diagonal.
Under normality the means and the (co)variances share no information
(Chapter 1, Section 8), but within the means \\\Sigma^{-1}\\ couples the
mean of `covariate1` with the mean of `treatment`, and within the
(co)variances the variance of `covariate1` shares information with the
variance of `treatment` and with their covariance. Fixing the moments of
`treatment` removes those partners, so the standard errors of
`covariate1`’s moments come from a smaller block. For the mean this has
a closed form. With \\s\_{11}\\, \\s\_{12}\\, \\s\_{22}\\ the entries of
\\S\_{ff}\\ (1 for `treatment`, 2 for `covariate1`), the free fit’s
standard error is \\\sqrt{s\_{22}/n}\\ and the subset fit’s is
\\\sqrt{(s\_{22} - s\_{12}^2/s\_{11})/n}\\, the conditional variance of
`covariate1` given `treatment`, over \\n\\:

``` r
se_mean <- function(f) sqrt(diag(f@vcov))[["covariate1~1"]]
c(free_fit = se_mean(free), by_hand_free = sqrt(s_ff[2, 2] / n),
  subset_fit = se_mean(subset_fit), by_hand_subset = sqrt((s_ff[2, 2] - s_ff[1, 2]^2 / s_ff[1, 1]) / n))
```

          free_fit   by_hand_free     subset_fit by_hand_subset
        0.05098626     0.05098626     0.05050386     0.05050386 

The structural block still has no cross term with any exogenous moment,
so Step 3 holds for it unchanged.

## 4. The conditional log likelihood

[`logLik()`](https://rdrr.io/r/stats/logLik.html) for the fixed fit is
the *conditional* log likelihood \\\ell_c(\hat\psi)\\. From Step 1,
\\\ell_c = \ell - \ell_m(\eta)\\, so at the estimates

\\ \ell_c(\hat\psi) = \ell(\hat\psi, \hat\eta) - \ell_m(\hat\eta) . \\

**The marginal term.** Evaluate \\\ell_m\\ at the sample moments. Each
row contributes \\-\tfrac12\bigl\[k\log 2\pi + \log\|S\_{ff}\| + (x_i -
\bar x)^\top S\_{ff}^{-1}(x_i - \bar x)\bigr\]\\. By the trace argument
of Chapter 1 (Step 3), \\\sum_i (x_i - \bar x)^\top S\_{ff}^{-1}(x_i -
\bar x) = n\operatorname{tr}(S\_{ff}^{-1} S\_{ff}) = n k\\. So

\\ \ell_m(\hat\eta) = -\frac n2 \bigl(\log\|S\_{ff}\| + k + k\log
2\pi\bigr), \qquad \ell_c(\hat\psi) = \ell(\hat\psi, \hat\eta) + \frac
n2 \bigl(\log\|S\_{ff}\| + k + k\log 2\pi\bigr). \\

This is the correction [`logLik()`](https://rdrr.io/r/stats/logLik.html)
applies to the joint value. Check it three ways: against the joint value
from the free fit, against a direct computation of the conditional
density from the RAM matrices, and against lavaan.

``` r
k <- length(exo)
marginal <- -0.5 * n * (as.numeric(determinant(s_ff, logarithm = TRUE)$modulus) + k + k * log(2 * pi))
c(joint_logLik_free_fit = as.numeric(logLik(free)),
  conditional_logLik_fixed_fit = as.numeric(logLik(fx)),
  difference_of_the_two = as.numeric(logLik(fx)) - as.numeric(logLik(free)),
  minus_marginal_term = -marginal)
```

           joint_logLik_free_fit conditional_logLik_fixed_fit
                      -2001.8256                   -1139.9279
           difference_of_the_two          minus_marginal_term
                        861.8977                     861.8977 

By hand from the conditional model of the setup: the endogenous block is
`mediator1` and `outcome`, the mean of each row given its fixed
variables is \\c + \Gamma x_i\\ and the covariance is \\\Psi\\. Sum the
bivariate normal log densities:

``` r
mats <- medfit:::.sem_ram_mats(fx@internals$ram, fx@theta)
A <- mats$a
s_ram <- mats$s
m <- medfit:::.sem_ram_m(fx@internals$ram, fx@theta)
vars <- fx@internals$ram$vars
endo <- c("mediator1", "outcome")
iy <- match(endo, vars)
ix <- match(exo, vars)
b_yy <- solve(diag(length(endo)) - A[iy, iy])
Psi <- b_yy %*% s_ram[iy, iy] %*% t(b_yy)
data_mat <- as.matrix(d[, c(endo, exo)])
ll_by_hand <- sum(vapply(seq_len(n), function(i) {
  mu_i <- drop(b_yy %*% (m[iy] + A[iy, ix] %*% data_mat[i, exo]))
  e <- data_mat[i, endo] - mu_i
  -0.5 * (length(endo) * log(2 * pi) + log(det(Psi)) + drop(t(e) %*% solve(Psi) %*% e))
}, numeric(1)))
c(by_hand = ll_by_hand, logLik = as.numeric(logLik(fx)))
```

      by_hand    logLik
    -1139.928 -1139.928 

**The parameter count.**
[`logLik()`](https://rdrr.io/r/stats/logLik.html) also carries a `df`
attribute, the parameter count behind AIC and BIC. With a mean structure
the free intercepts are in the parameter vector already. Without one,
the likelihood still has means: the model’s means are saturated, one
free mean for each variable that is not fixed (a fixed variable’s mean
is a constant, not a parameter). So the count is

\\ \text{df}\_{\text{logLik}} = (q - \text{rank}) + (p - k)\\\mathbb
1\[\text{no mean structure}\] , \\

with \\q - \text{rank}\\ the free parameters after equality constraints.
Check against the four fits of Section 2, and compare with lavaan, which
reports the same count for the mean-structure fit:

``` r
ll <- lapply(fits, logLik)
data.frame(
  fit = names(fits),
  logLik = vapply(ll, as.numeric, numeric(1)),
  df_attribute = vapply(ll, attr, numeric(1), "df"),
  formula = vapply(fits, function(f) {
    p <- length(f@internals$ram$obs)
    kk <- length(f@internals$fixed_x)
    (length(f@theta) - f@internals$eq_rank) + (p - kk) * !isTRUE(f@internals$ram$has_mean)
  }, numeric(1)),
  AIC = vapply(fits, AIC, numeric(1)),
  BIC = vapply(fits, BIC, numeric(1)),
  row.names = NULL
)
```

             fit    logLik df_attribute formula      AIC      BIC
    1   free_cov -2003.571           13      13 4033.142 4085.031
    2  fixed_cov -1141.673            8       8 2299.347 2331.279
    3  free_mean -2003.571           13      13 4033.142 4085.031
    4 fixed_mean -1141.673            8       8 2299.347 2331.279

The two fixed fits have the same likelihood, parameter count, AIC and
BIC whether or not a mean structure is declared, and so do the two free
fits: declaring means only moves the intercepts into the parameter
vector.

``` r
lv_fixed <- lavaan::sem(restricted, d, meanstructure = TRUE, fixed.x = TRUE, information = "expected")
lv_free <- lavaan::sem(restricted, d, meanstructure = TRUE, fixed.x = FALSE, information = "expected")
lv_row <- function(f) {
  unname(c(lavaan::fitMeasures(f, "logl"), lavaan::fitMeasures(f, "npar"), lavaan::fitMeasures(f, "chisq"),
           lavaan::fitMeasures(f, "df"), lavaan::fitMeasures(f, "aic"), lavaan::fitMeasures(f, "bic")))
}
mf_row <- function(f) {
  unname(c(as.numeric(logLik(f)), attr(logLik(f), "df"), f@n_obs * f@f, f@df, AIC(f), BIC(f)))
}
data.frame(
  quantity = c("logLik", "df of logLik (lavaan: npar)", "chisq", "df", "AIC", "BIC"),
  medfit_fixed = mf_row(fits$fixed_mean),
  lavaan_fixed.x_TRUE = lv_row(lv_fixed),
  medfit_free = mf_row(fits$free_mean),
  lavaan_fixed.x_FALSE = lv_row(lv_free)
)
```

                         quantity medfit_fixed lavaan_fixed.x_TRUE  medfit_free
    1                      logLik -1141.673450        -1141.673450 -2003.571146
    2 df of logLik (lavaan: npar)     8.000000            8.000000    13.000000
    3                       chisq     3.491141            3.491141     3.491141
    4                          df     1.000000            1.000000     1.000000
    5                         AIC  2299.346900         2299.346900  4033.142292
    6                         BIC  2331.278617         2331.278617  4085.031331
      lavaan_fixed.x_FALSE
    1         -2003.571146
    2            13.000000
    3             3.491141
    4             1.000000
    5          4033.142292
    6          4085.031331

``` r
mean_fixed_expected <- fit_sem(restricted, d, meanstructure = TRUE, fixed_x = TRUE, information = "expected")
nm <- intersect(names(lavaan::coef(lv_fixed)), names(mean_fixed_expected@theta))
c(largest_estimate_difference = max(abs(lavaan::coef(lv_fixed)[nm] - mean_fixed_expected@theta[nm])),
  largest_se_difference = max(abs(sqrt(diag(lavaan::vcov(lv_fixed)))[nm] - sqrt(diag(mean_fixed_expected@vcov))[nm])))
```

    largest_estimate_difference       largest_se_difference
                   1.765230e-08                1.248207e-09 

(Both standard-error computations use the expected information.)

OpenMx can hold the exogenous moments at their sample values with fixed
paths. Its `-2 log L` is the *joint* value at those moments, so it
equals the free fit’s, and the conditional value differs from it by the
marginal term:

``` r
suppressMessages(library(OpenMx))
mxOption(NULL, "Number of Threads", 1)
dat <- d[, c("mediator1", "treatment", "covariate1", "outcome")]
mu_s <- colMeans(dat)
s_s <- cov(dat) * (n - 1) / n
mod <- mxModel(
  "fixedx", type = "RAM", manifestVars = names(dat),
  mxPath("treatment", "mediator1", values = 0.4, labels = "a"),
  mxPath("covariate1", "mediator1", values = 0.1, labels = "m_c"),
  mxPath("mediator1", "outcome", values = 0.4, labels = "b"),
  mxPath("covariate1", "outcome", values = 0.1, labels = "y_c"),
  mxPath(c("mediator1", "outcome"), arrows = 2, values = 1, labels = c("vm", "vy")),
  mxPath("treatment", arrows = 2, free = FALSE, values = s_s["treatment", "treatment"]),
  mxPath("covariate1", arrows = 2, free = FALSE, values = s_s["covariate1", "covariate1"]),
  mxPath("treatment", "covariate1", arrows = 2, free = FALSE, values = s_s["treatment", "covariate1"]),
  mxPath("one", c("treatment", "covariate1"), free = FALSE, values = mu_s[c("treatment", "covariate1")]),
  mxPath("one", c("mediator1", "outcome"), values = 0, labels = c("i_m", "i_y")),
  mxData(dat, type = "raw")
)
mx_run <- mxRun(mod, silent = TRUE)
data.frame(
  quantity = c("OpenMx -2 log L (joint, moments held)", "medfit free fit, -2 log L (joint)",
               "medfit fixed fit, -2 log L (conditional)", "conditional + 2 x marginal term"),
  value = c(summary(mx_run)$Minus2LogLikelihood, -2 * as.numeric(logLik(fits$free_mean)),
            -2 * as.numeric(logLik(fits$fixed_mean)), -2 * as.numeric(logLik(fits$fixed_mean)) - 2 * marginal)
)
```

                                      quantity    value
    1    OpenMx -2 log L (joint, moments held) 4007.142
    2        medfit free fit, -2 log L (joint) 4007.142
    3 medfit fixed fit, -2 log L (conditional) 2283.347
    4          conditional + 2 x marginal term 4007.142

(Here `cp == 0` is the restriction, written in OpenMx by leaving out the
path from `treatment` to `outcome`.)

## 5. What the engine refuses

Because \\\ell_c\\ conditions on different variables for different fixed
sets, two such values do not measure the same thing. The difference of
two of them, or two AIC values, is meaningless, so the engine refuses to
produce it. The messages (captured with `tryCatch` so the page keeps
rendering):

``` r
say <- function(expr) {
  tryCatch({
    expr
    "no error"
  }, error = function(e) conditionMessage(e))
}
fixed_full <- fit_sem(full, d, fixed_x = TRUE)
fixed_restricted <- fit_sem(restricted, d, fixed_x = TRUE)
free_restricted <- fit_sem(restricted, d)
fixed_treatment <- fit_sem(restricted, d, fixed_x = "treatment")
d_other <- d
d_other$outcome <- d_other$outcome + 1
fixed_other_data <- fit_sem(restricted, d_other, fixed_x = TRUE)
msgs <- c(
  `anova, fixed vs free` = say(anova(fixed_restricted, free_restricted)),
  `AIC, fixed vs free` = say(AIC(fixed_restricted, free_restricted)),
  `BIC, free vs fixed` = say(BIC(free_restricted, fixed_restricted)),
  `AIC, different fixed sets` = say(AIC(fixed_restricted, fixed_treatment)),
  `AIC, fixed fit vs an lm` = say(AIC(fixed_restricted, lm(outcome ~ treatment, d))),
  `anova, same set, different data` = say(anova(fixed_full, fixed_other_data)),
  `AIC, same set, different data` = say(AIC(fixed_full, fixed_other_data))
)
cat(sprintf("%s:\n  %s\n", names(msgs), msgs), sep = "\n")
```

    anova, fixed vs free:
      the fits have different `fixed_x` sets (fixed_restricted: covariate1, treatment; free_restricted: none): their likelihoods condition on different variables, so they cannot be compared

    AIC, fixed vs free:
      the fits have different `fixed_x` sets (fixed_restricted: covariate1, treatment; free_restricted: none): their likelihoods condition on different variables, so they cannot be compared

    BIC, free vs fixed:
      the fits have different `fixed_x` sets (free_restricted: none; fixed_restricted: covariate1, treatment): their likelihoods condition on different variables, so they cannot be compared

    AIC, different fixed sets:
      the fits have different `fixed_x` sets (fixed_restricted: covariate1, treatment; fixed_treatment: treatment): their likelihoods condition on different variables, so they cannot be compared

    AIC, fixed fit vs an lm:
      a SEMFit with `fixed_x` has a conditional likelihood and cannot be compared with a model of another class: lm(outcome ~ treatment, d)

    anova, same set, different data:
      'fixed_full' and 'fixed_other_data' were fitted to different data. With `fixed_x` the likelihood conditions on the data's fixed block.

    AIC, same set, different data:
      'fixed_full' and 'fixed_other_data' were fitted to different data. With `fixed_x` the likelihood conditions on the data's fixed block.

Comparisons within one fixed set and one data set are allowed, and they
are exactly what the free fits would give:

``` r
anova(fixed_full, fixed_restricted)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

                     Df  Chisq Chisq diff Df diff Pr(>Chisq)
    fixed_full        0 0.0000
    fixed_restricted  1 3.4911     3.4911       1     0.0617 .
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

``` r
free_full <- fit_sem(full, d)
anova(free_full, free_restricted)
```

    Likelihood-ratio (chi-square difference) test for SEMFit models

    n = 400; Chisq is n times the minimized discrepancy

                    Df  Chisq Chisq diff Df diff Pr(>Chisq)
    free_full        0 0.0000
    free_restricted  1 3.4911     3.4911       1     0.0617 .
    ---
    Signif. codes:  0 '***' 0.001 '**' 0.01 '*' 0.05 '.' 0.1 ' ' 1

The two tables are the same test: the chi-square difference of a nested
pair does not depend on whether the exogenous moments are fixed.

Two more refusals concern the model itself. A statement about a selected
variable’s moments contradicts the request to fix them, and a name that
is not exogenous cannot be fixed:

``` r
msgs <- c(
  `statement on a fixed variable` = say(fit_sem(paste0(full, "treatment ~~ treatment\n"), d, fixed_x = TRUE)),
  `fixed_x names the outcome` = say(fit_sem(full, d, fixed_x = "outcome"))
)
cat(sprintf("%s:\n  %s\n", names(msgs), msgs), sep = "\n")
```

    statement on a fixed variable:
      `fixed_x` fixes the moments of the selected variables, but the model has a statement on them (treatment ~~ treatment): remove the statement, or leave the variable out of `fixed_x`

    fixed_x names the outcome:
      `fixed_x` names variables that are not exogenous observed variables of the model: outcome

Finally,
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
(the test of an indirect effect of Chapter 5) refits the model text on
the data the fit used, with the fit’s `fixed_x`. The statistic is the
same as from the free fit, since the structural estimates and the
discrepancy are:

``` r
c(from_fixed_fit = unname(mbco_sem(fixed_full, "a", "b")$statistic),
  from_free_fit = unname(mbco_sem(fit_sem(full, d), "a", "b")$statistic))
```

    from_fixed_fit  from_free_fit
          33.35322       33.35322 

## 6. When to use it

Fixing the exogenous moments shrinks the problem: with many covariates
the free fit has a parameter for every variance and covariance among
them, and the fixed fit has none, so it is smaller. The price is the
likelihood: it is conditional, comparable only within one fixed set and
one data set, and it is not the joint likelihood a different package may
report. When the question is about the paths (their estimates, standard
errors, tests) the answer is the same either way, as Section 3 proved;
the standard errors of exogenous moments left free next to fixed ones
are the exception that section showed. When the question is about
information criteria across models, fit them all with the same
`fixed_x`.

## Check yourself

1.  In Section 3 where does the proof use that no statement is made
    about the fixed variables’ moments? (Answer: Step 2 needs no
    parameter or constraint shared between \\\psi\\ and \\\eta\\. A
    constraint linking a moment to a path ties them, and then the
    structural estimates change. A fixed value such as
    `treatment ~~ 0.25*treatment` leaves the structural estimates alone
    but restricts \\\eta\\, so the discrepancy and the chi-square
    change. The engine refuses both kinds of statement.)
2.  With \\p = 6\\ observed variables, \\k = 3\\ fixed, no mean
    structure, and 11 free parameters after constraints, what is the
    `df` of [`logLik()`](https://rdrr.io/r/stats/logLik.html)? (Answer:
    \\11 + (6 - 3) = 14\\.)
3.  The fixed and the free fit report different
    [`logLik()`](https://rdrr.io/r/stats/logLik.html) values for the
    same model and data. Which is wrong? (Answer: neither: they are
    different quantities, the conditional and the joint log likelihood,
    and differ by the marginal term of Section 4.)

## Where next

[Chapter
5](https://data-wise.github.io/medfit/articles/native-book-5-inference.md)
opens the information matrix itself: the observed and expected versions,
the sandwich estimator, and the tests built on the discrepancy, MBCO and
[`anova()`](https://rdrr.io/r/stats/anova.html).
