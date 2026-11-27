# IG5 T3: effects, delta-method SEs, tidy/confint/summary for TwoLevelParallelMediationData.
# Oracle: lavaan `:=` defined parameters on the same fit (helper-twolevel-effects.R, tlp_defined_fit()).

skip_on_cran() # Windows check time (0.21.3): runs in CI and the local full run

skip_if_not_installed("lavaan")

# --- O1: lavaan `:=` oracle, per level and for the contrasts ---

test_that("specific, total, NDE, TE, PM and contrasts match lavaan := (estimates and SEs, 1e-6)", {
  for (name in c("base", "shared_a1")) {
    fit <- tlp_defined_fit(name)
    td <- tlp_extract(fit)
    d <- tlp_defined_diff(td, fit, name)
    expect_lt(d[["estimate"]], 1e-6, label = paste(name, "estimate"))
    expect_lt(d[["std_error"]], 1e-6, label = paste(name, "std_error"))
  }
})

test_that("with a_M1 and b_M1 both equated, M1's contrast is NA and the rest match lavaan :=", {
  fit <- tlp_defined_fit("shared_ab1")
  td <- tlp_extract(fit)
  expect_setequal(td@cross_level_equal, c("a_M1", "b_M1"))
  d <- tlp_defined_diff(td, fit, "shared_ab1")
  expect_lt(d[["estimate"]], 1e-6)
  expect_lt(d[["std_error"]], 1e-6)
  w <- tl_catch(tidy(td, type = "effects"), "medfit_warning_twolevel_constrained")
  expect_s3_class(w, "medfit_warning_twolevel_constrained")
  ti <- suppressWarnings(tidy(td, type = "effects"))
  expect_true(is.na(ti$estimate[ti$term == "nie_M1_contrast"]))
  expect_true(is.na(ti$std_error[ti$term == "nie_M1_contrast"]))
  expect_true(is.finite(ti$estimate[ti$term == "nie_contrast"]))
})

test_that("only a_M1 equated: every contrast is estimable and no constrained warning", {
  td <- tlp_extract(tlp_fixture("shared_a1"))
  expect_identical(td@cross_level_equal, "a_M1")
  expect_no_warning(ti <- tidy(td, type = "effects"))
  expect_true(all(is.finite(ti$estimate)))
  expect_true(all(is.finite(ti$std_error)))
})

# --- O2: planted defect, the cross-mediator covariance block ---

test_that("zeroing the cross-mediator block of @vcov is caught by the := oracle", {
  fit <- tlp_defined_fit("base")
  td <- tlp_extract(fit)
  expect_true(tlp_defined_ok(td, fit))
  bad <- tlp_zero_cross_mediator(td)
  expect_false(tlp_defined_ok(bad, fit))
  # the total SE moves; each specific SE (one mediator's rows only) does not
  ref <- lavaan::parameterEstimates(fit)
  se <- function(x, term) tidy(x, type = "effects")$std_error[tidy(x, type = "effects")$term == term]
  expect_gt(abs(se(bad, "nie_within") - ref$se[which(ref$label == "niew")]), 1e-6)
  expect_lt(abs(se(bad, "nie_M1_within") - ref$se[which(ref$label == "s1w")]), 1e-6)
  expect_lt(abs(se(bad, "nie_M2_within") - ref$se[which(ref$label == "s2w")]), 1e-6)
})

# --- O3: API shape ---

test_that("nie() gives the total by default and a named specific vector with type = 'specific'", {
  td <- tlp_extract(tlp_fixture("base"))
  a <- td@a_within
  b <- td@b_within
  expect_s3_class(nie(td), "mediation_effect")
  expect_equal(as.numeric(nie(td)), sum(a * b))
  expect_identical(attr(nie(td), "level"), "within")
  sp <- nie(td, type = "specific")
  expect_named(sp, c("M1", "M2"))
  expect_equal(as.numeric(sp), unname(a * b))
  expect_equal(as.numeric(nie(td, level = "between")), sum(td@a_between * td@b_between))
  expect_named(nie(td, level = "both"), c("within", "between"))
  expect_named(nie(td, level = "both", type = "specific"),
               c("M1_within", "M2_within", "M1_between", "M2_between"))
  # contrast: within minus between, as in the one-mediator class
  expect_equal(as.numeric(nie(td, level = "contrast")),
               sum(a * b) - sum(td@a_between * td@b_between))
  expect_equal(as.numeric(nie(td, level = "contrast", type = "specific")),
               unname(a * b - td@a_between * td@b_between))
  expect_error(nie(td, type = "chain"))
})

test_that("nde(), te(), pm() follow the one-mediator conventions", {
  td <- tlp_extract(tlp_fixture("base"))
  nie_w <- sum(td@a_within * td@b_within)
  expect_equal(as.numeric(nde(td)), td@c_prime_within)
  expect_equal(as.numeric(te(td)), nie_w + td@c_prime_within)
  expect_equal(as.numeric(pm(td)), nie_w / (nie_w + td@c_prime_within))
  expect_named(te(td, level = "both"), c("within", "between"))
  for (f in list(nde, te, pm)) {
    expect_s3_class(tl_catch(f(td, level = "contrast"), "medfit_error_twolevel_level"),
                    "medfit_error_twolevel_level")
  }
})

