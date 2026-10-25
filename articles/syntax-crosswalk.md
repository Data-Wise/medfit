# One model in medfit, lavaan, OpenMx and semopy

medfit’s quality control checks the native engine against independent
SEM software ([Quality control of the
optimizer](https://data-wise.github.io/medfit/articles/quality-control.md)).
This page writes the same simple mediation model in each package’s own
syntax, so the comparisons can be read and rerun. The lavaan and OpenMx
blocks run when the site is built and stop the build if they drift from
medfit. The semopy block is Python: its script and its output are saved
in the package (`tests/sim/oracles/`), and the build checks the saved
output against medfit.

The model: `treatment` affects `mediator1` (path `a`), `mediator1`
affects `outcome` (path `b`), and `treatment` affects `outcome` directly
(path `cp`), on the bundled `mediation_demo` data (n = 400).

|  | medfit | lavaan | OpenMx | semopy 2.3.11 |
|----|----|----|----|----|
| Label a path | `mediator1 ~ a*treatment` | `mediator1 ~ a*treatment` | `mxPath(..., labels = "a")` | `mediator1 ~ a*treatment` |
| Indirect effect | `ab := a*b` | `ab := a*b` | `mxAlgebra(a * b, name = "ab")` | not in the syntax: `:=` is an unknown command; compute `a * b` from the estimates |
| Exogenous variance | estimated; `fixed_x = TRUE` fixes it | fixed by default; `fixed.x = FALSE` estimates it | estimated when you write its path | not estimated (no row in the output) |
| Tight convergence | default | default | `mxOption()` tolerances (defaults stop up to about 5.5e-6 away) | `options = {"ftol": 1e-12}` (the default stops about 4e-5 away) |

In medfit 0.15.0 the native defaults become `fixed_x` = the exogenous
observed variables and `meanstructure = TRUE`, so the exogenous variance
row will be fixed by default, as in lavaan.

## medfit

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
model <- "
  mediator1 ~ a*treatment
  outcome ~ b*mediator1 + cp*treatment
  ab := a*b
"
native <- tidy(fit_sem(model, mediation_demo))
native[, c("term", "estimate", "std_error")]
```

    # A tibble: 7 × 3
      term                 estimate std_error
      <chr>                   <dbl>     <dbl>
    1 a                      0.456     0.108
    2 b                      0.713     0.0505
    3 cp                     0.0406    0.111
    4 mediator1~~mediator1   1.16      0.0819
    5 outcome~~outcome       1.18      0.0835
    6 treatment~~treatment   0.250     0.0177
    7 ab                     0.325     0.0802

## lavaan

``` r
library(lavaan)
```

    This is lavaan 0.7-3
    lavaan is FREE software! Please report any bugs.

``` r
lav <- parameterEstimates(sem(model, mediation_demo, fixed.x = FALSE))
lav[lav$label %in% c("a", "b", "cp", "ab"), c("label", "est", "se")]
```

      label   est    se
    1     a 0.456 0.108
    2     b 0.713 0.050
    3    cp 0.041 0.111
    7    ab 0.325 0.080

The [lavaan
comparison](https://data-wise.github.io/medfit/articles/lavaan-comparison.md)
covers the rest of the overlap and where the two differ by design.

## OpenMx

OpenMx describes the model as paths in a RAM model. The data are the
sample covariance matrix with `numObs` set to n, the maximum-likelihood
fit medfit uses;
[`compare_lr()`](https://data-wise.github.io/medfit/reference/compare_lr.md)
builds its OpenMx models the same way (from the raw data the fit used
when the fit has a mean structure).

``` r
library(OpenMx)
```

    To take full advantage of multiple cores, use:
      mxOption(key='Number of Threads', value=parallel::detectCores()) #now
      Sys.setenv(OMP_NUM_THREADS=parallel::detectCores()) #before library(OpenMx)

``` r
old <- c(mxOption(NULL, "Optimality tolerance"), mxOption(NULL, "Feasibility tolerance"),
         mxOption(NULL, "Function precision"))
mxOption(NULL, "Optimality tolerance", 1e-12)
mxOption(NULL, "Feasibility tolerance", 1e-12)
mxOption(NULL, "Function precision", 1e-15)
vars <- c("treatment", "mediator1", "outcome")
omx <- mxModel(
  "simple", type = "RAM", manifestVars = vars,
  mxPath(from = "treatment", to = "mediator1", labels = "a"),
  mxPath(from = "mediator1", to = "outcome", labels = "b"),
  mxPath(from = "treatment", to = "outcome", labels = "cp"),
  mxPath(from = vars, arrows = 2, values = 1, labels = c("v_x", "v_m", "v_y")),
  mxAlgebra(a * b, name = "ab"),
  mxData(observed = cov(mediation_demo[, vars]), type = "cov", numObs = nrow(mediation_demo))
)
omx <- mxRun(omx, silent = TRUE)
omx_est <- summary(omx)$parameters
omx_est[omx_est$name %in% c("a", "b", "cp"), c("name", "Estimate", "Std.Error")]
```

      name   Estimate Std.Error
    1    a 0.45599630 0.1076345
    2   cp 0.04057664 0.1110597
    3    b 0.71342866 0.0504720

``` r
mxEval(ab, omx)
```

              [,1]
    [1,] 0.3253208

## semopy (Python)

[semopy](https://pypi.org/project/semopy/) reads lavaan-style syntax. It
is not one of medfit’s quality-control oracles yet; this is the script
that would be one, saved as `tests/sim/oracles/semopy-simple.py`:

``` python
# The simple mediation model in semopy, for the syntax crosswalk article (vignettes/articles/syntax-crosswalk.qmd).
# Run from the package root:
#   Rscript -e 'write.csv(medfit::mediation_demo, "mediation_demo.csv", row.names = FALSE)'
#   uv run --with semopy==2.3.11 python -I tests/sim/oracles/semopy-simple.py mediation_demo.csv \
#     > tests/sim/oracles/semopy-simple.csv
# semopy's default SLSQP stop leaves the estimates about 4e-5 from the optimum; ftol = 1e-12 removes that.
import sys

import pandas as pd
import semopy

data = pd.read_csv(sys.argv[1])
model = semopy.Model("""
mediator1 ~ a*treatment
outcome ~ b*mediator1 + cp*treatment
""")
model.fit(data, obj="MLW", options={"ftol": 1e-12})
out = model.inspect()[["lval", "op", "rval", "Estimate", "Std. Err"]]
out.columns = ["lhs", "op", "rhs", "estimate", "std_error"]
out.insert(0, "semopy", semopy.__version__)
out.to_csv(sys.stdout, index=False, float_format="%.12g")
```

Its output from semopy 2.3.11 (2026-10-24), saved as
`tests/sim/oracles/semopy-simple.csv`, next to medfit with
`fixed_x = TRUE`, which matches semopy’s treatment of the exogenous
variable:

``` r
semopy <- read.csv(file.path(oracles, "semopy-simple.csv"))
labels <- c("mediator1~treatment" = "a", "outcome~mediator1" = "b", "outcome~treatment" = "cp")
key <- paste0(semopy$lhs, semopy$op, semopy$rhs)
semopy$term <- ifelse(key %in% names(labels), labels[key], key)
stopifnot(nrow(semopy) == 5)
fixed <- tidy(fit_sem(model, mediation_demo, fixed_x = TRUE))
both <- merge(semopy[, c("term", "estimate", "std_error")],
              fixed[, c("term", "estimate", "std_error")], by = "term",
              suffixes = c("_semopy", "_medfit"))
both
```

                      term estimate_semopy std_error_semopy estimate_medfit
    1                    a      0.45599616       0.10763362      0.45599612
    2                    b      0.71342892       0.05047200      0.71342873
    3                   cp      0.04057561       0.11106055      0.04057665
    4 mediator1~~mediator1      1.15847060       0.08191624      1.15847022
    5     outcome~~outcome      1.18044581       0.08347012      1.18044625
      std_error_medfit
    1       0.10763360
    2       0.05047202
    3       0.11106057
    4       0.08191621
    5       0.08347015

``` r
stopifnot(max(abs(both$estimate_semopy - both$estimate_medfit)) < 1e-5,
          max(abs(both$std_error_semopy - both$std_error_medfit)) < 1e-5)
```

With semopy’s default stopping rule the same script gives `a` = 0.456039
instead of 0.455996, a gap of about 4e-5, which is why the script sets
`ftol`. Comparing software at 1e-6 means first checking that each one
has actually converged.
