## Solver benchmark (DESIGN.md, precommitted in 0fa69b1). Claude's code; base R + nloptr + Rsolnp.
## Usage: Rscript bench.R <cells (comma list, or "all")> <reps> <out_csv> [methods]
args <- commandArgs(TRUE)
cells_arg <- args[1]; reps <- as.integer(args[2]); out <- args[3]
methods <- if (length(args) >= 4) strsplit(args[4], ",")[[1]] else c("T", "AUG", "SLSQP", "CSOLNP")
here <- "docs/strategy/ideation-checks/solver-benchmark"
.libPaths(c(file.path(here, "rlib"), .libPaths()))
suppressMessages({ library(nloptr); has_rsolnp <- requireNamespace("Rsolnp", quietly = TRUE) })
cat("R", R.version$major, R.version$minor, "| nloptr", as.character(packageVersion("nloptr")),
    "| Rsolnp", if (has_rsolnp) as.character(packageVersion("Rsolnp")) else "absent", "\n")
BASE_SEED <- 20261024L

## ---------------------------------------------------------------- models
## Two-path: theta = (a, b, cp, lpm, lpy); F = n lpm + RSSM/psiM + n lpy + RSSY/psiY.
two_path <- function(x, m, y) {
  n <- length(x); sxx <- sum(x^2)
  f <- function(t) { rm <- m - t[1] * x; ry <- y - t[3] * x - t[2] * m
    n * t[4] + sum(rm^2) / exp(t[4]) + n * t[5] + sum(ry^2) / exp(t[5]) }
  g <- function(t) { rm <- m - t[1] * x; ry <- y - t[3] * x - t[2] * m; pm <- exp(t[4]); py <- exp(t[5])
    c(-2 * sum(x * rm) / pm, -2 * sum(m * ry) / py, -2 * sum(x * ry) / py,
      n - sum(rm^2) / pm, n - sum(ry^2) / py) }
  a <- sum(x * m) / sxx; X <- cbind(x, m); cb <- solve(crossprod(X), crossprod(X, y))
  rm <- m - a * x; ry <- y - X %*% cb
  mle <- c(a = a, b = cb[2], cp = cb[1], lpm = log(mean(rm^2)), lpy = log(mean(ry^2)))
  list(n = n, f = f, g = g, mle = mle, idx = 1:2, x = x, m = m, y = y, sxx = sxx,
       se_a = sqrt(mean(rm^2) / sxx))
}
## Three-path chain: theta = (b1, b2, b3, l1, l2, l3).
chain3 <- function(x, m1, m2, y) {
  n <- length(x); dep <- list(m1, m2, y); reg <- list(x, m1, m2)
  f <- function(t) sum(vapply(1:3, function(j) { r <- dep[[j]] - t[j] * reg[[j]]; n * t[3 + j] + sum(r^2) / exp(t[3 + j]) }, 0))
  g <- function(t) { out <- numeric(6); for (j in 1:3) { r <- dep[[j]] - t[j] * reg[[j]]; p <- exp(t[3 + j])
    out[j] <- -2 * sum(reg[[j]] * r) / p; out[3 + j] <- n - sum(r^2) / p }; out }
  b <- vapply(1:3, function(j) sum(dep[[j]] * reg[[j]]) / sum(reg[[j]]^2), 0)
  l <- vapply(1:3, function(j) log(mean((dep[[j]] - b[j] * reg[[j]])^2)), 0)
  list(n = n, f = f, g = g, mle = setNames(c(b, l), c("b1", "b2", "b3", "l1", "l2", "l3")), idx = 1:3,
       dep = dep, reg = reg)
}
## Parallel model, variance-profiled (DEVIATION 1 in RESULTS.md): theta = (a1, a2, cp, b1, b2);
## F = n log det(E'E/n) + n log(RSSY/n) (+ const); E = residuals of (M1, M2) on x.
parallel <- function(x, m1, m2, y) {
  n <- length(x)
  f <- function(t) { E <- cbind(m1 - t[1] * x, m2 - t[2] * x); ry <- y - t[3] * x - t[4] * m1 - t[5] * m2
    n * log(det(crossprod(E) / n)) + n * log(sum(ry^2) / n) }
  g <- function(t) { E <- cbind(m1 - t[1] * x, m2 - t[2] * x); S <- crossprod(E) / n; Si <- solve(S)
    ry <- y - t[3] * x - t[4] * m1 - t[5] * m2; R <- sum(ry^2)
    dS1 <- -(outer(c(1, 0), crossprod(x, E)[1, ]) + t(outer(c(1, 0), crossprod(x, E)[1, ]))) / n
    dS2 <- -(outer(c(0, 1), crossprod(x, E)[1, ]) + t(outer(c(0, 1), crossprod(x, E)[1, ]))) / n
    c(n * sum(Si * dS1), n * sum(Si * dS2),
      -2 * n * sum(x * ry) / R, -2 * n * sum(m1 * ry) / R, -2 * n * sum(m2 * ry) / R) }
  a1 <- sum(x * m1) / sum(x^2); a2 <- sum(x * m2) / sum(x^2)
  X <- cbind(x, m1, m2); cb <- solve(crossprod(X), crossprod(X, y))
  list(n = n, f = f, g = g, mle = c(a1 = a1, a2 = a2, cp = cb[1], b1 = cb[2], b2 = cb[3]),
       x = x, m1 = m1, m2 = m2, y = y)
}

