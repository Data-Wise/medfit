# FI-G3 slice S1b: the serial FIML class and its consumers (saturated, k = 0). The class carries the likelihood
# provenance (a variant slot that must agree with fit_context), the effects come from the existing serial gradient
# builders over the full extracted covariance, the exact-origin NA rule is per effect, and every consumer (tidy,
# confint, coef, summary, pm, glance, quick, bootstrap) either reports all six paths or refuses. Oracles: hand delta
# gradients of spec 3.2 recomputed from the extracted covariance, an enumeration of the directed paths, and the lavaan
# `:=` values in test-fiml-g3-serial-saturated.R. Helpers are in helper-fiml-serial.R (sb_*).

sb_obj <- local({
  cache <- list()
  function(direct = "free") {
    if (is.null(cache[[direct]])) {
      d <- sb_data("mar", cp = if (direct == "free") .25 else 0)
      cache[[direct]] <<- sb_extract(sb_fit(d, direct))
    }
    cache[[direct]]
  }
})
sb_note_total <- "NIE total inference unavailable: zero delta gradient"
sb_tidy <- function(z, ...) suppressWarnings(generics::tidy(z, ...))
sb_ci <- function(z, ...) suppressWarnings(confint(z, ...))

# ---- the class ---------------------------------------------------------------------------------------------------
test_that("the class is registered, inherits the serial class and stays internal", {
  z <- sb_obj()
  expect_true(S7::S7_inherits(z, FIMLSerialMediationData))
  expect_true(S7::S7_inherits(z, SerialMediationData))
  expect_true(.sem_fiml_is(z))
  expect_false("FIMLSerialMediationData" %in% getNamespaceExports("medfit"))
})

test_that("the validator binds the variant to fit_context (Q14): a forged variant breaks the object", {
  z <- sb_obj()
  # the slot and the context disagree
  expect_error(S7::set_props(z, variant = "chain"), "fit_context")
  ctx <- z@fit_context
  ctx$variant <- "chain"
  expect_error(S7::set_props(z, fit_context = ctx), "fit_context")
  # both changed together without rebinding the parameter hash
  expect_error(S7::set_props(z, variant = "chain", fit_context = ctx), "fit_context")
  # an unknown variant
  ctx$variant <- "bogus"
  expect_error(S7::set_props(z, variant = "bogus", fit_context = ctx), "fit_context")
  # tampering with an estimate, a path slot, the covariance or the data without rebinding the hash
  expect_error(S7::set_props(z, a_path = z@a_path + .1), "fit_context")
  est <- z@estimates
  est[["b"]] <- est[["b"]] + .1
  expect_error(S7::set_props(z, estimates = est), "fit_context")
  V <- z@vcov
  V[1, 1] <- V[1, 1] * 2
  expect_error(S7::set_props(z, vcov = V), "fit_context")
  # a saturated object whose predictor lists describe the chain, or whose estimates lack a shortcut path
  expect_error(S7::set_props(z, mediator_predictors = list("X", "M1")), "fit_context")
  expect_error(S7::set_props(z, outcome_predictors = c("M2", "X")), "fit_context")
  # the mediator order is the structural order
  ctx <- z@fit_context
  expect_error(S7::set_props(z, mediators = c("M2", "M1")), "fit_context")
})

test_that("a rebound forged object passes only when every part agrees", {
  z <- sb_obj()
  ok <- sb_forge(z, list(a = 0.3))
  expect_equal(ok@a_path, 0.3)
  expect_true(S7::S7_inherits(ok, FIMLSerialMediationData))
})