test_that("paths() and decompose() have the documented shape", {
  td <- tlp_extract(tlp_fixture("base"))
  expect_named(paths(td), c(names(.twolevel_parallel_paths(td, "within")),
                            names(.twolevel_parallel_paths(td, "between"))))
  dec <- decompose(td)
  expect_identical(dimnames(dec), list(c("M1", "M2", "total"), c("within", "between", "contrast")))
  expect_equal(dec["total", "within"], as.numeric(nie(td)))
  expect_equal(dec["M2", "contrast"], as.numeric(nie(td, level = "contrast", type = "specific"))[2])
  expect_match(attr(dec, "label"), "not a test")
})

test_that("tidy() term order, glance(), coef(), vcov(), nobs()", {
  td <- tlp_extract(tlp_fixture("base"))
  keys <- c("nie_M1_within", "nie_M2_within", "nie_within", "nde_within", "te_within", "pm_within",
            "nie_M1_between", "nie_M2_between", "nie_between", "nde_between", "te_between", "pm_between",
            "nie_M1_contrast", "nie_M2_contrast", "nie_contrast")
  ti <- tidy(td)
  expect_identical(ti$term, c(names(paths(td)), keys))
  expect_identical(tidy(td, type = "paths")$term, names(paths(td)))
  expect_named(tidy(td, conf_int = TRUE), c("term", "estimate", "std_error", "conf_low", "conf_high"))
  g <- glance(td)
  expect_named(g, c("nie_within", "nie_between", "nie_contrast", "n_mediators", "n_clusters", "nobs",
                    "converged", "between_identified", "admissible"))
  expect_equal(g$nie_within, as.numeric(nie(td)))
  expect_identical(g$n_mediators, 2L)
  expect_identical(names(coef(td, type = "effects")), keys)
  expect_identical(coef(td), paths(td))
  expect_identical(coef(td, type = "all"), td@estimates)
  expect_identical(vcov(td), td@vcov)
  expect_identical(nobs(td), td@n_obs)
})

test_that("confint() agrees with the tidy() intervals", {
  td <- tlp_extract(tlp_fixture("base"))
  ti <- tidy(td, conf_int = TRUE, conf_level = 0.9)
  ci <- confint(td, parm = "effects", level = 0.9)
  i <- match(rownames(ci), ti$term)
  expect_equal(unname(ci[, 1]), ti$conf_low[i], tolerance = 1e-12)
  expect_equal(unname(ci[, 2]), ti$conf_high[i], tolerance = 1e-12)
  expect_identical(colnames(ci), c("5 %", "95 %"))
  cp <- confint(td, level = 0.9)
  expect_identical(rownames(cp), names(paths(td)))
  expect_equal(unname(cp[, 1]), ti$conf_low[match(rownames(cp), ti$term)], tolerance = 1e-12)
  expect_identical(rownames(confint(td, parm = c("nie_M2_between", "a_M1_within"))),
                   c("nie_M2_between", "a_M1_within"))
  expect_error(confint(td, parm = "nie_M3_within"))
})

test_that("summary() and print() show every specific effect per level", {
  td <- tlp_extract(tlp_fixture("base"))
  s <- summary(td)
  expect_s3_class(s, "summary_TwoLevelParallelMediationData")
  expect_identical(rownames(s$effects), names(coef(td, type = "effects")))
  out <- capture.output(print(s))
  expect_true(any(grepl("Summary of TwoLevelParallelMediationData", out, fixed = TRUE)))
  expect_true(any(grepl("nie_M2_between", out, fixed = TRUE)))
  expect_true(any(grepl("Cov(a_j, a_j')", out, fixed = TRUE)))
  expect_identical(capture.output(td), capture.output(print(td)))
})

# --- O4: D5 with every path of both mediators equated (hand object) ---

test_that("all a and b equated: every contrast is NA with the constrained warning", {
  td <- tlp_td(cross_level_equal = c("a_M1", "b_M1", "a_M2", "b_M2"))
  w <- tl_catch(nie(td, level = "contrast"), "medfit_warning_twolevel_constrained")
  expect_s3_class(w, "medfit_warning_twolevel_constrained")
  eff <- suppressWarnings(coef(td, type = "effects"))
  expect_true(all(is.na(eff[c("nie_M1_contrast", "nie_M2_contrast", "nie_contrast")])))
  expect_true(all(is.finite(eff[c("nie_within", "nie_between")])))
  # one mediator equated: its contrast NA, the other's and the total estimable
  td1 <- tlp_td(cross_level_equal = c("a_M2", "b_M2"))
  eff1 <- suppressWarnings(coef(td1, type = "effects"))
  expect_true(is.na(eff1[["nie_M2_contrast"]]))
  expect_equal(eff1[["nie_contrast"]], eff1[["nie_within"]] - eff1[["nie_between"]])
  ti1 <- suppressWarnings(tidy(td1))
  expect_true(is.finite(ti1$std_error[ti1$term == "nie_contrast"]))
})

