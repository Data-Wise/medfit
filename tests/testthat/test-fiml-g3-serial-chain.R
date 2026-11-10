# FI-G3 slice S2: the PURE CHAIN with no covariates (X -> M1 -> M2 -> Y; X -> M2 and M1 -> Y absent, a structural zero;
# independent disturbances written as zero covariances; the direct path free, fixed at exactly zero or omitted). The
# chain is overidentified (q = 12 free direct / 11 fixed against 14 moments: df 2 / 3), so unlike the saturated variant
# its likelihood is a real restriction and the saturation identity does not apply (V16). Oracles, each independent of
# the production kernel and adapter: matched lavaan raw-data FIML (estimates, covariance, logLik, the defined effects),
# equation-wise ML OLS on complete data with a block-diagonal covariance, a from-scratch rowwise likelihood with an
# independent Hessian, OpenMx for one cell, hand delta gradients, the lavaan chi-square for the restriction against
# the saturated fit. Helpers are in helper-fiml-serial.R (sb_*) and helper-fiml-serial2-chain.R (sc_*).

sc_kinds <- c("mar", "mcar30", "sparse", "complete")
sc_directs <- c("free", "zero", "omit")
sc_note_total <- "NIE total inference unavailable: zero delta gradient"
sc_tidy <- function(z, ...) suppressWarnings(generics::tidy(z, ...))
sc_ci <- function(z, ...) suppressWarnings(confint(z, ...))

# ---- what is public ---------------------------------------------------------------------------------------------
test_that("the chain syntax with k = 0 is a public fit in every direct policy, with 12 / 11 free parameters", {
  d <- sc_data("mar")
  for (dr in sc_directs) {
    f <- sc_fit(d, dr)
    expect_s7_class(f, SEMFit)
    expect_true(.sem_fiml_is(f))
    ll <- f@internals$likelihood
    expect_identical(ll$structure, "serial")
    expect_identical(ll$variant, "chain")
    expect_identical(unname(ll$mediators), c("M1", "M2"))
    expect_length(f@theta, if (dr == "free") 12L else 11L)
    expect_false(any(c("M2~X", "Y~M1") %in% names(coef(f))))
    expect_identical(f@diagnostics$ledger$schema, "fiml-1")
    expect_true(f@converged)
  }
  # an omitted direct path is the fixed-zero policy (Q3): the same fit
  expect_identical(sc_fit(d, "zero")@theta, sc_fit(d, "omit")@theta)
  expect_identical(sc_fit(d, "zero")@vcov, sc_fit(d, "omit")@vcov)
  # the two residual-zero orders per pair are the same model
  rev <- c("M2 ~~ 0*M1", "Y ~~ 0*M1", "Y ~~ 0*M2")
  expect_identical(sc_fit(d, model = sc_model("free", zeros = rev))@theta, sc_fit(d)@theta)
})

test_that("the k = 2 serial shapes are public fits since slice S4 (R4)", {
  d <- sc_data("mar")
  d$Z <- d$Z1 <- stats::rnorm(nrow(d))
  d$Z2 <- stats::rnorm(nrow(d))
  z <- paste(sc_zeros, collapse = "\n")
  shapes <- c(
    sat2 = "M1 ~ X + Z1 + Z2\nM2 ~ M1 + X + Z1 + Z2\nY ~ M1 + M2 + X + Z1 + Z2",
    chain2 = "M1 ~ X + Z1 + Z2\nM2 ~ M1 + Z1 + Z2\nY ~ M2 + X + Z1 + Z2"
  )
  for (nm in names(shapes)) {
    expect_s7_class(fit_sem(paste(shapes[[nm]], z, sep = "\n"), d, missing = "fiml", fixed_x = FALSE), SEMFit)
  }
})

test_that("a half shortcut at k = 0 is refused as a partial set, a fixed or labeled shortcut as not free-or-absent", {
  d <- sc_data("mar")
  z <- paste(sc_zeros, collapse = "\n")
  one <- function(m) tryCatch(fit_sem(paste(m, z, sep = "\n"), d, missing = "fiml", fixed_x = FALSE), error = identity)
  half <- c(a2_only = "M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + X", b1_only = "M1 ~ X\nM2 ~ M1\nY ~ M1 + M2 + X",
            a2_only_zero = "M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + 0*X", b1_only_omit = "M1 ~ X\nM2 ~ M1\nY ~ M1 + M2")
  for (nm in names(half)) {
    e <- one(half[[nm]])
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_match(conditionMessage(e), "both shortcut paths", info = nm)
    expect_false(grepl("not yet available", conditionMessage(e)), info = nm)
  }
  fixed <- c(zero_shortcut = "M1 ~ X\nM2 ~ M1 + 0*X\nY ~ M2 + X", labeled = "M1 ~ X\nM2 ~ M1 + w*X\nY ~ M2 + X",
             fixed_b1 = "M1 ~ X\nM2 ~ M1\nY ~ 0*M1 + M2 + X")
  for (nm in names(fixed)) {
    e <- one(fixed[[nm]])
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_match(conditionMessage(e), "free or absent", info = nm)
  }
  # the router detects the chain at k = 0 from the equations: X absent from M2's equation and M1 absent from Y's
  spec <- .sem_fiml_model(paste("M1 ~ X\nM2 ~ M1\nY ~ M2 + X", z, sep = "\n"))
  expect_identical(spec$variant, "chain")
  spec <- .sem_fiml_model(paste("M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X", z, sep = "\n"))
  expect_identical(spec$variant, "saturated")
})

test_that("the admission predicates: the chain joins the saturated variant at k = 0, 1 and 2 and nothing else", {
  for (v in c("saturated", "chain")) {
    expect_true(.fiml_serial_shape_admitted(v, 0L))
    expect_true(.fiml_serial_extract_supported(v, 0L))
    # slice S3 opened k = 1 and slice S4 k = 2 for both variants; a third covariate stays closed
    expect_true(.fiml_serial_shape_admitted(v, 1L))
    expect_true(.fiml_serial_extract_supported(v, 1L))
    expect_true(.fiml_serial_shape_admitted(v, 2L))
    expect_true(.fiml_serial_extract_supported(v, 2L))
    expect_false(.fiml_serial_shape_admitted(v, 3L))
    expect_false(.fiml_serial_extract_supported(v, 3L))
  }
  expect_false(.fiml_serial_shape_admitted("bogus", 0L))
  testthat::local_mocked_bindings(.fiml_serial_admitted = function() TRUE)
  for (k in 0:3) for (v in c("saturated", "chain")) expect_true(.fiml_serial_shape_admitted(v, k))
})

