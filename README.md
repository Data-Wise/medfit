# medfit: Infrastructure for Mediation Analysis in R

[![CRAN status](https://www.r-pkg.org/badges/version/medfit)](https://CRAN.R-project.org/package=medfit)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![R-CMD-check](https://github.com/Data-Wise/medfit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Data-Wise/medfit/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/Data-Wise/medfit/graph/badge.svg)](https://app.codecov.io/gh/Data-Wise/medfit)
[![pkgdown](https://github.com/Data-Wise/medfit/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/Data-Wise/medfit/actions/workflows/pkgdown.yaml)

<!-- badges: start -->
[![r-universe](https://data-wise.r-universe.dev/badges/medfit)](https://data-wise.r-universe.dev/medfit)
<!-- badges: end -->


**medfit** fits mediation models, pulls out the paths, and gives you effects with
intervals. One call to start; the same objects and functions work for every
model, from one mediator to a latent variable.

> **In one line:** `med()` runs a mediation analysis, `quick()` prints it, and
> `nie()`, `nde()`, `te()`, `pm()` and `tidy()` read it.

## What's new

| Version | What you get |
|---|---|
| **0.14.1** | The outcome ledger for native fits: every zero-product branch and `mbco_sem()` null keeps its outcome (`fit@diagnostics$ledger`, `$ledger` on the errors); literal `a == 0` / nonzero contradictions are certified empty, not fitted; branch maps and an overflow-safe 64-branch cap; a covariance-stage failure is a typed error (`medfit_sem_covariance_error`) that `mbco_sem()` retains for a null. A literal contradiction now stops before the optimizer (see NEWS). |
| **0.14.0** | Notice for the 0.15.0 native defaults (`fixed_x = TRUE`, `meanstructure = TRUE`): a native fit that leaves either unset warns once per session (no result changes); `options(medfit.native_defaults = "0.15")` opts in early; the [0.15.0 defaults article](https://data-wise.github.io/medfit/articles/native-defaults-0-15.html) explains both settings and how dependent packages keep today's results. |
| **0.13.0** | A roundoff-limited restoration's objective rise is capped, so a worse point can no longer stand and inflate a likelihood-ratio statistic; a refit the optimizer cannot fit is an unresolved result (`mbco_sem()`, `compare_lr()`) instead of an error or a silent answer, and a zero-product branch that cannot be fitted stops `fit_sem()` with an error instead of returning a partial fit. |
| **0.12.0** | `compare_lr()` runs the product-null LR (`a*b == 0`) in lavaan or OpenMx and compares it with `mbco_sem()`, warning only on observed evidence (a dropped constraint, a statistic above medfit's); a fix for the native acceptance gate rejecting a correct fit at a bound on the reference BLAS (#238) |
| **0.11.1** | Nonparametric and cluster bootstrap resamples no longer depend on `ncores`; `anova()` on `SEMFit` records `p_valid` and refuses a pair with a nonzero fixed parameter in one fit only; `@diagnostics$optimum` records the best-of-starts verdict; an engine comparison table on the Models page; the minibook explains the hard concepts from scratch; a robustness suite for the native optimizer (metamorphic, nloptr fault injection, an edge-case grid and a randomized oracle sweep, registered as a gate) |
| **0.11.0** | Categorical (factor, character, logical) covariates in native syntax; population-average four-way standard errors on request; a fix for nonlinear-constrained fits that wandered to negative variances (#213); a start fallback and a single-start warning for the native optimizer; the native engine is no longer marked experimental, and its exported signatures, `SEMFit` properties and model syntax change only through a deprecation |
| **0.10.0** | The product term `x:m` in native syntax and the four-way decomposition from a native fit (`extract_mediation()` on a `fit_sem()` fit), inside a documented supported class; the model test is `NA` when a product factor is a regression target; a native route in cookbook recipe 7 |
| **0.9.0** | Observed intercepts and means in the native engine (`y ~ 1`, `meanstructure =`), with centered coordinates for data far from zero; `fixed_x` to fix exogenous moments at the sample values (lavaan's `fixed.x = TRUE`); the tutorial's step 9 and cookbook recipe 18 |
| **0.8.0** | Nonlinear constraints (`cp == a*b`, `a*b > k`), `mbco_sem(paths = )` for a product of k paths, `anova()`, `tidy()` and `glance()` for `SEMFit`, one lavaan-style naming convention; the lavaan comparison article and cookbook recipes 12 and 13 |
| **0.7.0** | A native maximum-likelihood SEM engine: latent mediators, constraints, defined parameters, `fit_sem()`, `mbco_sem()` |
| **0.6.0** | Cluster-randomized designs (2-1-1) with `engine = "lmer"`, Kenward-Roger intervals, cluster bootstrap; the Reference Card and Cookbook |
| **0.5.0** | Joint mediation (`JointMediationData`), the bundled `mediation_demo` data; two results fixed: serial `te()`/`pm()` sum every path, `confint()` path rows are found by name |
| **0.4.0** | The `regmedint` engine, the four-way decomposition from `fit_mediation()`, and `m_star` |

Full list: [NEWS](https://data-wise.github.io/medfit/news/index.html).

## Install

```r
install.packages(
  "medfit",
  repos = c("https://data-wise.r-universe.dev", "https://cloud.r-project.org")
)
```

This installs the current r-universe release (0.14.1). Binaries are available
for supported R/platform combinations; a source installation can require a
compiler for dependencies such as `nloptr`. From GitHub instead:
`pak::pak("data-wise/medfit")`.

> **CRAN has 0.3.2, which does not run the examples on this site.** It lacks
> `mediation_demo`, `fit_sem()`, `mbco_sem()` and the joint and cluster classes.
> Its two known issues, serial `te()`/`pm()` and `confint()` path rows, are fixed in
> 0.5.0; see [#83](https://github.com/Data-Wise/medfit/issues/83).

## Try it in 60 seconds

```r
library(medfit)

# Simulate data
set.seed(123)
n <- 200
mydata <- data.frame(X = rnorm(n))
mydata$M <- 0.5 * mydata$X + rnorm(n)
mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

result <- med(data = mydata, treatment = "X", mediator = "M", outcome = "Y")
quick(result)
#> NIE = 0.164  | NDE = 0.293 | PM = 36 %
```

NIE is the indirect effect through the mediator, NDE the direct effect, PM the
share mediated. Next: read the pieces, then add an interval.

```r
nie(result)   # indirect effect (a * b)
nde(result)   # direct effect (c')
te(result)    # total effect
pm(result)    # proportion mediated
paths(result) # a, b, c'
```

### Read it as a table

```r
library(generics)

# Tidy tibble of all effects
tidy(result)
#> # A tibble: 6 × 3
#>   term    estimate std_error
#>   <chr>      <dbl>     <dbl>
#> 1 a          0.471    0.0750
#> 2 b          0.349    0.0689
#> 3 c_prime    0.293    0.0797
#> 4 nie        0.164    0.0417
#> 5 nde        0.293    0.0797
#> 6 te         0.457    0.0773

# One-row model summary
glance(result)
#> # A tibble: 1 × 6
#>     nie   nde    te    pm  nobs converged
#>   <dbl> <dbl> <dbl> <dbl> <int> <lgl>
#> 1 0.164 0.293 0.457 0.360   200 TRUE
```

### Add an interval

```r
# With bootstrap CI
result_boot <- med(
  data = mydata,
  treatment = "X",
  mediator = "M",
  outcome = "Y",
  boot = TRUE,
  n_boot = 1000,
  seed = 42
)

quick(result_boot)
#> NIE = 0.164  [0.0867, 0.256] | NDE = 0.293 | PM = 36 %
```

## Pick your model

Find the row that matches your data, then open its page. All of them are on the
[Models page](https://data-wise.github.io/medfit/articles/models.html).

| I have | Start here |
|---|---|
| One mediator, a continuous outcome | [Simple mediation](https://data-wise.github.io/medfit/articles/model-simple.html) |
| A binary or count variable | [Binary and non-normal variables](https://data-wise.github.io/medfit/articles/model-glm-families.html) |
| An effect of the mediator that depends on treatment | [Treatment-by-mediator interaction](https://data-wise.github.io/medfit/articles/model-interaction.html) |
| Inverse-probability or case weights | [Weights and robust SEs](https://data-wise.github.io/medfit/articles/model-weights.html) |
| Mediators in a chain | [Serial mediation](https://data-wise.github.io/medfit/articles/model-serial.html) |
| Mediators side by side | [Parallel mediation](https://data-wise.github.io/medfit/articles/model-parallel.html) |
| Several mediators with products | [Joint mediation](https://data-wise.github.io/medfit/articles/model-joint.html) |
| Treatment assigned to whole clusters | [Cluster-randomized trials](https://data-wise.github.io/medfit/articles/model-cluster.html) |
| A lavaan fit | [lavaan fits](https://data-wise.github.io/medfit/articles/model-lavaan.html) |
| A latent mediator | [Native: a latent mediator](https://data-wise.github.io/medfit/articles/model-native-latent.html) |
| Constraints, or a test of the indirect effect | [Native: constraints and MBCO](https://data-wise.github.io/medfit/articles/model-native-constraints.html) |
| Serial or parallel mediators written as syntax | [Native: several mediators and weights](https://data-wise.github.io/medfit/articles/model-native-multi.html) |

Already have fitted `lm`, `glm`, `lmer` or lavaan models? `extract_mediation()`
turns them into the same objects:

```r
fit_m <- lm(M ~ X, data = mydata)
fit_y <- lm(Y ~ X + M, data = mydata)
med_data <- extract_mediation(fit_m, model_y = fit_y, treatment = "X", mediator = "M")
nie(med_data)
```

## More examples

<details>
<summary><b>Cluster-randomized trial</b> (treatment assigned to schools, clinics)</summary>

When the treatment is assigned to whole clusters (such as schools), use the
`lmer` engine (needs the suggested `lme4`; add `se_type = "kr"` with `pbkrtest`
for few clusters):

```r
# 40 schools of 10 students, treatment assigned by school
set.seed(123)
J <- 40
n <- 10
school <- rep(seq_len(J), each = n)
cdat <- data.frame(school = factor(school), X = sample(rep(0:1, J / 2))[school])
cdat$M <- 0.5 * cdat$X + rnorm(J, sd = 0.5)[school] + rnorm(J * n)
cdat$Y <- 0.2 * cdat$X + 0.4 * cdat$M + rnorm(J, sd = 0.5)[school] + rnorm(J * n)

fit <- fit_mediation(
  Y ~ X + M, M ~ X, data = cdat,
  treatment = "X", mediator = "M",
  engine = "lmer", cluster = "school"
)

nie(fit)        # a * b_between
decompose(fit)  # own-mediator and spillover parts (large-cluster approximation)
```

```
#> Natural Indirect Effect (NIE): 0.328
#>        own  spillover        nie
#> 0.25763321 0.07036432 0.32799753
```

See [Methods and Formulas](https://data-wise.github.io/medfit/articles/methods.html)
for the estimand and the assumptions each effect needs.

</details>

<details>
<summary><b>Latent mediator</b> (native engine)</summary>

When the mediator is a construct measured by several indicators, write the model
as syntax. The native maximum-likelihood engine needs no
other package:

```r
# a latent mediator `eta` with three indicators, simulated
set.seed(11)
n <- 400
X <- rnorm(n)
eta <- 0.5 * X + rnorm(n, sd = 0.9)
ldat <- data.frame(
  X = X,
  m1 = eta + rnorm(n, sd = 0.7),
  m2 = 0.8 * eta + rnorm(n, sd = 0.7),
  m3 = 0.7 * eta + rnorm(n, sd = 0.8)
)
ldat$Y <- 0.4 * eta + 0.2 * X + rnorm(n, sd = 0.8)

syntax <- "
  eta =~ m1 + m2 + m3
  eta ~ a * X
  Y ~ b * eta + cp * X
"
fit <- fit_mediation(model = syntax, data = ldat, treatment = "X",
                     mediator = "eta", engine = "native")
nie(fit)

mbco_sem(fit_sem(syntax, ldat), "a", "b")  # minimum of two likelihood-ratio tests
```

```
#> Natural Indirect Effect (NIE): 0.1685
#>
#> 	Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect
#>
#> data:  a * b = 0
#> MBCO = 46.753, df = 1, p-value = 8.054e-12
```

</details>

## What is in the box

| Class | Models |
|---|---|
| `MediationData` | Simple mediation: X to M to Y (paths a, b, c') |
| `InteractionMediationData` | Treatment-by-mediator interaction, four-way decomposition (CDE, INTref, INTmed, PIE) |
| `SerialMediationData` | A chain X to M1 to M2 to Y; `nie()` is the chain, `te()`/`pm()` count every path |
| `ParallelMediationData` | Mediators side by side; indirect effect is the sum of a_j * b_j |
| `JointMediationData` | Joint natural effects of several mediators with products |
| `ClusterMediationData` | Treatment assigned to clusters (2-1-1): own-mediator and spillover parts |
| `SEMFit` | A native-engine fit; `extract_mediation()` turns it into the classes above |
| `BootstrapResult` | Point estimates, intervals and the bootstrap distribution |

| You want to | Call |
|---|---|
| Run a mediation in one step | `med()`, `quick()` |
| Read effects and paths | `nie()`, `nde()`, `te()`, `pm()`, `paths()`, `decompose()` |
| Get a table | `tidy()`, `glance()`, `confint()`, `coef()`, `vcov()`, `nobs()` |
| Fit with control | `fit_mediation()` (engines `glm`, `regmedint`, `lmer`, `native`) |
| Use fitted models | `extract_mediation()` (lm, glm, lmer, lavaan, `SEMFit`) |
| Write a model as syntax | `fit_sem()`, `mbco_sem()` |
| Bootstrap | `bootstrap_mediation()` (parametric, nonparametric, plugin) |

Every function is on the [Reference Card](https://data-wise.github.io/medfit/articles/refcard.html).

## Mediationverse Ecosystem

medfit is the foundation for the **mediationverse** ecosystem:

| Package | Purpose | Role |
|---------|---------|------|
| **medfit** (this) | Model fitting, extraction, bootstrap | Foundation |
| [RMediation](https://github.com/data-wise/rmediation) | Confidence intervals (DOP, MBCO) | Application |
| [probmed](https://github.com/data-wise/probmed) | Probabilistic effect size (P_med) | Application |
| [medrobust](https://github.com/data-wise/medrobust) | Sensitivity analysis | Application (independent of medfit) |
| [medsim](https://github.com/data-wise/medsim) | Simulation infrastructure | Support |
| [mediationverse](https://github.com/data-wise/mediationverse) | Meta-package | Ecosystem |

See [Ecosystem Coordination](https://github.com/Data-Wise/mediation-planning/blob/main/docs/ECOSYSTEM-COORDINATION.md) for version compatibility and development guidelines.

## Documentation

| If you want to | Read |
|---|---|
| Run your first model | [Get Started](https://data-wise.github.io/medfit/articles/getting-started.html) |
| Find the page for your model | [Models](https://data-wise.github.io/medfit/articles/models.html) |
| Copy a short recipe | [Cookbook](https://data-wise.github.io/medfit/articles/cookbook.html) (twenty-one recipes) |
| Look up a function or class | [Reference Card](https://data-wise.github.io/medfit/articles/refcard.html) |
| Understand the classes | [Introduction](https://data-wise.github.io/medfit/articles/introduction.html) |
| Extract from fitted models | [Model Extraction](https://data-wise.github.io/medfit/articles/extraction.html) |
| Run a bootstrap | [Bootstrap Inference](https://data-wise.github.io/medfit/articles/bootstrap.html) |
| Check the math | [Methods and Formulas](https://data-wise.github.io/medfit/articles/methods.html) |
| Upgrade from CRAN 0.3.2 | [What changed since CRAN 0.3.2](https://data-wise.github.io/medfit/articles/guide-changes.html) |
| Fix an error or warning | [Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html) |
| Choose an interval | [Which interval should I use?](https://data-wise.github.io/medfit/articles/guide-intervals.html) |
| Look up a term or symbol | [Glossary and symbols](https://data-wise.github.io/medfit/articles/guide-glossary.html) |

## Development Status

medfit is on CRAN. Current development adds mediation structures and inference
on the `dev` branch; see `NEWS.md` for what each release contains.

### Code Quality

- **Defensive Programming**: checkmate for input validation, S7 validators for class integrity
- **Testing**: 5,700+ testthat expectations in 1,200+ test blocks (>90% coverage, enforced via codecov)
- **CI/CD**: R CMD check, lintr, coverage reporting via GitHub Actions

See the [NEWS](https://data-wise.github.io/medfit/news/index.html) for what changed in each release.

## Contributing

This package is in active development. Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch from `dev`
3. Make your changes with tests
4. Submit a pull request to `dev`

## Code of Conduct

Please note that the medfit project is released with a [Contributor Code of Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html). By contributing to this project, you agree to abide by its terms.

## License

GPL (>= 3)

## Citation

If you use medfit in your research, please cite:

```
Tofighi, D. (2026). medfit: Infrastructure for mediation analysis in R.
R package version 0.14.1. https://data-wise.github.io/medfit/
```

For the entry matching your installed version, run `citation("medfit")`.

## Related Resources

- [Package Documentation](https://data-wise.github.io/medfit/)
- [Development Guide](https://github.com/data-wise/medfit/blob/main/CLAUDE.md)
- [NEWS](https://data-wise.github.io/medfit/news/index.html)
- [Ecosystem Strategy](https://github.com/Data-Wise/mediation-planning/blob/main/docs/ECOSYSTEM-COORDINATION.md)

## Contact

- **Author**: Davood Tofighi
- **Email**: dtofighi@gmail.com
- **ORCID**: [0000-0001-8523-7776](https://orcid.org/0000-0001-8523-7776)
- **Issues**: [GitHub Issues](https://github.com/data-wise/medfit/issues)
