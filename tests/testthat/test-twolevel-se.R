# Inference for TwoLevelMediationData: gradients, tidy, confint, glance, summary, O3, planted defects
# (#394, S2 PR2)

val <- function(e) as.numeric(unclass(e))

test_that("effect SEs equal the hand delta method on the joint vcov (cross-level block carried)", {
  td <- tl_td_cov()
  aw <- 0.4
  bw <- 0.5
  cw <- 0.3
  ab <- 0.7
  bb <- 1.5
  tw <- aw * bw + cw
  tb <- ab * bb - 0.1
  se <- .effect_se(td, c("nie_within", "nie_between", "nie_contrast", "nde_within", "nde_between",
                         "te_within", "te_between", "pm_within", "pm_between"))
  expect_equal(unname(se["nie_within"]), tl_hand_se(td, c(a_within = bw, b_within = aw)), tolerance = 1e-12)
  expect_equal(unname(se["nie_between"]), tl_hand_se(td, c(a_between = bb, b_between = ab)), tolerance = 1e-12)
  expect_equal(unname(se["nie_contrast"]),
               tl_hand_se(td, c(a_within = bw, b_within = aw, a_between = -bb, b_between = -ab)),
               tolerance = 1e-12)
  expect_equal(unname(se["nde_within"]), 0.09, tolerance = 1e-12)
  expect_equal(unname(se["nde_between"]), 0.22, tolerance = 1e-12)
  expect_equal(unname(se["te_within"]),
               tl_hand_se(td, c(a_within = bw, b_within = aw, c_prime_within = 1)), tolerance = 1e-12)
  # pm = nie / te: the quotient rule
  g_pm_w <- c(a_within = bw / tw - aw * bw * bw / tw^2, b_within = aw / tw - aw * bw * aw / tw^2,
              c_prime_within = -aw * bw / tw^2)
  expect_equal(unname(se["pm_within"]), tl_hand_se(td, g_pm_w), tolerance = 1e-12)
  g_pm_b <- c(a_between = bb / tb - ab * bb * bb / tb^2, b_between = ab / tb - ab * bb * ab / tb^2,
              c_prime_between = -ab * bb / tb^2)
  expect_equal(unname(se["pm_between"]), tl_hand_se(td, g_pm_b), tolerance = 1e-12)
})

test_that("the contrast SE differs from the one with the cross-level block zeroed", {
  td <- tl_td_cov()
  full <- .effect_se(td, "nie_contrast")
  blk <- td@vcov
  blk[1:3, 4:6] <- 0
  blk[4:6, 1:3] <- 0
  td0 <- tl_td_cov(vcov = blk)
  expect_false(isTRUE(all.equal(unname(full), unname(.effect_se(td0, "nie_contrast")), tolerance = 1e-6)))
})

test_that("tidy() has paths then effects, with NA between rows for a within-only object", {
  td <- tl_td_cov()
  t_all <- tidy(td)
  expect_identical(names(t_all), c("term", "estimate", "std_error"))
  expect_identical(t_all$term, c(
    "a_within", "b_within", "c_prime_within", "a_between", "b_between", "c_prime_between",
    "nie_within", "nde_within", "te_within", "pm_within",
    "nie_between", "nde_between", "te_between", "pm_between", "nie_contrast"
  ))
  expect_equal(t_all$std_error[1:6], unname(sqrt(diag(td@vcov))), tolerance = 1e-12)
  expect_identical(tidy(td, type = "paths")$term, t_all$term[1:6])
  expect_identical(tidy(td, type = "effects")$term, t_all$term[7:15])

  w <- tl_td(within_only = TRUE)
  expect_warning(tw <- tidy(w), class = "medfit_between_unidentified")
  expect_equal(nrow(tw), 15L)
  between <- grepl("between|contrast", tw$term)
  expect_true(all(is.na(tw$estimate[between])))
  expect_true(all(is.na(tw$std_error[between])))
  expect_true(all(is.finite(tw$std_error[!between])))
  expect_no_warning(tidy(w, type = "paths"))
})

test_that("tidy() and confint() agree, and the contrast is NA with a warning when constrained", {
  td <- tl_td_cov()
  ti <- tidy(td, type = "effects", conf_int = TRUE)
  ci <- confint(td, parm = "effects")
  expect_equal(unname(as.matrix(ti[c("conf_low", "conf_high")])), unname(ci), tolerance = 1e-12)
  expect_identical(rownames(ci), ti$term)
  tp <- tidy(td, type = "paths", conf_int = TRUE, conf_level = 0.9)
  cp <- confint(td, parm = "paths", level = 0.9)
  expect_equal(unname(as.matrix(tp[c("conf_low", "conf_high")])), unname(cp), tolerance = 1e-12)
  expect_equal(unname(cp[1, ]), 0.4 + c(-1, 1) * stats::qnorm(0.95) * 0.10, tolerance = 1e-12)

  tc <- tl_td_cov(cross_level_equal = c("a", "b"))
  expect_warning(t_c <- tidy(tc, type = "effects"), class = "medfit_warning_twolevel_constrained")
  expect_true(is.na(t_c$estimate[t_c$term == "nie_contrast"]))
  expect_true(is.na(t_c$std_error[t_c$term == "nie_contrast"]))
  expect_false(is.na(t_c$std_error[t_c$term == "nie_between"]))
  expect_warning(cc <- confint(tc, parm = "effects"), class = "medfit_warning_twolevel_constrained")
  expect_true(all(is.na(cc["nie_contrast", ])))
})