# ---- V1/V2: lavaan raw-data FIML -----------------------------------------------------------------------------------
test_that("estimates, covariance and logLik agree with lavaan raw-data FIML in every cell", {
  skip_if_not_installed("lavaan")
  for (kind in sc_kinds) for (dr in sc_directs) {
    d <- sc_data(kind, cp = if (dr == "free") .25 else 0)
    f <- sc_fit(d, dr)
    ref <- sb_lavaan(sc_model(dr), d)
    q <- coef(f)
    info <- paste(kind, dr)
    expect_lt(max(abs(q - sb_align(lavaan::coef(ref), q))), 1e-5, label = info)
    idx <- match(sb_key(names(q)), sb_key(names(lavaan::coef(ref))))
    expect_lt(sb_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3, label = info)
    expect_lt(abs(as.numeric(logLik(f)) - as.numeric(lavaan::logLik(ref))), 1e-6, label = info)
    expect_identical(nobs(f), nrow(d) - sum(rowSums(!is.na(d)) == 0L))
  }
})

test_that("the sparse mask has all-incomplete patterns and an all-NA row that is dropped", {
  f <- sc_fit(sc_data("sparse"))
  expect_identical(f@n_dropped, 1L)
  expect_gte(length(f@internals$likelihood$rows$patterns), 8L)
})

test_that("the extracted paths, effects and effect SEs equal the lavaan := values (te := ind for a zero direct path)", {
  skip_if_not_installed("lavaan")
  for (kind in sc_kinds) for (dr in c("free", "zero")) {
    d <- sc_data(kind, cp = if (dr == "free") .25 else 0)
    z <- sb_extract(sc_fit(d, dr))
    r <- sc_reference(d, dr)
    info <- paste(kind, dr)
    expect_lt(max(abs(z@estimates[names(r$est)] - r$est)), 1e-5, label = info)
    expect_lt(sb_rel_gap(z@vcov[names(r$est), names(r$est)], r$vcov), 1e-3, label = info)
    tb <- generics::tidy(z, type = "effects")
    est <- stats::setNames(tb$estimate, tb$term)
    se <- stats::setNames(tb$std_error, tb$term)
    expect_lt(abs(est[["nie"]] - r$ind$est), 1e-5, label = info)
    expect_lt(abs(est[["nie_total"]] - r$ind$est), 1e-5, label = info) # nie_total is compared to ind
    expect_lt(abs(est[["te"]] - r$te$est), 1e-5, label = info)
    expect_lt(abs(se[["nie"]] - r$ind$se) / r$ind$se, 2e-3, label = info)
    expect_lt(abs(se[["nie_total"]] - r$ind$se) / r$ind$se, 2e-3, label = info)
    expect_lt(abs(se[["te"]] - r$te$se) / r$te$se, 2e-3, label = info)
  }
})

# ---- V3: complete-data neutrality ----------------------------------------------------------------------------------
test_that("complete data: equation-wise ML OLS (no X in M2, no M1 in Y), covariance block diagonal across equations", {
  for (dr in sc_directs) {
    d <- sc_data("complete", cp = if (dr == "free") .25 else 0)
    f <- sc_fit(d, dr)
    q <- coef(f)
    n <- nrow(d)
    l1 <- stats::lm(M1 ~ X, d)
    l2 <- stats::lm(M2 ~ M1, d)
    ly <- stats::lm(if (dr == "free") Y ~ M2 + X else Y ~ M2, d)
    expect_equal(q[["M1~X"]], stats::coef(l1)[["X"]], tolerance = 1e-7)
    expect_equal(q[["M2~M1"]], stats::coef(l2)[["M1"]], tolerance = 1e-7)
    for (v in names(stats::coef(ly))[-1L]) expect_equal(q[[paste0("Y~", v)]], stats::coef(ly)[[v]], tolerance = 1e-7)
    expect_equal(q[["M1~~M1"]], sum(stats::resid(l1)^2) / n, tolerance = 1e-7)
    expect_equal(q[["M2~~M2"]], sum(stats::resid(l2)^2) / n, tolerance = 1e-7)
    expect_equal(q[["Y~~Y"]], sum(stats::resid(ly)^2) / n, tolerance = 1e-7)
    V <- vcov(f)
    blocks <- list(
      m1 = c("M1~1", "M1~X"), m2 = c("M2~1", "M2~M1"), y = c("Y~1", paste0("Y~", names(stats::coef(ly))[-1L]))
    )
    for (nm in names(blocks)) {
      fit <- list(m1 = l1, m2 = l2, y = ly)[[nm]]
      w <- stats::model.matrix(fit)
      ref <- sum(stats::resid(fit)^2) / n * solve(crossprod(w))
      lhs <- c(m1 = "M1", m2 = "M2", y = "Y")[[nm]]
      cn <- colnames(w)
      cn[cn == "(Intercept)"] <- "1"
      dimnames(ref) <- list(paste0(lhs, "~", cn), paste0(lhs, "~", cn))
      expect_equal(V[rownames(ref), colnames(ref)], ref, tolerance = 1e-6, ignore_attr = TRUE)
    }
    for (i in 1:2) for (j in (i + 1L):3) expect_lt(max(abs(V[blocks[[i]], blocks[[j]]])), 1e-9)
    # the extracted block: a, d1, b sit in three equations (exactly uncorrelated); b and c_prime share the Y equation
    z <- sb_extract(f)
    expect_lt(abs(z@vcov["a", "d1"]) + abs(z@vcov["a", "b"]) + abs(z@vcov["d1", "b"]), 1e-9)
    if (dr == "free") expect_gt(abs(z@vcov["b", "c_prime"]), 0)
  }
})

test_that("incomplete data: the cross-equation covariance blocks are not zero", {
  z <- sc_obj()
  expect_gt(abs(z@vcov["a", "d1"]) + abs(z@vcov["a", "b"]) + abs(z@vcov["d1", "b"]), 1e-8)
})

