# FI-G2, slice 2: parallel FIML with a FREE residual covariance between the two mediators (`M1 ~~ M2` written,
# label-less, either order), no covariates. Oracles independent of the production kernel: matched lavaan raw-data
# FIML, a from-scratch rowwise likelihood with an independent Hessian, closed-form complete-data checks. Helpers are
# prefixed p3_ and self-contained.

p3_vars <- c("X", "M1", "M2", "Y")
p3_data <- function(kind = "mar", n = 450L, direct = TRUE, seed = 6131L, rho = .5) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  e <- stats::rnorm(n)
  # a common disturbance gives the two mediators a residual correlation near rho
  m1 <- .3 + .9 * x + .5 * (sqrt(rho) * e + sqrt(1 - rho) * stats::rnorm(n))
  m2 <- -.2 + .6 * x + .5 * (sqrt(rho) * e + sqrt(1 - rho) * stats::rnorm(n))
  y <- .2 + .7 * m1 + .3 * m2 + (if (direct) .25 else 0) * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M1 = m1, M2 = m2, Y = y)
  if (kind == "mar") {
    d[stats::runif(n) < .08, "X"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M1"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.3 - .5 * x), "M2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind == "sparse") {
    d[1:20, "X"] <- NA_real_
    d[21:40, "M1"] <- NA_real_
    d[41:60, "M2"] <- NA_real_
    d[61:80, "Y"] <- NA_real_
    d[81:90, c("X", "M1")] <- NA_real_
    d[91:100, c("M2", "Y")] <- NA_real_
    d[101:110, c("M1", "M2")] <- NA_real_
    d[111L, ] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
p3_models <- c(
  free = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2",
  zero = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + 0*X\nM1 ~~ M2",
  omitted = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2\nM1 ~~ M2"
)
p3_independent <- "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2"
p3_fit <- function(d = p3_data(), model = p3_models[["free"]]) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE)
}
p3_lavaan <- function(d, model) {
  suppressWarnings(lavaan::sem(model, d, missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
                               information = "observed", control = list(rel.tol = 1e-10)))
}
p3_lavaan_labeled <- function(variant) {
  y <- switch(variant,
    free = "Y ~ b1*M1 + b2*M2 + cp*X", zero = "Y ~ b1*M1 + b2*M2 + 0*X", omitted = "Y ~ b1*M1 + b2*M2"
  )
  paste0("M1 ~ a1*X\nM2 ~ a2*X\n", y, "\nM1 ~~ M2\nind1 := a1*b1\nind2 := a2*b2\ntot := a1*b1 + a2*b2",
         if (variant == "free") "\nte := cp + a1*b1 + a2*b2")
}
p3_rel_gap <- function(V, ref) max(abs(V - ref) / sqrt(outer(diag(ref), diag(ref))))
p3_n_par <- function(variant) if (variant == "free") 14L else 13L
p3_moments <- function(q) {
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  B <- matrix(0, 4, 4, dimnames = list(p3_vars, p3_vars))
  for (r in c("M1", "M2", "Y")) for (p in setdiff(p3_vars, r)) B[r, p] <- g(paste0(r, "~", p))
  B["M1", "M2"] <- B["M2", "M1"] <- B["M1", "Y"] <- B["M2", "Y"] <- 0
  psi <- diag(vapply(p3_vars, function(v) g(paste0(v, "~~", v)), numeric(1)))
  dimnames(psi) <- list(p3_vars, p3_vars)
  psi["M1", "M2"] <- psi["M2", "M1"] <- g("M1~~M2")
  A <- solve(diag(4) - B)
  list(mu = drop(A %*% vapply(p3_vars, function(v) g(paste0(v, "~1")), numeric(1))), sigma = A %*% psi %*% t(A))
}
p3_nll <- function(d, q) gk_row_nll(as.matrix(d[, p3_vars]), p3_moments(q))
p3_hessian <- function(f, q) {
  units <- pmax(abs(q), 1)
  v <- grep("~~", names(q))
  units[v] <- pmin(units[v], pmax(abs(q[v]), 1e-3) / 10)
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
p3_delta <- function(m) {
  V <- m@vcov
  a <- m@a_paths
  b <- m@b_paths
  se <- function(g) sqrt(drop(t(g) %*% V[names(g), names(g)] %*% g))
  list(
    ind1 = se(c(a1 = b[[1]], b1 = a[[1]])), ind2 = se(c(a2 = b[[2]], b2 = a[[2]])),
    sum = se(c(a1 = b[[1]], a2 = b[[2]], b1 = a[[1]], b2 = a[[2]]))
  )
}

# ---- tables: slice 1 is untouched ------------------------------------------------------------------------------------

test_that("slice-1, three-variable and covariate tables are identical() to the pre-change dump", {
  before <- readRDS(test_path("fixtures", "fiml-tables-before-g2s2.rds"))
  for (j in 1:2) for (d in c(TRUE, FALSE)) {
    expect_identical(.sem_fiml_tables_med(j, d), before[[paste0("med", j, d)]])
    expect_identical(.sem_fiml_tables_med(j, d, residual_covariance = FALSE), before[[paste0("med", j, d)]])
  }
  for (k in 1:2) for (d in c(TRUE, FALSE)) {
    expect_identical(.sem_fiml_tables_cov(k, d), before[[paste0("cov", k, d)]])
  }
})

test_that("the residual-covariance tables add exactly one free covariance between the mediators", {
  for (direct in c(TRUE, FALSE)) {
    t0 <- .sem_fiml_tables_med(2L, direct)
    t1 <- .sem_fiml_tables_med(2L, direct, residual_covariance = TRUE)
    expect_identical(t1$a, t0$a)
    expect_identical(t1$m, t0$m)
    expect_identical(t1$vars, t0$vars)
    expect_identical(t1$s[seq_len(nrow(t0$s)), ], t0$s)
    expect_identical(nrow(t1$s), nrow(t0$s) + 1L)
    extra <- t1$s[nrow(t1$s), ]
    expect_identical(c(extra$row, extra$col), c("M1", "M2"))
    expect_true(is.na(extra$value))
    lay <- .sem_fiml_layout(t1)
    expect_identical(nrow(lay$covariances), 1L)
    expect_identical(nrow(.sem_fiml_layout(t0)$covariances), 0L)
  }
  expect_error(.sem_fiml_tables_med(1L, TRUE, residual_covariance = TRUE), class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_tables_med(2L, TRUE, residual_covariance = NA), class = "medfit_sem_fiml_error")
})

# ---- the free variant is distinguishable from the independent one ---------------------------------------------------

test_that("a residual correlation near 0.5 separates the free variant from the independent one", {
  d <- p3_data()
  free <- p3_fit(d)
  ind <- p3_fit(d, p3_independent)
  rho <- coef(free)[["M1~~M2"]] / sqrt(coef(free)[["M1~~M1"]] * coef(free)[["M2~~M2"]])
  expect_gt(rho, .3)
  expect_lt(rho, .7)
  expect_gt(as.numeric(stats::logLik(free)) - as.numeric(stats::logLik(ind)), 20)
  expect_identical(length(coef(free)), length(coef(ind)) + 1L)
  mf <- extract_mediation(free, treatment = "X", mediator = c("M1", "M2"))
  mi <- extract_mediation(ind, treatment = "X", mediator = c("M1", "M2"))
  # the free covariance moves the cross-b covariance: the sum's SE differs materially
  expect_gt(abs(p3_delta(mf)$sum - p3_delta(mi)$sum) / p3_delta(mf)$sum, .01)
  expect_gt(abs(mf@vcov["b1", "b2"] - mi@vcov["b1", "b2"]), 1e-3)
})

# ---- fit versus lavaan and the rowwise oracle -----------------------------------------------------------------------

test_that("free-covariance FIML matches lavaan: estimates, covariance, logLik, products, SUM, te and SEs", {
  skip_if_not_installed("lavaan")
  for (variant in names(p3_models)) {
    d <- p3_data(direct = variant == "free")
    f <- p3_fit(d, p3_models[[variant]])
    ref <- p3_lavaan(d, p3_models[[variant]])
    q <- coef(f)
    expect_length(q, p3_n_par(variant))
    expect_identical(length(lavaan::coef(ref)), p3_n_par(variant))
    expect_true("M1~~M2" %in% names(q))
    expect_setequal(names(q), names(lavaan::coef(ref)))
    expect_lt(max(abs(q - lavaan::coef(ref)[names(q)])), 1e-5)
    idx <- match(names(q), names(lavaan::coef(ref)))
    expect_lt(p3_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
    expect_lt(abs(as.numeric(stats::logLik(f)) - as.numeric(lavaan::logLik(ref))), 1e-6)
    expect_identical(attr(stats::logLik(f), "df"), p3_n_par(variant))
    rl <- p3_lavaan(d, p3_lavaan_labeled(variant))
    pe <- lavaan::parameterEstimates(rl)
    pe <- pe[pe$op == ":=", ]
    m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
    expect_s3_class(m, "medfit::FIMLParallelMediationData")
    expect_equal(as.numeric(nie(m)), pe$est[pe$label == "tot"], tolerance = 1e-5)
    expect_equal(m@a_paths[[1]] * m@b_paths[[1]], pe$est[pe$label == "ind1"], tolerance = 1e-5)
    expect_equal(m@a_paths[[2]] * m@b_paths[[2]], pe$est[pe$label == "ind2"], tolerance = 1e-5)
    dl <- p3_delta(m)
    expect_equal(dl$ind1, pe$se[pe$label == "ind1"], tolerance = 2e-3)
    expect_equal(dl$ind2, pe$se[pe$label == "ind2"], tolerance = 2e-3)
    expect_equal(dl$sum, pe$se[pe$label == "tot"], tolerance = 2e-3)
    tt <- generics::tidy(m, type = "effects")
    expect_equal(tt$std_error[tt$term == "nie"], dl$sum, tolerance = 1e-8)
    if (variant == "free") {
      expect_equal(as.numeric(te(m)), pe$est[pe$label == "te"], tolerance = 1e-5)
      expect_equal(tt$std_error[tt$term == "te"], pe$se[pe$label == "te"], tolerance = 2e-3)
    } else {
      expect_identical(unname(m@c_prime), 0)
    }
    # full covariance carried: alias block and the residual covariance row
    nm <- c("a1", "a2", "b1", "b2", if (variant == "free") "c_prime")
    ln <- c("a1", "a2", "b1", "b2", if (variant == "free") "cp")
    expect_lt(p3_rel_gap(m@vcov[nm, nm], lavaan::vcov(rl)[ln, ln]), 1e-3)
    expect_true("M1~~M2" %in% rownames(m@vcov))
    expect_equal(m@vcov["M1~~M2", "M1~~M2"], vcov(f)[["M1~~M2", "M1~~M2"]])
    expect_equal(unname(m@a_paths), unname(q[c("M1~X", "M2~X")]))
    expect_equal(unname(m@b_paths), unname(q[c("Y~M1", "Y~M2")]))
  }
})

test_that("either statement order gives the same fit and a swapped mediator request the same sum", {
  d <- p3_data()
  f <- p3_fit(d)
  fs <- p3_fit(d, "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM2 ~~ M1")
  expect_equal(unname(coef(fs)), unname(coef(f)))
  expect_identical(sub("M2~~M1", "M1~~M2", names(coef(fs)), fixed = TRUE), names(coef(f)))
  expect_identical(names(.sem_fiml_model(p3_models[["free"]])$map),
                   c("a1", "a2", "b1", "b2", "cp", "vx", "vm1", "vm2", "vy", "cm12", "ix", "im1", "im2", "iy"))
  expect_identical(names(.sem_fiml_model(p3_models[["zero"]])$map),
                   c("a1", "a2", "b1", "b2", "vx", "vm1", "vm2", "vy", "cm12", "ix", "im1", "im2", "iy"))
  m <- extract_mediation(f, treatment = "X", mediator = c("M2", "M1"))
  m1 <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  expect_equal(as.numeric(nie(m)), as.numeric(nie(m1)))
  expect_equal(generics::tidy(m, type = "effects")$std_error, generics::tidy(m1, type = "effects")$std_error)
  expect_no_error(extract_mediation(f, treatment = "X", mediator = c("M1", "M2"), structure = "parallel"))
})

test_that("free-covariance FIML equals the rowwise likelihood oracle, is a local optimum, and its Hessian agrees", {
  for (variant in c("free", "zero")) {
    d <- p3_data(direct = variant == "free")
    f <- p3_fit(d, p3_models[[variant]])
    q <- coef(f)
    nll <- function(x) p3_nll(d, stats::setNames(x, names(q)))
    expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
    grad <- vapply(seq_along(q), function(k) {
      fo_richardson(lapply(.02 / 2^(0:3), function(h) {
        e <- q * 0
        e[k] <- h * max(abs(q[k]), 1)
        (nll(q + e) - nll(q - e)) / (2 * e[k])
      }))
    }, numeric(1))
    expect_lt(max(abs(grad)), 1e-4)
    expect_lt(p3_rel_gap(vcov(f), solve(p3_hessian(nll, q))), 1e-3)
  }
})

test_that("a sparse pattern sweep with an all-empty row keeps every pattern", {
  skip_if_not_installed("lavaan")
  d <- p3_data("sparse")
  f <- p3_fit(d)
  expect_identical(f@n_dropped, 1L)
  expect_gte(length(f@internals$likelihood$rows$patterns), 7L)
  ref <- p3_lavaan(d, p3_models[["free"]])
  q <- coef(f)
  expect_lt(max(abs(q - lavaan::coef(ref)[names(q)])), 1e-5)
  nll <- function(x) p3_nll(d[rowSums(!is.na(d)) > 0L, ], stats::setNames(x, names(q)))
  expect_lt(abs(f@internals$likelihood$nll - nll(q)), 1e-7)
})

test_that("complete data: ML estimates are equation-wise OLS plus the residual covariance of the two M residuals", {
  for (variant in c("free", "zero")) {
    d <- p3_data("complete", direct = variant == "free")
    f <- p3_fit(d, p3_models[[variant]])
    q <- coef(f)
    n <- nrow(d)
    l1 <- stats::lm(M1 ~ X, d)
    l2 <- stats::lm(M2 ~ X, d)
    ly <- if (variant == "free") stats::lm(Y ~ M1 + M2 + X, d) else stats::lm(Y ~ M1 + M2, d)
    expect_equal(q[["M1~X"]], stats::coef(l1)[["X"]], tolerance = 1e-6)
    expect_equal(q[["M2~X"]], stats::coef(l2)[["X"]], tolerance = 1e-6)
    expect_equal(q[["Y~M1"]], stats::coef(ly)[["M1"]], tolerance = 1e-6)
    expect_equal(q[["Y~M2"]], stats::coef(ly)[["M2"]], tolerance = 1e-6)
    expect_equal(q[["M1~~M1"]], sum(stats::resid(l1)^2) / n, tolerance = 1e-6)
    expect_equal(q[["M2~~M2"]], sum(stats::resid(l2)^2) / n, tolerance = 1e-6)
    expect_equal(q[["Y~~Y"]], sum(stats::resid(ly)^2) / n, tolerance = 1e-6)
    expect_equal(q[["M1~~M2"]], sum(stats::resid(l1) * stats::resid(l2)) / n, tolerance = 1e-6)
    # exact ML covariance of the structural block: the M and Y equations stay uncorrelated for the structural parts
    # of Y given M (the Y equation's residual is uncorrelated with the M residuals), and M1~X, M2~X covary as
    # Sigma_12 (X'X)^-1
    V <- vcov(f)
    xm <- cbind(1, d$X)
    S12 <- sum(stats::resid(l1) * stats::resid(l2)) / n
    expect_equal(V[c("M1~1", "M1~X"), c("M2~1", "M2~X")], S12 * solve(crossprod(xm)), tolerance = 1e-4,
                 ignore_attr = TRUE)
    expect_lt(abs(V[["M1~X", "Y~M1"]]), 1e-8)
  }
})

# ---- cross-path covariance in the sum, with the free covariance -----------------------------------------------------

test_that("the free residual covariance changes the sum's SE and the full cross-path covariance matters", {
  skip_if_not_installed("lavaan")
  d <- p3_data(direct = FALSE)
  f <- p3_fit(d, p3_models[["zero"]])
  m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  V <- m@vcov
  g <- c(a1 = m@b_paths[[1]], a2 = m@b_paths[[2]], b1 = m@a_paths[[1]], b2 = m@a_paths[[2]])
  full <- sqrt(drop(t(g) %*% V[names(g), names(g)] %*% g))
  one <- function(a, b) g[[a]]^2 * V[a, a] + g[[b]]^2 * V[b, b] + 2 * g[[a]] * g[[b]] * V[a, b]
  naive <- sqrt(one("a1", "b1") + one("a2", "b2"))
  expect_gt(abs(full - naive) / full, .03)
  # Cov(a1, a2) is nonzero because the disturbances covary
  expect_gt(abs(V["a1", "a2"]), 1e-4)
  ref <- p3_lavaan(d, p3_lavaan_labeled("zero"))
  pe <- lavaan::parameterEstimates(ref)
  expect_equal(full, pe$se[pe$label == "tot"], tolerance = 2e-3)
})

# ---- what stays refused ---------------------------------------------------------------------------------------------

p3_unadmitted <- c(
  implicit_independence = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X",
  labeled_free_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ c*M2",
  fixed_nonzero_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0.2*M2",
  bounded_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ start(.1)*M2",
  tied_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ r*M2\nM1 ~~ r*M1",
  constrained_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ cc*M2\ncc == 0.1",
  defined_from_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ cc*M2\nz := cc*2",
  mediator_outcome_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2\nM1 ~~ Y",
  mediator_outcome_covariance_2 = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2\nM2 ~~ Y",
  treatment_mediator_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2\nX ~~ M1",
  covariate_with_parallel = "M1 ~ X + Z\nM2 ~ X + Z\nY ~ M1 + M2 + X + Z\nM1 ~~ M2",
  serial = "M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X\nM1 ~~ M2",
  three_mediators = "M1 ~ X\nM2 ~ X\nM3 ~ X\nY ~ M1 + M2 + M3 + X\nM1 ~~ M2",
  one_mediator_only_to_y = "M1 ~ X\nM2 ~ X\nY ~ M1 + X\nM1 ~~ M2",
  fixed_nonzero_direct = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + 0.5*X\nM1 ~~ M2",
  tied_a_paths = "M1 ~ p*X\nM2 ~ p*X\nY ~ M1 + M2 + X\nM1 ~~ M2",
  fixed_variance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2\nM1 ~~ 1*M1",
  interaction = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X + M1:X\nM1 ~~ M2",
  duplicate_covariance = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2\nM2 ~~ M1"
)
p3_refusal_data <- function() {
  d <- p3_data()
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
  d <- p3_refusal_data()
  for (nm in names(p3_unadmitted)) {
    e <- tryCatch(fit_sem(p3_unadmitted[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
    expect_false(grepl("reached", conditionMessage(e)), info = nm)
  }
  expect_identical(reached, character())
})

test_that("the prepare layer refuses wrong shapes for the covariance tables", {
  d <- p3_data()
  tables <- .sem_fiml_tables_med(2L, TRUE, residual_covariance = TRUE)
  expect_error(.sem_fiml_prepare_core(as.matrix(d[, c("X", "M1", "Y")]), tables), "invalid FIML input")
  expect_error(.sem_fiml_prepare_core(as.matrix(d)[, c("X", "M2", "M1", "Y")], tables), "invalid FIML input")
  expect_type(.sem_fiml_prepare_core(as.matrix(d), tables), "list")
})

test_that("the parallel source-fit refusal stays, behind the guard and behind it", {
  f <- p3_fit()
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
  }
  expect_identical(refit_calls, 0L)
  fm <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  expect_error(confint(fm, method = "boot"), "FIML")
  expect_error(pm(fm), "FIML")
})

test_that("extraction refusals still apply to a free-covariance fit", {
  f <- p3_fit()
  refused <- list(
    list(treatment = "X", mediator = "M1"), list(treatment = "M1", mediator = c("M1", "M2")),
    list(treatment = "X", mediator = c("M1", "M1")),
    list(treatment = "X", mediator = c("M1", "M2"), standardized = TRUE),
    list(treatment = "X", mediator = c("M1", "M2"), structure = "serial"),
    list(treatment = "X", mediator = c("M1", "M2"), decomposition = "four_way"),
    list(treatment = "X", mediator = c("M1", "M2"), outcome = "X")
  )
  for (args in refused) {
    expect_error(do.call(extract_mediation, c(list(f), args)), "FIML extraction supports only")
  }
})

# ---- planted defects with positive controls --------------------------------------------------------------------------

p3_kernel_gap <- function(d, ref, tables) {
  fit <- .sem_fiml_solve(.sem_fiml_prepare_core(as.matrix(d), tables))
  e <- fit$estimate
  map <- c(a1 = "M1~X", a2 = "M2~X", b1 = "Y~M1", b2 = "Y~M2", cp = "Y~X", vx = "X~~X", vm1 = "M1~~M1",
           vm2 = "M2~~M2", vy = "Y~~Y", ix = "X~1", im1 = "M1~1", im2 = "M2~1", iy = "Y~1")
  shared <- intersect(names(e), names(map))
  max(max(abs(e[shared] - lavaan::coef(ref)[map[shared]])), abs(-fit$nll - as.numeric(lavaan::logLik(ref))))
}

test_that("the oracles catch planted defects: dropped covariance, zeroed or mis-scaled transport, swap", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  d <- p3_data()
  ref <- p3_lavaan(d, p3_models[["free"]])
  full <- .sem_fiml_tables_med(2L, TRUE, residual_covariance = TRUE)
  # positive control: the unmutated tables pass, and the covariance parameter matches lavaan
  expect_lt(p3_kernel_gap(d, ref, full), 1e-5)
  fit0 <- .sem_fiml_solve(.sem_fiml_prepare_core(as.matrix(d), full))
  cov_name <- full$s$label[nrow(full$s)]
  expect_lt(abs(fit0$estimate[[cov_name]] - lavaan::coef(ref)[["M1~~M2"]]), 1e-5)
  # D-a: the M1-M2 residual covariance dropped
  expect_gt(p3_kernel_gap(d, ref, .sem_fiml_tables_med(2L, TRUE)), 1e-2)
  # D-b: the covariance treated as zero in the covariance transport
  f <- p3_fit(d)
  idx <- match(names(coef(f)), names(lavaan::coef(ref)))
  zeroed <- sem_mutate(
    .sem_fiml_solve, "V <- p$transport %*% solve(H) %*% t(p$transport)",
    paste0("V <- p$transport %*% solve(H) %*% t(p$transport); k <- match(p$layout$covariances$par, ram$par_names); ",
           "V[k, ] <- 0; V[, k] <- 0")
  )
  fz <- testthat::with_mocked_bindings(p3_fit(d), .sem_fiml_solve = zeroed)
  expect_lt(p3_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
  expect_gt(abs(vcov(fz)[["M1~~M2", "M1~~M2"]] - vcov(f)[["M1~~M2", "M1~~M2"]]), 1e-4)
  # D-c: wrong transport unit for the covariance (variance-scale instead of the product of the two scales)
  badunit <- sem_mutate(
    .sem_fiml_transport, "units[cv$par] <- scale[cv$row] * scale[cv$col]", "units[cv$par] <- 1"
  )
  fu <- testthat::with_mocked_bindings(p3_fit(d), .sem_fiml_transport = badunit)
  expect_lt(abs(coef(f)[["M1~~M2"]] - lavaan::coef(ref)[["M1~~M2"]]), 1e-5)
  expect_gt(abs(coef(fu)[["M1~~M2"]] - lavaan::coef(ref)[["M1~~M2"]]), 1e-3)
  # D-d: a1 and a2 swapped in the alias map
  swp <- sem_mutate(.sem_fiml_extract_parallel, "a_aliases <- map[paste0(\"a\", i)]",
                    "a_aliases <- rev(map[paste0(\"a\", i)])")
  ms <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")),
                                       .sem_fiml_extract_parallel = swp)
  m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  expect_gt(abs(as.numeric(nie(ms)) - as.numeric(nie(m))), .05)
})

test_that("the oracles catch the dropped cross-path covariance in the sum's SE with a free residual covariance", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  d <- p3_data(direct = FALSE)
  f <- p3_fit(d, p3_models[["zero"]])
  ref <- p3_lavaan(d, p3_lavaan_labeled("zero"))
  pe <- lavaan::parameterEstimates(ref)
  target <- pe$se[pe$label == "tot"]
  se_of <- function(x) generics::tidy(x, type = "effects")$std_error[1L]
  m <- extract_mediation(f, treatment = "X", mediator = c("M1", "M2"))
  expect_lt(abs(se_of(m) - target) / target, 2e-3)
  block <- sem_mutate(
    .sem_fiml_extract_parallel,
    "V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]",
    paste0("V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]; ",
           "V[c(\"a1\", \"b1\"), c(\"a2\", \"b2\")] <- 0; V[c(\"a2\", \"b2\"), c(\"a1\", \"b1\")] <- 0")
  )
  mb <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = c("M1", "M2")),
                                       .sem_fiml_extract_parallel = block)
  expect_gt(abs(se_of(mb) - target) / target, .02)
})
