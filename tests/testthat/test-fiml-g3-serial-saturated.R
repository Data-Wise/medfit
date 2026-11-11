# FI-G3 slice S1b (kept current by S2): the first public serial FIML variant, the SATURATED graph with no covariates
# (X -> M1 -> M2 -> Y with X -> M2 and M1 -> Y free, independent disturbances written as zero covariances, the direct
# path free, fixed at exactly zero or omitted). Oracles, each independent of the production kernel and adapter:
# matched lavaan raw-data FIML (estimates, covariance, logLik, the defined effects), the unrestricted multivariate
# normal MLE mapped to the recursive parameters (the saturation identity, df 0 / df 1), complete-data equation-wise
# OLS with a block-diagonal covariance, a from-scratch rowwise likelihood with an independent Hessian, and OpenMx for
# one cell. Helpers are in helper-fiml-serial.R (sb_*).

sb_kinds <- c("mar", "mcar30", "sparse")
sb_directs <- c("free", "zero", "omit")

# ---- what is public ---------------------------------------------------------------------------------------------
test_that("the saturated serial syntax with k = 0 is a public fit in every direct policy", {
  d <- sb_data("mar")
  for (dr in sb_directs) {
    f <- sb_fit(d, dr)
    expect_s7_class(f, SEMFit)
    expect_true(.sem_fiml_is(f))
    ll <- f@internals$likelihood
    expect_identical(ll$structure, "serial")
    expect_identical(ll$variant, "saturated")
    expect_identical(unname(ll$mediators), c("M1", "M2"))
    expect_length(f@theta, if (dr == "free") 14L else 13L)
    expect_identical(f@diagnostics$ledger$schema, "fiml-1")
    expect_true(f@converged)
  }
  # an omitted direct path is the fixed-zero policy (Q3): the same fit
  fz <- sb_fit(d, "zero")
  fo <- sb_fit(d, "omit")
  expect_identical(fz@theta, fo@theta)
  expect_identical(fz@vcov, fo@vcov)
})

test_that("the k = 2 serial shapes are public fits (S4); the F6 syntax is the chain with treatment Z (R4)", {
  d <- sb_data("mar")
  d$Z <- d$Z1 <- stats::rnorm(nrow(d))
  d$Z2 <- stats::rnorm(nrow(d))
  z <- paste(sb_zeros, collapse = "\n")
  shapes <- c(
    # the k = 1 shapes became public in slice S3 (test-fiml-g3-serial-covariate.R), the k = 2 shapes in slice S4
    # (test-fiml-g3-serial-two-cov.R)
    sat2 = "M1 ~ X + Z1 + Z2\nM2 ~ M1 + X + Z1 + Z2\nY ~ M1 + M2 + X + Z1 + Z2",
    chain2 = "M1 ~ X + Z1 + Z2\nM2 ~ M1 + Z1 + Z2\nY ~ M2 + X + Z1 + Z2"
  )
  # F6: `M2 ~ M1 + X` with Z omitted is a chain whose treatment is Z; it is a public k = 1 fit since slice S3
  shapes <- c(shapes, z_treatment = "M1 ~ X + Z\nM2 ~ M1 + X\nY ~ M2 + X + Z")
  for (nm in setdiff(names(shapes), "z_treatment")) {
    expect_s7_class(fit_sem(paste(shapes[[nm]], z, sep = "\n"), d, missing = "fiml", fixed_x = FALSE), SEMFit)
  }
  # the F6 syntax parses as the chain with k = 1 and the treatment `Z`
  spec <- .sem_fiml_model(paste(shapes[["z_treatment"]], z, sep = "\n"))
  expect_identical(spec$variant, "chain")
  expect_identical(unname(spec$vars[["X"]]), "Z")
  expect_identical(length(spec$covariate), 1L)
})

