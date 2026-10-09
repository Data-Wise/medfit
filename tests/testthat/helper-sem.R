# Helpers for the native SEM engine tests (PR 1: RAM core, information, driver).
#
# Each model constructor returns the RAM index object, the true parameter vector
# (named by the engine's parameter names) and the names of its latent variables.
# Data come from the model-implied covariance at the true parameters, so a fit
# can be checked against a known answer without a separate simulator per model.
# The fifth, constrained K10 structure is added with the constrained gate (S15).
# lavaan and OpenMx wrappers are oracles only: each test skips when the
# package is absent.

sem_rows <- function(...) {
  rows <- list(...)
  do.call(rbind, lapply(rows, function(r) {
    data.frame(row = r[[1]], col = r[[2]], label = if (length(r) > 2) r[[3]] else "",
               value = if (length(r) > 3) r[[4]] else NA_real_, stringsAsFactors = FALSE)
  }))
}

sem_model <- function(vars, obs, a, s, theta, latent = character(), loadings = character()) {
  ram <- .sem_ram(vars, obs, a, s) # nolint: object_usage_linter.
  stopifnot(setequal(names(theta), ram$par_names))
  list(ram = ram, theta = theta[ram$par_names], latent = latent, loadings = loadings)
}

# Observed path model with one covariate: C -> M, X -> M -> Y, X -> Y, C -> Y.
# Ten parameters and ten moments (p = 4), so the model is saturated.
sem_model_observed <- function() {
  sem_model(
    vars = c("X", "C", "M", "Y"), obs = c("X", "C", "M", "Y"),
    a = sem_rows(list("M", "X"), list("M", "C"), list("Y", "M"), list("Y", "X"), list("Y", "C")),
    s = sem_rows(list("X", "X"), list("C", "C"), list("X", "C"), list("M", "M"), list("Y", "Y")),
    theta = c("M ~ X" = .4, "M ~ C" = .3, "Y ~ M" = .5, "Y ~ X" = .2, "Y ~ C" = .1,
              "X ~~ X" = 1, "C ~~ C" = 1.2, "X ~~ C" = .3, "M ~~ M" = .8, "Y ~~ Y" = .7)
  )
}

# Latent mediator with three indicators (marker loading fixed to 1).
sem_model_latent <- function() {
  sem_model(
    vars = c("X", "eta", "m1", "m2", "m3", "Y"), obs = c("X", "m1", "m2", "m3", "Y"),
    a = sem_rows(list("eta", "X"), list("m1", "eta", "", 1), list("m2", "eta"), list("m3", "eta"),
                 list("Y", "eta"), list("Y", "X")),
    s = sem_rows(list("X", "X"), list("eta", "eta"), list("m1", "m1"), list("m2", "m2"), list("m3", "m3"),
                 list("Y", "Y")),
    theta = c("eta ~ X" = .5, "m2 ~ eta" = .8, "m3 ~ eta" = .7, "Y ~ eta" = .4, "Y ~ X" = .2,
              "X ~~ X" = 1, "eta ~~ eta" = .9, "m1 ~~ m1" = .5, "m2 ~~ m2" = .6, "m3 ~~ m3" = .7, "Y ~~ Y" = .8),
    latent = "eta", loadings = c("m2 ~ eta", "m3 ~ eta")
  )
}

# Two parallel mediators with correlated residuals.
sem_model_parallel <- function() {
  sem_model(
    vars = c("X", "M1", "M2", "Y"), obs = c("X", "M1", "M2", "Y"),
    a = sem_rows(list("M1", "X"), list("M2", "X"), list("Y", "M1"), list("Y", "M2"), list("Y", "X")),
    s = sem_rows(list("X", "X"), list("M1", "M1"), list("M2", "M2"), list("M1", "M2"), list("Y", "Y")),
    theta = c("M1 ~ X" = .5, "M2 ~ X" = .4, "Y ~ M1" = .3, "Y ~ M2" = .4, "Y ~ X" = .2,
              "X ~~ X" = 1, "M1 ~~ M1" = .8, "M2 ~~ M2" = .9, "M1 ~~ M2" = .2, "Y ~~ Y" = .7)
  )
}

# Two serial mediators: X -> M1 -> M2 -> Y, with every direct path free.
sem_model_serial <- function() {
  sem_model(
    vars = c("X", "M1", "M2", "Y"), obs = c("X", "M1", "M2", "Y"),
    a = sem_rows(list("M1", "X"), list("M2", "M1"), list("M2", "X"), list("Y", "M2"), list("Y", "M1"),
                 list("Y", "X")),
    s = sem_rows(list("X", "X"), list("M1", "M1"), list("M2", "M2"), list("Y", "Y")),
    theta = c("M1 ~ X" = .5, "M2 ~ M1" = .4, "M2 ~ X" = .1, "Y ~ M2" = .3, "Y ~ M1" = .1, "Y ~ X" = .2,
              "X ~~ X" = 1, "M1 ~~ M1" = .8, "M2 ~~ M2" = .9, "Y ~~ Y" = .7)
  )
}

