# Extended bounded FIML gate (FI-G1 covariates, FI-G2 parallel mediators with zero, one or two covariates, FI-G3 slices
# S1b and S2 the saturated serial variant and the pure chain, each with no covariates).
# Oracle: matched lavaan raw-data FIML with observed information (estimates, covariance, logLik, defined indirect
# effect and its delta SE). Two seeds each. For a serial structure `nie_estimate` and `nie_se` are the WORST of the
# chain NIE (a*d1*b), the total indirect effect, the total effect and every extracted path (estimate, SE) against
# lavaan's `:=` and labeled values: the chain NIE, its SE and (in the pure chain) the total effect are invariant to a
# consistent d1/b swap, so a check on the effects alone could not catch that defect; the path rows can.
# MUTANT= wrong_unit, no_offset, swap_b, dropped_cov, missing_guard, parcov_drop_path, parcov_orthogonal,
# serial_admitted, serial_router_off, ser_swap_db, ser_drop_cross, ser_total_gradient, ser_drop_shortcut,
# ser_chain_free_shortcut, ser_chain_swap_db, ser_chain_origin, ser_chain_te_gradient alter production functions in
# memory only.
suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/testthat/helper-sem.R")
ns <- asNamespace("medfit")
mutate <- get("sem_mutate")
mutant <- Sys.getenv("MUTANT", "")
swap <- function(name, pattern, replacement) {
  fn <- mutate(get(name, ns), pattern, replacement)
  if (bindingIsLocked(name, ns)) unlockBinding(name, ns)
  assign(name, fn, envir = ns)
}
if (mutant == "wrong_unit") {
  # a covariance of two variables is rescaled by one variable's scale squared
  swap(".sem_fiml_transport", "units[cv$par] <- scale[cv$row] * scale[cv$col]", "units[cv$par] <- scale[cv$row]^2")
} else if (mutant == "no_offset") {
  swap(".sem_fiml_transport", "offset[i$par] <- center[i$var]", "offset[i$par] <- 0")
} else if (mutant == "swap_b") {
  swap(
    ".sem_fiml_extract_parallel", "b_paths = unname(estimates[paste0(\"b\", seq_len(k))])",
    "b_paths = rev(unname(estimates[paste0(\"b\", seq_len(k))]))"
  )
} else if (mutant == "dropped_cov") {
  swap(
    ".sem_fiml_extract_parallel", "V[present, present] <- object@vcov[idx[present], idx[present], drop = FALSE]",
    "V[present, present] <- diag(diag(object@vcov[idx[present], idx[present], drop = FALSE]))"
  )
} else if (mutant == "parcov_drop_path") {
  # the first covariate dropped from the second mediator equation of the parallel-with-covariates tables
  swap(
    ".sem_fiml_tables_med", "return(.sem_fiml_tables_parcov(k, direct, residual_covariance))",
    paste0("return({ t <- .sem_fiml_tables_parcov(k, direct, residual_covariance); ",
           "t$a <- t$a[!(t$a$row == \"M2\" & t$a$col == t$vars[2L]), ]; t })")
  )
} else if (mutant == "parcov_orthogonal") {
  # the exogenous covariance block imposed as orthogonal in the parallel-with-covariates tables
  swap(
    ".sem_fiml_tables_med", "return(.sem_fiml_tables_parcov(k, direct, residual_covariance))",
    paste0("return({ t <- .sem_fiml_tables_parcov(k, direct, residual_covariance); ",
           "t$s <- t$s[!(t$s$row == \"X\" & t$s$col == t$vars[2L]), ]; t })")
  )
} else if (mutant == "serial_admitted") {
  # the serial fit-entry refusal removed: serial syntaxes that are valid but not yet public are fitted (R4 probes)
  swap(".fiml_serial_admitted", "FALSE", "TRUE")
} else if (mutant == "serial_router_off") {
  # serial detection disabled: serial syntax falls to the parallel parser and loses its Q2 and shortcut reasons
  swap(".sem_fiml_ser_detect", "length(outcome) == 1L", "FALSE && length(outcome) == 1L")
} else if (mutant == "ser_swap_db") {
  # the serial extraction reads d1 and b from each other's parameter
  swap(
    ".sem_fiml_extract_serial", "d1 = par(\"d1\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"b\")",
    "d1 = par(\"b\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"d1\")"
  )
} else if (mutant == "ser_drop_cross") {
  # the cross-equation covariance blocks of the extracted path block zeroed (the lm/glm-style covariance)
  swap(
    ".sem_fiml_extract_serial", "V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE]",
    paste0("V[present, present] <- object@vcov[roles[present], roles[present], drop = FALSE] * ",
           "outer(c(a = 1, a2 = 2, d1 = 2, b1 = 3, b = 3, c_prime = 3)[names(roles)[present]], ",
           "c(a = 1, a2 = 2, d1 = 2, b1 = 3, b = 3, c_prime = 3)[names(roles)[present]], \"==\")")
  )
} else if (mutant == "ser_total_gradient") {
  # the total-indirect gradient replaced by the chain gradient
  swap(".effect_gradients", "g_te[names(g_te) != \"c_prime\"]", "g_nie")
} else if (mutant == "ser_drop_shortcut") {
  # the saturated tables lose the M1 -> Y shortcut (a hidden chain under the saturated label)
  swap(".sem_fiml_tables_ser", "path(\"Y\", \"M1\", \"b1\")", "NULL")
} else if (mutant == "ser_chain_free_shortcut") {
  # the pure chain fitted with the shortcut rows free (the kernel gets the saturated tables): LR = 0, df 0 instead of 2
  swap(".sem_fiml_syntax", "identical(spec$variant, \"saturated\")", "TRUE")
} else if (mutant == "ser_chain_swap_db") {
  # the chain extraction reads d1 and b from each other's parameter; only the path rows expose it (nie and te do not)
  swap(
    ".sem_fiml_extract_serial", "d1 = par(\"d1\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"b\")",
    "d1 = par(\"b\"), if (!chain) c(b1 = par(\"b1\")), b = par(\"d1\")"
  )
} else if (mutant == "ser_chain_origin") {
  # the per-effect origin rule withholds the chain effect SEs although no factor is zero: a fitted object then has NA
  # effect SEs, which the nie_se check turns into a failed row (a non-finite value never passes)
  swap(".sem_fiml_origin_effects", "chain_zero <- sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 2L",
       "chain_zero <- sum(c(e[[\"a\"]], e[[\"d1\"]], e[[\"b\"]]) == 0) >= 0L")
} else if (mutant == "ser_chain_te_gradient") {
  # the total-effect gradient loses its c_prime entry
  swap(".effect_gradients", "g_te <- .serial_te_gradient(x)", "g_te <- .serial_te_gradient(x)[c(\"a\", \"d1\", \"b\")]")
} else if (mutant == "missing_guard") {
  swap(".sem_fiml_refuse", "if (.sem_fiml_is(x))", "if (FALSE)")
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

# lavaan names an exogenous covariance in its own order: match by the unordered pair
key <- function(nm) {
  vapply(strsplit(nm, "~~", fixed = TRUE), function(p) {
    if (length(p) == 2L) paste(sort(p), collapse = "~~") else paste(p, collapse = "")
  }, character(1))
}
lav <- function(model, d) {
  suppressWarnings(lavaan::sem(model, d,
    missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
    information = "observed", control = list(rel.tol = 1e-10)
  ))
}
make_data <- function(structure, seed, n = 300L) {
  set.seed(seed)
  x <- .5 + stats::rnorm(n)
  if (structure %in% c("ser_sat0", "ser_chain0")) {
    # the saturated graph has real shortcut effects; the pure chain data have none (the chain is then true)
    x <- .5 + stats::rnorm(n)
    sc <- structure == "ser_sat0"
    m1 <- .3 + .9 * x + stats::rnorm(n, sd = .7)
    m2 <- -.2 + .7 * m1 + (if (sc) .4 * x else 0) + stats::rnorm(n, sd = .8)
    y <- .2 + .6 * m2 + (if (sc) .35 * m1 else 0) + .25 * x + stats::rnorm(n, sd = .9)
    d <- data.frame(X = x, M1 = m1, M2 = m2, Y = y)
    vars <- names(d)
  } else if (structure %in% c("cov1", "cov2")) {
    z1 <- 1 + .4 * x + stats::rnorm(n, sd = 1.2)
    z2 <- -.5 + .3 * x - .35 * z1 + stats::rnorm(n, sd = 1.1)
    m <- .3 + .5 * x + .4 * z1 - (if (structure == "cov2") .25 * z2 else 0) + stats::rnorm(n, sd = .8)
    y <- .2 + .6 * m + .25 * x - .3 * z1 + (if (structure == "cov2") .2 * z2 else 0) + stats::rnorm(n, sd = .9)
    d <- data.frame(X = x, Z1 = z1, Z2 = z2, M = m, Y = y)
    if (structure == "cov1") d$Z2 <- NULL
    vars <- names(d)
  } else {
    e <- stats::rnorm(n)
    rho <- if (grepl("free$", structure)) .5 else 0
    kk <- if (grepl("^parcov", structure)) as.integer(sub("^parcov(\\d).*", "\\1", structure)) else 0L
    z1 <- 1 + .4 * x + stats::rnorm(n, sd = 1.2)
    z2 <- -.5 + .3 * x - .35 * z1 + stats::rnorm(n, sd = 1.1)
    zc <- function(w) (if (kk >= 1L) w[1L] * z1 else 0) + (if (kk >= 2L) w[2L] * z2 else 0)
    m1 <- .3 + .9 * x + zc(c(.4, -.25)) + .5 * (sqrt(rho) * e + sqrt(1 - rho) * stats::rnorm(n))
    m2 <- -.2 + .6 * x + zc(c(-.3, .2)) + .5 * (sqrt(rho) * e + sqrt(1 - rho) * stats::rnorm(n))
    y <- .2 + .7 * m1 + .3 * m2 + .25 * x + zc(c(.3, -.2)) + stats::rnorm(n, sd = .9)
    d <- data.frame(X = x, M1 = m1, M2 = m2, Y = y)
    if (kk >= 1L) d <- data.frame(X = x, Z1 = z1, M1 = m1, M2 = m2, Y = y)
    if (kk >= 2L) d <- data.frame(X = x, Z1 = z1, Z2 = z2, M1 = m1, M2 = m2, Y = y)
    vars <- names(d)
  }
  # every variable can be incomplete; the mediators and Y depend (ignorably) on the observed X
  for (v in vars) d[stats::runif(n) < .08, v] <- NA_real_
  med <- setdiff(vars, c("X", "Z1", "Z2", "Y"))
  for (v in med) d[stats::runif(n) < stats::plogis(-1.4 + .6 * x), v] <- NA_real_
  d[stats::runif(n) < stats::plogis(-1.2 - .5 * x), "Y"] <- NA_real_
  rbind(d, NA_real_)
}
models <- list(
  cov1 = list(
    fit = "M ~ X + Z1\nY ~ M + X + Z1", lab = "M ~ a*X + Z1\nY ~ b*M + cp*X + Z1\nnie := a*b",
    med = "M"
  ),
  cov2 = list(
    fit = "M ~ X + Z1 + Z2\nY ~ M + X + Z1 + Z2", lab = "M ~ a*X + Z1 + Z2\nY ~ b*M + cp*X + Z1 + Z2\nnie := a*b",
    med = "M"
  ),
  par_ind = list(
    fit = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2",
    lab = "M1 ~ a1*X\nM2 ~ a2*X\nY ~ b1*M1 + b2*M2 + cp*X\nM1 ~~ 0*M2\nnie := a1*b1 + a2*b2",
    med = c("M1", "M2")
  ),
  par_free = list(
    fit = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2",
    lab = "M1 ~ a1*X\nM2 ~ a2*X\nY ~ b1*M1 + b2*M2 + cp*X\nM1 ~~ M2\nnie := a1*b1 + a2*b2",
    med = c("M1", "M2")
  )
)
zeros3 <- "\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y"
models$ser_sat0 <- list(
  fit = paste0("M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X", zeros3),
  lab = paste0("M1 ~ a*X\nM2 ~ d1*M1 + a2*X\nY ~ b1*M1 + b*M2 + cp*X", zeros3,
               "\nnie := a*d1*b\nnie_tot := a*d1*b + a2*b + a*b1\nte := a*d1*b + a2*b + a*b1 + cp"),
  med = c("M1", "M2"), serial = TRUE, paths = c(a = "a", a2 = "a2", d1 = "d1", b1 = "b1", b = "b", c_prime = "cp")
)
# the pure chain: X -> M2 and M1 -> Y are absent; its total indirect effect is the chain effect
models$ser_chain0 <- list(
  fit = paste0("M1 ~ X\nM2 ~ M1\nY ~ M2 + X", zeros3),
  lab = paste0("M1 ~ a*X\nM2 ~ d1*M1\nY ~ b*M2 + cp*X", zeros3,
               "\nnie := a*d1*b\nnie_tot := a*d1*b\nte := a*d1*b + cp"),
  med = c("M1", "M2"), serial = TRUE, paths = c(a = "a", d1 = "d1", b = "b", c_prime = "cp")
)
for (kk in 1:2) {
  zs <- paste0("Z", seq_len(kk), collapse = " + ")
  for (resid in c("ind", "free")) {
    cv <- if (resid == "free") "M1 ~~ M2" else "M1 ~~ 0*M2"
    models[[paste0("parcov", kk, "_", resid)]] <- list(
      fit = paste0("M1 ~ X + ", zs, "\nM2 ~ X + ", zs, "\nY ~ M1 + M2 + X + ", zs, "\n", cv),
      lab = paste0("M1 ~ a1*X + ", zs, "\nM2 ~ a2*X + ", zs, "\nY ~ b1*M1 + b2*M2 + cp*X + ", zs, "\n", cv,
                   "\nnie := a1*b1 + a2*b2"),
      med = c("M1", "M2")
    )
  }
}
records <- new.env(parent = emptyenv())
records$rows <- list()
add <- function(cell, check, value, limit) {
  records$rows[[length(records$rows) + 1L]] <- data.frame(cell, check, value, limit,
    pass = is.finite(value) && value >= 0 && value <= limit
  )
}
for (structure in names(models)) {
  for (seed in c(4111L, 7219L)) {
    cell <- paste(structure, seed, sep = "-")
    mod <- models[[structure]]
    d <- make_data(structure, seed)
    f <- fit_sem(mod$fit, d, missing = "fiml", fixed_x = FALSE, meanstructure = TRUE)
    l <- lav(mod$fit, d)
    q <- coef(f)
    rc <- lavaan::coef(l)
    idx <- match(key(names(q)), key(names(rc)))
    add(cell, "estimates", if (anyNA(idx)) Inf else max(abs(q - rc[idx])), 1e-5)
    V <- vcov(f)
    W <- lavaan::vcov(l)[idx, idx]
    add(cell, "covariance", max(abs(V - W) / sqrt(outer(diag(W), diag(W)))), 1e-3)
    add(cell, "likelihood", abs(as.numeric(logLik(f)) - as.numeric(lavaan::logLik(l))), 1e-6)
    empty <- sum(rowSums(!is.na(d)) == 0L) # the appended row, plus any row the missingness mechanism emptied
    add(cell, "retained", abs(nobs(f) - (nrow(d) - empty)) + abs(f@n_dropped - empty), 0)
    z <- extract_mediation(f, treatment = "X", mediator = mod$med)
    ok_class <- S7::S7_inherits(z, if (isTRUE(mod$serial)) {
      ns$FIMLSerialMediationData
    } else if (length(mod$med) == 1L) {
      ns$FIMLMediationData
    } else {
      ns$FIMLParallelMediationData
    })
    add(cell, "provenance", as.numeric(!ok_class), 0)
    pe <- lavaan::parameterEstimates(lav(mod$lab, d))
    nie_ref <- pe[pe$label == "nie", ]
    if (isTRUE(mod$serial)) {
      tb <- generics::tidy(z, type = "effects")
      est <- stats::setNames(tb$estimate, tb$term)
      se <- stats::setNames(tb$std_error, tb$term)
      lab <- c("nie", "nie_tot", "te")
      eff_key <- c(nie = "nie", nie_tot = "nie_total", te = "te")
      worst_est <- max(vapply(lab, function(l) abs(est[[eff_key[[l]]]] - pe$est[pe$label == l]), numeric(1)))
      worst_se <- max(vapply(lab, function(l) {
        abs(se[[eff_key[[l]]]] - pe$se[pe$label == l]) / pe$se[pe$label == l]
      }, numeric(1)))
      # every extracted path against lavaan's labeled estimate and SE (a d1/b swap cannot hide here)
      pr <- mod$paths
      worst_est <- max(worst_est, vapply(names(pr), function(r) {
        abs(z@estimates[[r]] - pe$est[pe$label == pr[[r]]][1L])
      }, numeric(1)))
      worst_se <- max(worst_se, vapply(names(pr), function(r) {
        abs(sqrt(z@vcov[r, r]) - pe$se[pe$label == pr[[r]]][1L]) / pe$se[pe$label == pr[[r]]][1L]
      }, numeric(1)))
      add(cell, "nie_estimate", worst_est, 1e-5)
      add(cell, "nie_se", worst_se, 2e-3)
      err <- tryCatch(pm(z), error = identity)
      add(cell, "guard", as.numeric(!inherits(err, "error")), 0)
      next
    }
    if (length(mod$med) == 1L) {
      se_nie <- generics::tidy(z, type = "effects")
      se_nie <- se_nie$std_error[se_nie$term == "nie"]
    } else {
      g <- c(a1 = z@b_paths[[1]], a2 = z@b_paths[[2]], b1 = z@a_paths[[1]], b2 = z@a_paths[[2]])
      se_nie <- sqrt(drop(t(g) %*% z@vcov[names(g), names(g)] %*% g))
    }
    add(cell, "nie_estimate", abs(as.numeric(nie(z)) - nie_ref$est), 1e-5)
    add(cell, "nie_se", abs(se_nie - nie_ref$se) / nie_ref$se, 2e-3)
    err <- tryCatch(pm(z), error = identity)
    add(cell, "guard", as.numeric(!inherits(err, "error")), 0)
  }
}
# Refusals (R4): every unadmitted neighbor must be rejected with the classed FIML error; count the ones admitted.
# A probe with an expected reason (a regular expression on the message) also counts as admitted when it is refused for
# any other reason, so a refusal that moved to the wrong rule cannot hide behind the class.
set.seed(1)
big <- as.data.frame(matrix(stats::rnorm(200 * 6), 200, dimnames = list(NULL, c("X", "Z1", "Z2", "Z3", "M", "Y"))))
big$M1 <- big$M
big$M2 <- big$Z3
zeros <- "\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y"
sat0 <- "M1 ~ X\nM2 ~ M1 + X\nY ~ M1 + M2 + X"
chn0 <- "M1 ~ X\nM2 ~ M1\nY ~ M2 + X"
sat1 <- "M1 ~ X + Z1\nM2 ~ M1 + X + Z1\nY ~ M1 + M2 + X + Z1"
chn1 <- "M1 ~ X + Z1\nM2 ~ M1 + Z1\nY ~ M2 + X + Z1"
sat2 <- "M1 ~ X + Z1 + Z2\nM2 ~ M1 + X + Z1 + Z2\nY ~ M1 + M2 + X + Z1 + Z2"
chn2 <- "M1 ~ X + Z1 + Z2\nM2 ~ M1 + Z1 + Z2\nY ~ M2 + X + Z1 + Z2"
omit <- "not yet available"
refused <- list(
  three_covariates = list("M ~ X + Z1 + Z2 + Z3\nY ~ M + X + Z1 + Z2 + Z3"),
  covariate_on_M_only = list("M ~ X + Z1\nY ~ M + X"),
  # Q2 probes: the serial syntax without the three written disturbance zeros (previously `serial` and
  # `parallel_covariate_serial`, which are the chain with a free direct path and the saturated k = 1 set with only
  # `M1 ~~ 0*M2`)
  q2_serial_chain_no_zeros = list(chn0, "needs the independent disturbances"),
  q2_parallel_covariate_serial = list(paste0(sat1, "\nM1 ~~ 0*M2"), "M1 ~~ 0\\*Y, M2 ~~ 0\\*Y"),
  q2_omit_m1m2 = list(paste0(sat0, "\nM1 ~~ 0*Y\nM2 ~~ 0*Y"), "M1 ~~ 0\\*M2"),
  q2_omit_m1y = list(paste0(chn0, "\nM1 ~~ 0*M2\nM2 ~~ 0*Y"), "M1 ~~ 0\\*Y"),
  q2_omit_m2y = list(paste0(sat0, "\nM1 ~~ 0*M2\nM1 ~~ 0*Y"), "M2 ~~ 0\\*Y"),
  q2_free_serial_residual = list(paste0(sat0, "\nM1 ~~ M2\nM1 ~~ 0*Y\nM2 ~~ 0*Y"), "correlated"),
  q2_free_serial_residual_chain = list(paste0(chn0, "\nM1 ~~ 0*M2\nM1 ~~ 0*Y\nM2 ~~ Y"), "correlated"),
  partial_shortcut_x_to_m2 = list(paste0("M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + X", zeros), "shortcut"),
  partial_shortcut_m1_to_y = list(paste0("M1 ~ X\nM2 ~ M1\nY ~ M1 + M2 + X", zeros), "shortcut"),
  fixed_shortcut = list(paste0("M1 ~ X + Z1\nM2 ~ M1 + 0*X + Z1\nY ~ M2 + X + Z1", zeros), "free or absent"),
  labeled_shortcut = list(paste0("M1 ~ X\nM2 ~ M1 + a2*X\nY ~ M1 + M2 + X", zeros), "free or absent"),
  # valid serial syntax is not public until its slice: each shape stays refused (S3 and S4 remove their own entries;
  # the saturated and chain k = 0 shapes became public in S1b and S2 and are gate structures now)
  fixed_shortcut_k0 = list(paste0("M1 ~ X\nM2 ~ M1 + 0*X\nY ~ M2 + X", zeros), "free or absent"),
  serial_saturated_k1 = list(paste0(sat1, zeros), omit), serial_chain_k1 = list(paste0(chn1, zeros), omit),
  serial_saturated_k2 = list(paste0(sat2, zeros), omit), serial_chain_k2 = list(paste0(chn2, zeros), omit),
  parallel_covariate_on_one_mediator = list("M1 ~ X + Z1\nM2 ~ X\nY ~ M1 + M2 + X + Z1\nM1 ~~ 0*M2"),
  parallel_three_covariates = list(paste0("M1 ~ X + Z1 + Z2 + Z3\nM2 ~ X + Z1 + Z2 + Z3\n",
                                          "Y ~ M1 + M2 + X + Z1 + Z2 + Z3\nM1 ~~ 0*M2")),
  parallel_omitted_cov = list("M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X"),
  parallel_tied_paths = list("M1 ~ a*X\nM2 ~ a*X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2"),
  parallel_fixed_cov = list("M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0.3*M2")
)
accepted <- vapply(refused, function(p) {
  r <- tryCatch(fit_sem(p[[1L]], big, missing = "fiml", fixed_x = FALSE, meanstructure = TRUE), error = identity)
  !inherits(r, "medfit_sem_fiml_error") || (length(p) > 1L && !grepl(p[[2L]], conditionMessage(r)))
}, logical(1))
# the reversed-order extraction probe of spec 4.4 (a real saturated serial fit exists since S1b): refused with the class
rev_fit <- tryCatch(fit_sem(paste0(sat0, zeros), big, missing = "fiml", fixed_x = FALSE, meanstructure = TRUE),
                    error = identity)
rev_err <- tryCatch(extract_mediation(rev_fit, treatment = "X", mediator = c("M2", "M1")), error = identity)
accepted[["serial_reversed_order_extraction"]] <- !inherits(rev_err, "medfit_error_fiml_extract_unsupported")
# the same for a real pure-chain fit (public since S2)
rev_chain <- tryCatch(fit_sem(paste0(chn0, zeros), big, missing = "fiml", fixed_x = FALSE, meanstructure = TRUE),
                      error = identity)
rev_chain_err <- tryCatch(extract_mediation(rev_chain, treatment = "X", mediator = c("M2", "M1")), error = identity)
accepted[["serial_chain_reversed_order_extraction"]] <- !inherits(rev_chain_err, "medfit_error_fiml_extract_unsupported")
# a pair of variables never jointly observed (saturated serial, direct path free): fails closed at the numerical stage
never <- big[, c("X", "M1", "M2", "Y")]
never$M2 <- .5 * never$M1 + stats::rnorm(nrow(never))
never[1:100, "Y"] <- NA_real_
never[101:200, "M2"] <- NA_real_
never_err <- tryCatch(fit_sem(paste0(sat0, zeros), never, missing = "fiml", fixed_x = FALSE, meanstructure = TRUE),
                      error = identity)
accepted[["serial_never_jointly_observed"]] <- !(inherits(never_err, "medfit_sem_fiml_error") &&
                                                   identical(never_err$stage, "numerical"))
add("refusals", "unadmitted_accepted", sum(accepted), 0)
results <- do.call(rbind, records$rows)
dir.create("tests/sim/results", recursive = TRUE, showWarnings = FALSE)
out <- if (nzchar(mutant)) {
  tempfile("fiml-ext-mutant-", fileext = ".csv")
} else {
  file.path("tests/sim/results", paste0("sem-fiml-ext-gate-", Sys.Date(), ".csv"))
}
utils::write.csv(results, out, row.names = FALSE)
print(results)
if (!all(results$pass)) stop("extended bounded FIML gate failed")
