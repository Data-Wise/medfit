# Standalone research harness. Run from the worktree root with:
# Rscript planning/studies/fiml-feasibility/study.R
stopifnot(requireNamespace("lavaan"), requireNamespace("numDeriv"))
out_dir <- "planning/studies/fiml-feasibility"
started <- Sys.time()
vars <- c("X", "M", "Y")
threshold <- c(ll_per_row = 1e-8, parameter = 1e-5, se_relative = 1e-3,
               gradient = 1e-5)

# q uses marginal means and log residual variances, not lavaan's coordinates.
moments <- function(q, direct = TRUE) {
  a <- q[4]; b <- q[5]; cp <- if (direct) q[6] else 0
  v <- exp(tail(q, 3)); vx <- v[1]; vm <- v[2]; vy <- v[3]
  t <- cp + a * b
  S <- matrix(c(vx, a * vx, t * vx,
                a * vx, a^2 * vx + vm, a * t * vx + b * vm,
                t * vx, a * t * vx + b * vm, t^2 * vx + b^2 * vm + vy), 3)
  list(mu = q[1:3], sigma = S)
}

structural <- function(q, direct = TRUE) {
  a <- q[4]; b <- q[5]; cp <- if (direct) q[6] else 0
  setNames(c(q[1], q[2] - a * q[1], q[3] - b * q[2] - cp * q[1],
             a, b, if (direct) cp, exp(tail(q, 3))),
           c("ix", "im", "iy", "a", "b", if (direct) "cp", "vx", "vm", "vy"))
}

make_groups <- function(dat) {
  keys <- apply(!is.na(dat), 1, paste0, collapse = "")
  lapply(split(seq_len(nrow(dat)), keys), function(ids) {
    cols <- which(!is.na(dat[ids[1], ]))
    list(ids = ids, cols = cols, y = dat[ids, cols, drop = FALSE])
  })
}

# Pattern evaluator uses a dense solve and log determinant.
nll <- function(q, groups, direct = TRUE) {
  m <- moments(q, direct)
  value <- tryCatch(sum(vapply(groups, function(g) {
    if (!length(g$cols)) return(0)
    S <- m$sigma[g$cols, g$cols, drop = FALSE]
    detS <- determinant(S, logarithm = TRUE)
    if (detS$sign <= 0) return(1e50)
    z <- sweep(g$y, 2, m$mu[g$cols])
    0.5 * (nrow(z) * (length(g$cols) * log(2 * pi) + as.numeric(detS$modulus)) +
             sum(z * t(solve(S, t(z)))))
  }, numeric(1))), error = function(e) 1e50)
  if (is.finite(value)) value else 1e50
}

# Separate case evaluator uses Cholesky whitening; empty rows contribute zero.
nll_cases <- function(q, dat, direct = TRUE) {
  m <- moments(q, direct)
  sum(vapply(seq_len(nrow(dat)), function(i) {
    j <- which(!is.na(dat[i, ]))
    if (!length(j)) return(0)
    U <- chol(m$sigma[j, j, drop = FALSE])
    z <- forwardsolve(t(U), dat[i, j] - m$mu[j])
    0.5 * (length(j) * log(2 * pi) + 2 * sum(log(diag(U))) + sum(z^2))
  }, numeric(1)))
}

# Independent complete-data factorization, directly from structural regressions.
nll_conditional <- function(q, dat, direct = TRUE) {
  s <- structural(q, direct)
  cp <- if (direct) s["cp"] else 0
  -sum(stats::dnorm(dat[, 1], s["ix"], sqrt(s["vx"]), log = TRUE) +
         stats::dnorm(dat[, 2], s["im"] + s["a"] * dat[, 1], sqrt(s["vm"]), log = TRUE) +
         stats::dnorm(dat[, 3], s["iy"] + s["b"] * dat[, 2] + cp * dat[, 1],
                      sqrt(s["vy"]), log = TRUE))
}

