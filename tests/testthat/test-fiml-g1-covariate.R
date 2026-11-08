# FI-G1, slice 1: bounded Gaussian FIML with ONE observed covariate Z (random X; X, Z, M, Y jointly Gaussian), the model
# M ~ X + Z, Y ~ M + X + Z (direct X -> Y free or fixed at zero). Oracles, each independent of the production kernel:
#   lavaan   raw-data FIML (`missing = "ml"`, `fixed.x = FALSE`): estimates, SEs, the covariance of (a, b, cp), the
#            delta-method NIE SE (`ab := a * b`), and the log likelihood;
#   rowwise  a from-scratch Gaussian NLL over each row's observed subvector (no production RAM, objective or transport),
#            including its numerical gradient and Hessian at the fitted point;
#   closed   complete data: OLS regressions and ML (co)variances.

g1_data <- function(kind = "mar", n = 400L, direct = TRUE, seed = 4107L) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  z <- 1 + .4 * x + stats::rnorm(n, sd = 1.2)
  m <- .3 + .5 * x + .4 * z + stats::rnorm(n, sd = .8)
  y <- .2 + .6 * m + (if (direct) .25 else 0) * x - .3 * z + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, Z = z, M = m, Y = y)
  if (kind == "mar") {
    # every variable can be incomplete; M and Y depend (ignorably) on the observed X
    d[stats::runif(n) < .10, "X"] <- NA_real_
    d[stats::runif(n) < .10, "Z"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), "M"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}
g1_model <- "M ~ X + Z\nY ~ M + X + Z"
g1_zero_model <- "M ~ X + Z\nY ~ M + 0*X + Z"
g1_fit <- function(d = g1_data(), model = g1_model, ...) {
  fit_sem(model, d, missing = "fiml", fixed_x = FALSE, ...)
}
g1_lavaan <- function(d, model) {
  suppressWarnings(lavaan::sem(model, d, missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
                               information = "observed", control = list(rel.tol = 1e-10)))
}

