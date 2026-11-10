# FI-G3 slice S4: bounded Gaussian FIML for two SERIAL mediators with TWO observed covariates Z1 and Z2, in both
# shortcut variants (the saturated forward graph and the pure chain), each with the direct path free or fixed exactly
# at zero.
# Random X: X, Z1, Z2, M1, M2, Y are jointly Gaussian with a free exogenous covariance (three pairs). Oracles, each
# independent of the production kernel: matched lavaan raw-data FIML (estimates, logLik, the full covariance and the
# `:=` effects), the closed-form complete-data equation-wise OLS with its block-diagonal covariance, a from-scratch
# rowwise likelihood with an independent Hessian, the unrestricted multivariate-normal likelihood, and OpenMx for one
# cell per variant. Helpers: helper-fiml-serial.R (sb_*), helper-fiml-serial3.R (s3_*), helper-fiml-serial4.R (s4_*).
# The covariate effects in the data-generating process are large and distinct from the path values and from each other.

s4_observe <- function(model, data) {
  e <- tryCatch(fit_sem(model, data, missing = "fiml", fixed_x = FALSE), error = identity)
  if (!inherits(e, "error")) return(list(class = "<fit>", message = NA_character_, stage = NA_character_))
  list(class = class(e), message = conditionMessage(e), stage = if (is.null(e$stage)) NA_character_ else e$stage)
}
s4_note_total <- "NIE total inference unavailable: zero delta gradient"
s4_cells <- expand.grid(variant = c("saturated", "chain"), direct = c("free", "zero"), stringsAsFactors = FALSE)
s4_cp <- function(dr) if (dr == "free") s4_truth[["cp"]] else 0

# ---- admission ------------------------------------------------------------------------------------------------------

test_that("k = 2 is a public fit for both variants and direct policies; parameter counts 27/26 and 25/24", {
  d <- s4_data("mar")
  for (i in seq_len(nrow(s4_cells))) {
    v <- s4_cells$variant[i]
    dr <- s4_cells$direct[i]
    f <- s4_fit(d, v, dr)
    expect_s3_class(f, "medfit::SEMFit")
    expect_identical(f@internals$likelihood$structure, "serial")
    expect_identical(f@internals$likelihood$variant, v)
    expect_identical(unname(f@internals$likelihood$covariate), c("Z1", "Z2"))
    q <- if (v == "saturated") 27L else 25L
    expect_identical(length(f@theta), q - (dr == "zero"), info = paste(v, dr))
    expect_true(f@converged)
  }
})

test_that("the admission predicates open k = 2 for both variants and keep k = 3 closed", {
  for (v in c("saturated", "chain")) {
    for (k in 0:2) {
      expect_true(.fiml_serial_shape_admitted(v, k), info = paste(v, k))
      expect_true(.fiml_serial_extract_supported(v, k), info = paste(v, k))
    }
    expect_false(.fiml_serial_shape_admitted(v, 3L))
    expect_false(.fiml_serial_extract_supported(v, 3L))
  }
  expect_false(.fiml_serial_shape_admitted("bogus", 2L))
})

