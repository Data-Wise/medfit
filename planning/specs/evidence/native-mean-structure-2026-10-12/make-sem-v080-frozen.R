# Freeze the native SEM engine's v0.8.0 numbers for the 0.9.0 mean-structure gate (T1, G3).
# Run against the v0.8.0 tag, NOT a tree with the has_mean edits:
#   git archive v0.8.0 | tar -x -C <empty dir>; (cd <dir>; Rscript <this file> <out.rds>)
# Stores, per case: the data, the model, F / gradient / expected and observed information at a point
# off the optimum (`theta_eval` = 1.1 * fitted theta; the gradient at the optimum is ~0, so a relative
# tolerance there compares noise) through the internal evaluators, and the fitted estimates and vcov.
suppressMessages(devtools::load_all("."))
out <- commandArgs(TRUE)[1]

gen <- function(n, seed) {
  set.seed(seed)
  d <- data.frame(X = rnorm(n), C = rnorm(n, sd = 1.2))
  d$M <- 0.4 * d$X + 0.3 * d$C + rnorm(n, sd = 0.9)
  d$Y <- 0.5 * d$M + 0.2 * d$X + 0.1 * d$C + rnorm(n, sd = 0.8)
  d
}
d <- gen(300, 20261012)
w <- local({ set.seed(7); runif(300, 0.4, 2.5) })

cases <- list(
  observed = list(model = "M ~ X + C\nY ~ M + X + C", data = d, weights = NULL, se_type = "model"),
  weighted_sandwich = list(model = "M ~ X + C\nY ~ M + X + C", data = d, weights = w, se_type = "sandwich"),
  constrained = list(model = "M ~ a*X + C\nY ~ b*M + X + C\na + b == 0.6", data = d, weights = NULL, se_type = "model")
)

frozen <- lapply(cases, function(k) {
  fit <- fit_sem(k$model, k$data, weights = k$weights, se_type = k$se_type)
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram, fit@internals$weights)
  th <- fit@theta
  te <- th * 1.1
  c(k, list(
    theta = th, theta_eval = te, f = .sem_fml(te, ram, smp), grad = .sem_grad(te, ram, smp),
    info_expected = .sem_info_expected(te, ram, smp), info_observed = .sem_info_observed(te, ram, smp),
    vcov = fit@vcov
  ))
})
frozen$r_version <- as.character(getRversion())
saveRDS(frozen, out, version = 2)
cat("wrote", out, "\n")
