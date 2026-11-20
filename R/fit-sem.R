# Native SEM engine: user entry point.
#
# `fit_sem()` fits model syntax to raw data by maximum likelihood with the
# engine in R/sem-*.R and returns a `SEMFit`. `.sem_as_semfit()` is the one place
# that turns the engine's plain list into the S7 object.

#' Fit a Structural Equation Model by Maximum Likelihood
#'
#' @description
#' Fits a model written in lavaan-style syntax to raw data with the sem engine,
#' medfit's own maximum-likelihood SEM fitter, and returns a [SEMFit] object. The engine handles
#' observed and latent variables, user labels, fixed values, starts and bounds,
#' equality and inequality constraints (`==`, `<`, `>`, linear or nonlinear), and defined
#' parameters (`:=`) with delta-method standard errors.
#'
#' @param model Character: model syntax. Lines may use `~` (regression),
#'   `=~` (latent variable), `~~` (variance or covariance), `label*variable`
#'   modifiers, `start()`, `lower()` and `upper()`, and the constraint
#'   operators `==`, `<`, `>` and `:=`. An intercept is written `y ~ 1` (alone or with other terms, as
#'   in `y ~ 1 + x`) and turns on the mean structure. A product of two observed variables is written
#'   `x:m` on the right side of a regression (canonical name `m:x`); `?"medfit-syntax"` lists the
#'   supported class and each limit.
#' @param data A data frame with the model's observed variables. Numeric columns are used as is; a
#'   factor, character or logical column named on a regression's right side is expanded to 0/1 dummies
#'   (`?"medfit-syntax"` lists the rules and limits). Rows with missing values in those columns are dropped once
#'   (listwise deletion) and counted in `n_dropped` under the default `missing = "listwise"`.
#'   Bounded `missing = "fiml"` accepts numeric model columns only, retains rows with any
#'   observed model variable, and drops only all-empty model rows; extra columns do not select rows.
#' @param information Character: `"observed"` (default) or `"expected"`
#'   information for the standard errors. `"expected"` is an error for a model with a product term
#'   that has an endogenous factor (the product is a function of another variable, so the expected
#'   information gives wrong standard errors); use the default with `se_type = "sandwich"`.
#'   Bounded FIML supports only `"observed"`.
#' @param n_starts Positive integer or `NULL`: number of optimizer starts
#'   tried before the fit is declared failed (`NULL` uses 5). Retries use
#'   perturbed starts drawn under a fixed seed and never change the caller's
#'   random number stream; with 3 or more starts the last attempt is the model's
#'   own moment-based start, so a start in a bad basin does not end the fit.
#'   With a nonlinear constraint, which can leave several
#'   local optima, every start is tried and the best accepted one is kept (a
#'   warning says when the accepted starts disagree); otherwise the first
#'   accepted start is used. A supported nonzero-product equality searches both sign
#'   branches independently, with `n_starts` starts per nonempty branch; aggregate
#'   diagnostics report the actual attempts, not the number of branches. For FIML,
#'   only `NULL` or `3` is supported: three starts per solver, with refinements counted separately.
#' @param control A [sem_control()] object, or a plain list of options passed to
#'   the optimizer (`nloptr`), the same as `sem_control(nloptr = <list>)`. An
#'   `n_starts` given both here (in `sem_control()`) and as the argument must
#'   agree. FIML requires `optimizer = "auto"`, an empty `nloptr` list (or the
#'   empty plain list) and `n_starts` `NULL` or 3, under its initial validated
#'   numerical protocol. The resolved protocol is recorded
#'   in `fit@diagnostics$protocol`.
#' @param weights Optional numeric vector of non-negative case weights,
#'   one per row of `data` (`NULL`, the default, fits unweighted). The fit is
#'   weighted maximum likelihood on the weighted mean and covariance; the scale
#'   of the weights does not matter. Rows dropped for missing values drop their
#'   weights with them. Use with `se_type = "sandwich"`. FIML rejects every non-NULL weight vector.
#' @param se_type Character: `"model"` (default) takes the covariance of the
#'   estimates from the inverse information; `"sandwich"` uses the robust
#'   sandwich covariance \eqn{A^{-1} B A^{-1}}{A^-1 B A^-1} with casewise scores
#'   (HC0-type: it equals `sandwich::vcovHC(type = "HC0")` per equation and
#'   lavaan's robust standard errors with `sampling.weights`, and is smaller
#'   than the HC3 default of the glm route by a factor that shrinks like
#'   \eqn{1/n}{1/n}). Model-based standard errors are not valid under weights. In a two-level model (`cluster`)
#'   `"sandwich"` is the cluster-robust sandwich: per-cluster scores, \eqn{B = \sum_j s_j s_j'}{B = sum_j s_j s_j'}
#'   with no small-sample factor (CR0), the observed information as \eqn{A}{A}, projected under active linear
#'   constraints; it matches lavaan's `se = "robust.huber.white"` for the same two-level model.
#' @param meanstructure Logical or `NULL`. `TRUE` (default) fits a mean structure;
#'   `NULL` fits one only when the model writes
#'   an intercept (`y ~ 1`, free or fixed); `FALSE` fits covariances only and
#'   errors if an intercept is written. With a mean structure every observed variable whose intercept is
#'   not written has a free one, so a model with only free intercepts has the same estimates and
#'   standard errors as the covariance-only fit. A latent variable's mean is fixed at 0.
#'   A model with a product term (`y ~ x + m + x:m`) always fits the mean structure (it needs the mediator
#'   intercept for the four-way decomposition), so with a product `meanstructure = FALSE` is an error.
#'   An explicit `NULL` or `FALSE` is kept as given for listwise fits. FIML requires `TRUE`.
#' @param fixed_x `TRUE` (default), `FALSE`, or a character vector of exogenous observed variable names. The
#'   selected variables (`TRUE`: every exogenous observed variable, product columns included) have their mean (with
#'   a mean structure), variance and the exogenous covariances the model contains fixed at the sample moments of
#'   the estimation sample (weighted when `weights` are given) and removed from estimation, as lavaan does with
#'   `fixed.x = TRUE`. The structural estimates, their standard errors, the degrees of freedom and the chi-square do
#'   not change; the parameter count and the log likelihood do: the log likelihood (and so AIC and BIC) is
#'   conditional on the fixed variables, and `glance()$fixed_x` lists them. Models whose `fixed_x` sets or data differ
#'   cannot be compared with [stats::anova()], [mbco_sem()], `AIC()` or `BIC()`. A (co)variance or intercept statement
#'   on a selected variable is an error (lavaan would silently keep it free). The fixed rows stay in the parameter table
#'   (`fixed_x` column, no standard error) but not in `coef()` or `vcov()`.
#'   Left unset it resolves to an explicit subset: every exogenous observed variable
#'   (product and factor-dummy columns included) except those a `~~` or `~1`
#'   statement names, which are left free with a message of class `medfit_message_fixed_x_lenient` (an explicit
#'   `TRUE` errors there instead; an explicit `FALSE` is kept). `glance()$fixed_x` names the set the fit used.
#' @param missing Exact missing-data method: `listwise` (default) or bounded Gaussian
#'   `fiml` (no abbreviations). FIML requires explicit `fixed_x = FALSE`; see
#'   the Bounded FIML section. The argument is appended to preserve existing positional calls.
#' @param cluster **Experimental.** `NULL` (default) or a string: the name of the cluster column
#'   of `data`, for a two-level model written with `level:` blocks (`level: 1` or `level: within`; `level: 2`,
#'   `level: between` or the cluster variable's name). Two-level only: `cluster` without `level:` blocks, and
#'   `level:` blocks without `cluster`, are errors (`medfit_error_twolevel_cluster`, which also covers more than two
#'   levels, fewer than two clusters and a missing or incomplete cluster column); misordered `level:` blocks are
#'   `medfit_error_twolevel_syntax`; a within variable constant in every cluster, or a cluster-level variable in a
#'   `level: 1` row, is `medfit_error_twolevel_varset`. A model that passes the two-level checks is fitted by maximum
#'   likelihood (experimental); an inadmissible solution (a negative variance or a non-positive-definite implied
#'   covariance at either level) stops with `medfit_error_twolevel_inadmissible`, which keeps the fit and its outcome
#'   ledger. `extract_mediation()` on a native two-level fit returns a `TwoLevelMediationData` (`@source` is
#'   `"native"`), with the warnings of the lavaan two-level adapter. `glance()` adds `n_clusters`,
#'   `cluster_size_min` and `cluster_size_max` (counted after listwise deletion); its `chisq` and `p_value` are `NA`
#'   with a note, because the engine fits no saturated two-level model. See the "Two-level models" section of
#'   [medfit-syntax]. Unset `fixed_x`
#'   means `FALSE` on this route; an explicit `fixed_x = TRUE`, `meanstructure = FALSE`, `weights`,
#'   `missing = "fiml"`, `information = "expected"`, latent variables, product terms and
#'   nonlinear constraints are refused with classed errors (`medfit_error_twolevel_*`); the one nonlinear row admitted
#'   is the equality of the within and between indirect effects (`a_w*b_w == a_b*b_b`, the null of
#'   [twolevel_equal_indirect()]). `se_type = "sandwich"` gives
#'   the cluster-robust sandwich (see `se_type`), and `glance()` then reports `se_type`. Appended last to preserve
#'   positional calls.
#' @param sampling_weights `r lifecycle::badge("deprecated")` Renamed `weights`, the name
#'   [fit_mediation()] uses; the old name still works with a warning.
#'
#' @section Defaults changed in 0.15.0:
#' `fixed_x` is the exogenous observed variables (lavaan's `fixed.x = TRUE`) and `meanstructure = TRUE`, so a default
#' fit matches a default `lavaan::sem()` fit. Against 0.14.x the parameter count, `logLik()`, `AIC()`, `BIC()` and the
#' names in `coef()`, `vcov()` and `tidy()` change; the structural estimates and their standard errors did not change
#' on the cases measured. Which random start a multi-start fit tries can change too (the retry seed follows the
#' parameter names). To keep the 0.14.x results, pass `fixed_x = FALSE, meanstructure = NULL`.
#' The 0.14.x `options(medfit.native_defaults)` opt-in no longer has any effect.
#'
#' @section Bounded FIML:
#' Explicit `missing = "fiml"` fits a joint Gaussian random-X model under ignorable
#' missingness (for example, MAR with the usual ignorability conditions). It evaluates
#' observed components, without imputing values. It supports numeric continuous
#' observed variables in four shapes: X -> M -> Y (three variables), the
#' same model with one covariate `Z`, with two covariates `Z1` and `Z2`, and two
#' parallel mediators (see below). The
#' X -> Y path is free or fixed exactly at zero, intercepts are free, and
#' disturbances are independent except the free mediator residual covariance of the
#' parallel form. Names and labels are arbitrary.
#'
#' With covariates the regressions are `M ~ X + Z` and `Y ~ M + X + Z` (one
#' covariate), or `M ~ X + Z1 + Z2` and `Y ~ M + X + Z1 + Z2` (two). Every
#' exogenous variable needs a written path to `Y`, and every covariate path to `M`
#' is free. The exogenous variables have a free joint covariance: write every pair
#' (in either order) or none; a partial set is refused. Any variable may be
#' incomplete. With no `Y` path fixed at zero, the first exogenous variable is the
#' fit's treatment and [extract_mediation()] may name any exogenous variable as the
#' treatment; with exactly one `Y` path fixed at zero, that variable is the
#' treatment. Parameter counts are 8 or 9 (three variables), 13 or 14 (one
#' covariate) and 19 or 20 (two covariates), without or with the direct path.
#' Three or more covariates, a covariate on one equation only, residual
#' covariances (other than the parallel mediator covariance), extra predictors beyond these, latent variables, products,
#' factors, correlated disturbances, parameter ties, bounds, general constraints,
#' defined parameters and syntax-supplied starts are not supported. The covariate
#' fits are implemented and numerically verified against lavaan and an independent
#' likelihood; their coverage has not been calibrated or statistically admitted.
#' Input checks and local numerical gates do not establish global identification,
#' a global optimum or inference coverage.
#'
#' Two parallel mediators (`M1 ~ X`, `M2 ~ X`, `Y ~ M1 + M2`, with or without
#' `Y ~ X`) are fitted in two forms. Independent residuals require
#' the statement `M1 ~~ 0*M2` (either order): an omitted statement is refused
#' because lavaan's default would free it. A free, label-less `M1 ~~ M2` fits the
#' mediator residual covariance. A labeled, fixed nonzero, bounded, tied or
#' otherwise constrained covariance is refused. The free-parameter count is 12 or
#' 13 (independent residuals) and 13 or 14 (free covariance), without or with the
#' direct path. [extract_mediation()] needs both mediators named and returns a
#' `FIMLParallelMediationData` object with the full path covariance of `a1`, `a2`,
#' `b1`, `b2` and `c_prime`, so the sum of the indirect effects keeps every
#' cross-path term. Extraction refusals for the parallel form have class
#' `medfit_error_fiml_extract_unsupported`.
#'
#' Two parallel mediators also take one covariate `Z` or two covariates `Z1`,
#' `Z2` (`M1 ~ X + Z`, `M2 ~ X + Z`, `Y ~ M1 + M2 + X + Z`, in either residual
#' form). The covariate rules are those above: every exogenous variable has a free
#' path to both mediators and a written path to `Y`, the exogenous covariance is
#' free (write every pair or none), and any variable may be incomplete. With no `Y`
#' path fixed at zero, [extract_mediation()] may name any exogenous variable as the
#' treatment; with one fixed at zero that variable is the treatment. The
#' free-parameter count is 18 to 20 (one covariate) and 25 to 27 (two), without or
#' with the direct path and the free residual covariance. Three or more mediators,
#' three or more covariates and a covariate on only some of the equations stay
#' refused.
#'
#' Two serial mediators are fitted in two forms, each with no, one or two
#' covariates: the saturated forward graph `M1 ~ X`, `M2 ~ M1 + X` and
#' `Y ~ M1 + M2 + X`, and the pure chain `M1 ~ X`, `M2 ~ M1` and `Y ~ M2` (the direct
#' path `Y ~ X` is free, `0*X`, or omitted in both without a covariate), with the independence of all three
#' disturbance pairs written as `M1 ~~ 0*M2`, `M1 ~~ 0*Y` and `M2 ~~ 0*Y`
#' (either order within a pair; an omitted or free statement is refused). The
#' saturated model has 14 free parameters (13 with the direct path fixed) and is just
#' identified with the direct path free, so a pair of variables that is never
#' observed together makes the fit fail closed (`medfit_sem_fiml_error` at the
#' numerical stage). The chain has 12 free parameters (11 with the direct path
#' fixed), is overidentified (2 or 3 degrees of freedom) and so is a restriction
#' the data can reject; it fails closed for fewer unobserved pairs. A graph with
#' exactly one of the two shortcuts, and a fixed or labeled shortcut, is refused.
#' With one covariate `Z` it predicts `M1`, `M2` and `Y` (`M1 ~ X + Z`,
#' `M2 ~ M1 + X + Z` or `M2 ~ M1 + Z`, `Y ~ ... + X + Z`), `X` and `Z` have a free
#' covariance, and every exogenous variable needs a written `Y` path (free; at most
#' one fixed at exactly zero, which makes that variable the treatment). The
#' saturated model then has 20 free parameters (19) and the chain 18 (17). With two
#' covariates `Z1` and `Z2` both predict every equation, the three exogenous
#' covariances (`X ~~ Z1`, `X ~~ Z2`, `Z1 ~~ Z2`) are all written or none (a
#' partial set is refused), and the saturated model has 27 free parameters (26) and
#' the chain 25 (24). In the pure chain the treatment is structural, the variable
#' with no path to `M2`: leaving a variable out of the equation of `M2` makes it the
#' treatment, and exactly one variable may be left out. In the saturated graph with
#' a fixed-zero direct path the variable with the fixed-zero path is the only valid
#' treatment.
#' [extract_mediation()] needs both mediators named in the fitted
#' order (the reversed order is refused) and returns a `FIMLSerialMediationData`
#' object with the full covariance of `a`, `a2` (X to M2), `d1` (M1 to M2), `b1`
#' (M1 to Y), `b` and `c_prime`; `nie()` is the chain effect `a * d1 * b`,
#' `nie(type = "total")` adds `a2 * b + a * b1`, and `paths()`, `tidy()`,
#' `coef(type = "paths")` and `summary()` list all six paths. For the chain the
#' object has the four paths `a`, `d1`, `b` and `c_prime`, and `nie()` and
#' `nie(type = "total")` are the same effect. The covariate's coefficients are never
#' paths: the aliases are the treatment's. In the saturated graph with a free direct
#' path a covariate may be named the treatment; in the pure chain naming a covariate
#' is refused (both covariates, with the classed `medfit_error_fiml_extract_unsupported`). Its normal intervals
#' are available; `pm()`, `quick()`, `glance()` and bootstrap intervals are not
#' (`bootstrap_mediation(source_fit = )` stays withheld, and behind that guard a
#' serial fit raises `medfit_error_fiml_serial_source_fit`). Serial models with three
#' or more covariates and every other serial shape stay refused.
#'
#' Supply `fixed_x = FALSE` explicitly; omission, `TRUE` and named subsets are errors.
#' Require `meanstructure = TRUE`, `information = "observed"`, `se_type = "model"`,
#' no weights, empty `control`, and `n_starts = NULL` or `3`. These numerical-control
#' restrictions reproduce the initial validated protocol. Missing values never
#' select FIML automatically, and a failed fit never falls back to listwise deletion.
#' [fit_mediation()] with `engine = "sem"` forwards these settings through `engine_args`; its
#' `se_type = "model"` remains a top-level argument.
#'
#' `nobs()` counts rows with any observed model variable; `n_dropped` counts only
#' all-empty rows. Singleton patterns and data with no complete rows are supported
#' when the local identification and information checks pass. Original positional
#' row IDs and pattern counts are retained. `logLik()` includes the full Gaussian
#' constants, with its `df` attribute equal to the free-parameter count (8 or 9 for three variables; see above for
#' covariates).
#' AIC and BIC use that likelihood and retained row count. The discrepancy `f` and
#' model-test `df` are `NA`: no saturated missing-data reference model is fitted.
#'
#' Supported operations include SEMFit coefficient/covariance and likelihood
#' summaries, parameter tidy/normal confidence intervals, and extraction followed by
#' `paths()`, `nie()`, `nde()`, `te()`, `coef()`, `vcov()`, print/summary, tidy and
#' normal path/effect confidence intervals. Extracted aliases follow topology;
#' source labels/full covariance remain in the validated durable fit context.
#' At a = b = 0, the NIE point value remains available but its inferential fields
#' are unavailable; a known fixed direct path is a different case.
#'
#' SEMFit `glance()` reports likelihood/IC fields with unavailable model-test fields;
#' extracted-object `glance()`, `quick()`, `pm()`, extracted-object bootstrap, profiles,
#' MBCO and fit tests remain unavailable. The [bootstrap_mediation()] `source_fit`
#' intervals are implemented but withheld (refused with a classed error) until
#' statistical admission is decided; a covariate fit is additionally refused with
#' `medfit_error_fiml_covariate_source_fit` (including a parallel fit with
#' covariates) and a parallel fit without covariates with
#' `medfit_error_fiml_parallel_source_fit`, so no source-fit interval exists for
#' either. Delta-method Wald intervals stay available for these extracted objects;
#' as for the three-variable model, the NIE standard error is `NA` only at the
#' exact origin (every a and b path exactly zero).
#' Object-aware package guards precede package-controlled refits/RNG/workers; opaque user callbacks and external-first
#' dispatch remain outside that guarantee. Adapter/topology/numerical failures retain
#' stage, reason, original parent and completed attempts; basic argument-type errors
#' can occur earlier. A dedicated `fiml-1` ledger binds likelihood, rows, settings
#' and attempts; the version-1 ledger below continues to describe listwise fits.
#' See the Methods and Formulas article, Bounded FIML, for the likelihood and
#' the sem engine guide for the supported workflow. Bounded FIML was introduced
#' in 0.16.0; released 0.15.0 does not provide this option.
#'
#' @section Nonzero-product search coverage:
#' One equality `c*a*b == q` is supported when the constants and `q/c` are finite and nonzero, `a` and `b`
#' are distinct free scalar labels after expanding definitions, and no other constraint row involves either label.
#' The engine fits both signs of `a` independently with the existing optimizer and acceptance gates, respecting
#' user bounds and effective variance floors. It returns the lowest accepted discrepancy only when each required
#' sign branch is accepted or excluded by an explicit bounds contradiction. An unresolved branch stops the fit
#' with `medfit_error_no_convergence`; an all-empty search returns no fit. Zero-product fitting is unchanged.
#' Repeated factors, multiple product equalities, coupled rows and other unsupported shapes retain local search.
#'
#' `internals$search_evidence` is a separate versioned internal record, not a change to the outcome-ledger schema.
#' Its `coverage` is `charted` for covered sign branches, `local` for unsupported shapes, or `unresolved` for an
#' incomplete search. It retains restrictions, context, branch states, candidates, objectives, gates and attempts;
#' validation checks their attribution to the model and sample. Charted coverage does not prove a global optimum
#' within a branch. Existing optimum status meanings are retained, and objects without this optional record remain
#' usable. Counts distinguish optimizer starts, accepted starts and synthetic reference attempts.
#'
#' The stored raw constraint residual is diagnostic only. Its optional standardized value uses the gradient and
#' covariance at an already available matching reference fit without the tested restriction, never the projected
#' constrained covariance. No additional fit or covariance calculation is requested. The ordinary optimizer reference
#' lacks covariance, so the standard error and standardized residual are `NA` with reason
#' `reference_covariance_unavailable`. These diagnostics do not affect acceptance or inference.
#'
#' @section Constrained standard errors:
#' Observed-information covariance includes the curvature of active nonlinear constraints; expected information
#' retains its Fisher definition. Sandwich standard errors use the corresponding information as bread.
#' Active inequalities, user bounds and solver variance floors give a local tangent covariance, with exactly zero
#' variance for a pinned coordinate. This is not the full sampling distribution at a boundary. See the
#' Methods and Formulas article, under Constraints, for the covariance formula.
#'
#' @return A [SEMFit] object. With a product term whose factor is a regression target (`x:m` with
#'   `m` regressed on `x`), `glance()` reports the chi-square, df and p-value as `NA` with a note, and
#'   `anova()` and [mbco_sem()] refuse; see [SEMFit-methods].
#'   `diagnostics$ledger` holds the versioned outcome ledger described below.
#'
#' @section Outcome ledger:
#' `diagnostics$ledger` is a list with `schema_version = 1L`. Each node has `id`, `parent_id`, the exact parsed
#' `constraints`, and `context` (the estimation `sample`, the model syntax and parameters, the likelihood `domain`,
#' the settings and `n_obs`). `enumeration` records `state` and the number of required children; `complete` means
#' every required restriction was attempted, not that any was globally optimized. `outcome` is `resolved` or
#' `unresolved`. Separate fields record `optimizer` (acceptance state, original status, decrement, retries and
#' optimum diagnostics), `likelihood` (availability and `f`), `feasibility` (`witness` or `unknown`), `covariance`
#' (`available`, `unavailable`, `not_retained` or `failed`), `improper`, the retained `notices` (warnings and
#' messages), the original `condition` (class, message, call) and the recursive `children`. IDs are deterministic
#' positions within the call, not certificates of equivalent parameter spaces. No global optimum is asserted, and a
#' failed branch is unknown, never certified infeasible.
#'
#' A node whose constraints hold zero-product rows also has `branch_map`: `state`, `raw_count`, the parser
#' `factor_counts`, `unique_count` and `raw_to_canonical`, a structural restriction-set ID for each raw row. The IDs
#' collapse duplicate or permuted constraint rows, not arbitrary affine equivalence, and every raw row is still fitted
#' in its original order (ties go to the first). More than 64 raw combinations, duplicates included, is refused before
#' the grid is allocated, even when the unique count would be smaller; that node is `not_enumerated`, with an unknown
#' unique count and no raw mapping, and nothing is fitted or certified. Its message prints the count without scientific
#' notation, labels a count above \eqn{2^{53}}{2^53} as approximate (a double need not be an exact cardinality there)
#' and names an overflow; `raw_count` is `Inf` on overflow. If the map cannot be built while an error is recorded, its
#' `state` is `unavailable` with that condition, and the original error is not replaced. The map is rebuilt from the
#' node's constraints during validation, so a forged map is refused.
#'
#' The one proof of emptiness in this version-1 ledger is the literal certificate `literal_zero_nonzero`: an explicit
#' `label == 0` equality and an explicit finite nonzero literal equality on the same parsed label (`a == 0` with
#' `a == 1`). Its label, source
#' rows and values are kept in `certificate` and rebuilt from the node's own parsed parameters and constraints before
#' any inference uses it. A certified-empty branch is retained with `outcome = "excluded"`,
#' `feasibility = "certified_empty"` and an unavailable likelihood: it is not fitted and is not a successful fit. No
#' tolerance, solver status, numerical rank, bound, general affine contradiction or fixed value in the parameter
#' table is a proof, and a literal too small to represent (`1e-999`) is unknown.
#'
#' A zero-product fit returns only if at least one required branch resolves and every other branch resolves or is
#' certified empty. A direct fit whose own equalities contradict literally stops with `medfit_sem_infeasible`, and a
#' union whose every branch is certified empty with `medfit_sem_empty_union`; both are refinements of
#' `medfit_error_no_convergence` and carry the ledger. Otherwise it stops with a
#' `medfit_error_no_convergence` error, never a fit; the error carries the ledger of every required branch as
#' `$ledger` and, when a branch survived, `$best_survivor` (its `id` and discrepancy `f`, diagnostic only, never a
#' p-value). The union's own node does not aggregate its children's notices; inspect each child. The notices of a
#' failed call are in the ledger only; the error message keeps its text. A data or model error keeps its own class
#' and also carries `$ledger`. The estimation sample is stored once, on the root node; a descendant fitted on the
#' same rows carries only `context$sample_hash`. A fit made before the ledger existed must be refitted before
#' [mbco_sem()] can use it, which refuses it with a `medfit_error_ledger` error.
#'
#' When the optimizer accepts a fit and the covariance stage explicitly diagnoses non-positive-definite information
#' or a negative variance, the call stops with
#' `medfit_sem_covariance_error`, never a fit. The class is a sibling of `medfit_error_no_convergence`: no optimizer
#' failed, so the handlers that report an unresolved result for an optimizer failure do not take it. Its fields are
#' `schema_version = 1L`, `stage = "covariance"`, `partial` (the accepted optimizer result: `f`, `theta`, sample,
#' domain, dimensions and settings; no `vcov` or `defined`) and `ledger` (the same node as `partial$ledger`, with
#' `covariance = "failed"` and `post_fit`: versioned evidence with the original condition's class, message, call and
#' diagnostic kind, `information_not_pd` or `negative_variance`). Other covariance errors propagate unchanged,
#' without a retained likelihood. Singular information still warns and returns an NA covariance, recorded as
#' `unavailable` rather than `failed`.
#' The message is the original one. Resolved here means an accounted-for accepted likelihood, not a successful
#' covariance. A union root reports the first failing branch's `post_fit`, in branch order, even when another branch
#' supplies its minimum likelihood, and does not claim the winning branch failed: inspect the branch IDs. A branch that
#' did not converge still stops the call with `medfit_error_no_convergence` first. Definition values and gradients are
#' checked before the covariance, and model, data, optimizer, objective and other errors get no covariance certificate.
#' The condition is not accepted as an input to [mbco_sem()], and a fit that carries `post_fit` is refused with
#' `medfit_error_ledger`.
#'
#' @examples
#' \donttest{
#' fit <- fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
#'   data = mediation_demo, fixed_x = FALSE, meanstructure = NULL
#' )
#' fit@defined
#'
#' # A treatment-by-mediator product: the four-way decomposition
#' fit4 <- fit_sem(
#'   "mediator1 ~ treatment\noutcome_int ~ treatment + mediator1 + treatment:mediator1",
#'   data = mediation_demo, se_type = "sandwich"
#' )
#' decompose(extract_mediation(fit4, treatment = "treatment", mediator = "mediator1",
#'                             outcome = "outcome_int"))
#' }
#'
#' @seealso [SEMFit], [fit_mediation()]
#' @export
fit_sem <- function(model, data, information = c("observed", "expected"), n_starts = NULL,
                    control = list(), weights = NULL, se_type = c("model", "sandwich"),
                    meanstructure = TRUE, fixed_x = TRUE, sampling_weights = lifecycle::deprecated(),
                    missing = c("listwise", "fiml"), cluster = NULL) {
  # 0.15.0 (E-14): missing() is only reliable before either argument is reassigned.
  fx_unset <- base::missing(fixed_x)
  missing_unset <- base::missing(missing)
  if (missing_unset) missing <- "listwise"
  if (!is.character(missing) || length(missing) != 1L || is.na(missing) ||
        !missing %in% c("listwise", "fiml")) {
    stop("`missing` must be exactly 'listwise' or 'fiml'", call. = FALSE)
  }
  ms_unset <- base::missing(meanstructure)
  if (lifecycle::is_present(sampling_weights)) {
    lifecycle::deprecate_warn("0.8.0", "fit_sem(sampling_weights)", "fit_sem(weights)")
    if (!is.null(weights)) {
      stop("pass `weights`, not both `weights` and the deprecated `sampling_weights`.", call. = FALSE)
    }
    weights <- sampling_weights
  }
  checkmate::assert_character(model, min.len = 1L, any.missing = FALSE, .var.name = "model")
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information)
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  # a plain list or a sem_control() object, resolved once to the plain nloptr list every internal receives (S2)
  resolved_control <- .sem_resolve_control(control, n_starts, !base::missing(n_starts) && !is.null(n_starts),
                                           missing)
  control <- resolved_control$control
  n_starts <- resolved_control$n_starts
  checkmate::assert_flag(meanstructure, null.ok = TRUE, .var.name = "meanstructure")
  checkmate::assert(
    checkmate::check_flag(fixed_x),
    checkmate::check_character(fixed_x, any.missing = FALSE, min.len = 1L, unique = TRUE),
    .var.name = "fixed_x"
  )
  se_type <- match.arg(se_type)
  checkmate::assert_string(cluster, min.chars = 1L, null.ok = TRUE, .var.name = "cluster")
  # Two-level route (S4a, experimental): before the FIML, weights and defaults dispatch, so none of them runs on a
  # model with `level:` blocks. A model that passes the guards is fitted by `.sem_fit_twolevel()` (S4a.4).
  if (!is.null(cluster) || .sem_has_level_lines(model)) {
    model <- paste(model, collapse = "\n")
    parsed <- .sem_twolevel_guard(model, data, cluster, information = information, weights = weights,
                                  se_type = se_type, missing = missing, fixed_x = fixed_x, fx_unset = fx_unset,
                                  meanstructure = meanstructure, ms_unset = ms_unset)
    fit <- .sem_fit_syntax(model, data, information, n_starts = if (is.null(n_starts)) 5L else n_starts,
                           control = control, se_type = se_type, parsed = parsed, meanstructure = TRUE,
                           fixed_x = FALSE, cluster = cluster)
    return(.sem_record_protocol(.sem_as_semfit(fit, model, match.call()), resolved_control$protocol))
  }
  if (missing == "fiml") {
    fit <- .sem_fiml_syntax(paste(model, collapse = "\n"), data, information, n_starts, control, weights, se_type,
                            meanstructure, fixed_x, fx_unset, match.call(), optimizer = resolved_control$optimizer)
    return(.sem_record_protocol(fit, resolved_control$protocol))
  }
  if (!is.null(weights) && se_type == "model") {
    .notify_ipw_model_se()
  }
  model <- paste(model, collapse = "\n")
  if (fx_unset || ms_unset) {
    resolved <- .native_defaults_resolve(model, data, fixed_x, meanstructure, fx_unset, ms_unset)
    fixed_x <- resolved$fixed_x
    meanstructure <- resolved$meanstructure
  }
  fit <- .sem_fit_syntax(model, data, information, n_starts = if (is.null(n_starts)) 5L else n_starts,
                         control = control, weights = weights, se_type = se_type, meanstructure = meanstructure,
                         fixed_x = fixed_x)
  .sem_record_protocol(.sem_as_semfit(fit, model, match.call()), resolved_control$protocol)
}