test_that("k = 3 serial syntax stays refused at fit, for both variants, even with the master switch open", {
  d <- s4_data("complete")
  d$Z3 <- stats::rnorm(nrow(d))
  for (v in c("saturated", "chain")) {
    sat <- v == "saturated"
    m <- paste(c(
      "M1 ~ X + Z1 + Z2 + Z3", paste("M2 ~ M1 +", if (sat) "X + " else "", "Z1 + Z2 + Z3"),
      paste("Y ~", if (sat) "M1 + " else "", "M2 + X + Z1 + Z2 + Z3"), s4_zeros
    ), collapse = "\n")
    e <- tryCatch(fit_sem(m, d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input")
    expect_match(conditionMessage(e), "number of FIML covariates", info = v)
    testthat::local_mocked_bindings(.fiml_serial_admitted = function() TRUE)
    e2 <- tryCatch(fit_sem(m, d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e2, "medfit_sem_fiml_error")
  }
})

# ---- V1: lavaan raw-data FIML ----------------------------------------------------------------------------------------

test_that("estimates, covariance and logLik agree with lavaan raw-data FIML in every cell", {
  skip_if_not_installed("lavaan")
  for (i in seq_len(nrow(s4_cells))) {
    v <- s4_cells$variant[i]
    dr <- s4_cells$direct[i]
    for (kind in c("complete", "mar", "mcar30", "sparse", "zmiss")) {
      info <- paste(v, dr, kind)
      d <- s4_data(kind, cp = s4_cp(dr))
      f <- s4_fit(d, v, dr)
      l <- sb_lavaan(s4_model(v, dr), d)
      q <- coef(f)
      ref <- s4_align_v(lavaan::coef(l), names(q))
      expect_false(anyNA(ref), info = info)
      expect_lt(max(abs(q - ref)), 1e-5, label = info)
      expect_lt(abs(as.numeric(logLik(f)) - as.numeric(lavaan::logLik(l))), 1e-6, label = info)
      W <- s4_align_m(lavaan::vcov(l), names(q))
      expect_lt(sb_rel_gap(unname(vcov(f)), unname(W)), 2e-3, label = info)
    }
  }
})

test_that("the extracted aliases, their covariance block and the effects agree with lavaan's labeled model", {
  skip_if_not_installed("lavaan")
  for (i in seq_len(nrow(s4_cells))) {
    v <- s4_cells$variant[i]
    dr <- s4_cells$direct[i]
    for (kind in c("mar", "sparse")) {
      info <- paste(v, dr, kind)
      d <- s4_data(kind, cp = s4_cp(dr))
      z <- s4_extract(s4_fit(d, v, dr))
      ref <- s4_reference(d, v, dr)
      roles <- names(ref$est)
      expect_lt(max(abs(z@estimates[roles] - ref$est)), 1e-5, label = info)
      expect_lt(sb_rel_gap(z@vcov[roles, roles], ref$vcov), 2e-3, label = info)
      tb <- suppressWarnings(generics::tidy(z, type = "effects"))
      est <- stats::setNames(tb$estimate, tb$term)
      se <- stats::setNames(tb$std_error, tb$term)
      expect_lt(abs(est[["nie"]] - ref$ind$est), 1e-5, label = info)
      expect_lt(abs(est[["nie_total"]] - ref$ind_tot$est), 1e-5, label = info)
      expect_lt(abs(est[["te"]] - ref$te$est), 1e-5, label = info)
      expect_lt(abs(se[["nie"]] - ref$ind$se) / ref$ind$se, 3e-3, label = info)
      expect_lt(abs(se[["nie_total"]] - ref$ind_tot$se) / ref$ind_tot$se, 3e-3, label = info)
      expect_lt(abs(se[["te"]] - ref$te$se) / ref$te$se, 3e-3, label = info)
    }
  }
})

# ---- V3: complete-data closed form, block-diagonal covariance --------------------------------------------------------

test_that("complete data: equation-wise OLS with the ML exogenous moments and a block-diagonal covariance", {
  for (i in seq_len(nrow(s4_cells))) {
    v <- s4_cells$variant[i]
    dr <- s4_cells$direct[i]
    info <- paste(v, dr)
    d <- s4_data("complete", cp = s4_cp(dr))
    f <- s4_fit(d, v, dr)
    o <- s4_ols(d, v, dr)
    q <- coef(f)
    expect_setequal(sb_key(names(q)), sb_key(names(o$est)))
    expect_lt(max(abs(q - s4_align_v(o$est, names(q)))), 1e-6, label = info)
    expect_lt(abs(as.numeric(logLik(f)) - o$logl), 1e-6, label = info)
    W <- s4_align_m(o$vcov, names(q))
    expect_lt(sb_rel_gap(unname(vcov(f)), unname(W)), 1e-5, label = info)
    zero <- unname(W) == 0
    expect_lt(max(abs(vcov(f)[zero])) / max(abs(vcov(f))), 1e-6, label = info)
  }
})

test_that("saturated with a free direct path is the unrestricted multivariate normal (df 0); the chain restricts it", {
  d <- s4_data("complete")
  n <- nrow(d)
  S <- stats::cov(d) * (n - 1) / n
  ll_unrestricted <- -n / 2 * (6 * log(2 * pi) + log(det(S)) + 6)
  fs <- s4_fit(d, "saturated", "free")
  expect_lt(abs(as.numeric(logLik(fs)) - ll_unrestricted), 1e-7)
  expect_identical(length(fs@theta), 27L)
  for (dr in c("free", "zero")) {
    fc <- s4_fit(d, "chain", dr)
    expect_gt(as.numeric(logLik(fs)) - as.numeric(logLik(fc)), 1)
  }
  fz <- s4_fit(d, "saturated", "zero")
  expect_lt(as.numeric(logLik(fz)), as.numeric(logLik(fs)))
})

test_that("the chain's likelihood-ratio statistic against the saturated fit equals lavaan's model test (df 2 and 3)", {
  skip_if_not_installed("lavaan")
  for (kind in c("complete", "mar")) {
    for (dr in c("free", "zero")) {
      d <- s4_data(kind, cp = s4_cp(dr), a2 = .5, b1 = .4)
      fc <- s4_fit(d, "chain", dr)
      fs <- s4_fit(d, "saturated", "free")
      ref <- s4_reference(d, "chain", dr)
      expect_identical(as.integer(ref$df), if (dr == "free") 2L else 3L)
      expect_identical(length(fs@theta) - length(fc@theta), as.integer(ref$df))
      expect_lt(abs(2 * (as.numeric(logLik(fs)) - as.numeric(logLik(fc))) - ref$chisq), 1e-4, label = paste(kind, dr))
    }
  }
})

# ---- V6: rowwise likelihood and independent Hessian ------------------------------------------------------------------

test_that("the objective is the rowwise likelihood and the covariance inverts an independent Hessian", {
  for (v in c("saturated", "chain")) {
    for (cell in list(c("mar", "free"), c("sparse", "zero"))) {
      kind <- cell[1L]
      dr <- cell[2L]
      d <- s4_data(kind, cp = s4_cp(dr))
      f <- s4_fit(d, v, dr)
      q <- coef(f)
      keep <- d[rowSums(!is.na(d)) > 0L, ]
      nll <- function(x) s4_nll(keep, stats::setNames(x, names(q)))
      expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
      H <- numDeriv::hessian(nll, q)
      expect_lt(sb_rel_gap(solve(H), vcov(f)), 1e-3, label = paste(v, kind, dr))
    }
  }
})

# ---- V7: OpenMx, one cell per variant --------------------------------------------------------------------------------

test_that("OpenMx raw-data FIML agrees on the free-direct MAR cell of each variant", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  for (v in c("saturated", "chain")) {
    d <- s4_data("mar")
    f <- s4_fit(d, v, "free")
    q <- coef(f)
    lab <- function(nm) gsub("~", "_", nm, fixed = TRUE)
    paths <- list()
    for (nm in names(q)) {
      if (grepl("~1$", nm)) {
        paths[[nm]] <- OpenMx::mxPath(from = "one", to = sub("~1$", "", nm), arrow = 1, free = TRUE, values = 0,
                                      labels = lab(nm))
      } else if (grepl("~~", nm)) {
        p <- strsplit(nm, "~~", fixed = TRUE)[[1L]]
        same <- p[1L] == p[2L]
        paths[[nm]] <- OpenMx::mxPath(from = p[1L], to = if (same) NA else p[2L], arrow = 2, free = TRUE,
                                      values = if (same) 1 else .1, labels = lab(nm))
      } else {
        p <- strsplit(nm, "~", fixed = TRUE)[[1L]]
        paths[[nm]] <- OpenMx::mxPath(from = p[2L], to = p[1L], arrow = 1, free = TRUE, values = .1, labels = lab(nm))
      }
    }
    mx <- do.call(OpenMx::mxModel, c(
      list("s4", type = "RAM", manifestVars = s4_vars), unname(paths),
      list(OpenMx::mxData(d[rowSums(!is.na(d)) > 0L, s4_vars], type = "raw"))
    ))
    fit <- suppressWarnings(OpenMx::mxTryHard(mx, silent = TRUE, extraTries = 5L))
    expect_true(fit$output$status$code %in% c(0, 1), info = v)
    pars <- fit$output$estimate
    expect_lt(max(abs(pars[lab(names(q))] - q)), 5e-4, label = v)
    expect_lt(abs(fit$output$Minus2LogLikelihood / 2 - f@internals$likelihood$nll), 1e-5, label = v)
    se <- fit$output$standardErrors
    expect_equal(unname(se[lab(names(q)), 1L]), unname(sqrt(diag(vcov(f)))), tolerance = 5e-3)
  }
})

# ---- extraction ------------------------------------------------------------------------------------------------------

test_that("extraction keeps the variant's aliases, takes them from the treatment, and records both covariates", {
  for (v in c("saturated", "chain")) {
    o <- s4_obj(v, "free", "mar")
    z <- o$z
    q <- coef(o$f)
    expect_s3_class(z, "medfit::FIMLSerialMediationData")
    expect_identical(z@variant, v)
    expect_identical(z@treatment, "X")
    expect_identical(unname(z@fit_context$covariate), c("Z1", "Z2"))
    expect_identical(z@fit_context$variables[["X"]], "X")
    sat <- v == "saturated"
    alias <- if (sat) c("a", "a2", "d1", "b1", "b", "c_prime") else c("a", "d1", "b", "c_prime")
    expect_identical(names(z@estimates), alias)
    src <- if (sat) c("M1~X", "M2~X", "M2~M1", "Y~M1", "Y~M2", "Y~X") else c("M1~X", "M2~M1", "Y~M2", "Y~X")
    # the treatment's coefficients, not either covariate's (covariate effects 1.4, -0.8, -0.9, 1.1, 1.7, -1.2)
    expect_equal(unname(z@estimates), unname(q[src]), tolerance = 1e-12)
    idx <- match(src, names(q))
    expect_equal(unname(z@vcov), unname(vcov(o$f)[idx, idx]), tolerance = 1e-12)
    expect_equal(z@a_path, q[["M1~X"]])
    expect_equal(z@d_path, q[["M2~M1"]])
    expect_equal(z@b_path, q[["Y~M2"]])
    expect_equal(z@c_prime, q[["Y~X"]])
    expect_equal(z@sigma_mediators, sqrt(unname(q[c("M1~~M1", "M2~~M2")])), tolerance = 1e-12)
    expect_equal(z@sigma_y, sqrt(q[["Y~~Y"]]), tolerance = 1e-12)
    expect_setequal(z@mediator_predictors[[1L]], c("X", "Z1", "Z2"))
    expect_setequal(z@mediator_predictors[[2L]], c("M1", if (sat) "X", "Z1", "Z2"))
    expect_setequal(z@outcome_predictors, c(if (sat) "M1", "M2", "X", "Z1", "Z2"))
    expect_identical(z@n_obs, nobs(o$f))
    expect_false(is.na(as.numeric(te(z))))
  }
})

test_that("incomplete data: the cross-equation blocks of the extracted covariance are not zero", {
  for (v in c("saturated", "chain")) {
    z <- s4_obj(v, "free", "mar")$z
    expect_gt(abs(z@vcov["a", "d1"]) + abs(z@vcov["a", "b"]) + abs(z@vcov["d1", "b"]), 1e-8)
  }
})

test_that("a fixed-zero direct path is a zero row and column and the same object class, in both variants", {
  for (v in c("saturated", "chain")) {
    z <- s4_obj(v, "zero", "mar")$z
    expect_identical(z@c_prime, 0)
    expect_true(all(z@vcov["c_prime", ] == 0) && all(z@vcov[, "c_prime"] == 0))
    expect_identical(unname(z@fit_context$covariate), c("Z1", "Z2"))
    expect_setequal(z@outcome_predictors, c(if (v == "saturated") "M1", "M2", "X", "Z1", "Z2"))
  }
})

test_that("hand delta-method SEs from the extracted covariance equal tidy() to 1e-12, with two covariates in the fit", {
  for (i in seq_len(nrow(s4_cells))) {
    v <- s4_cells$variant[i]
    dr <- s4_cells$direct[i]
    z <- s4_obj(v, dr, "mar")$z
    g <- s4_grad(z)
    tb <- generics::tidy(z, type = "effects")
    se <- stats::setNames(tb$std_error, tb$term)
    for (eff in c("nie", "nie_total", "nde", "te")) {
      gg <- g[[eff]]
      if (eff == "te" && dr != "free") gg <- gg[names(gg) != "c_prime"]
      if (eff == "nde" && dr != "free") next
      expect_lt(abs(se[[eff]] - sb_se(z, gg)), 1e-12, label = paste(v, dr, eff))
    }
  }
})

test_that("the path rows and intervals come from the extracted covariance: every displayed path has its own row", {
  for (v in c("saturated", "chain")) {
    z <- s4_obj(v, "free", "mar")$z
    alias <- names(z@estimates)
    tp <- generics::tidy(z, type = "paths", conf_int = TRUE)
    expect_identical(nrow(tp), length(alias))
    expect_lt(max(abs(tp$std_error - sqrt(diag(z@vcov)[alias]))), 1e-12)
    ci <- confint(z, parm = "paths")
    expect_identical(nrow(ci), length(alias))
    want <- if (v == "saturated") c("a", "a2", "d", "b1", "b", "c_prime") else c("a", "d", "b", "c_prime")
    expect_identical(names(coef(z, type = "paths")), want)
    ce <- suppressWarnings(confint(z, parm = "effects"))
    expect_identical(rownames(ce), c("nie", "nie_total", "nde", "te"))
    expect_no_error(utils::capture.output(print(z)))
    expect_no_error(utils::capture.output(print(summary(z))))
  }
})

# ---- exact-origin rules with two covariates in the fit ---------------------------------------------------------------

test_that("the per-effect exact-origin rules hold for k = 2 objects in both variants, in tidy() and confint()", {
  na_row <- function(w, term) {
    t <- suppressWarnings(generics::tidy(w, type = "effects"))
    is.na(t$std_error[t$term == term])
  }
  notes <- function(w) attr(suppressWarnings(generics::tidy(w, type = "effects")), "note")
  ci_na <- function(w, term) all(is.na(suppressWarnings(confint(w, parm = "effects"))[term, ]))
  for (v in c("saturated", "chain")) {
    z <- s4_obj(v, "free", "mar")$z
    expect_identical(unname(z@fit_context$covariate), c("Z1", "Z2"))
    for (zero in list(c("a", "d1"), c("a", "b"), c("d1", "b"))) {
      w <- sb_forge(z, stats::setNames(as.list(rep(0, 2L)), zero))
      expect_true(na_row(w, "nie"), info = paste(v, paste(zero, collapse = "")))
      expect_true(ci_na(w, "nie"), info = paste(v, paste(zero, collapse = "")))
      expect_identical(unname(notes(w)["nie"]), sb_note_nie)
      expect_false(na_row(w, "te"))
      expect_false(na_row(w, "nde"))
      if (v == "chain") {
        expect_true(na_row(w, "nie_total"))
        expect_identical(unname(notes(w)["nie_total"]), s4_note_total)
      }
    }
    w <- sb_forge(z, list(a = 0))
    expect_false(na_row(w, "nie"))
    expect_false(na_row(w, "nie_total"))
    expect_null(notes(w))
    expect_false(ci_na(w, "nie"))
  }
  z <- s4_obj("saturated", "free", "mar")$z
  w <- sb_forge(z, list(a = 0, d1 = 0))
  expect_false(na_row(w, "nie_total"))
  w <- sb_forge(z, list(a = 0, a2 = 0, b = 0, b1 = 0))
  expect_true(na_row(w, "nie_total") && na_row(w, "nie"))
  expect_true(ci_na(w, "nie_total"))
  expect_identical(notes(w), c(nie = sb_note_nie, nie_total = s4_note_total))
  expect_false(na_row(w, "te"))
  expect_false(na_row(w, "nde"))
})

# ---- the treatment rule (Q6 and Q6a) ---------------------------------------------------------------------------------

test_that("saturated: either covariate may be the treatment: a = gm1, a2 = gm2, c_prime = gy (lavaan relabeled)", {
  skip_if_not_installed("lavaan")
  for (kind in c("mar", "sparse")) {
    d <- s4_data(kind)
    f <- s4_fit(d, "saturated", "free")
    q <- coef(f)
    for (tr in c("Z1", "Z2")) {
      zt <- s4_extract(f, treatment = tr)
      other <- setdiff(c("Z1", "Z2"), tr)
      expect_identical(zt@treatment, tr)
      expect_identical(zt@fit_context$variables[["X"]], tr)
      expect_setequal(zt@fit_context$covariate, c("X", other))
      src <- paste0(c("M1~", "M2~"), tr)
      expect_equal(unname(zt@estimates), unname(q[c(src, "M2~M1", "Y~M1", "Y~M2", paste0("Y~", tr))]),
                   tolerance = 1e-12, info = paste(kind, tr))
      ref <- s4_reference(d, "saturated", "free", tr = tr, cvs = c("X", other))
      roles <- names(ref$est)
      expect_lt(max(abs(zt@estimates[roles] - ref$est)), 1e-5, label = paste(kind, tr))
      expect_lt(sb_rel_gap(zt@vcov[roles, roles], ref$vcov), 2e-3, label = paste(kind, tr))
      tb <- suppressWarnings(generics::tidy(zt, type = "effects"))
      se <- stats::setNames(tb$std_error, tb$term)
      expect_lt(abs(se[["nie_total"]] - ref$ind_tot$se) / ref$ind_tot$se, 3e-3, label = paste(kind, tr))
      expect_lt(abs(se[["te"]] - ref$te$se) / ref$te$se, 3e-3, label = paste(kind, tr))
      expect_setequal(zt@mediator_predictors[[1L]], c("X", "Z1", "Z2"))
      expect_setequal(zt@outcome_predictors, c("M1", "M2", "X", "Z1", "Z2"))
    }
    # the three treatments give three different aliases: a covariate's coefficients are not another's
    a <- vapply(c("X", "Z1", "Z2"), function(tr) s4_extract(f, treatment = tr)@a_path, numeric(1))
    expect_gt(min(abs(diff(unname(a)))), .1)
  }
})

test_that("saturated: a fixed-zero Y path on Z2 makes Z2 the treatment; naming X or Z1 says so (classed)", {
  d <- s4_data("mar", cp = 0)
  m <- "M1 ~ X + Z1 + Z2\nM2 ~ M1 + X + Z1 + Z2\nY ~ M1 + M2 + X + Z1 + 0*Z2"
  f <- fit_sem(paste(m, paste(s4_zeros, collapse = "\n"), sep = "\n"), d, missing = "fiml", fixed_x = FALSE)
  expect_identical(length(f@theta), 26L)
  expect_identical(f@internals$likelihood$variables[["X"]], "Z2")
  z <- s4_extract(f, treatment = "Z2")
  expect_identical(z@treatment, "Z2")
  expect_identical(z@c_prime, 0)
  expect_setequal(z@fit_context$covariate, c("X", "Z1"))
  for (tr in c("X", "Z1")) {
    e <- tryCatch(s4_extract(f, treatment = tr), error = identity)
    expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
    expect_match(conditionMessage(e), "fixed-zero direct path", info = tr)
    expect_match(conditionMessage(e), "Z2", fixed = TRUE, info = tr)
  }
  # an unknown name keeps the generic message
  e <- tryCatch(s4_extract(f, treatment = "W"), error = identity)
  expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
  expect_no_match(conditionMessage(e), "fixed-zero direct path")
  # with the fixed zero on X (the usual case) a covariate cannot be the treatment either, and the message names X
  f0 <- s4_fit(d, "saturated", "zero")
  for (tr in c("Z1", "Z2")) {
    e0 <- tryCatch(s4_extract(f0, treatment = tr), error = identity)
    expect_s3_class(e0, "medfit_error_fiml_extract_unsupported")
    expect_match(conditionMessage(e0), "fixed-zero direct path", info = tr)
    expect_match(conditionMessage(e0), "X", fixed = TRUE, info = tr)
  }
})

test_that("chain: the treatment is structural, and naming either covariate is refused (Q6a)", {
  for (dr in c("free", "zero")) {
    f <- s4_obj("chain", dr, "mar")$f
    for (tr in c("Z1", "Z2")) {
      e <- tryCatch(s4_extract(f, treatment = tr), error = identity)
      expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
      expect_match(conditionMessage(e), "structural|covariate", info = paste(dr, tr))
    }
    expect_s3_class(s4_extract(f, treatment = "X"), "medfit::FIMLSerialMediationData")
  }
})

test_that("chain: the variable absent from M2 is the treatment whatever its name; the others are then covariates", {
  d <- s4_data("mar")
  # Z2 is absent from M2's equation: it is the chain's treatment and X, Z1 the covariates (the F6 reading)
  m <- s4_model("chain", "free", tr = "Z2", cvs = c("X", "Z1"))
  f <- fit_sem(m, d, missing = "fiml", fixed_x = FALSE)
  expect_identical(f@internals$likelihood$variables[["X"]], "Z2")
  expect_setequal(f@internals$likelihood$covariate, c("X", "Z1"))
  expect_identical(length(f@theta), 25L)
  z <- s4_extract(f, treatment = "Z2")
  expect_identical(z@treatment, "Z2")
  expect_identical(z@variant, "chain")
  q <- coef(f)
  expect_equal(unname(z@estimates), unname(q[c("M1~Z2", "M2~M1", "Y~M2", "Y~Z2")]), tolerance = 1e-12)
  expect_s3_class(tryCatch(s4_extract(f, treatment = "X"), error = identity), "medfit_error_fiml_extract_unsupported")
  skip_if_not_installed("lavaan")
  ref <- s4_reference(d, "chain", "free", tr = "Z2", cvs = c("X", "Z1"))
  expect_lt(max(abs(z@estimates[names(ref$est)] - ref$est)), 1e-5)
})

# ---- extraction refusals ---------------------------------------------------------------------------------------------

test_that("extraction refuses the reversed mediators, a covariate as mediator, standardized and unknown arguments", {
  f <- s4_obj("saturated", "free", "mar")$f
  cls <- "medfit_error_fiml_extract_unsupported"
  expect_s3_class(tryCatch(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")), error = identity), cls)
  expect_s3_class(tryCatch(extract_mediation(f, treatment = "X", mediator = c("M1", "Z2")), error = identity), cls)
  expect_s3_class(tryCatch(extract_mediation(f, treatment = "X", mediator = "M1"), error = identity), cls)
  expect_s3_class(tryCatch(s4_extract(f, standardized = TRUE), error = identity), cls)
  expect_s3_class(tryCatch(s4_extract(f, structure = "parallel"), error = identity), cls)
  expect_s3_class(tryCatch(s4_extract(f, bogus = 1), error = identity), cls)
  expect_s3_class(tryCatch(s4_extract(f, treatment = "W"), error = identity), cls)
  expect_s3_class(s4_extract(f, structure = "serial"), "medfit::FIMLSerialMediationData")
})

# ---- the validator ---------------------------------------------------------------------------------------------------

test_that("the validator rejects forgeries with two covariates: dropped, on some equations only, wrong treatment", {
  forge <- function(z, ...) {
    for (nm in names(list(...))) attr(z, nm) <- list(...)[[nm]]
    z
  }
  valid <- function(z) is.null(FIMLSerialMediationData@validator(z))
  for (v in c("saturated", "chain")) {
    z <- s4_obj(v, "free", "mar")$z
    expect_true(valid(z), info = v)
    ctx <- z@fit_context
    bad <- list(
      z1_dropped_m1 = forge(z, mediator_predictors = list(c("X", "Z2"), z@mediator_predictors[[2L]])),
      z2_dropped_m2 = forge(z, mediator_predictors = list(
        z@mediator_predictors[[1L]], setdiff(z@mediator_predictors[[2L]], "Z2")
      )),
      z1_dropped_y = forge(z, outcome_predictors = setdiff(z@outcome_predictors, "Z1")),
      both_dropped_y = forge(z, outcome_predictors = setdiff(z@outcome_predictors, c("Z1", "Z2"))),
      z2_on_y_only = forge(z, mediator_predictors = list(c("X", "Z1"), setdiff(z@mediator_predictors[[2L]], "Z2"))),
      one_covariate_forgotten = forge(z, fit_context = replace(ctx, "covariate", list("Z1"))),
      covariate_forgotten = forge(z, fit_context = replace(ctx, "covariate", list(NULL))),
      wrong_treatment = forge(z, treatment = "Z1")
    )
    for (nm in names(bad)) expect_false(valid(bad[[nm]]), info = paste(v, nm))
    expect_true(valid(forge(z, mediator_predictors = rev(z@mediator_predictors)[c(2L, 1L)])), info = v)
  }
})

# ---- consumers -------------------------------------------------------------------------------------------------------

test_that("the consumers refuse the k = 2 serial fit and its extracted object as for every FIML fit", {
  for (v in c("saturated", "chain")) {
    o <- s4_obj(v, "free", "mar")
    expect_error(pm(o$z), "not supported for bounded FIML objects")
    expect_error(quick(o$z), "not supported for bounded FIML objects")
    expect_error(generics::glance(o$z), "not supported for bounded FIML objects")
    expect_error(confint(o$z, method = "boot"), "not supported for bounded FIML objects")
    expect_error(bootstrap_mediation(function(x) 1, mediation_data = o$z), "FIML")
  }
})

test_that("source-fit inference: the stage-0 guard answers first, then the serial class, before any RNG or refit", {
  fx_skip_covr()
  refit_calls <- 0L
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    refit_calls <<- refit_calls + 1L
    stop("refit reached")
  })
  fits <- lapply(c("saturated", "chain"), function(v) s4_obj(v, "free", "mar")$f)
  for (f in fits) for (m in c("parametric", "nonparametric")) {
    expect_error(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L),
                 class = "medfit_error_fiml_inference_unavailable")
  }
  testthat::local_mocked_bindings(.fiml_source_inference_admitted = function() TRUE)
  for (f in fits) for (m in c("parametric", "nonparametric")) {
    set.seed(99L)
    before <- .Random.seed
    e <- tryCatch(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L), error = identity)
    expect_s3_class(e, "medfit_error_fiml_serial_source_fit")
    expect_false(inherits(e, "medfit_error_fiml_parallel_source_fit"))
    expect_false(inherits(e, "medfit_error_fiml_covariate_source_fit"))
    expect_identical(.Random.seed, before)
  }
  expect_identical(refit_calls, 0L)
})