test_that("coef, vcov and nobs", {
  td <- tl_td_cov()
  expect_identical(coef(td), paths(td))
  expect_identical(coef(td, type = "all"), td@estimates)
  expect_equal(unname(coef(td, type = "effects")["nie_between"]), 0.7 * 1.5)
  expect_identical(vcov(td), td@vcov)
  expect_identical(nobs(td), 500L)
})

test_that("glance() is one row with the headline effects and the flags", {
  g <- glance(tl_td_cov())
  expect_equal(nrow(g), 1L)
  expect_identical(names(g), c("nie_within", "nie_between", "nie_contrast", "n_clusters", "nobs",
                               "converged", "between_identified", "admissible"))
  expect_equal(g$nie_contrast, 0.2 - 1.05)
  expect_no_warning(gw <- glance(tl_td(within_only = TRUE)))
  expect_true(is.na(gw$nie_between))
  expect_true(is.na(gw$nie_contrast))
  expect_false(gw$between_identified)
})

test_that("summary() reports effects with SEs, provenance, assumptions and flags", {
  td <- tl_td_cov(cross_level_equal = "c_prime", fixed_paths = "c_prime_within")
  s <- summary(td)
  txt <- paste(utils::capture.output(print(s)), collapse = "\n")
  expect_match(txt, "TwoLevelMediationData")
  expect_match(txt, "fixed_x")
  expect_match(txt, "information")
  expect_match(txt, "lavaan 0.7.3")
  expect_match(txt, "latent cluster means")
  expect_match(txt, "descriptive, not a test")
  expect_match(txt, "equated across levels: c_prime")
  expect_match(txt, "fixed: c_prime_within")
  expect_match(txt, "NIE")
  # the standard errors are printed, and the fixed.x SE gap is stated without a hard-coded number
  expect_false(grepl("3-4%|3 to 4|narrower", txt))
  expect_match(txt, "conditional on the sample")
  expect_equal(s$effects["nie_within", "std_error"], unname(.effect_se(td, "nie_within")), tolerance = 1e-12)
  expect_no_warning(summary(tl_td(within_only = TRUE)))
})

test_that("effects of a lavaan fit match lavaan's := estimates, SEs and the contrast SE (O3)", {
  skip_if_not_installed("lavaan")
  fit <- tl_defined_fit()
  td <- tl_extract(fit)
  pe <- lavaan::parameterEstimates(fit)
  ti <- tidy(td, type = "effects")
  chk <- function(term, name, tol = 1e-8) {
    row <- pe[pe$op == ":=" & pe$label == name, ]
    r <- ti[ti$term == term, ]
    c(est = abs(r$estimate - row$est) / max(abs(row$est), 1e-12),
      se = abs(r$std_error - row$se) / row$se) < tol
  }
  for (nm in names(tl_defined_labels)) expect_true(all(chk(nm, tl_defined_labels[[nm]])), info = nm)

  # the hand delta with V re-read by free index, not through the adapter's sub-block helper
  V <- lavaan::vcov(fit)
  pt <- lavaan::parTable(fit)
  idx <- vapply(c("a", "b", "cp", "a2", "b2", "cp2"), function(l) pt$free[match(l, pt$label)], integer(1))
  Vs <- as.matrix(V)[idx, idx]
  est <- unname(lavaan::coef(fit)[idx])
  g <- c(est[2], est[1], 0, -est[5], -est[4], 0)
  expect_equal(ti$std_error[ti$term == "nie_contrast"], sqrt(drop(g %*% Vs %*% g)), tolerance = 1e-8)
  # the cross-level covariance is carried
  expect_equal(td@vcov["a_within", "a_between"], Vs[1, 4], tolerance = 1e-12)
  expect_true(abs(Vs[1, 4]) > 0)
})

# --- Planted defects: each must make the oracle comparison fail ---

# (tl_o3_se_ok() and tl_defined_fit() are in helper-twolevel-effects.R)

test_that("planted defect: the real builder passes the SE oracle (positive control)", {
  skip_if_not_installed("lavaan")
  fit <- tl_defined_fit()
  expect_true(tl_o3_se_ok(tl_extract(fit), fit))
})

test_that("planted defect: levels swapped in the gradients is caught", {
  skip_if_not_installed("lavaan")
  fit <- tl_defined_fit()
  td <- tl_extract(fit)
  real <- medfit:::.effect_gradients_twolevel
  swap <- function(g) {
    nm <- names(g)
    nm <- ifelse(grepl("_within$", nm), sub("_within$", "_between", nm), sub("_between$", "_within", nm))
    stats::setNames(g, nm)
  }
  testthat::local_mocked_bindings(
    .effect_gradients_twolevel = function(x) {
      g <- real(x)
      g$nie_within <- swap(g$nie_within)
      g
    },
    .package = "medfit"
  )
  expect_false(tl_o3_se_ok(td, fit))
})

