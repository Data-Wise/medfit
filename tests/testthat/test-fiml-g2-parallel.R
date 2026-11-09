# FI-G2, slice 1: bounded Gaussian FIML for PARALLEL mediation, two mediators, independent disturbances, no covariates
# (random X; X, M1, M2, Y jointly Gaussian): M1 ~ X, M2 ~ X, Y ~ M1 + M2 [+ X], with `M1 ~~ 0*M2` written. Oracles, each
# independent of the production kernel: matched lavaan raw-data FIML (including the := products and their SUM), a
# from-scratch rowwise Gaussian likelihood, and closed-form complete-data OLS. Helpers are prefixed p2_.

p2_vars <- c("X", "M1", "M2", "Y")
p2_data <- function(kind = "mar", n = 450L, direct = TRUE, seed = 6121L, a = c(.9, .6), b = c(.7, .3)) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  m1 <- .3 + a[1] * x + stats::rnorm(n, sd = .5)
  m2 <- -.2 + a[2] * x + stats::rnorm(n, sd = .5)
  y <- .2 + b[1] * m1 + b[2] * m2 + (if (direct) .25 else 0) * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M1 = m1, M2 = m2, Y = y)
  if (kind == "mar") {
    # every variable can be incomplete; the mediators and Y depend (ignorably) on the observed X
    d[stats::runif(n) < .08, "X"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.3 - .5 * x), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind == "sparse") {
    # single-variable and pair patterns in disjoint row blocks plus one all-empty row
    d[1:20, "X"] <- NA_real_
    d[21:40, "M1"] <- NA_real_
    d[41:60, "M2"] <- NA_real_
    d[61:80, "Y"] <- NA_real_
    d[81:90, c("X", "M1")] <- NA_real_
    d[91:100, c("M2", "Y")] <- NA_real_
    d[101:110, c("X", "Y")] <- NA_real_
    d[111L, ] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
p2_cov <- "\nM1 ~~ 0*M2"
p2_models <- c(
  free = paste0("M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X", p2_cov),
  zero = paste0("M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + 0*X", p2_cov),
  omitted = paste0("M1 ~ X\nM2 ~ X\nY ~ M1 + M2", p2_cov)
)
p2_fit <- function(d = p2_data(), model = p2_models[["free"]], ...) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE, ...)
}
p2_lavaan <- function(d, model) {
  suppressWarnings(lavaan::sem(model, d, missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
                               information = "observed", control = list(rel.tol = 1e-10)))
}
# lavaan model with labels and the defined parameters: the two products, their SUM and the total effect
p2_lavaan_labeled <- function(variant) {
  y <- switch(variant, free = "Y ~ b1*M1 + b2*M2 + cp*X", zero = "Y ~ b1*M1 + b2*M2 + 0*X",
              omitted = "Y ~ b1*M1 + b2*M2")
  paste0("M1 ~ a1*X\nM2 ~ a2*X\n", y, p2_cov, "\nind1 := a1*b1\nind2 := a2*b2\ntot := a1*b1 + a2*b2",
         if (variant == "free") "\nte := cp + a1*b1 + a2*b2")
}
p2_rel_gap <- function(V, ref) max(abs(V - ref) / sqrt(outer(diag(ref), diag(ref))))
p2_n_par <- function(variant) if (variant == "free") 13L else 12L