test_that("the admission predicate is true for the k = 0, 1 and 2 shapes only; the switch opens the rest", {
  for (k in 0:2) expect_true(.fiml_serial_shape_admitted("saturated", k))
  for (k in 0:2) expect_true(.fiml_serial_shape_admitted("chain", k)) # slices S2, S3 and S4
  expect_false(.fiml_serial_shape_admitted("saturated", 3L))
  expect_false(.fiml_serial_shape_admitted("chain", 3L))
  testthat::local_mocked_bindings(.fiml_serial_admitted = function() TRUE)
  for (k in 0:3) for (v in c("saturated", "chain")) expect_true(.fiml_serial_shape_admitted(v, k))
})

# ---- V1/V2: lavaan raw-data FIML -----------------------------------------------------------------------------------
test_that("estimates, covariance and logLik agree with lavaan raw-data FIML in every cell", {
  skip_if_not_installed("lavaan")
  for (kind in sb_kinds) for (dr in sb_directs) {
    d <- sb_data(kind, cp = if (dr == "free") .25 else 0)
    f <- sb_fit(d, dr)
    ref <- sb_lavaan(sb_model(if (dr == "omit") "omit" else dr), d)
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
  d <- sb_data("sparse")
  f <- sb_fit(d)
  expect_identical(f@n_dropped, 1L)
  expect_gte(length(f@internals$likelihood$rows$patterns), 8L)
})

test_that("the extracted path estimates, effects and effect SEs equal the lavaan := values", {
  skip_if_not_installed("lavaan")
  for (kind in sb_kinds) for (dr in c("free", "zero")) {
    d <- sb_data(kind, cp = if (dr == "free") .25 else 0)
    f <- sb_fit(d, dr)
    z <- sb_extract(f)
    r <- sb_reference(d, dr)
    info <- paste(kind, dr)
    expect_lt(max(abs(z@estimates[names(r$est)] - r$est)), 1e-5, label = info)
    expect_lt(sb_rel_gap(z@vcov[names(r$est), names(r$est)], r$vcov), 1e-3, label = info)
    tb <- generics::tidy(z, type = "effects")
    est <- stats::setNames(tb$estimate, tb$term)
    se <- stats::setNames(tb$std_error, tb$term)
    expect_lt(abs(est[["nie"]] - r$ind$est), 1e-5, label = info)
    expect_lt(abs(est[["nie_total"]] - r$ind_tot$est), 1e-5, label = info)
    expect_lt(abs(est[["te"]] - r$te$est), 1e-5, label = info)
    expect_lt(abs(se[["nie"]] - r$ind$se) / r$ind$se, 2e-3, label = info)
    expect_lt(abs(se[["nie_total"]] - r$ind_tot$se) / r$ind_tot$se, 2e-3, label = info)
    expect_lt(abs(se[["te"]] - r$te$se) / r$te$se, 2e-3, label = info)
  }
})

# ---- V4/V5: saturation identity and the fixed-zero restriction -----------------------------------------------------
test_that("complete data: the free-direct fit is the unrestricted multivariate normal MLE (closed form)", {
  d <- sb_data("complete")
  f <- sb_fit(d)
  n <- nrow(d)
  S <- stats::cov(d) * (n - 1) / n
  mu <- colMeans(d)
  r <- sb_recursive(mu, S)
  q <- coef(f)
  expect_equal(unname(q[c("M1~X", "M2~X", "M2~M1", "Y~M1", "Y~M2", "Y~X")]),
               unname(c(r$m1$b[["X"]], r$m2$b[["X"]], r$m2$b[["M1"]], r$y$b[["M1"]], r$y$b[["M2"]], r$y$b[["X"]])),
               tolerance = 1e-7)
  expect_equal(unname(q[c("M1~~M1", "M2~~M2", "Y~~Y", "X~~X")]), unname(c(r$m1$v, r$m2$v, r$y$v, r$vx)),
               tolerance = 1e-7)
  expect_equal(unname(q[c("M1~1", "M2~1", "Y~1", "X~1")]), unname(c(r$m1$int, r$m2$int, r$y$int, r$mx)),
               tolerance = 1e-7)
  # the unrestricted log-likelihood at the sample moments
  ll <- sum(vapply(seq_len(n), function(i) {
    x <- as.numeric(d[i, ]) - mu
    -.5 * (4 * log(2 * pi) + as.numeric(determinant(S, logarithm = TRUE)$modulus) + drop(t(x) %*% solve(S, x)))
  }, numeric(1)))
  expect_equal(as.numeric(logLik(f)), ll, tolerance = 1e-8)
})

test_that("incomplete data: the free-direct fit equals the unrestricted MLE mapped by recursive regressions", {
  skip_if_not_installed("lavaan")
  for (kind in sb_kinds) {
    d <- sb_data(kind)
    f <- sb_fit(d)
    u <- suppressWarnings(lavaan::sem(
      "X ~~ M1 + M2 + Y\nM1 ~~ M2 + Y\nM2 ~~ Y", d, missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
      information = "observed", control = list(rel.tol = 1e-10)
    ))
    mu <- lavaan::lavInspect(u, "mean.ov")[c("X", "M1", "M2", "Y")]
    S <- lavaan::lavInspect(u, "cov.ov")[c("X", "M1", "M2", "Y"), c("X", "M1", "M2", "Y")]
    r <- sb_recursive(mu, S)
    q <- coef(f)
    expect_lt(max(abs(unname(q[c("M1~X", "M2~X", "M2~M1", "Y~M1", "Y~M2", "Y~X")]) -
                        unname(c(r$m1$b[["X"]], r$m2$b[["X"]], r$m2$b[["M1"]], r$y$b[["M1"]], r$y$b[["M2"]],
                                 r$y$b[["X"]])))), 1e-5, label = kind)
    expect_lt(max(abs(unname(q[c("M1~~M1", "M2~~M2", "Y~~Y")]) - c(r$m1$v, r$m2$v, r$y$v))), 1e-5, label = kind)
    expect_lt(abs(as.numeric(logLik(f)) - as.numeric(lavaan::logLik(u))), 1e-6, label = kind)
  }
})

test_that("the fixed-zero direct path is one restriction: LR against the unrestricted fit equals lavaan's chi-square", {
  skip_if_not_installed("lavaan")
  d <- sb_data("mar", cp = 0)
  free <- sb_fit(d, "free")
  zero <- sb_fit(d, "zero")
  expect_identical(length(free@theta) - length(zero@theta), 1L) # df 1: 14 moments, 13 parameters
  lr <- 2 * (as.numeric(logLik(free)) - as.numeric(logLik(zero)))
  ref <- sb_lavaan(sb_model("zero"), d)
  expect_equal(lr, unname(lavaan::fitMeasures(ref, "chisq")), tolerance = 1e-5)
  expect_equal(unname(lavaan::fitMeasures(ref, "df")), 1)
  expect_gte(lr, -1e-8)
})

# ---- V3: complete-data neutrality ----------------------------------------------------------------------------------
test_that("complete data: equation-wise ML OLS, and a covariance block diagonal across equations", {
  for (dr in sb_directs) {
    d <- sb_data("complete", cp = if (dr == "free") .25 else 0)
    f <- sb_fit(d, dr)
    q <- coef(f)
    n <- nrow(d)
    l1 <- stats::lm(M1 ~ X, d)
    l2 <- stats::lm(M2 ~ M1 + X, d)
    ly <- stats::lm(if (dr == "free") Y ~ M1 + M2 + X else Y ~ M1 + M2, d)
    for (v in c("X")) expect_equal(q[["M1~X"]], stats::coef(l1)[[v]], tolerance = 1e-7)
    for (v in c("M1", "X")) expect_equal(q[[paste0("M2~", v)]], stats::coef(l2)[[v]], tolerance = 1e-7)
    for (v in names(stats::coef(ly))[-1L]) expect_equal(q[[paste0("Y~", v)]], stats::coef(ly)[[v]], tolerance = 1e-7)
    expect_equal(q[["Y~~Y"]], sum(stats::resid(ly)^2) / n, tolerance = 1e-7)
    expect_equal(q[["M2~~M2"]], sum(stats::resid(l2)^2) / n, tolerance = 1e-7)
    V <- vcov(f)
    blocks <- list(
      m1 = c("M1~1", "M1~X"), m2 = c("M2~1", "M2~M1", "M2~X"),
      y = c("Y~1", paste0("Y~", names(stats::coef(ly))[-1L]))
    )
    # within an equation: the ML OLS covariance s_ML^2 (W'W)^-1, with the unbiased lm covariance rescaled by (n-p)/n
    for (nm in names(blocks)) {
      fit <- list(m1 = l1, m2 = l2, y = ly)[[nm]]
      p <- length(stats::coef(fit))
      w <- stats::model.matrix(fit)
      s2 <- sum(stats::resid(fit)^2) / n
      ref <- s2 * solve(crossprod(w))
      cn <- colnames(w)
      cn[cn == "(Intercept)"] <- "1"
      dimnames(ref) <- list(paste0(c(m1 = "M1", m2 = "M2", y = "Y")[[nm]], "~", cn),
                            paste0(c(m1 = "M1", m2 = "M2", y = "Y")[[nm]], "~", cn))
      expect_equal(V[rownames(ref), colnames(ref)], ref, tolerance = 1e-6, ignore_attr = TRUE)
      expect_equal(p, nrow(ref))
    }
    # across equations: exactly zero (the likelihood factors over the equations)
    for (i in 1:2) for (j in (i + 1L):3) {
      expect_lt(max(abs(V[blocks[[i]], blocks[[j]]])), 1e-9)
    }
    # and the extracted path block inherits it
    z <- sb_extract(f)
    expect_lt(abs(z@vcov["a", "d1"]) + abs(z@vcov["a", "b"]) + abs(z@vcov["d1", "b"]) + abs(z@vcov["a2", "b1"]), 1e-9)
    expect_gt(abs(z@vcov["a2", "d1"]), 0) # within the M2 equation: a2 and d1 covary through X and M1
  }
})

test_that("incomplete data: the cross-equation covariance blocks are not zero", {
  d <- sb_data("mar")
  z <- sb_extract(sb_fit(d))
  expect_gt(abs(z@vcov["a", "d1"]) + abs(z@vcov["a", "b"]) + abs(z@vcov["d1", "b"]), 1e-8)
})

# ---- V6: rowwise likelihood and independent Hessian ----------------------------------------------------------------
test_that("the objective is the rowwise likelihood and the covariance inverts an independent Hessian", {
  for (kind in c("mar", "sparse")) {
    d <- sb_data(kind)
    f <- sb_fit(d)
    q <- coef(f)
    keep <- d[rowSums(!is.na(d)) > 0L, ]
    nll <- function(x) sb_nll(keep, stats::setNames(x, names(q)))
    expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
    # the parameter vector is a stationary point of the independent objective
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
test_that("OpenMx raw-data FIML agrees on the free-direct MAR cell", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  d <- sb_data("mar")
  f <- sb_fit(d)
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
    list("sb", type = "RAM", manifestVars = vars), unname(paths),
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

# ---- V10: identification -------------------------------------------------------------------------------------------
# Rows 1-60 lack the second variable of the pair and rows 61-120 the first, so the pair is never jointly observed and
# every other pair is. The saturated model has a free covariance for every pair (df 0): with the direct path free that
# direction is flat and the public fit fails closed at stage `numerical`.
sb_never <- function(pair, seed = 7701L, direct = "free") {
  set.seed(seed)
  n <- 120L
  d <- data.frame(X = stats::rnorm(n))
  d$M1 <- .6 * d$X + stats::rnorm(n)
  d$M2 <- .5 * d$M1 + stats::rnorm(n)
  d$Y <- .5 * d$M2 + .2 * d$X + stats::rnorm(n)
  d[1:60, pair[2L]] <- NA_real_
  d[61:120, pair[1L]] <- NA_real_
  tryCatch(sb_fit(d, direct), error = identity)
}
test_that("V10: a never-jointly-observed pair fails closed at the numerical stage with the direct path free", {
  for (pair in utils::combn(c("X", "M1", "M2", "Y"), 2L, simplify = FALSE)) {
    e <- sb_never(pair)
    info <- paste(pair, collapse = ",")
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "numerical", info = info)
    expect_match(conditionMessage(e), "rank deficient", info = info)
  }
})
test_that("V10: with the direct path fixed, each never-jointly-observed pair is a finite fit or a classed error", {
  for (pair in utils::combn(c("X", "M1", "M2", "Y"), 2L, simplify = FALSE)) {
    e <- sb_never(pair, direct = "zero")
    info <- paste(pair, collapse = ",")
    if (inherits(e, "error")) {
      expect_s3_class(e, "medfit_sem_fiml_error")
      expect_identical(e$stage, "numerical", info = info)
    } else {
      expect_true(all(is.finite(coef(e))), info = info)
      expect_true(all(is.finite(vcov(e))), info = info)
    }
  }
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
    e <- tryCatch(sb_fit(d), error = identity)
    if (inherits(e, "error")) {
      expect_s3_class(e, "medfit_sem_fiml_error")
    } else {
      ref <- tryCatch(sb_lavaan(sb_model(), d), error = identity)
      if (!inherits(ref, "error") && lavaan::lavInspect(ref, "converged")) {
        expect_lt(abs(as.numeric(logLik(e)) - as.numeric(lavaan::logLik(ref))), 1e-4, label = seed)
      }
    }
  }
})

# ---- extraction contract -------------------------------------------------------------------------------------------
test_that("extraction returns the serial FIML class with the saturated path set and the full covariance block", {
  d <- sb_data("mar")
  f <- sb_fit(d)
  z <- sb_extract(f)
  expect_s3_class(z, "medfit::FIMLSerialMediationData")
  expect_true(S7::S7_inherits(z, SerialMediationData))
  expect_identical(z@variant, "saturated")
  expect_identical(z@fit_context$variant, "saturated")
  expect_identical(z@fit_context$structure, "serial")
  expect_identical(z@mediators, c("M1", "M2"))
  expect_identical(z@treatment, "X")
  expect_identical(z@outcome, "Y")
  expect_identical(names(z@estimates), c("a", "a2", "d1", "b1", "b", "c_prime"))
  expect_identical(dimnames(z@vcov), list(names(z@estimates), names(z@estimates)))
  q <- coef(f)
  expect_equal(unname(z@estimates), unname(q[c("M1~X", "M2~X", "M2~M1", "Y~M1", "Y~M2", "Y~X")]), tolerance = 1e-12)
  expect_equal(z@a_path, q[["M1~X"]])
  expect_equal(z@d_path, q[["M2~M1"]])
  expect_equal(z@b_path, q[["Y~M2"]])
  expect_equal(z@c_prime, q[["Y~X"]])
  # the covariance block is the fitted one, cross terms included
  idx <- match(c("M1~X", "M2~X", "M2~M1", "Y~M1", "Y~M2", "Y~X"), names(q))
  expect_equal(unname(z@vcov), unname(vcov(f)[idx, idx]), tolerance = 1e-12)
  expect_equal(z@sigma_mediators, sqrt(unname(q[c("M1~~M1", "M2~~M2")])), tolerance = 1e-12)
  expect_equal(z@sigma_y, sqrt(q[["Y~~Y"]]), tolerance = 1e-12)
  expect_identical(z@mediator_predictors, list("X", c("M1", "X")))
  expect_setequal(z@outcome_predictors, c("M1", "M2", "X"))
  expect_identical(z@n_obs, nobs(f))
  expect_identical(z@source_package, "medfit")
  # the shortcut paths are stored, so te() is not NA
  expect_false(is.na(as.numeric(te(z))))
})

test_that("a fixed-zero or omitted direct path is a zero row and column and the same object", {
  d <- sb_data("mar", cp = 0)
  zz <- sb_extract(sb_fit(d, "zero"))
  zo <- sb_extract(sb_fit(d, "omit"))
  expect_identical(zz@c_prime, 0)
  expect_identical(zz@estimates[["c_prime"]], 0)
  expect_true(all(zz@vcov["c_prime", ] == 0) && all(zz@vcov[, "c_prime"] == 0))
  expect_identical(zz@estimates, zo@estimates)
  expect_identical(zz@vcov, zo@vcov)
  expect_identical(generics::tidy(zz), generics::tidy(zo))
  expect_identical(zz@mediator_predictors, zo@mediator_predictors)
  expect_identical(zz@outcome_predictors, zo@outcome_predictors)
  # the zero direct path has SE 0 in the paths and te() = the total indirect effect
  tb <- generics::tidy(zz)
  expect_identical(tb$std_error[tb$term == "c_prime"], 0)
  expect_equal(as.numeric(te(zz)), as.numeric(nie(zz, type = "total")))
})

test_that("labels never decide a role: labels that reuse reserved alias names extract the same effects", {
  d <- sb_data("mar")
  plain <- sb_extract(sb_fit(d))
  odd <- sb_extract(sb_fit(d, model = paste(
    c("M1 ~ b*X", "M2 ~ a*M1 + X", "Y ~ M1 + d1*M2 + a2*X", sb_zeros), collapse = "\n"
  )))
  expect_equal(unname(odd@estimates), unname(plain@estimates), tolerance = 1e-8)
  expect_equal(unname(odd@vcov), unname(plain@vcov), tolerance = 1e-6)
  expect_identical(names(odd@estimates), names(plain@estimates))
})

test_that("V9: with distinct large path values every extracted path is the one its label names", {
  d <- sb_data("complete", n = 2000L, seed = 7)
  z <- sb_extract(sb_fit(d))
  expect_equal(unname(z@estimates), unname(sb_truth[c("a", "a2", "d1", "b1", "b", "cp")]), tolerance = .08)
  # d1 = .7 and b = .6 are close: only the rows and SEs tell them apart
  expect_lt(abs(z@estimates[["d1"]] - z@estimates[["b"]]), .2)
  tb <- generics::tidy(z, type = "paths")
  expect_identical(tb$term, c("a", "a2", "d", "b1", "b", "c_prime"))
})

test_that("Q7 and the extract refusals: reversed order, wrong sets and unsupported arguments are classed", {
  f <- sb_fit(sb_data("mar"))
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
  # the reversed-order message names the fitted order
  e <- tryCatch(extract_mediation(f, treatment = "X", mediator = c("M2", "M1")), error = identity)
  expect_match(conditionMessage(e), "M1, M2", fixed = TRUE)
  expect_match(conditionMessage(e), "fitted order", fixed = TRUE)
  # admitted spellings
  for (args in list(list(structure = "serial"), list(structure = "auto"), list(decomposition = "two_way"),
                    list(decomposition = "auto"), list(standardized = FALSE), list(outcome = "Y"))) {
    expect_s3_class(do.call(extract_mediation, c(list(f, treatment = "X", mediator = c("M1", "M2")), args)),
                    "medfit::FIMLSerialMediationData")
  }
})

test_that("the extraction predicate is closed for a third covariate, which the parser refuses even mock-opened", {
  testthat::local_mocked_bindings(.fiml_serial_admitted = function() TRUE)
  d <- sb_data("mar")
  d$Z1 <- stats::rnorm(nrow(d))
  d$Z2 <- stats::rnorm(nrow(d))
  d$Z3 <- stats::rnorm(nrow(d))
  m <- paste(c(
    "M1 ~ X + Z1 + Z2 + Z3", "M2 ~ M1 + X + Z1 + Z2 + Z3", "Y ~ M1 + M2 + X + Z1 + Z2 + Z3", sb_zeros
  ), collapse = "\n")
  expect_error(fit_sem(m, d, missing = "fiml", fixed_x = FALSE), class = "medfit_sem_fiml_error")
  expect_false(.fiml_serial_extract_supported("saturated", 3L))
  expect_false(.fiml_serial_extract_supported("chain", 3L))
})

test_that("D9: the mediators are structural, not in order of appearance, at extraction too", {
  d <- sb_data("mar")
  names(d) <- c("X", "B", "A", "Y") # B is the first mediator in the chain, A the second
  m <- paste(c("A ~ B + X", "B ~ X", "Y ~ B + A + X", "A ~~ 0*B", "B ~~ 0*Y", "A ~~ 0*Y"), collapse = "\n")
  f <- fit_sem(m, d, missing = "fiml", fixed_x = FALSE)
  z <- extract_mediation(f, treatment = "X", mediator = c("B", "A"))
  expect_identical(z@mediators, c("B", "A"))
  ref <- sb_extract(sb_fit(sb_data("mar")))
  expect_equal(unname(z@estimates), unname(ref@estimates), tolerance = 1e-8)
  e <- tryCatch(extract_mediation(f, treatment = "X", mediator = c("A", "B")), error = identity)
  expect_s3_class(e, "medfit_error_fiml_extract_unsupported")
  expect_match(conditionMessage(e), "B, A", fixed = TRUE)
})

test_that("only the fitted object is extracted: a forged or foreign fit is refused by the ledger", {
  f <- sb_fit(sb_data("mar"))
  g <- f
  g@theta[1L] <- g@theta[1L] + 1
  expect_error(sb_extract(g), class = "medfit_error_ledger")
})

# ---- the classed refusals of the source-fit path are now reachable for a real fit ------------------------------
test_that("source-fit inference: the stage-0 guard answers first, then the serial class, before any RNG or refit", {
  fx_skip_covr()
  f <- sb_fit(sb_data("mar"))
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

test_that("other consumers of the fit refuse it as for every FIML fit", {
  f <- sb_fit(sb_data("mar"))
  expect_error(mbco_sem(f, a = "M1~X", b = "Y~M2"), "FIML")
  expect_error(compare_lr(f, paths = c("M1~X", "Y~M2")), "FIML")
  expect_error(anova(f, f), "FIML")
})

# ---- the SEMFit surface that was unreachable before this slice -------------------------------------------------------
test_that("the serial SEMFit prints, summarizes, tidies and reports its information criteria like every FIML fit", {
  d <- sb_data("mar")
  f <- sb_fit(d)
  out <- utils::capture.output(print(f))
  expect_true(any(grepl("FIML, random X", out, fixed = TRUE)))
  expect_true(any(grepl("14 free", out, fixed = TRUE)))
  expect_true(any(grepl("FIML model test unavailable", out, fixed = TRUE)))
  expect_s3_class(summary(f), "summary_SEMFit")
  tb <- generics::tidy(f)
  expect_identical(nrow(tb), 14L)
  expect_true(all(is.finite(tb$std_error)))
  gl <- generics::glance(f)
  expect_identical(gl$npar, 14L)
  expect_true(is.na(gl$chisq) && is.na(gl$p_value))
  expect_equal(gl$logLik, as.numeric(logLik(f)), tolerance = 1e-12)
  expect_identical(attr(logLik(f), "df"), 14L)
  n <- nobs(f)
  expect_equal(stats::AIC(f), -2 * as.numeric(logLik(f)) + 2 * 14, tolerance = 1e-10)
  expect_equal(stats::BIC(f), -2 * as.numeric(logLik(f)) + log(n) * 14, tolerance = 1e-10)
  fz <- sb_fit(d, "zero")
  expect_identical(generics::glance(fz)$npar, 13L)
})

test_that("fit_mediation(engine = 'native') keeps its one-mediator limit for a serial FIML model", {
  d <- sb_data("mar")
  m <- paste(c("M1 ~ X", "M2 ~ M1 + X", "Y ~ M1 + M2 + X", sb_zeros), collapse = "\n")
  call <- function(med) {
    fit_mediation(engine = "native", model = m, data = d, treatment = "X", mediator = med,
                  engine_args = list(missing = "fiml", fixed_x = FALSE))
  }
  # two mediators are not taken by fit_mediation() (fit_sem() then extract_mediation() is the route)
  expect_error(call(c("M1", "M2")), "mediator")
  # a single mediator named for the serial fit is refused by the extraction, with its class
  expect_error(call("M1"), class = "medfit_error_fiml_extract_unsupported")
})