test_that("planted defect: the contrast SE with the cross-level covariance ignored is caught", {
  skip_if_not_installed("lavaan")
  fit <- tl_defined_fit()
  td <- tl_extract(fit)
  real <- medfit:::.gradient_var
  testthat::local_mocked_bindings(
    .gradient_var = function(g, vc) {
      vc[1:3, 4:6] <- 0
      vc[4:6, 1:3] <- 0
      real(g, vc)
    },
    .package = "medfit"
  )
  expect_false(tl_o3_se_ok(td, fit))
})

test_that("planted defect: a dropped cross-level block in the extracted vcov is caught directly", {
  skip_if_not_installed("lavaan")
  fit <- tl_defined_fit()
  real <- medfit:::.twolevel_subvcov
  testthat::local_mocked_bindings(
    .twolevel_subvcov = function(V, key) {
      out <- real(V, key)
      out[1:3, 4:6] <- 0
      out[4:6, 1:3] <- 0
      out
    },
    .package = "medfit"
  )
  td <- tl_extract(fit)
  V <- as.matrix(lavaan::vcov(fit))
  pt <- lavaan::parTable(fit)
  i <- pt$free[match(c("a", "a2"), pt$label)]
  expect_false(isTRUE(all.equal(td@vcov["a_within", "a_between"], V[i[1], i[2]])))
  # the functional a_within - a_between: joint SE from lavaan's := against the object's block
  pe <- lavaan::parameterEstimates(tl_cached("fit_adiff", tl_fit(tl_sim(), paste0(tl_model(), "d := a - a2\n"))))
  se_joint <- pe$se[pe$label == "d"]
  g <- c(a_within = 1, a_between = -1)
  se_obj <- sqrt(drop(t(g) %*% td@vcov[names(g), names(g)] %*% g))
  expect_gt(abs(se_obj - se_joint) / se_joint, 0.01)
})


# --- Hardening 7: a negative or missing variance is NA with one classed warning, never a silent NaN ---

# Classes of every warning raised while evaluating `expr`, and the value.
tl_collect_warnings <- function(expr) {
  classes <- list()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      classes[[length(classes) + 1L]] <<- class(w)
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, classes = classes)
}

test_that(".safe_se is sqrt for valid variances and NA with one classed warning otherwise", {
  v <- c(a = 4, b = 0, c = 2.25)
  res <- tl_collect_warnings(medfit:::.safe_se(v, "test"))
  expect_identical(res$value, sqrt(v))              # bit-identical when every entry is valid
  expect_length(res$classes, 0L)

  bad <- c(a = 4, b = -1, c = NA, d = -2)
  res <- tl_collect_warnings(medfit:::.safe_se(bad, "test"))
  expect_identical(unname(res$value), c(2, NA, NA, NA))
  expect_identical(names(res$value), names(bad))
  expect_identical(sum(vapply(res$classes, function(k) "medfit_warning_vcov_diagonal" %in% k, logical(1))), 1L)
  expect_length(res$classes, 1L)                    # one warning for the whole vector, no NaN warning
})

test_that("summary() reports NA for a negative variance and signals medfit_warning_vcov_diagonal", {
  td <- tl_td()
  vc <- td@vcov
  vc[2, 2] <- -0.01
  S7::prop(td, "vcov", check = FALSE) <- vc
  res <- tl_collect_warnings(summary(td))
  expect_true(any(vapply(res$classes, function(k) "medfit_warning_vcov_diagonal" %in% k, logical(1))))
  expect_true(is.na(res$value$paths["b_within", "std_error"]))
  expect_false(is.na(res$value$paths["a_within", "std_error"]))
  # planted defect: a plain sqrt gives NaN and no medfit warning, which this test must not accept
  plain <- suppressWarnings(sqrt(diag(vc)))
  expect_true(is.nan(plain[[2]]))
})

test_that("the extractor reports a negative between variance with the classed warning, not a silent NaN", {
  skip_if_not_installed("lavaan")
  fit <- tl_fixture("base")
  real_read <- medfit:::.twolevel_read_vcov
  pt <- lavaan::parTable(fit)
  i <- pt$free[match("a2", pt$label)]
  testthat::local_mocked_bindings(
    .twolevel_read_vcov = function(fit) {
      V <- real_read(fit)
      V[i, i] <- -0.01
      V
    },
    .twolevel_is_pd = function(M) TRUE,     # let the bad block reach the standard-error step
    .package = "medfit"
  )
  res <- tl_collect_warnings(try(extract_mediation(fit, "X", "M", "Y"), silent = TRUE))
  expect_true(any(vapply(res$classes, function(k) "medfit_warning_vcov_diagonal" %in% k, logical(1))))
  expect_s3_class(res$value, "try-error")           # the validator refuses the object that follows
})