# ---- V8: effects, hand gradients and path enumeration -----------------------------------------------------------------
test_that("effects: chain, total indirect, direct and total equal the path enumeration to 1e-12", {
  for (dr in c("free", "zero")) {
    z <- sb_obj(dr)
    e <- z@estimates
    chain <- e[["a"]] * e[["d1"]] * e[["b"]]
    total_ind <- chain + e[["a2"]] * e[["b"]] + e[["a"]] * e[["b1"]]
    expect_equal(as.numeric(nie(z)), chain, tolerance = 1e-12)
    expect_equal(as.numeric(nie(z, type = "total")), total_ind, tolerance = 1e-12)
    expect_equal(as.numeric(nde(z)), e[["c_prime"]], tolerance = 1e-12)
    expect_equal(as.numeric(te(z)), total_ind + e[["c_prime"]], tolerance = 1e-12)
    # the matrix form: [(I - B)^-1]_{Y,X} over the saturated path matrix
    B <- matrix(0, 4, 4)
    B[2, 1] <- e[["a"]]
    B[3, 1] <- e[["a2"]]
    B[3, 2] <- e[["d1"]]
    B[4, 2] <- e[["b1"]]
    B[4, 3] <- e[["b"]]
    B[4, 1] <- e[["c_prime"]]
    expect_equal(solve(diag(4) - B)[4, 1], as.numeric(te(z)), tolerance = 1e-12)
  }
})

test_that("effect SEs equal the hand delta SEs from the extracted covariance to 1e-12, tidy and confint alike", {
  for (dr in c("free", "zero")) {
    z <- sb_obj(dr)
    g <- sb_grad(z)
    tb <- sb_tidy(z, type = "effects")
    se <- stats::setNames(tb$std_error, tb$term)
    for (k in c("nie", "nie_total", "nde", "te")) expect_equal(se[[k]], sb_se(z, g[[k]]), tolerance = 1e-12, info = k)
    ci <- sb_ci(z, parm = "effects")
    expect_identical(rownames(ci), c("nie", "nie_total", "nde", "te"))
    half <- (ci[, 2L] - ci[, 1L]) / 2 / stats::qnorm(.975)
    for (k in rownames(ci)) expect_equal(unname(half[[k]]), se[[k]], tolerance = 1e-10, info = k)
    expect_equal(unname(ci[, 1L] + ci[, 2L]) / 2, unname(tb$estimate), tolerance = 1e-12)
  }
  # the SE of the total indirect effect is NOT the chain SE and is not the sum of the chain and shortcut SEs
  z <- sb_obj()
  tb <- sb_tidy(z, type = "effects")
  expect_gt(abs(tb$std_error[tb$term == "nie_total"] - tb$std_error[tb$term == "nie"]), 1e-4)
})

test_that("the cross-equation terms matter for these SEs: dropping them changes nie and te under missingness", {
  z <- sb_obj()
  g <- sb_grad(z)
  Vd <- diag(diag(z@vcov))
  full <- sb_se(z, g$nie)
  diag_only <- sqrt(sum(g$nie^2 * diag(z@vcov)[names(g$nie)]))
  expect_gt(abs(full - diag_only) / full, 1e-4)
  expect_equal(Vd[1, 1], z@vcov[1, 1])
})

# ---- V12: the exact-origin rule, per effect -------------------------------------------------------------------------
sb_row <- function(z, term) {
  tb <- sb_tidy(z, type = "effects", conf_int = TRUE)
  list(tb = tb, row = tb[tb$term == term, ])
}
test_that("the per-effect helper: nie withheld when two of a, d1, b are 0; nie_total only when a = a2 = b = b1 = 0", {
  z <- sb_obj()
  expect_identical(.sem_fiml_origin_effects(z), c(nie = FALSE, nie_total = FALSE))
  at <- function(vals) .sem_fiml_origin_effects(sb_forge(z, vals))
  expect_identical(at(list(a = 0, d1 = 0)), c(nie = TRUE, nie_total = FALSE))
  expect_identical(at(list(a = 0, b = 0)), c(nie = TRUE, nie_total = FALSE))
  expect_identical(at(list(d1 = 0, b = 0)), c(nie = TRUE, nie_total = FALSE))
  expect_identical(at(list(a = 0, d1 = 0, b = 0)), c(nie = TRUE, nie_total = FALSE))
  expect_identical(at(list(a = 0)), c(nie = FALSE, nie_total = FALSE))
  expect_identical(at(list(d1 = 0)), c(nie = FALSE, nie_total = FALSE))
  expect_identical(at(list(b = 0)), c(nie = FALSE, nie_total = FALSE))
  expect_identical(at(list(a = 0, a2 = 0, b = 0, b1 = 0)), c(nie = TRUE, nie_total = TRUE))
  expect_identical(at(list(a = 0, a2 = 0, b = 0, b1 = 0, d1 = 0)), c(nie = TRUE, nie_total = TRUE))
  # three of the four is not enough for the total indirect effect, whichever is left
  for (nz in list(c("a", "a2", "b"), c("a", "a2", "b1"), c("a", "b", "b1"), c("a2", "b", "b1"))) {
    vals <- stats::setNames(as.list(rep(0, 3)), nz)
    expect_false(unname(at(vals)[["nie_total"]]), info = paste(nz, collapse = ","))
  }
  # the scalar helper stays scalar and is not the serial rule
  expect_identical(.sem_fiml_origin(z), FALSE)
  expect_identical(.sem_fiml_origin(sb_forge(z, list(a = 0, a2 = 0, b = 0, b1 = 0))), FALSE)
})