sem_models <- function() {
  list(observed = sem_model_observed(), latent = sem_model_latent(),
       parallel = sem_model_parallel(), serial = sem_model_serial())
}

# Data drawn from the model-implied covariance at the true parameters.
sem_sim <- function(model, n, seed) {
  set.seed(seed)
  sigma <- .sem_implied(model$ram, model$theta) # nolint: object_usage_linter.
  as.data.frame(MASS::mvrnorm(n, rep(0, ncol(sigma)), sigma))
}

# Central-difference gradient, the independent check for the analytic one.
sem_fd_grad <- function(f, x, h = 1e-6) {
  vapply(seq_along(x), function(i) {
    e <- numeric(length(x))
    e[i] <- h
    (f(x + e) - f(x - e)) / (2 * h)
  }, numeric(1))
}

# Rebuild an internal function with one source pattern replaced, to plant a
# defect. The pattern must match exactly once, so a refactor cannot turn a
# planted defect into a silent no-op.
sem_mutate <- function(fn, pattern, replacement) {
  src <- paste(deparse(fn, width.cutoff = 500L), collapse = "\n")
  hits <- gregexpr(pattern, src, fixed = TRUE)[[1]]
  stopifnot(hits[1] > 0, length(hits) == 1)
  # eval(parse()) is safe here: the text is this package's own deparsed function with a literal
  # pattern swap written in the test, never external input.
  out <- eval(parse(text = sub(pattern, replacement, src, fixed = TRUE)))
  environment(out) <- environment(fn)
  out
}

# lavaan parameter names for the engine's parameter names (oracle wrapper).
sem_lavaan_names <- function(par_names, loadings) {
  vapply(par_names, function(nm) {
    if (grepl(" ~~ ", nm, fixed = TRUE)) {
      parts <- strsplit(nm, " ~~ ", fixed = TRUE)[[1]]
      return(paste(parts, collapse = "~~"))
    }
    parts <- strsplit(nm, " ~ ", fixed = TRUE)[[1]]
    if (nm %in% loadings) paste0(parts[2], "=~", parts[1]) else paste0(parts[1], "~", parts[2])
  }, character(1), USE.NAMES = FALSE)
}

# lavaan model text for the four structures (fixed.x = FALSE keeps the
# exogenous variances free, as the engine does).
sem_lavaan_text <- function(name) {
  switch(name,
    observed = "M ~ X + C\nY ~ M + X + C",
    latent = "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X",
    parallel = "M1 ~ X\nM2 ~ X\nY ~ M1 + M2 + X\nM1 ~~ M2",
    serial = "M1 ~ X\nM2 ~ M1 + X\nY ~ M2 + M1 + X"
  )
}

# A valid starting vector: variances 1, covariances 0, everything else 0.1.
sem_start <- function(ram) {
  stats::setNames(vapply(ram$par_names, function(nm) {
    if (grepl(" ~~ ", nm, fixed = TRUE)) {
      parts <- strsplit(nm, " ~~ ", fixed = TRUE)[[1]]
      if (parts[1] == parts[2]) 1 else 0
    } else {
      0.1
    }
  }, numeric(1), USE.NAMES = FALSE), ram$par_names)
}

# lavaan's estimates and SEs for a structure, reordered to the engine's parameter order.
sem_lavaan_ref <- function(nm, information, n = 400, seed = 21) {
  mod <- sem_models()[[nm]]
  d <- sem_sim(mod, n, seed)
  fit <- suppressWarnings(lavaan::sem(sem_lavaan_text(nm), d, fixed.x = FALSE, information = information))
  norm <- function(x) {
    vapply(strsplit(x, "~~", fixed = TRUE), function(p) {
      if (length(p) == 2) paste(sort(p), collapse = "~~") else p
    }, character(1))
  }
  pos <- match(norm(sem_lavaan_names(mod$ram$par_names, mod$loadings)), norm(names(lavaan::coef(fit))))
  list(
    mod = mod, smp = .sem_sample(d, mod$ram), # nolint: object_usage_linter.
    theta = unname(lavaan::coef(fit))[pos], se = sqrt(diag(lavaan::vcov(fit)))[pos]
  )
}

# Latent-mediator model with small indicator residuals; at n = 50 and seed 10 lavaan
# returns a negative variance (a Heywood case), the fixture for improper solutions.
sem_model_heywood <- function() {
  mod <- sem_model_latent()
  mod$theta["m1 ~~ m1"] <- 0.05
  mod$theta["m2 ~~ m2"] <- 0.1
  mod
}

# Exact transport of a parameter vector to data multiplied by `s` in every
# observed and latent variable: (co)variances scale by s^2, paths and loadings
# do not, and the discrepancy is unchanged.
sem_transport <- function(theta, s) {
  ifelse(grepl(" ~~ ", names(theta), fixed = TRUE), theta * s^2, theta)
}

sem_scale_sample <- function(smp, s) {
  smp$s <- smp$s * s^2
  smp$logdet <- smp$logdet + smp$p * log(s^2)
  smp
}