initial <- function(dat, direct) {
  cc <- dat[stats::complete.cases(dat), , drop = FALSE]
  if (nrow(cc) < 10) stop("Insufficient complete rows for this bounded initializer")
  fm <- stats::lm(M ~ X, data = as.data.frame(cc))
  fy <- stats::lm(if (direct) Y ~ M + X else Y ~ M, data = as.data.frame(cc))
  c(colMeans(dat, na.rm = TRUE), unname(coef(fm)["X"]), unname(coef(fy)["M"]),
    if (direct) unname(coef(fy)["X"]),
    log(c(stats::var(cc[, 1]), mean(resid(fm)^2), mean(resid(fy)^2))))
}

reference <- function(dat, direct) {
  groups <- make_groups(dat)
  n <- sum(rowSums(!is.na(dat)) > 0)
  q0 <- initial(dat, direct)
  # Deterministic dispersed starts, independent of lavaan estimates.
  sdv <- apply(dat, 2, stats::sd, na.rm = TRUE)
  qscale <- c(sdv, sdv[2] / sdv[1], sdv[3] / sdv[2],
              if (direct) sdv[3] / sdv[1], rep(1, 3))
  starts <- list(rep(0, length(q0)), 0.12 * sin(seq_along(q0)),
                 -0.15 * cos(seq_along(q0)))
  # Optimize dimensionless coordinates, including for the rescaling probe.
  objective <- function(u) nll(q0 + qscale * u, groups, direct) / n
  runs <- lapply(starts, function(u) {
    b <- stats::optim(u, objective, method = "BFGS",
                      control = list(reltol = 1e-13, maxit = 1500))
    p <- stats::nlminb(b$par, objective,
                       control = list(rel.tol = 1e-13, x.tol = 1e-12, iter.max = 1500))
    list(q = q0 + qscale * p$par, value = p$objective,
         bfgs = b$convergence, polish = p$convergence)
  })
  best <- runs[[which.min(vapply(runs, `[[`, numeric(1), "value"))]]
  q <- best$q
  H <- numDeriv::hessian(function(p) nll(p, groups, direct), q)
  J <- numDeriv::jacobian(function(p) structural(p, direct), q)
  V <- J %*% solve(H) %*% t(J)
  list(q = q, estimates = structural(q, direct), se = sqrt(diag(V)), H = H,
       gradient = max(abs(numDeriv::grad(function(p) nll(p, groups, direct) / n, q))),
       start_spread = diff(range(vapply(runs, `[[`, numeric(1), "value"))),
       bfgs = best$bfgs, polish = best$polish, n = n, groups = groups)
}

lavaan_fit <- function(dat, direct, fixed = FALSE) {
  syntax <- paste("M ~ a*X", if (direct) "Y ~ b*M + cp*X" else "Y ~ b*M + 0*X",
                  "M ~ im*1", "Y ~ iy*1", "M ~~ vm*M", "Y ~~ vy*Y", sep = "\n")
  # Explicit free X moments would make X modeled, defeating the fixed-X probe.
  if (!fixed) syntax <- paste(syntax, "X ~ ix*1", "X ~~ vx*X", sep = "\n")
  lavaan::sem(syntax, data = as.data.frame(dat), missing = "fiml",
              fixed.x = fixed, conditional.x = FALSE, meanstructure = TRUE,
              likelihood = "normal", information = "observed",
              observed.information = "hessian", se = "standard", test = "none",
              control = list(rel.tol = 1e-10, iter.max = 10000, eval.max = 20000))
}

generate <- function(seed, mask, direct) {
  set.seed(seed)
  X <- 0.8 + stats::rnorm(300, sd = 1.1)
  M <- -0.4 + 0.5 * X + stats::rnorm(300, sd = 0.8)
  Y <- 0.7 + 0.6 * M + (if (direct) 0.25 else 0) * X + stats::rnorm(300, sd = 0.9)
  dat <- cbind(X, M, Y)
  if (mask == "monotone_mcar") {
    u <- stats::runif(nrow(dat)); dat[u < .18, 2:3] <- NA
    dat[u >= .18 & u < .38, 3] <- NA
  }
  if (mask == "nonmonotone_mcar") {
    dat[stats::runif(300) < .22, 2] <- NA
    dat[stats::runif(300) < .28, 3] <- NA
  }
  if (mask == "mar_observed_x") {
    dat[stats::runif(300) < stats::plogis(-1.3 + .7 * X), 2] <- NA
    dat[stats::runif(300) < stats::plogis(-1.1 - .6 * X), 3] <- NA
  }
  if (mask == "missing_x_mcar") {
    for (j in 1:3) dat[stats::runif(300) < .22, j] <- NA
  }
  dat
}

