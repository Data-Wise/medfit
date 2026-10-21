# What changed in medfit 0.11.0 and 0.11.1

This is a practical guide to the changes recorded in
[NEWS](https://github.com/data-wise/medfit/blob/dev/NEWS.md). The native
engine’s public interface graduated from experimental status in 0.11.0;
the later fixes improve the reliability and interpretation of its
results. Examples use the bundled `mediation_demo` data. Native fits are
marked `eval: false` because optimization can take longer than a quick
site build.

## Reproducible bootstrap resamples (0.11.1)

**What:** Nonparametric row and cluster resample indices are drawn in
the calling R process before refits are sent to workers. **Why:** A
fixed `seed` now selects the same resamples and `boot_estimates`
regardless of `ncores`. Sequential statistics that do not draw random
numbers retain the 0.11.0 stream. A statistic that draws its own random
numbers is outside this guarantee; its sequential stream changes because
those draws follow all resample draws. The pre-drawn indices also use
memory proportional to the number of rows times the number of
replicates. See `R/bootstrap.R`.

``` r

library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r

stat <- function(d) mean(d$mediator1)
a <- bootstrap_mediation(stat, method = "nonparametric",
                         data = mediation_demo, n_boot = 12, seed = 41)
b <- bootstrap_mediation(stat, method = "nonparametric",
                         data = mediation_demo, n_boot = 12, seed = 41,
                         parallel = TRUE, ncores = 2)
identical(a@boot_estimates, b@boot_estimates)
```

    [1] TRUE

For cluster resampling, pass `cluster = "school"` on data with a school
column. Each draw gets a new cluster ID, including repeated draws of one
school.

## Interpretable model comparisons (0.11.1)

**What:** [`anova()`](https://rdrr.io/r/stats/anova.html) attaches a
named logical `p_valid` attribute. Its first row is `NA`; a test whose
null lies on a boundary is `FALSE`. The printed p-value and boundary
warning remain, but the usual chi-square reference is invalid there.
**Why:** Programs can check validity without parsing a warning. It also
refuses pairs with a nonzero fixed parameter on one side and an absent
row on the other: those models are not nested. Fixing a parameter that
was free in the larger model remains a valid restriction. See
`R/sem-anova.R`.

``` r

base <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
full <- fit_sem(base, mediation_demo)
restricted <- fit_sem(paste(base, "a == 0", sep = "\n"), mediation_demo)
comparison <- anova(full, restricted)
attr(comparison, "p_valid")
```

``` r

# The covariance is fixed at 0.5 in one model but absent (zero) in the other.
with_fixed_covariance <- fit_sem(
  paste(base, "mediator1 ~~ 0.5*outcome", "a == 0", sep = "\n"),
  mediation_demo)
try(anova(full, with_fixed_covariance))
```

## Optimum diagnostics (0.11.1)

**What:** `SEMFit@diagnostics$optimum` records `n_starts`, `n_accepted`,
`best_of`, `certified`, `spread`, and `status`. **Why:** A nonlinear
constraint can have several feasible branches. The engine tries every
start, keeps the lowest discrepancy among accepted solutions, and warns
when accepted starts disagree or only one succeeds. `certified` means a
feasible unconstrained reference provides a lower bound attained by the
constrained fit; otherwise `status` can be `single`, `disagreed`, or
`agreed`. An ordinary fit reports `unique`. `spread` is the range of
accepted discrepancies, or `NA` when there is no comparison. See
`R/sem-optim.R`.

``` r

nonlinear <- fit_sem(paste(base, "a*b > 0.01", sep = "\n"),
                     mediation_demo)
nonlinear@diagnostics$optimum[c("n_starts", "n_accepted", "best_of",
                                "certified", "spread", "status")]
```

## Factors and the native engine’s gate (0.11.0)

**What:** Factor, character, and logical covariates on the right side of
native regressions expand to reference-coded 0/1 columns before missing
rows are removed. `fixed_x` can fix all dummies;
[`mbco_sem()`](https://data-wise.github.io/medfit/reference/mbco_sem.md)
retains their map across refits. Ordered factors, a categorical
treatment or mediator, a label on the whole factor, and a product of two
factors are refused. **Why:** The explicit dummies keep the covariance
model and refits consistent. The native engine is now a supported public
interface with a frozen syntax and API contract. See `R/sem-fit.R` and
[the factor model
guide](https://data-wise.github.io/medfit/articles/model-native-factors.md).

``` r

d <- transform(mediation_demo,
               group = cut(covariate1, c(-Inf, 0, Inf), labels = c("low", "high")))
fit <- fit_sem(paste("mediator1 ~ a*treatment + group",
                     "outcome ~ b*mediator1 + cp*treatment + group", sep = "\n"), d)
head(fit@table)
```

**What:** For nonlinear constraints, the solver now floors variances
that occur in the constraint relative to their natural units, adds the
unconstrained fit and sign-flipped copies as starts, and will not
replace a feasible reference with a worse accepted point. A single
accepted start warns. **Why:** A solver could previously stop on the
wrong sign branch or step to an invalid variance. Other fits keep their
previous optimization path. See `R/sem-optim.R`.

``` r

gated <- fit_sem(paste(base, "cp == a*b", sep = "\n"), mediation_demo)
gated@diagnostics[c("decrement", "sign_check", "optimum")]
```

Other 0.11.0 changes include population-average four-way SEs when
`options(medfit.covariate_mean_variance = TRUE)`, a moment-based
fallback start, development-S7 load compatibility, and refusal to
compare AIC/BIC across different observed variable sets. The [worked GPA
example](https://data-wise.github.io/medfit/articles/example-gpa.md)
provides independent numerical comparisons.

## How robustness is checked

The four layers inspect different failure modes; they are development
tests, not user-facing switches. The [optimizer
plan](https://github.com/data-wise/medfit/blob/dev/planning/specs/PLAN-optimizer-robustness-2026-10-20.md)
describes the design, while the current tests and `tests/sim/gates.csv`
record later implementation. Metamorphic tests change units, row order,
syntax order, redundant constraints, and starts and check the
corresponding invariant. `nloptr` fault injection supplies bad statuses,
nonfinite or inconsistent output, and thrown errors to test rejection
and retries. An edge-case grid exercises near-singularity, bounds, rank,
and extreme scales. A seeded randomized sweep compares 180 cases with
independent OLS or profile oracles. Its recorded baseline, in
**correct/refused/flagged/wrong** order, is:

| Family | Correct | Refused | Flagged | Wrong |
|:-------|--------:|--------:|--------:|------:|
| A      |      53 |       0 |       7 |     0 |
| B      |      60 |       0 |       0 |     0 |
| C      |      17 |       0 |      43 |     0 |

“Flagged” means an explicit warning or optimum diagnostic, not an
independent proof of correctness. The sweep is an expensive development
gate; this short example inspects one fit’s user-visible verdict:

``` r

fit <- fit_sem(base, mediation_demo)
fit@diagnostics$optimum$status
```