## ---------------------------------------------------------------- constraints
## Each: eq(t) = value - q, jac(t), plus metadata for T0/T1.
con_prod <- function(idx) list(type = "prod", idx = idx,
  eq = function(t, q) prod(t[idx]) - q,
  jac = function(t, q) { j <- numeric(length(t)); for (k in idx) j[k] <- prod(t[setdiff(idx, k)]); j })
## b1 b2 = b3 b4 in the parallel model is a1*b1 - a2*b2 (theta order a1, a2, cp, b1, b2).
con_eqprod <- function() list(type = "eqprod",
  eq = function(t, q) t[1] * t[4] - t[2] * t[5] - q,
  jac = function(t, q) c(t[4], -t[5], 0, t[1], -t[2]))

## ---------------------------------------------------------------- oracles
lrn <- function(n, rss0, rss1) n * log(rss0 / rss1)
oracle_prod0 <- function(mod, kind) {
  if (kind == "two") {
    x <- mod$x; m <- mod$m; y <- mod$y
    r_a <- lrn(mod$n, sum(m^2), sum((m - sum(x * m) / mod$sxx * x)^2))
    rx <- sum((y - sum(x * y) / mod$sxx * x)^2); X <- cbind(x, m)
    r_b <- lrn(mod$n, rx, sum((y - X %*% solve(crossprod(X), crossprod(X, y)))^2))
    return(min(r_a, r_b))
  }
  if (kind == "three") return(min(vapply(1:3, function(j) {
    d <- mod$dep[[j]]; r <- mod$reg[[j]]; lrn(mod$n, sum(d^2), sum((d - sum(d * r) / sum(r^2) * r)^2)) }, 0)))
  stop("kind")
}
## Exact 1-D profile for ab = q (two-path), DESIGN.md grid + optimize().
oracle_abq <- function(mod, q) {
  x <- mod$x; m <- mod$m; y <- mod$y; n <- mod$n; sxx <- mod$sxx
  rssm <- function(a) sum((m - a * x)^2)
  rssy <- function(b) { r <- y - b * m; sum(r^2) - sum(x * r)^2 / sxx }
  P <- function(a) n * log(rssm(a)) + n * log(rssy(q / a))
  F0 <- n * log(rssm(mod$mle[["a"]])) + n * log(sum((y - cbind(x, m) %*% c(mod$mle[["cp"]], mod$mle[["b"]]))^2))
  sr <- sd(m) / sd(x); ah <- mod$mle[["a"]]; best <- Inf
  for (s in c(-1, 1)) {
    g1 <- s * exp(seq(log(1e-6 * sr), log(1e3 * sr), length.out = 20001))
    lin <- seq(ah - 8 * mod$se_a, ah + 8 * mod$se_a, length.out = 2001); lin <- lin[sign(lin) == s & lin != 0]
    a <- sort(unique(c(g1, lin))); v <- vapply(a, P, 0)
    loc <- which(diff(sign(diff(v))) > 0) + 1
    for (k in loc) {
      o <- optimize(P, sort(c(a[k - 1], a[k + 1])), tol = 1e-12); best <- min(best, o$objective, v[k])
    }
    best <- min(best, min(v))
  }
  best - F0
}