warnings_seen <- character()
capture_warnings <- function(expr) withCallingHandlers(expr, warning = function(w) {
  warnings_seen <<- c(warnings_seen, conditionMessage(w)); invokeRestart("muffleWarning")
})
rows <- list(); saved <- list(); coordinates <- list()
for (direct in c(TRUE, FALSE)) for (seed in c(271L, 613L, 997L)) {
  for (mask in c("complete", "monotone_mcar", "nonmonotone_mcar",
                 "mar_observed_x", "missing_x_mcar")) {
    id <- paste(if (direct) "unrestricted" else "cp_zero", seed, mask, sep = "/")
    dat <- generate(seed, mask, direct)
    r <- reference(dat, direct)
    fit <- capture_warnings(lavaan_fit(dat, direct))
    pt <- lavaan::parameterEstimates(fit)
    wanted <- names(r$estimates)
    tab <- pt[pt$label %in% wanted, , drop = FALSE]
    stopifnot(nrow(tab) == length(wanted), !anyDuplicated(tab$label),
              setequal(tab$label, wanted))
    tab <- tab[match(wanted, tab$label), ]
    # Translate lavaan's structural coordinates back to independent q coordinates.
    s <- setNames(tab$est, tab$label)
    cp <- if (direct) s["cp"] else 0
    mx <- s["ix"]; mm <- s["im"] + s["a"] * mx
    q_lav <- unname(c(mx, mm, s["iy"] + s["b"] * mm + cp * mx,
                     s["a"], s["b"], if (direct) cp, log(s[c("vx", "vm", "vy")])))
    ll_gap <- abs(-nll(r$q, r$groups, direct) - as.numeric(lavaan::logLik(fit))) / r$n
    own_at_lav <- abs(-nll(q_lav, r$groups, direct) - as.numeric(lavaan::logLik(fit))) / r$n
    # Marginal SDs define the fixed, original-data standardization for estimates.
    sdv <- apply(dat, 2, stats::sd, na.rm = TRUE)
    scales <- c(sdv, sdv[2] / sdv[1], sdv[3] / sdv[2],
                if (direct) sdv[3] / sdv[1], sdv^2)
    param_gap <- max(abs(r$estimates - tab$est) / scales)
    se_gap <- max(abs(r$se - tab$se) / tab$se)
    point_gap <- max(vapply(list(r$q, r$q + .07 * sin(seq_along(r$q)),
                                 r$q - .09 * cos(seq_along(r$q))), function(q) {
      abs(nll(q, r$groups, direct) - nll_cases(q, dat, direct)) / r$n
    }, numeric(1)))
    conditional_gap <- if (mask == "complete") {
      abs(nll(r$q, r$groups, direct) - nll_conditional(r$q, dat, direct)) / r$n
    } else 0
    # A second finite-difference resolution must support the SE calculation.
    H2 <- numDeriv::hessian(function(q) nll(q, r$groups, direct), r$q,
                           method.args = list(r = 6))
    J <- numDeriv::jacobian(function(q) structural(q, direct), r$q)
    se2 <- sqrt(diag(J %*% solve(H2) %*% t(J)))
    hessian_stability <- max(abs(se2 / r$se - 1))
    retained_lavaan <- lavaan::lavInspect(fit, "nobs")
    pass <- retained_lavaan == r$n &&
      all(c(ll_gap, own_at_lav, point_gap, conditional_gap) <= threshold["ll_per_row"]) &&
      param_gap <= threshold["parameter"] && se_gap <= threshold["se_relative"] &&
      r$gradient <= threshold["gradient"] && min(eigen(r$H, symmetric = TRUE)$values) > 0 &&
      hessian_stability <= 1e-4 && lavaan::lavInspect(fit, "converged") &&
      r$bfgs == 0 && r$polish == 0 && r$start_spread <= 1e-8
    coordinates[[id]] <- data.frame(cell = id, parameter = wanted,
      independent_estimate = unname(r$estimates), lavaan_estimate = tab$est,
      independent_se = r$se, lavaan_se = tab$se)
    rows[[id]] <- data.frame(cell = id, retained = r$n, retained_lavaan = retained_lavaan,
      empty = nrow(dat) - r$n,
      patterns = length(r$groups), ll_per_row = ll_gap, own_at_lavaan = own_at_lav,
      parameter_standardized = param_gap, parameter_raw = max(abs(r$estimates - tab$est)),
      se_relative = se_gap, gradient = r$gradient, formulations = point_gap,
      complete_factorization = conditional_gap, hessian_stability = hessian_stability,
      starts_spread = r$start_spread, bfgs = r$bfgs, polish = r$polish, pass = pass)
    saved[[id]] <- list(dat = dat, reference = r, fit = fit, direct = direct)
    cat(id, "PASS=", pass, "ll=", format(ll_gap, digits = 3),
        "par=", format(param_gap, digits = 3), "se=", format(se_gap, digits = 3), "\n")
    utils::write.csv(do.call(rbind, rows), file.path(out_dir, "results.csv"), row.names = FALSE)
  }
}

