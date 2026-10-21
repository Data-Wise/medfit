# Native SEM engine: anova() for nested SEMFits (0.8.0 T10, ledger G9).
# Oracles: the S19 known answers on RMediation's `memory_exp` (OpenMx diffLL 221.045546 for a1 == 0 and
# 0.083100 for b1 == 0), chi-square tail probabilities worked by hand (statistic 4: p = 0.0455 at df 1,
# 0.1353 at df 2), and mbco_sem(), which differences the same discrepancy per refit. Planted defects: the
# infeasible-point value 0, the df mutated, the boundary check removed, a refusal removed.

anova_mem <- function() {
  path <- testthat::test_path("fixtures", "memory_exp.rds")
  if (!file.exists(path)) testthat::skip("tests/testthat/fixtures/memory_exp.rds is not present")
  readRDS(path)
}

anova_syntax <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

anova_fits <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      d <- anova_mem()
      cache <<- list(
        d = d,
        full = fit_sem(anova_syntax, d),
        b1 = fit_sem(paste0(anova_syntax, "\nb1 == 0"), d),
        a1 = fit_sem(paste0(anova_syntax, "\na1 == 0"), d),
        both = fit_sem(paste0(anova_syntax, "\nb1 == 0\na1 == 0"), d)
      )
    }
    cache
  }
})

test_that("known answers: both memory_exp diffLL values, df, p and the layout", {
  f <- anova_fits()
  a <- anova(f$full, f$b1)
  expect_s3_class(a, c("anova", "data.frame"))
  expect_named(a, c("Df", "Chisq", "Chisq diff", "Df diff", "Pr(>Chisq)"))
  expect_identical(rownames(a), c("f$full", "f$b1"))
  expect_lt(abs(a[2, "Chisq diff"] - 0.083100), 1e-6)
  expect_lt(abs(anova(f$a1, f$full)[2, "Chisq diff"] - 221.045546), 1e-6)
  expect_equal(a[2, "Df diff"], 1)
  expect_equal(a[2, "Df"] - a[1, "Df"], 1)
  expect_equal(a[1, "Chisq"], f$full@n_obs * f$full@f)
  expect_equal(a[2, "Pr(>Chisq)"], stats::pchisq(a[2, "Chisq diff"], 1, lower.tail = FALSE))
  expect_true(all(is.na(a[1, c("Chisq diff", "Df diff", "Pr(>Chisq)")])))
})

test_that("anova() reproduces the per-refit diffLL of mbco_sem()", {
  f <- anova_fits()
  m <- mbco_sem(f$full, "a1", "b1")
  expect_equal(anova(f$full, f$a1)[2, "Chisq diff"], m$tests$diff_ll[m$tests$constraint == "a1 == 0"],
               tolerance = 1e-8)
  expect_equal(anova(f$full, f$b1)[2, "Chisq diff"], m$tests$diff_ll[m$tests$constraint == "b1 == 0"],
               tolerance = 1e-8)
})

test_that("the p-value uses the df difference: statistic 4 gives 0.0455 at df 1 and 0.1353 at df 2", {
  f <- anova_fits()
  # shift the restricted discrepancy so the statistic is exactly 4 (the oracle is the hand-worked tail)
  for (case in list(list(r = f$b1, df = 1, p = 0.0455), list(r = f$both, df = 2, p = 0.1353))) {
    r <- case$r
    r@f <- f$full@f + 4 / f$full@n_obs
    a <- anova(f$full, r)
    expect_equal(a[2, "Df diff"], case$df)
    expect_equal(a[2, "Chisq diff"], 4, tolerance = 1e-8)
    expect_lt(abs(a[2, "Pr(>Chisq)"] - case$p), 5e-5)
  }
})

test_that("the models are ordered by df, named by argument or by name, and a chain tests successive pairs", {
  f <- anova_fits()
  chain <- anova(f$both, f$full, f$b1)
  expect_identical(rownames(chain), c("f$full", "f$b1", "f$both"))
  expect_equal(chain[2, "Chisq diff"], anova(f$full, f$b1)[2, "Chisq diff"], tolerance = 1e-12)
  expect_equal(chain[3, "Chisq diff"], anova(f$b1, f$both)[2, "Chisq diff"], tolerance = 1e-12)
  expect_equal(chain[3, "Df diff"], 1)
  named <- anova(f$full, restricted = f$b1)
  expect_identical(rownames(named), c("f$full", "restricted"))
})