# Whether the syntax has a `level:` line; statements are split as the parser splits them, so comments and `;` count.
.sem_has_level_lines <- function(model) {
  stmts <- .sem_statements(unlist(strsplit(paste(model, collapse = "\n"), "\n", fixed = TRUE)))
  any(grepl("^level\\s*:(?!=)", stmts, perl = TRUE))
}

# The two-level guards (plan S4a, Refused table), in order: `level:` names and order, `cluster` and its column, the
# refused features, the `fixed_x` / `meanstructure` / `information` settings, then the W and Z variable sets (which
# read the data, so the features that would name non-columns, latent variables and products, are refused first).
# Unset `fixed_x` resolves to FALSE and unset `meanstructure` to TRUE silently (U2): no 0.15.0 default ever applied
# to a two-level model, so `.native_defaults_resolve()` is not consulted. Returns the parsed model for the fit.
.sem_twolevel_guard <- function(model, data, cluster, information, weights, se_type, missing, fixed_x, fx_unset,
                                meanstructure, ms_unset) {
  parsed <- .sem_resolve_levels(.sem_parse(model), cluster)
  abort <- function(msg, what) .twolevel_abort(msg, paste0("medfit_error_twolevel_", what))
  has_levels <- length(parsed$levels$tokens) > 0L
  if (!has_levels) {
    abort("`cluster` is given but the model has no `level:` blocks; write `level: 1` and `level: 2` blocks", "cluster")
  }
  if (is.null(cluster)) {
    abort("the model uses `level:` blocks but `cluster` is not given; name the cluster variable with `cluster =`",
          "cluster")
  }
  if (!cluster %in% names(data)) {
    abort(sprintf("`cluster`: '%s' is not a column of `data`", cluster), "cluster")
  }
  if (anyNA(data[[cluster]])) {
    abort(sprintf("the cluster variable '%s' has missing values; drop those rows first", cluster), "cluster")
  }
  if (length(unique(data[[cluster]])) < 2L) {
    abort(sprintf("the cluster variable '%s' has fewer than 2 clusters; a two-level model needs at least 2 clusters",
                  cluster), "cluster")
  }
  p <- parsed$parameters
  if (any(p$op == "=~")) {
    abort("latent variables (`=~`) are not supported in a two-level model", "latent")
  }
  if (any(grepl(":", p$rhs, fixed = TRUE))) {
    abort("a product term (`x:m`) is not supported in a two-level model", "product")
  }
  if (!is.null(weights)) {
    abort("`weights` are not supported in a two-level model", "weights")
  }
  if (missing == "fiml") {
    abort("missing = \"fiml\" is not supported in a two-level model; incomplete rows are dropped (listwise)",
          "missing")
  }
  # one nonlinear row shape is admitted (IG3 T-B): the within indirect effect equal to the between one
  if (.sem_has_nonlinear_constraint(parsed$constraints) &&
        !.sem_equal_products_only(parsed$constraints, parsed$parameters)) {
    abort(paste0("nonlinear constraints (including a product of labels set to zero) are not supported in a two-level ",
                 "model; the one exception is the equality of the within and the between indirect effect, ",
                 "`a_w*b_w == a_b*b_b`"),
          "nonlinear")
  }
  if (!fx_unset && !isFALSE(fixed_x)) {
    abort(paste0("a two-level model takes `fixed_x = FALSE` only (the default there); ",
                 "fixed exogenous moments are not supported"), "fixed_x")
  }
  if (!ms_unset && isFALSE(meanstructure)) {
    abort("a two-level model needs the mean structure (the between-level means); `meanstructure = FALSE` is refused",
          "meanstructure")
  }
  if (information == "expected") {
    abort("information = \"expected\" is not supported in a two-level model; use \"observed\"", "information")
  }
  .sem_twolevel_sets(parsed, data, cluster)
  parsed
}

