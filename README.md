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

**Next:** [install](#install), then [run the example](#start-here-in-60-seconds).

## Install

```r
install.packages("medfit",
  repos = c("https://data-wise.r-universe.dev", "https://cloud.r-project.org"))
```

From GitHub instead: `pak::pak("data-wise/medfit")`. This installs the version currently built by r-universe; check `packageVersion("medfit")` afterward. Binaries exist for supported R and platform combinations; a source installation can need a compiler for dependencies such as `nloptr`.

> **CRAN has 0.3.2, which does not run the examples on this site.** It lacks
> `mediation_demo`, `fit_sem()`, `mbco_sem()` and the joint and cluster classes.
> Its two known issues, serial `te()`/`pm()` and `confint()` path rows, are fixed in
> 0.5.0; see [#83](https://github.com/Data-Wise/medfit/issues/83).

## Start here in 60 seconds

`mediation_demo` ships with the package, so this runs as written:

```r
library(medfit)

result <- med(
  data = mediation_demo,
  treatment = "treatment", mediator = "mediator1", outcome = "outcome",
  covariates = c("covariate1", "covariate2")
)
quick(result)
#> NIE = 0.333  | NDE = 0.206 | PM = 61.8 %
```

**You should see** one line. NIE is the indirect effect through the mediator, NDE the direct effect, PM the share mediated. If you get an error instead, see [When something fails](#when-something-fails).

<details>
<summary><b>Then: read the pieces, get a table, add an interval</b></summary>

```r
nie(result)   # indirect effect (a * b)
nde(result)   # direct effect (c')
te(result)    # total effect
pm(result)    # proportion mediated
paths(result) # a, b, c'

library(generics)
tidy(result)   # every effect with its standard error
#> # A tibble: 6 × 3
#>   term    estimate std_error
#>   <chr>      <dbl>     <dbl>
#> 1 a          0.583    0.0989
#> 2 b          0.571    0.0535
#> 3 c_prime    0.206    0.110 
#> 4 nie        0.333    0.0645
#> 5 nde        0.206    0.110 
#> 6 te         0.539    0.119 

glance(result)  # one-row model summary
#> # A tibble: 1 × 6
#>     nie   nde    te    pm  nobs converged
#>   <dbl> <dbl> <dbl> <dbl> <int> <lgl>    
#> 1 0.333 0.206 0.539 0.618   400 TRUE     

# With a bootstrap interval
result_boot <- med(
  data = mediation_demo,
  treatment = "treatment", mediator = "mediator1", outcome = "outcome",
  covariates = c("covariate1", "covariate2"),
  boot = TRUE, n_boot = 1000, seed = 42
)
quick(result_boot)
#> NIE = 0.333  [0.208, 0.458] | NDE = 0.206 | PM = 61.8 %
```

</details>

## Pick your model

Find your data, open its page.

| I have | Start here |
|---|---|
| One mediator, a continuous outcome | [Simple mediation](https://data-wise.github.io/medfit/articles/model-simple.html) |
| A binary or count variable | [Binary and non-normal variables](https://data-wise.github.io/medfit/articles/model-glm-families.html) |
| Several mediators | [Parallel](https://data-wise.github.io/medfit/articles/model-parallel.html), [serial](https://data-wise.github.io/medfit/articles/model-serial.html) or [joint](https://data-wise.github.io/medfit/articles/model-joint.html) mediation |
| Clusters (schools, clinics) or two-level data | [Cluster-randomized trials](https://data-wise.github.io/medfit/articles/model-cluster.html), [two-level mediation](https://data-wise.github.io/medfit/articles/model-twolevel.html) (experimental) |
| A lavaan fit, or a latent mediator | [lavaan fits](https://data-wise.github.io/medfit/articles/model-lavaan.html), [the sem engine: a latent mediator](https://data-wise.github.io/medfit/articles/model-sem-latent.html) |
| Missing data | [Bounded FIML](https://data-wise.github.io/medfit/articles/model-fiml.html): numerically verified against lavaan, not statistically admitted (no interval coverage is established) |

Other cases (interaction, weights, constraints and MBCO, serial or parallel models written as syntax) are on the [full Models table](https://data-wise.github.io/medfit/articles/models.html). Not sure which engine? See [Which engine should I use?](https://data-wise.github.io/medfit/articles/guide-engines.html)

## When something fails

- [Troubleshooting](https://data-wise.github.io/medfit/articles/guide-troubleshooting.html): each error and warning, with the fix.
- [Glossary and symbols](https://data-wise.github.io/medfit/articles/guide-glossary.html): what a term or symbol means.
- [What changed since CRAN 0.3.2](https://data-wise.github.io/medfit/articles/guide-changes.html): if the CRAN version behaves differently.

## Go further

[Get Started](https://data-wise.github.io/medfit/articles/getting-started.html) | [Cookbook](https://data-wise.github.io/medfit/articles/cookbook.html) (twenty-four recipes) | [Reference Card](https://data-wise.github.io/medfit/articles/refcard.html) | [Methods and Formulas](https://data-wise.github.io/medfit/articles/methods.html) | [Which interval should I use?](https://data-wise.github.io/medfit/articles/guide-intervals.html)

## More, when you need it

<details>
<summary><strong>What's new in 0.21.0.9000</strong></summary>

* **Development version:** no user-visible changes yet since 0.21.0 (released 2026-11-25), whose highlights follow.

* **0.21.0 (2026-11-25, GitHub only):** adds the MLR estimator and classed product refusals below since 0.20.0 (released 2026-11-23).
* **MLR estimator (0.21.0):** `fit_sem(model, data, estimator = "MLR")` keeps the ML estimates, uses sandwich standard errors and adds the Yuan-Bentler scaled chi-square (`chisq_scaled`, `scaling_factor`, `p_value_scaled` in `glance()`), as lavaan's MLR. It is defined for single-level complete-data fits with linear equality constraints; anything else stops with a classed error. See the [NEWS](https://data-wise.github.io/medfit/news/index.html).
* **Classed product refusals (0.21.0):** every refusal of the `:` product term has a class (`medfit_error_product_*`); messages and numbers are unchanged.
* **0.20.0 (2026-11-23, GitHub only):** adds the native two-level route below since 0.19.0 (released 2026-11-17). The two-level API is experimental, so it may change without a deprecation period.
* **Native two-level fit (0.20.0, experimental):** `fit_sem(model, data, cluster = )` fits a two-level (1-1-1) model written in `level:` blocks with the sem engine, and `extract_mediation()` on the fit returns `TwoLevelMediationData`; `fit_mediation(engine = "sem", model = , cluster = )` returns the same object. `se_type = "sandwich"` gives cluster-robust standard errors. See the [model page](https://data-wise.github.io/medfit/articles/model-twolevel.html).
* **Tests on native two-level fits (0.20.0, experimental):** `mbco_sem()` tests the indirect effect at one level, and `twolevel_equal_indirect()` tests that the within and between indirect effects are equal; a pair-sign twin certificate stops a worse local optimum from standing in the equality refit.
* **Behavior change (0.20.0, experimental):** the within-only rule for a two-level fit now reads the unrestricted (h1) ICC on both routes, so within-only results are rarer. See the [NEWS](https://data-wise.github.io/medfit/news/index.html).
* **Two-level parallel mediation (0.19.0, experimental):** `extract_mediation()` on a two-level `lavaan` fit with two or more mediators returns `TwoLevelParallelMediationData`, with per-mediator and total effects at each level, delta-method SEs and `twolevel_statistic()` for the bootstrap. One-mediator results are unchanged. See the [model page](https://data-wise.github.io/medfit/articles/model-twolevel.html#several-parallel-mediators).
* **The sem engine (0.18.0):** `fit_mediation(engine = "sem")` names medfit's own SEM fitter; `engine = "native"` still works, with identical results. `sem_control()` collects its optimizer settings. See [Which engine should I use?](https://data-wise.github.io/medfit/articles/guide-engines.html).
* **Renamed pages (0.18.0):** the sem engine articles moved (`native-guide` is now `sem-guide`, and so on); old links redirect.
* **Bounded FIML expansion (0.17.0):** one or two covariates, two parallel and two serial mediators (numerically verified, not statistically admitted). See the [model page](https://data-wise.github.io/medfit/articles/model-fiml.html).
* **Two-level mediation (0.17.0, experimental):** `extract_mediation()` on a two-level `lavaan` fit returns `TwoLevelMediationData`; lavaan floor 0.7-3. See the [model page](https://data-wise.github.io/medfit/articles/model-twolevel.html).
* **Before that:** 0.16.0 (both sign branches of a nonzero-product equality, corrected constrained standard errors) and 0.15.0 (native defaults flip: `fixed_x` and `meanstructure` on when unset).

Every release is listed in [NEWS](https://data-wise.github.io/medfit/news/index.html); upgrading from CRAN 0.3.2? See [What changed since CRAN 0.3.2](https://data-wise.github.io/medfit/articles/guide-changes.html).

</details>

<details>
<summary><strong>Bounded FIML (0.16.0 and 0.17.0): settings and limits</strong></summary>

medfit 0.16.0 added explicit `fit_sem(missing = "fiml", fixed_x = FALSE)` for
three-variable Gaussian random-X mediation, preserving listwise defaults. medfit 0.17.0
also fits one or two covariates, two parallel mediators
(with zero, one or two covariates) and two-mediator serial models (the saturated graph
or the pure chain, with up to two covariates; implemented and verified against lavaan, not calibrated for coverage). It is
unavailable in 0.15.0 and earlier. Observed/model SEs and
unstandardized effects and normal intervals are supported. The model requires
continuous X, M and Y, a free or exactly zero direct path, independent Gaussian
disturbances, free intercepts and ignorable missingness under that joint model.
Native `fit_mediation()` uses `engine_args` for the same opt-in. Extracted FIML
objects refuse `quick()`, `pm()` and `glance()`; fit tests, profiles and MBCO
remain unavailable. Source-fit retained-row and Gaussian parameter-draw intervals
(`bootstrap_mediation(source_fit = ...)`) are implemented but withheld: the call is
refused until statistical admission is decided. `glance()` on the source SEMFit retains likelihood/IC fields.
See the [native guide](https://data-wise.github.io/medfit/articles/sem-guide.html#bounded-fiml)
for settings and limits.

</details>

<details>
<summary><b>Already have fitted models?</b> (<code>lm</code>, <code>glm</code>, <code>lmer</code>, lavaan)</summary>

`extract_mediation()` turns fitted models into the same objects (see [Model Extraction](https://data-wise.github.io/medfit/articles/extraction.html)):

```r
fit_m <- lm(mediator1 ~ treatment + covariate1 + covariate2, data = mediation_demo)
fit_y <- lm(outcome ~ treatment + mediator1 + covariate1 + covariate2, data = mediation_demo)
med_data <- extract_mediation(fit_m, model_y = fit_y, treatment = "treatment", mediator = "mediator1")
nie(med_data)
```

</details>

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
<summary><b>Latent mediator</b> (sem engine)</summary>

When the mediator is a construct measured by several indicators, write the model
as syntax. The sem engine needs no
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
                     mediator = "eta", engine = "sem")
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

<details>
<summary><b>Classes and functions</b></summary>

| Class | Models |
|---|---|
| `MediationData` | Simple mediation: X to M to Y (paths a, b, c') |
| `InteractionMediationData` | Treatment-by-mediator interaction, four-way decomposition (CDE, INTref, INTmed, PIE) |
| `SerialMediationData` | A chain X to M1 to M2 to Y; `nie()` is the chain, `te()`/`pm()` count every path |
| `ParallelMediationData` | Mediators side by side; indirect effect is the sum of a_j * b_j |
| `JointMediationData` | Joint natural effects of several mediators with products |
| `ClusterMediationData` | Treatment assigned to clusters (2-1-1): own-mediator and spillover parts |
| `TwoLevelMediationData` | A two-level `lavaan` fit with X, M and Y on level-1 units (1-1-1): the indirect effect at the within and the between level (0.17.0, experimental) |
| `TwoLevelParallelMediationData` | The same two-level fit with two or more parallel mediators: per-mediator and total effects at each level (0.19.0, experimental) |
| `FIMLMediationData`, `FIMLParallelMediationData`, `FIMLSerialMediationData` | Bounded FIML fits (`fit_sem(missing = "fiml")`): X to M to Y, two parallel mediators, two serial mediators (see above) |
| `SEMFit` | A sem engine fit; `extract_mediation()` turns it into the classes above |
| `BootstrapResult` | Point estimates, intervals and the bootstrap distribution |

| You want to | Call |
|---|---|
| Run a mediation in one step | `med()`, `quick()` |
| Read effects and paths | `nie()`, `nde()`, `te()`, `pm()`, `paths()`, `decompose()` |
| Get a table | `tidy()`, `glance()`, `confint()`, `coef()`, `vcov()`, `nobs()` |
| Fit with control | `fit_mediation()` (engines `glm`, `regmedint`, `lmer`, `sem`) |
| Use fitted models | `extract_mediation()` (lm, glm, lmer, lavaan, `SEMFit`) |
| Write a model as syntax | `fit_sem()`, `mbco_sem()` |
| Bootstrap | `bootstrap_mediation()` (parametric, nonparametric, plugin) |

Every function is on the [Reference Card](https://data-wise.github.io/medfit/articles/refcard.html). For the classes, see the [Introduction](https://data-wise.github.io/medfit/articles/introduction.html); for resampling, [Bootstrap Inference](https://data-wise.github.io/medfit/articles/bootstrap.html).

</details>

<details>
<summary><b>Mediationverse ecosystem and related packages</b></summary>

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

Also: [Package documentation](https://data-wise.github.io/medfit/), [Development Guide](https://github.com/data-wise/medfit/blob/main/CLAUDE.md), [NEWS](https://data-wise.github.io/medfit/news/index.html).

</details>

---

## Development status

CRAN has an older release (0.3.2), and this site documents the GitHub build (see
the callout under Install). Current development adds mediation structures and
inference on the `dev` branch; see `NEWS.md` for what each release contains.

### Code quality

- **Defensive Programming**: checkmate for input validation, S7 validators for class integrity
- **Testing**: 2,600+ `test_that()` blocks (>90% coverage, enforced via codecov)
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
Tofighi, D. (2026). medfit: Infrastructure for Mediation Model Fitting and Extraction.
R package version x.y.z. https://data-wise.github.io/medfit/
```

Replace `x.y.z` with your installed version, or run `citation("medfit")` for the exact entry.

## Contact

- **Author**: Davood Tofighi
- **Email**: dtofighi@gmail.com
- **ORCID**: [0000-0001-8523-7776](https://orcid.org/0000-0001-8523-7776)
- **Issues**: [GitHub Issues](https://github.com/data-wise/medfit/issues)