test_that("refit trap: a restricted fit from a clean start gives 0.083100 and never the infeasible-point 0", {
  f <- anova_fits()
  good <- anova(f$full, f$b1)[2, "Chisq diff"]
  expect_lt(abs(good - 0.083100), 1e-6)
  expect_gt(good, 0.08)
  # medfit's optimizer reaches the same value when the refit is seeded from the full fit's estimates, so the
  # OpenMx trap (a constraint added to an already-fitted model stops at the infeasible point, diffLL 0) does
  # not arise in the engine; the fixture still pins the value
  seeded <- sem_mutate(
    .sem_fit_syntax, "start <- .sem_default_start(ram, smp)",
    "start <- .sem_default_start(ram, smp); start[] <- SEED[ram$par_names]"
  )
  environment(seeded) <- list2env(list(SEED = f$full@theta), parent = environment(.sem_fit_syntax))
  r <- seeded(paste0(anova_syntax, "\nb1 == 0"), f$d, n_starts = 1L)
  expect_lt(abs(r$n_obs * (r$f - f$full@f) - 0.083100), 1e-6)
  # planted defect: a restricted fit that never left the full fit's point (diffLL 0) misses the fixture
  stuck <- f$b1
  stuck@f <- f$full@f
  expect_lt(anova(f$full, stuck)[2, "Chisq diff"], 1e-12)
  expect_gt(abs(anova(f$full, stuck)[2, "Chisq diff"] - 0.083100), 0.08)
})

test_that("planted defects: a wrong df or a wrong n misses the known answers", {
  f <- anova_fits()
  good <- anova(f$full, f$a1)
  wrong_df <- sem_mutate(.sem_anova, "ddf <- df[[i]] - df[[i - 1L]]", "ddf <- 2")
  expect_gt(abs(wrong_df(list(a = f$full, b = f$a1))[2, "Pr(>Chisq)"] - good[2, "Pr(>Chisq)"]), 0)
  expect_equal(wrong_df(list(a = f$full, b = f$b1))[2, "Df diff"], 2)
  wrong_n <- sem_mutate(.sem_anova, "n <- models[[1L]]@n_obs", "n <- models[[1L]]@n_obs - 1L")
  expect_gt(abs(wrong_n(list(a = f$full, b = f$b1))[2, "Chisq diff"] - 0.083100), 1e-6)
})

test_that("it refuses fewer than two fits, a non-SEMFit, weights and a fit that did not converge", {
  f <- anova_fits()
  expect_error(anova(f$full), "at least two fits")
  expect_error(anova(f$full, lm(1 ~ 1)), "not a SEMFit")
  weighted <- fit_sem(paste0(anova_syntax, "\nb1 == 0"), f$d, weights = rep(1, nrow(f$d)),
                      se_type = "sandwich")
  expect_error(anova(f$full, weighted), "sampling weights")
  bad <- f$b1
  bad@converged <- FALSE
  expect_error(anova(f$full, bad), "did not converge")
})

test_that("it refuses different data, different variables, equal df, and a model that is not nested", {
  f <- anova_fits()
  d2 <- f$d
  d2$recall <- d2$recall + stats::rnorm(nrow(d2), sd = 0.5)
  other <- fit_sem(paste0(anova_syntax, "\nb1 == 0"), d2)
  expect_error(anova(f$full, other), "different data")
  few <- fit_sem(paste0(anova_syntax, "\nb1 == 0"), f$d[-1L, ])
  expect_error(anova(f$full, few), "different numbers of rows")
  fewer_vars <- fit_sem("repetition ~ a1*x\nimagery ~ a2*x", f$d)
  expect_error(anova(f$full, fewer_vars), "same observed variables")
  expect_error(anova(f$b1, f$a1), "same degrees of freedom")
  # frees a parameter the full model leaves out (a residual covariance) while dropping two paths: df is larger
  # but the model is not nested in the full one
  not_nested <- fit_sem("repetition ~ a1*x\nrecall ~ b1*repetition + b2*imagery\nimagery ~~ repetition\nimagery ~ 0*x",
                        f$d)
  expect_gt(not_nested@df, f$full@df)
  expect_error(anova(f$full, not_nested), "not nested")
  # the same pair is refused whatever the argument order
  expect_error(anova(not_nested, f$full), "not nested")
})

