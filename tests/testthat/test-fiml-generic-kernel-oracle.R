# FI-G0b: independent reference oracles for the observed-data FIML kernel (spec:
# planning/specs/SPEC-fiml-generic-kernel-2026-11-08.md). Every reference below is a from-scratch calculation
# (explicit matrices, rowwise loops, closed-form recursive-regression inversion). The production kernel appears only
# as the code under test. Tests are written against the existing X -> M -> Y kernel; the reference itself is
# dimension-generic (a path matrix B, disturbance variances psi, intercepts nu).

# ---- reference calculations (no production helpers) ----------------------------------------------------------------

# Implied moments of a recursive model: mu = (I - B)^-1 nu, Sigma = (I - B)^-1 Psi (I - B)^-T.
gk_implied <- function(B, psi, nu) {
  A <- solve(diag(nrow(B)) - B)
  list(mu = drop(A %*% nu), sigma = A %*% diag(psi, length(psi)) %*% t(A))
}
# The three-variable adapter: theta is named a, b, [cp,] vx, vm, vy, ix, im, iy; variable order X, M, Y.
gk_theta_moments <- function(theta) {
  B <- matrix(0, 3, 3)
  B[2, 1] <- theta[["a"]]
  B[3, 2] <- theta[["b"]]
  if ("cp" %in% names(theta)) B[3, 1] <- theta[["cp"]]
  gk_implied(B, theta[c("vx", "vm", "vy")], theta[c("ix", "im", "iy")])
}
# Rowwise Gaussian NLL over observed subvectors; all-empty rows contribute exactly zero.
gk_row_nll <- function(d, mom) {
  sum(vapply(seq_len(nrow(d)), function(i) {
    j <- which(!is.na(d[i, ]))
    if (!length(j)) return(0)
    r <- as.numeric(d[i, j]) - mom$mu[j]
    S <- mom$sigma[j, j, drop = FALSE]
    .5 * (length(j) * log(2 * pi) + as.numeric(determinant(S, logarithm = TRUE)$modulus) +
            drop(t(r) %*% solve(S, r)))
  }, numeric(1)))
}
gk_center <- function(d) colMeans(d, na.rm = TRUE)
gk_scale <- function(d) apply(d, 2, stats::sd, na.rm = TRUE)
gk_standardize <- function(d) sweep(sweep(d, 2, gk_center(d)), 2, gk_scale(d), `/`)
# Standardized-coordinate NLL and the original-scale NLL it implies (moments mapped by mu = c + D mu_s).
gk_nll_std <- function(d, theta) gk_row_nll(gk_standardize(d), gk_theta_moments(theta))
gk_nll_original <- function(d, theta) {
  m <- gk_theta_moments(theta)
  s <- gk_scale(d)
  gk_row_nll(d, list(mu = gk_center(d) + s * m$mu, sigma = diag(s) %*% m$sigma %*% diag(s)))
}
# Recover structural parameters from moments by recursive regressions (inverse of gk_implied for X -> M -> Y).
gk_recover <- function(mom, direct) {
  S <- mom$sigma
  mu <- mom$mu
  a <- S[2, 1] / S[1, 1]
  if (direct) {
    coef <- solve(S[c(2, 1), c(2, 1)], S[c(2, 1), 3])
    b <- coef[[1]]
    cp <- coef[[2]]
    vy <- S[3, 3] - sum(coef * S[c(2, 1), 3])
  } else {
    b <- S[2, 3] / S[2, 2]
    cp <- 0
    vy <- S[3, 3] - b * S[2, 3]
  }
  q <- c(a = a, b = b, cp = cp, vx = S[1, 1], vm = S[2, 2] - a * S[2, 1], vy = vy,
         ix = mu[[1]], im = mu[[2]] - a * mu[[1]], iy = mu[[3]] - b * mu[[2]] - cp * mu[[1]])
  if (!direct) q <- q[names(q) != "cp"]
  q
}
# Central differences with Richardson extrapolation, independent of production derivatives.
gk_gradient <- function(f, theta) {
  vapply(seq_along(theta), function(k) {
    fo_richardson(lapply(.02 / 2^(0:3), function(h) {
      e <- theta * 0
      e[k] <- h
      (f(theta + e) - f(theta - e)) / (2 * h)
    }))
  }, numeric(1))
}