# ---- V6: rowwise likelihood and independent Hessian ----------------------------------------------------------------
test_that("the objective is the rowwise likelihood and the covariance inverts an independent Hessian", {
  for (kind in c("mar", "sparse")) for (dr in c("free", "zero")) {
    d <- sc_data(kind, cp = if (dr == "free") .25 else 0)
    f <- sc_fit(d, dr)
    q <- coef(f)
    keep <- d[rowSums(!is.na(d)) > 0L, ]
    nll <- function(x) sb_nll(keep, stats::setNames(x, names(q)))
    expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
    h <- 1e-5
    grad <- vapply(seq_along(q), function(j) {
      e <- q * 0
      e[j] <- h * max(1, abs(q[j]))
      (nll(q + e) - nll(q - e)) / (2 * e[j])
    }, numeric(1))
    expect_lt(max(abs(grad)), 1e-3)
    H <- numDeriv::hessian(nll, q)
    expect_lt(max(abs(solve(H) - vcov(f)) / sqrt(outer(diag(vcov(f)), diag(vcov(f))))), 1e-3)
  }
})

# ---- V7: OpenMx, one cell ------------------------------------------------------------------------------------------
test_that("OpenMx raw-data FIML agrees on the free-direct MAR cell of the chain", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  d <- sc_data("mar")
  f <- sc_fit(d)
  q <- coef(f)
  vars <- c("X", "M1", "M2", "Y")
  lab <- function(nm) gsub("~", "_", nm, fixed = TRUE)
  paths <- list()
  for (nm in names(q)) {
    if (grepl("~1$", nm)) {
      paths[[nm]] <- OpenMx::mxPath(from = "one", to = sub("~1$", "", nm), arrow = 1, free = TRUE, values = 0,
                                    labels = lab(nm))
    } else if (grepl("~~", nm)) {
      p <- strsplit(nm, "~~", fixed = TRUE)[[1L]]
      paths[[nm]] <- OpenMx::mxPath(from = p[1L], arrow = 2, free = TRUE, values = 1, labels = lab(nm))
    } else {
      p <- strsplit(nm, "~", fixed = TRUE)[[1L]]
      paths[[nm]] <- OpenMx::mxPath(from = p[2L], to = p[1L], arrow = 1, free = TRUE, values = .1, labels = lab(nm))
    }
  }
  mx <- do.call(OpenMx::mxModel, c(
    list("sc", type = "RAM", manifestVars = vars), unname(paths),
    list(OpenMx::mxData(d[rowSums(!is.na(d)) > 0L, vars], type = "raw"))
  ))
  fit <- suppressWarnings(OpenMx::mxTryHard(mx, silent = TRUE, extraTries = 5L))
  expect_true(fit$output$status$code %in% c(0, 1))
  pars <- fit$output$estimate
  expect_lt(max(abs(pars[lab(names(q))] - q)), 5e-4)
  expect_lt(abs(fit$output$Minus2LogLikelihood / 2 - f@internals$likelihood$nll), 1e-5)
  se <- fit$output$standardErrors
  expect_equal(unname(se[lab(names(q)), 1L]), unname(sqrt(diag(vcov(f)))), tolerance = 5e-3)
})

# ---- V16: the chain is a restriction the data can reject ---------------------------------------------------------
test_that("V16: LR against the saturated fit equals the lavaan chi-square; df 2 free / 3 fixed from q and moments", {
  skip_if_not_installed("lavaan")
  for (kind in c("mar", "mcar30", "complete")) {
    for (dr in c("free", "zero")) {
      d <- sc_data(kind, cp = if (dr == "free") .25 else 0, a2 = .3, b1 = .25)
      chain <- sc_fit(d, dr)
      sat <- sc_sat_fit(d, "free")
      ref <- sb_lavaan(sc_model(dr), d)
      df <- 14L - length(chain@theta)
      info <- paste(kind, dr)
      expect_identical(df, if (dr == "free") 2L else 3L, info = info)
      expect_equal(unname(lavaan::fitMeasures(ref, "df")), df, info = info)
      lr <- 2 * (as.numeric(logLik(sat)) - as.numeric(logLik(chain)))
      expect_equal(lr, unname(lavaan::fitMeasures(ref, "chisq")), tolerance = 1e-5, info = info)
      expect_gt(lr, 0)
    }
  }
})

test_that("V16: nesting on a sparse mask, direct-path ordering, and a restriction the test can fail", {
  d <- sc_data("sparse")
  expect_lte(as.numeric(logLik(sc_fit(d))), as.numeric(logLik(sc_sat_fit(d))) + 1e-8)
  d <- sc_data("mar")
  expect_gte(as.numeric(logLik(sc_fit(d, "free"))), as.numeric(logLik(sc_fit(d, "zero"))) - 1e-8)
  lr <- function(a2, b1, seed = 41L) {
    dd <- sc_data("complete", n = 600L, seed = seed, a2 = a2, b1 = b1)
    2 * (as.numeric(logLik(sc_sat_fit(dd))) - as.numeric(logLik(sc_fit(dd))))
  }
  # a data-generating chain: the LR is a chi-square(2) draw; real shortcuts make it large (the test can fail)
  expect_lt(lr(0, 0), stats::qchisq(.999, 2))
  expect_gt(lr(.4, .3), stats::qchisq(.9999, 2))
  expect_gt(lr(.4, 0), stats::qchisq(.999, 2))
  expect_gt(lr(0, .4), stats::qchisq(.999, 2))
  # with no shortcut effect the chain and saturated estimates agree up to sampling error
  dd <- sc_data("complete", n = 4000L, seed = 5L)
  zc <- sb_extract(sc_fit(dd))
  zs <- sb_extract(sc_sat_fit(dd))
  expect_lt(max(abs(zc@estimates[c("a", "d1", "b", "c_prime")] - zs@estimates[c("a", "d1", "b", "c_prime")])), .08)
})