test_that("other consumers of the k = 2 fit refuse it as for every FIML fit", {
  f <- s4_obj("saturated", "free", "mar")$f
  expect_error(mbco_sem(f, a = "M1~X", b = "Y~M2"), "FIML")
  expect_error(compare_lr(f, paths = c("M1~X", "Y~M2")), "FIML")
  expect_error(anova(f, f), "FIML")
  expect_identical(generics::glance(f)$npar, 27L)
})

# ---- what stays refused at fit ---------------------------------------------------------------------------------------

s4_refused <- c(
  omitted_zero_m1m2 = s4_body(tail = c("M1 ~~ 0*Y", "M2 ~~ 0*Y")),
  omitted_zero_m2y = s4_body(tail = c("M1 ~~ 0*M2", "M1 ~~ 0*Y")),
  free_residual = s4_body(tail = c("M1 ~~ 0*M2", "M1 ~~ 0*Y", "M2 ~~ Y")),
  covariate_on_m1_only = s4_body(m2 = "M2 ~ M1 + X", y = "Y ~ M1 + M2 + X"),
  one_covariate_not_on_m2 = s4_body(m2 = "M2 ~ M1 + X + Z1"),
  one_covariate_not_on_y = s4_body(y = "Y ~ M1 + M2 + X + Z1"),
  one_covariate_not_on_m1 = s4_body(m1 = "M1 ~ X + Z1"),
  omitted_y_path_x = s4_body(y = "Y ~ M1 + M2 + Z1 + Z2"),
  omitted_y_path_z2 = s4_body(y = "Y ~ M1 + M2 + X + Z1"),
  omitted_y_path_chain = s4_body(m2 = "M2 ~ M1 + Z1 + Z2", y = "Y ~ M2 + Z1 + Z2"),
  two_y_fixed = s4_body(y = "Y ~ M1 + M2 + 0*X + 0*Z1 + Z2"),
  three_y_fixed = s4_body(y = "Y ~ M1 + M2 + 0*X + 0*Z1 + 0*Z2"),
  fixed_covariate_to_m = s4_body(m1 = "M1 ~ X + 0*Z1 + Z2"),
  fixed_nonzero_direct = s4_body(y = "Y ~ M1 + M2 + .5*X + Z1 + Z2"),
  labeled_a2 = s4_body(m2 = "M2 ~ M1 + a2*X + Z1 + Z2"),
  fixed_b1 = s4_body(y = "Y ~ 0*M1 + M2 + X + Z1 + Z2"),
  tied_covariate_paths = s4_body(m1 = "M1 ~ X + p*Z1 + Z2", m2 = "M2 ~ M1 + X + p*Z1 + Z2"),
  fixed_exo_cov = s4_body(tail = c(s4_zeros, "X ~~ 0*Z1")),
  fixed_exo_cov_z1z2 = s4_body(tail = c(s4_zeros, "Z1 ~~ 0*Z2")),
  partial_shortcut_x_only = s4_body(y = "Y ~ M2 + X + Z1 + Z2"),
  partial_shortcut_b1_only = s4_body(m2 = "M2 ~ M1 + Z1 + Z2"),
  chain_both_absent = s4_body(m2 = "M2 ~ M1 + Z1", y = "Y ~ M2 + X + Z1 + Z2"),
  chain_three_absent = s4_body(m2 = "M2 ~ M1", y = "Y ~ M2 + X + Z1 + Z2"),
  mediator_exo_cov = s4_body(tail = c(s4_zeros, "M1 ~~ Z2")),
  interaction = s4_body(y = "Y ~ M1 + M2 + X + Z1 + Z2 + M1:X")
)

