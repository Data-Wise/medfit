# Native engine book, chapter 2: scale and conditioning

[Chapter
1](https://data-wise.github.io/medfit/articles/native-book-1-mean-structure.md)
built the mean structure. This chapter asks what happens when the
variables sit far from zero relative to their spread, a common situation
(a test score near 500 with a spread of 10, a year near 2000), and shows
the change of coordinates the engine uses so that the answer does not
depend on where the data sit. The engine is experimental.

|  |  |
|----|----|
| **You need** | Chapter 1 (the RAM matrices \\A\\, \\S\_{\text{ram}}\\, \\m\\, the implied mean and the expected information) |
| **You get** | why the information matrix goes singular as the means grow, the centered coordinates \\\phi\\ and the map \\\theta = T(\phi + c_0)\\, the identity \\V = T V\_\phi T^\top\\, and the exact conditions under which the engine fits shifted data |
| **Time** | about 35 minutes |

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
f3 <- function(x) formatC(x, format = "f", digits = 3)
rd <- function(x, d = 4) round(x, d)
sci <- function(x, d = 2) formatC(x, format = "e", digits = d)

syntax <- "
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
"
base <- mediation_demo[, c("treatment", "mediator1", "outcome")]
# the same data moved far from zero: means 100 to 300 ("mid"), then 1e3 to 1e5 ("big"),
# against standard deviations of 0.5 to 1.3
mid <- base
mid$treatment <- mid$treatment + 100
mid$mediator1 <- mid$mediator1 + 100
mid$outcome <- mid$outcome + 300
big <- base
big$treatment <- big$treatment + 1e3
big$mediator1 <- big$mediator1 + 1e4
big$outcome <- big$outcome + 1e5
rbind(mean_mid = colMeans(mid), mean_big = colMeans(big), sd = apply(base, 2, sd)) |> rd(2)
```

             treatment mediator1   outcome
    mean_mid     100.5    100.38    300.53
    mean_big    1000.5  10000.38 100000.53
    sd             0.5      1.10      1.34

Adding a constant to a variable changes its mean and nothing else about
it: the variances, covariances and every regression path are exactly
what they were. A good estimator should return the same paths, variances
and standard errors of those for `mid` and `big` as for `base` (only the
intercepts should move, as Section 1 explains). We will see which tools
manage that.

## 1. The symptom

Fit the model to the `big` data with the native engine, and compare its
standard errors for the paths and variances with those from the original
data:

``` r
fit_base <- fit_sem(syntax, base, meanstructure = TRUE, information = "expected")
fit_big <- fit_sem(syntax, big, meanstructure = TRUE, information = "expected")
se_base <- sqrt(diag(fit_base@vcov))
se_big <- sqrt(diag(fit_big@vcov))
rd(rbind(base = se_base, big = se_big), 5)
```

               a       b      cp mediator1~~mediator1 outcome~~outcome
    base 0.10763 0.05047 0.11106              0.08192          0.08347
    big  0.10763 0.05047 0.11106              0.08192          0.08347
         treatment~~treatment mediator1~1 treatment~1 outcome~1
    base              0.01768      0.0763       0.025   0.07742
    big               0.01768    107.6877       0.025 493.82590

``` r
c(largest_difference_in_the_six_path_and_variance_SEs = max(abs(se_big - se_base)[1:6]))
```

    largest_difference_in_the_six_path_and_variance_SEs
                                           1.183775e-14 

The six path and variance standard errors do not move. The last three
entries of each row are the intercepts, and two of their standard errors
grow, as they should. An intercept is the mean of its variable when its
*predictors* are at zero, so its standard error grows with the distance
of the predictors’ means from zero: the intercept of `mediator1` is an
extrapolation to `treatment` = 0, now 1,000 units from the data, and
that of `outcome` to `mediator1` = `treatment` = 0. The intercept of
`treatment` has no predictors, and its standard error does not move. Now
the same model in lavaan and OpenMx:

``` r
lav_warn <- NULL
lv <- withCallingHandlers(
  lavaan::sem(syntax, big, meanstructure = TRUE, fixed.x = FALSE),
  warning = function(w) {
    lav_warn <<- conditionMessage(w)
    invokeRestart("muffleWarning")
  }
)
cat("lavaan warning:", trimws(gsub("\\s+", " ", lav_warn)), "\n\n")
```

    lavaan warning: lavaan->lav_model_vcov(): Could not compute standard errors! The information matrix could not be inverted. This may be a symptom that the model is not identified. 

``` r
suppressMessages(library(OpenMx))
mxOption(NULL, "Number of Threads", 1)
vars <- names(big)
mod <- mxModel(
  "big", type = "RAM", manifestVars = vars,
  mxPath(from = "treatment", to = "mediator1", values = 0.4, labels = "a"),
  mxPath(from = c("mediator1", "treatment"), to = "outcome", values = 0.5, labels = c("b", "cp")),
  mxPath(from = vars, arrows = 2, values = 1, labels = paste0("v_", vars)),
  mxPath(from = "one", to = vars, values = colMeans(big), labels = paste0("m_", vars)),
  mxData(big, type = "raw")
)
run <- suppressWarnings(mxRun(mod, silent = TRUE))
pt <- summary(run)$parameters
cat("OpenMx optimizer status code:", run$output$status$code, "(0 is success)\n")
```

    OpenMx optimizer status code: 0 (0 is success)

``` r
paths_mx <- pt[pt$name %in% c("a", "b", "cp"), c("name", "Estimate", "Std.Error")]
paths_mx$ratio_to_native_se <- signif(paths_mx$Std.Error / se_base[paths_mx$name], 2)
paths_mx
```

      name  Estimate Std.Error ratio_to_native_se
    1    a 0.4559961  37182.26             350000
    2   cp 0.0405768  36833.91             330000
    3    b 0.7134301 368168.25            7300000

lavaan cannot invert its information matrix and returns no standard
errors. OpenMx reports a nonzero optimizer status and standard errors
for the paths that are orders of magnitude too large: the last column
divides each by the native engine’s standard error on the original data,
which the first table of this section showed is also the right value for
`big`. Neither is a bug in the estimator’s idea; both are the numerical
consequence of a nearly singular information matrix. The next section
shows where the singularity comes from.

## 2. Why the information goes singular

The expected information of Chapter 1 has a mean part
\\n\\(\partial_k\mu)^\top \Sigma^{-1} (\partial_l\mu)\\. It is built
from the derivatives of the implied mean \\\mu = F B m\\ with \\B = (I -
A)^{-1}\\. Take two parameters that both move the mean of the same
variable \\r\\: its intercept \\m_r\\ and one of its paths \\A\_{r c}\\.
From Chapter 1, Step 4 of the gradient derivation,

\\ \frac{\partial \mu}{\partial m_r} = F B e_r, \qquad \frac{\partial
\mu}{\partial A\_{r c}} = F B e_r \\(B m)\_c . \\

The two derivatives are the same vector, \\F B e_r\\, and the second is
multiplied by the scalar \\(B m)\_c\\. That scalar is the implied mean
of variable \\c\\, which at a good fit is close to its sample mean
\\\bar x_c\\. So the mean parts of the two columns of the information
matrix are almost proportional, with a factor of \\\bar x_c\\. When
\\\|\bar x_c\|\\ is large against the standard deviations, the mean part
of the information matrix has two nearly parallel columns, and a matrix
with two nearly parallel columns is nearly singular. Scale the
information to unit diagonal, \\I\_{kl} / \sqrt{I\_{kk} I\_{ll}}\\: each
entry is then the cosine of the angle between two columns (in the
geometry the information defines), and an entry near \\\pm 1\\ marks a
nearly parallel pair. On the `mid` data:

``` r
fit_mid <- fit_sem(syntax, mid, meanstructure = TRUE, information = "expected")
ram <- fit_mid@internals$ram
theta <- fit_mid@theta
smp <- medfit:::.sem_sample(fit_mid@data, ram)
info_raw <- medfit:::.sem_info_expected(theta, ram, smp, NULL)
# scale to unit diagonal: entry (k, l) is I_kl / sqrt(I_kk I_ll)
cor_raw <- cov2cor(info_raw)
pick <- c("a", "b", "cp", "mediator1~1", "outcome~1")
rd(cor_raw[pick, pick], 4)
```

                a      b     cp mediator1~1 outcome~1
    a           1 0.0000 0.0000           1    0.0000
    b           0 1.0000 0.9999           0    0.9999
    cp          0 0.9999 1.0000           0    1.0000
    mediator1~1 1 0.0000 0.0000           1    0.0000
    outcome~1   0 0.9999 1.0000           0    1.0000

The entry for `a` and `mediator1~1` is 1: that pair of columns is
parallel to four decimals. `b`, `cp` and the intercept of `outcome` all
move the mean of `outcome`, so those three columns are nearly parallel
together (0.9999 for `b` and the intercept). The summary the engine uses
to decide whether an information matrix can be inverted is its
**Jacobi-scaled reciprocal condition number**: the reciprocal condition
number of the matrix after scaling it to unit diagonal, so that the
units of the parameters play no part. Larger is better, and the engine
treats the matrix as singular below 1e-08 (`.sem_info_singular_tol`):

``` r
rcond_scaled <- function(m) rcond(cov2cor(m))
ram_b <- fit_big@internals$ram
smp_b <- medfit:::.sem_sample(fit_big@data, ram_b)
info_raw_b <- medfit:::.sem_info_expected(fit_big@theta, ram_b, smp_b, NULL)
c(mid_raw = rcond_scaled(info_raw), big_raw = rcond_scaled(info_raw_b),
  big_raw_unscaled = rcond(info_raw_b), engine_threshold = medfit:::.sem_info_singular_tol)
```

             mid_raw          big_raw big_raw_unscaled engine_threshold
        3.947868e-06     2.016914e-09     1.099791e-16     1.000000e-08 

At `mid` scale the raw matrix is poorly conditioned but still above the
threshold. At `big` scale it is below it, and without the Jacobi scaling
its reciprocal condition number is at the level of the machine precision
(about \\10^{-16}\\): the matrix is singular to working precision, which
is what lavaan reported above.

## 3. Centered coordinates

The fix is to describe the same model with different coordinates in
which the paths and the intercepts do not interfere. Let \\\bar x_v\\ be
the sample mean of variable \\v\\ (taken as 0 for a latent variable,
whose mean is fixed at 0). For every variable \\v\\ with a free
intercept, define the **centered intercept**

\\ \tilde m_v = m_v - \Bigl(\bar x_v - \sum_c A\_{v c}\\\bar x_c\Bigr).
\\

The bracket is the intercept that variable \\v\\’s equation would need
to reproduce its own sample mean given its paths: if every variable sits
at its mean, \\\bar x_v = m_v + \sum_c A\_{v c} \bar x_c\\, so \\m_v =
\bar x_v - \sum_c A\_{v c}\bar x_c\\. (In the engine the sum runs over
the free paths into \\v\\; Section 5 needs the fixed paths to be zero.)
So \\\tilde m_v\\ is the amount by which the intercept misses that
value, and it should be near zero at the optimum, whatever the means
are, when every intercept is free (Section 5 shows why). All other
parameters (paths, variances, the intercepts that are not free) keep
their own value. Call the vector of these coordinates \\\phi\\. Solving
the definition for \\m_v\\ shows \\\theta\\ is an affine function of
\\\phi\\,

\\ \theta = T\\(\phi + c_0), \qquad T = I + C, \qquad
C\_{k_m(v),\\k_a(v,c)} = -\bar x_c, \qquad (c_0)\_{k_m(v)} = \bar x_v ,
\\

where \\k_m(v)\\ is the position of \\v\\’s intercept in the parameter
vector and \\k_a(v, c)\\ that of the path from \\c\\ to \\v\\. \\C\\ has
nonzero entries only in the rows of intercepts and the columns of paths,
and \\c_0\\ only at intercepts. When no intercept shares a label with a
path (condition 3 of Section 5), no intercept position is also a path
position, so \\C c_0 = 0\\ and \\C^2 = 0\\. Hence \\T^{-1} = I - C\\,
which gives \\\phi = \theta - C\theta - c_0\\. The helpers
`.sem_center_map()` and `.sem_to_phi()` build exactly this:

``` r
ctr <- medfit:::.sem_center_map(ram, smp)
dimnames(ctr$t) <- dimnames(ctr$c) <- list(ram$par_names, ram$par_names)
shifted_rows <- c("mediator1~1", "outcome~1")
cat("The rows of T that differ from the identity (columns: the paths):\n")
```

    The rows of T that differ from the identity (columns: the paths):

``` r
rd(ctr$t[shifted_rows, c("a", "b", "cp")], 3)
```

                       a        b       cp
    mediator1~1 -100.502    0.000    0.000
    outcome~1      0.000 -100.384 -100.502

``` r
dev <- ctr$t - diag(ram$q)
dev[shifted_rows, c("a", "b", "cp")] <- 0
cat("\nEvery other entry of T equals the identity: largest deviation =", max(abs(dev)), "\n")
```


    Every other entry of T equals the identity: largest deviation = 0 

``` r
cat("\nc0 (the sample means, at the intercepts)\n")
```


    c0 (the sample means, at the intercepts)

``` r
rd(stats::setNames(ctr$c0, ram$par_names)[c("mediator1~1", "treatment~1", "outcome~1")], 3)
```

    mediator1~1 treatment~1   outcome~1
        100.384     100.502     300.526 

Read the two rows: the row `mediator1~1` has \\-\bar
x\_{\text{treatment}}\\ in the column of `a`, since `mediator1`’s only
path comes from `treatment`; the row `outcome~1` has \\-\bar
x\_{\text{mediator1}}\\ and \\-\bar x\_{\text{treatment}}\\ in the
columns of `b` and `cp`. Check the algebra, and check that at the fitted
values the centered intercepts are near zero:

``` r
tinv <- diag(ram$q) - ctr$c
phi <- medfit:::.sem_to_phi(theta, ctr)
c(T_times_inverse = max(abs(ctr$t %*% tinv - diag(ram$q))),
  round_trip = max(abs(as.vector(ctr$t %*% (phi + ctr$c0)) - theta)))
```

    T_times_inverse      round_trip
                  0               0 

``` r
rd(stats::setNames(phi, ram$par_names)[c("mediator1~1", "treatment~1", "outcome~1")], 8)
```

    mediator1~1 treatment~1   outcome~1
              0           0           0 

The intercepts of `mediator1` and `outcome` in \\\phi\\ are zero to 8
decimals (the `treatment` intercept has no path entering it, so \\\tilde
m\\ equals \\m - \bar x\\ and it is zero because the free mean of an
exogenous variable is its sample mean). This is no accident, and Section
5 explains it.

## 4. Information and covariance in the new coordinates

Because \\\theta = T(\phi + c_0)\\ is affine, the gradient and Hessian
of the discrepancy follow by the chain rule. For \\F(\phi) =
F\_{ML}(T(\phi + c_0))\\, \\\nabla\_\phi F = T^\top \nabla\_\theta F\\
and \\\nabla^2\_\phi F = T^\top (\nabla^2\_\theta F)\\T\\ (there is no
term from the second derivative of the map, because it is affine). So
the information in the new coordinates is \\I\_\phi = T^\top I\_\theta
T\\, and the covariance of the estimates transforms in the opposite
direction:

\\ I\_\phi = T^\top I\_\theta\\ T \qquad\Longleftrightarrow\qquad
V\_\theta = I\_\theta^{-1} = T\\ I\_\phi^{-1}\\ T^\top = T\\ V\_\phi\\
T^\top . \\

The engine builds \\I\_\phi\\ (`.sem_info_expected(..., ctr)` for the
expected information; the observed one takes the Hessian directly in
\\\phi\\, along the columns of \\T\\), inverts it, and maps back. The
mean part of \\I\_\phi\\ uses \\\partial\mu/\partial\phi\\, the
derivative of Section 2 with the path columns changed to \\F B e_r\\\[(B
m)\_c - \bar x_c\]\\. The bracket is the gap between the implied and the
sample mean of \\c\\, which is close to zero at the fit, so the two
nearly parallel columns of Section 2 have been pulled apart. See the
conditioning, and check the identity on the `mid` data, where the raw
matrix can still be inverted:

``` r
info_phi <- medfit:::.sem_info_expected(theta, ram, smp, ctr)
c(raw = rcond_scaled(info_raw), centered = rcond_scaled(info_phi))
```

             raw     centered
    3.947868e-06 6.566856e-01 

``` r
v_phi <- solve(info_phi)
v_back <- ctr$t %*% v_phi %*% t(ctr$t)
c(
  chain_rule = max(abs(info_phi - t(ctr$t) %*% info_raw %*% ctr$t)) / max(abs(info_phi)),
  V_equals_T_Vphi_Tt = max(abs(v_back - solve(info_raw))) / max(abs(v_back)),
  engine_vcov = max(abs(v_back - fit_mid@vcov)) / max(abs(v_back))
)
```

            chain_rule V_equals_T_Vphi_Tt        engine_vcov
          3.002781e-13       1.363772e-11       3.644666e-35 

The centered information is well conditioned, the chain rule holds to
rounding, and the covariance the engine reports equals \\T V\_\phi
T^\top\\. At `big` scale there is no raw inverse to compare with, but
the centered route still works. Its path and variance standard errors
were already shown in Section 1 to equal those of the original data, and
its conditioning is:

``` r
ctr_b <- medfit:::.sem_center_map(ram_b, smp_b)
c(raw = rcond_scaled(info_raw_b),
  centered = rcond_scaled(medfit:::.sem_info_expected(fit_big@theta, ram_b, smp_b, ctr_b)))
```

             raw     centered
    2.016914e-09 7.919246e-01 

### The same comparison against lavaan and OpenMx

On the `mid` data every package can invert its information. We compare
the nine standard errors with lavaan’s from the same information
(expected, then observed) and with OpenMx’s, which come from a numerical
Hessian and so correspond to the observed information:

``` r
f_exp <- fit_sem(syntax, mid, meanstructure = TRUE, information = "expected")
f_obs <- fit_sem(syntax, mid, meanstructure = TRUE, information = "observed")
lv_exp <- lavaan::sem(syntax, mid, meanstructure = TRUE, fixed.x = FALSE, information = "expected")
lv_obs <- lavaan::sem(syntax, mid, meanstructure = TRUE, fixed.x = FALSE, information = "observed")

vars <- names(mid)
mod_mid <- mxModel(
  "mid", type = "RAM", manifestVars = vars,
  mxPath(from = "treatment", to = "mediator1", values = 0.4, labels = "a"),
  mxPath(from = c("mediator1", "treatment"), to = "outcome", values = 0.5, labels = c("b", "cp")),
  mxPath(from = vars, arrows = 2, values = 1, labels = paste0("v_", vars)),
  mxPath(from = "one", to = vars, values = colMeans(mid), labels = paste0("m_", vars)),
  mxData(mid, type = "raw")
)
run_mid <- mxRun(mod_mid, silent = TRUE)
pt_mid <- summary(run_mid)$parameters
se_mx <- stats::setNames(pt_mid$Std.Error, pt_mid$name)
mx_name <- c(a = "a", b = "b", cp = "cp", "mediator1~~mediator1" = "v_mediator1",
             "outcome~~outcome" = "v_outcome", "treatment~~treatment" = "v_treatment",
             "mediator1~1" = "m_mediator1", "treatment~1" = "m_treatment", "outcome~1" = "m_outcome")
nm <- names(mx_name)
rel <- function(x, y) max(abs(x - y) / y)
c(
  `expected: medfit vs lavaan` = rel(sqrt(diag(f_exp@vcov))[nm], sqrt(diag(lavaan::vcov(lv_exp)))[nm]),
  `observed: medfit vs lavaan` = rel(sqrt(diag(f_obs@vcov))[nm], sqrt(diag(lavaan::vcov(lv_obs)))[nm]),
  `observed: medfit vs OpenMx` = rel(sqrt(diag(f_obs@vcov))[nm], se_mx[mx_name])
)
```

    expected: medfit vs lavaan observed: medfit vs lavaan
                  8.396106e-12               1.860648e-09
    observed: medfit vs OpenMx
                  7.111496e-05 

Each entry is the largest relative difference over the nine standard
errors.

## 5. The shifted-data fit, and why it is exact

The centered coordinates fix the information. The engine goes one step
further when it can: it fits the model to data from which the sample
means have been subtracted, and maps the solution back. Why is that
allowed? Here is the argument, in three steps.

**Step 1: profile out the intercepts.** Suppose every observed variable
has its own free, unconstrained intercept. For any fixed paths \\A\\ and
variances \\S\_{\text{ram}}\\, choose \\m = (I - A)\bar x\\ (with \\\bar
x\\ padded with zeros for latent variables, which this argument excludes
below). Then \\\mu = F B m = F B (I - A) \bar x = F\bar x = \bar x\\.
The gap \\d = \bar x - \mu\\ of Chapter 1 is zero, so the mean term
vanishes, which is its smallest possible value. So for each \\(A,
S\_{\text{ram}})\\ the best intercepts are those, and the discrepancy
that remains,

\\ \min_m F\_{ML}(A, S\_{\text{ram}}, m) = \log\|\Sigma\| +
\operatorname{tr}(\Sigma^{-1} S) - \log\|S\| - p, \\

involves the data only through \\S\\, the sample covariance.

**Step 2: \\S\\ does not change under a shift.** Subtracting \\\bar x\\
from every row changes the means and leaves the covariance matrix alone.
So the profile function, and therefore the minimizing \\(A,
S\_{\text{ram}})\\, are the same for the original and the centered data.

**Step 3: map the intercepts back.** On the centered data the sample
mean is 0, and the intercepts that solve Step 1 are \\\tilde m = (I - A)
\cdot 0 = 0\\: the centered fit has \\\tilde m = 0\\ at the optimum, as
Section 3 saw. On the original data they are \\m = (I - A)\bar x\\,
which is \\\theta = T(\phi + c_0)\\ with \\\phi\\ the centered solution
(for variable \\v\\, \\m_v = \tilde m_v + \bar x_v - \sum_c A\_{v c}\bar
x_c\\).

This also explains the \\\phi\\ values in Section 3 and gives something
to check: the mean-structure fit has no mean discrepancy left, and its
paths and variances equal those of the covariance-only fit.

``` r
# a model with one restriction (df = 1), so the discrepancy is not zero
restricted <- paste0(syntax, "cp == 0\n")
fit_cov <- fit_sem(restricted, big)                              # no intercepts: covariance only
fit_ms <- fit_sem(restricted, big, meanstructure = TRUE)         # with free intercepts
ram_r <- fit_ms@internals$ram
gap <- colMeans(fit_ms@data) - medfit:::.sem_implied_mean(ram_r, fit_ms@theta)
common <- names(fit_cov@theta)
c(F_covariance_only = fit_cov@f, F_with_means = fit_ms@f,
  largest_difference_in_shared_estimates = max(abs(fit_ms@theta[common] - fit_cov@theta)),
  mean_gap_xbar_minus_mu = max(abs(gap)))
```

                         F_covariance_only                           F_with_means
                              3.336570e-04                           3.336570e-04
    largest_difference_in_shared_estimates                 mean_gap_xbar_minus_mu
                              4.356765e-24                           0.000000e+00 

The two discrepancies are the same nonzero number, the shared estimates
agree, and the mean gap \\\bar x - \mu\\ is zero (to the tolerance of
the optimizer), on data whose means are 1,000 to 100,000 units from
zero.

Now the shifted fit itself, on the unrestricted model. Fit the centered
data, map the solution back with \\T(\phi + c_0)\\, and compare with
`fit_big`:

``` r
centered <- as.data.frame(scale(big, center = TRUE, scale = FALSE))
fit_c <- fit_sem(syntax, centered, meanstructure = TRUE)
c0_b <- ctr_b$c0
back <- as.vector(ctr_b$t %*% (fit_c@theta + c0_b))
cat("centered-data intercepts (phi):\n")
```

    centered-data intercepts (phi):

``` r
rd(fit_c@theta[c("mediator1~1", "treatment~1", "outcome~1")], 10)
```

    mediator1~1 treatment~1   outcome~1
              0           0           0 

``` r
c(largest_difference_after_mapping_back = max(abs(back - fit_big@theta)))
```

    largest_difference_after_mapping_back
                             4.440892e-16 

The intercepts on the centered data are zero, and the mapped-back
solution equals `fit_big`. That comparison only shows that we reproduced
the engine’s route, since `fit_big` itself came out of the shifted path.
The independent check is the refused-shift comparison below, which fits
the same data without the shift.

### When the shift is allowed

Step 1 needs every intercept to be free to take the value \\(I - A)\bar
x\\, and the back-map of Step 3 needs the paths to carry the shift
through \\T\\. `.sem_shift_ok()` in `R/sem-fit.R` checks, in this order:

1.  the model has a mean structure, and some free intercept belongs to a
    variable that has a free path entering it (otherwise there is no map
    to undo);
2.  every free intercept is its own parameter (no shared label), none
    has a user start value, and none has a bound;
3.  every observed variable has a free intercept or, under `fixed_x`
    (Chapter 4), a mean held at its sample value, and no intercept
    shares a label with a path;
4.  there is no fixed nonzero path, and every free path enters an
    observed variable (a path into a latent variable cannot absorb the
    shift, because the latent mean is fixed at 0; a latent variable’s
    marker loading is also a fixed nonzero path);
5.  no intercept appears in a constraint.

Constraints on paths and variances are allowed, because the argument
never touches them. We test the rule by building each situation and
asking the function, replicating the first steps of
[`fit_sem()`](https://data-wise.github.io/medfit/reference/fit_sem.md)
to get its arguments:

``` r
shift_ok <- function(text, data, meanstructure = TRUE) {
  parsed <- medfit:::.sem_parse(text)
  tab <- medfit:::.sem_complete(parsed$parameters, meanstructure)
  conv <- medfit:::.sem_to_ram(tab)
  r <- conv$ram
  s <- medfit:::.sem_sample(data[, r$obs], r)
  given <- !is.na(conv$start)
  lb <- ifelse(is.na(conv$lower), -Inf, conv$lower)
  ub <- ifelse(is.na(conv$upper), Inf, conv$upper)
  medfit:::.sem_shift_ok(r, s, parsed$constraints, lb, ub, given)
}
cases <- c(
  "all intercepts free" = syntax,
  "constraint on paths (a == b)" = paste0(syntax, "\na == b"),
  "outcome ~ 0*1 (a fixed intercept)" = paste0(syntax, "\noutcome ~ 0*1"),
  "an intercept in a constraint" = paste0(syntax, "\nmediator1 ~ k*1\nk == 5"),
  "a start value on an intercept" = paste0(syntax, "\nmediator1 ~ start(5)*1"),
  "a bound on an intercept" = paste0(syntax, "\nmediator1 ~ lower(0)*1"),
  "one label on two intercepts" = paste0(syntax, "\nmediator1 ~ k*1\noutcome ~ k*1"),
  "an intercept sharing a path's label" = paste0(syntax, "\nmediator1 ~ a*1"),
  "a fixed nonzero path" = "mediator1 ~ a * treatment\noutcome ~ b * mediator1 + 0.5 * treatment",
  "a latent variable (and a path into it)" = "M =~ mediator1 + outcome\nM ~ treatment"
)
allowed <- vapply(cases, shift_ok, NA, data = mid)
data.frame(model = names(cases), shift_allowed = allowed, row.names = NULL)
```

                                        model shift_allowed
    1                     all intercepts free          TRUE
    2            constraint on paths (a == b)          TRUE
    3       outcome ~ 0*1 (a fixed intercept)         FALSE
    4            an intercept in a constraint         FALSE
    5           a start value on an intercept         FALSE
    6                 a bound on an intercept         FALSE
    7             one label on two intercepts         FALSE
    8     an intercept sharing a path's label         FALSE
    9                    a fixed nonzero path         FALSE
    10 a latent variable (and a path into it)         FALSE

``` r
shift_ok(syntax, mid, meanstructure = FALSE)
```

    [1] FALSE

The last line is the model without a mean structure (condition 1): there
are no intercepts to profile, and the answer is `FALSE`.

### What happens when the shift is refused

A refusal does not mean failure. The engine then optimizes in the
original coordinates, with the same **acceptance gate** (the engine’s
test, applied to every solution, that the solver really stopped at a
minimum; Chapter 3 derives it, and it still uses the centered Hessian
when a mean structure is present) and, for a model without constraints,
a Newton polish in the centered coordinates after the solver stops
(`.sem_polish_centered()`, which takes a few Newton steps on the
centered Hessian). To see it, give the `mediator1` intercept a start
value (an innocuous request that condition 2 refuses) and compare with
the shifted fit, on both data sets:

``` r
compare_refused <- function(d) {
  fast <- fit_sem(syntax, d, meanstructure = TRUE)
  start_txt <- paste0(syntax, "\nmediator1 ~ start(", round(mean(d$mediator1) * 0.95), ")*1")
  slow <- fit_sem(start_txt, d)
  data.frame(shift_allowed_default = shift_ok(syntax, d), shift_allowed_with_start = shift_ok(start_txt, d),
             largest_estimate_difference = max(abs(fast@theta - slow@theta[names(fast@theta)])))
}
refused <- rbind(mid = compare_refused(mid), big = compare_refused(big))
refused
```

        shift_allowed_default shift_allowed_with_start largest_estimate_difference
    mid                  TRUE                    FALSE                3.552714e-14
    big                  TRUE                    FALSE                2.775558e-16

The two routes return the same estimates, so the shift is an
optimization and not a requirement. What it buys is a better-behaved
problem for the solver. To see that, run SLSQP (the solver, Chapter 3)
once on each version of the data from the engine’s default start, and
judge each solution with the engine’s acceptance gate. The gate builds
the curvature in centered coordinates in both cases, so it can judge the
raw-coordinate solution fairly:

``` r
opts <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = 10000L)
solve_once <- function(d, centered) {
  f <- fit_sem(syntax, d, meanstructure = TRUE)
  r0 <- f@internals$ram
  dd <- if (centered) as.data.frame(scale(d, scale = FALSE)) else d
  sm <- medfit:::.sem_sample(dd, r0)
  lb <- rep(-Inf, r0$q)
  ub <- rep(Inf, r0$q)
  res <- medfit:::.sem_solve_one(medfit:::.sem_default_start(r0, sm), r0, sm, lb, ub, opts)
  gate <- medfit:::.sem_gate(res$solution, res$status, r0, sm, lb, ub)
  data.frame(nlopt_status = res$status, iterations = res$iterations, accepted = gate$accepted,
             newton_decrement = signif(gate$decrement, 2))
}
runs <- rbind(mid_original = solve_once(mid, FALSE), mid_centered = solve_once(mid, TRUE),
              big_original = solve_once(big, FALSE), big_centered = solve_once(big, TRUE))