edges <- list()
edge <- function(name, value, evidence) {
  edges[[name]] <<- data.frame(check = name, pass = isTRUE(value), evidence = evidence)
}
v <- saved[["unrestricted/271/mar_observed_x"]]
d <- v$dat; r <- v$reference; direct <- TRUE
reordered <- d[rev(seq_len(nrow(d))), ]
edge("row_order", abs(nll(r$q, make_groups(reordered)) - nll(r$q, r$groups)) < 1e-8,
     "Reverse row order; independent likelihood unchanged")
aug <- rbind(d, matrix(NA_real_, 5, 3, dimnames = list(NULL, vars)))
fit_aug <- capture_warnings(lavaan_fit(aug, TRUE))
edge("empty_rows", abs(as.numeric(lavaan::logLik(fit_aug)) - as.numeric(lavaan::logLik(v$fit))) < 1e-6 &&
       sum(rowSums(!is.na(aug)) > 0) == r$n &&
       lavaan::lavInspect(fit_aug, "nobs") == r$n &&
       abs(nll(r$q, make_groups(aug)) - nll(r$q, r$groups)) < 1e-8,
     paste("Five all-missing rows add zero information; lavaan nobs", lavaan::lavInspect(fit_aug, "nobs")))

mult <- c(10, .1, 3); shift <- c(2, -1, 4)
ds <- sweep(sweep(d, 2, mult, `*`), 2, shift, `+`)
rs <- reference(ds, TRUE)
st <- structural(r$q)
transformed <- unname(c(moments(r$q)$mu * mult + shift,
                       st["a"] * mult[2] / mult[1], st["b"] * mult[3] / mult[2],
                       st["cp"] * mult[3] / mult[1],
                       log(st[c("vx", "vm", "vy")] * mult^2)))
jacobian_offset <- sum(colSums(!is.na(d)) * log(abs(mult)))
edge("shift_rescale_identity", abs(nll(transformed, make_groups(ds)) -
       nll(r$q, r$groups) - jacobian_offset) / r$n < 1e-8 &&
       abs(nll(rs$q, make_groups(ds)) - nll(transformed, make_groups(ds))) / r$n < 1e-8,
     "Known data Jacobian offset; independently refitted transformed data")

# Matched fixed-X fits are compared on structural parameters and SEs only.
fixed <- capture_warnings(lavaan_fit(d, TRUE, fixed = TRUE))
free_pt <- lavaan::parameterEstimates(v$fit)
fixed_pt <- lavaan::parameterEstimates(fixed)
lab <- c("im", "iy", "a", "b", "cp", "vm", "vy")
ff <- free_pt[match(lab, free_pt$label), ]
fx <- fixed_pt[match(lab, fixed_pt$label), ]
edge("fixed_x_complete", max(abs(ff$est - fx$est)) < 1e-5 &&
       max(abs(ff$se - fx$se) / ff$se) < 1e-3,
     "Complete X: random/fixed-X structural estimates and observed SEs agree")
