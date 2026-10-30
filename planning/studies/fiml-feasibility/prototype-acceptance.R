# Run from the worktree root. Local acceptance only, never a production fit.
base_dir <- "planning/studies/fiml-feasibility"
out_dir <- file.path(base_dir, "prototype-results")
dir.create(out_dir, showWarnings = FALSE)
pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
source(file.path(base_dir, "prototype.R"))
source(file.path(base_dir, "prototype-fixtures.R"))
started <- Sys.time()

# Reproduce the complete original reference harness into its own output directory.
oracle <- new.env(parent = globalenv())
oracle$out_dir <- file.path(out_dir, "reference")
dir.create(oracle$out_dir, showWarnings = FALSE)
for (expr in parse(file.path(base_dir, "study.R"))) {
  is_out_dir <- is.call(expr) && identical(expr[[1]], as.name("<-")) &&
    identical(expr[[2]], as.name("out_dir"))
  if (!is_out_dir) eval(expr, oracle)
}
stopifnot(oracle$summary$primary_pass == 30L, oracle$summary$edge_pass == 10L)

# The independent oracle keeps its marginal-mean/log-variance likelihood and
# its own optimizer; only this research initializer avoids complete-case lm.
oracle$initial <- function(dat, direct) {
  c(colMeans(dat, na.rm = TRUE), 0, 0, if (direct) 0,
    log(apply(dat, 2, stats::var, na.rm = TRUE)))
}
environment(oracle$initial) <- oracle
reference_fit <- function(dat, direct) {
  center <- colMeans(dat, na.rm = TRUE)
  scale <- apply(dat, 2, stats::sd, na.rm = TRUE)
  z <- sweep(sweep(dat, 2, center), 2, scale, `/`)
  r <- oracle$reference(z, direct, derivative_polish = TRUE)
  raw_parameters <- function(q) {
    qr <- q
    qr[1:3] <- center + scale * q[1:3]
    qr[4] <- q[4] * scale[2] / scale[1]
    qr[5] <- q[5] * scale[3] / scale[2]
    if (direct) qr[6] <- q[6] * scale[3] / scale[1]
    qr[(length(q) - 2):length(q)] <- tail(q, 3) + 2 * log(scale)
    oracle$structural(qr, direct)
  }
  J <- numDeriv::jacobian(raw_parameters, r$q)
  V <- J %*% solve(r$H) %*% t(J)
  estimate <- raw_parameters(r$q)
  dimnames(V) <- list(names(estimate), names(estimate))
  list(r = r, z = z, estimate = estimate, covariance = V,
       nll = oracle$nll(r$q, r$groups, direct) + sum(colSums(!is.na(dat)) * log(scale)))
}
# Fit lavaan in data-derived affine coordinates, then independently transport
# its full covariance by a numerical Jacobian; never use prototype transport.
lavaan_reference <- function(dat, direct) {
  center <- colMeans(dat, na.rm = TRUE)
  scale <- apply(dat, 2, stats::sd, na.rm = TRUE)
  z <- sweep(sweep(dat, 2, center), 2, scale, `/`)
  fit <- oracle$lavaan_fit(z, direct)
  Vz <- lavaan::vcov(fit)
  labels <- rownames(Vz)
  q <- setNames(as.numeric(lavaan::coef(fit)), labels)
  raw <- function(t) {
    names(t) <- labels
    r <- t
    r["a"] <- scale[2] / scale[1] * t["a"]
    r["b"] <- scale[3] / scale[2] * t["b"]
    if (direct) r["cp"] <- scale[3] / scale[1] * t["cp"]
    r[c("vx", "vm", "vy")] <- scale^2 * t[c("vx", "vm", "vy")]
    r["ix"] <- center[1] + scale[1] * t["ix"]
    r["im"] <- center[2] + scale[2] * t["im"] - r["a"] * center[1]
    r["iy"] <- center[3] + scale[3] * t["iy"] - r["b"] * center[2] -
      (if (direct) r["cp"] * center[1] else 0)
    r
  }
  J <- numDeriv::jacobian(raw, q)
  V <- J %*% Vz %*% t(J)
  dimnames(V) <- list(labels, labels)
  tab <- lavaan::parameterEstimates(fit)
  tab$est[match(labels, tab$label)] <- raw(q)
  tab$se[match(labels, tab$label)] <- sqrt(diag(V))
  list(fit = fit, table = tab, covariance = V,
    loglik = as.numeric(lavaan::logLik(fit)) - sum(colSums(!is.na(dat)) * log(scale)))
}
theta_q <- function(theta, direct) {
  cp <- if (direct) theta["cp"] else 0
  mx <- theta["ix"]; mm <- theta["im"] + theta["a"] * mx
  unname(c(mx, mm, theta["iy"] + theta["b"] * mm + cp * mx,
           theta["a"], theta["b"], if (direct) cp, log(theta[c("vx", "vm", "vy")])))
}
relative <- function(x, ref) max(abs(x - ref)) / max(1, max(abs(ref)))
cov_error <- function(x, ref, se) max(abs(x - ref) / outer(se, se))
record_matrix <- function(cell, point, type, matrix) {
  data.frame(cell = cell, point = point, type = type,
             row = rep(rownames(matrix), times = ncol(matrix)),
             col = rep(colnames(matrix), each = nrow(matrix)), value = as.vector(matrix))
}