# Whether any `==`, `<` or `>` constraint is nonlinear in the labels, after defined parameters are substituted (a
# zero-product branch, `a*b == 0`, is one).
.sem_has_nonlinear_constraint <- function(constraints) {
  defs <- constraints[constraints$op == ":=", , drop = FALSE]
  defs <- .sem_defs(stats::setNames(defs$rhs, defs$lhs))
  for (i in which(constraints$op %in% c("==", "<", ">"))) {
    tree <- .sem_expr_subst(.sem_expr_parse(paste0("(", constraints$lhs[i], ") - (", constraints$rhs[i], ")")), defs)
    if (!.sem_tree_linear(tree)) {
      return(TRUE)
    }
  }
  FALSE
}

# Whether the only nonlinear constraint is exactly one equality of the within indirect effect and the between one:
# `a_w*b_w == a_b*b_b`, in either written order and either factor order, where each product is a chain (`m ~ x` labeled
# a, `y ~ m` labeled b) at one level and the two chains have the same x, m and y at levels 1 and 2. Every other
# nonlinear row (`a_w*a_b == b_w*b_b`, a product with `cp`, a constant, an inequality, three factors, a second row, and
# a defined parameter standing for a product, whose name is not a regression label) is another shape and stays refused:
# only this pairing has an oracle and a gate (IG3 T-B). A serial chain (`a*d` or `d*b` with the same x, m, y at both
# levels) has the same shape and is admitted, but has no separate oracle or gate.
# `parameters` is the parsed table with its levels resolved.
.sem_equal_products_only <- function(constraints, parameters) {
  defs <- constraints[constraints$op == ":=", , drop = FALSE]
  defs <- .sem_defs(stats::setNames(defs$rhs, defs$lhs))
  two_labels <- function(e) {
    while (is.call(e) && identical(e[[1L]], as.name("("))) e <- e[[2L]]
    if (is.call(e) && identical(e[[1L]], as.name("*")) && length(e) == 3L && is.symbol(e[[2L]]) &&
          is.symbol(e[[3L]])) {
      c(as.character(e[[2L]]), as.character(e[[3L]]))
    }
  }
  reg <- parameters[parameters$op == "~" & !is.na(parameters$label) & nzchar(parameters$label), , drop = FALSE]
  # the chain of a product at one level: c(level, x, m, y), or NULL when it is not an a-then-b chain
  chain <- function(labels) {
    rows <- lapply(labels, function(l) reg[reg$label == l, , drop = FALSE])
    if (any(vapply(rows, nrow, 1L) != 1L) || rows[[1L]]$level != rows[[2L]]$level) {
      return(NULL)
    }
    for (k in 1:2) {
      a_row <- rows[[k]]
      b_row <- rows[[3L - k]]
      if (identical(a_row$lhs, b_row$rhs)) {
        return(c(level = a_row$level, x = a_row$rhs, m = a_row$lhs, y = b_row$lhs))
      }
    }
    NULL
  }
  n_nl <- 0L
  for (i in which(constraints$op %in% c("==", "<", ">"))) {
    lhs <- .sem_expr_parse(constraints$lhs[i])
    rhs <- .sem_expr_parse(constraints$rhs[i])
    if (.sem_tree_linear(.sem_expr_subst(call("-", lhs, rhs), defs))) {
      next
    }
    n_nl <- n_nl + 1L
    pair <- list(two_labels(lhs), two_labels(rhs))
    if (constraints$op[i] != "==" || n_nl > 1L || any(vapply(pair, is.null, TRUE)) || anyDuplicated(unlist(pair))) {
      return(FALSE)
    }
    ch <- lapply(pair, chain)
    if (any(vapply(ch, is.null, TRUE)) || !setequal(c(ch[[1L]][["level"]], ch[[2L]][["level"]]), c("1", "2")) ||
          !identical(unname(ch[[1L]][-1L]), unname(ch[[2L]][-1L]))) {
      return(FALSE)
    }
  }
  n_nl == 1L
}