# ---- independent rowwise likelihood ---------------------------------------------------------------------------------
p2_moments <- function(q) {
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  B <- matrix(0, 4, 4, dimnames = list(p2_vars, p2_vars))
  for (r in c("M1", "M2", "Y")) for (p in setdiff(p2_vars, r)) B[r, p] <- g(paste0(r, "~", p))
  B["M1", "M2"] <- B["M2", "M1"] <- B["M1", "Y"] <- B["M2", "Y"] <- 0
  psi <- diag(vapply(p2_vars, function(v) g(paste0(v, "~~", v)), numeric(1)))
  dimnames(psi) <- list(p2_vars, p2_vars)
  A <- solve(diag(4) - B)
  list(mu = drop(A %*% vapply(p2_vars, function(v) g(paste0(v, "~1")), numeric(1))), sigma = A %*% psi %*% t(A))
}
p2_nll <- function(d, q) gk_row_nll(as.matrix(d[, p2_vars]), p2_moments(q))
p2_hessian <- function(f, q) {
  units <- pmax(abs(q), 1)
  v <- grep("~~", names(q))
  units[v] <- pmin(units[v], abs(q[v]) / 10 + (q[v] == 0))
  f0 <- f(q)
  H <- fo_richardson(lapply(.02 / 2^(0:3), function(delta) {
    H <- matrix(0, length(q), length(q))
    for (j in seq_along(q)) {
      ej <- q * 0
      ej[j] <- units[j] * delta
      H[j, j] <- (f(q + ej) - 2 * f0 + f(q - ej)) / ej[j]^2
      if (j > 1L) {
        for (k in seq_len(j - 1L)) {
          ek <- q * 0
          ek[k] <- units[k] * delta
          H[j, k] <- H[k, j] <- (f(q + ej + ek) - f(q + ej - ek) - f(q - ej + ek) + f(q - ej - ek)) /
            (4 * ej[j] * ek[k])
        }
      }
    }
    H
  }))
  (H + t(H)) / 2
}
# independent delta-method SEs of the two products and their sum from an extracted object's covariance
p2_delta <- function(m) {
  V <- m@vcov
  a <- m@a_paths
  b <- m@b_paths
  se <- function(g) sqrt(drop(t(g) %*% V[names(g), names(g)] %*% g))
  list(
    ind1 = se(c(a1 = b[[1]], b1 = a[[1]])), ind2 = se(c(a2 = b[[2]], b2 = a[[2]])),
    sum = se(c(a1 = b[[1]], a2 = b[[2]], b1 = a[[1]], b2 = a[[2]]))
  )
}

# ---- fit versus lavaan and the rowwise oracle -----------------------------------------------------------------------

test_that("the two-mediator parallel tables are the three-variable tables for one mediator", {
  ref <- function(direct) {
    a <- data.frame(row = c("M", "Y", "Y"), col = c("X", "M", "X"), label = c("a", "b", "cp"),
                    value = c(NA, NA, if (direct) NA else 0))
    s <- data.frame(row = c("X", "M", "Y"), col = c("X", "M", "Y"), label = c("vx", "vm", "vy"), value = NA_real_)
    m <- data.frame(row = c("X", "M", "Y"), label = c("ix", "im", "iy"), value = NA_real_)
    list(vars = c("X", "M", "Y"), a = a, s = s, m = m)
  }
  for (direct in c(TRUE, FALSE)) {
    expect_identical(.sem_fiml_tables_med(1L, direct), ref(direct))
    expect_identical(.sem_fiml_tables(direct), ref(direct))
  }
  t2 <- .sem_fiml_tables_med(2L, TRUE)
  expect_identical(t2$vars, p2_vars)
  expect_identical(t2$a$label, c("a1", "a2", "b1", "b2", "cp"))
  expect_identical(.sem_fiml_layout(t2)$paths$predictor, c("X", "X", "M1", "M2", "X"))
  expect_error(.sem_fiml_tables_med(3L, TRUE), class = "medfit_sem_fiml_error")
})

