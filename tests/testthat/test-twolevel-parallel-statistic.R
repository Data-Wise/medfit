# twolevel_statistic() for TwoLevelParallelMediationData (IG5 T4, SPEC-IG5 D4)
#
# Oracles: nie()/nde()/te() on the same object (the statistic must equal them exactly at the estimate for the
# parametric route, and at 1e-6 for a refit on the fit's own data), and a hand sum of a_j * b_j from the
# object's path vectors (independent of the shared effect kernel). The planted defect (the total NIE key mapped
# to the first mediator's specific key) is asserted with expect_false() on a boolean check.

val <- function(e) as.numeric(unclass(e))

# The hand value of one effect from the object's path vectors (no package effect code).
tlp_hand_effect <- function(td, effect, level, specific = NULL) {
  at <- function(lev) {
    a <- S7::prop(td, paste0("a_", lev))
    b <- S7::prop(td, paste0("b_", lev))
    cp <- S7::prop(td, paste0("c_prime_", lev))
    switch(effect,
      nie = sum(a * b),
      nie_j = unname(a[[specific]] * b[[specific]]),
      nde = cp,
      te = sum(a * b) + cp
    )
  }
  if (identical(level, "contrast")) at("within") - at("between") else at(level)
}

# The package value of one effect from the effect generics.
tlp_generic_effect <- function(td, effect, level, specific = NULL) {
  switch(effect,
    nie = val(nie(td, level = level)),
    nie_j = val(nie(td, level = level, type = "specific")[[specific]]),
    nde = val(nde(td, level = level)),
    te = val(te(td, level = level))
  )
}

# Every (effect, level, specific) cell D4 defines for an object.
tlp_cells <- function(td) {
  cells <- list()
  for (level in c("within", "between", "contrast")) {
    cells[[length(cells) + 1L]] <- list(effect = "nie", level = level, specific = NULL)
    for (m in td@mediators) cells[[length(cells) + 1L]] <- list(effect = "nie_j", level = level, specific = m)
    if (!identical(level, "contrast")) {
      for (eff in c("nde", "te")) cells[[length(cells) + 1L]] <- list(effect = eff, level = level, specific = NULL)
    }
  }
  cells
}

# TRUE when the parametric callback equals nie()/nde()/te() exactly and the hand value at 1e-12, in every cell.
tlp_param_stat_ok <- function(td) {
  all(vapply(tlp_cells(td), function(cl) {
    stat <- twolevel_statistic(td, cl$effect, level = cl$level, specific = cl$specific)
    got <- stat(td@estimates)
    identical(got, tlp_generic_effect(td, cl$effect, cl$level, cl$specific)) &&
      isTRUE(all.equal(got, tlp_hand_effect(td, cl$effect, cl$level, cl$specific), tolerance = 1e-12))
  }, logical(1)))
}

# A three-mediator two-level fit (M1, M2, M3 each on X, Y on all three and X, at both levels): no serial row.
tlp_fixture_k3 <- function() {
  tl_cached("tlp_fit_k3", tl_fit(tlp_sim_w(), paste0(
    "level: 1\n  M1 ~ X\n  M2 ~ X\n  M3 ~ X\n  Y ~ M1 + M2 + M3 + X\n",
    "level: 2\n  M1 ~ X\n  M2 ~ X\n  M3 ~ X\n  Y ~ M1 + M2 + M3 + X\n"
  )))
}

# TRUE when the refit callback on the fit's own data equals the object's effects (1e-6) in every cell.
tlp_refit_stat_ok <- function(fit, d, meds) {
  td <- tlp_extract(fit, mediator = meds)
  all(vapply(tlp_cells(td), function(cl) {
    stat <- twolevel_statistic(fit, cl$effect, treatment = "X", mediator = meds, outcome = "Y", level = cl$level,
                               specific = cl$specific)
    isTRUE(all.equal(stat(d), tlp_generic_effect(td, cl$effect, cl$level, cl$specific), tolerance = 1e-6))
  }, logical(1)))
}

