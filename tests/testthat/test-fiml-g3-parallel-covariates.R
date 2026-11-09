# FI-G2, slices 3 and 4: bounded Gaussian FIML for PARALLEL mediation (two mediators) with one or two observed
# covariates, in both residual forms (`M1 ~~ 0*M2` written, or the free, label-less `M1 ~~ M2`), each with the direct
# path free or fixed exactly at zero. Random X: X, Z (or Z1, Z2), M1, M2, Y are jointly Gaussian with a free exogenous
# covariance. Oracles, each independent of the production kernel: matched lavaan raw-data FIML (including the := products,
# their SUM and the total), a from-scratch rowwise Gaussian likelihood with an independent Hessian, closed-form
# complete-data OLS, and OpenMx for one cell. Helpers are prefixed p4_ and self-contained.

p4_ks <- 1L # lifted to 1:2 with slice 4
p4_exo <- function(k) c("X", if (k == 1L) "Z" else c("Z1", "Z2"))
p4_kvars <- function(k) c(p4_exo(k), "M1", "M2", "Y")
p4_data <- function(k = 1L, kind = "mar", n = 450L, direct = TRUE, seed = 6141L, rho = .5) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  z1 <- 1 + .4 * x + stats::rnorm(n, sd = 1.2)
  z2 <- -.5 + .3 * x - .35 * z1 + stats::rnorm(n, sd = 1.1)
  zz <- if (k == 1L) list(z1) else list(z1, z2)
  zc <- function(w) Reduce(`+`, Map(`*`, w[seq_along(zz)], zz))
  e <- stats::rnorm(n)
  m1 <- .3 + .9 * x + zc(c(.4, -.25)) + .5 * (sqrt(rho) * e + sqrt(1 - rho) * stats::rnorm(n))
  m2 <- -.2 + .6 * x + zc(c(-.3, .2)) + .5 * (sqrt(rho) * e + sqrt(1 - rho) * stats::rnorm(n))
  y <- .2 + .7 * m1 + .3 * m2 + (if (direct) .25 else 0) * x + zc(c(.3, -.2)) + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x)
  for (i in seq_along(zz)) d[[p4_exo(k)[i + 1L]]] <- zz[[i]]
  d$M1 <- m1
  d$M2 <- m2
  d$Y <- y
  if (kind == "mar") {
    # every variable can be incomplete; the mediators and Y depend (ignorably) on the observed X
    for (v in p4_exo(k)) d[stats::runif(n) < .08, v] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.3 - .5 * x), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind == "sparse") {
    # single-variable, pair and both-mediator patterns in disjoint row blocks plus one all-empty row
    z <- p4_exo(k)[2L]
    d[1:20, "X"] <- NA_real_
    d[21:40, z] <- NA_real_
    d[41:60, "M1"] <- NA_real_
    d[61:80, "M2"] <- NA_real_
    d[81:100, "Y"] <- NA_real_
    d[101:115, c("M1", "M2")] <- NA_real_
    d[116:125, c("X", z)] <- NA_real_
    d[126:135, c("M2", "Y")] <- NA_real_
    d[136L, ] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
# model text: `direct` free or the treatment's Y path fixed at 0; `resid` the written mediator residual covariance
p4_model <- function(k = 1L, direct = TRUE, resid = "free", exo = p4_exo(k), labels = FALSE, cov_written = FALSE) {
  x <- exo[1L]
  z <- exo[-1L]
  lab <- function(l, v) if (labels) paste0(l, "*", v) else v
  m1 <- paste(c(lab("a1", x), z), collapse = " + ")
  m2 <- paste(c(lab("a2", x), z), collapse = " + ")
  y <- paste(c(lab("b1", "M1"), lab("b2", "M2"), if (direct) lab("cp", x) else paste0("0*", x), z), collapse = " + ")
  paste0(
    "M1 ~ ", m1, "\nM2 ~ ", m2, "\nY ~ ", y, "\n", if (resid == "free") "M1 ~~ M2" else "M1 ~~ 0*M2",
    if (cov_written) paste0("\n", paste(exo[utils::combn(length(exo), 2L)[1L, ]], "~~",
                                         exo[utils::combn(length(exo), 2L)[2L, ]], collapse = "\n"))
  )
}
p4_fit <- function(d, model) fit_sem(model, d, missing = "fiml", fixed_x = FALSE)
p4_lavaan <- function(d, model) {
  suppressWarnings(lavaan::sem(model, d, missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
                               information = "observed", control = list(rel.tol = 1e-10)))
}
# lavaan model with labels and defined parameters: the two products, their SUM, the total (and te with a direct path)
p4_lavaan_labeled <- function(k, direct, resid, exo = p4_exo(k)) {
  paste0(p4_model(k, direct, resid, exo, labels = TRUE), "\nind1 := a1*b1\nind2 := a2*b2\ntot := a1*b1 + a2*b2",
         if (direct) "\nte := cp + a1*b1 + a2*b2")
}
p4_rel_gap <- function(V, ref) max(abs(V - ref) / sqrt(outer(diag(ref), diag(ref))))
p4_n_par <- function(k, direct, resid) 12L + 5L * k + choose(k + 1L, 2L) + direct + (resid == "free")
# lavaan writes an exogenous covariance in its own order: match by the unordered pair
p4_key <- function(nm) {
  vapply(strsplit(nm, "~~", fixed = TRUE), function(p) {
    if (length(p) == 2L) paste(sort(p), collapse = "~~") else paste(p, collapse = "")
  }, character(1))
}
p4_align <- function(ref_coef, q) ref_coef[match(p4_key(names(q)), p4_key(names(ref_coef)))]
p4_variants <- expand.grid(direct = c(TRUE, FALSE), resid = c("free", "ind"), stringsAsFactors = FALSE)

# ---- independent rowwise likelihood ---------------------------------------------------------------------------------
p4_moments <- function(q, k) {
  vars <- p4_kvars(k)
  nv <- length(vars)
  exo <- p4_exo(k)
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  gc <- function(a, b) if (paste0(a, "~~", b) %in% names(q)) q[[paste0(a, "~~", b)]] else g(paste0(b, "~~", a))
  B <- matrix(0, nv, nv, dimnames = list(vars, vars))
  for (r in c("M1", "M2", "Y")) for (p in setdiff(vars, r)) B[r, p] <- g(paste0(r, "~", p))
  B["M1", "M2"] <- B["M2", "M1"] <- B["M1", "Y"] <- B["M2", "Y"] <- 0
  psi <- diag(vapply(vars, function(v) g(paste0(v, "~~", v)), numeric(1)))
  dimnames(psi) <- list(vars, vars)
  psi["M1", "M2"] <- psi["M2", "M1"] <- gc("M1", "M2")
  for (i in seq_along(exo)) for (j in seq_along(exo)) {
    if (i < j) psi[exo[i], exo[j]] <- psi[exo[j], exo[i]] <- gc(exo[i], exo[j])
  }
  A <- solve(diag(nv) - B)
  list(mu = drop(A %*% vapply(vars, function(v) g(paste0(v, "~1")), numeric(1))), sigma = A %*% psi %*% t(A))
}
p4_nll <- function(d, q, k) gk_row_nll(as.matrix(d[, p4_kvars(k)]), p4_moments(q, k))
p4_hessian <- function(f, q) {
  units <- pmax(abs(q), 1)
  v <- grep("~~", names(q))
  units[v] <- pmin(units[v], pmax(abs(q[v]), 1e-3) / 10)
  f0 <- f(q)
  H <- fo_richardson(lapply(.02 / 2^(0:2), function(delta) {
    H <- matrix(0, length(q), length(q))
    for (j in seq_along(q)) {
      ej <- q * 0
      ej[j] <- units[j] * delta
      H[j, j] <- (f(q + ej) - 2 * f0 + f(q - ej)) / ej[j]^2
      if (j > 1L) {
        for (kk in seq_len(j - 1L)) {
          ek <- q * 0
          ek[kk] <- units[kk] * delta
          H[j, kk] <- H[kk, j] <- (f(q + ej + ek) - f(q + ej - ek) - f(q - ej + ek) + f(q - ej - ek)) /
            (4 * ej[j] * ek[kk])
        }
      }
    }
    H
  }))
  (H + t(H)) / 2
}
# independent delta-method SEs of the two products and their sum from an extracted object's covariance
p4_delta <- function(m) {
  V <- m@vcov
  a <- m@a_paths
  b <- m@b_paths
  se <- function(g) sqrt(drop(t(g) %*% V[names(g), names(g)] %*% g))
  list(
    ind1 = se(c(a1 = b[[1]], b1 = a[[1]])), ind2 = se(c(a2 = b[[2]], b2 = a[[2]])),
    sum = se(c(a1 = b[[1]], a2 = b[[2]], b1 = a[[1]], b2 = a[[2]]))
  )
}
p4_extract <- function(f, ...) extract_mediation(f, treatment = "X", mediator = c("M1", "M2"), ...)

# ---- tables ---------------------------------------------------------------------------------------------------------

test_that("the frozen pre-slice-3 tables are identical() to the current output", {
  before <- readRDS(test_path("fixtures", "fiml-tables-before-g2s3.rds"))
  for (d in c(TRUE, FALSE)) {
    expect_identical(.sem_fiml_tables_med(1L, d), before[[paste0("med1", d)]])
    expect_identical(.sem_fiml_tables_med(2L, d), before[[paste0("med2", d)]])
    expect_identical(.sem_fiml_tables_med(2L, d, residual_covariance = FALSE, k = 0L), before[[paste0("med2", d)]])
    expect_identical(.sem_fiml_tables_med(2L, d, TRUE), before[[paste0("medrc2", d)]])
    expect_identical(.sem_fiml_tables_med(2L, d, TRUE, 0L), before[[paste0("medrc2", d)]])
    for (kk in 1:2) expect_identical(.sem_fiml_tables_cov(kk, d), before[[paste0("cov", kk, d)]])
  }
})

test_that("the parallel covariate tables have the documented variables, labels and parameter counts", {
  for (direct in c(TRUE, FALSE)) for (rc in c(FALSE, TRUE)) {
    t1 <- .sem_fiml_tables_med(2L, direct, rc, k = 1L)
    expect_identical(t1$vars, c("X", "Z", "M1", "M2", "Y"))
    lay <- .sem_fiml_layout(t1)
    expect_identical(nrow(lay$covariances), 1L + rc)
    n_free <- sum(is.na(t1$a$value)) + sum(is.na(t1$s$value)) + sum(is.na(t1$m$value))
    expect_identical(n_free, p4_n_par(1L, direct, if (rc) "free" else "ind"))
    expect_true(all(c("a1", "a2", "b1", "b2", "vm1", "vm2", "vy") %in% c(t1$a$label, t1$s$label)))
    expect_identical(sum(t1$a$row == "M1"), 2L)
    expect_identical(sum(t1$a$row == "M2"), 2L)
    expect_identical(sum(t1$a$row == "Y"), 4L) # M1, M2, X (value 0 when fixed) and Z
  }
  expect_error(.sem_fiml_tables_med(1L, TRUE, FALSE, k = 1L), class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_tables_med(2L, TRUE, FALSE, k = 3L), class = "medfit_sem_fiml_error")
})

test_that("the parameter map has exact names and targets for the admitted models", {
  expect_identical(
    names(.sem_fiml_model(p4_model(1L, TRUE, "free"))$map),
    c("a1", "a2", "gm1z1", "gm2z1", "b1", "b2", "cp", "gy", "vx", "vz", "vm1", "vm2", "vy", "cxz", "cm12",
      "ix", "iz", "im1", "im2", "iy")
  )
  s <- .sem_fiml_model(p4_model(1L, FALSE, "ind"))
  expect_identical(
    names(s$map),
    c("a1", "a2", "gm1z1", "gm2z1", "b1", "b2", "gy", "vx", "vz", "vm1", "vm2", "vy", "cxz", "ix", "iz",
      "im1", "im2", "iy")
  )
  expect_identical(
    unname(s$map),
    c("M1~X", "M2~X", "M1~Z", "M2~Z", "Y~M1", "Y~M2", "Y~Z", "X~~X", "Z~~Z", "M1~~M1", "M2~~M2", "Y~~Y", "X~~Z",
      "X~1", "Z~1", "M1~1", "M2~1", "Y~1")
  )
  expect_identical(unname(s$covariate), "Z")
  expect_identical(unname(s$vars), c("X", "M1", "M2", "Y"))
  expect_identical(unname(s$mediators), c("M1", "M2"))
  # the zero policy: the treatment is the variable whose Y path is fixed; written exogenous order does not matter
  s2 <- .sem_fiml_model("M1 ~ Z + X\nM2 ~ Z + X\nY ~ M1 + M2 + 0*X + Z\nM1 ~~ M2")
  expect_identical(unname(s2$vars["X"]), "X")
  expect_identical(unname(s2$covariate), "Z")
  s3 <- .sem_fiml_model("M1 ~ Z + X\nM2 ~ Z + X\nY ~ M1 + M2 + X + 0*Z\nM1 ~~ M2")
  expect_identical(unname(s3$vars["X"]), "Z")
  expect_identical(unname(s3$covariate), "X")
})

# ---- fit versus lavaan ----------------------------------------------------------------------------------------------

test_that("parallel covariate FIML matches lavaan: estimates, covariance, logLik, products, SUM, te and SEs", {
  skip_if_not_installed("lavaan")
  for (k in p4_ks) for (i in seq_len(nrow(p4_variants))) {
    direct <- p4_variants$direct[i]
    resid <- p4_variants$resid[i]
    info <- paste(k, direct, resid)
    d <- p4_data(k, direct = direct)
    model <- p4_model(k, direct, resid)
    f <- p4_fit(d, model)
    ref <- p4_lavaan(d, model)
    q <- coef(f)
    expect_length(q, p4_n_par(k, direct, resid))
    expect_identical(length(lavaan::coef(ref)), p4_n_par(k, direct, resid), info = info)
    expect_setequal(p4_key(names(q)), p4_key(names(lavaan::coef(ref))))
    rq <- p4_align(lavaan::coef(ref), q)
    expect_lt(max(abs(q - rq)), 1e-5)
    idx <- match(p4_key(names(q)), p4_key(names(lavaan::coef(ref))))
    expect_lt(p4_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
    expect_lt(abs(as.numeric(stats::logLik(f)) - as.numeric(lavaan::logLik(ref))), 1e-6)
    expect_identical(attr(stats::logLik(f), "df"), p4_n_par(k, direct, resid))
    rl <- p4_lavaan(d, p4_lavaan_labeled(k, direct, resid))
    pe <- lavaan::parameterEstimates(rl)
    pe <- pe[pe$op == ":=", ]
    m <- p4_extract(f)
    expect_s3_class(m, "medfit::FIMLParallelMediationData")
    expect_equal(as.numeric(nie(m)), pe$est[pe$label == "tot"], tolerance = 1e-5)
    expect_equal(m@a_paths[[1]] * m@b_paths[[1]], pe$est[pe$label == "ind1"], tolerance = 1e-5)
    expect_equal(m@a_paths[[2]] * m@b_paths[[2]], pe$est[pe$label == "ind2"], tolerance = 1e-5)
    dl <- p4_delta(m)
    expect_equal(dl$ind1, pe$se[pe$label == "ind1"], tolerance = 2e-3)
    expect_equal(dl$ind2, pe$se[pe$label == "ind2"], tolerance = 2e-3)
    expect_equal(dl$sum, pe$se[pe$label == "tot"], tolerance = 2e-3)
    tt <- generics::tidy(m, type = "effects")
    expect_equal(tt$std_error[tt$term == "nie"], dl$sum, tolerance = 1e-8)
    if (direct) {
      expect_equal(as.numeric(te(m)), pe$est[pe$label == "te"], tolerance = 1e-5)
      expect_equal(tt$std_error[tt$term == "te"], pe$se[pe$label == "te"], tolerance = 2e-3)
    } else {
      expect_identical(unname(m@c_prime), 0)
    }
    # the full path covariance, covariates not mistaken for paths
    nm <- c("a1", "a2", "b1", "b2", if (direct) "c_prime")
    ln <- c("a1", "a2", "b1", "b2", if (direct) "cp")
    expect_lt(p4_rel_gap(m@vcov[nm, nm], lavaan::vcov(rl)[ln, ln]), 1e-3)
    expect_equal(unname(m@a_paths), unname(q[c("M1~X", "M2~X")]))
    expect_equal(unname(m@b_paths), unname(q[c("Y~M1", "Y~M2")]))
    expect_false(any(c("a1", "a2") %in% names(q)))
    expect_identical(m@fit_context$covariate, p4_exo(k)[-1L])
    expect_identical(m@mediator_predictors, list(p4_exo(k), p4_exo(k)))
  }
})

test_that("a written exogenous covariance (either order) is the automatic one; a swapped mediator request keeps the sum", {
  d <- p4_data(1L)
  f <- p4_fit(d, p4_model(1L))
  fw <- p4_fit(d, p4_model(1L, cov_written = TRUE))
  fs <- p4_fit(d, paste0(p4_model(1L), "\nZ ~~ X"))
  expect_equal(unname(coef(fw)), unname(coef(f)))
  expect_equal(unname(coef(fs)), unname(coef(f)))
  m <- extract_mediation(f, treatment = "X", mediator = c("M2", "M1"))
  m1 <- p4_extract(f)
  expect_equal(as.numeric(nie(m)), as.numeric(nie(m1)))
  expect_equal(generics::tidy(m, type = "effects")$std_error, generics::tidy(m1, type = "effects")$std_error)
  expect_no_error(p4_extract(f, structure = "parallel"))
})

test_that("a covariate may be named the treatment with a free direct path; it matches lavaan with that role", {
  skip_if_not_installed("lavaan")
  d <- p4_data(1L)
  f <- p4_fit(d, p4_model(1L, TRUE, "free"))
  m <- extract_mediation(f, treatment = "Z", mediator = c("M1", "M2"))
  expect_s3_class(m, "medfit::FIMLParallelMediationData")
  expect_identical(m@treatment, "Z")
  expect_identical(m@fit_context$covariate, "X")
  expect_identical(unname(m@fit_context$variables["X"]), "Z")
  rl <- p4_lavaan(d, p4_lavaan_labeled(1L, TRUE, "free", exo = c("Z", "X")))
  pe <- lavaan::parameterEstimates(rl)
  pe <- pe[pe$op == ":=", ]
  expect_equal(as.numeric(nie(m)), pe$est[pe$label == "tot"], tolerance = 1e-5)
  expect_equal(as.numeric(te(m)), pe$est[pe$label == "te"], tolerance = 1e-5)
  tt <- generics::tidy(m, type = "effects")
  expect_equal(tt$std_error[tt$term == "nie"], pe$se[pe$label == "tot"], tolerance = 2e-3)
  expect_equal(tt$std_error[tt$term == "te"], pe$se[pe$label == "te"], tolerance = 2e-3)
  expect_equal(unname(m@a_paths), unname(coef(f)[c("M1~Z", "M2~Z")]))
  expect_equal(m@c_prime, coef(f)[["Y~Z"]], ignore_attr = TRUE)
  expect_lt(p4_rel_gap(m@vcov[c("a1", "a2", "b1", "b2", "c_prime"), c("a1", "a2", "b1", "b2", "c_prime")],
                       lavaan::vcov(rl)[c("a1", "a2", "b1", "b2", "cp"), c("a1", "a2", "b1", "b2", "cp")]), 1e-3)
  # the fixed-zero fit names only X as the treatment
  fz <- p4_fit(p4_data(1L, direct = FALSE), p4_model(1L, FALSE, "free"))
  expect_error(extract_mediation(fz, treatment = "Z", mediator = c("M1", "M2")),
               class = "medfit_error_fiml_extract_unsupported")
})

# ---- rowwise likelihood, stationarity and Hessian -------------------------------------------------------------------

test_that("parallel covariate FIML equals the rowwise likelihood oracle and is a stationary point", {
  for (k in p4_ks) for (i in seq_len(nrow(p4_variants))) {
    direct <- p4_variants$direct[i]
    resid <- p4_variants$resid[i]
    d <- p4_data(k, direct = direct)
    f <- p4_fit(d, p4_model(k, direct, resid))
    q <- coef(f)
    nll <- function(x) p4_nll(d, stats::setNames(x, names(q)), k)
    expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
    grad <- vapply(seq_along(q), function(j) {
      fo_richardson(lapply(.02 / 2^(0:3), function(h) {
        e <- q * 0
        e[j] <- h * max(abs(q[j]), 1)
        (nll(q + e) - nll(q - e)) / (2 * e[j])
      }))
    }, numeric(1))
    expect_lt(max(abs(grad)), 1e-4)
  }
})

test_that("the observed-information covariance agrees with an independent numerical Hessian", {
  skip_on_cran()
  for (k in p4_ks) for (i in c(1L, 4L)) { # (free direct, free covariance) and (zero direct, independent)
    direct <- p4_variants$direct[i]
    resid <- p4_variants$resid[i]
    d <- p4_data(k, direct = direct, n = 200L)
    f <- p4_fit(d, p4_model(k, direct, resid))
    q <- coef(f)
    nll <- function(x) p4_nll(d[rowSums(!is.na(d)) > 0L, ], stats::setNames(x, names(q)), k)
    expect_lt(p4_rel_gap(vcov(f), solve(p4_hessian(nll, q))), 2e-3)
  }
})

test_that("a sparse pattern sweep with both-mediator gaps and an all-empty row keeps every pattern", {
  skip_if_not_installed("lavaan")
  for (k in p4_ks) for (resid in c("free", "ind")) {
    d <- p4_data(k, "sparse")
    f <- p4_fit(d, p4_model(k, TRUE, resid))
    expect_identical(f@n_dropped, 1L)
    expect_gte(length(f@internals$likelihood$rows$patterns), 8L)
    expect_true(any(vapply(f@internals$likelihood$rows$patterns, function(p) {
      !any(c("M1", "M2") %in% p$variables) && "Y" %in% p$variables || identical(sort(p$variables), sort(setdiff(
        p4_kvars(k), c("M1", "M2"))))
    }, logical(1))))
    ref <- p4_lavaan(d, p4_model(k, TRUE, resid))
    q <- coef(f)
    expect_lt(max(abs(q - p4_align(lavaan::coef(ref), q))), 1e-5)
    nll <- function(x) p4_nll(d[rowSums(!is.na(d)) > 0L, ], stats::setNames(x, names(q)), k)
    expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
  }
})

test_that("complete data: ML estimates are equation-wise OLS, the exogenous ML covariance and the M-residual covariance", {
  for (k in p4_ks) for (i in seq_len(nrow(p4_variants))) {
    direct <- p4_variants$direct[i]
    resid <- p4_variants$resid[i]
    d <- p4_data(k, "complete", direct = direct)
    f <- p4_fit(d, p4_model(k, direct, resid))
    q <- coef(f)
    n <- nrow(d)
    rhs <- function(v) paste(v, collapse = " + ")
    z <- p4_exo(k)[-1L]
    l1 <- stats::lm(stats::reformulate(p4_exo(k), "M1"), d)
    l2 <- stats::lm(stats::reformulate(p4_exo(k), "M2"), d)
    ly <- stats::lm(stats::reformulate(c("M1", "M2", if (direct) "X", z), "Y"), d)
    for (v in p4_exo(k)) {
      expect_equal(q[[paste0("M1~", v)]], stats::coef(l1)[[v]], tolerance = 1e-6)
      expect_equal(q[[paste0("M2~", v)]], stats::coef(l2)[[v]], tolerance = 1e-6)
    }
    for (v in c("M1", "M2", if (direct) "X", z)) expect_equal(q[[paste0("Y~", v)]], stats::coef(ly)[[v]], tolerance = 1e-6)
    expect_equal(q[["M1~1"]], stats::coef(l1)[["(Intercept)"]], tolerance = 1e-6)
    expect_equal(q[["Y~1"]], stats::coef(ly)[["(Intercept)"]], tolerance = 1e-6)
    expect_equal(q[["M1~~M1"]], sum(stats::resid(l1)^2) / n, tolerance = 1e-6)
    expect_equal(q[["M2~~M2"]], sum(stats::resid(l2)^2) / n, tolerance = 1e-6)
    expect_equal(q[["Y~~Y"]], sum(stats::resid(ly)^2) / n, tolerance = 1e-6)
    S <- stats::cov(d[, p4_exo(k)]) * (n - 1) / n
    expect_equal(q[["X~~X"]], S[1, 1], tolerance = 1e-6)
    expect_equal(q[["X~1"]], mean(d$X), tolerance = 1e-6)
    expect_equal(unname(q[[grep("^X~~Z", names(q), value = TRUE)[1L]]]), S[1, 2], tolerance = 1e-6)
    if (resid == "free") {
      expect_equal(q[["M1~~M2"]], sum(stats::resid(l1) * stats::resid(l2)) / n, tolerance = 1e-6)
      # the M1 and M2 coefficient blocks covary as Sigma_12 (W'W)^-1
      V <- vcov(f)
      w <- cbind(1, as.matrix(d[, p4_exo(k)]))
      nm1 <- c("M1~1", paste0("M1~", p4_exo(k)))
      nm2 <- c("M2~1", paste0("M2~", p4_exo(k)))
      S12 <- q[["M1~~M2"]]
      expect_equal(V[nm1, nm2], S12 * solve(crossprod(w)), tolerance = 1e-4, ignore_attr = TRUE)
    } else {
      expect_equal(unname(q[["M1~X"]]), unname(stats::coef(l1)[["X"]]), tolerance = 1e-6)
    }
  }
})

# ---- OpenMx, one cell ------------------------------------------------------------------------------------------------

test_that("OpenMx raw-data FIML agrees on the free-covariance, free-direct cell with one covariate", {
  skip_on_cran()
  skip_if_not_installed("OpenMx")
  d <- p4_data(1L)
  f <- p4_fit(d, p4_model(1L, TRUE, "free"))
  q <- coef(f)
  vars <- p4_kvars(1L)
  paths <- list()
  for (nm in names(q)) {
    if (grepl("~1$", nm)) {
      paths[[nm]] <- OpenMx::mxPath(from = "one", to = sub("~1$", "", nm), arrow = 1, free = TRUE, values = 0, labels = nm)
    } else if (grepl("~~", nm)) {
      p <- strsplit(nm, "~~", fixed = TRUE)[[1L]]
      paths[[nm]] <- OpenMx::mxPath(from = p[1L], to = if (p[1L] == p[2L]) NA else p[2L], arrow = 2, free = TRUE,
                                    values = if (p[1L] == p[2L]) 1 else .1, labels = nm)
    } else {
      p <- strsplit(nm, "~", fixed = TRUE)[[1L]]
      paths[[nm]] <- OpenMx::mxPath(from = p[2L], to = p[1L], arrow = 1, free = TRUE, values = .1, labels = nm)
    }
  }
  mx <- do.call(OpenMx::mxModel, c(
    list("p4", type = "RAM", manifestVars = vars), unname(paths),
    list(OpenMx::mxData(d[rowSums(!is.na(d)) > 0L, vars], type = "raw"))
  ))
  fit <- suppressWarnings(OpenMx::mxTryHard(mx, silent = TRUE, extraTries = 5L))
  expect_true(fit$output$status$code %in% c(0, 1))
  pars <- fit$output$estimate
  expect_lt(max(abs(pars[names(q)] - q)), 5e-4)
  expect_lt(abs(fit$output$Minus2LogLikelihood / 2 - f@internals$likelihood$nll), 1e-5)
  se <- fit$output$standardErrors
  expect_equal(unname(se[names(q), 1L]), unname(sqrt(diag(vcov(f)))), tolerance = 5e-3)
})

# ---- what stays refused ---------------------------------------------------------------------------------------------

p4_refused <- c(
  omitted_independence = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z",
  labeled_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ c*M2",
  fixed_nonzero_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ 0.2*M2",
  bounded_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ start(.1)*M2",
  tied_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ r*M2\nM1 ~~ r*M1",
  constrained_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ cc*M2\ncc == 0.1",
  duplicate_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2\nM2 ~~ M1",
  fixed_exogenous_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2\nX ~~ 0*Z",
  labeled_exogenous_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2\nX ~~ cx*Z",
  duplicate_exogenous_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2\nX ~~ Z\nZ ~~ X",
  covariate_on_one_mediator = "M1 ~ X + Z\nM2 ~ X\nY ~ M1 + M2 + X + Z\nM1 ~~ M2",
  covariate_not_on_y = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X\nM1 ~~ M2",
  omitted_treatment_y_path = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + Z\nM1 ~~ M2",
  both_y_paths_fixed = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + 0*X + 0*Z\nM1 ~~ M2",
  fixed_nonzero_direct = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + 0.5*X + Z\nM1 ~~ M2",
  fixed_zero_covariate_to_mediator = "M1 ~ X + 0*Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2",
  fixed_zero_a_path = "M1 ~ 0*X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2",
  tied_a_paths = "M1 ~ p*X + Z\nM2 ~ p*X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2",
  tied_covariate_paths = "M1 ~ X + p*Z\nM2 ~ X + p*Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2",
  covariate_mediator_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2\nZ ~~ M1",
  mediator_outcome_covariance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2\nM1 ~~ Y",
  serial_with_covariate = "M1 ~ X + Z\nM2 ~ M1 + X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2",
  one_mediator_only_to_y = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + X + Z\nM1 ~~ M2",
  interaction = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z + M1:X\nM1 ~~ M2",
  three_mediators_with_covariate = "M1 ~ X + Z\nM2 ~ X + Z\nM3 ~ X + Z\nY ~ M1 + M2 + M3 + X + Z\nM1 ~~ M2",
  three_covariates = "M1 ~ X + Z + W + V\nM2 ~ X + Z + W + V\nY ~ M1 + M2 + X + Z + W + V\nM1 ~~ M2",
  fixed_variance = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2\nZ ~~ 1*Z"
)
if (!2L %in% p4_ks) {
  p4_refused[["two_covariates_not_yet"]] <- p4_model(2L)
}
p4_refusal_data <- function() {
  d <- p4_data(2L)
  d$Z <- d$Z1
  d$W <- stats::rnorm(nrow(d))
  d$V <- stats::rnorm(nrow(d))
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
  d <- p4_refusal_data()
  for (nm in names(p4_refused)) {
    e <- tryCatch(fit_sem(p4_refused[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
    expect_false(grepl("reached", conditionMessage(e)), info = nm)
    expect_error(.sem_fiml_model(p4_refused[[nm]]), class = "medfit_sem_fiml_error")
  }
  expect_identical(reached, character())
})

test_that("the prepare layer refuses wrong shapes for the covariate tables", {
  d <- p4_data(1L)
  tables <- .sem_fiml_tables_med(2L, TRUE, TRUE, k = 1L)
  expect_error(.sem_fiml_prepare_core(as.matrix(d[, c("X", "M1", "M2", "Y")]), tables), "invalid FIML input")
  expect_error(.sem_fiml_prepare_core(as.matrix(d)[, c("X", "M1", "Z", "M2", "Y")], tables), "invalid FIML input")
  expect_type(.sem_fiml_prepare_core(as.matrix(d), tables), "list")
})

test_that("source-fit inference stays refused for the covariate parallel fits, with no refit and no RNG draw", {
  f <- p4_fit(p4_data(1L), p4_model(1L))
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
    set.seed(99L)
    before <- .Random.seed
    e <- tryCatch(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L), error = identity)
    expect_s3_class(e, "medfit_error_fiml_covariate_source_fit")
    expect_identical(.Random.seed, before)
  }
  expect_identical(refit_calls, 0L)
  fm <- p4_extract(f)
  expect_error(confint(fm, method = "boot"), "FIML")
  expect_error(pm(fm), "FIML")
  expect_error(generics::glance(fm), "FIML")
})

test_that("extraction refusals apply to the covariate parallel fits and are classed", {
  f <- p4_fit(p4_data(1L), p4_model(1L))
  refused <- list(
    list(treatment = "X", mediator = "M1"), list(treatment = "M1", mediator = c("M1", "M2")),
    list(treatment = "X", mediator = c("M1", "M1")), list(treatment = "X", mediator = c("M1", "Z")),
    list(treatment = "X", mediator = c("M1", "M2"), standardized = TRUE),
    list(treatment = "X", mediator = c("M1", "M2"), structure = "serial"),
    list(treatment = "X", mediator = c("M1", "M2"), decomposition = "four_way"),
    list(treatment = "X", mediator = c("M1", "M2"), outcome = "X"),
    list(treatment = c("X", "Z"), mediator = c("M1", "M2")), list(treatment = "Q", mediator = c("M1", "M2"))
  )
  for (args in refused) {
    expect_error(do.call(extract_mediation, c(list(f), args)), class = "medfit_error_fiml_extract_unsupported")
  }
})

# ---- planted defects with positive controls --------------------------------------------------------------------------

p4_label_key <- function(k) {
  tb <- .sem_fiml_tables_med(2L, TRUE, TRUE, k = k)
  keys <- c(
    paste0(tb$a$row, "~", tb$a$col), paste0(tb$s$row, "~~", tb$s$col), paste0(tb$m$row, "~1")
  )
  stats::setNames(keys, c(tb$a$label, tb$s$label, tb$m$label))
}
p4_kernel_gap <- function(d, ref, tables, k) {
  fit <- .sem_fiml_solve(.sem_fiml_prepare_core(as.matrix(d), tables))
  e <- fit$estimate
  key <- p4_label_key(k)
  shared <- intersect(names(e), names(key))
  rq <- lavaan::coef(ref)[match(p4_key(key[shared]), p4_key(names(lavaan::coef(ref))))]
  max(max(abs(e[shared] - rq)), abs(-fit$nll - as.numeric(lavaan::logLik(ref))))
}

test_that("the oracles catch planted kernel defects: dropped covariate path, orthogonal exogenous block, transport", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  k <- 1L
  d <- p4_data(k)
  ref <- p4_lavaan(d, p4_model(k, TRUE, "free"))
  full <- .sem_fiml_tables_med(2L, TRUE, TRUE, k = k)
  # positive control: the unmutated tables pass
  expect_lt(p4_kernel_gap(d, ref, full, k), 1e-5)
  # D-a: the covariate dropped from the second mediator equation
  t1 <- full
  t1$a <- t1$a[!(t1$a$row == "M2" & t1$a$col == "Z"), ]
  expect_gt(p4_kernel_gap(d, ref, t1, k), 1e-2)
  # D-b: the exogenous covariance block imposed as orthogonal (the X-Z covariance row removed)
  t2 <- full
  t2$s <- t2$s[!(t2$s$row == "X" & t2$s$col == "Z"), ]
  expect_gt(p4_kernel_gap(d, ref, t2, k), 1e-2)
  # D-c: the mediator residual covariance removed
  t3 <- full
  t3$s <- t3$s[!(t3$s$row == "M1" & t3$s$col == "M2"), ]
  expect_gt(p4_kernel_gap(d, ref, t3, k), 1e-2)
  # D-d: wrong transport unit for the covariances (cxz and cm12 together)
  f <- p4_fit(d, p4_model(k))
  idx <- match(p4_key(names(coef(f))), p4_key(names(lavaan::coef(ref))))
  expect_lt(abs(coef(f)[["M1~~M2"]] - lavaan::coef(ref)[["M1~~M2"]]), 1e-5)
  badunit <- sem_mutate(.sem_fiml_transport, "units[cv$par] <- scale[cv$row] * scale[cv$col]", "units[cv$par] <- 1")
  fu <- testthat::with_mocked_bindings(p4_fit(d, p4_model(k)), .sem_fiml_transport = badunit)
  expect_gt(abs(coef(fu)[["M1~~M2"]] - lavaan::coef(ref)[["M1~~M2"]]), 1e-3)
  xz <- grep("^(X~~Z|Z~~X)$", names(coef(f)), value = TRUE)
  expect_gt(abs(coef(fu)[[xz]] - p4_align(lavaan::coef(ref), coef(f)[xz])[[1L]]), 1e-3)
  # D-e: the covariance block zeroed in the covariance transport
  zeroed <- sem_mutate(
    .sem_fiml_solve, "V <- p$transport %*% solve(H) %*% t(p$transport)",
    paste0("V <- p$transport %*% solve(H) %*% t(p$transport); k <- match(p$layout$covariances$par, ram$par_names); ",
           "V[k, ] <- 0; V[, k] <- 0")
  )
  fz <- testthat::with_mocked_bindings(p4_fit(d, p4_model(k)), .sem_fiml_solve = zeroed)
  expect_lt(p4_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
  expect_gt(abs(vcov(fz)[["M1~~M2", "M1~~M2"]] - vcov(f)[["M1~~M2", "M1~~M2"]]), 1e-4)
})

test_that("the oracles catch planted extraction defects: swapped a, zeroed Cov(b1, b2), dropped cross-path block", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  d <- p4_data(1L, direct = FALSE)
  model <- p4_model(1L, FALSE, "free")
  f <- p4_fit(d, model)
  ref <- p4_lavaan(d, p4_lavaan_labeled(1L, FALSE, "free"))
  pe <- lavaan::parameterEstimates(ref)
  target <- pe$se[pe$label == "tot"]
  se_of <- function(x) generics::tidy(x, type = "effects")$std_error[1L]
  m <- p4_extract(f)
  # positive control
  expect_lt(abs(se_of(m) - target) / target, 2e-3)
  expect_gt(abs(m@vcov["b1", "b2"]), 1e-4)
  mutated <- function(pattern, replacement) {
    fn <- sem_mutate(.sem_fiml_extract_parallel, pattern, replacement)
    testthat::with_mocked_bindings(p4_extract(f), .sem_fiml_extract_parallel = fn)
  }
  swapped <- mutated("a_aliases <- map[paste0(\"a\", i)]", "a_aliases <- rev(map[paste0(\"a\", i)])")
  expect_gt(abs(as.numeric(nie(swapped)) - as.numeric(nie(m))), .05)
  v_line <- "V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]"
  zero_bb <- mutated(v_line, paste0(v_line, "; V[\"b1\", \"b2\"] <- 0; V[\"b2\", \"b1\"] <- 0"))
  expect_gt(abs(se_of(zero_bb) - target) / target, .005)
  block <- mutated(v_line, paste0(v_line, "; V[c(\"a1\", \"b1\"), c(\"a2\", \"b2\")] <- 0; ",
                                   "V[c(\"a2\", \"b2\"), c(\"a1\", \"b1\")] <- 0"))
  expect_gt(abs(se_of(block) - target) / target, .02)
  # covariate coefficients mistaken for paths: gm1z1 aliased in place of a1 changes the effect
  wrong <- mutated("a_aliases <- map[paste0(\"a\", i)]", "a_aliases <- map[paste0(\"gm\", i, \"z1\")]")
  expect_gt(abs(as.numeric(nie(wrong)) - as.numeric(nie(m))), .05)
})
