# Extended bounded FIML gate (FI-G1 covariates, FI-G2 parallel mediators with zero, one or two covariates). Oracle: matched lavaan raw-data FIML with
# observed information (estimates, covariance, logLik, defined indirect effect and its delta SE). Two seeds each.
# MUTANT= wrong_unit, no_offset, swap_b, dropped_cov, missing_guard, parcov_drop_path, parcov_orthogonal alter production functions in memory only.
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
  if (structure %in% c("cov1", "cov2")) {
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
    ok_class <- S7::S7_inherits(z, if (length(mod$med) == 1L) ns$FIMLMediationData else ns$FIMLParallelMediationData)
    add(cell, "provenance", as.numeric(!ok_class), 0)
    pe <- lavaan::parameterEstimates(lav(mod$lab, d))
    nie_ref <- pe[pe$label == "nie", ]
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
set.seed(1)
big <- as.data.frame(matrix(stats::rnorm(200 * 6), 200, dimnames = list(NULL, c("X", "Z1", "Z2", "Z3", "M", "Y"))))
big$M1 <- big$M
big$M2 <- big$Z3
refused <- c(
  three_covariates = "M ~ X + Z1 + Z2 + Z3\nY ~ M + X + Z1 + Z2 + Z3",
  covariate_on_M_only = "M ~ X + Z1\nY ~ M + X",
  serial = "M1 ~ X\nM2 ~ M1\nY ~ M2 + X",
  parallel_covariate_on_one_mediator = "M1 ~ X + Z1\nM2 ~ X\nY ~ M1 + M2 + X + Z1\nM1 ~~ 0*M2",
  parallel_three_covariates = paste0("M1 ~ X + Z1 + Z2 + Z3\nM2 ~ X + Z1 + Z2 + Z3\n",
                                     "Y ~ M1 + M2 + X + Z1 + Z2 + Z3\nM1 ~~ 0*M2"),
  parallel_covariate_serial = "M1 ~ X + Z1\nM2 ~ M1 + X + Z1\nY ~ M1 + M2 + X + Z1\nM1 ~~ 0*M2",
  parallel_omitted_cov = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X",
  parallel_tied_paths = "M1 ~ a*X\nM2 ~ a*X\nY ~ M1 + M2 + X\nM1 ~~ 0*M2",
  parallel_fixed_cov = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ 0.3*M2"
)
accepted <- vapply(refused, function(model) {
  r <- tryCatch(fit_sem(model, big, missing = "fiml", fixed_x = FALSE, meanstructure = TRUE), error = identity)
  !inherits(r, "medfit_sem_fiml_error")
}, logical(1))
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