# --- Parametric route (no lavaan needed) ---

test_that("the parametric callback equals nie(), nde() and te() at the estimate, k = 2 and k = 3", {
  for (k in 2:3) {
    td <- tlp_td(k = k)
    # the specific and the total differ, so a defect that returns one for the other is visible
    expect_false(isTRUE(all.equal(val(nie(td)), val(nie(td, type = "specific"))[[1]])))
    expect_true(tlp_param_stat_ok(td), info = paste("k =", k))
  }
  # the default is the total within NIE
  td <- tlp_td(k = 3)
  expect_identical(twolevel_statistic(td)(td@estimates), val(nie(td)))
  # a callback only needs the rows it reads
  rows <- c("a_M2_within", "b_M2_within")
  expect_identical(twolevel_statistic(td, "nie_j", specific = "M2")(td@estimates[rows]),
                   val(nie(td, type = "specific")[["M2"]]))
})

test_that("the parametric callback equals the effects of a lavaan-extracted object", {
  skip_if_not_installed("lavaan")
  expect_true(tlp_param_stat_ok(tlp_extract(tlp_fixture("base"))))
  expect_true(tlp_param_stat_ok(tlp_extract(tlp_fixture_k3(), mediator = c("M1", "M2", "M3"))))
})

test_that("bootstrap_mediation() runs the parametric and plugin routes on the fixture", {
  skip_if_not_installed("lavaan")
  skip_if_not_installed("MASS")
  td <- tlp_extract(tlp_fixture("base"))
  res <- bootstrap_mediation(twolevel_statistic(td, "nie", level = "between"), method = "parametric",
                             mediation_data = td, n_boot = 200, seed = 1)
  expect_s7_class(res, BootstrapResult)
  expect_identical(res@n_boot, 200L)
  expect_identical(res@estimate, val(nie(td, level = "between")))
  expect_true(all(is.finite(c(res@ci_lower, res@ci_upper))))
  expect_lt(res@ci_lower, res@estimate)
  expect_gt(res@ci_upper, res@estimate)

  res_j <- bootstrap_mediation(twolevel_statistic(td, "nie_j", level = "contrast", specific = "M2"),
                               method = "parametric", mediation_data = td, n_boot = 50, seed = 1)
  expect_identical(res_j@estimate, val(nie(td, level = "contrast", type = "specific")[["M2"]]))
  expect_length(res_j@boot_estimates, 50L)

  plug <- bootstrap_mediation(twolevel_statistic(td, "te"), method = "plugin", mediation_data = td)
  expect_identical(plug@estimate, val(te(td)))
  expect_identical(plug@n_boot, 0L)
})

# --- Cluster refit route ---

test_that("the refit callback on the fit's own data equals the object's effects, k = 2 and k = 3", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  expect_true(tlp_refit_stat_ok(tlp_fixture("base"), tlp_sim(), c("M1", "M2")))
  expect_true(tlp_refit_stat_ok(tlp_fixture_k3(), tlp_sim_w(), c("M1", "M2", "M3")))
})

test_that("bootstrap_mediation() runs the cluster refit on the fixture", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  fit <- tlp_fixture("base")
  td <- tlp_extract(fit)
  stat <- twolevel_statistic(fit, "nie", treatment = "X", mediator = c("M1", "M2"), outcome = "Y",
                             level = "between")
  res <- suppressWarnings(bootstrap_mediation(stat, method = "nonparametric", data = tlp_sim(), cluster = "id",
                                              n_boot = 12L, seed = 3L))
  expect_s7_class(res, BootstrapResult)
  expect_identical(res@method, "nonparametric")
  expect_gte(res@n_boot, 10L)
  expect_equal(res@estimate, val(nie(td, level = "between")), tolerance = 1e-6)
  expect_true(all(is.finite(res@boot_estimates)))
  expect_true(all(is.finite(c(res@ci_lower, res@ci_upper))))
})