cases <- list()
for (direct in c(TRUE, FALSE)) for (seed in c(271L, 613L, 997L)) {
  for (mask in c("complete", "monotone_mcar", "nonmonotone_mcar",
                 "mar_observed_x", "missing_x_mcar")) {
    id <- paste(if (direct) "unrestricted" else "cp_zero", seed, mask, sep = "/")
    cases[[id]] <- list(data = oracle$generate(seed, mask, direct), direct = direct)
  }
}
patterns <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE),
                                 Y = c(FALSE, TRUE)))[-1, ]
for (direct in c(TRUE, FALSE)) {
  prefix <- if (direct) "unrestricted" else "cp_zero"
  dat <- oracle$generate(613L, "complete", direct)
  pair <- rbind(c(TRUE, FALSE, TRUE), c(TRUE, TRUE, FALSE), c(FALSE, TRUE, TRUE))
  dat[!pair[rep(1:3, length.out = 300), ]] <- NA
  cases[[paste0(prefix, "/new/no_complete")]] <- list(data = dat, direct = direct)
  dat <- oracle$generate(997L, "complete", direct)
  for (i in 1:6) dat[i, !patterns[i, ]] <- NA
  cases[[paste0(prefix, "/new/singletons")]] <- list(data = dat, direct = direct)
  dat <- oracle$generate(997L, "complete", direct)
  dat[!patterns[rep(1:7, length.out = 300), ]] <- NA
  cases[[paste0(prefix, "/new/all_patterns")]] <- list(data = dat, direct = direct)
  dat <- oracle$generate(271L, "mar_observed_x", direct)
  cases[[paste0(prefix, "/new/shifted")]] <-
    list(data = sweep(dat, 2, c(100, -200, 300), `+`), direct = direct)
  cases[[paste0(prefix, "/new/rescaled")]] <-
    list(data = sweep(dat, 2, c(100, .01, 3), `*`), direct = direct)
  dat <- prototype_near_singular(oracle$generate, direct)
  cases[[paste0(prefix, "/new/near_singular")]] <- list(data = dat, direct = direct)
}
stopifnot(length(cases) == 42L)
rows <- list(); attempts <- list(); matrices <- list(); derivatives <- list()
coordinates <- list(); ledgers <- list(); fits <- list(); warnings_seen <- list()
gradients <- list(); independent_gates <- list(); identities <- list(); conditioning <- list(); independent_attempts <- list()
capture <- function(expr, id) withCallingHandlers(expr, warning = function(w) {
  warnings_seen[[length(warnings_seen) + 1L]] <<- data.frame(cell = id, message = conditionMessage(w))
  invokeRestart("muffleWarning")
})
write_records <- function() {
  for (name in c("rows", "attempts", "matrices", "derivatives", "coordinates", "ledgers", "warnings_seen",
                 "gradients", "independent_gates", "identities", "conditioning", "independent_attempts")) {
    object <- get(name)
    if (length(object)) utils::write.csv(do.call(rbind, object),
      file.path(out_dir, paste0(name, ".csv")), row.names = FALSE)
  }
}
for (id in names(cases)) {
  cell <- cases[[id]]; direct <- cell$direct; dat <- cell$data
  cat("PROTOTYPE", id, "\n")
  ledgers[[id]] <- data.frame(cell = id, row_id = seq_len(nrow(dat)),
    pattern = apply(!is.na(dat), 1, paste0, collapse = ""),
    retained = rowSums(!is.na(dat)) > 0L)
  result <- tryCatch({
    p <- prototype_fit(dat, direct)
    fits[[id]] <- p
    attempts[[id]] <- cbind(cell = id, p$attempts)
    for (type in c("observed_hessian", "moment_geometry")) {
      H <- if (type == "observed_hessian") p$H else prototype_geometry(p$theta, p$prepared)
      spectrum <- eigen(H / sqrt(outer(diag(H), diag(H))), symmetric = TRUE)$values
      conditioning[[length(conditioning) + 1L]] <- data.frame(cell = id, type = type,
        minimum_scaled_eigenvalue = min(spectrum), scaled_condition = max(spectrum) / min(spectrum))
    }
    own <- reference_fit(dat, direct)
    independent_attempts[[id]] <- cbind(cell = id, own$r$attempts)
    lavaan_ref <- capture(lavaan_reference(dat, direct), id)
    lv <- lavaan_ref$fit
    tab <- lavaan_ref$table
    labels <- names(p$estimate)
    tab <- tab[tab$label %in% labels, ]
    stopifnot(nrow(tab) == length(labels), !anyDuplicated(tab$label),
              setequal(tab$label, labels), setequal(names(own$estimate), labels))
    tab <- tab[match(labels, tab$label), ]
    Vlav <- lavaan_ref$covariance
    stopifnot(setequal(rownames(Vlav), labels), !anyDuplicated(rownames(Vlav)))
    Vlav <- Vlav[labels, labels]
    Vref <- own$covariance[labels, labels]
    eref <- own$estimate[labels]; sref <- sqrt(diag(Vref))
    stopifnot(all(is.finite(sref)), all(sref > 0))
    par_error <- max(abs(p$estimate - eref) / p$prepared$units,
                     abs(p$estimate - tab$est) / p$prepared$units)
    se_error <- max(abs(p$se / sref - 1), abs(p$se / tab$se - 1))
    cv_error <- max(cov_error(p$covariance, Vref, sref), cov_error(p$covariance, Vlav, sref))
    ll_error <- max(abs(p$nll - own$nll),
                    abs(p$nll + lavaan_ref$loglik),
                    abs(oracle$nll(theta_q(setNames(tab$est, labels), direct),
                                   oracle$make_groups(dat), direct) + lavaan_ref$loglik)) / p$prepared$n
    retained <- which(rowSums(!is.na(dat)) > 0L)
    row_ok <- identical(p$prepared$rows$retained, retained) &&
      identical(p$prepared$rows$empty, which(rowSums(!is.na(dat)) == 0L)) &&
      lavaan::lavInspect(lv, "nobs") == length(retained)
    coordinates[[id]] <- data.frame(cell = id, parameter = labels,
      prototype = p$estimate, independent = eref, lavaan = tab$est,
      prototype_se = p$se, independent_se = sref, lavaan_se = tab$se)
    for (type in c("prototype", "independent", "lavaan")) {
      matrix <- switch(type, prototype = p$covariance, independent = Vref, lavaan = Vlav)
      matrices[[length(matrices) + 1L]] <- record_matrix(id, "fit", type, matrix)
    }
    theta <- p$theta; prep <- p$prepared
    invT <- solve(prep$transport)
    groups_ref <- oracle$make_groups(prep$standardized)
    independent_nll <- function(t) oracle$nll(theta_q(setNames(t, labels), direct), groups_ref, direct)
    points <- list(fit = theta)
    for (k in 1:2) {
      delta <- (if (k == 1) .07 else -.09) * sin(seq_along(theta) + k)
      v <- match(c("vx", "vm", "vy"), labels)
      delta[v] <- delta[v] * theta[v]
      points[[paste0("perturbed", k)]] <- theta + delta
    }
    checks <- list()
    for (point in names(points)) {
      t <- points[[point]]
      gn <- numDeriv::grad(function(delta) independent_nll(t + delta), rep(0, length(t)))
      ga <- prototype_eval(t, prep)$gradient
      gradients[[length(gradients) + 1L]] <- data.frame(cell = id, point = point,
        parameter = labels, prototype = ga, independent = gn)
      difference <- prototype_difference(t, theta, prep)
      independent_difference <- independent_nll(t) - independent_nll(theta)
      identities[[length(identities) + 1L]] <- data.frame(cell = id, point = point,
        error_per_row = abs(difference - independent_difference) / prep$n,
        pass = abs(difference - independent_difference) / prep$n <= 1e-8)
      # Relative variance perturbations stay inside the positive domain.
      step_units <- rep(1, length(t))
      step_units[match(c("vx", "vm", "vy"), labels)] <- t[c("vx", "vm", "vy")]
      independent_scaled <- function(delta) independent_nll(t + step_units * delta)
      Hn <- numDeriv::hessian(independent_scaled, rep(0, length(t)),
                              method.args = list(eps = .01, r = 4)) / outer(step_units, step_units)
      Hn2 <- numDeriv::hessian(independent_scaled, rep(0, length(t)),
                               method.args = list(eps = .01, r = 6)) / outer(step_units, step_units)
      Ha <- prototype_hessian(t, prep)
      Ha2 <- prototype_hessian(t, prep, .5)
      g_raw <- as.vector(t(invT) %*% ga) / prep$n
      gn_raw <- as.vector(t(invT) %*% gn) / prep$n
      scaled_H <- function(H) (t(invT) %*% H %*% invT) * outer(prep$units, prep$units)
      ge <- relative(g_raw * prep$units, gn_raw * prep$units)
      he <- max(relative(scaled_H(Ha), scaled_H(Hn)),
                relative(scaled_H(Ha2), scaled_H(Hn2)), relative(scaled_H(Ha), scaled_H(Ha2)))
      formulations <- abs(oracle$nll(theta_q(setNames(t, labels), direct), groups_ref, direct) -
        oracle$nll_cases(theta_q(setNames(t, labels), direct), prep$standardized, direct)) / prep$n
      checks[[point]] <- data.frame(cell = id, point = point,
        gradient_error = ge, hessian_error = he, formulations = formulations,
        pass = ge <= 1e-6 && he <= 1e-4 && formulations <= 1e-8)
      for (type in c("analytic_hessian", "independent_hessian")) {
        matrix <- if (type == "analytic_hessian") Ha else Hn
        dimnames(matrix) <- list(labels, labels)
        matrices[[length(matrices) + 1L]] <- record_matrix(id, point, type, matrix)
      }
      derivatives[[length(derivatives) + 1L]] <- checks[[point]]
    }
    H2 <- prototype_hessian(theta, prep, .5)
    V2 <- prep$transport %*% solve(H2) %*% t(prep$transport)
    stability <- max(abs(sqrt(diag(V2)) / p$se - 1))
    stationarity <- max(abs(prep$units * as.vector(t(invT) %*% prototype_eval(theta, prep)$gradient) / prep$n))
    independent_ok <- own$r$bfgs == 0L && own$r$polish == 0L &&
      own$r$gradient <= 1e-5 && own$r$start_spread <= 1e-8 &&
      min(eigen(own$r$H, symmetric = TRUE)$values) > 0
    independent_gates[[id]] <- data.frame(cell = id, bfgs = own$r$bfgs,
      polish = own$r$polish, gradient = own$r$gradient, spread = own$r$start_spread,
      minimum_eigenvalue = min(eigen(own$r$H, symmetric = TRUE)$values), pass = independent_ok)
    pass <- par_error <= 1e-5 && se_error <= 1e-3 && cv_error <= 1e-3 &&
      ll_error <= 1e-8 && row_ok && stability <= 1e-4 && stationarity <= 1e-5 &&
      independent_ok && lavaan::lavInspect(lv, "converged") &&
      all(vapply(checks, function(x) x$pass, logical(1))) &&
      all(vapply(identities[vapply(identities, function(x) x$cell == id, logical(1))],
                 function(x) x$pass, logical(1)))
    data.frame(cell = id, pass = pass, likelihood_per_row = ll_error,
      parameter = par_error, se = se_error, covariance = cv_error,
      se_stability = stability, stationarity = stationarity, rows = row_ok,
      independent_ok = independent_ok,
      reason = if (!independent_ok) "independent optimizer/information gate" else "")
  }, error = function(e) {
    if (!is.null(e$attempts)) attempts[[id]] <<- cbind(cell = id, e$attempts)
    data.frame(cell = id, pass = FALSE, likelihood_per_row = NA_real_,
      parameter = NA_real_, se = NA_real_, covariance = NA_real_,
      se_stability = NA_real_, stationarity = NA_real_, rows = FALSE,
      independent_ok = FALSE, reason = conditionMessage(e))
  })
  rows[[id]] <- result
  cat("ACCEPT", id, result$pass, result$reason, "\n")
  write_records()
}