## ---------------------------------------------------------------- solvers (constrained)
TOL_EQ <- function(q) 1e-8 * max(1, abs(q))
run_constrained <- function(method, mod, con, q, starts) {
  fits <- lapply(starts, function(s0) {
    t0 <- Sys.time()
    r <- tryCatch({
      if (method %in% c("AUG", "SLSQP")) {
        o <- nloptr(s0, eval_f = function(t) list(objective = mod$f(t), gradient = mod$g(t)),
          eval_g_eq = function(t) list(constraints = con$eq(t, q), jacobian = matrix(con$jac(t, q), 1)),
          opts = if (method == "AUG") list(algorithm = "NLOPT_LD_AUGLAG", xtol_rel = 1e-10, maxeval = 20000,
                   local_opts = list(algorithm = "NLOPT_LD_LBFGS", xtol_rel = 1e-10))
                 else list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, maxeval = 20000))
        list(par = o$solution, ok = o$status > 0)
      } else {
        bnd <- 1e3 + 100 * abs(s0)
        o <- suppressWarnings(Rsolnp::csolnp(s0, fn = mod$f, gr = mod$g,
          eq_fn = function(t) con$eq(t, q), eq_b = 0, eq_jac = function(t) matrix(con$jac(t, q), 1),
          lower = s0 - bnd, upper = s0 + bnd, control = list(trace = 0)))
        list(par = o$pars, ok = o$convergence == 0)
      }
    }, error = function(e) list(par = rep(NA, length(s0)), ok = FALSE))
    fv <- if (all(is.finite(r$par))) mod$f(r$par) else NA
    viol <- if (all(is.finite(r$par))) abs(con$eq(r$par, q)) else NA
    list(f = fv, ok = isTRUE(r$ok) && is.finite(fv), viol = viol, sec = as.numeric(Sys.time() - t0, units = "secs"))
  })
  acc <- vapply(fits, function(z) z$ok && !is.na(z$viol) && z$viol <= TOL_EQ(q), TRUE)
  ## DEVIATION 2 (sensitivity only): accept any finite, feasible fit regardless of solver status.
  acc2 <- vapply(fits, function(z) is.finite(z$f) && !is.na(z$viol) && z$viol <= TOL_EQ(q), TRUE)
  list(f = if (any(acc)) min(vapply(fits[acc], `[[`, 0, "f")) else NA,
       f_relaxed = if (any(acc2)) min(vapply(fits[acc2], `[[`, 0, "f")) else NA,
       infeasible = sum(vapply(fits, function(z) isTRUE(z$ok) && !is.na(z$viol) && z$viol > TOL_EQ(q), TRUE)),
       sec = sum(vapply(fits, `[[`, 0, "sec")))
}
## T0: branch fits with nlminb (q = 0 products): fix each constrained coordinate at 0.
run_T0 <- function(mod, idx) {
  t0 <- Sys.time()
  fs <- vapply(idx, function(j) {
    free <- setdiff(seq_along(mod$mle), j); st <- mod$mle; st[j] <- 0
    full <- function(u) { t <- st; t[free] <- u; t }
    o <- nlminb(st[free], function(u) mod$f(full(u)), function(u) mod$g(full(u))[free])
    if (o$convergence == 0 && is.finite(o$objective)) o$objective else NA
  }, 0)
  fT <- if (any(!is.na(fs))) min(fs, na.rm = TRUE) else NA
  list(f = fT, f_relaxed = fT, infeasible = 0,
       sec = as.numeric(Sys.time() - t0, units = "secs"))
}
## T1 for ab = q != 0 (two-path): a = s exp(phi), b = q / a; outer grid + nlminb.
run_T1_abq <- function(mod, q) {
  t0 <- Sys.time(); best <- NA
  for (s in c(-1, 1)) {
    toT <- function(u) c(s * exp(u[1]), q / (s * exp(u[1])), u[2], u[3], u[4])
    obj <- function(u) mod$f(toT(u))
    gr <- function(u) { t <- toT(u); gg <- mod$g(t); c(gg[1] * t[1] - gg[2] * t[2], gg[3], gg[4], gg[5]) }
    ctr <- log(max(abs(mod$mle[["a"]]), mod$se_a)); grid <- seq(ctr - 8, ctr + 8, length.out = 41)
    inner <- vapply(grid, function(ph) {
      o <- nlminb(mod$mle[3:5], function(v) obj(c(ph, v)), function(v) gr(c(ph, v))[2:4]); o$objective }, 0)
    for (k in order(inner)[1:3]) {
      o <- nlminb(c(grid[k], mod$mle[3:5]), obj, gr)
      if (o$convergence == 0 && is.finite(o$objective)) best <- min(best, o$objective, na.rm = TRUE)
    }
  }
  list(f = best, f_relaxed = best, infeasible = 0, sec = as.numeric(Sys.time() - t0, units = "secs"))
}
## T1 for a1 b1 = a2 b2 (parallel): chart b2 = a1 b1 / a2, chart b1 = a2 b2 / a1, stratum a1 = a2 = 0.
run_T1_eqprod <- function(mod, nstart = 4) {
  t0 <- Sys.time(); best <- NA; m0 <- mod$mle
  chA <- function(u) c(u[1], u[2], u[3], u[4], u[1] * u[4] / u[2])          # u = (a1, a2, cp, b1)
  chB <- function(u) c(u[1], u[2], u[3], u[2] * u[4] / u[1], u[4])          # u = (a1, a2, cp, b2)
  jA <- function(u) { t <- chA(u); g <- mod$g(t); c(g[1] + g[5] * u[4] / u[2], g[2] - g[5] * u[1] * u[4] / u[2]^2, g[3], g[4] + g[5] * u[1] / u[2]) }
  jB <- function(u) { t <- chB(u); g <- mod$g(t); c(g[1] - g[4] * u[2] * u[4] / u[1]^2, g[2] + g[4] * u[4] / u[1], g[3], g[5] + g[4] * u[2] / u[1]) }
  sts <- list(c(1, 1), c(-1, 1), c(1, -1), c(-1, -1))[seq_len(nstart)]
  for (sg in sts) {
    oA <- nlminb(c(sg[1] * m0[1], sg[2] * m0[2], m0[3], m0[4]), function(u) mod$f(chA(u)), jA)
    oB <- nlminb(c(sg[1] * m0[1], sg[2] * m0[2], m0[3], m0[5]), function(u) mod$f(chB(u)), jB)
    for (o in list(oA, oB)) if (o$convergence == 0 && is.finite(o$objective)) best <- min(best, o$objective, na.rm = TRUE)
  }
  st <- function(u) c(0, 0, u)                                              # stratum: a1 = a2 = 0
  oS <- nlminb(m0[3:5], function(u) mod$f(st(u)), function(u) mod$g(st(u))[3:5])
  if (oS$convergence == 0) best <- min(best, oS$objective, na.rm = TRUE)
  list(f = best, f_relaxed = best, infeasible = 0, sec = as.numeric(Sys.time() - t0, units = "secs"))
}
## Best-known reference for a1 b1 = a2 b2: heavy multistart on both charts (200 each) + stratum.
oracle_eqprod <- function(mod, seed) {
  old <- .Random.seed; on.exit(assign(".Random.seed", old, envir = globalenv()))  # keep the data stream intact
  set.seed(seed); best <- Inf; m0 <- mod$mle
  chA <- function(u) c(u[1], u[2], u[3], u[4], u[1] * u[4] / u[2])
  chB <- function(u) c(u[1], u[2], u[3], u[2] * u[4] / u[1], u[4])
  for (k in 1:200) for (ch in list(chA, chB)) {
    o <- tryCatch(optim(rnorm(4, 0, 1), function(u) { v <- mod$f(ch(u)); if (is.finite(v)) v else 1e300 }, method = "BFGS",
                        control = list(reltol = 1e-14, maxit = 5000)), error = function(e) NULL)
    if (!is.null(o) && is.finite(o$value)) {
      p <- tryCatch(nlminb(o$par, function(u) { v <- mod$f(ch(u)); if (is.finite(v)) v else 1e300 }), error = function(e) NULL)
      best <- min(best, o$value, if (!is.null(p) && is.finite(p$objective)) p$objective else Inf) }
  }
  oS <- nlminb(m0[3:5], function(u) mod$f(c(0, 0, u))); min(best, oS$objective)
}