# ---- V10: identification -------------------------------------------------------------------------------------------
# Rows 1-60 lack the second variable of the pair and rows 61-120 the first, so the pair is never jointly observed. The
# chain restricts Cov(X, M2), Cov(M1, Y) and (fixed direct path) Cov(X, Y) through its structure, so it fits where the
# saturated variant fails closed; the cells that do fail must fail closed with a class, never as a silent fit.
sc_never_data <- function(pair, seed = 7701L) {
  set.seed(seed)
  n <- 120L
  d <- data.frame(X = stats::rnorm(n))
  d$M1 <- .6 * d$X + stats::rnorm(n)
  d$M2 <- .5 * d$M1 + stats::rnorm(n)
  d$Y <- .5 * d$M2 + .2 * d$X + stats::rnorm(n)
  d[1:60, pair[2L]] <- NA_real_
  d[61:120, pair[1L]] <- NA_real_
  d
}
sc_never <- function(pair, seed = 7701L, direct = "free") {
  tryCatch(sc_fit(sc_never_data(pair, seed), direct), error = identity)
}
test_that("V10: each never-jointly-observed pair is a finite fit or a classed numerical error, per direct policy", {
  out <- character()
  for (direct in c("free", "zero")) for (pair in utils::combn(c("X", "M1", "M2", "Y"), 2L, simplify = FALSE)) {
    e <- sc_never(pair, direct = direct)
    info <- paste(direct, paste(pair, collapse = ","))
    if (inherits(e, "error")) {
      expect_s3_class(e, "medfit_sem_fiml_error")
      expect_identical(e$stage, "numerical", info = info)
      out[info] <- "refused"
    } else {
      expect_true(all(is.finite(coef(e))) && all(is.finite(vcov(e))), info = info)
      out[info] <- "fit"
    }
  }
  # Observed 2026-11-09 (lavaan 0.7-3, this machine, seed 7701): with the direct path free every pair fits, because the
  # structural zeros pin Cov(X, M2), Cov(M1, Y) and Cov(X, Y) through the chain (the saturated variant refuses all six
  # pairs there, see test-fiml-g3-serial-saturated.R); with the direct path fixed only (X, M1) fails closed, with "no
  # accepted candidate". The refusals are numerical and seed dependent, so only the class and the contrast are pinned.
  expect_true(all(out[grepl("^free", names(out))] == "fit"))
  expect_gte(sum(out == "fit"), 10L)
})
# Added after the first full-suite run (review): a finite fit is not a correct one, and these cells are new numerical
# territory for the chain. Each fitted cell must agree with lavaan raw-data FIML wherever lavaan converges.
test_that("V10: every fitted never-jointly-observed cell agrees with lavaan where lavaan converges", {
  skip_if_not_installed("lavaan")
  compared <- 0L
  for (direct in c("free", "zero")) for (pair in utils::combn(c("X", "M1", "M2", "Y"), 2L, simplify = FALSE)) {
    d <- sc_never_data(pair)
    e <- sc_never(pair, direct = direct)
    if (inherits(e, "error")) next
    ref <- tryCatch(sb_lavaan(sc_model(direct), d), error = identity)
    if (inherits(ref, "error") || !isTRUE(lavaan::lavInspect(ref, "converged"))) next
    info <- paste(direct, paste(pair, collapse = ","))
    q <- coef(e)
    expect_lt(abs(as.numeric(logLik(e)) - as.numeric(lavaan::logLik(ref))), 1e-6, label = info)
    # Observed on 2026-11-09: the logLik gap is below 1e-8 in every cell and the largest estimate gap 1.4e-5 (a flat
    # likelihood with 120 rows and half of the rows missing a variable); the limit for the estimates is 5e-5 here, not
    # the 1e-5 of the regular cells
    expect_lt(max(abs(q - sb_align(lavaan::coef(ref), q))), 5e-5, label = info)
    compared <- compared + 1L
  }
  expect_gte(compared, 6L)
})
test_that("V10: a weak first stage and a near-deterministic M2 ~ M1 fit like lavaan or error with a class", {
  skip_if_not_installed("lavaan")
  for (seed in 1:3) {
    set.seed(seed)
    n <- 60L
    d <- data.frame(X = stats::rnorm(n))
    d$M1 <- .02 * d$X + stats::rnorm(n)
    d$M2 <- 1 * d$M1 + .01 * stats::rnorm(n)
    d$Y <- .5 * d$M2 + stats::rnorm(n)
    for (v in c("M1", "M2", "Y")) d[stats::runif(n) < .2, v] <- NA_real_
    e <- tryCatch(sc_fit(d), error = identity)
    if (inherits(e, "error")) {
      expect_s3_class(e, "medfit_sem_fiml_error")
    } else {
      ref <- tryCatch(sb_lavaan(sc_model(), d), error = identity)
      if (!inherits(ref, "error") && lavaan::lavInspect(ref, "converged")) {
        expect_lt(abs(as.numeric(logLik(e)) - as.numeric(lavaan::logLik(ref))), 1e-4, label = seed)
      }
    }
  }
})

# ---- extraction contract -------------------------------------------------------------------------------------------
test_that("extraction returns the serial FIML class with the four chain aliases and no a2 or b1 anywhere", {
  d <- sc_data("mar")
  f <- sc_fit(d)
  z <- sb_extract(f)
  expect_s3_class(z, "medfit::FIMLSerialMediationData")
  expect_true(S7::S7_inherits(z, SerialMediationData))
  expect_identical(z@variant, "chain")
  expect_identical(z@fit_context$variant, "chain")
  expect_identical(z@fit_context$structure, "serial")
  expect_identical(z@mediators, c("M1", "M2"))
  expect_identical(z@treatment, "X")
  expect_identical(z@outcome, "Y")
  expect_identical(names(z@estimates), c("a", "d1", "b", "c_prime"))
  expect_identical(dimnames(z@vcov), list(names(z@estimates), names(z@estimates)))
  expect_identical(dim(z@vcov), c(4L, 4L))
  expect_false(any(c("a2", "b1") %in% c(names(z@estimates), rownames(z@vcov), colnames(z@vcov))))
  q <- coef(f)
  expect_equal(unname(z@estimates), unname(q[c("M1~X", "M2~M1", "Y~M2", "Y~X")]), tolerance = 1e-12)
  expect_equal(z@a_path, q[["M1~X"]])
  expect_equal(z@d_path, q[["M2~M1"]])
  expect_equal(z@b_path, q[["Y~M2"]])
  expect_equal(z@c_prime, q[["Y~X"]])
  idx <- match(c("M1~X", "M2~M1", "Y~M2", "Y~X"), names(q))
  expect_equal(unname(z@vcov), unname(vcov(f)[idx, idx]), tolerance = 1e-12)
  expect_equal(z@sigma_mediators, sqrt(unname(q[c("M1~~M1", "M2~~M2")])), tolerance = 1e-12)
  expect_equal(z@sigma_y, sqrt(q[["Y~~Y"]]), tolerance = 1e-12)
  # the absent edges are recorded as absent in the predictor lists (D23)
  expect_identical(z@mediator_predictors, list("X", "M1"))
  expect_setequal(z@outcome_predictors, c("M2", "X"))
  expect_false("X" %in% z@mediator_predictors[[2L]])
  expect_false("M1" %in% z@outcome_predictors)
  expect_identical(z@n_obs, nobs(f))
  expect_identical(z@source_package, "medfit")
  # te() reads no missing coefficient
  expect_false(is.na(as.numeric(te(z))))
  expect_no_warning(te(z))
})