test_that("the hand gradient matches the package SE on a diagonal vcov", {
  td <- tlp_td()
  ti <- tidy(td, type = "effects")
  g <- c(a_M1_within = td@b_within[["M1"]], b_M1_within = td@a_within[["M1"]],
         a_M2_within = td@b_within[["M2"]], b_M2_within = td@a_within[["M2"]],
         a_M1_between = -td@b_between[["M1"]], b_M1_between = -td@a_between[["M1"]],
         a_M2_between = -td@b_between[["M2"]], b_M2_between = -td@a_between[["M2"]])
  expect_equal(ti$std_error[ti$term == "nie_contrast"], sqrt(sum(g^2 * diag(td@vcov)[names(g)])),
               tolerance = 1e-12)
})

# --- O5: within-only (D2) ---

test_that("within-only fit: between effects and contrasts NA with medfit_between_unidentified", {
  td <- tlp_extract(tlp_fixture("low_icc_m2"))
  expect_false(td@between_identified)
  w <- tl_catch(nie(td, level = "between"), "medfit_between_unidentified")
  expect_s3_class(w, "medfit_between_unidentified")
  expect_no_warning(nie(td))
  ti <- suppressWarnings(tidy(td, type = "effects"))
  between <- grepl("between|contrast", ti$term)
  expect_true(all(is.na(ti$estimate[between])))
  expect_true(all(is.na(ti$std_error[between])))
  expect_true(all(is.finite(ti$std_error[!between])))
  expect_true(is.na(suppressWarnings(decompose(td))["total", "between"]))
  expect_s3_class(suppressWarnings(summary(td)), "summary_TwoLevelParallelMediationData")
})

# --- O6: metamorphic, mediator order ---

test_that("permuting the mediators leaves totals unchanged and permutes the specific effects", {
  fit <- tlp_fixture("base")
  td <- tlp_extract(fit)
  tp <- tlp_extract(fit, mediator = c("M2", "M1"))
  e <- coef(td, type = "effects")
  ep <- coef(tp, type = "effects")
  tot <- c("nie_within", "te_within", "pm_within", "nie_between", "nie_contrast")
  expect_equal(ep[tot], e[tot], tolerance = 1e-12)
  expect_equal(ep[["nie_M1_between"]], e[["nie_M1_between"]], tolerance = 1e-12)
  se <- function(x) stats::setNames(tidy(x, type = "effects")$std_error, tidy(x, type = "effects")$term)
  expect_equal(se(tp)[names(se(td))], se(td), tolerance = 1e-10)
})

# --- O7: k = 1 neutrality ---

# The snapshot was written on one platform; lavaan estimates differ across BLAS and
# compilers in the last bits (about 1e-15), and covr's instrumented build moves the
# numerically zero cross-level covariances by about 1e-12, so the comparison allows 1e-8. Printed
# output (summ, prt) is still compared exactly, since expect_equal() compares strings exactly.
test_that("k = 1 TwoLevelMediationData results match the pre-T3 snapshot", {
  snap <- readRDS(test_path("fixtures", "twolevel-k1-snapshot.rds"))
  now <- function(name) {
    suppressWarnings({
      td <- tl_extract(tl_fixture(name))
      list(
        tidy_all = as.data.frame(tidy(td, type = "all", conf.int = TRUE)),
        glance = as.data.frame(glance(td)),
        confint = confint(td),
        confint_e = confint(td, parm = "effects"),
        coef_all = coef(td, type = "all"),
        vcov = vcov(td),
        nobs = nobs(td),
        eff = lapply(c("within", "between", "both"), function(l) {
          unclass(c(nie(td, level = l), nde(td, level = l), te(td, level = l), pm(td, level = l)))
        }),
        contr = unclass(nie(td, level = "contrast")),
        paths = paths(td),
        dec = decompose(td),
        summ = utils::capture.output(print(summary(td))),
        prt = utils::capture.output(print(td))
      )
    })
  }
  for (name in names(snap)) {
    expect_equal(now(name), snap[[name]], tolerance = 1e-8, label = name)
  }
})

test_that("summary() of a within-only object warns as k = 1 does (QA loop 1)", {
  warn_classes <- function(expr) {
    cls <- character()
    withCallingHandlers(expr, warning = function(w) {
      cls <<- c(cls, class(w)[1])
      invokeRestart("muffleWarning")
    })
    cls
  }
  k1 <- warn_classes(summary(tl_td(within_only = TRUE)))
  td <- suppressWarnings(tlp_extract(tlp_fixture("low_icc_m2")))
  expect_false(td@between_identified)
  k2 <- warn_classes(summary(td))
  expect_identical(k2, k1)
  # the NA rows are still there: between and contrast effects are NA
  s <- summary(td)
  expect_true(all(is.na(s$effects[c("nie_between", "nie_contrast"), "estimate"])))
})
