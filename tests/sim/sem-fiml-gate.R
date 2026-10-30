# Bounded local FIML oracle gate. Independent row likelihood, lavaan covariance, and public-route guards.
# MUTANT=wrong_n, complete_case, dropped_cov, lost_provenance, missing_guard alter production functions in memory only.
suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/testthat/helper-sem.R")
ns <- asNamespace("medfit")
mutant <- Sys.getenv("MUTANT", "")
swap <- function(name, pattern, replacement) {
  fn <- sem_mutate(get(name, ns), pattern, replacement)
  if (bindingIsLocked(name, ns)) unlockBinding(name, ns)
  assign(name, fn, envir = ns)
}
if (mutant == "wrong_n") {
  swap(
    ".sem_fiml_fit", "V <- p$transport %*% solve(H) %*% t(p$transport)",
    "V <- 2 * p$transport %*% solve(H) %*% t(p$transport)"
  )
} else if (mutant == "complete_case") {
  swap(".sem_fiml_syntax", "candidate <- .sem_fiml_fit(z, direct = spec$direct)",
       "candidate <- .sem_fiml_fit(z[stats::complete.cases(z), , drop = FALSE], direct = spec$direct)")
} else if (mutant == "dropped_cov") {
  swap(
    ".sem_fiml_fit", "V <- p$transport %*% solve(H) %*% t(p$transport)",
    "V <- (p$transport %*% solve(H) %*% t(p$transport)) * diag(nrow(p$transport))"
  )
} else if (mutant == "lost_provenance") {
  swap(".sem_fiml_extract", "do.call(FIMLMediationData, c(props, list(fit_context = ctx)))", "out")
} else if (mutant == "missing_guard") {
  swap(".sem_fiml_refuse", "if (.sem_fiml_is(x))", "if (FALSE)")
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

# Direct structural formulas, independent of the production RAM/objective and its standardization.
row_nll <- function(d, theta) {
  a <- theta[["a"]]
  b <- theta[["b"]]
  cp <- if ("cp" %in% names(theta)) theta[["cp"]] else 0
  L <- rbind(c(1, 0, 0), c(a, 1, 0), c(cp + a * b, b, 1))
  S <- L %*% diag(theta[c("X~~X", "M~~M", "Y~~Y")]) %*% t(L)
  mu <- drop(L %*% theta[c("X~1", "M~1", "Y~1")])
  sum(vapply(seq_len(nrow(d)), function(i) {
    o <- which(!is.na(d[i, ]))
    if (!length(o)) {
      return(0)
    }
    C <- chol(S[o, o, drop = FALSE])
    z <- backsolve(C, as.numeric(d[i, o]) - mu[o], transpose = TRUE)
    .5 * (length(o) * log(2 * pi) + 2 * sum(log(diag(C))) + sum(z^2))
  }, 0))
}
records <- new.env(parent = emptyenv())
records$rows <- list()
add <- function(cell, check, value, limit) {
  records$rows[[length(records$rows) + 1L]] <- data.frame(cell, check, value, limit,
    pass = is.finite(value) && value >= 0 && value <= limit
  )
}
for (seed in c(271L, 613L)) {
  set.seed(seed)
  n <- 240L
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  d <- data.frame(X = x, M = m, Y = .7 + .6 * m + .25 * x + stats::rnorm(n, sd = .9))
  if (seed == 271L) {
    for (j in 1:3) d[seq(j, n, 5L), j] <- NA_real_
  } else {
    for (j in 1:3) d[seq(j, n, 3L), j] <- NA_real_
  }
  d <- rbind(d, c(NA_real_, NA_real_, NA_real_))
  for (direct in c(TRUE, FALSE)) {
    cell <- paste(seed, if (direct) "free" else "zero", sep = "-")
    model <- paste0("M ~ a*X\nY ~ b*M + ", if (direct) "cp" else "0", "*X")
    f <- fit_sem(model, d, fixed_x = FALSE, missing = "fiml")
    l <- lavaan::sem(model, d,
      missing = "ml", fixed.x = FALSE, meanstructure = TRUE,
      information = "observed", control = list(rel.tol = 1e-10)
    )
    q <- coef(f)
    ref <- lavaan::coef(l)
    add(cell, "estimates", max(abs(q - ref[names(q)])), 1e-5)
    V <- vcov(f)
    W <- lavaan::vcov(l)[names(q), names(q)]
    add(cell, "covariance", max(abs(V - W) / sqrt(outer(diag(W), diag(W)))), 1e-3)
    add(cell, "likelihood", abs(row_nll(d, q) + as.numeric(logLik(f))), 1e-7)
    add(cell, "retained", abs(nobs(f) - n) + abs(f@n_dropped - 1L), 0)
    z <- extract_mediation(f, treatment = "X", mediator = "M")
    add(cell, "provenance", as.numeric(!S7::S7_inherits(z, ns$FIMLMediationData)), 0)
    err <- tryCatch(pm(z), error = identity)
    add(cell, "guard", as.numeric(!inherits(err, "error")), 0)
  }
}
results <- do.call(rbind, records$rows)
dir.create("tests/sim/results", recursive = TRUE, showWarnings = FALSE)
out <- if (nzchar(mutant)) {
  tempfile("fiml-mutant-", fileext = ".csv")
} else {
  file.path("tests/sim/results", paste0("sem-fiml-gate-", Sys.Date(), ".csv"))
}
utils::write.csv(results, out, row.names = FALSE)
print(results)
if (!all(results$pass)) stop("bounded FIML gate failed")