# Discrepancy summaries, each returning Inf when the code under test errors (a mutation that crashes is caught).
gk_safe <- function(expr) tryCatch(suppressWarnings(expr), error = function(e) Inf)
gk_value_gap <- function(d, direct, theta, prepare = .sem_fiml_prepare, eval = .sem_fiml_eval) {
  gk_safe({
    p <- prepare(d, direct = direct)
    th <- stats::setNames(theta[p$ram$par_names], p$ram$par_names)
    abs(eval(th, p, derivative = FALSE)$value + p$jacobian - gk_nll_original(d, theta))
  })
}
gk_group_gap <- function(d, direct, prepare = .sem_fiml_prepare) {
  gk_safe({
    p <- prepare(d, direct = direct)
    z <- gk_standardize(d)
    gaps <- vapply(p$groups, function(g) {
      if (!length(g$cols)) return(if (any(!is.na(d[g$ids, , drop = FALSE]))) Inf else 0)
      block <- z[g$ids, g$cols, drop = FALSE]
      mn <- colMeans(block)
      cv <- crossprod(sweep(block, 2, mn)) / nrow(block)
      max(abs(g$mean - mn), abs(g$covariance - cv), abs(g$n - nrow(block)))
    }, numeric(1))
    max(gaps)
  })
}
gk_transport_gap <- function(d, direct, prepare = .sem_fiml_prepare) {
  gk_safe({
    p <- prepare(d, direct = direct)
    q_of <- function(th) {
      s <- gk_scale(d)
      m <- gk_theta_moments(th)
      gk_recover(list(mu = gk_center(d) + s * m$mu, sigma = diag(s) %*% m$sigma %*% diag(s)), direct)
    }
    gaps <- vapply(c(11L, 12L), function(seed) {
      th <- gk_theta(direct, seed)[p$ram$par_names]
      code <- p$offset + as.vector(p$transport %*% th)
      max(abs(code - q_of(th)[p$ram$par_names]))
    }, numeric(1))
    th1 <- gk_theta(direct, 11L)[p$ram$par_names]
    th2 <- gk_theta(direct, 12L)[p$ram$par_names]
    lin <- as.vector(p$transport %*% (th1 - th2)) - (q_of(th1) - q_of(th2))[p$ram$par_names]
    max(gaps, abs(lin))
  })
}
gk_n_gap <- function(d, direct, prepare = .sem_fiml_prepare) {
  gk_safe({
    p <- prepare(d, direct = direct)
    abs(p$n - sum(rowSums(!is.na(d)) > 0L))
  })
}

# ---- R1 to R4: value, groups, transport, gradient against the references ------------------------------------------

for (direct in c(TRUE, FALSE)) {
  for (kind in gk_kinds) {
    cell <- paste(kind, if (direct) "free" else "zero")
    test_that(paste("FIML observed-subvector likelihood and constants match the rowwise reference:", cell), {
      d <- gk_data(kind)
      for (seed in 1:3) {
        expect_lt(gk_value_gap(d, direct, gk_theta(direct, seed)), 1e-8)
      }
      p <- .sem_fiml_prepare(d, direct = direct)
      # R6 constants: the log-Jacobian is the observed-entry count weighted log scale, per column.
      expect_equal(p$jacobian, sum(colSums(!is.na(d)) * log(gk_scale(d))), tolerance = 1e-12)
    })
    test_that(paste("FIML pattern summaries equal a from-scratch recomputation:", cell), {
      d <- gk_data(kind)
      expect_lt(gk_group_gap(d, direct), 1e-12)
      p <- .sem_fiml_prepare(d, direct = direct)
      ids <- unname(unlist(lapply(p$groups, `[[`, "ids")))
      expect_identical(sort(ids), seq_len(nrow(d)))
      expect_false(anyDuplicated(ids) > 0L)
      keys <- apply(!is.na(d), 1, paste0, collapse = "")
      expect_setequal(names(p$groups), unique(keys))
      for (nm in names(p$groups)) {
        expect_true(all(keys[p$groups[[nm]]$ids] == nm))
        expect_identical(p$groups[[nm]]$cols, which(!is.na(d[p$groups[[nm]]$ids[1L], ])))
      }
    })
    test_that(paste("FIML transport equals the moment-recovered original-scale parameters:", cell), {
      d <- gk_data(kind)
      expect_lt(gk_transport_gap(d, direct), 1e-9)
      p <- .sem_fiml_prepare(d, direct = direct)
      expect_identical(rownames(p$transport), p$ram$par_names)
      expect_identical(colnames(p$transport), p$ram$par_names)
    })
    test_that(paste("FIML analytic gradient equals central differences of the reference:", cell), {
      d <- gk_data(kind)
      p <- .sem_fiml_prepare(d, direct = direct)
      th <- gk_theta(direct, 5L)[p$ram$par_names]
      reference <- gk_gradient(function(x) gk_nll_std(d, stats::setNames(x, names(th))), th)
      actual <- .sem_fiml_eval(th, p)$gradient
      expect_lt(max(abs(actual - reference)) / max(1, max(abs(reference))), 1e-6)
    })
  }
}