test_that("a nonzero fixed residual covariance cannot appear or disappear across nested fits", {
  set.seed(32)
  d <- data.frame(X = stats::rnorm(400))
  d$M1 <- 0.5 * d$X + stats::rnorm(400)
  d$M2 <- 0.4 * d$X + stats::rnorm(400)
  d$Y <- 0.3 * d$M1 + 0.2 * d$M2 + 0.1 * d$X + stats::rnorm(400)
  base <- "M1 ~ a1*X\nM2 ~ a2*X\nY ~ b1*M1 + b2*M2 + cp*X"
  restricted <- "M1 ~ a1*X\nM2 ~ a2*X\nY ~ b1*M1 + 0*M2 + 0*X"
  full <- fit_sem(base, d)
  added <- fit_sem(paste0(restricted, "\nM1 ~~ 0.5*M2"), d)
  expect_gt(added@df, full@df)
  expect_error(anova(full, added), "not nested.*nonzero fixed parameters.*M1 ~~ M2")
  # Planted defect: skipping the new guard restores the spurious chi-square p-value.
  silent <- sem_mutate(.sem_anova_nested,
                       "changed <- c(missing_fixed(restricted_tab, full_tab), missing_fixed(full_tab, restricted_tab))",
                       "changed <- character()")
  unchecked <- sem_mutate(.sem_anova, "tested <- .sem_anova_nested(full, restricted, label)",
                          "tested <- SILENT(full, restricted, label)")
  environment(unchecked) <- list2env(list(SILENT = silent), parent = environment(.sem_anova))
  expect_true(is.finite(unchecked(list(full = full, added = added))[2, "Pr(>Chisq)"]))
  fixed_full <- fit_sem(paste0(base, "\nM1 ~~ 0.5*M2"), d)
  omitted <- fit_sem(restricted, d)
  expect_gt(omitted@df, fixed_full@df)
  expect_error(anova(fixed_full, omitted), "not nested.*nonzero fixed parameters.*M1 ~~ M2")
})

test_that("a restricted fit with a smaller discrepancy than the model it restricts is refused", {
  f <- anova_fits()
  worse <- f$b1
  worse@f <- f$full@f - 0.01
  expect_error(anova(f$full, worse), "global optimum")
  # a difference within roundoff is clamped to zero, not an error
  tiny <- f$b1
  tiny@f <- f$full@f - 1e-12
  expect_equal(anova(f$full, tiny)[2, "Chisq diff"], 0)
})

boundary_data <- function(n = 500, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = stats::rnorm(n))
  d$M <- 0.5 * d$X + stats::rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(n)
  d
}
boundary_base <- "M ~ a*X\nY ~ b*M + cp*X"

boundary_pair <- function(extra, null = "a == 0") {
  d <- boundary_data()
  list(
    full = fit_sem(paste0(boundary_base, "\n", extra), d),
    null = fit_sem(paste0(boundary_base, "\n", extra, "\n", null), d)
  )
}

test_that("a null on the boundary warns as mbco_sem() does; an interior or unrelated constraint does not", {
  # a > 0: the null a == 0 sits on the bound, so the statistic is a mixture, not chi-square(df)
  on_edge <- boundary_pair("a > 0")
  expect_warning(anova(on_edge$full, on_edge$null), "boundary")
  expect_warning(mbco_sem(on_edge$full, "a", "b"), "boundary")
  # an inequality row that binds at the null fit
  row <- boundary_pair("a - b > -0.3")
  expect_warning(anova(row$full, row$null), "boundary")
  # a < 0.2: the null a == 0 is interior
  interior <- boundary_pair("a < 0.2")
  expect_no_warning(res <- anova(interior$full, interior$null))
  expect_true(is.finite(res[2, "Chisq diff"]))
  # active at the null fit but on parameters other than the tested one, and an inactive row
  other <- boundary_pair("b + cp < 0.5")
  expect_no_warning(anova(other$full, other$null))
  inactive <- boundary_pair("b + cp < 5")
  expect_no_warning(anova(inactive$full, inactive$null))
})

test_that("a null written by fixing the path in the syntax equals the one written as a constraint", {
  d <- boundary_data()
  full <- fit_sem(boundary_base, d)
  fixed <- fit_sem("M ~ 0*X\nY ~ b*M + cp*X", d)
  constrained <- fit_sem(paste0(boundary_base, "\na == 0"), d)
  expect_equal(anova(full, fixed)[2, "Chisq diff"], anova(full, constrained)[2, "Chisq diff"], tolerance = 1e-6)
  expect_equal(anova(full, fixed)[2, "Df diff"], 1)
})