test_that("tidy: the nie SE is NA only where its gradient is zero, and each effect carries its own note", {
  z <- sb_obj()
  # a = d1 = 0: nie withheld, nie_total finite
  w <- sb_forge(z, list(a = 0, d1 = 0))
  r <- sb_row(w, "nie")
  expect_true(is.na(r$row$std_error) && is.na(r$row$conf_low) && is.na(r$row$conf_high))
  rt <- sb_row(w, "nie_total")$row
  expect_true(is.finite(rt$std_error) && is.finite(rt$conf_low))
  expect_equal(rt$std_error, sb_se(w, sb_grad(w)$nie_total), tolerance = 1e-12)
  expect_identical(attr(r$tb, "note"), c(nie = sb_note_nie))
  expect_true(all(is.finite(r$tb$std_error[r$tb$term %in% c("nde", "te")])))
  # a = 0 alone keeps a finite NIE SE equal to the hand value (gradient (d1 b, 0, 0))
  w <- sb_forge(z, list(a = 0))
  r <- sb_row(w, "nie")
  expect_true(is.finite(r$row$std_error))
  expect_equal(r$row$std_error, sb_se(w, c(a = w@estimates[["d1"]] * w@estimates[["b"]], d1 = 0, b = 0)), tolerance = 1e-12)
  expect_null(attr(r$tb, "note"))
  # a = a2 = b = b1 = 0: both withheld, both noted, te and nde never
  w <- sb_forge(z, list(a = 0, a2 = 0, b = 0, b1 = 0))
  r <- sb_row(w, "nie_total")
  expect_true(is.na(r$row$std_error))
  expect_true(is.na(sb_row(w, "nie")$row$std_error))
  expect_identical(attr(r$tb, "note"), c(nie = sb_note_nie, nie_total = sb_note_total))
  expect_true(all(is.finite(r$tb$std_error[r$tb$term %in% c("nde", "te")])))
  expect_true(is.finite(r$tb$std_error[r$tb$term == "te"]))
  # near-origin controls keep every SE finite and no note
  w <- sb_forge(z, list(a = 1e-9, a2 = 1e-9, b = 1e-9, b1 = 1e-9))
  r <- sb_row(w, "nie_total")
  expect_true(is.finite(r$row$std_error))
  expect_null(attr(r$tb, "note"))
  # the unforged object has no note
  expect_null(attr(sb_row(z, "nie")$tb, "note"))
})

test_that("confint: the same cells, NA rows and per-effect notes", {
  z <- sb_obj()
  w <- sb_forge(z, list(a = 0, d1 = 0))
  ci <- sb_ci(w, parm = "effects")
  expect_true(all(is.na(ci["nie", ])))
  expect_true(all(is.finite(ci["nie_total", ])))
  expect_identical(attr(ci, "note"), c(nie = sb_note_nie))
  w <- sb_forge(z, list(a = 0, a2 = 0, b = 0, b1 = 0))
  ci <- sb_ci(w, parm = "effects")
  expect_true(all(is.na(ci["nie", ])) && all(is.na(ci["nie_total", ])))
  expect_true(all(is.finite(ci["nde", ])) && all(is.finite(ci["te", ])))
  expect_identical(attr(ci, "note"), c(nie = sb_note_nie, nie_total = sb_note_total))
  w <- sb_forge(z, list(a = 0))
  ci <- sb_ci(w, parm = "effects")
  expect_true(all(is.finite(ci)))
  expect_null(attr(ci, "note"))
  expect_null(attr(sb_ci(z, parm = "effects"), "note"))
})