## ---------------------------------------------------------------- cells
cells <- list(
  list(id = 1, kind = "two", p = c(0, 0), q = 0), list(id = 2, kind = "two", p = c(0, .39), q = 0),
  list(id = 3, kind = "two", p = c(.39, 0), q = 0), list(id = 4, kind = "two", p = c(.14, 0), q = 0),
  list(id = 5, kind = "two", p = c(.3, .3), q = .09), list(id = 6, kind = "two", p = c(.3, .3), q = .02),
  list(id = 7, kind = "two", p = c(.3, .3), q = .005), list(id = 8, kind = "two", p = c(.3, .3), q = -.02),
  list(id = 9, kind = "two", p = c(.3, .3), q = -.09), list(id = 10, kind = "two", p = c(.1, .5), q = .05),
  list(id = 11, kind = "two", p = c(.1, .5), q = -.05),
  list(id = 12, kind = "three", p = c(0, 0, 0), q = 0), list(id = 13, kind = "three", p = c(.39, 0, 0), q = 0),
  list(id = 14, kind = "three", p = c(.39, .39, 0), q = 0),
  list(id = 15, kind = "parallel", p = c(0, 0, .4, .4), q = 0, n = 200))
sel <- if (cells_arg == "all") seq_along(cells) else as.integer(strsplit(cells_arg, ",")[[1]])