# Additional edge/diagnostic/mutant evidence is evaluated even after cell misses.
edges <- list()
edge <- function(name, ok, evidence) {
  edges[[name]] <<- data.frame(check = name, pass = isTRUE(ok), evidence = evidence)
}
diagnostic <- function(expr) inherits(tryCatch(expr, error = identity), "fiml_prototype_diagnostic")
id <- "unrestricted/271/mar_observed_x"; p <- fits[[id]]; dat <- cases[[id]]$data
if (!is.null(p)) {
  reverse <- prototype_fit(dat[300:1, ], row_id = 300:1)
  edge("row_order", abs(p$nll - reverse$nll) / p$prepared$n < 1e-8 &&
    cov_error(reverse$covariance, p$covariance, p$se) < 1e-3 &&
    identical(reverse$prepared$rows$original, 300:1), "Reordered fits and row IDs agree")
  empty <- prototype_fit(rbind(dat, matrix(NA_real_, 5, 3)))
  edge("empty_rows", abs(empty$nll - p$nll) / p$prepared$n < 1e-8 &&
    identical(empty$prepared$rows$empty, 301:305), "Empty rows excluded by ID with zero likelihood")
  for (kind in c("shifted", "rescaled")) {
    target <- fits[[paste0("unrestricted/new/", kind)]]
    if (is.null(target)) {
      edge(paste0("affine_", kind), FALSE, "Required transformed fit failed")
      next
    }
    s <- if (kind == "rescaled") c(100, .01, 3) else c(1, 1, 1)
    c0 <- if (kind == "shifted") c(100, -200, 300) else c(0, 0, 0)
    transform <- function(t) {
      q <- theta_q(setNames(t, names(p$estimate)), TRUE)
      q[1:3] <- q[1:3] * s + c0
      q[4:6] <- q[4:6] * c(s[2] / s[1], s[3] / s[2], s[3] / s[1])
      q[(length(q) - 2):length(q)] <- tail(q, 3) + 2 * log(s)
      oracle$structural(q, TRUE)[names(p$estimate)]
    }
    J <- numDeriv::jacobian(transform, p$estimate)
    expected_cov <- J %*% p$covariance %*% t(J)
    offset <- sum(colSums(!is.na(dat)) * log(s))
    edge(paste0("affine_", kind), abs(target$nll - p$nll - offset) / p$prepared$n <= 1e-8 &&
      max(abs(target$estimate - transform(p$estimate)) / target$prepared$units) <= 1e-5 &&
      cov_error(target$covariance, expected_cov, sqrt(diag(expected_cov))) <= 1e-3,
      "Known Jacobian offset plus full estimate/covariance transport")
  }
  cc <- prototype_fit(dat[stats::complete.cases(dat), ])
  raw_to_std <- function(t) as.vector(solve(p$prepared$transport, t - p$prepared$offset))
  cc_on_all <- prototype_eval(raw_to_std(cc$estimate), p$prepared)$value + p$prepared$jacobian
  edge("mutant_listwise", (cc_on_all - p$nll) / p$prepared$n > 1e-8,
       "Listwise-fitted candidate fails common observed-data likelihood")
  wrong <- p$estimate; wrong[c("ix", "im", "iy")] <- 0
  omitted <- prototype_eval(raw_to_std(wrong), p$prepared)$value + p$prepared$jacobian
  edge("mutant_means", abs(omitted - p$nll) / p$prepared$n > 1e-8,
       "Zero structural intercepts fail the mean-structure likelihood")
  edge("mutant_hessian_N", cov_error(p$covariance * p$prepared$n, p$covariance, p$se) > 1e-3,
       "Inverse average Hessian fails full covariance criterion")
  bad <- dat; bad[, 2] <- NA
  edge("all_missing_variable", diagnostic(prototype_fit(bad)), "Typed study diagnostic")
  edge("fixed_X_rejected", diagnostic(prototype_fit(dat, fixed_x = TRUE)), "Reference-only setting rejected")
  edge("unsupported_rejected", diagnostic(prototype_fit(dat, weights = rep(1, 300))) &&
    diagnostic(prototype_fit(dat, direct = NA)), "Weights and invalid model selector rejected")
  bad_theta <- p$theta; bad_theta["vy"] <- 1e-14
  edge("invalid_PD", is.null(prototype_eval(bad_theta, p$prepared)), "Existing correlation-scale PD floor rejects unusable covariance")
  no_overlap <- oracle$generate(271L, "complete", TRUE)
  no_overlap[1:150, 3] <- NA; no_overlap[151:300, 1:2] <- NA
  no_overlap_error <- tryCatch(prototype_fit(no_overlap), error = identity)
  no_overlap_attempts <- no_overlap_error$attempts
  ledger_ok <- is.data.frame(no_overlap_attempts) && nrow(no_overlap_attempts) == 6L &&
    !anyDuplicated(paste(no_overlap_attempts$solver, no_overlap_attempts$start)) &&
    setequal(paste(no_overlap_attempts$solver, no_overlap_attempts$start),
             paste(rep(c("slsqp", "nlminb"), each = 3), rep(1:3, 2)))
  if (is.data.frame(no_overlap_attempts)) {
    utils::write.csv(cbind(cell = "nonidentification", no_overlap_attempts),
                    file.path(out_dir, "diagnostic_attempts.csv"), row.names = FALSE)
  }
  edge("nonidentification", inherits(no_overlap_error, "fiml_prototype_diagnostic") && ledger_ok,
       "No finite-SE success; all six solver/start records retained on the diagnostic")
}
cp0 <- fits[["cp_zero/271/nonmonotone_mcar"]]
if (!is.null(cp0)) {
  source_expr <- parse(file.path(base_dir, "numerical-probes.R"))
  helpers <- new.env(parent = oracle)
  for (expr in source_expr) {
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
        as.character(expr[[2]]) %in% c("moment_vector", "moment_nll")) eval(expr, helpers)
  }
  theta <- cp0$theta; pp <- cp0$prepared
  map <- function(t) helpers$moment_vector(theta_q(setNames(t, names(theta)), FALSE), FALSE)
  D <- numDeriv::jacobian(map, theta)
  groups <- oracle$make_groups(pp$standardized)
  Hmom <- numDeriv::hessian(function(m) helpers$moment_nll(m, groups), map(theta))
  naive <- crossprod(D, Hmom %*% D)
  edge("mutant_mapping_curvature", relative(naive, cp0$H) > 1e-4,
       "Dropping moment-mapping curvature violates full observed Hessian criterion")
}
utils::write.csv(do.call(rbind, edges), file.path(out_dir, "edges.csv"), row.names = FALSE)
summary <- list(primary_pass = sum(vapply(rows, function(x) x$pass, logical(1))),
                primary_total = length(rows), edge_pass = sum(vapply(edges, function(x) x$pass, logical(1))),
                edge_total = length(edges), seconds = as.numeric(difftime(Sys.time(), started, units = "secs")))
capture.output(print(summary), file = file.path(out_dir, "summary.txt"))
capture.output(sessionInfo(), file = file.path(out_dir, "session.txt"))
print(summary)
if (summary$primary_pass != 42L || summary$edge_total != 13L || summary$edge_pass != 13L) quit(status = 1L)