test_that("every other k = 2 serial syntax is refused at fit with a classed reason", {
  d <- s4_data("complete")
  for (nm in names(s4_refused)) {
    e <- tryCatch(fit_sem(s4_refused[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
  }
})

test_that("a partial exogenous covariance set is refused with a reason that names it (S3 QA finding 2)", {
  d <- s4_data("complete")
  for (tail in list(
    c(s4_zeros, "X ~~ Z1"), c(s4_zeros, "X ~~ Z2"), c(s4_zeros, "Z1 ~~ Z2"), c(s4_zeros, "X ~~ Z1", "X ~~ Z2")
  )) {
    for (variant in c("saturated", "chain")) {
      body <- if (variant == "saturated") {
        s4_body(tail = tail)
      } else {
        s4_body(m2 = "M2 ~ M1 + Z1 + Z2", y = "Y ~ M2 + X + Z1 + Z2", tail = tail)
      }
      e <- tryCatch(fit_sem(body, d, missing = "fiml", fixed_x = FALSE), error = identity)
      expect_s3_class(e, "medfit_sem_fiml_error")
      expect_identical(e$stage, "input")
      info <- paste(variant, paste(tail[-(1:3)], collapse = " "))
      expect_match(conditionMessage(e), "exogenous covariance", info = info)
      expect_no_match(conditionMessage(e), "serial mediation needs M1 ~ X")
    }
  }
})

test_that("the complete written exogenous-covariance set, in any pair order, is the same model as the omitted one", {
  d <- s4_data("mar")
  for (v in c("saturated", "chain")) {
    f0 <- s4_fit(d, v, "free")
    fa <- s4_fit(d, model = s4_model(v, "free", exo_cov = "all"))
    expect_equal(unname(s4_align_v(coef(fa), names(coef(f0)))), unname(coef(f0)), tolerance = 1e-8, info = v)
    swapped <- gsub("X ~~ Z1", "Z1 ~~ X", s4_model(v, "free", exo_cov = "all"), fixed = TRUE)
    swapped <- gsub("X ~~ Z2", "Z2 ~~ X", swapped, fixed = TRUE)
    expect_false(identical(swapped, s4_model(v, "free", exo_cov = "all")))
    fs <- s4_fit(d, model = swapped)
    expect_equal(unname(s4_align_v(coef(fs), names(coef(f0)))), unname(coef(f0)), tolerance = 1e-8, info = v)
  }
})

# ---- frozen fixtures -------------------------------------------------------------------------------------------------

test_that("the k = 2 tables are frozen with identical(); the refusal dump pins the entries that became fits", {
  tb <- readRDS(test_path("fixtures", "fiml-tables-after-g3s4.rds"))
  expect_length(tb, 4L)
  for (sc in c(TRUE, FALSE)) for (dr in c(TRUE, FALSE)) {
    nm <- paste0(if (sc) "sat2" else "chain2", if (dr) "free" else "fixed")
    expect_identical(.sem_fiml_tables_ser(dr, 2L, sc), tb[[nm]], info = nm)
    expect_identical(nrow(tb[[nm]]$a) + nrow(tb[[nm]]$s) + nrow(tb[[nm]]$m) - sum(!is.na(tb[[nm]]$a$value)),
                     (if (sc) 27L else 25L) - !dr, info = nm)
  }
  b3 <- readRDS(test_path("fixtures", "fiml-refusals-after-g3s3.rds"))
  b4 <- readRDS(test_path("fixtures", "fiml-refusals-after-g3s4.rds"))
  expect_identical(b4$models, b3$models)
  changed <- c("ser_sat2_zeros", "ser_chain2_zeros", "ser_all_exo_cov_sat2")
  # a refusal that is now worded by its own reason (S3 QA finding 2)
  reworded <- "ser_partial_exo_cov_sat2"
  for (nm in names(b4$models)) {
    got <- s4_observe(b4$models[[nm]], b4$data)
    expect_identical(got$class, b4$results[[nm]]$class, info = nm)
    expect_identical(got$message, b4$results[[nm]]$message, info = nm)
    expect_identical(got$stage, b4$results[[nm]]$stage, info = nm)
    if (nm %in% changed) {
      expect_identical(b4$results[[nm]]$class, "<fit>", info = nm)
      expect_match(b3$results[[nm]]$message, "serial FIML is not yet available", info = nm)
    } else if (nm %in% reworded) {
      expect_identical(b4$results[[nm]]$class, b3$results[[nm]]$class, info = nm)
      expect_match(b4$results[[nm]]$message, "exogenous covariance", info = nm)
      expect_match(b3$results[[nm]]$message, "serial mediation needs M1 ~ X", info = nm)
    } else {
      expect_identical(b4$results[[nm]], b3$results[[nm]], info = nm)
    }
  }
})