# the resolved search protocol goes in diagnostics, after the fit (and the FIML ledger binding) are built
.sem_record_protocol <- function(fit, protocol) {
  dg <- fit@diagnostics
  dg$protocol <- protocol
  fit@diagnostics <- dg
  fit
}

.sem_as_semfit <- function(fit, model, call = NULL) {
  .sem_require_outcome(fit, model)
  tab <- fit$table
  free <- !is.na(fit$par_map)
  est <- ifelse(free, fit$theta[pmax(fit$par_map, 1L)], tab$fixed)
  se <- ifelse(free, sqrt(diag(fit$vcov))[pmax(fit$par_map, 1L)], NA_real_)
  table <- data.frame(
    lhs = tab$lhs, op = tab$op, rhs = tab$rhs, label = tab$label, free = free,
    est = unname(est), se = unname(se), fixed_x = tab$fixed_x, stringsAsFactors = FALSE
  )
  # a two-level fit keeps each row's level (S4a.4)
  if (!is.null(tab$level) && isTRUE(fit$ram$twolevel)) table$level <- tab$level
  internals <- fit[c("ram", "par_map", "constraints", "partable", "weights", "eq_rank", "n_starts", "control",
                     "branch", "fixed_x", "factors", "search_evidence")]
  # a two-level fit keeps the cluster column's name and the cluster of every kept row (S4a.5: extraction, glance())
  if (isTRUE(fit$ram$twolevel)) internals[c("cluster", "cluster_ids")] <- fit[c("cluster", "cluster_ids")]
  SEMFit(
    theta = fit$theta, vcov = fit$vcov, table = table, defined = fit$defined, f = fit$f,
    n_obs = fit$n_obs, n_dropped = fit$n_dropped, df = fit$df, information = fit$information,
    converged = fit$converged, data = fit$data, model = model,
    diagnostics = fit[c("status", "decrement", "retries", "active_bounds", "active_constraints", "improper",
                        "sign_check", "se_type", "optimum", "ledger")],
    internals = internals,
    call = call
  )
}