# ---- independent rowwise likelihood ---------------------------------------------------------------------------------
# q names: the public coefficient names of the fit (M~X, M~Z, Y~M, [Y~X,] Y~Z, variances, X~~Z, intercepts).
g1_moments <- function(q) {
  g <- function(nm) if (nm %in% names(q)) q[[nm]] else 0
  vars <- c("X", "Z", "M", "Y")
  B <- matrix(0, 4, 4, dimnames = list(vars, vars))
  B["M", "X"] <- g("M~X")
  B["M", "Z"] <- g("M~Z")
  B["Y", "M"] <- g("Y~M")
  B["Y", "X"] <- g("Y~X")
  B["Y", "Z"] <- g("Y~Z")
  psi <- diag(c(g("X~~X"), g("Z~~Z"), g("M~~M"), g("Y~~Y")))
  psi[1, 2] <- psi[2, 1] <- g("X~~Z")
  A <- solve(diag(4) - B)
  list(mu = drop(A %*% c(g("X~1"), g("Z~1"), g("M~1"), g("Y~1"))), sigma = A %*% psi %*% t(A))
}
g1_nll <- function(d, q) gk_row_nll(as.matrix(d[, c("X", "Z", "M", "Y")]), g1_moments(q))
g1_hessian <- function(f, q) {
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
g1_rel_gap <- function(V, ref) max(abs(V - ref) / sqrt(outer(diag(ref), diag(ref))))

# ---- fit versus lavaan and the rowwise oracle -----------------------------------------------------------------------

test_that("one-covariate FIML matches lavaan raw-data FIML: estimates, covariance, logLik, NIE SE", {
  skip_if_not_installed("lavaan")
  d <- g1_data()
  expect_true(all(vapply(d, anyNA, logical(1))))
  f <- g1_fit(d)
  expect_s3_class(f, "medfit::SEMFit")
  ref <- g1_lavaan(d, g1_model)
  q <- coef(f)
  expect_setequal(names(q), names(lavaan::coef(ref)))
  expect_length(q, 14L)
  expect_lt(max(abs(q - lavaan::coef(ref)[names(q)])), 1e-5)
  expect_lt(g1_rel_gap(vcov(f), lavaan::vcov(ref)[names(q), names(q)]), 1e-3)
  expect_lt(abs(as.numeric(stats::logLik(f)) - as.numeric(lavaan::logLik(ref))), 1e-6)
  expect_identical(attr(stats::logLik(f), "df"), 14L)
  # effects: NIE, NDE, TE and their delta-method SEs against lavaan's defined parameters
  lab <- "M ~ a*X + Z\nY ~ b*M + cp*X + Z\nnie := a*b\nte := cp + a*b"
  rl <- g1_lavaan(d, lab)
  pe <- lavaan::parameterEstimates(rl)
  m <- extract_mediation(f, treatment = "X", mediator = "M")
  expect_s3_class(m, "medfit::FIMLMediationData")
  expect_equal(as.numeric(nie(m)), pe$est[pe$label == "nie"], tolerance = 1e-5)
  expect_equal(as.numeric(te(m)), pe$est[pe$label == "te"], tolerance = 1e-5)
  tt <- generics::tidy(m, type = "effects")
  expect_equal(tt$std_error[tt$term == "nie"], pe$se[pe$label == "nie"], tolerance = 2e-3)
  expect_equal(tt$std_error[tt$term == "te"], pe$se[pe$label == "te"], tolerance = 2e-3)
  # the full covariance of the three mediation paths
  V3 <- m@vcov[c("a", "b", "c_prime"), c("a", "b", "c_prime")]
  r3 <- lavaan::vcov(rl)[c("a", "b", "cp"), c("a", "b", "cp")]
  expect_lt(g1_rel_gap(V3, r3), 1e-3)
  expect_equal(unname(m@a_path), q[["M~X"]])
  expect_equal(unname(m@b_path), q[["Y~M"]])
  expect_equal(unname(m@c_prime), q[["Y~X"]])
  expect_identical(m@n_obs, f@n_obs)
})

test_that("one-covariate FIML equals the rowwise likelihood oracle and is a local optimum (observed information)", {
  d <- g1_data()
  f <- g1_fit(d)
  q <- coef(f)
  nll <- function(x) g1_nll(d, stats::setNames(x, names(q)))
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
  V <- solve(g1_hessian(nll, q))
  expect_lt(g1_rel_gap(vcov(f), V), 1e-3)
})

test_that("a missing pattern sweep keeps every pattern including singletons and an all-empty row", {
  skip_if_not_installed("lavaan")
  d <- g1_data()
  d <- rbind(d, data.frame(X = NA_real_, Z = NA_real_, M = NA_real_, Y = NA_real_))
  f <- g1_fit(d)
  expect_identical(f@n_dropped, 1L)
  expect_identical(f@n_obs, nrow(d) - 1L)
  ref <- g1_lavaan(d, g1_model)
  q <- coef(f)
  expect_lt(max(abs(q - lavaan::coef(ref)[names(q)])), 1e-5)
})

test_that("complete data: one-covariate FIML equals closed-form OLS and ML covariances", {
  d <- g1_data("complete")
  f <- g1_fit(d)
  q <- coef(f)
  mm <- stats::coef(stats::lm(M ~ X + Z, d))
  ym <- stats::coef(stats::lm(Y ~ M + X + Z, d))
  expect_equal(q[["M~X"]], mm[["X"]], tolerance = 1e-6)
  expect_equal(q[["M~Z"]], mm[["Z"]], tolerance = 1e-6)
  expect_equal(q[["M~1"]], mm[["(Intercept)"]], tolerance = 1e-6)
  expect_equal(q[["Y~M"]], ym[["M"]], tolerance = 1e-6)
  expect_equal(q[["Y~X"]], ym[["X"]], tolerance = 1e-6)
  expect_equal(q[["Y~Z"]], ym[["Z"]], tolerance = 1e-6)
  n <- nrow(d)
  expect_equal(q[["M~~M"]], sum(stats::resid(stats::lm(M ~ X + Z, d))^2) / n, tolerance = 1e-6)
  expect_equal(q[["Y~~Y"]], sum(stats::resid(stats::lm(Y ~ M + X + Z, d))^2) / n, tolerance = 1e-6)
  S <- stats::cov(d) * (n - 1) / n
  expect_equal(q[["X~~X"]], S["X", "X"], tolerance = 1e-6)
  expect_equal(q[["Z~~Z"]], S["Z", "Z"], tolerance = 1e-6)
  expect_equal(q[["X~~Z"]], S["X", "Z"], tolerance = 1e-6)
  expect_equal(q[["X~1"]], mean(d$X), tolerance = 1e-6)
  # neutrality: the complete-data native listwise fit (fixed_x = FALSE) has the same structural estimates and SEs
  lw <- fit_sem(g1_model, d, fixed_x = FALSE, meanstructure = TRUE)
  shared <- c("M~X", "M~Z", "Y~M", "Y~X", "Y~Z", "M~~M", "Y~~Y")
  expect_equal(q[shared], coef(lw)[shared], tolerance = 1e-5)
  expect_equal(sqrt(diag(vcov(f)))[shared], sqrt(diag(vcov(lw)))[shared], tolerance = 1e-3)
  expect_equal(f@internals$likelihood$rows$complete, nrow(d))
})

test_that("a direct path fixed at zero is a fixed row, not a parameter, and matches lavaan", {
  skip_if_not_installed("lavaan")
  d <- g1_data(direct = FALSE)
  f <- g1_fit(d, g1_zero_model)
  q <- coef(f)
  expect_length(q, 13L)
  expect_false("Y~X" %in% names(q))
  ref <- g1_lavaan(d, g1_zero_model)
  expect_lt(max(abs(q - lavaan::coef(ref)[names(q)])), 1e-5)
  expect_lt(g1_rel_gap(vcov(f), lavaan::vcov(ref)[names(q), names(q)]), 1e-3)
  m <- extract_mediation(f, treatment = "X", mediator = "M")
  expect_identical(unname(m@c_prime), 0)
  expect_equal(as.numeric(nde(m)), 0)
  expect_equal(as.numeric(te(m)), as.numeric(nie(m)))
  expect_false(any(f@table$free[f@table$lhs == "Y" & f@table$rhs == "X"]))
  # the zero is on the treatment's direct path: the covariate cannot be the treatment of this fit
  f <- g1_fit(d, g1_zero_model)
  expect_error(extract_mediation(f, treatment = "Z", mediator = "M"), "FIML extraction supports only")
  # a zero on the other exogenous variable's path makes THAT variable the treatment
  fz <- g1_fit(d, "M ~ X + Z\nY ~ M + X + 0*Z")
  expect_error(extract_mediation(fz, treatment = "X", mediator = "M"), "FIML extraction supports only")
  mz <- extract_mediation(fz, treatment = "Z", mediator = "M")
  expect_identical(unname(mz@c_prime), 0)
})

test_that("either exogenous variable may be the treatment when both outcome paths are free", {
  skip_if_not_installed("lavaan")
  d <- g1_data()
  f <- g1_fit(d)
  q <- coef(f)
  rl <- g1_lavaan(d, "M ~ a*Z + X\nY ~ b*M + cp*Z + X\nnie := a*b")
  mz <- extract_mediation(f, treatment = "Z", mediator = "M")
  expect_equal(unname(mz@a_path), q[["M~Z"]])
  expect_equal(unname(mz@c_prime), q[["Y~Z"]])
  pe <- lavaan::parameterEstimates(rl)
  expect_equal(as.numeric(nie(mz)), pe$est[pe$label == "nie"], tolerance = 1e-5)
  tt <- generics::tidy(mz, type = "effects")
  expect_equal(tt$std_error[tt$term == "nie"], pe$se[pe$label == "nie"], tolerance = 2e-3)
  expect_lt(g1_rel_gap(mz@vcov[c("a", "b", "c_prime"), c("a", "b", "c_prime")],
                       lavaan::vcov(rl)[c("a", "b", "cp"), c("a", "b", "cp")]), 1e-3)
  # the mediator and the outcome are not exogenous
  expect_error(extract_mediation(f, treatment = "M", mediator = "X"), "FIML extraction supports only")
  expect_error(extract_mediation(f, treatment = "X", mediator = "M", outcome = "Z"), "FIML extraction supports only")
})

test_that("an omitted Y path is refused (a covariate acting on M only is not a complete covariate)", {
  d <- g1_data()
  for (mod in c("M ~ X + Z\nY ~ M + Z", "M ~ X + Z\nY ~ M + X")) {
    e <- tryCatch(g1_fit(d, mod), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input")
  }
})

test_that("explicit and automatic exogenous covariances, labels and variable order give the same fit", {
  d <- g1_data()
  base <- coef(g1_fit(d))
  for (mod in c(paste0(g1_model, "\nX ~~ Z"), paste0(g1_model, "\nZ ~~ X"), "Y ~ M + Z + X\nM ~ Z + X",
                "M ~ p*X + r*Z\nY ~ s*M + t*X + u*Z")) {
    q <- coef(g1_fit(d, mod))
    expect_equal(sort(unname(q)), sort(unname(base)), tolerance = 1e-6)
  }
  # a label that equals a reserved alias must not change roles
  m <- extract_mediation(g1_fit(d, "M ~ cp*X + b*Z\nY ~ a*M + X + Z"), treatment = "X", mediator = "M")
  expect_equal(unname(m@a_path), base[["M~X"]], tolerance = 1e-6)
  expect_equal(unname(m@b_path), base[["Y~M"]], tolerance = 1e-6)
})

# ---- refusals: every other topology and direct-path policy ----------------------------------------------------------

g1_unadmitted <- c(
  both_outcome_paths_omitted = "M ~ X + Z\nY ~ M",
  covariate_only_on_mediator = "M ~ X + Z\nY ~ M + X",
  covariate_only_on_outcome = "M ~ X\nY ~ M + X + Z",
  three_covariates = "M ~ X + Z + W + V\nY ~ M + X + Z + W + V",
  covariate_zero_on_outcome_and_x_zero = "M ~ X + Z\nY ~ M + 0*X + 0*Z",
  fixed_nonzero_x_path = "M ~ X + Z\nY ~ M + 0.5*X + Z",
  fixed_zero_mediator_covariate_path = "M ~ X + 0*Z\nY ~ M + X + Z",
  fixed_nonzero_covariate_path = "M ~ X + Z\nY ~ M + X + 0.3*Z",
  orthogonal_exogenous = "M ~ X + Z\nY ~ M + X + Z\nX ~~ 0*Z",
  correlated_disturbance = "M ~ X + Z\nY ~ M + X + Z\nM ~~ Y",
  covariate_disturbance_covariance = "M ~ X + Z\nY ~ M + X + Z\nM ~~ Z",
  tied_covariate_paths = "M ~ p*X + p*Z\nY ~ M + X + Z",
  tied_outcome_paths = "M ~ X + Z\nY ~ M + q*X + q*Z",
  equality_constraint = "M ~ p*X + r*Z\nY ~ M + X + Z\np == r",
  defined_parameter = "M ~ p*X + Z\nY ~ b*M + X + Z\nab := p*b",
  bounded_start = "M ~ start(.5)*X + Z\nY ~ M + X + Z",
  interaction = "M ~ X + Z\nY ~ M + X + Z + M:X",
  covariate_as_mediator = "M ~ X\nZ ~ M\nY ~ Z + M + X",
  no_mediator_path = "M ~ X + Z\nY ~ X + Z",
  parallel_with_covariate = "M ~ X + Z\nM2 ~ X + Z\nY ~ M + M2 + X + Z"
)
g1_refusal_data <- function() {
  d <- g1_data()
  set.seed(11L)
  d$W <- stats::rnorm(nrow(d))
  d$V <- stats::rnorm(nrow(d))
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
  d <- g1_refusal_data()
  for (nm in names(g1_unadmitted)) {
    e <- tryCatch(fit_sem(g1_unadmitted[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
    expect_false(grepl("reached", conditionMessage(e)), info = nm)
    expect_error(.sem_fiml_model(g1_unadmitted[[nm]]), class = "medfit_sem_fiml_error")
  }
  expect_identical(reached, character())
})

test_that("the three-variable prepare, the argument settings and the input checks still refuse", {
  d <- g1_data()
  expect_error(.sem_fiml_prepare(as.matrix(d)), class = "medfit_sem_fiml_error")
  expect_error(fit_sem(g1_model, d, missing = "fiml"), "fixed_x")
  expect_error(fit_sem(g1_model, d, missing = "fiml", fixed_x = TRUE), "fixed_x")
  expect_error(fit_sem(g1_model, d, missing = "fiml", fixed_x = "X"), "fixed_x")
  expect_error(fit_sem(g1_model, d, missing = "fiml", fixed_x = FALSE, weights = rep(1, nrow(d))),
               class = "medfit_sem_fiml_error")
  expect_error(fit_sem(g1_model, d, missing = "fiml", fixed_x = FALSE, information = "expected"),
               class = "medfit_sem_fiml_error")
  # a covariate with no positive scale, a factor covariate, and an Inf cell are refused at input
  d0 <- d
  d0$Z <- 1
  e <- tryCatch(g1_fit(d0), error = identity)
  expect_s3_class(e, "medfit_sem_fiml_error")
  expect_identical(e$stage, "input")
  d1 <- d
  d1$Z <- factor(sample(c("a", "b"), nrow(d), TRUE))
  expect_error(g1_fit(d1), class = "medfit_sem_fiml_error")
  d2 <- d
  d2$Z[3L] <- Inf
  expect_error(g1_fit(d2), class = "medfit_sem_fiml_error")
  d3 <- d[, c("X", "M", "Y")]
  expect_error(g1_fit(d3), "absent from data")
})

test_that("extraction refuses everything outside the fitted simple model and both source-fit methods stay refused", {
  d <- g1_data()
  f <- g1_fit(d)
  refused <- list(
    list(treatment = "X", mediator = "Y"), list(treatment = "X", mediator = "M", standardized = TRUE),
    list(treatment = "X", mediator = "M", structure = "parallel"),
    list(treatment = "X", mediator = "M", decomposition = "four_way"),
    list(treatment = "X", mediator = "M", interaction = "XM"),
    list(treatment = "X", mediator = c("M", "Z"))
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
  # even with the stage-0 guard mocked open, the covariate variant is not an admitted source-fit topology
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
  # other consumers keep refusing the extracted object
  m <- extract_mediation(f, treatment = "X", mediator = "M")
  expect_error(bootstrap_mediation(function(x) 1, mediation_data = m), "FIML")
  expect_error(confint(m, method = "boot"), "FIML")
})

test_that("unidentified missing patterns are refused numerically with the attempt ledger", {
  d <- g1_data()
  d[1:200, "Y"] <- NA_real_
  d[201:400, c("X", "M")] <- NA_real_
  e <- tryCatch(g1_fit(d), error = identity)
  expect_s3_class(e, "medfit_sem_fiml_error")
  expect_identical(e$stage, "numerical")
})

# ---- planted defects ------------------------------------------------------------------------------------------------

g1_kernel_gap <- function(d, ref, tables) {
  p <- .sem_fiml_prepare_core(as.matrix(d), tables)
  fit <- .sem_fiml_solve(p)
  e <- fit$estimate
  map <- c(a = "M~X", gm = "M~Z", b = "Y~M", cp = "Y~X", gy = "Y~Z", vx = "X~~X", vz = "Z~~Z", vm = "M~~M",
           vy = "Y~~Y", cxz = "X~~Z", ix = "X~1", iz = "Z~1", im = "M~1", iy = "Y~1")
  shared <- intersect(names(e), names(map))
  est_gap <- max(abs(e[shared] - lavaan::coef(ref)[map[shared]]))
  max(est_gap, abs(-fit$nll - as.numeric(lavaan::logLik(ref))))
}

test_that("the oracles catch planted defects: dropped Z -> Y path, dropped X-Z covariance, untransported covariance", {
  skip_if_not_installed("lavaan")
  fx_skip_covr()
  d <- g1_data()
  ref <- g1_lavaan(d, g1_model)
  # positive control: the unmutated tables pass
  expect_lt(g1_kernel_gap(d, ref, .sem_fiml_tables_cov1(TRUE)), 1e-5)
  drop_row <- function(tab, which, col, label) {
    tab[[which]] <- tab[[which]][!(tab[[which]]$label == label), , drop = FALSE]
    tab
  }
  # D-a: Z -> Y dropped (the covariate bypasses the outcome equation)
  no_zy <- drop_row(.sem_fiml_tables_cov1(TRUE), "a", NULL, "gy")
  expect_gt(g1_kernel_gap(d, ref, no_zy), 1e-3)
  # D-b: the exogenous covariance dropped (X and Z treated as independent)
  no_cxz <- drop_row(.sem_fiml_tables_cov1(TRUE), "s", NULL, "cxz")
  expect_gt(g1_kernel_gap(d, ref, no_cxz), 1e-3)
  # D-c: the original-scale unit of a covariance parameter forgotten in the transport
  tr_bad <- sem_mutate(.sem_fiml_transport, "units[cv$par] <- scale[cv$row] * scale[cv$col]", "units[cv$par] <- 1")
  expect_gt(testthat::with_mocked_bindings(g1_kernel_gap(d, ref, .sem_fiml_tables_cov1(TRUE)),
                                           .sem_fiml_transport = tr_bad), 1e-3)
  # D-d: the effect functional uses the wrong covariate path as the direct effect (public extraction)
  f <- g1_fit(d)
  ext_bad <- sem_mutate(.sem_fiml_extract, "c_prime = unname(map[\"cp\"])", "c_prime = unname(map[\"gy\"])")
  mb <- testthat::with_mocked_bindings(extract_mediation(f, treatment = "X", mediator = "M"),
                                       .sem_fiml_extract = ext_bad)
  expect_gt(abs(mb@estimates[["c_prime"]] - coef(f)[["Y~X"]]), 1e-3)
})