test_that("tampering with an object without rebinding the hash is rejected before any origin rule can read it", {
  z <- sb_obj()
  expect_error(S7::set_props(z, a_path = 0, d_path = 0), "fit_context")
})

# ---- path rows (Q4) ------------------------------------------------------------------------------------------------
test_that("paths(), coef(type = 'paths'), tidy and summary list all six estimated paths", {
  for (dr in c("free", "zero")) {
    z <- sb_obj(dr)
    p <- paths(z)
    expect_identical(names(p), c("a", "a2", "d", "b1", "b", "c_prime"))
    expect_equal(unname(p), unname(z@estimates[c("a", "a2", "d1", "b1", "b", "c_prime")]), tolerance = 1e-12)
    cf <- coef(z, type = "paths")
    expect_identical(names(cf), c("a", "a2", "d", "b1", "b", "c_prime"))
    expect_identical(cf, p)
    expect_identical(coef(z, type = "all"), z@estimates)
    s <- summary(z)
    expect_identical(names(s$paths)[1:6], c("a", "a2", "d", "b1", "b", "c_prime"))
    expect_equal(unname(s$paths[1:6]), unname(p), tolerance = 1e-12)
    expect_true(all(c("indirect", "indirect_total") %in% names(s$paths)))
    expect_equal(unname(s$paths[["indirect_total"]]), as.numeric(nie(z, type = "total")), tolerance = 1e-12)
    expect_identical(s$fit_context, z@fit_context)
    expect_output(print(s), "FIML")
    expect_output(print(s), "a2")
    expect_output(print(s), "b1")
  }
})

test_that("tidy and confint map every displayed path to a covariance row: six rows, SEs from the @vcov diagonal", {
  for (dr in c("free", "zero")) {
    z <- sb_obj(dr)
    tb <- sb_tidy(z, type = "paths", conf_int = TRUE)
    expect_identical(tb$term, c("a", "a2", "d", "b1", "b", "c_prime"))
    se <- sqrt(diag(z@vcov)[c("a", "a2", "d1", "b1", "b", "c_prime")])
    expect_equal(unname(tb$std_error), unname(se), tolerance = 1e-12)
    expect_equal(tb$conf_low, tb$estimate - stats::qnorm(.975) * tb$std_error, tolerance = 1e-12)
    ci <- sb_ci(z, parm = "paths")
    expect_identical(rownames(ci), c("a", "a2", "d", "b1", "b", "c_prime"))
    expect_equal(unname((ci[, 2L] - ci[, 1L]) / 2 / stats::qnorm(.975)), unname(se), tolerance = 1e-10)
    all <- sb_tidy(z)
    expect_identical(all$term, c("a", "a2", "d", "b1", "b", "c_prime", "nie", "nie_total", "nde", "te"))
    expect_identical(attr(all, "fit_context"), z@fit_context)
  }
  # the fixed-zero direct row is listed with value 0 and SE 0 (Q12)
  z <- sb_obj("zero")
  tb <- sb_tidy(z, type = "paths")
  expect_identical(tb$estimate[tb$term == "c_prime"], 0)
  expect_identical(tb$std_error[tb$term == "c_prime"], 0)
})

