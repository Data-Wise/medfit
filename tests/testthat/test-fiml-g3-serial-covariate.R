# FI-G3 slice S3: bounded Gaussian FIML for two SERIAL mediators with ONE observed covariate Z, in both shortcut
# variants (the saturated forward graph and the pure chain), each with the direct path free or fixed exactly at zero.
# Random X: X, Z, M1, M2, Y are jointly Gaussian with a free exogenous covariance. Oracles, each independent of the
# production kernel: matched lavaan raw-data FIML (estimates, logLik, the full covariance and the `:=` effects), the
# closed-form complete-data equation-wise OLS with its block-diagonal covariance, a from-scratch rowwise likelihood with an
# independent Hessian, the unrestricted multivariate-normal likelihood, and OpenMx for one cell per variant. Helpers:
# helper-fiml-serial.R (sb_*) and helper-fiml-serial3.R (s3_*). The covariate effects in the data-generating process are
# large and distinct from the path values, so a covariate coefficient mistaken for a path cannot hide.

s3_cells <- expand.grid(variant = c("saturated", "chain"), direct = c("free", "zero"), stringsAsFactors = FALSE)

# ---- admission ------------------------------------------------------------------------------------------------------

test_that("k = 1 is a public fit for both variants and both direct policies; the parameter counts are 20/19 and 18/17", {
  d <- s3_data("mar")
  for (i in seq_len(nrow(s3_cells))) {
    v <- s3_cells$variant[i]
    dr <- s3_cells$direct[i]
    f <- s3_fit(d, v, dr)
    expect_s3_class(f, "medfit::SEMFit")
    expect_identical(f@internals$likelihood$structure, "serial")
    expect_identical(f@internals$likelihood$variant, v)
    expect_identical(f@internals$likelihood$covariate, "Z")
    q <- if (v == "saturated") 20L else 18L
    expect_identical(length(f@theta), q - (dr == "zero"), info = paste(v, dr))
    expect_true(f@converged)
  }
})

test_that("the admission predicates open k = 1 for both variants and keep k = 2 closed", {
  for (v in c("saturated", "chain")) {
    for (k in 0:1) {
      expect_true(.fiml_serial_shape_admitted(v, k), info = paste(v, k))
      expect_true(.fiml_serial_extract_supported(v, k), info = paste(v, k))
    }
    expect_false(.fiml_serial_shape_admitted(v, 2L))
    expect_false(.fiml_serial_extract_supported(v, 2L))
  }
  expect_false(.fiml_serial_shape_admitted("bogus", 1L))
})