runs
```

                 nlopt_status iterations accepted newton_decrement
    mid_original            4         64     TRUE          6.9e-11
    mid_centered            4         31     TRUE          3.0e-10
    big_original            4         86     TRUE          1.2e-08
    big_centered            4         35     TRUE          9.2e-09

All four runs are accepted. The Newton decrement is the gate’s measure
of how far the solution is from a stationary point (the gradient
measured in the units of the curvature; Chapter 3 defines it), and it is
far below the gate’s threshold of \\10^{-3}\\ in every run. The status
column gives the reason the solver stopped (3: the objective stopped
changing; 4: the parameters stopped moving). The centered data need
fewer iterations at both scales, although the engine already rescales
every parameter by its natural unit before calling the solver (Chapter
3), which removes much of the difference in units.

## Check yourself

1.  Add 50 to every value of `outcome`. Which of the following change:
    the path \\b\\, the variance of `outcome`, the intercept of
    `outcome`, the standard error of \\b\\? (Answer: only the intercept;
    the chunk after this list runs it.)
2.  Why does condition 3 say “every observed variable”? (Answer: Step 1
    sets \\\mu = \bar x\\ for all observed variables at once; one fixed
    intercept leaves a mean gap that depends on the location of the
    data.)
3.  Why is \\C^2 = 0\\? (Answer: \\C\\ has nonzero columns only at path
    parameters and nonzero rows only at intercept parameters, and when
    no intercept shares a label with a path, which the shift requires,
    no position is both.)

``` r
moved <- fit_sem(syntax, transform(base, outcome = outcome + 50), meanstructure = TRUE)
orig <- fit_sem(syntax, base, meanstructure = TRUE)
rd(moved@theta - orig@theta, 6)
```

                       a                    b                   cp
                       0                    0                    0
    mediator1~~mediator1     outcome~~outcome treatment~~treatment
                       0                    0                    0
             mediator1~1          treatment~1            outcome~1
                       0                    0                   50 

``` r
rd(sqrt(diag(moved@vcov)) - sqrt(diag(orig@vcov)), 6)
```

                       a                    b                   cp
                       0                    0                    0
    mediator1~~mediator1     outcome~~outcome treatment~~treatment
                       0                    0                    0
             mediator1~1          treatment~1            outcome~1
                       0                    0                    0 

The first line is the change in each estimate and the second the change
in each standard error, after adding 50 to `outcome`: the intercept of
`outcome` moves by 50 and nothing else does, not even a standard error.
(The standard error of an intercept depends on where the *predictors*
sit, as Section 1 showed by shifting them; this shift leaves them
alone.)

## Where next

[Chapter
3](https://data-wise.github.io/medfit/articles/native-book-3-constraints.md)
adds constraints: how the solver is handed them, how it decides a
solution is good, and how the engine polishes it.