# ---- R5: row identities, empty rows, permutation invariance --------------------------------------------------------

test_that("FIML row identities, retained and empty rows follow the declared contract", {
  d <- gk_data("all7")
  ids <- paste0("r", sprintf("%03d", seq_len(nrow(d))))
  p <- .sem_fiml_prepare(d, direct = TRUE, row_id = ids)
  empty <- which(rowSums(!is.na(d)) == 0L)
  expect_identical(p$rows$original, ids)
  expect_identical(p$rows$empty, ids[empty])
  expect_identical(p$rows$retained, ids[-empty])
  expect_identical(p$n, nrow(d) - length(empty))
  expect_length(empty, 2L)
  # Empty rows sit in a group with no columns that is skipped everywhere.
  expect_length(p$groups[["FALSEFALSEFALSE"]]$cols, 0L)
  expect_identical(p$groups[["FALSEFALSEFALSE"]]$n, length(empty))
  th <- gk_theta(TRUE, 3L)[p$ram$par_names]
  with_empty <- .sem_fiml_eval(th, p)$value
  without <- .sem_fiml_eval(th, .sem_fiml_prepare(d[-empty, ], direct = TRUE))$value
  expect_equal(with_empty, without, tolerance = 1e-12)
  # Group membership by id is invariant to row order, and so is the likelihood.
  set.seed(77L)
  perm <- sample(nrow(d))
  q <- .sem_fiml_prepare(d[perm, ], direct = TRUE, row_id = ids[perm])
  members <- function(pp) {
    lapply(pp$groups, function(g) sort(pp$rows$original[g$ids]))
  }
  expect_identical(members(q)[sort(names(q$groups))], members(p)[sort(names(p$groups))])
  expect_identical(sort(q$rows$empty), sort(p$rows$empty))
  expect_equal(.sem_fiml_eval(th, q)$value, with_empty, tolerance = 1e-10)
  expect_equal(q$jacobian, p$jacobian, tolerance = 1e-12)
  expect_identical(gk_n_gap(d, TRUE), 0L)
})

test_that("FIML values shift by exactly the log-Jacobian under an affine rescaling of the data", {
  d <- gk_data("pairs")
  s <- c(3, .5, 2)
  d2 <- sweep(sweep(d, 2, s, `*`), 2, c(2, -3, 4), `+`)
  p1 <- .sem_fiml_prepare(d, direct = TRUE)
  p2 <- .sem_fiml_prepare(d2, direct = TRUE)
  th <- gk_theta(TRUE, 9L)[p1$ram$par_names]
  expect_equal(.sem_fiml_eval(th, p1)$value, .sem_fiml_eval(th, p2)$value, tolerance = 1e-10)
  expect_equal(p2$jacobian - p1$jacobian, sum(colSums(!is.na(d)) * log(s)), tolerance = 1e-10)
  expect_equal(p2$scale, p1$scale * s, tolerance = 1e-12)
})

# ---- R7: refusals preserved at prepare, fit, extract and both source-fit methods -----------------------------------