test_that("k = 2 serial syntax stays refused with the not-yet-available reason, for both variants", {
  d <- s3_data("complete")
  d$Z1 <- d$Z
  d$Z2 <- d$X - d$Z
  for (v in c("saturated", "chain")) {
    sat <- v == "saturated"
    m <- paste(c(
      "M1 ~ X + Z1 + Z2", paste("M2 ~ M1 +", if (sat) "X + " else "", "Z1 + Z2"),
      paste("Y ~", if (sat) "M1 + " else "", "M2 + X + Z1 + Z2"), s3_zeros
    ), collapse = "\n")
    e <- tryCatch(fit_sem(m, d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_match(conditionMessage(e), "serial FIML is not yet available", info = v)
  }
})

# ---- V1: lavaan raw-data FIML ----------------------------------------------------------------------------------------

test_that("estimates, covariance and logLik agree with lavaan raw-data FIML in every cell", {
  skip_if_not_installed("lavaan")
  for (i in seq_len(nrow(s3_cells))) {
    v <- s3_cells$variant[i]
    dr <- s3_cells$direct[i]
    for (kind in c("complete", "mar", "mcar30", "sparse", "zmiss")) {
      info <- paste(v, dr, kind)
      d <- s3_data(kind, cp = if (dr == "free") s3_truth[["cp"]] else 0)
      f <- s3_fit(d, v, dr)
      l <- sb_lavaan(s3_model(v, dr), d)
      q <- coef(f)
      ref <- s3_align_v(lavaan::coef(l), names(q))
      expect_false(anyNA(ref), info = info)
      expect_lt(max(abs(q - ref)), 1e-5, label = info)
      expect_lt(abs(as.numeric(logLik(f)) - as.numeric(lavaan::logLik(l))), 1e-6, label = info)
      W <- s3_align_m(lavaan::vcov(l), names(q))
      expect_lt(sb_rel_gap(unname(vcov(f)), unname(W)), 2e-3, label = info)
    }
  }
})

test_that("the extracted aliases, their covariance block and the effects agree with lavaan's labeled model", {
  skip_if_not_installed("lavaan")
  for (i in seq_len(nrow(s3_cells))) {
    v <- s3_cells$variant[i]
    dr <- s3_cells$direct[i]
    for (kind in c("mar", "sparse")) {
      info <- paste(v, dr, kind)
      d <- s3_data(kind, cp = if (dr == "free") s3_truth[["cp"]] else 0)
      z <- s3_extract(s3_fit(d, v, dr))
      ref <- s3_reference(d, v, dr)
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

# ---- V2: complete-data closed form, block-diagonal covariance ---------------------------------------------------------

test_that("complete data: equation-wise OLS with the ML exogenous moments and a block-diagonal covariance", {
  for (i in seq_len(nrow(s3_cells))) {
    v <- s3_cells$variant[i]
    dr <- s3_cells$direct[i]
    info <- paste(v, dr)
    d <- s3_data("complete", cp = if (dr == "free") s3_truth[["cp"]] else 0)
    f <- s3_fit(d, v, dr)
    o <- s3_ols(d, v, dr)
    q <- coef(f)
    expect_setequal(sb_key(names(q)), sb_key(names(o$est)))
    expect_lt(max(abs(q - s3_align_v(o$est, names(q)))), 1e-6, label = info)
    expect_lt(abs(as.numeric(logLik(f)) - o$logl), 1e-6, label = info)
    W <- s3_align_m(o$vcov, names(q))
    expect_lt(sb_rel_gap(unname(vcov(f)), unname(W)), 1e-5, label = info)
    # the cross-equation blocks and the exogenous block's cross terms with the equations are exactly zero in the oracle
    # and negligible in the fit
    zero <- unname(W) == 0
    expect_lt(max(abs(vcov(f)[zero])) / max(abs(vcov(f))), 1e-6, label = info)
  }
})

test_that("saturated with a free direct path is the unrestricted multivariate-normal fit (df 0), and the chain restricts it", {
  d <- s3_data("complete")
  n <- nrow(d)
  S <- stats::cov(d) * (n - 1) / n
  ll_unrestricted <- -n / 2 * (5 * log(2 * pi) + log(det(S)) + 5)
  fs <- s3_fit(d, "saturated", "free")
  expect_lt(abs(as.numeric(logLik(fs)) - ll_unrestricted), 1e-7)
  expect_identical(length(fs@theta), 20L)
  # the restricted fits cannot exceed it; a true saturated DGP makes the chain fit strictly worse
  for (dr in c("free", "zero")) {
    fc <- s3_fit(d, "chain", dr)
    expect_gt(as.numeric(logLik(fs)) - as.numeric(logLik(fc)), 1)
  }
  fz <- s3_fit(d, "saturated", "zero")
  expect_lt(as.numeric(logLik(fz)), as.numeric(logLik(fs)))
})

test_that("the chain's likelihood-ratio statistic against the saturated fit equals lavaan's model test (df 2 and 3)", {
  skip_if_not_installed("lavaan")
  for (kind in c("complete", "mar")) {
    for (dr in c("free", "zero")) {
      d <- s3_data(kind, cp = if (dr == "free") s3_truth[["cp"]] else 0, a2 = .5, b1 = .4)
      fc <- s3_fit(d, "chain", dr)
      fs <- s3_fit(d, "saturated", "free")
      ref <- s3_reference(d, "chain", dr)
      expect_identical(as.integer(ref$df), if (dr == "free") 2L else 3L)
      expect_identical(length(fs@theta) - length(fc@theta), as.integer(ref$df))
      expect_lt(abs(2 * (as.numeric(logLik(fs)) - as.numeric(logLik(fc))) - ref$chisq), 1e-4, label = paste(kind, dr))
    }
  }
})

# ---- V6: rowwise likelihood and independent Hessian --------------------------------------------------------------------

test_that("the objective is the rowwise likelihood and the covariance inverts an independent Hessian (two cells per variant)", {
  for (v in c("saturated", "chain")) {
    for (cell in list(c("mar", "free"), c("sparse", "zero"))) {
      kind <- cell[1L]
      dr <- cell[2L]
      d <- s3_data(kind, cp = if (dr == "free") s3_truth[["cp"]] else 0)
      f <- s3_fit(d, v, dr)
      q <- coef(f)
      keep <- d[rowSums(!is.na(d)) > 0L, ]
      nll <- function(x) s3_nll(keep, stats::setNames(x, names(q)))
      expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
      H <- numDeriv::hessian(nll, q)
      expect_lt(sb_rel_gap(solve(H), vcov(f)), 1e-3, label = paste(v, kind, dr))
    }
  }
})

# ---- V7: OpenMx, one cell per variant ------------------------------------------------------------------------------------

test_that("OpenMx raw-data FIML agrees on the free-direct MAR cell of each variant", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  for (v in c("saturated", "chain")) {
    d <- s3_data("mar")
    f <- s3_fit(d, v, "free")
    q <- coef(f)
    vars <- c("X", "Z", "M1", "M2", "Y")
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
      list("s3", type = "RAM", manifestVars = vars), unname(paths),
      list(OpenMx::mxData(d[rowSums(!is.na(d)) > 0L, vars], type = "raw"))
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

# ---- extraction -------------------------------------------------------------------------------------------------------

test_that("extraction keeps the variant's aliases, takes them from the treatment, and records the covariate", {
  for (v in c("saturated", "chain")) {
    o <- s3_obj(v, "free", "mar")
    z <- o$z
    q <- coef(o$f)
    expect_s3_class(z, "medfit::FIMLSerialMediationData")
    expect_identical(z@variant, v)
    expect_identical(z@treatment, "X")
    expect_identical(z@fit_context$covariate, "Z")
    expect_identical(z@fit_context$variables[["X"]], "X")
    sat <- v == "saturated"
    alias <- if (sat) c("a", "a2", "d1", "b1", "b", "c_prime") else c("a", "d1", "b", "c_prime")
    expect_identical(names(z@estimates), alias)
    src <- if (sat) c("M1~X", "M2~X", "M2~M1", "Y~M1", "Y~M2", "Y~X") else c("M1~X", "M2~M1", "Y~M2", "Y~X")
    # the treatment's coefficients, not the covariate's (the covariate effects 1.4, -0.9 and 1.7 differ from the paths)
    expect_equal(unname(z@estimates), unname(q[src]), tolerance = 1e-12)
    expect_false(any(abs(z@estimates - 1.4) < .2) && any(abs(z@estimates - 1.7) < .2))
    idx <- match(src, names(q))
    expect_equal(unname(z@vcov), unname(vcov(o$f)[idx, idx]), tolerance = 1e-12)
    expect_equal(z@a_path, q[["M1~X"]])
    expect_equal(z@d_path, q[["M2~M1"]])
    expect_equal(z@b_path, q[["Y~M2"]])
    expect_equal(z@c_prime, q[["Y~X"]])
    expect_equal(z@sigma_mediators, sqrt(unname(q[c("M1~~M1", "M2~~M2")])), tolerance = 1e-12)
    expect_equal(z@sigma_y, sqrt(q[["Y~~Y"]]), tolerance = 1e-12)
    expect_setequal(z@mediator_predictors[[1L]], c("X", "Z"))
    expect_setequal(z@mediator_predictors[[2L]], c("M1", if (sat) "X", "Z"))
    expect_setequal(z@outcome_predictors, c(if (sat) "M1", "M2", "X", "Z"))
    expect_identical(z@n_obs, nobs(o$f))
    expect_false(is.na(as.numeric(te(z))))
  }
})

test_that("incomplete data: the cross-equation blocks of the extracted covariance are not zero", {
  for (v in c("saturated", "chain")) {
    z <- s3_obj(v, "free", "mar")$z
    expect_gt(abs(z@vcov["a", "d1"]) + abs(z@vcov["a", "b"]) + abs(z@vcov["d1", "b"]), 1e-8)
  }
})

test_that("a fixed-zero direct path is a zero row and column and the same object class, in both variants", {
  for (v in c("saturated", "chain")) {
    z <- s3_obj(v, "zero", "mar")$z
    expect_identical(z@c_prime, 0)
    expect_true(all(z@vcov["c_prime", ] == 0) && all(z@vcov[, "c_prime"] == 0))
    expect_identical(z@fit_context$covariate, "Z")
    expect_setequal(z@outcome_predictors, c(if (v == "saturated") "M1", "M2", "X", "Z"))
  }
})

test_that("hand delta-method SEs from the extracted covariance equal tidy() to 1e-12, with the covariate in the fit", {
  for (i in seq_len(nrow(s3_cells))) {
    v <- s3_cells$variant[i]
    dr <- s3_cells$direct[i]
    z <- s3_obj(v, dr, "mar")$z
    g <- s3_grad(z)
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
    z <- s3_obj(v, "free", "mar")$z
    alias <- names(z@estimates)
    tp <- generics::tidy(z, type = "paths", conf_int = TRUE)
    expect_identical(nrow(tp), length(alias))
    expect_lt(max(abs(tp$std_error - sqrt(diag(z@vcov)[alias]))), 1e-12)
    ci <- confint(z, parm = "paths")
    expect_identical(nrow(ci), length(alias))
    expect_lt(max(abs((ci[, 2L] - ci[, 1L]) / 2 / stats::qnorm(.975) - sqrt(diag(z@vcov)[alias]))), 1e-10)
    expect_identical(names(coef(z, type = "paths")), if (v == "saturated") c("a", "a2", "d", "b1", "b", "c_prime") else
      c("a", "d", "b", "c_prime"))
    ce <- confint(z, parm = "effects")
    expect_identical(rownames(ce), c("nie", "nie_total", "nde", "te"))
  }
})

test_that("printing and summarizing the extracted objects with a covariate do not fail", {
  for (v in c("saturated", "chain")) {
    z <- s3_obj(v, "free", "mar")$z
    expect_no_error(utils::capture.output(print(z)))
    expect_no_error(utils::capture.output(print(summary(z))))
  }
})

# ---- the treatment rule (Q6 and Q6a) ------------------------------------------------------------------------------------

test_that("saturated: a covariate may be the treatment and takes a = gm1, a2 = gm2, c_prime = gy (lavaan, relabeled)", {
  skip_if_not_installed("lavaan")
  for (kind in c("mar", "sparse")) {
    d <- s3_data(kind)
    f <- s3_fit(d, "saturated", "free")
    zt <- s3_extract(f, treatment = "Z")
    q <- coef(f)
    expect_identical(zt@treatment, "Z")
    expect_identical(zt@fit_context$variables[["X"]], "Z")
    expect_identical(zt@fit_context$covariate, "X")
    expect_equal(unname(zt@estimates), unname(q[c("M1~Z", "M2~Z", "M2~M1", "Y~M1", "Y~M2", "Y~Z")]), tolerance = 1e-12)
    ref <- s3_reference(d, "saturated", "free", tr = "Z", cv = "X")
    roles <- names(ref$est)
    expect_lt(max(abs(zt@estimates[roles] - ref$est)), 1e-5)
    expect_lt(sb_rel_gap(zt@vcov[roles, roles], ref$vcov), 2e-3)
    tb <- suppressWarnings(generics::tidy(zt, type = "effects"))
    se <- stats::setNames(tb$std_error, tb$term)
    expect_lt(abs(se[["nie_total"]] - ref$ind_tot$se) / ref$ind_tot$se, 3e-3)
    expect_lt(abs(se[["te"]] - ref$te$se) / ref$te$se, 3e-3)
    # the effects of the two treatments differ: the covariate coefficients are not those of X
    expect_gt(abs(zt@a_path - s3_extract(f, treatment = "X")@a_path), .1)
    expect_setequal(zt@mediator_predictors[[1L]], c("X", "Z"))
    expect_setequal(zt@outcome_predictors, c("M1", "M2", "X", "Z"))
  }
})

test_that("saturated: a fixed-zero Y path on Z makes Z the treatment, and X is then refused", {
  d <- s3_data("mar", cp = 0)
  m <- "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + 0*Z"
  f <- fit_sem(paste(m, paste(s3_zeros, collapse = "\n"), sep = "\n"), d, missing = "fiml", fixed_x = FALSE)
  expect_identical(length(f@theta), 19L)
  expect_identical(f@internals$likelihood$variables[["X"]], "Z")
  z <- s3_extract(f, treatment = "Z")
  expect_identical(z@treatment, "Z")
  expect_identical(z@c_prime, 0)
  expect_identical(z@fit_context$covariate, "X")
  expect_s3_class(tryCatch(s3_extract(f, treatment = "X"), error = identity), "medfit_error_fiml_extract_unsupported")
  # with the fixed zero on X (the usual case) a covariate cannot be the treatment either
  f0 <- s3_fit(d, "saturated", "zero")
  expect_s3_class(tryCatch(s3_extract(f0, treatment = "Z"), error = identity), "medfit_error_fiml_extract_unsupported")
})

test_that("chain: the treatment is structural, and naming a covariate is refused (Q6a)", {
  for (dr in c("free", "zero")) {
    f <- s3_obj("chain", dr, "mar")$f
    e <- tryCatch(s3_extract(f, treatment = "Z"), error = identity)
    expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
    expect_match(conditionMessage(e), "structural|covariate", info = dr)
    expect_s3_class(s3_extract(f, treatment = "X"), "medfit::FIMLSerialMediationData")
  }
})

test_that("chain: the variable absent from M2 is the treatment whatever its name; the other is then the covariate", {
  d <- s3_data("mar")
  # Z is absent from M2's equation: it is the chain's treatment and X the covariate
  m <- s3_model("chain", "free", tr = "Z", cv = "X")
  f <- fit_sem(m, d, missing = "fiml", fixed_x = FALSE)
  expect_identical(f@internals$likelihood$variables[["X"]], "Z")
  expect_identical(f@internals$likelihood$covariate, "X")
  expect_identical(length(f@theta), 18L)
  z <- s3_extract(f, treatment = "Z")
  expect_identical(z@treatment, "Z")
  expect_identical(z@variant, "chain")
  q <- coef(f)
  expect_equal(unname(z@estimates), unname(q[c("M1~Z", "M2~M1", "Y~M2", "Y~Z")]), tolerance = 1e-12)
  expect_s3_class(tryCatch(s3_extract(f, treatment = "X"), error = identity), "medfit_error_fiml_extract_unsupported")
  skip_if_not_installed("lavaan")
  ref <- s3_reference(d, "chain", "free", tr = "Z", cv = "X")
  expect_lt(max(abs(z@estimates[names(ref$est)] - ref$est)), 1e-5)
})

# ---- extraction refusals ----------------------------------------------------------------------------------------------

test_that("extraction refuses the reversed mediators, a covariate as mediator, standardized and unknown arguments", {
  f <- s3_obj("saturated", "free", "mar")$f
  cls <- "medfit_error_fiml_extract_unsupported"
  expect_s3_class(tryCatch(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")), error = identity), cls)
  expect_s3_class(tryCatch(extract_mediation(f, treatment = "X", mediator = c("M1", "Z")), error = identity), cls)
  expect_s3_class(tryCatch(extract_mediation(f, treatment = "X", mediator = "M1"), error = identity), cls)
  expect_s3_class(tryCatch(s3_extract(f, standardized = TRUE), error = identity), cls)
  expect_s3_class(tryCatch(s3_extract(f, structure = "parallel"), error = identity), cls)
  expect_s3_class(tryCatch(s3_extract(f, bogus = 1), error = identity), cls)
  expect_s3_class(tryCatch(s3_extract(f, treatment = "W"), error = identity), cls)
  expect_s3_class(s3_extract(f, structure = "serial"), "medfit::FIMLSerialMediationData")
})

test_that("k = 2 extraction stays refused for a mock-opened fit, both variants", {
  d <- s3_data("complete")
  d$Z1 <- d$Z
  d$Z2 <- d$X - d$Z
  testthat::local_mocked_bindings(.fiml_serial_admitted = function() TRUE)
  for (v in c("saturated", "chain")) {
    sat <- v == "saturated"
    m <- paste(c(
      "M1 ~ X + Z1 + Z2", paste("M2 ~ M1 +", if (sat) "X + " else "", "Z1 + Z2"),
      paste("Y ~", if (sat) "M1 + " else "", "M2 + X + Z1 + Z2"), s3_zeros
    ), collapse = "\n")
    f <- fit_sem(m, d, missing = "fiml", fixed_x = FALSE)
    e <- tryCatch(s3_extract(f), error = identity)
    expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
    expect_match(conditionMessage(e), "not yet available", info = v)
  }
})

# ---- the validator ------------------------------------------------------------------------------------------------------

test_that("the validator rejects forgeries with a covariate: dropped from an equation, on some equations only, wrong treatment", {
  forge <- function(z, ...) {
    for (nm in names(list(...))) attr(z, nm) <- list(...)[[nm]]
    z
  }
  valid <- function(z) is.null(FIMLSerialMediationData@validator(z))
  for (v in c("saturated", "chain")) {
    z <- s3_obj(v, "free", "mar")$z
    expect_true(valid(z), info = v)
    sat <- v == "saturated"
    bad <- list(
      z_dropped_m1 = forge(z, mediator_predictors = list("X", z@mediator_predictors[[2L]])),
      z_dropped_m2 = forge(z, mediator_predictors = list(z@mediator_predictors[[1L]], setdiff(z@mediator_predictors[[2L]], "Z"))),
      z_dropped_y = forge(z, outcome_predictors = setdiff(z@outcome_predictors, "Z")),
      z_on_y_only = forge(z, mediator_predictors = list("X", setdiff(z@mediator_predictors[[2L]], "Z"))),
      z_extra_in_m1_only_listing = forge(z, mediator_predictors = list(c("X", "Z", "M2"), z@mediator_predictors[[2L]])),
      covariate_forgotten = forge(z, fit_context = replace(z@fit_context, "covariate", list(NULL))),
      wrong_treatment = forge(z, treatment = "Z")
    )
    for (nm in names(bad)) expect_false(valid(bad[[nm]]), info = paste(v, nm))
    expect_true(valid(forge(z, mediator_predictors = rev(z@mediator_predictors)[c(2L, 1L)])), info = v)
    if (!sat) {
      expect_false(valid(forge(z, mediator_predictors = list(c("X", "Z"), c("M1", "X", "Z")))), info = v)
    }
  }
})

# ---- consumers ---------------------------------------------------------------------------------------------------------

test_that("the consumers refuse the k = 1 serial fit and its extracted object as for every FIML fit", {
  for (v in c("saturated", "chain")) {
    o <- s3_obj(v, "free", "mar")
    expect_error(pm(o$z), "not supported for bounded FIML objects")
    expect_error(quick(o$z), "not supported for bounded FIML objects")
    expect_error(generics::glance(o$z), "not supported for bounded FIML objects")
    expect_error(confint(o$z, method = "boot"), "not supported for bounded FIML objects")
    expect_error(bootstrap_mediation(function(x) 1, mediation_data = o$z), "FIML")
  }
})

test_that("source-fit inference: the stage-0 guard answers first, then the serial class at k = 1, before any RNG or refit", {
  fx_skip_covr()
  refit_calls <- 0L
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    refit_calls <<- refit_calls + 1L
    stop("refit reached")
  })
  fits <- lapply(c("saturated", "chain"), function(v) s3_obj(v, "free", "mar")$f)
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

test_that("other consumers of the k = 1 fit refuse it as for every FIML fit", {
  f <- s3_obj("saturated", "free", "mar")$f
  expect_error(mbco_sem(f, a = "M1~X", b = "Y~M2"), "FIML")
  expect_error(compare_lr(f, paths = c("M1~X", "Y~M2")), "FIML")
  expect_error(anova(f, f), "FIML")
  expect_identical(generics::glance(f)$npar, 20L)
})

# ---- what stays refused at fit -----------------------------------------------------------------------------------------

s3_refused <- c(
  omitted_zero_m1m2 = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  omitted_zero_m1y = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM2 ~~ 0*Y",
  omitted_zero_m2y = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y",
  free_residual = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ Y",
  covariate_on_m1_only = "M1 ~ X + Z\nM2 ~ M1 + X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  covariate_not_on_m2 = "M1 ~ X + Z\nM2 ~ M1 + X\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  covariate_not_on_y = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  covariate_not_on_m1 = "M1 ~ X\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  omitted_y_path_x = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  omitted_y_path_chain = "M1 ~ X + Z\nM2 ~ M1 + Z\nY ~ M2 + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  both_y_fixed = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + 0*X + 0*Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  fixed_covariate_to_m = "M1 ~ X + 0*Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  fixed_nonzero_direct = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + .5*X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  labeled_a2 = "M1 ~ X + Z\nM2 ~ M1 + a2*X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  fixed_b1 = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ 0*M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  tied_covariate_paths = "M1 ~ X + p*Z\nM2 ~ M1 + X + p*Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  fixed_exo_cov = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y\nX ~~ 0*Z",
  partial_shortcut_x_only = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  partial_shortcut_b1_only = "M1 ~ X + Z\nM2 ~ M1 + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  chain_both_absent = "M1 ~ X + Z\nM2 ~ M1\nY ~ M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y",
  mediator_exo_cov = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y\nM1 ~~ Z",
  interaction = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z + M1:X\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y"
)

test_that("every other k = 1 serial syntax is refused at fit with a classed reason", {
  d <- s3_data("complete")
  d$W <- d$Z
  for (nm in names(s3_refused)) {
    e <- tryCatch(fit_sem(s3_refused[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
  }
})

test_that("the tied-shortcut and the written exogenous-covariance forms behave as specified", {
  d <- s3_data("mar")
  # the exogenous covariance written (either order) is the same model as the omitted one
  f0 <- s3_fit(d, "saturated", "free")
  fz <- s3_fit(d, model = s3_model("saturated", "free", exo_cov = TRUE))
  expect_equal(coef(fz), coef(f0), tolerance = 1e-8)
  fr <- s3_fit(d, model = sub("X ~~ Z", "Z ~~ X", s3_model("chain", "free", exo_cov = TRUE), fixed = TRUE),
               variant = "chain")
  expect_equal(coef(fr), coef(s3_fit(d, "chain", "free")), tolerance = 1e-8)
  # a labeled free exogenous covariance is a different (tied) statement and not admitted as a path
  e <- tryCatch(s3_fit(d, model = paste0(s3_model("saturated", "free"), "\nX ~~ c*Z\nX ~~ c*X")), error = identity)
  expect_s3_class(e, "medfit_sem_fiml_error")
})

# ---- frozen fixtures --------------------------------------------------------------------------------------------------

test_that("the new k = 1 tables are frozen with identical() for S4, and the refusal dump pins the entries that became fits", {
  tb <- readRDS(test_path("fixtures", "fiml-tables-after-g3s3.rds"))
  expect_length(tb, 4L)
  for (sc in c(TRUE, FALSE)) for (dr in c(TRUE, FALSE)) {
    nm <- paste0(if (sc) "sat1" else "chain1", if (dr) "free" else "fixed")
    expect_identical(.sem_fiml_tables_ser(dr, 1L, sc), tb[[nm]], info = nm)
    expect_identical(nrow(tb[[nm]]$a) + nrow(tb[[nm]]$s) + nrow(tb[[nm]]$m) - sum(!is.na(tb[[nm]]$a$value)),
                     (if (sc) 20L else 18L) - !dr, info = nm)
  }
  b2 <- readRDS(test_path("fixtures", "fiml-refusals-after-g3s2.rds"))
  b3 <- readRDS(test_path("fixtures", "fiml-refusals-after-g3s3.rds"))
  expect_identical(b3$models, b2$models)
  changed <- c("ser_sat1_zeros", "ser_chain1_zeros", "ser_chain_z_omitted", "ser_partial_exo_cov_sat1")
  for (nm in names(b3$models)) {
    got <- b0_observe(b3$models[[nm]], b3$data)
    expect_identical(got$class, b3$results[[nm]]$class, info = nm)
    expect_identical(got$message, b3$results[[nm]]$message, info = nm)
    if (nm %in% changed) {
      expect_identical(b3$results[[nm]]$class, "<fit>", info = nm)
      expect_match(b2$results[[nm]]$message, "serial FIML is not yet available", info = nm)
    } else {
      expect_identical(b3$results[[nm]], b2$results[[nm]], info = nm)
    }
  }
  # the k = 2 entries keep the not-yet-available reason
  expect_match(b3$results[["ser_sat2_zeros"]]$message, "not yet available")
  expect_match(b3$results[["ser_chain2_zeros"]]$message, "not yet available")
  expect_match(b3$results[["ser_all_exo_cov_sat2"]]$message, "not yet available")
})