test_that("the refit callback refits on the resampled clusters: it equals a fresh lavaan refit's := values", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  # Oracle: lavaan's own defined parameters from a fresh fit of the same model on the resampled data, with the
  # refit's three overrides only; the object's effect code is not used.
  defs <- paste0(
    "  ind1w := a1*b1\n  ind2w := a2*b2\n  niew := ind1w + ind2w\n  tew := niew + cp\n",
    "  ind1b := a1B*b1B\n  ind2b := a2B*b2B\n  nieb := ind1b + ind2b\n  teb := nieb + cpB\n",
    "  niec := niew - nieb\n  ind2c := ind2w - ind2b\n"
  )
  d <- tlp_sim()
  set.seed(42)
  ids <- sample(unique(d$id), replace = TRUE)
  db <- do.call(rbind, lapply(seq_along(ids), function(i) {
    z <- d[d$id == ids[[i]], ]
    z$id <- i
    z
  }))
  fresh <- lavaan::sem(paste0(tlp_model(), defs), data = db, cluster = "id", se = "none", test = "none",
                       check.post = FALSE)
  pe <- lavaan::parameterEstimates(fresh, se = FALSE)
  oracle <- stats::setNames(pe$est, pe$lhs)[pe$op == ":="]
  fit <- tlp_fixture("base")
  td <- tlp_extract(fit)
  cells <- list(
    list("nie", "within", NULL, "niew"), list("nie", "between", NULL, "nieb"), list("nie", "contrast", NULL, "niec"),
    list("nie_j", "within", "M1", "ind1w"), list("nie_j", "between", "M2", "ind2b"),
    list("nie_j", "contrast", "M2", "ind2c"), list("nde", "between", NULL, "cpB"), list("te", "within", NULL, "tew"),
    list("te", "between", NULL, "teb")
  )
  oracle[["cpB"]] <- pe$est[pe$label == "cpB" & pe$op == "~"]
  for (cl in cells) {
    stat <- twolevel_statistic(fit, cl[[1]], treatment = "X", mediator = c("M1", "M2"), outcome = "Y",
                               level = cl[[2]], specific = cl[[3]])
    got <- stat(db)
    expect_equal(got, oracle[[cl[[4]]]], tolerance = 1e-6, info = cl[[4]])
    # a resample is a different data set: the value moves away from the estimate on the fit's own data
    expect_gt(abs(got - stat(d)), 1e-4)
  }
})

test_that("a refit whose mediator loses its between level is a failed replicate (D2 over every mediator)", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  fit <- tlp_fixture("base")
  stat <- twolevel_statistic(fit, "nie", treatment = "X", mediator = c("M1", "M2"), outcome = "Y",
                             level = "between")
  # M2 without a between part: its h1 ICC (.0025 on this data) is below the floor, so the between total is not returned
  expect_true(is.na(suppressWarnings(stat(tlp_sim(m2_between = FALSE, seed = 76L)))))
  within <- twolevel_statistic(fit, "nie", treatment = "X", mediator = c("M1", "M2"), outcome = "Y")
  expect_true(is.finite(suppressWarnings(within(tlp_sim(m2_between = FALSE, seed = 76L)))))
})

# --- Errors ---