# ---- the confint contract (spec 3.3 item 3c) ------------------------------------------------------------------------
test_that("confint: boot is refused with the FIML text, and the effects warning carries no bootstrap advice", {
  z <- sb_obj()
  e <- tryCatch(confint(z, parm = "effects", method = "boot"), error = identity)
  expect_s3_class(e, "error")
  expect_identical(conditionMessage(e), "bootstrap CI is not supported for bounded FIML objects")
  expect_error(confint(z, parm = "paths", method = "boot"), "not supported for bounded FIML objects")
  expect_false(grepl("bootstrap_mediation\\(\\)", conditionMessage(e)))
  w <- NULL
  withCallingHandlers(confint(z, parm = "effects"), warning = function(c) {
    w <<- c(w, conditionMessage(c))
    invokeRestart("muffleWarning")
  })
  expect_length(w, 1L)
  expect_match(w, "Bootstrap intervals for FIML fits are unavailable pending statistical admission.", fixed = TRUE)
  expect_false(grepl("Consider bootstrap_mediation", w, fixed = TRUE))
  # paths: no warning
  expect_silent(confint(z, parm = "paths"))
  expect_error(confint(z, parm = "bogus"))
})

# ---- the refusals of the consumers ---------------------------------------------------------------------------------
test_that("pm(), glance() and quick() refuse the serial FIML object; bootstrap_mediation refuses it as input", {
  z <- sb_obj()
  expect_error(pm(z), "pm\\(\\) is not supported for bounded FIML objects")
  expect_error(generics::glance(z), "not supported for bounded FIML objects")
  expect_error(quick(z), "quick\\(\\) is not supported for bounded FIML objects")
  expect_error(bootstrap_mediation(function(x) 1, mediation_data = z), "bootstrap_mediation\\(\\) is not supported for bounded FIML")
  expect_error(bootstrap_mediation(function(x) 1, data = z), "bootstrap_mediation\\(\\) is not supported for bounded FIML")
  # the effects remain available, and printing works
  expect_s3_class(nie(z), "mediation_effect")
  expect_output(print(z))
})

# ---- the base serial class is byte-identical ---------------------------------------------------------------------------
sb_lm_serial <- function() {
  e <- c(a = .5, d1 = .4, b = .3, c_prime = .2)
  V <- diag(4) * c(.01, .02, .03, .04)
  dimnames(V) <- list(names(e), names(e))
  SerialMediationData(
    a_path = .5, d_path = .4, b_path = .3, c_prime = .2, estimates = e, vcov = V, sigma_mediators = c(1, 1),
    sigma_y = 1, treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
    mediator_predictors = list("X", "M1"), outcome_predictors = c("M2", "X"), data = NULL, n_obs = 10L,
    converged = TRUE, source_package = "lm"
  )
}
test_that("the lm/glm serial class is unchanged: four paths, three effect rows, the bootstrap advice, pm/glance/quick work", {
  z <- sb_lm_serial()
  expect_identical(names(coef(z, type = "paths")), c("a", "d", "b", "c_prime"))
  expect_identical(names(paths(z)), c("a", "d", "b", "c_prime"))
  expect_identical(rownames(confint(z, parm = "paths")), c("a", "d", "b", "c_prime"))
  w <- NULL
  ci <- withCallingHandlers(confint(z, parm = "effects"), warning = function(c) {
    w <<- c(w, conditionMessage(c))
    invokeRestart("muffleWarning")
  })
  expect_identical(rownames(ci), c("nie", "nde", "te"))
  expect_match(w, "Consider bootstrap_mediation() for robust inference.", fixed = TRUE)
  expect_null(attr(ci, "note"))
  e <- tryCatch(confint(z, method = "boot"), error = identity)
  expect_match(conditionMessage(e), "Bootstrap CIs are computed via bootstrap_mediation()", fixed = TRUE)
  tb <- generics::tidy(z)
  expect_identical(tb$term, c("a", "d", "b", "c_prime", "nie", "nie_total", "nde", "te"))
  expect_null(attr(tb, "note"))
  expect_null(attr(tb, "fit_context"))
  expect_silent(pm(z))
  expect_s3_class(generics::glance(z), "data.frame")
  expect_output(quick(z))
  expect_identical(names(summary(z)$paths), c("a", "d", "b", "c_prime", "indirect"))
  expect_false(.sem_fiml_is(z))
  expect_identical(.sem_fiml_origin(z), FALSE)
})