test_that("parallel FIML matches lavaan raw-data FIML: estimates, covariance, logLik, products, their SUM and SEs", {
  skip_if_not_installed("lavaan")
  for (variant in names(p2_models)) {
    d <- p2_data(direct = variant == "free")
    expect_true(all(vapply(d, anyNA, logical(1))))
    f <- p2_fit(d, p2_models[[variant]])
    expect_s3_class(f, "medfit::SEMFit")
    ref <- p2_lavaan(d, p2_models[[variant]])
    q <- coef(f)
    expect_length(q, p2_n_par(variant))
    expect_identical(length(lavaan::coef(ref)), p2_n_par(variant))
    expect_setequal(names(q), names(lavaan::coef(ref)))
    expect_lt(max(abs(q - lavaan::coef(ref)[names(q)])), 1e-5)
    idx <- match(names(q), names(lavaan::coef(ref)))
    expect_lt(p2_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
    expect_lt(abs(as.numeric(stats::logLik(f)) - as.numeric(lavaan::logLik(ref))), 1e-6)
    expect_identical(attr(stats::logLik(f), "df"), p2_n_par(variant))
    rl <- p2_lavaan(d, p2_lavaan_labeled(variant))
    pe <- lavaan::parameterEstimates(rl)
    pe <- pe[pe$op == ":=", ]
    expect_no_warning(m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2")))
    expect_s3_class(m, "medfit::FIMLParallelMediationData")
    expect_s3_class(m, "medfit::ParallelMediationData")
    expect_equal(as.numeric(nie(m)), pe$est[pe$label == "tot"], tolerance = 1e-5)
    expect_equal(m@a_paths[[1]] * m@b_paths[[1]], pe$est[pe$label == "ind1"], tolerance = 1e-5)
    expect_equal(m@a_paths[[2]] * m@b_paths[[2]], pe$est[pe$label == "ind2"], tolerance = 1e-5)
    dl <- p2_delta(m)
    expect_equal(dl$ind1, pe$se[pe$label == "ind1"], tolerance = 2e-3)
    expect_equal(dl$ind2, pe$se[pe$label == "ind2"], tolerance = 2e-3)
    expect_equal(dl$sum, pe$se[pe$label == "tot"], tolerance = 2e-3)
    tt <- generics::tidy(m, type = "effects")
    expect_equal(tt$std_error[tt$term == "nie"], pe$se[pe$label == "tot"], tolerance = 2e-3)
    expect_equal(tt$std_error[tt$term == "nie"], dl$sum, tolerance = 1e-8)
    ci <- suppressWarnings(confint(m, parm = "effects"))
    expect_equal(unname(ci[1L, 2L] - ci[1L, 1L]) / (2 * stats::qnorm(.975)), dl$sum, tolerance = 1e-8)
    if (variant == "free") {
      expect_equal(as.numeric(te(m)), pe$est[pe$label == "te"], tolerance = 1e-5)
      expect_equal(tt$std_error[tt$term == "te"], pe$se[pe$label == "te"], tolerance = 2e-3)
    } else {
      expect_identical(unname(m@c_prime), 0)
      expect_equal(as.numeric(te(m)), as.numeric(nie(m)))
    }
    # the extracted covariance is the fitted one, path by path (full block, including cross-mediator terms)
    nm <- c("a1", "a2", "b1", "b2", if (variant == "free") "c_prime")
    ln <- c("a1", "a2", "b1", "b2", if (variant == "free") "cp")
    expect_lt(p2_rel_gap(m@vcov[nm, nm], lavaan::vcov(rl)[ln, ln]), 1e-3)
    expect_equal(unname(m@a_paths), unname(q[c("M1~X", "M2~X")]))
    expect_equal(unname(m@b_paths), unname(q[c("Y~M1", "Y~M2")]))
    expect_identical(m@n_obs, f@n_obs)
    expect_identical(m@mediators, c("M1", "M2"))
    expect_identical(m@fit_context$mediators, c("M1", "M2"))
    expect_identical(attr(tt, "fit_context")$method, "fiml")
  }
})

test_that("parallel FIML equals the rowwise likelihood oracle and is a local optimum (observed information)", {
  for (variant in names(p2_models)) {
    d <- p2_data(direct = variant == "free")
    f <- p2_fit(d, p2_models[[variant]])
    q <- coef(f)
    nll <- function(x) p2_nll(d, stats::setNames(x, names(q)))
    expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
    grad <- vapply(seq_along(q), function(k) {
      fo_richardson(lapply(.02 / 2^(0:3), function(h) {
        e <- q * 0
        e[k] <- h * max(abs(q[k]), 1)
        (nll(q + e) - nll(q - e)) / (2 * e[k])
      }))
    }, numeric(1))
    expect_lt(max(abs(grad)), 1e-4)
    for (k in seq_along(q)) {
      e <- q * 0
      e[k] <- .05 * max(abs(q[k]), 1)
      expect_gt(nll(q + e), nll(q))
      expect_gt(nll(q - e), nll(q))
    }
    expect_lt(p2_rel_gap(vcov(f), solve(p2_hessian(nll, q))), 1e-3)
  }
})

test_that("a sparse pattern sweep keeps every pattern including an all-empty row", {
  skip_if_not_installed("lavaan")
  d <- p2_data("sparse")
  f <- p2_fit(d)
  expect_identical(f@n_dropped, 1L)
  expect_identical(f@n_obs, nrow(d) - 1L)
  expect_gte(length(f@internals$likelihood$rows$patterns), 7L)
  ref <- p2_lavaan(d, p2_models[["free"]])
  q <- coef(f)
  expect_lt(max(abs(q - lavaan::coef(ref)[names(q)])), 1e-5)
  nll <- function(x) p2_nll(d[rowSums(!is.na(d)) > 0L, ], stats::setNames(x, names(q)))
  expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
})

test_that("complete data: parallel FIML equals closed-form OLS, ML covariances and the exact block structure", {
  d <- p2_data("complete")
  f <- p2_fit(d)
  q <- coef(f)
  n <- nrow(d)
  l1 <- stats::lm(M1 ~ X, d)
  l2 <- stats::lm(M2 ~ X, d)
  ly <- stats::lm(Y ~ M1 + M2 + X, d)
  expect_equal(q[["M1~X"]], stats::coef(l1)[["X"]], tolerance = 1e-6)
  expect_equal(q[["M2~X"]], stats::coef(l2)[["X"]], tolerance = 1e-6)
  expect_equal(q[["Y~M1"]], stats::coef(ly)[["M1"]], tolerance = 1e-6)
  expect_equal(q[["Y~M2"]], stats::coef(ly)[["M2"]], tolerance = 1e-6)
  expect_equal(q[["Y~X"]], stats::coef(ly)[["X"]], tolerance = 1e-6)
  expect_equal(q[["M1~1"]], stats::coef(l1)[["(Intercept)"]], tolerance = 1e-6)
  expect_equal(q[["Y~1"]], stats::coef(ly)[["(Intercept)"]], tolerance = 1e-6)
  v1 <- sum(stats::resid(l1)^2) / n
  v2 <- sum(stats::resid(l2)^2) / n
  vy <- sum(stats::resid(ly)^2) / n
  vx <- mean((d$X - mean(d$X))^2)
  expect_equal(q[["M1~~M1"]], v1, tolerance = 1e-6)
  expect_equal(q[["M2~~M2"]], v2, tolerance = 1e-6)
  expect_equal(q[["Y~~Y"]], vy, tolerance = 1e-6)
  expect_equal(q[["X~~X"]], vx, tolerance = 1e-6)
  expect_equal(q[["X~1"]], mean(d$X), tolerance = 1e-6)
  lln <- function(r, v) sum(stats::dnorm(r, 0, sqrt(v), log = TRUE))
  ll <- lln(d$X - mean(d$X), vx) + lln(stats::resid(l1), v1) + lln(stats::resid(l2), v2) + lln(stats::resid(ly), vy)
  expect_equal(as.numeric(stats::logLik(f)), ll, tolerance = 1e-8)
  # exact ML covariances: sigma^2 (Z'Z)^-1 per equation, zero across the independent equations
  V <- vcov(f)
  xm <- cbind(1, d$X)
  expect_equal(V[c("M1~1", "M1~X"), c("M1~1", "M1~X")], v1 * solve(crossprod(xm)), tolerance = 1e-4, ignore_attr = TRUE)
  zy <- cbind(1, d$M1, d$M2, d$X)
  Vy <- vy * solve(crossprod(zy))
  expect_equal(V[["Y~M1", "Y~M2"]], Vy[2, 3], tolerance = 1e-3)
  expect_equal(V[["Y~M1", "Y~M1"]], Vy[2, 2], tolerance = 1e-4)
  expect_lt(abs(V[["M1~X", "M2~X"]]), 1e-8)
  expect_lt(abs(V[["M1~X", "Y~M2"]]), 1e-8)
  expect_gt(abs(V[["Y~M1", "Y~M2"]]), 1e-4)
})

# ---- the cross-path covariance (the plan's named defect) ------------------------------------------------------------

test_that("the sum of indirect paths keeps the full cross-path covariance and it matters", {
  skip_if_not_installed("lavaan")
  d <- p2_data(direct = FALSE)
  f <- p2_fit(d, p2_models[["zero"]])
  m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  V <- m@vcov
  g <- c(a1 = m@b_paths[[1]], a2 = m@b_paths[[2]], b1 = m@a_paths[[1]], b2 = m@a_paths[[2]])
  full <- sqrt(drop(t(g) %*% V[names(g), names(g)] %*% g))
  # naive sum of the two products' variances ignores every cross-mediator term
  one <- function(a, b) g[[a]]^2 * V[a, a] + g[[b]]^2 * V[b, b] + 2 * g[[a]] * g[[b]] * V[a, b]
  naive <- sqrt(one("a1", "b1") + one("a2", "b2"))
  expect_gt(abs(full - naive) / full, .03)
  tt <- generics::tidy(m, type = "effects")
  expect_equal(tt$std_error[tt$term == "nie"], full, tolerance = 1e-10)
  # the cross-mediator block is not zero in the observed-information covariance
  expect_gt(abs(V["b1", "b2"]), 1e-4)
  ref <- p2_lavaan(d, p2_lavaan_labeled("zero"))
  pe <- lavaan::parameterEstimates(ref)
  expect_equal(full, pe$se[pe$label == "tot"], tolerance = 2e-3)
  expect_gt(abs(full - naive), 10 * abs(full - pe$se[pe$label == "tot"]))
})

# ---- the direct-path policy, residual policy and extraction rules ----------------------------------------------------

test_that("direct-path policies are free, fixed at zero, omitted; the residual covariance is written", {
  expect_identical(.sem_fiml_model(p2_models[["free"]])$direct, TRUE)
  expect_identical(.sem_fiml_model(p2_models[["zero"]])$direct, FALSE)
  expect_identical(.sem_fiml_model(p2_models[["omitted"]])$direct, FALSE)
  expect_identical(names(.sem_fiml_model(p2_models[["free"]])$map),
                   c("a1", "a2", "b1", "b2", "cp", "vx", "vm1", "vm2", "vy", "ix", "im1", "im2", "iy"))
  expect_identical(names(.sem_fiml_model(p2_models[["zero"]])$map),
                   c("a1", "a2", "b1", "b2", "vx", "vm1", "vm2", "vy", "ix", "im1", "im2", "iy"))
  swapped <- "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM2 ~~ 0*M1"
  expect_identical(.sem_fiml_model(swapped)$map, .sem_fiml_model(p2_models[["free"]])$map)
  d <- p2_data()
  expect_equal(coef(p2_fit(d, swapped)), coef(p2_fit(d)))
  # labels that do not tie anything and any statement order give the same fit
  labeled <- "Y ~ q*M1 + r*M2 + s*X\nM2 ~ t*X\nM1 ~ u*X\nM1 ~~ 0*M2"
  expect_equal(sort(unname(coef(p2_fit(d, labeled)))), sort(unname(coef(p2_fit(d)))), tolerance = 1e-6)
})

test_that("extraction names the fitted structure: both mediators in either order; everything else refused", {
  d <- p2_data()
  f <- p2_fit(d)
  q <- coef(f)
  m <- extract_mediation(f, treatment = "X", mediator = c("M2", "M1"))
  expect_identical(m@mediators, c("M2", "M1"))
  expect_equal(unname(m@a_paths), unname(q[c("M2~X", "M1~X")]))
  expect_equal(unname(m@b_paths), unname(q[c("Y~M2", "Y~M1")]))
  m1 <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  expect_equal(as.numeric(nie(m)), as.numeric(nie(m1)))
  expect_equal(generics::tidy(m, type = "effects")$std_error, generics::tidy(m1, type = "effects")$std_error)
  expect_no_error(extract_mediation(f, treatment = "X", mediator = c("M1", "M2"), structure = "parallel"))
  expect_no_error(extract_mediation(f, treatment = "X", mediator = c("M1", "M2"), outcome = "Y"))
  refused <- list(
    list(treatment = "X", mediator = "M1"), list(treatment = "X", mediator = "M2"),
    list(treatment = "M1", mediator = c("M1", "M2")), list(treatment = "X", mediator = c("M1", "Y")),
    list(treatment = "X", mediator = c("M1", "M1")), list(treatment = "X", mediator = c("M1", "M2", "Y")),
    list(treatment = "X", mediator = c("M1", "M2"), standardized = TRUE),
    list(treatment = "X", mediator = c("M1", "M2"), structure = "serial"),
    list(treatment = "X", mediator = c("M1", "M2"), decomposition = "four_way"),
    list(treatment = "X", mediator = c("M1", "M2"), interaction = "XM"),
    list(treatment = "X", mediator = c("M1", "M2"), outcome = "X")
  )
  for (args in refused) {
    expect_error(do.call(extract_mediation, c(list(f), args)), "FIML extraction supports only")
  }
  # a simple three-variable fit does not extract two mediators, and a parallel fit is not a simple mediation
  d3 <- p2_data()
  f3 <- fit_sem("M1 ~ X\nY ~ M1 + X", d3[, c("X", "M1", "Y")], missing = "fiml", fixed_x = FALSE)
  expect_error(extract_mediation(f3, treatment = "X", mediator = c("M1", "M2")), "FIML extraction supports only")
  expect_s3_class(extract_mediation(f3, treatment = "X", mediator = "M1"), "medfit::FIMLMediationData")
})

test_that("downstream consumers refuse the extracted parallel object exactly as a simple FIML object", {
  f <- p2_fit()
  m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  expect_true(.sem_fiml_is(m))
  expect_error(bootstrap_mediation(function(x) 1, mediation_data = m), "FIML")
  expect_error(confint(m, method = "boot"), "FIML")
  expect_error(pm(m), "FIML")
  expect_error(generics::glance(m), "FIML")
  expect_error(quick(m), "requires a MediationData")
  expect_identical(attr(generics::tidy(m), "fit_context")$mediators, c("M1", "M2"))
  expect_output(print(m), "FIML")
  # the validator rejects a tampered object
  expect_error(FIMLParallelMediationData(
    a_paths = m@a_paths * 2, b_paths = m@b_paths, c_prime = m@c_prime, estimates = m@estimates, vcov = m@vcov,
    sigma_mediators = m@sigma_mediators, sigma_y = m@sigma_y, treatment = m@treatment, mediators = m@mediators,
    outcome = m@outcome, mediator_predictors = m@mediator_predictors, outcome_predictors = m@outcome_predictors,
    data = m@data, n_obs = m@n_obs, converged = m@converged, source_package = m@source_package,
    fit_context = m@fit_context
  ), "fit_context")
})

# ---- everything else is refused, at prepare, fit, extraction and both source-fit methods -----------------------------

p2_unadmitted <- c(
  # a free label-less `M1 ~~ M2` is admitted from slice 2 (test-fiml-g2-residual-covariance.R)
  labeled_residual_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ c*M2",
  implicit_independence = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X",
  duplicate_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nM2 ~~ 0*M1",
  fixed_nonzero_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0.2*M2",
  serial = "M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2",
  serial_without_direct = "M1 ~ X\nM2 ~ M1\nY ~ M2 + X",
  one_mediator_only_to_y = "M1 ~ X\nM2 ~ X\nY ~ M1 + X\nM1 ~~ 0*M2",
  mediator_without_a_path = "M1 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2",
  three_mediators = "M1 ~ X\nM2 ~ X\nM3 ~ X\nY ~ M1 + M2 + M3 + X",
  covariate_with_parallel = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0*M2",
  mediator_outcome_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nM1 ~~ Y",
  mediator_outcome_covariance_2 = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nM2 ~~ Y",
  fixed_nonzero_direct = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + 0.5*X\nM1 ~~ 0*M2",
  fixed_zero_a_path = "M1 ~ 0*X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2",
  fixed_zero_b_path = "M1 ~ X\nM2 ~ X\nY ~ 0*M1 + M2 + X\nM1 ~~ 0*M2",
  fixed_nonzero_b_path = "M1 ~ X\nM2 ~ X\nY ~ 0.3*M1 + M2 + X\nM1 ~~ 0*M2",
  tied_a_paths = "M1 ~ p*X\nM2 ~ p*X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2",
  tied_b_paths = "M1 ~ X\nM2 ~ X\nY ~ q*M1 + q*M2 + X\nM1 ~~ 0*M2",
  equality_constraint = "M1 ~ a1*X\nM2 ~ a2*X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\na1 == a2",
  defined_parameter = "M1 ~ a1*X\nM2 ~ a2*X\nY ~ b1*M1 + b2*M2 + X\nM1 ~~ 0*M2\nab := a1*b1",
  bounded_start = "M1 ~ start(.5)*X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2",
  interaction = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X + M1:X\nM1 ~~ 0*M2",
  fixed_variance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nM1 ~~ 1*M1",
  mediators_swapped_roles = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2\nX ~~ M1"
)
p2_refusal_data <- function() {
  d <- p2_data()
  set.seed(17L)
  d$Z <- stats::rnorm(nrow(d))
  d$M3 <- .3 * d$X + stats::rnorm(nrow(d))
  d
}

test_that("every other topology and policy is refused at fit before the kernel", {
  reached <- character()
  testthat::local_mocked_bindings(
    .sem_fiml_prepare = function(...) {
      reached <<- c(reached, "prepare")
      stop("prepare reached")
    },
    .sem_fiml_prepare_core = function(...) {
      reached <<- c(reached, "core")
      stop("core reached")
    },
    .sem_fiml_fit = function(...) {
      reached <<- c(reached, "fit")
      stop("kernel reached")
    },
    .sem_fiml_solve = function(...) {
      reached <<- c(reached, "solve")
      stop("solve reached")
    }
  )
  d <- p2_refusal_data()
  for (nm in names(p2_unadmitted)) {
    e <- tryCatch(fit_sem(p2_unadmitted[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
    expect_false(grepl("reached", conditionMessage(e)), info = nm)
    # the parser rejects a covariance written twice, and the product rules reject a product with a residual
    # covariance, both before any FIML rule applies
    expect_error(.sem_fiml_model(p2_unadmitted[[nm]]),
                 class = if (nm %in% c("duplicate_covariance", "interaction")) NULL else "medfit_sem_fiml_error",
                 info = nm)
  }
  expect_identical(reached, character())
})

test_that("the prepare layer and the input checks refuse the wrong shapes", {
  d <- p2_data()
  # the three-variable prepare takes no four-column data; the two-mediator tables take only X, M1, M2, Y
  expect_error(.sem_fiml_prepare(as.matrix(d)), class = "medfit_sem_fiml_error")
  tables <- .sem_fiml_tables_med(2L, TRUE)
  expect_error(.sem_fiml_prepare_core(as.matrix(d[, c("X", "M1", "Y")]), tables), "invalid FIML input")
  bad <- as.matrix(d)
  colnames(bad) <- c("X", "M", "M2", "Y")
  expect_error(.sem_fiml_prepare_core(bad, tables), "invalid FIML input")
  expect_error(.sem_fiml_prepare_core(as.matrix(d)[, c("X", "M2", "M1", "Y")], tables), "invalid FIML input")
  expect_type(.sem_fiml_prepare_core(as.matrix(d), tables), "list")
  expect_error(fit_sem(p2_models[["free"]], d, missing = "fiml"), "fixed_x")
  expect_error(fit_sem(p2_models[["free"]], d, missing = "fiml", fixed_x = TRUE), "fixed_x")
  expect_error(fit_sem(p2_models[["free"]], d, missing = "fiml", fixed_x = FALSE, weights = rep(1, nrow(d))),
               class = "medfit_sem_fiml_error")
  d1 <- d
  d1$M2 <- factor(sample(c("a", "b"), nrow(d), TRUE))
  expect_error(p2_fit(d1), class = "medfit_sem_fiml_error")
  d2 <- d
  d2$M1[3L] <- Inf
  expect_error(p2_fit(d2), class = "medfit_sem_fiml_error")
  d3 <- d[, c("X", "M1", "Y")]
  expect_error(p2_fit(d3), "absent from data")
  d4 <- d
  d4$M2 <- 1
  e <- tryCatch(p2_fit(d4), error = identity)
  expect_s3_class(e, "medfit_sem_fiml_error")
  expect_identical(e$stage, "input")
})

test_that("both source-fit methods stay refused for parallel fits, behind the guard and behind it", {
  f <- p2_fit()
  set.seed(3L)
  before <- .Random.seed
  for (m in c("parametric", "nonparametric")) {
    expect_error(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L),
                 class = "medfit_error_fiml_inference_unavailable")
  }
  testthat::local_mocked_bindings(.fiml_source_inference_admitted = function() TRUE)
  refit_calls <- 0L
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    refit_calls <<- refit_calls + 1L
    stop("refit reached")
  })
  for (m in c("parametric", "nonparametric")) {
    e <- tryCatch(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L), error = identity)
    expect_s3_class(e, "medfit_error_fiml_parallel_source_fit")
    expect_match(conditionMessage(e), "parallel")
  }
  expect_identical(refit_calls, 0L)
  expect_identical(.Random.seed, before)
  # the zero-direct and omitted-direct parallel fits are refused the same way
  for (variant in c("zero", "omitted")) {
    fv <- p2_fit(p2_data(direct = FALSE), p2_models[[variant]])
    e <- tryCatch(bootstrap_mediation(source_fit = fv, effect = "te", method = "parametric", n_boot = 3L),
                  error = identity)
    expect_s3_class(e, "medfit_error_fiml_parallel_source_fit")
  }
})

# ---- planted defects ------------------------------------------------------------------------------------------------

p2_kernel_gap <- function(d, ref, tables) {
  p <- .sem_fiml_prepare_core(as.matrix(d), tables)
  fit <- .sem_fiml_solve(p)
  e <- fit$estimate
  map <- c(a1 = "M1~X", a2 = "M2~X", b1 = "Y~M1", b2 = "Y~M2", cp = "Y~X", vx = "X~~X", vm1 = "M1~~M1",
           vm2 = "M2~~M2", vy = "Y~~Y", ix = "X~1", im1 = "M1~1", im2 = "M2~1", iy = "Y~1")
  shared <- intersect(names(e), names(map))
  est_gap <- max(abs(e[shared] - lavaan::coef(ref)[map[shared]]))
  max(est_gap, abs(-fit$nll - as.numeric(lavaan::logLik(ref))))
}

test_that("the oracles catch planted defects: dropped M2 -> Y path, untransported covariance, wrong wiring, swap", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  d <- p2_data()
  ref <- p2_lavaan(d, p2_models[["free"]])
  # positive control: the unmutated tables pass
  expect_lt(p2_kernel_gap(d, ref, .sem_fiml_tables_med(2L, TRUE)), 1e-5)
  # D-a: M2 -> Y dropped (the second mediator bypasses the outcome equation)
  tab <- .sem_fiml_tables_med(2L, TRUE)
  tab$a <- tab$a[tab$a$label != "b2", , drop = FALSE]
  expect_gt(p2_kernel_gap(d, ref, tab), 1e-3)
  # D-b: the covariance is not carried back to the original scale
  f <- p2_fit(d)
  slv <- sem_mutate(
    .sem_fiml_solve, "V <- p$transport %*% solve(H) %*% t(p$transport)",
    "V <- solve(H); dimnames(V) <- list(ram$par_names, ram$par_names)"
  )
  fb <- testthat::with_mocked_bindings(p2_fit(d), .sem_fiml_solve = slv)
  idx <- match(names(coef(f)), names(lavaan::coef(ref)))
  expect_lt(p2_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
  expect_gt(p2_rel_gap(vcov(fb), lavaan::vcov(ref)[idx, idx]), 1e-2)
  # D-c: c' wired to the wrong path (b1) in the public extraction
  ext <- sem_mutate(.sem_fiml_extract_parallel, "unname(map[\"cp\"])", "unname(map[\"b1\"])")
  mb <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")),
                                       .sem_fiml_extract_parallel = ext)
  expect_gt(abs(mb@c_prime - coef(f)[["Y~X"]]), 1e-3)
  # D-d: a1 and a2 swapped in the alias map (the products pair the wrong a with b)
  swp <- sem_mutate(.sem_fiml_extract_parallel, "a_aliases <- map[paste0(\"a\", i)]",
                    "a_aliases <- rev(map[paste0(\"a\", i)])")
  ms <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")),
                                       .sem_fiml_extract_parallel = swp)
  m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  expect_gt(abs(as.numeric(nie(ms)) - as.numeric(nie(m))), .05)
  expect_gt(abs(ms@a_paths[[1]] - coef(f)[["M1~X"]]), .1)
})