gen <- function(cl) {
  n <- if (is.null(cl$n)) 100 else cl$n; x <- rnorm(n)
  if (cl$kind == "two") { m <- cl$p[1] * x + rnorm(n); y <- cl$p[2] * m + rnorm(n); return(two_path(x, m, y)) }
  if (cl$kind == "three") { m1 <- cl$p[1] * x + rnorm(n); m2 <- cl$p[2] * m1 + rnorm(n); y <- cl$p[3] * m2 + rnorm(n)
    return(chain3(x, m1, m2, y)) }
  m1 <- cl$p[1] * x + rnorm(n); m2 <- cl$p[2] * x + rnorm(n); y <- cl$p[3] * m1 + cl$p[4] * m2 + rnorm(n)
  parallel(x, m1, m2, y)
}
starts_for <- function(mod, cl) {
  m0 <- mod$mle
  flips <- if (cl$kind == "two") list(c(1, 1), c(-1, 1), c(1, -1), c(-1, -1)) else
           if (cl$kind == "three") list(c(1, 1, 1), c(-1, 1, 1), c(1, -1, 1), c(1, 1, -1)) else
           list(c(1, 1), c(-1, 1), c(1, -1), c(-1, -1))
  lapply(flips, function(fl) {
    s <- m0
    if (cl$kind == "parallel") { s[1:2] <- s[1:2] * fl } else s[mod$idx] <- s[mod$idx] * fl
    if (cl$kind == "two" && cl$q != 0) s[2] <- cl$q / s[1]                 # project onto ab = q
    s })
}

rows <- list(); t_start <- Sys.time()
for (ci in sel) {
  cl <- cells[[ci]]; set.seed(BASE_SEED + cl$id)
  for (r in seq_len(reps)) {
    mod <- gen(cl); F0 <- mod$f(mod$mle)
    con <- if (cl$kind == "parallel") con_eqprod() else con_prod(mod$idx)
    ref <- if (cl$kind == "parallel") oracle_eqprod(mod, BASE_SEED * 10L + cl$id * 100000L + r) - F0 else
           if (cl$q == 0) oracle_prod0(mod, cl$kind) else oracle_abq(mod, cl$q)
    sts <- starts_for(mod, cl); one <- list()
    for (meth in methods) {
      if (meth == "CSOLNP" && !has_rsolnp) next
      res <- if (meth == "T") {
        if (cl$kind == "parallel") run_T1_eqprod(mod) else if (cl$q == 0) run_T0(mod, mod$idx) else run_T1_abq(mod, cl$q)
      } else run_constrained(meth, mod, con, cl$q, sts)
      one[[meth]] <- res
    }
    ## DEVIATION 3: for the best-known (parallel) cell the reference is the minimum over the oracle
    ## and every method's feasible value (all are feasible points, so the minimum is still an upper bound
    ## on the restricted minimum and the best known).
    if (cl$kind == "parallel") ref <- min(c(ref, vapply(one, function(z) z$f_relaxed - F0, 0)), na.rm = TRUE)
    for (meth in names(one)) {
      res <- one[[meth]]; lr <- res$f - F0; lr2 <- res$f_relaxed - F0; tol <- 1e-6 * max(1, ref)
      rows[[length(rows) + 1]] <- data.frame(cell = cl$id, rep = r, method = meth, lr = lr, lr_relaxed = lr2, oracle = ref,
        success = !is.na(lr) && abs(lr - ref) <= tol, unresolved = is.na(lr),
        success_relaxed = !is.na(lr2) && abs(lr2 - ref) <= tol, unresolved_relaxed = is.na(lr2),
        below_oracle = !is.na(lr2) && lr2 < ref - tol, infeasible_returns = res$infeasible, sec = res$sec)
    }
  }
  cat("cell", cl$id, "done", format(Sys.time() - t_start), "\n")
}
res <- do.call(rbind, rows); write.csv(res, out, row.names = FALSE)
res$wrong <- !res$success & !res$unresolved; res$wrong_relaxed <- !res$success_relaxed & !res$unresolved_relaxed
print(aggregate(cbind(success, wrong, unresolved, success_relaxed, wrong_relaxed, below_oracle, infeasible_returns, sec) ~ cell + method,
                data = res, FUN = mean), digits = 3)
