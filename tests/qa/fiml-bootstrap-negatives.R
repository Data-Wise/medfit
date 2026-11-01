# Zero-fit negative controls, independent of the paired optimizer execution.
devtools::load_all(quiet = TRUE)
source("tests/testthat/helper-fiml-oracle.R")
workspace <- "_agents_workspace/fiml-bounded-inference"
mat <- readRDS(file.path(workspace, "qa-matrix.rds"))
fit <- mat$artifacts[["mar-free"]]$fit
assert <- function(x) if (!isTRUE(x)) stop("independent assertion failed")
reject <- function(expression) assert(inherits(tryCatch(force(expression), error = identity), "error"))
for (a in mat$artifacts) {
  assert(isTRUE(lavaan::lavInspect(a$ref, "converged")))
  assert(lavaan::lavInspect(a$ref, "nobs") == 300L)
  for (i in seq_len(12L)) {
    assert(isTRUE(lavaan::lavInspect(a$reference[[i]], "converged")))
    assert(lavaan::lavInspect(a$reference[[i]], "nobs") == 300L)
    r <- lavaan::coef(a$reference[[i]])
    q <- coef(a$native[[i]])
    for (effect in c("nie", "nde", "te")) {
      hand <- function(x) {
        cp <- if ("cp" %in% names(x)) x[["cp"]] else 0
        switch(effect,
          nie = x[["a"]] * x[["b"]],
          nde = cp,
          te = cp + x[["a"]] * x[["b"]]
        )
      }
      assert(abs(hand(q) - hand(r)) < 1e-5)
    }
  }
}
cat("All 78 lavaan fits converged with exact retained counts; paired three-effect hand oracles PASS\n")
V <- matrix(c(4, 2, 2, 9), 2, dimnames = list(c("a", "b"), c("a", "b")))
root <- medfit:::.bootstrap_fiml_factor
for (damage in c("duplicate", "missing", "Inf", "NaN", "variance", "asymmetry", "indefinite")) {
  bad <- V
  if (damage == "duplicate") dimnames(bad) <- list(c("a", "a"), c("a", "a"))
  if (damage == "missing") dimnames(bad) <- list(c("a", "absent"), c("a", "absent"))
  if (damage == "Inf") bad[1, 1] <- Inf
  if (damage == "NaN") bad[1, 1] <- NaN
  if (damage == "variance") bad[1, 1] <- -1
  if (damage == "asymmetry") bad[1, 2] <- 3
  if (damage == "indefinite") bad[1, 2] <- bad[2, 1] <- 8
  reject(root(bad, c("a", "b")))
}
singular <- matrix(1, 2, 2, dimnames = dimnames(V))
assert(max(abs(tcrossprod(root(singular, c("a", "b"))$factor) - singular)) < 1e-14)
roundoff <- singular
roundoff[1, 2] <- roundoff[2, 1] <- 1 + .Machine$double.eps
assert(length(root(roundoff, c("a", "b"))$clipped) == 1L)
asym <- V
asym[1, 2] <- asym[1, 2] + .Machine$double.eps * 8
assert(root(asym, c("a", "b"))$symmetry_adjustment > 0)
cat("Covariance singularity, recorded roundoff, alias/name, finite and material-repair controls PASS\n")
for (args in list(
  list(seed = NA_integer_), list(seed = Inf), list(ci_level = 0), list(n_boot = NA),
  list(ncores = 0), list(parallel = NA), list(effect = "ni"), list(method = "plugin"),
  list(cluster = "X"), list(mediation_data = fit), list(statistic_fn = NULL)
)) {
  base <- list(source_fit = fit, effect = "nie", method = "parametric", n_boot = 3L)
  base[names(args)] <- args
  set.seed(199L)
  before <- .Random.seed
  reject(do.call(bootstrap_mediation, base))
  assert(identical(before, .Random.seed))
}
cat("Invalid seed/confidence/B/cores/effect/conflicts guard before RNG PASS\n")
# Negative variance coordinates must not trigger truncation or rejection.
q <- coef(fit)
set.seed(123L)
Z <- matrix(stats::rnorm(8L * length(q)), 8L, byrow = TRUE)
draw <- sweep(Z * 100, 2, q, `+`)
colnames(draw) <- names(q)
assert(any(draw[, "X~~X"] < 0))
out <- testthat::with_mocked_bindings(
  bootstrap_mediation(source_fit = fit, effect = "nie", method = "parametric", n_boot = 8L, seed = 123L),
  .bootstrap_fiml_factor = function(V, parameters) list(factor = diag(100, length(parameters))), .package = "medfit"
)
assert(max(abs(out@boot_estimates - draw[, "a"] * draw[, "b"])) < 1e-10)
nonfinite <- testthat::with_mocked_bindings(
  bootstrap_mediation(source_fit = fit, effect = "nie", method = "parametric", n_boot = 3L, seed = 123L),
  .bootstrap_fiml_factor = function(V, parameters) list(factor = matrix(Inf, length(parameters), length(parameters))),
  .package = "medfit"
)
assert(all(is.na(nonfinite@boot_estimates)) && identical(nonfinite@inference$status, "withheld"))
cat("Negative nuisance draws untruncated and nonfinite functionals withheld PASS\n")
# Direct base-revision callback execution avoids comparing only a stored receipt.
base_text <- system2("git", c("show", "5e845007:R/bootstrap.R"), stdout = TRUE)
base_env <- new.env(parent = asNamespace("medfit"))
eval(parse(text = base_text), base_env)
for (parallel in c(FALSE, TRUE)) {
  args <- list(
    statistic_fn = function(d) mean(d$X), data = data.frame(X = 1:20),
    method = "nonparametric", n_boot = 12L, seed = 911L, parallel = parallel, ncores = 2L
  )
  old <- do.call(base_env$bootstrap_mediation, args)
  current <- do.call(bootstrap_mediation, args)
  assert(identical(old@boot_estimates, current@boot_estimates))
  assert(identical(c(old@estimate, old@ci_lower, old@ci_upper),
                   c(current@estimate, current@ci_lower, current@ci_upper)))
}
cat("Legacy row callback exact numeric neutrality versus base sequential/two-worker PASS\n")