test_that("the oracles catch the dropped cross-path covariance in the sum's standard error", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  d <- p2_data(direct = FALSE)
  f <- p2_fit(d, p2_models[["zero"]])
  ref <- p2_lavaan(d, p2_lavaan_labeled("zero"))
  pe <- lavaan::parameterEstimates(ref)
  target <- pe$se[pe$label == "tot"]
  m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  se_of <- function(x) generics::tidy(x, type = "effects")$std_error[1L]
  # positive control: the unmutated extraction matches lavaan
  expect_equal(se_of(m), target, tolerance = 2e-3)
  # lm-style defect: only Cov(a1, a2) and Cov(b1, b2) dropped
  lm_style <- sem_mutate(
    .sem_fiml_extract_parallel,
    "V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]",
    paste0("V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]; ",
           "V[\"a1\", \"a2\"] <- V[\"a2\", \"a1\"] <- 0; V[\"b1\", \"b2\"] <- V[\"b2\", \"b1\"] <- 0")
  )
  m_lm <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")),
                                         .sem_fiml_extract_parallel = lm_style)
  # full defect: the whole cross-mediator block (a1, b1) x (a2, b2) dropped
  block <- sem_mutate(
    .sem_fiml_extract_parallel,
    "V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]",
    paste0("V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]; ",
           "V[c(\"a1\", \"b1\"), c(\"a2\", \"b2\")] <- 0; V[c(\"a2\", \"b2\"), c(\"a1\", \"b1\")] <- 0")
  )
  m_blk <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")),
                                          .sem_fiml_extract_parallel = block)
  expect_gt(abs(se_of(m_lm) - target) / target, .02)
  expect_gt(abs(se_of(m_blk) - target) / target, .02)
  expect_lt(abs(se_of(m) - target) / target, 2e-3)
})