test_that("a null written on a defined parameter is compared like any other", {
  d <- boundary_data()
  base <- paste0(boundary_base, "\ns := a + b")
  full <- fit_sem(base, d)
  via_def <- fit_sem(paste0(base, "\ns == 0.5"), d)
  via_row <- fit_sem(paste0(boundary_base, "\na + b == 0.5"), d)
  res <- anova(full, via_def)
  expect_equal(res[2, "Df diff"], 1)
  expect_equal(res[2, "Chisq diff"], anova(fit_sem(boundary_base, d), via_row)[2, "Chisq diff"], tolerance = 1e-6)
  # a bound on a parameter inside the defined sum still marks the null as on the boundary
  edge_full <- fit_sem(paste0(base, "\na > 0"), d)
  edge_null <- fit_sem(paste0(base, "\na > 0\ns == 0.5\nb == 0.5"), d)
  expect_warning(anova(edge_full, edge_null), "boundary")
})

test_that("planted defect: without the boundary check the on-the-edge null passes silently", {
  on_edge <- boundary_pair("a > 0")
  silent <- sem_mutate(.sem_anova, ".sem_anova_warn_boundary(restricted, tested, label)", "TRUE")
  expect_no_warning(res_silent <- silent(list(full = on_edge$full, null = on_edge$null)))
  expect_warning(res <- .sem_anova(list(full = on_edge$full, null = on_edge$null)), "boundary")
  # the structured flag says what the warning says, and the mutant that skips the check reports a valid p-value
  expect_false(attr(res, "p_valid")[[2L]])
  expect_true(attr(res_silent, "p_valid")[[2L]])
})

test_that("the p_valid attribute marks a boundary null FALSE and keeps the p-value", {
  on_edge <- boundary_pair("a > 0")
  expect_warning(res <- anova(on_edge$full, on_edge$null), "boundary")
  pv <- attr(res, "p_valid")
  expect_identical(names(pv), rownames(res))
  expect_true(is.na(pv[[1L]]))
  expect_false(pv[[2L]])
  expect_true(is.finite(res[2, "Pr(>Chisq)"]))
  # an interior null and an unrelated active row are valid
  interior <- boundary_pair("a < 0.2")
  expect_true(attr(anova(interior$full, interior$null), "p_valid")[[2L]])
  other <- boundary_pair("b + cp < 0.5")
  expect_true(attr(anova(other$full, other$null), "p_valid")[[2L]])
  # a chain: only the row whose restricted fit sits on the boundary is invalid
  chain <- anova_fits()
  expect_true(all(attr(anova(chain$full, chain$b1), "p_valid")[-1L]))
})

test_that("print uses the anova layout with a heading", {
  f <- anova_fits()
  out <- paste(utils::capture.output(print(anova(f$full, f$b1))), collapse = "\n")
  expect_match(out, "Likelihood-ratio", fixed = TRUE)
  expect_match(out, "Pr(>Chisq)", fixed = TRUE)
  expect_match(out, "n = 369", fixed = TRUE)
})

# Nesting must hold for the constraints and fixed values of the larger model, not only for the free rows.
nest_model <- function(tail) {
  fit_sem(paste0("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\n", tail), medfit::mediation_demo)
}

test_that("a restricted model that breaks the larger model's equality is not nested in it", {
  full <- nest_model("a == b")
  broken <- nest_model("a == 0\nb == 0.5")
  expect_error(anova(full, broken), "not nested")
})

test_that("a restricted model that implies the larger model's equality is nested in it", {
  full <- nest_model("a == b")
  zero <- nest_model("a == 0\nb == 0")
  half <- nest_model("a == 0.5\nb == 0.5")
  res <- anova(full, zero)
  expect_equal(res$Df, c(full@df, zero@df))
  expect_no_error(anova(full, half))
})

test_that("a fixed value of the larger model must be kept", {
  full <- fit_sem("mediator1 ~ a*treatment\noutcome ~ 0.5*mediator1 + treatment", mediation_demo)
  same <- fit_sem("mediator1 ~ 0*treatment\noutcome ~ 0.5*mediator1 + treatment", mediation_demo)
  moved <- fit_sem("mediator1 ~ 0*treatment\noutcome ~ 0.4*mediator1 + treatment", mediation_demo)
  expect_no_error(anova(full, same))
  expect_error(anova(full, moved), "not nested")
})

test_that("a nonlinear or inequality constraint of the larger model must appear in the restricted one", {
  full <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\ncp == a*b", mediation_demo)
  drop <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\ncp == 0\nb == 0", mediation_demo)
  expect_error(anova(full, drop), "not nested")
})