test_that("undefined effects, levels and mediators are classed errors", {
  td <- tlp_td()
  expect_error(twolevel_statistic(td, "nie_j", specific = "M9"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(td, "nie_j"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(td, "nie", specific = "M1"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(td, "nie_within"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(td, "pm"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(td, "nde", level = "contrast"), class = "medfit_error_twolevel_level")
  expect_error(twolevel_statistic(td, "te", level = "contrast"), class = "medfit_error_twolevel_level")
  for (lev in list("both", "Within", c("within", "between"), NA_character_, 1)) {
    expect_error(twolevel_statistic(td, "nie", level = lev), class = "medfit_error_twolevel_level")
  }
  expect_error(twolevel_statistic(td, "nie", treatment = "X"), class = "medfit_error_twolevel_unsupported")

  # the one-mediator object keeps its own vocabulary and refuses the parallel arguments
  expect_error(twolevel_statistic(tl_td(), "nie_within", level = "within"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(tl_td(), "nie_within", specific = "M"), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(tl_td(), "nie"))
})

test_that("a between effect of a within-only object and a constrained contrast are classed errors", {
  within_only <- tlp_td(within_only = TRUE)
  for (eff in c("nie", "nde", "te")) {
    expect_error(twolevel_statistic(within_only, eff, level = "between"), class = "medfit_between_unidentified")
  }
  expect_error(twolevel_statistic(within_only, "nie", level = "contrast"), class = "medfit_between_unidentified")
  expect_error(twolevel_statistic(within_only, "nie_j", level = "contrast", specific = "M1"),
               class = "medfit_between_unidentified")
  stat <- twolevel_statistic(within_only, "nie")
  expect_identical(stat(within_only@estimates), val(nie(within_only)))

  # D5: M1's a and b equated -> its specific contrast is constrained; M2's and the total contrast are not
  constrained <- tlp_td(cross_level_equal = c("a_M1", "b_M1"))
  expect_error(twolevel_statistic(constrained, "nie_j", level = "contrast", specific = "M1"),
               class = "medfit_error_twolevel_constrained")
  expect_type(twolevel_statistic(constrained, "nie_j", level = "contrast", specific = "M2"), "closure")
  expect_identical(twolevel_statistic(constrained, "nie", level = "contrast")(constrained@estimates),
                   val(nie(constrained, level = "contrast")))
  # every mediator equated -> the total contrast is constrained too
  all_eq <- tlp_td(cross_level_equal = c("a_M1", "b_M1", "a_M2", "b_M2"))
  expect_error(twolevel_statistic(all_eq, "nie", level = "contrast"), class = "medfit_error_twolevel_constrained")
})

test_that("a lavaan fit with several mediators needs the roles and follows the same rules", {
  skip_if_not_installed("lavaan")
  fit <- tlp_fixture("base")
  expect_error(twolevel_statistic(fit, "nie", mediator = c("M1", "M2")), class = "medfit_error_twolevel_unsupported")
  expect_error(twolevel_statistic(fit, "nie_j", treatment = "X", mediator = c("M1", "M2"), outcome = "Y",
                                  specific = "M3"),
               class = "medfit_error_twolevel_unsupported")
  shared <- tlp_fixture("shared_ab1")
  expect_error(twolevel_statistic(shared, "nie_j", treatment = "X", mediator = c("M1", "M2"), outcome = "Y",
                                  level = "contrast", specific = "M1"),
               class = "medfit_error_twolevel_constrained")
  low <- tlp_fixture("low_icc_m2")
  expect_error(twolevel_statistic(low, "nie", treatment = "X", mediator = c("M1", "M2"), outcome = "Y",
                                  level = "between"),
               class = "medfit_between_unidentified")
})

# --- Planted defect ---

test_that("planted defect: the total NIE mapped to the first specific effect is caught", {
  skip_if_not_installed("lavaan")
  td <- tlp_td(k = 3)
  fit <- tlp_fixture("base")
  testthat::local_mocked_bindings(
    .twolevel_stat_parallel_key = function(td, effect, level, specific) {
      if (identical(effect, "nie")) return(paste0("nie_", td@mediators[[1L]], "_", level))
      if (identical(effect, "nie_j")) paste0("nie_", specific, "_", level) else paste0(effect, "_", level)
    },
    .package = "medfit"
  )
  expect_false(tlp_param_stat_ok(td))
  skip_on_cran()
  expect_false(tlp_refit_stat_ok(fit, tlp_sim(), c("M1", "M2")))
})