test_that("FIML prepare refuses exactly the documented inputs", {
  d <- gk_data("all7")
  bad <- function(expr, message) {
    e <- tryCatch(expr, error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(conditionMessage(e), message)
  }
  bad(.sem_fiml_prepare(d, fixed_x = TRUE), "unsupported FIML setting")
  bad(.sem_fiml_prepare(d, extra = 1), "unsupported FIML setting")
  bad(.sem_fiml_prepare(d, direct = NA), "unsupported FIML setting")
  bad(.sem_fiml_prepare(d, direct = c(TRUE, FALSE)), "unsupported FIML setting")
  bad(.sem_fiml_prepare(as.data.frame(d)), "invalid FIML input")
  bad(.sem_fiml_prepare(d[, 1:2]), "invalid FIML input")
  bad(.sem_fiml_prepare(d[, c("M", "X", "Y")]), "invalid FIML input")
  bad(.sem_fiml_prepare(cbind(d, C = 1)), "invalid FIML input")
  inf <- d
  inf[4L, "M"] <- Inf
  bad(.sem_fiml_prepare(inf), "invalid FIML input")
  bad(.sem_fiml_prepare(d, row_id = seq_len(nrow(d) - 1L)), "invalid FIML input")
  bad(.sem_fiml_prepare(d, row_id = rep(1L, nrow(d))), "invalid FIML input")
  na_id <- seq_len(nrow(d))
  na_id[2L] <- NA
  bad(.sem_fiml_prepare(d, row_id = na_id), "invalid FIML input")
  one <- d
  one[-1L, "Y"] <- NA_real_
  bad(.sem_fiml_prepare(one), "variable has insufficient observations")
  flat <- d
  flat[, "M"] <- 1
  bad(.sem_fiml_prepare(flat), "variable has no positive scale")
  # Current behavior recorded in the spec (open question 3): NaN is treated as missing, not refused.
  nan <- d
  nan[4L, "M"] <- NaN
  expect_no_error(.sem_fiml_prepare(nan))
})

gk_fit_data <- function() {
  d <- as.data.frame(gk_data("all7"))
  set.seed(5L)
  d$C <- stats::rnorm(nrow(d))
  d$M2 <- .3 * d$X + stats::rnorm(nrow(d))
  d
}
gk_unadmitted <- c(
  covariate_on_mediator = "M ~ a*X + C\nY ~ b*M + cp*X",
  covariate_on_outcome = "M ~ a*X\nY ~ b*M + cp*X + C",
  parallel = "M ~ a1*X\nM2 ~ a2*X\nY ~ b1*M + b2*M2 + cp*X",
  serial = "M ~ a*X\nM2 ~ d*M + e*X\nY ~ b*M2 + f*M + cp*X",
  correlated_disturbance = "M ~ a*X\nY ~ b*M + cp*X\nM ~~ Y",
  no_mediator_path = "M ~ a*X\nY ~ cp*X",
  interaction = "M ~ a*X\nY ~ b*M + cp*X + M:X",
  fixed_nonzero_direct = "M ~ a*X\nY ~ b*M + 0.5*X",
  fixed_mediator_path = "M ~ 0*X\nY ~ b*M + cp*X",
  tied_paths = "M ~ a*X\nY ~ a*M + cp*X",
  equality_constraint = "M ~ a*X\nY ~ b*M + cp*X\na == b",
  defined_parameter = "M ~ a*X\nY ~ b*M + cp*X\nab := a*b",
  bounded_start = "M ~ start(.5)*X\nY ~ b*M + cp*X"
)

test_that("unadmitted topologies and direct-path policies are refused at fit before the numerical kernel", {
  reached <- character()
  testthat::local_mocked_bindings(
    .sem_fiml_prepare = function(...) {
      reached <<- c(reached, "prepare")
      stop("prepare reached")
    },
    .sem_fiml_fit = function(...) {
      reached <<- c(reached, "fit")
      stop("kernel reached")
    }
  )
  d <- gk_fit_data()
  for (nm in names(gk_unadmitted)) {
    e <- tryCatch(fit_sem(gk_unadmitted[[nm]], d, missing = "fiml", fixed_x = FALSE), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input", info = nm)
    expect_false(grepl("reached", conditionMessage(e)), info = nm)
    expect_error(.sem_fiml_model(gk_unadmitted[[nm]]), class = "medfit_sem_fiml_error")
  }
  expect_identical(reached, character())
})

test_that("admitted direct-path policies are exactly free and fixed at zero", {
  expect_identical(.sem_fiml_model("M ~ a*X\nY ~ b*M + cp*X")$direct, TRUE)
  expect_identical(.sem_fiml_model("M ~ a*X\nY ~ b*M + 0*X")$direct, FALSE)
  expect_identical(.sem_fiml_model("M ~ a*X\nY ~ b*M")$direct, FALSE)
  expect_identical(names(.sem_fiml_model("M ~ a*X\nY ~ b*M + cp*X")$map),
                   c("a", "b", "cp", "vx", "vm", "vy", "ix", "im", "iy"))
  expect_identical(names(.sem_fiml_model("M ~ a*X\nY ~ b*M")$map),
                   c("a", "b", "vx", "vm", "vy", "ix", "im", "iy"))
})

test_that("extraction and both source-fit methods refuse everything outside the fitted simple model", {
  d <- as.data.frame(gk_data("all7"))
  f <- fit_sem("M ~ a*X\nY ~ b*M + cp*X", d, missing = "fiml", fixed_x = FALSE)
  expect_s3_class(extract_mediation(f, treatment = "X", mediator = "M"), "medfit::FIMLMediationData")
  refused <- list(
    list(treatment = "M", mediator = "X"), list(treatment = "X", mediator = "Y"),
    list(treatment = "X", mediator = "M", standardized = TRUE),
    list(treatment = "X", mediator = "M", structure = "parallel"),
    list(treatment = "X", mediator = "M", structure = "serial"),
    list(treatment = "X", mediator = "M", decomposition = "four_way"),
    list(treatment = "X", mediator = "M", outcome = "X")
  )
  for (args in refused) {
    expect_error(do.call(extract_mediation, c(list(f), args)), "FIML extraction supports only")
  }
  # Both source-fit methods are refused by the stage-0 guard; this task does not alter the guard.
  set.seed(3L)
  before <- .Random.seed
  for (m in c("parametric", "nonparametric")) {
    expect_error(bootstrap_mediation(source_fit = f, effect = "nie", method = m, n_boot = 3L),
                 class = "medfit_error_fiml_inference_unavailable")
    expect_error(bootstrap_mediation(source_fit = lm(Y ~ X, d), effect = "nie", method = m),
                 class = "medfit_error_fiml_inference_unavailable")
  }
  expect_identical(.Random.seed, before)
})

# ---- planted defects: each oracle cell must fail under the matching mutation ---------------------------------------

test_that("the oracles catch planted defects in the kernel (positive controls included)", {
  fx_skip_covr()
  d <- gk_data("all7")
  theta <- gk_theta(TRUE, 1L)
  tol <- 1e-6
  # Unmutated controls pass, so a failure below is attributable to the mutation.
  expect_lt(gk_value_gap(d, TRUE, theta), 1e-8)
  expect_lt(gk_group_gap(d, TRUE), 1e-12)
  expect_lt(gk_transport_gap(d, TRUE), 1e-9)
  expect_identical(gk_n_gap(d, TRUE), 0L)
  # D1: ML divisor replaced by n - 1 in the pattern covariance.
  m1 <- sem_mutate(.sem_fiml_prepare, "crossprod(centered)/length(ids)", "crossprod(centered)/(length(ids) - 1)")
  expect_gt(gk_group_gap(d, TRUE, prepare = m1), tol)
  expect_gt(gk_value_gap(d, TRUE, theta, prepare = m1), tol)
  # D2: log-Jacobian counted over all rows instead of each column's observed entries.
  m2 <- sem_mutate(.sem_fiml_prepare, "sum(colSums(!is.na(data)) * log(scale))", "sum(nrow(data) * log(scale))")
  expect_gt(gk_value_gap(d, TRUE, theta, prepare = m2), tol)
  # D3: sign of the intercept transport term for the mediator equation.
  m3 <- sem_mutate(.sem_fiml_prepare, "-center[1] * units[\"a\"]", "center[1] * units[\"a\"]")
  expect_gt(gk_transport_gap(d, TRUE, prepare = m3), tol)
  # D4: empty rows counted in n.
  m4 <- sem_mutate(.sem_fiml_prepare, "n = sum(retained)", "n = length(retained)")
  expect_gt(gk_n_gap(d, TRUE, prepare = m4), 0)
  # D5: every group evaluated on all columns instead of its observed subvector.
  m5 <- sem_mutate(.sem_fiml_eval, "j <- g$cols", "j <- seq_len(ncol(sigma))")
  expect_gt(gk_value_gap(d, TRUE, theta, eval = m5), tol)
  # D6: the 2 pi constant dropped.
  m6 <- sem_mutate(.sem_fiml_eval, "length(j) * log(2 * pi)", "length(j) * 0")
  expect_gt(gk_value_gap(d, TRUE, theta, eval = m6), tol)
  # D7: sign of the mean term in the analytic gradient.
  m7 <- sem_mutate(.sem_fiml_eval, "- sum(dm[j, k] * (W %*% d))", "+ sum(dm[j, k] * (W %*% d))")
  p <- .sem_fiml_prepare(d, direct = TRUE)
  th <- theta[p$ram$par_names]
  reference <- gk_gradient(function(x) gk_nll_std(d, stats::setNames(x, names(th))), th)
  expect_lt(max(abs(.sem_fiml_eval(th, p)$gradient - reference)), 1e-6)
  expect_gt(max(abs(m7(th, p)$gradient - reference)), tol)
})