test_that("planted defect: without the constraint check the broken pair returns a p-value", {
  full <- nest_model("a == b")
  broken <- nest_model("a == 0\nb == 0.5")
  silent <- sem_mutate(.sem_anova_nested, "kept <- .sem_anova_kept(full, restricted)", "kept <- NULL")
  expect_no_error(silent(full, broken, c("full", "broken")))
})

test_that("a bound of the larger model must be kept by the restricted model", {
  fit_b <- function(m) fit_sem(paste0(m, "\noutcome ~ mediator1 + treatment"), mediation_demo)
  bounded <- fit_b("mediator1 ~ lower(0)*treatment")
  expect_error(anova(bounded, fit_b("mediator1 ~ -1*treatment")), "not nested")
  expect_no_error(anova(bounded, fit_b("mediator1 ~ 0*treatment")))
})

test_that("a single-label inequality of the larger model is a bound and must be kept", {
  base <- "mediator1 ~ a1*treatment\noutcome ~ b1*mediator1 + a2*treatment\n"
  full <- fit_sem(paste0(base, "a1 > 0.1"), mediation_demo)
  expect_error(anova(full, fit_sem(paste0(base, "a2 == 0"), mediation_demo)), "not nested")
  expect_no_error(anova(full, fit_sem(paste0(base, "a1 > 0.1\na2 == 0"), mediation_demo)))
})

test_that("planted defect: without the bound check the dropped bound returns a p-value", {
  base <- "mediator1 ~ a1*treatment\noutcome ~ b1*mediator1 + a2*treatment\n"
  full <- fit_sem(paste0(base, "a1 > 0.1"), mediation_demo)
  rest <- fit_sem(paste0(base, "a2 == 0"), mediation_demo)
  silent <- sem_mutate(.sem_anova_kept, ".sem_anova_bounds_kept(full, restricted), ", "")
  expect_length(silent(full, rest), 0L)
  expect_length(.sem_anova_kept(full, rest), 1L)
})

test_that("a shared label of the larger model is an equality the restricted model must keep", {
  full <- fit_sem("mediator1 ~ a*treatment + g*mediator2\noutcome ~ a*mediator1 + cp*treatment", mediation_demo)
  released <- fit_sem("mediator1 ~ a*treatment + 0*mediator2\noutcome ~ b*mediator1 + 0*treatment", mediation_demo)
  expect_error(anova(full, released), "not nested")
  kept <- fit_sem("mediator1 ~ a*treatment + 0*mediator2\noutcome ~ a*mediator1 + 0*treatment", mediation_demo)
  expect_no_error(anova(full, kept))
  # the same tie written as an explicit equality is kept as well
  tied <- fit_sem("mediator1 ~ a*treatment + 0*mediator2\noutcome ~ b*mediator1 + 0*treatment\na == b", mediation_demo)
  expect_no_error(anova(full, tied))
})

test_that("planted defect: without the tie check the released shared label returns a p-value", {
  full <- fit_sem("mediator1 ~ a*treatment + g*mediator2\noutcome ~ a*mediator1 + cp*treatment", mediation_demo)
  released <- fit_sem("mediator1 ~ a*treatment + 0*mediator2\noutcome ~ b*mediator1 + 0*treatment", mediation_demo)
  expect_gt(length(.sem_anova_kept(full, released)), 0L)
  silent <- sem_mutate(.sem_anova_kept, ", .sem_anova_ties_kept(full, restricted))", ")")
  expect_length(silent(full, released), 0L)
})

test_that("an active nonlinear inequality at the restricted fit warns that the null is on the boundary", {
  base <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\n"
  full <- fit_sem(paste0(base, "a*b > 0"), mediation_demo)
  null <- fit_sem(paste0(base, "a*b > 0\nb == 0"), mediation_demo)
  expect_warning(anova(full, null), "a\\*b > 0")
})

test_that("planted defect: without the nonlinear branch the boundary guard stays silent", {
  base <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\n"
  null <- fit_sem(paste0(base, "a*b > 0\nb == 0"), mediation_demo)
  state <- list(active_bounds = null@diagnostics$active_bounds, constraints = null@internals$constraints,
                ram = null@internals$ram, theta = null@theta)
  expect_length(.sem_boundary_active(state, "b"), 1L)
  silent <- sem_mutate(.sem_boundary_active, "nli <- rows$nli", "nli <- NULL")
  expect_length(silent(state, "b"), 0L)
})

test_that("mbco_sem warns on an active nonlinear inequality too", {
  fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment\na*b > 0", mediation_demo)
  warned <- testthat::capture_warnings(mbco_sem(fit, a = "a", b = "b"))
  expect_true(any(grepl("boundary", warned)))
})
