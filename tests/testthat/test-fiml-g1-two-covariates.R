# FI-G1, slice 2: bounded Gaussian FIML with TWO observed covariates Z1, Z2 (random X; X, Z1, Z2, M, Y jointly
# Gaussian), the model M ~ X + Z1 + Z2, Y ~ M + X + Z1 + Z2 (direct path free, or one Y path fixed at
# zero). Oracles, each independent of the production kernel: matched lavaan raw-data FIML, a from-scratch rowwise Gaussian likelihood, and
# closed-form complete-data OLS. Slice-1 helpers (g1_*) live in test-fiml-g1-covariate.R and are not reused.

g2_vars <- c("X", "Z1", "Z2", "M", "Y")
g2_data <- function(kind = "mar", n = 450L, direct = TRUE, seed = 5113L) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  z1 <- 1 + .4 * x + stats::rnorm(n, sd = 1.2)
  z2 <- -.5 + .3 * x - .35 * z1 + stats::rnorm(n, sd = 1.1)
  m <- .3 + .5 * x + .4 * z1 - .25 * z2 + stats::rnorm(n, sd = .8)
  y <- .2 + .6 * m + (if (direct) .25 else 0) * x - .3 * z1 + .2 * z2 + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, Z1 = z1, Z2 = z2, M = m, Y = y)
  if (kind == "mar") {
    # every variable can be incomplete; M and Y depend (ignorably) on the observed X
    d[stats::runif(n) < .08, "X"] <- NA_real_
    d[stats::runif(n) < .08, "Z1"] <- NA_real_
    d[stats::runif(n) < .08, "Z2"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
g2_model <- "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2"
g2_fit <- function(d = g2_data(), model = g2_model, ...) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE, ...)
}
g2_lavaan <- function(d, model) {
  suppressWarnings(lavaan::sem(model, d, missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
                               information = "observed", control = list(rel.tol = 1e-10)))
}
g2_rel_gap <- function(V, ref) max(abs(V - ref) / sqrt(outer(diag(ref), diag(ref))))
# lavaan names an exogenous covariance in the order its table has it; match by the unordered pair
g2_align <- function(ref_coef, q) {
  key <- function(nm) {
    vapply(strsplit(nm, "~~", fixed = TRUE), function(p) {
      if (length(p) == 2L) paste(sort(p), collapse = "~~") else paste(p, collapse = "")
    }, character(1))
  }
  ref_coef[match(key(names(q)), key(names(ref_coef)))]
}

