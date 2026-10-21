## Deterministic fixtures D1 (memory RQ1-RQ3) and D2 (near-zero divisor) for the solver benchmark.
## Reuses bench.R's definitions. Data are centered (equivalent to free intercepts under ML).
## Usage: Rscript bench_fixtures.R <out_csv>
fixtures_out <- commandArgs(TRUE)[1]
src <- readLines("docs/strategy/ideation-checks/solver-benchmark/bench.R")
cut <- grep("^rows <- list\\(\\); t_start", src)
src <- sub("^args <- commandArgs\\(TRUE\\)", "args <- c(\"all\", \"1\", \"/tmp/unused.csv\")", src)
eval(parse(text = src[1:(cut - 1)]))
methods <- c("T", "AUG", "SLSQP", "CSOLNP")
data("memory_exp", package = "RMediation"); d <- as.data.frame(memory_exp)
ctr <- function(v) v - mean(v)
x <- ctr(as.numeric(d$x == "imagery")); im <- ctr(d$imagery); rp <- ctr(d$repetition); y <- ctr(d$recall)

fixtures <- list(
  list(id = "D1-RQ1", mod = two_path(x, im, y), kind = "two", q = 0, ref = 72.5436, ref_tol = 1e-4),
  list(id = "D1-RQ2", mod = parallel(x, im, rp, y), kind = "par_prod", idx = c(2, 5), q = 0, ref = 0.0831, ref_tol = 1e-4),
  list(id = "D1-RQ3", mod = parallel(x, im, rp, y), kind = "parallel", q = 0, ref = 25.8283, ref_tol = 1e-4))
set.seed(20261024); n <- 200; xx <- rnorm(n); mm <- rnorm(n); mm <- mm - sum(xx * mm) / sum(xx^2) * xx  # x'm = 0
fixtures[[4]] <- list(id = "D2-near-zero-divisor", mod = two_path(xx, mm, .5 * mm + rnorm(n)), kind = "two", q = .05,
                      ref = NA, ref_tol = 1e-6)

rows <- list()
for (fx in fixtures) {
  mod <- fx$mod; F0 <- mod$f(mod$mle)
  if (fx$kind == "par_prod") mod$idx <- fx$idx
  con <- if (fx$kind == "parallel") con_eqprod() else con_prod(mod$idx)
  ref <- if (!is.na(fx$ref)) fx$ref else oracle_abq(mod, fx$q)
  cl <- list(kind = if (fx$kind == "two") "two" else "parallel", q = fx$q)
  sts <- if (fx$kind == "par_prod") lapply(list(c(1, 1), c(-1, 1), c(1, -1), c(-1, -1)), function(fl) { s <- mod$mle; s[fx$idx] <- s[fx$idx] * fl; s })
         else starts_for(mod, cl)
  for (meth in methods) {
    if (meth == "CSOLNP" && !has_rsolnp) next
    res <- if (meth == "T") {
      if (fx$kind == "parallel") run_T1_eqprod(mod) else if (fx$q == 0) run_T0(mod, mod$idx) else run_T1_abq(mod, fx$q)
    } else run_constrained(meth, mod, con, fx$q, sts)
    lr <- res$f - F0; lr2 <- res$f_relaxed - F0
    rows[[length(rows) + 1]] <- data.frame(fixture = fx$id, method = meth, lr = lr, lr_relaxed = lr2, reference = ref,
      success = !is.na(lr) && abs(lr - ref) <= max(fx$ref_tol, 1e-6 * max(1, ref)),
      success_relaxed = !is.na(lr2) && abs(lr2 - ref) <= max(fx$ref_tol, 1e-6 * max(1, ref)))
  }
}
res <- do.call(rbind, rows); write.csv(res, fixtures_out, row.names = FALSE); print(res, digits = 8, row.names = FALSE)
cat("T (Tier 0/1) must succeed on every fixture:", all(res$success[res$method == "T"]), "\n")