# `fit_mediation(engine = "sem")` (alias "native"): fit the syntax with the sem engine, then
# extract the mediation structure through the shared workers. Reached before the
# formula validation of the other engines, since the native route takes `model`,
# not formulas, and a latent mediator is not a column of `data`. Every argument
# the engine cannot honor errors, never silently ignored. `weights` and `se_type` pass to `fit_sem()`.
.fit_mediation_native <- function(model, data, treatment, mediator, given, weights, se_type, cluster,
                                  engine_args, m_star, dots) {
  if (given$formulas) {
    stop("engine = \"sem\" takes `model =`, not formulas", call. = FALSE)
  }
  if (is.null(model)) {
    stop("engine = \"sem\" needs `model`, the model syntax.", call. = FALSE)
  }
  checkmate::assert_character(model, min.len = 1L, any.missing = FALSE, .var.name = "model")
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  checkmate::assert_string(treatment, .var.name = "treatment")
  checkmate::assert_string(mediator, .var.name = "mediator")
  checkmate::assert_list(engine_args, names = "unique", .var.name = "engine_args")
  if (!is.null(weights)) {
    checkmate::assert_numeric(weights, len = nrow(data), lower = 0, any.missing = FALSE, .var.name = "weights")
  }
  if (se_type == "kr") {
    stop("se_type = \"kr\" (Kenward-Roger) is only used with engine = \"lmer\".", call. = FALSE)
  }
  if (given$family) {
    stop("engine = \"sem\" fits Gaussian models; `family_y` and `family_m` are not used.", call. = FALSE)
  }
  if (length(dots)) {
    stop("unused arguments for engine = \"sem\": ", paste(names(dots), collapse = ", "), call. = FALSE)
  }
  fit_args <- c("information", "n_starts", "control", "meanstructure", "fixed_x", "missing")
  extract_args <- c("outcome", "structure", "decomposition", "interaction", "a_label", "b_label", "cp_label")
  unknown <- setdiff(names(engine_args), c(fit_args, extract_args))
  if (length(unknown)) {
    stop("unknown `engine_args` for engine = \"sem\": ", paste(unknown, collapse = ", "),
         ". Recognized: ", paste(c(fit_args, extract_args), collapse = ", "), ".", call. = FALSE)
  }
  syntax <- paste(model, collapse = "\n")
  # A product term (`m:x`) names two variables; a treatment that only appears inside one is still in the model.
  vars <- unique(unlist(strsplit(unlist(.sem_parse(syntax)$parameters[c("lhs", "rhs")]), ":", fixed = TRUE)))
  for (nm in c(treatment = treatment, mediator = mediator)) {
    if (!(nm %in% vars)) {
      stop(sprintf("'%s' is not a variable in `model`", nm), call. = FALSE)
    }
  }
  fit <- do.call(
    fit_sem,
    c(list(model = syntax, data = data, weights = weights, se_type = se_type),
      engine_args[intersect(names(engine_args), fit_args)],
      # `cluster` (two-level, experimental) only when given, so fit_sem() sees it as absent otherwise
      if (!is.null(cluster)) list(cluster = cluster))
  )
  extract_call <- c(
    list(object = fit, treatment = treatment, mediator = mediator),
    engine_args[intersect(names(engine_args), extract_args)],
    if (given$m_star) list(m_star = m_star)
  )
  do.call(extract_mediation, extract_call)
}