test_that("a fixed-zero or omitted direct path is a zero row and column and the same chain object", {
  d <- sc_data("mar", cp = 0)
  zz <- sb_extract(sc_fit(d, "zero"))
  zo <- sb_extract(sc_fit(d, "omit"))
  expect_identical(zz@c_prime, 0)
  expect_identical(zz@estimates[["c_prime"]], 0)
  expect_true(all(zz@vcov["c_prime", ] == 0) && all(zz@vcov[, "c_prime"] == 0))
  expect_identical(dim(zz@vcov), c(4L, 4L))
  expect_identical(zz@estimates, zo@estimates)
  expect_identical(zz@vcov, zo@vcov)
  expect_identical(generics::tidy(zz), generics::tidy(zo))
  tb <- generics::tidy(zz)
  expect_identical(tb$std_error[tb$term == "c_prime"], 0)
  expect_equal(as.numeric(te(zz)), as.numeric(nie(zz)))
})

test_that("labels never decide a role: labels that reuse reserved alias names extract the same chain", {
  d <- sc_data("mar")
  plain <- sb_extract(sc_fit(d))
  odd <- sb_extract(sc_fit(d, model = paste(
    c("M1 ~ b*X", "M2 ~ a*M1", "Y ~ d1*M2 + a2*X", sc_zeros), collapse = "\n"
  )))
  expect_equal(unname(odd@estimates), unname(plain@estimates), tolerance = 1e-8)
  expect_equal(unname(odd@vcov), unname(plain@vcov), tolerance = 1e-6)
  expect_identical(names(odd@estimates), names(plain@estimates))
})

test_that("V9: with distinct large path values every extracted chain path is the one its label names", {
  d <- sc_data("complete", n = 3000L, seed = 7L)
  z <- sb_extract(sc_fit(d))
  expect_equal(unname(z@estimates), unname(sc_truth[c("a", "d1", "b", "cp")]), tolerance = .08)
  # d1 = .7 and b = .6 are close: only the rows and SEs tell them apart
  expect_lt(abs(z@estimates[["d1"]] - z@estimates[["b"]]), .2)
  tb <- generics::tidy(z, type = "paths")
  expect_identical(tb$term, c("a", "d", "b", "c_prime"))
  expect_equal(tb$estimate[tb$term == "d"], z@estimates[["d1"]])
  expect_equal(tb$estimate[tb$term == "b"], z@estimates[["b"]])
})