dx <- saved[["unrestricted/271/missing_x_mcar"]]$dat
fx_missing <- capture_warnings(lavaan_fit(dx, TRUE, fixed = TRUE))
expected_n <- sum(!is.na(dx[, 1]) & rowSums(!is.na(dx)) > 0)
edge("fixed_x_missing_rows", lavaan::lavInspect(fx_missing, "nobs") == expected_n,
     paste("fixed-X retained", lavaan::lavInspect(fx_missing, "nobs"), "expected", expected_n))

all_missing <- d; all_missing[, 2] <- NA
bad_all <- tryCatch(capture_warnings(lavaan_fit(all_missing, TRUE)), error = identity)
edge("all_missing_variable", inherits(bad_all, "error"),
     if (inherits(bad_all, "error")) conditionMessage(bad_all) else "Unexpected fit")
no_overlap <- generate(271, "complete", TRUE)
no_overlap[seq_len(150), 3] <- NA
no_overlap[151:300, 1:2] <- NA
q <- saved[["unrestricted/271/complete"]]$reference$q
# One can change b/cp while keeping marginal Y variance/mean fixed.
qbad <- q; qbad[5:6] <- c(.2, -.1)
target_vy <- moments(q)$sigma[3, 3] -
  (qbad[6] + qbad[4] * qbad[5])^2 * exp(tail(qbad, 3)[1]) -
  qbad[5]^2 * exp(tail(qbad, 3)[2])
stopifnot(target_vy > 0)
qbad[length(qbad)] <- log(target_vy)
edge("no_overlap_unidentified", abs(nll(q, make_groups(no_overlap)) -
       nll(qbad, make_groups(no_overlap))) < 1e-7 && max(abs(q - qbad)) > .1,
     "Distinct structural paths yield identical observed-data likelihood")

# Positive controls: apply the same likelihood/SE agreement criteria to defects.
cc <- d[stats::complete.cases(d), , drop = FALSE]
listwise <- reference(cc, TRUE)
listwise_gap <- (nll(listwise$q, r$groups) - nll(r$q, r$groups)) / r$n
edge("mutant_listwise_caught", listwise_gap > threshold["ll_per_row"],
     paste("Listwise-fitted candidate fails common full-data likelihood by", signif(listwise_gap, 6), "per row"))
zero_mean <- r$q; zero_mean[1:3] <- 0
edge("mutant_omitted_means_caught", abs(nll(zero_mean, r$groups) -
       nll(r$q, r$groups)) / r$n > threshold["ll_per_row"],
     "Omitted means violate total-likelihood criterion")
J <- numDeriv::jacobian(function(q) structural(q), r$q)
wrong_se <- sqrt(diag(J %*% solve(r$H / r$n) %*% t(J)))
wrong_se_gap <- max(abs(wrong_se / free_pt$se[match(names(r$estimates), free_pt$label)] - 1))
edge("mutant_average_hessian_caught", wrong_se_gap > threshold["se_relative"],
     paste("Inverse average Hessian violates lavaan SE agreement; relative error", signif(wrong_se_gap, 6)))
utils::write.csv(do.call(rbind, coordinates), file.path(out_dir, "coordinates.csv"), row.names = FALSE)
utils::write.csv(do.call(rbind, edges), file.path(out_dir, "edges.csv"), row.names = FALSE)
writeLines(unique(warnings_seen), file.path(out_dir, "warnings.txt"))
capture.output(sessionInfo(), file = file.path(out_dir, "session.txt"))
summary <- list(primary_pass = sum(vapply(rows, function(x) x$pass, logical(1))),
                primary_total = length(rows), edge_pass = sum(vapply(edges, function(x) x$pass, logical(1))),
                edge_total = length(edges), seconds = as.numeric(difftime(Sys.time(), started, units = "secs")))
capture.output(print(summary), file = file.path(out_dir, "summary.txt"))
# Normalize display whitespace in exported diagnostic text, preserving values.
for (name in c("edges.csv", "warnings.txt", "session.txt", "summary.txt")) {
  path <- file.path(out_dir, name)
  lines <- sub("[[:blank:]]+$", "", readLines(path))
  while (length(lines) && !nzchar(tail(lines, 1))) lines <- head(lines, -1)
  writeLines(lines, path)
}
print(summary)
if (summary$primary_pass != summary$primary_total || summary$edge_pass != summary$edge_total) {
  quit(status = 1)
}