# ---- independent rowwise likelihood ---------------------------------------------------------------------------------
g2_moments <- function(q) {
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  gc <- function(a, b) if (paste0(a, "~~", b) %in% names(q)) q[[paste0(a, "~~", b)]] else g(paste0(b, "~~", a))
  B <- matrix(0, 5, 5, dimnames = list(g2_vars, g2_vars))
  for (r in c("M", "Y")) for (p in setdiff(g2_vars, r)) B[r, p] <- g(paste0(r, "~", p))
  B[c("X", "Z1", "Z2"), ] <- 0
  B["M", "Y"] <- 0
  psi <- diag(vapply(g2_vars, function(v) g(paste0(v, "~~", v)), numeric(1)))
  dimnames(psi) <- list(g2_vars, g2_vars)
  for (pr in list(c("X", "Z1"), c("X", "Z2"), c("Z1", "Z2"))) {
    psi[pr[1], pr[2]] <- psi[pr[2], pr[1]] <- gc(pr[1], pr[2])
  }
  A <- solve(diag(5) - B)
  list(mu = drop(A %*% vapply(g2_vars, function(v) g(paste0(v, "~1")), numeric(1))), sigma = A %*% psi %*% t(A))
}
g2_nll <- function(d, q) gk_row_nll(as.matrix(d[, g2_vars]), g2_moments(q))
g2_hessian <- function(f, q) {
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

# ---- fit versus lavaan and the rowwise oracle -----------------------------------------------------------------------

test_that("two-covariate FIML matches lavaan raw-data FIML: estimates, covariance, logLik, NIE and TE SEs", {
  skip_if_not_installed("lavaan")
  d <- g2_data()
  expect_true(all(vapply(d, anyNA, logical(1))))
  f <- g2_fit(d)
  expect_s3_class(f, "medfit::SEMFit")
  ref <- g2_lavaan(d, g2_model)
  q <- coef(f)
  expect_length(q, 20L)
  expect_setequal(names(q), names(g2_align(lavaan::coef(ref), q)))
  expect_false(anyNA(g2_align(lavaan::coef(ref), q)))
  expect_lt(max(abs(q - g2_align(lavaan::coef(ref), q))), 1e-5)
  idx <- match(names(g2_align(lavaan::coef(ref), q)), names(lavaan::coef(ref)))
  expect_lt(g2_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
  expect_lt(abs(as.numeric(stats::logLik(f)) - as.numeric(lavaan::logLik(ref))), 1e-6)
  expect_identical(attr(stats::logLik(f), "df"), 20L)
  lab <- "M ~ a*X + Z1 + Z2\nY ~ b*M + cp*X + Z1 + Z2\nnie := a*b\nte := cp + a*b"
  rl <- g2_lavaan(d, lab)
  pe <- lavaan::parameterEstimates(rl)
  m <- extract_mediation(f, treatment = "X", mediator = "M")
  expect_s3_class(m, "medfit::FIMLMediationData")
  expect_equal(as.numeric(nie(m)), pe$est[pe$label == "nie"], tolerance = 1e-5)
  expect_equal(as.numeric(te(m)), pe$est[pe$label == "te"], tolerance = 1e-5)
  tt <- generics::tidy(m, type = "effects")
  expect_equal(tt$std_error[tt$term == "nie"], pe$se[pe$label == "nie"], tolerance = 2e-3)
  expect_equal(tt$std_error[tt$term == "te"], pe$se[pe$label == "te"], tolerance = 2e-3)
  r3 <- lavaan::vcov(rl)[c("a", "b", "cp"), c("a", "b", "cp")]
  expect_lt(g2_rel_gap(m@vcov[c("a", "b", "c_prime"), c("a", "b", "c_prime")], r3), 1e-3)
  expect_equal(unname(m@a_path), q[["M~X"]])
  expect_equal(unname(m@b_path), q[["Y~M"]])
  expect_equal(unname(m@c_prime), q[["Y~X"]])
  expect_identical(m@n_obs, f@n_obs)
  expect_identical(m@fit_context$covariate, c("Z1", "Z2"))
})

test_that("two-covariate FIML equals the rowwise likelihood oracle and is a local optimum (observed information)", {
  d <- g2_data()
  f <- g2_fit(d)
  q <- coef(f)
  nll <- function(x) g2_nll(d, stats::setNames(x, names(q)))
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
  expect_lt(g2_rel_gap(vcov(f), solve(g2_hessian(nll, q))), 1e-3)
})

test_that("a missing pattern sweep keeps every pattern including an all-empty row", {
  skip_if_not_installed("lavaan")
  d <- g2_data()
  d <- rbind(d, data.frame(X = NA_real_, Z1 = NA_real_, Z2 = NA_real_, M = NA_real_, Y = NA_real_))
  f <- g2_fit(d)
  expect_identical(f@n_dropped, 1L)
  expect_identical(f@n_obs, nrow(d) - 1L)
  expect_gt(length(f@internals$likelihood$rows$patterns), 10L)
  ref <- g2_lavaan(d, g2_model)
  q <- coef(f)
  expect_lt(max(abs(q - g2_align(lavaan::coef(ref), q))), 1e-5)
})

test_that("complete data: two-covariate FIML equals closed-form OLS and ML covariances", {
  d <- g2_data("complete")
  f <- g2_fit(d)
  q <- coef(f)
  mm <- stats::coef(stats::lm(M ~ X + Z1 + Z2, d))
  ym <- stats::coef(stats::lm(Y ~ M + X + Z1 + Z2, d))
  for (p in c("X", "Z1", "Z2")) {
    expect_equal(q[[paste0("M~", p)]], mm[[p]], tolerance = 1e-6)
    expect_equal(q[[paste0("Y~", p)]], ym[[p]], tolerance = 1e-6)
  }
  expect_equal(q[["Y~M"]], ym[["M"]], tolerance = 1e-6)
  expect_equal(q[["M~1"]], mm[["(Intercept)"]], tolerance = 1e-6)
  expect_equal(q[["Y~1"]], ym[["(Intercept)"]], tolerance = 1e-6)
  n <- nrow(d)
  expect_equal(q[["M~~M"]], sum(stats::resid(stats::lm(M ~ X + Z1 + Z2, d))^2) / n, tolerance = 1e-6)
  expect_equal(q[["Y~~Y"]], sum(stats::resid(stats::lm(Y ~ M + X + Z1 + Z2, d))^2) / n, tolerance = 1e-6)
  S <- stats::cov(d) * (n - 1) / n
  for (v in c("X", "Z1", "Z2")) {
    expect_equal(q[[paste0(v, "~~", v)]], S[v, v], tolerance = 1e-6)
    expect_equal(q[[paste0(v, "~1")]], mean(d[[v]]), tolerance = 1e-6)
  }
  cq <- function(a, b) if (paste0(a, "~~", b) %in% names(q)) q[[paste0(a, "~~", b)]] else q[[paste0(b, "~~", a)]]
  expect_equal(cq("X", "Z1"), S["X", "Z1"], tolerance = 1e-6)
  expect_equal(cq("X", "Z2"), S["X", "Z2"], tolerance = 1e-6)
  expect_equal(cq("Z1", "Z2"), S["Z1", "Z2"], tolerance = 1e-6)
  # neutrality against the complete-data native listwise fit (fixed_x = FALSE)
  lw <- fit_sem(g2_model, d, fixed_x = FALSE, meanstructure = TRUE)
  shared <- c("M~X", "M~Z1", "M~Z2", "Y~M", "Y~X", "Y~Z1", "Y~Z2", "M~~M", "Y~~Y")
  expect_equal(q[shared], coef(lw)[shared], tolerance = 1e-5)
  expect_equal(sqrt(diag(vcov(f)))[shared], sqrt(diag(vcov(lw)))[shared], tolerance = 1e-3)
})

# ---- direct-path policy and the treatment rule ----------------------------------------------------------------------

test_that("with every Y path free any of the three exogenous variables may be the treatment", {
  skip_if_not_installed("lavaan")
  d <- g2_data()
  f <- g2_fit(d)
  q <- coef(f)
  others <- list(X = c("Z1", "Z2"), Z1 = c("X", "Z2"), Z2 = c("X", "Z1"))
  for (tr in names(others)) {
    lab <- paste0("M ~ a*", tr, " + ", paste(others[[tr]], collapse = " + "), "\nY ~ b*M + cp*", tr, " + ",
                  paste(others[[tr]], collapse = " + "), "\nnie := a*b")
    rl <- g2_lavaan(d, lab)
    pe <- lavaan::parameterEstimates(rl)
    m <- extract_mediation(f, treatment = tr, mediator = "M")
    expect_equal(unname(m@a_path), q[[paste0("M~", tr)]], info = tr)
    expect_equal(unname(m@c_prime), q[[paste0("Y~", tr)]], info = tr)
    expect_equal(as.numeric(nie(m)), pe$est[pe$label == "nie"], tolerance = 1e-5, info = tr)
    tt <- generics::tidy(m, type = "effects")
    expect_equal(tt$std_error[tt$term == "nie"], pe$se[pe$label == "nie"], tolerance = 2e-3, info = tr)
    expect_lt(g2_rel_gap(m@vcov[c("a", "b", "c_prime"), c("a", "b", "c_prime")],
                         lavaan::vcov(rl)[c("a", "b", "cp"), c("a", "b", "cp")]), 1e-3)
    expect_setequal(m@fit_context$covariate, others[[tr]])
  }
  expect_error(extract_mediation(f, treatment = "M", mediator = "X"), "FIML extraction supports only")
  expect_error(extract_mediation(f, treatment = "Z1", mediator = "M", outcome = "Z2"), "FIML extraction supports only")
})

test_that("a Y path fixed at zero is a fixed row; its variable is the treatment and the only valid one", {
  skip_if_not_installed("lavaan")
  d <- g2_data(direct = FALSE)
  zero <- list(X = "M ~ X + Z1 + Z2\nY ~ M + 0*X + Z1 + Z2", Z1 = "M ~ X + Z1 + Z2\nY ~ M + X + 0*Z1 + Z2",
               Z2 = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + 0*Z2")
  for (tr in names(zero)) {
    f <- g2_fit(d, zero[[tr]])
    q <- coef(f)
    expect_length(q, 19L)
    expect_false(paste0("Y~", tr) %in% names(q))
    ref <- g2_lavaan(d, zero[[tr]])
    expect_lt(max(abs(q - g2_align(lavaan::coef(ref), q))), 1e-5)
    m <- extract_mediation(f, treatment = tr, mediator = "M")
    expect_identical(unname(m@c_prime), 0)
    expect_equal(as.numeric(te(m)), as.numeric(nie(m)))
    expect_false(any(f@table$free[f@table$lhs == "Y" & f@table$rhs == tr]))
    for (other in setdiff(names(zero), tr)) {
      expect_error(extract_mediation(f, treatment = other, mediator = "M"), "FIML extraction supports only")
    }
  }
  f <- g2_fit(d, zero$Z1)
  ref <- g2_lavaan(d, zero$Z1)
  idx <- match(names(g2_align(lavaan::coef(ref), coef(f))), names(lavaan::coef(ref)))
  expect_lt(g2_rel_gap(vcov(f), lavaan::vcov(ref)[idx, idx]), 1e-3)
})

test_that("explicit and automatic exogenous covariances, labels and variable order give the same fit", {
  d <- g2_data()
  base <- coef(g2_fit(d))
  mods <- c(
    paste0(g2_model, "\nX ~~ Z1\nX ~~ Z2\nZ1 ~~ Z2"),
    paste0(g2_model, "\nZ2 ~~ Z1\nZ2 ~~ X\nZ1 ~~ X"),
    "Y ~ M + Z2 + X + Z1\nM ~ Z1 + Z2 + X",
    "M ~ p*X + r*Z1 + s*Z2\nY ~ t*M + u*X + v*Z1 + w*Z2"
  )
  for (mod in mods) {
    q <- coef(g2_fit(d, mod))
    expect_equal(sort(unname(q)), sort(unname(base)), tolerance = 1e-6, info = mod)
  }
  # a label that equals a reserved alias must not change roles
  m <- extract_mediation(g2_fit(d, "M ~ cp*X + b*Z1 + Z2\nY ~ a*M + X + Z1 + Z2"), treatment = "X", mediator = "M")
  expect_equal(unname(m@a_path), base[["M~X"]], tolerance = 1e-6)
  expect_equal(unname(m@b_path), base[["Y~M"]], tolerance = 1e-6)
})

# ---- refusals: every other topology and direct-path policy ----------------------------------------------------------

g2_unadmitted <- c(
  three_covariates = "M ~ X + Z1 + Z2 + W\nY ~ M + X + Z1 + Z2 + W",
  covariate_only_on_mediator = "M ~ X + Z1 + Z2\nY ~ M + X + Z1",
  second_covariate_only_on_outcome = "M ~ X + Z1\nY ~ M + X + Z1 + Z2",
  covariate_on_mediator_only_both = "M ~ X + Z1 + Z2\nY ~ M + X",
  omitted_x_outcome_path = "M ~ X + Z1 + Z2\nY ~ M + Z1 + Z2",
  two_outcome_zeros = "M ~ X + Z1 + Z2\nY ~ M + 0*X + 0*Z1 + Z2",
  three_outcome_zeros = "M ~ X + Z1 + Z2\nY ~ M + 0*X + 0*Z1 + 0*Z2",
  fixed_nonzero_outcome_path = "M ~ X + Z1 + Z2\nY ~ M + X + 0.5*Z1 + Z2",
  fixed_zero_mediator_covariate_path = "M ~ X + Z1 + 0*Z2\nY ~ M + X + Z1 + Z2",
  fixed_zero_mediator_x_path = "M ~ 0*X + Z1 + Z2\nY ~ M + X + Z1 + Z2",
  fixed_nonzero_covariate_path = "M ~ X + Z1 + 0.3*Z2\nY ~ M + X + Z1 + Z2",
  orthogonal_covariates = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nZ1 ~~ 0*Z2",
  orthogonal_x_covariate = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nX ~~ 0*Z2",
  fixed_nonzero_covariance = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nZ1 ~~ 0.2*Z2",
  # a partial explicit set leaves the unwritten pairs at zero in the completed table, which is an orthogonality
  # restriction, so it is refused rather than silently completed
  one_explicit_covariance = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nZ2 ~~ Z1",
  one_explicit_x_covariance = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nZ2 ~~ X",
  two_explicit_covariances = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nX ~~ Z1\nX ~~ Z2",
  correlated_disturbance = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nM ~~ Y",
  covariate_disturbance_covariance = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nM ~~ Z2",
  outcome_covariate_disturbance_covariance = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nY ~~ Z1",
  tied_covariate_paths = "M ~ p*X + p*Z1 + Z2\nY ~ M + X + Z1 + Z2",
  tied_outcome_paths = "M ~ X + Z1 + Z2\nY ~ M + q*X + Z1 + q*Z2",
  equality_constraint = "M ~ p*X + r*Z1 + Z2\nY ~ M + X + Z1 + Z2\np == r",
  defined_parameter = "M ~ p*X + Z1 + Z2\nY ~ b*M + X + Z1 + Z2\nab := p*b",
  bounded_start = "M ~ start(.5)*X + Z1 + Z2\nY ~ M + X + Z1 + Z2",
  interaction = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2 + M:X",
  covariate_as_mediator = "M ~ X + Z1\nZ2 ~ M\nY ~ Z2 + M + X + Z1",
  no_mediator_path = "M ~ X + Z1 + Z2\nY ~ X + Z1 + Z2",
  parallel_with_two_covariates = "M ~ X + Z1 + Z2\nM2 ~ X + Z1 + Z2\nY ~ M + M2 + X + Z1 + Z2"
)
g2_refusal_data <- function() {
  d <- g2_data()
  set.seed(12L)
  d$W <- stats::rnorm(nrow(d))
  d$M2 <- .3 * d$X + stats::rnorm(nrow(d))
  d
}

test_that("unadmitted topologies and direct-path policies are refused at fit before the kernel", {
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
  d <- g2_refusal_data()
  for (nm in names(g2_unadmitted)) {
    e <- tryCatch(fit_sem(g2_unadmitted[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
    expect_false(grepl("reached", conditionMessage(e)), info = nm)
    expect_error(.sem_fiml_model(g2_unadmitted[[nm]]), class = "medfit_sem_fiml_error")
  }
  expect_identical(reached, character())
  # the parser itself rejects a covariance written twice, in either order, before any FIML code is reached
  dup <- "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2\nZ1 ~~ Z2\nZ2 ~~ Z1"
  expect_error(fit_sem(dup, d, missing = "fiml", fixed_x = FALSE), class = "medfit_sem_fiml_error")
})

test_that("prepare, the argument settings and the input checks still refuse for the two-covariate model", {
  d <- g2_data()
  # the three-variable prepare and a five-column matrix against the wrong tables
  expect_error(.sem_fiml_prepare(as.matrix(d)), class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_prepare_core(as.matrix(d[, c("X", "Z1", "M", "Y")]), .sem_fiml_tables_cov(2L, TRUE)),
               class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_prepare_core(as.matrix(d[, c("Z1", "X", "Z2", "M", "Y")]), .sem_fiml_tables_cov(2L, TRUE)),
               class = "medfit_sem_fiml_error")
  expect_error(.sem_fiml_tables_cov(0L, TRUE))
  expect_error(.sem_fiml_tables_cov(3L, TRUE))
  expect_error(fit_sem(g2_model, d, missing = "fiml"), "fixed_x")
  expect_error(fit_sem(g2_model, d, missing = "fiml", fixed_x = TRUE), "fixed_x")
  expect_error(fit_sem(g2_model, d, missing = "fiml", fixed_x = c("X", "Z1")), "fixed_x")
  expect_error(fit_sem(g2_model, d, missing = "fiml", fixed_x = FALSE, weights = rep(1, nrow(d))),
               class = "medfit_sem_fiml_error")
  expect_error(fit_sem(g2_model, d, missing = "fiml", fixed_x = FALSE, information = "expected"),
               class = "medfit_sem_fiml_error")
  expect_error(fit_sem(g2_model, d, missing = "fiml", fixed_x = FALSE, se_type = "sandwich"),
               class = "medfit_sem_fiml_error")
  for (v in c("Z1", "Z2")) {
    d0 <- d
    d0[[v]] <- 1
    e <- tryCatch(g2_fit(d0), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input")
    d1 <- d
    d1[[v]] <- factor(sample(c("a", "b"), nrow(d), TRUE))
    expect_error(g2_fit(d1), class = "medfit_sem_fiml_error")
    d2 <- d
    d2[[v]][3L] <- Inf
    expect_error(g2_fit(d2), class = "medfit_sem_fiml_error")
    expect_error(g2_fit(d[, setdiff(names(d), v)]), "absent from data")
  }
})

test_that("extraction refuses everything outside the fitted simple model and both source-fit methods stay refused", {
  d <- g2_data()
  f <- g2_fit(d)
  refused <- list(
    list(treatment = "X", mediator = "Y"), list(treatment = "X", mediator = "M", standardized = TRUE),
    list(treatment = "X", mediator = "M", structure = "parallel"),
    list(treatment = "X", mediator = "M", decomposition = "four_way"),
    list(treatment = "X", mediator = "M", interaction = "XM"),
    list(treatment = "X", mediator = c("M", "Z1")), list(treatment = c("X", "Z1"), mediator = "M"),
    list(treatment = "W", mediator = "M")
  )
  for (args in refused) {
    expect_error(do.call(extract_mediation, c(list(f), args)), "FIML extraction supports only")
  }
  set.seed(3L)
  before <- .Random.seed
  for (m in c("parametric", "nonparametric")) {
    expect_error(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L),
                 class = "medfit_error_fiml_inference_unavailable")
  }
  # even with the stage-0 guard mocked open, the two-covariate variant is not an admitted source-fit topology
  testthat::local_mocked_bindings(.fiml_source_inference_admitted = function() TRUE)
  refit_calls <- 0L
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    refit_calls <<- refit_calls + 1L
    stop("refit reached")
  })
  for (m in c("parametric", "nonparametric")) {
    e <- tryCatch(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L), error = identity)
    expect_s3_class(e, "medfit_error_fiml_covariate_source_fit")
    expect_match(conditionMessage(e), "covariate")
  }
  expect_identical(refit_calls, 0L)
  expect_identical(.Random.seed, before)
  m <- extract_mediation(f, treatment = "X", mediator = "M")
  expect_error(bootstrap_mediation(function(x) 1, mediation_data = m), "FIML")
  expect_error(confint(m, method = "boot"), "FIML")
})

test_that("unidentified missing patterns are refused numerically with the attempt ledger", {
  d <- g2_data()
  d[1:225, "Y"] <- NA_real_
  d[226:450, c("X", "M")] <- NA_real_
  e <- tryCatch(g2_fit(d), error = identity)
  expect_s3_class(e, "medfit_sem_fiml_error")
  expect_identical(e$stage, "numerical")
})

# ---- the generalized tables reproduce the slice-1 tables exactly ----------------------------------------------------

test_that("the one-covariate tables are the slice-1 tables, unchanged", {
  expected <- function(direct) {
    a <- data.frame(
      row = c("M", "M", "Y", "Y", "Y"), col = c("X", "Z", "M", "X", "Z"),
      label = c("a", "gm", "b", "cp", "gy"), value = c(NA, NA, NA, if (direct) NA else 0, NA)
    )
    vars <- c("X", "Z", "M", "Y")
    s <- data.frame(
      row = c(vars, "X"), col = c(vars, "Z"),
      label = c("vx", "vz", "vm", "vy", "cxz"), value = NA_real_
    )
    m <- data.frame(row = vars, label = c("ix", "iz", "im", "iy"), value = NA_real_)
    list(vars = vars, a = a, s = s, m = m)
  }
  for (direct in c(TRUE, FALSE)) {
    expect_identical(.sem_fiml_tables_cov1(direct), expected(direct))
    expect_identical(.sem_fiml_tables_cov(1L, direct), expected(direct))
  }
  t2 <- .sem_fiml_tables_cov(2L, TRUE)
  expect_identical(t2$vars, c("X", "Z1", "Z2", "M", "Y"))
  expect_identical(t2$s$label[t2$s$row != t2$s$col], c("cxz1", "cxz2", "cz1z2"))
  expect_length(.sem_fiml_ram(TRUE)$par_names, 9L)
})

# ---- planted defects ------------------------------------------------------------------------------------------------

g2_kernel_gap <- function(d, ref, tables) {
  p <- .sem_fiml_prepare_core(as.matrix(d), tables)
  fit <- .sem_fiml_solve(p)
  e <- fit$estimate
  map <- c(a = "M~X", gm1 = "M~Z1", gm2 = "M~Z2", b = "Y~M", cp = "Y~X", gy1 = "Y~Z1", gy2 = "Y~Z2",
           vx = "X~~X", vz1 = "Z1~~Z1", vz2 = "Z2~~Z2", vm = "M~~M", vy = "Y~~Y", cxz1 = "X~~Z1", cxz2 = "X~~Z2",
           cz1z2 = "Z1~~Z2", ix = "X~1", iz1 = "Z1~1", iz2 = "Z2~1", im = "M~1", iy = "Y~1")
  shared <- intersect(names(e), names(map))
  est_gap <- max(abs(e[shared] - lavaan::coef(ref)[map[shared]]))
  max(est_gap, abs(-fit$nll - as.numeric(lavaan::logLik(ref))))
}

test_that("the oracles catch planted defects: dropped Z2 -> Y, dropped Z1-Z2 covariance, untransported covariance", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  d <- g2_data()
  ref <- g2_lavaan(d, g2_model)
  # positive control: the unmutated tables pass
  expect_lt(g2_kernel_gap(d, ref, .sem_fiml_tables_cov(2L, TRUE)), 1e-5)
  drop_row <- function(tab, which, label) {
    tab[[which]] <- tab[[which]][!(tab[[which]]$label == label), , drop = FALSE]
    tab
  }
  # D-a: Z2 -> Y dropped (the second covariate bypasses the outcome equation)
  expect_gt(g2_kernel_gap(d, ref, drop_row(.sem_fiml_tables_cov(2L, TRUE), "a", "gy2")), 1e-3)
  # D-b: the Z1-Z2 covariance dropped
  expect_gt(g2_kernel_gap(d, ref, drop_row(.sem_fiml_tables_cov(2L, TRUE), "s", "cz1z2")), 1e-3)
  # D-b2: an X-Z2 covariance dropped
  expect_gt(g2_kernel_gap(d, ref, drop_row(.sem_fiml_tables_cov(2L, TRUE), "s", "cxz2")), 1e-3)
  # D-c: the original-scale unit of a covariance parameter forgotten in the transport
  tr_bad <- sem_mutate(.sem_fiml_transport, "units[cv$par] <- scale[cv$row] * scale[cv$col]", "units[cv$par] <- 1")
  expect_gt(testthat::with_mocked_bindings(g2_kernel_gap(d, ref, .sem_fiml_tables_cov(2L, TRUE)),
                                           .sem_fiml_transport = tr_bad), 1e-3)
  # D-d: the effect functional uses a covariate path as the direct effect (public extraction)
  f <- g2_fit(d)
  ext_bad <- sem_mutate(.sem_fiml_extract, "c_prime = unname(map[\"cp\"])", "c_prime = unname(map[\"gy2\"])")
  mb <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = "M"),
                                       .sem_fiml_extract = ext_bad)
  expect_gt(abs(mb@estimates[["c_prime"]] - coef(f)[["Y~X"]]), 1e-3)
  # D-e: a covariate treated as the treatment reads the wrong covariate's outcome path
  ext_swap <- sem_mutate(.sem_fiml_extract, "paste0(\"gy\", sfx[i])", "paste0(\"gm\", sfx[i])")
  mz <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "Z2", mediator = "M"),
                                       .sem_fiml_extract = ext_swap)
  expect_gt(abs(mz@estimates[["c_prime"]] - coef(f)[["Y~Z2"]]), 1e-3)
})