test_that("Q7 and the chain extract refusals: reversed order, wrong sets and unsupported arguments are classed", {
  f <- sc_fit(sc_data("mar"))
  refused <- list(
    reversed = list(treatment = "X", mediator = c("M2", "M1")),
    one_mediator = list(treatment = "X", mediator = "M1"),
    wrong_set = list(treatment = "X", mediator = c("M1", "Y")),
    repeated = list(treatment = "X", mediator = c("M1", "M1")),
    wrong_treatment = list(treatment = "M1", mediator = c("M1", "M2")),
    standardized = list(treatment = "X", mediator = c("M1", "M2"), standardized = TRUE),
    wrong_outcome = list(treatment = "X", mediator = c("M1", "M2"), outcome = "X"),
    parallel = list(treatment = "X", mediator = c("M1", "M2"), structure = "parallel"),
    unknown_argument = list(treatment = "X", mediator = c("M1", "M2"), interaction = TRUE),
    decomposition = list(treatment = "X", mediator = c("M1", "M2"), decomposition = "four_way")
  )
  for (nm in names(refused)) {
    expect_error(do.call(extract_mediation, c(list(f), refused[[nm]])),
                 class = "medfit_error_fiml_extract_unsupported", info = nm)
  }
  e <- tryCatch(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")), error = identity)
  expect_match(conditionMessage(e), "M1, M2", fixed = TRUE)
  expect_match(conditionMessage(e), "fitted order", fixed = TRUE)
  for (args in list(list(structure = "serial"), list(structure = "auto"), list(decomposition = "two_way"),
                    list(decomposition = "auto"), list(standardized = FALSE), list(outcome = "Y"))) {
    z <- do.call(extract_mediation, c(list(f, treatment = "X", mediator = c("M1", "M2")), args))
    expect_s3_class(z, "medfit::FIMLSerialMediationData")
    expect_identical(z@variant, "chain")
  }
})

test_that("the chain with a third covariate is refused by the parser even mock-opened; extraction is closed", {
  testthat::local_mocked_bindings(.fiml_serial_admitted = function() TRUE)
  d <- sc_data("mar")
  d$Z1 <- stats::rnorm(nrow(d))
  d$Z2 <- stats::rnorm(nrow(d))
  d$Z3 <- stats::rnorm(nrow(d))
  m <- paste(c("M1 ~ X + Z1 + Z2 + Z3", "M2 ~ M1 + Z1 + Z2 + Z3", "Y ~ M2 + X + Z1 + Z2 + Z3", sc_zeros),
             collapse = "\n")
  expect_error(fit_sem(m, d, missing = "fiml", fixed_x = FALSE), class = "medfit_sem_fiml_error")
  expect_false(.fiml_serial_extract_supported("chain", 3L))
})

test_that("D9: the chain's mediators are structural, not in order of appearance, at extraction too", {
  d <- sc_data("mar")
  names(d) <- c("X", "B", "A", "Y") # B is the first mediator in the chain, A the second
  m <- paste(c("A ~ B", "B ~ X", "Y ~ A + X", "A ~~ 0*B", "B ~~ 0*Y", "A ~~ 0*Y"), collapse = "\n")
  f <- fit_sem(m, d, missing = "fiml", fixed_x = FALSE)
  z <- extract_mediation(f, treatment = "X", mediator = c("B", "A"))
  expect_identical(z@mediators, c("B", "A"))
  ref <- sb_extract(sc_fit(sc_data("mar")))
  expect_equal(unname(z@estimates), unname(ref@estimates), tolerance = 1e-8)
  e <- tryCatch(extract_mediation(f, treatment = "X", mediator = c("A", "B")), error = identity)
  expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
  expect_match(conditionMessage(e), "B, A", fixed = TRUE)
})

# ---- V17: variant routing -------------------------------------------------------------------------------------
test_that("V17: the same data and the two syntaxes reach the two variants; the slot matches the fitted q", {
  d <- sc_data("mar", a2 = .3, b1 = .25)
  fc <- sc_fit(d)
  fs <- sb_fit(d)
  zc <- sb_extract(fc)
  zs <- sb_extract(fs)
  expect_identical(c(zc@variant, zs@variant), c("chain", "saturated"))
  expect_identical(c(length(fc@theta), length(fs@theta)), c(12L, 14L))
  expect_identical(c(length(zc@estimates), length(zs@estimates)), c(4L, 6L))
  expect_identical(c(zc@fit_context$variant, zs@fit_context$variant), c("chain", "saturated"))
  # with real shortcuts the chain cannot reproduce the saturated paths (it has no a2/b1 to absorb them)
  expect_gt(abs(zc@estimates[["b"]] - zs@estimates[["b"]]) + abs(zc@estimates[["d1"]] - zs@estimates[["d1"]]), 1e-3)
  expect_lt(as.numeric(logLik(fc)), as.numeric(logLik(fs)))
})

# ---- the validator (both variants): predictor lists must match the variant exactly -------------------------------
test_that("the validator requires the predictor lists to match the variant (setequal), for both variants", {
  zc <- sc_obj()
  zs <- sb_extract(sb_fit(sc_data("mar")))
  # reordering within a list is the same model
  expect_s3_class(S7::set_props(zc, outcome_predictors = c("X", "M2")), "medfit::FIMLSerialMediationData")
  expect_s3_class(S7::set_props(zs, outcome_predictors = c("X", "M2", "M1")), "medfit::FIMLSerialMediationData")
  expect_s3_class(S7::set_props(zs, mediator_predictors = list("X", c("X", "M1"))), "medfit::FIMLSerialMediationData")
  forged <- list(
    # the chain object described as the saturated graph, and the reverse
    chain_with_x_in_m2 = list(o = zc, mediator_predictors = list("X", c("M1", "X"))),
    chain_with_m1_in_y = list(o = zc, outcome_predictors = c("M1", "M2", "X")),
    chain_without_m2_in_y = list(o = zc, outcome_predictors = "X"),
    chain_without_m1_in_m2 = list(o = zc, mediator_predictors = list("X", character())),
    chain_wrong_m1_predictors = list(o = zc, mediator_predictors = list(c("X", "M2"), "M1")),
    chain_extra_in_y = list(o = zc, outcome_predictors = c("M2", "X", "Y")),
    chain_one_list = list(o = zc, mediator_predictors = list("X")),
    sat_chain_lists = list(o = zs, mediator_predictors = list("X", "M1"), outcome_predictors = c("M2", "X")),
    sat_without_m2_in_y = list(o = zs, outcome_predictors = c("M1", "X")),
    sat_without_x_in_y = list(o = zs, outcome_predictors = c("M1", "M2")),
    sat_wrong_m1_predictors = list(o = zs, mediator_predictors = list(c("X", "M2"), c("M1", "X"))),
    sat_missing_m1_in_m2 = list(o = zs, mediator_predictors = list("X", c("X", "M2"))),
    sat_extra_in_m2 = list(o = zs, mediator_predictors = list("X", c("M1", "X", "Y"))),
    sat_extra_in_y = list(o = zs, outcome_predictors = c("M1", "M2", "X", "M1x")),
    sat_one_list = list(o = zs, mediator_predictors = list("X"))
  )
  for (nm in names(forged)) {
    args <- forged[[nm]]
    o <- args$o
    args$o <- NULL
    expect_error(do.call(S7::set_props, c(list(o), args)), "fit_context", info = nm)
  }
  # the stored alias vector of one variant on the other
  expect_error(S7::set_props(zc, variant = "saturated"), "fit_context")
  ctx <- zc@fit_context
  ctx$variant <- "saturated"
  expect_error(S7::set_props(zc, variant = "saturated", fit_context = ctx), "fit_context")
  # the chain estimates carrying the saturated six aliases
  est <- c(zc@estimates[1L], a2 = 0, zc@estimates[-1L])
  expect_error(S7::set_props(zc, estimates = est), "fit_context")
})

# ---- V8: effects, hand gradients and path enumeration ---------------------------------------------------------
test_that("effects: the chain indirect effect, nie_total = nie, direct and total equal the path enumeration to 1e-12", {
  for (dr in c("free", "zero")) {
    z <- sc_obj(dr)
    e <- z@estimates
    chain <- e[["a"]] * e[["d1"]] * e[["b"]]
    expect_equal(as.numeric(nie(z)), chain, tolerance = 1e-12)
    expect_equal(as.numeric(nie(z, type = "total")), chain, tolerance = 1e-12) # no other indirect path exists
    expect_equal(as.numeric(nde(z)), e[["c_prime"]], tolerance = 1e-12)
    expect_equal(as.numeric(te(z)), chain + e[["c_prime"]], tolerance = 1e-12)
    B <- matrix(0, 4, 4)
    B[2, 1] <- e[["a"]]
    B[3, 2] <- e[["d1"]]
    B[4, 3] <- e[["b"]]
    B[4, 1] <- e[["c_prime"]]
    expect_equal(solve(diag(4) - B)[4, 1], as.numeric(te(z)), tolerance = 1e-12)
  }
})

test_that("the chain gradients are the hand gradients: no a2 * b or a * b1 term, c_prime entry 1 in te", {
  for (dr in c("free", "zero")) {
    z <- sc_obj(dr)
    g <- .effect_gradients(z)
    h <- sc_grad(z)
    for (k in c("nie", "nie_total", "nde", "te")) {
      expect_identical(sort(names(g[[k]])), sort(names(h[[k]])), info = k)
      expect_equal(g[[k]][names(h[[k]])], h[[k]], tolerance = 1e-12, info = k)
    }
    expect_identical(sort(names(g$te)), sort(c("a", "d1", "b", "c_prime")))
    expect_false(any(c("a2", "b1") %in% unlist(lapply(g, names))))
  }
})

test_that("effect SEs equal the hand delta SEs (3 x 3 block for nie, 4 x 4 for te) to 1e-12, tidy and confint alike", {
  for (dr in c("free", "zero")) {
    z <- sc_obj(dr)
    g <- sc_grad(z)
    tb <- sc_tidy(z, type = "effects")
    se <- stats::setNames(tb$std_error, tb$term)
    for (k in c("nie", "nie_total", "nde", "te")) expect_equal(se[[k]], sb_se(z, g[[k]]), tolerance = 1e-12, info = k)
    # the 3 x 3 block over (a, d1, b) written out by hand
    V3 <- z@vcov[c("a", "d1", "b"), c("a", "d1", "b")]
    expect_equal(se[["nie"]], sqrt(drop(g$nie %*% V3 %*% g$nie)), tolerance = 1e-12)
    # nie_total is the same effect: identical row
    expect_identical(tb[tb$term == "nie_total", c("estimate", "std_error")],
                     tb[tb$term == "nie", c("estimate", "std_error")], ignore_attr = TRUE)
    ci <- sc_ci(z, parm = "effects")
    expect_identical(rownames(ci), c("nie", "nie_total", "nde", "te"))
    expect_identical(unname(ci["nie", ]), unname(ci["nie_total", ]))
    half <- (ci[, 2L] - ci[, 1L]) / 2 / stats::qnorm(.975)
    for (k in rownames(ci)) expect_equal(unname(half[[k]]), se[[k]], tolerance = 1e-10, info = k)
    expect_equal(unname(ci[, 1L] + ci[, 2L]) / 2, unname(tb$estimate), tolerance = 1e-12)
  }
  # te needs Cov(b, c_prime) (the Y equation); a te SE that ignores it differs
  z <- sc_obj()
  g <- sc_grad(z)$te
  diag_only <- sqrt(sum(g^2 * diag(z@vcov)[names(g)]))
  expect_gt(abs(sb_se(z, g) - diag_only) / diag_only, 1e-6)
})

test_that("the cross-equation terms matter under missingness: dropping them changes the chain nie SE", {
  z <- sc_obj()
  g <- sc_grad(z)
  full <- sb_se(z, g$nie)
  diag_only <- sqrt(sum(g$nie^2 * diag(z@vcov)[names(g$nie)]))
  expect_gt(abs(full - diag_only) / full, 1e-4)
})

# ---- V12: the exact-origin rule, one rule for the chain -----------------------------------------------------------
sc_row <- function(z, term) {
  tb <- sc_tidy(z, type = "effects", conf_int = TRUE)
  list(tb = tb, row = tb[tb$term == term, ])
}
test_that("the per-effect helper for the chain: nie and nie_total withheld together when two of a, d1, b are 0", {
  z <- sc_obj()
  expect_identical(.sem_fiml_origin_effects(z), c(nie = FALSE, nie_total = FALSE))
  at <- function(vals) .sem_fiml_origin_effects(sb_forge(z, vals))
  both <- c(nie = TRUE, nie_total = TRUE)
  none <- c(nie = FALSE, nie_total = FALSE)
  expect_identical(at(list(a = 0, d1 = 0)), both)
  expect_identical(at(list(a = 0, b = 0)), both)
  expect_identical(at(list(d1 = 0, b = 0)), both)
  expect_identical(at(list(a = 0, d1 = 0, b = 0)), both)
  expect_identical(at(list(a = 0)), none)
  expect_identical(at(list(d1 = 0)), none)
  expect_identical(at(list(b = 0)), none)
  expect_identical(at(list(c_prime = 0)), none)
  # the saturated rule must not be applied: a = d1 = 0 withholds in the chain (a2 and b1 do not exist)
  expect_identical(at(list(a = 0, d1 = 0))[["nie_total"]], TRUE)
  expect_identical(.sem_fiml_origin(z), FALSE)
})

test_that("tidy: both chain rows are NA where the gradient is zero, each noted; one zero factor stays finite", {
  z <- sc_obj()
  for (zero in list(c("a", "d1"), c("a", "b"), c("d1", "b"), c("a", "d1", "b"))) {
    w <- sb_forge(z, stats::setNames(as.list(rep(0, length(zero))), zero))
    r <- sc_row(w, "nie")
    rt <- sc_row(w, "nie_total")$row
    info <- paste(zero, collapse = ",")
    expect_true(is.na(r$row$std_error) && is.na(r$row$conf_low) && is.na(r$row$conf_high), info = info)
    expect_true(is.na(rt$std_error) && is.na(rt$conf_low) && is.na(rt$conf_high), info = info)
    expect_identical(attr(r$tb, "note"), c(nie = sb_note_nie, nie_total = sc_note_total), info = info)
    expect_true(all(is.finite(r$tb$std_error[r$tb$term %in% c("nde", "te")])), info = info)
  }
  # one exactly-zero factor keeps both SEs finite and equal to the hand value
  for (one in c("a", "d1", "b")) {
    w <- sb_forge(z, stats::setNames(list(0), one))
    r <- sc_row(w, "nie")
    rt <- sc_row(w, "nie_total")$row
    hand <- sb_se(w, sc_grad(w)$nie)
    expect_equal(r$row$std_error, hand, tolerance = 1e-12, info = one)
    expect_equal(rt$std_error, hand, tolerance = 1e-12, info = one)
    expect_null(attr(r$tb, "note"))
  }
  # near-origin controls stay finite with no note; the unforged object has no note
  w <- sb_forge(z, list(a = 1e-9, d1 = 1e-9))
  r <- sc_row(w, "nie")
  expect_true(is.finite(r$row$std_error))
  expect_null(attr(r$tb, "note"))
  expect_null(attr(sc_row(z, "nie")$tb, "note"))
})

test_that("confint: the same chain cells, NA rows and per-effect notes", {
  z <- sc_obj()
  w <- sb_forge(z, list(a = 0, d1 = 0))
  ci <- sc_ci(w, parm = "effects")
  expect_true(all(is.na(ci["nie", ])) && all(is.na(ci["nie_total", ])))
  expect_true(all(is.finite(ci["nde", ])) && all(is.finite(ci["te", ])))
  expect_identical(attr(ci, "note"), c(nie = sb_note_nie, nie_total = sc_note_total))
  w <- sb_forge(z, list(a = 0))
  ci <- sc_ci(w, parm = "effects")
  expect_true(all(is.finite(ci)))
  expect_null(attr(ci, "note"))
  expect_null(attr(sc_ci(z, parm = "effects"), "note"))
})

# ---- path rows (Q4, Q12) --------------------------------------------------------------------------------------------
test_that("paths(), coef(type = 'paths'), tidy and summary list the four chain paths, c_prime always", {
  for (dr in c("free", "zero")) {
    z <- sc_obj(dr)
    p <- paths(z)
    expect_identical(names(p), c("a", "d", "b", "c_prime"))
    expect_equal(unname(p), unname(z@estimates[c("a", "d1", "b", "c_prime")]), tolerance = 1e-12)
    cf <- coef(z, type = "paths")
    expect_identical(names(cf), c("a", "d", "b", "c_prime"))
    expect_identical(cf, p)
    expect_identical(coef(z, type = "all"), z@estimates)
    s <- summary(z)
    expect_identical(names(s$paths)[1:4], c("a", "d", "b", "c_prime"))
    expect_false(any(c("a2", "b1") %in% names(s$paths)))
    expect_equal(unname(s$paths[1:4]), unname(p), tolerance = 1e-12)
    expect_true(all(c("indirect", "indirect_total") %in% names(s$paths)))
    expect_equal(unname(s$paths[["indirect_total"]]), unname(s$paths[["indirect"]]), tolerance = 1e-12)
    expect_identical(s$fit_context, z@fit_context)
    expect_output(print(s), "FIML")
  }
})

test_that("tidy and confint map every displayed chain path to a covariance row: four rows, @vcov diagonal SEs", {
  for (dr in c("free", "zero")) {
    z <- sc_obj(dr)
    tb <- sc_tidy(z, type = "paths", conf_int = TRUE)
    expect_identical(tb$term, c("a", "d", "b", "c_prime"))
    se <- sqrt(diag(z@vcov)[c("a", "d1", "b", "c_prime")])
    expect_equal(unname(tb$std_error), unname(se), tolerance = 1e-12)
    expect_equal(tb$conf_low, tb$estimate - stats::qnorm(.975) * tb$std_error, tolerance = 1e-12)
    ci <- sc_ci(z, parm = "paths")
    expect_identical(rownames(ci), c("a", "d", "b", "c_prime"))
    expect_equal(unname((ci[, 2L] - ci[, 1L]) / 2 / stats::qnorm(.975)), unname(se), tolerance = 1e-10)
    all <- sc_tidy(z)
    expect_identical(all$term, c("a", "d", "b", "c_prime", "nie", "nie_total", "nde", "te"))
    expect_identical(attr(all, "fit_context"), z@fit_context)
  }
  z <- sc_obj("zero")
  tb <- sc_tidy(z, type = "paths")
  expect_identical(tb$estimate[tb$term == "c_prime"], 0)
  expect_identical(tb$std_error[tb$term == "c_prime"], 0)
})

# ---- the refusals of the consumers ---------------------------------------------------------------------------------
test_that("the consumers refuse the chain object as every FIML object; the effects warning has no bootstrap advice", {
  z <- sc_obj()
  expect_error(pm(z), "pm\\(\\) is not supported for bounded FIML objects")
  expect_error(generics::glance(z), "not supported for bounded FIML objects")
  expect_error(quick(z), "quick\\(\\) is not supported for bounded FIML objects")
  refusal <- "bootstrap_mediation\\(\\) is not supported for bounded FIML"
  expect_error(bootstrap_mediation(function(x) 1, mediation_data = z), refusal)
  expect_error(bootstrap_mediation(function(x) 1, data = z), refusal)
  e <- tryCatch(confint(z, parm = "effects", method = "boot"), error = identity)
  expect_identical(conditionMessage(e), "bootstrap CI is not supported for bounded FIML objects")
  expect_error(confint(z, parm = "paths", method = "boot"), "not supported for bounded FIML objects")
  w <- NULL
  withCallingHandlers(confint(z, parm = "effects"), warning = function(c) {
    w <<- c(w, conditionMessage(c))
    invokeRestart("muffleWarning")
  })
  expect_length(w, 1L)
  expect_false(grepl("Consider bootstrap_mediation", w, fixed = TRUE))
  expect_s3_class(nie(z), "mediation_effect")
  expect_output(print(z))
})

test_that("the chain SEMFit refuses mbco_sem, compare_lr, anova and source-fit bootstrap (serial class first)", {
  fx_skip_covr()
  f <- sc_fit(sc_data("mar"))
  expect_error(mbco_sem(f, a = "M1~X", b = "Y~M2"), "FIML")
  expect_error(compare_lr(f, paths = c("M1~X", "Y~M2")), "FIML")
  expect_error(anova(f, f), "FIML")
  refit_calls <- 0L
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    refit_calls <<- refit_calls + 1L
    stop("refit reached")
  })
  for (m in c("parametric", "nonparametric")) {
    expect_error(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L),
                 class = "medfit_error_fiml_inference_unavailable")
  }
  testthat::local_mocked_bindings(.fiml_source_inference_admitted = function() TRUE)
  for (m in c("parametric", "nonparametric")) {
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

test_that("the chain SEMFit prints, summarizes, tidies and reports its information criteria with 12 / 11 parameters", {
  d <- sc_data("mar")
  f <- sc_fit(d)
  out <- utils::capture.output(print(f))
  expect_true(any(grepl("FIML, random X", out, fixed = TRUE)))
  expect_true(any(grepl("12 free", out, fixed = TRUE)))
  tb <- generics::tidy(f)
  expect_identical(nrow(tb), 12L)
  expect_true(all(is.finite(tb$std_error)))
  gl <- generics::glance(f)
  expect_identical(gl$npar, 12L)
  expect_true(is.na(gl$chisq) && is.na(gl$p_value))
  expect_identical(attr(logLik(f), "df"), 12L)
  expect_equal(stats::AIC(f), -2 * as.numeric(logLik(f)) + 2 * 12, tolerance = 1e-10)
  expect_identical(generics::glance(sc_fit(d, "zero"))$npar, 11L)
})

test_that("fit_mediation(engine = 'native') keeps its one-mediator limit for a chain FIML model", {
  d <- sc_data("mar")
  m <- sc_model()
  call <- function(med) {
    fit_mediation(engine = "native", model = m, data = d, treatment = "X", mediator = med,
                  engine_args = list(missing = "fiml", fixed_x = FALSE))
  }
  expect_error(call(c("M1", "M2")), "mediator")
  expect_error(call("M1"), class = "medfit_error_fiml_extract_unsupported")
})

# ---- the saturated variant is unchanged by the chain being admitted --------------------------------------------------
test_that("the saturated k = 0 fit is bit identical to its own definition after the chain is admitted (V17 guard)", {
  d <- sb_data("mar")
  f <- sb_fit(d)
  expect_identical(length(f@theta), 14L)
  z <- sb_extract(f)
  expect_identical(names(z@estimates), c("a", "a2", "d1", "b1", "b", "c_prime"))
  expect_identical(z@mediator_predictors, list("X", c("M1", "X")))
})
