## Addendum A1 (ADDENDUM-DESIGN.md, precommitted 3572fcf): edge, general and invariance cells, T vs AUG.
## Reuses bench.R's models, oracle and solvers. Claude's code.
## Usage (from the repo root): Rscript docs/strategy/ideation-checks/solver-benchmark/bench_edge.R <cells|all> <out_csv>
edge_args <- commandArgs(TRUE)
src <- readLines("docs/strategy/ideation-checks/solver-benchmark/bench.R")
cut <- grep("^## -+ cells", src)
src <- sub("^args <- commandArgs\\(TRUE\\)", "args <- c(\"all\", \"1\", \"/tmp/unused.csv\", \"T,AUG\")", src)
eval(parse(text = src[1:(cut - 1)]))
sf <- grep("^starts_for <- ", src); eval(parse(text = src[sf:(grep("^rows <- list\\(\\); t_start", src) - 1)]))
BASE_A1 <- 20261101L

se_ab <- function(mod) {
  X <- cbind(mod$x, mod$m); ry <- mod$y - X %*% c(mod$mle[["cp"]], mod$mle[["b"]])
  se_b <- sqrt(mean(ry^2) * solve(crossprod(X))[2, 2])
  sqrt(mod$mle[["b"]]^2 * mod$se_a^2 + mod$mle[["a"]]^2 * se_b^2)
}
draw_q <- function(mod) { ab <- mod$mle[["a"]] * mod$mle[["b"]]; s <- se_ab(mod)
  repeat { q <- ab + runif(1, -4, 4) * s; if (abs(q) >= 1e-3) return(q) } }

gen_xy <- function(n, a, b, xdist = "norm", edist = "norm", sd_e = 1) {
  x <- switch(xdist, norm = rnorm(n), bern = { v <- rbinom(n, 1, .5); v - mean(v) }, exp = rexp(n) - 1)
  e <- function() switch(edist, norm = rnorm(n), t3 = rt(n, 3) / sqrt(3)) * sd_e
  m <- a * x + e(); y <- b * m + e(); list(x = x, m = m, y = y)
}

G <- function(id, n, box = .6, xdist = "norm", edist = "norm")
  list(id = id, R = 1000, make = function() { p <- runif(2, -box, box); d <- gen_xy(n, p[1], p[2], xdist, edist)
    mod <- two_path(d$x, d$m, d$y); list(mod = mod, q = draw_q(mod)) })
E <- function(id, R = 300, make) list(id = id, R = R, make = make)
fixed <- function(n, a, b, q, sd_e = 1) function() { d <- gen_xy(n, a, b, sd_e = sd_e); list(mod = two_path(d$x, d$m, d$y), q = q) }
perp <- function(q) function() { n <- 200; x <- rnorm(n); m <- rnorm(n); m <- m - sum(x * m) / sum(x^2) * x
  list(mod = two_path(x, m, .5 * m + rnorm(n)), q = q) }
I <- function(id, cdE, qmap) list(id = id, R = 200, inv = list(c = cdE[1], d = cdE[2], e = cdE[3], qmap = qmap),
  make = function() { p <- runif(2, -.6, .6); d <- gen_xy(100, p[1], p[2]); mod <- two_path(d$x, d$m, d$y)
    list(mod = mod, q = draw_q(mod), raw = d) })

cells <- list(
  G("G1", 100), G("G2", 500), G("G3", 30), G("G4", 100, xdist = "bern"), G("G5", 100, edist = "t3"),
  G("G6", 100, xdist = "exp"), G("G7", 100, box = 3),
  E("E1a", make = fixed(100, .3, .3, 1e-3)), E("E1b", make = fixed(100, .3, .3, 1e-4)),
  E("E1c", make = fixed(100, .3, .3, -1e-4)),
  E("E2a", make = perp(.05)), E("E2b", make = perp(-.05)), E("E2c", make = perp(.5)),
  E("E3a", make = fixed(10, .3, .3, .09)), E("E3b", make = fixed(6, .3, .3, .09)),
  E("E4a", make = fixed(100, 3, .3, .9)), E("E4b", make = fixed(100, 3, .3, -.9)),
  E("E5", make = function() { d <- gen_xy(100, .3, .3); mod <- two_path(d$x, d$m, d$y)
    list(mod = mod, q = mod$mle[["a"]] * mod$mle[["b"]], truth = 0) }),
  E("E6", make = fixed(100, .3, .3, 25)),
  E("E7", make = function() { d <- gen_xy(100, .3, .3, sd_e = .001); mod <- two_path(d$x, d$m, d$y)
    list(mod = mod, q = 2 * mod$mle[["a"]] * mod$mle[["b"]]) }),
  I("I1", c(1000, .01, 100), function(q) q * 100 / 1000), I("I2", c(-1, 1, 1), function(q) -q),
  I("I3", c(.001, 1, 1), function(q) q * 1000))
ids <- vapply(cells, `[[`, "", "id")
sel <- if (edge_args[1] == "all") seq_along(cells) else match(strsplit(edge_args[1], ",")[[1]], ids)
out_csv <- edge_args[2]
cat("R", R.version$major, R.version$minor, "| nloptr", as.character(packageVersion("nloptr")), "\n")

rows <- list(); t_start <- Sys.time()
for (ci in sel) {
  cl <- cells[[ci]]; set.seed(BASE_A1 + ci)
  if (nzchar(Sys.getenv("A1_SMOKE"))) cl$R <- as.integer(Sys.getenv("A1_SMOKE"))  # smoke test only
  for (r in seq_len(cl$R)) {
    s <- cl$make(); mod <- s$mod; q <- s$q; F0 <- mod$f(mod$mle)
    orc <- if (!is.null(s$truth)) s$truth else oracle_abq(mod, q)
    resT <- run_T1_abq(mod, q)
    resA <- run_constrained("AUG", mod, con_prod(mod$idx), q, starts_for(mod, list(kind = "two", q = q)))
    lrT <- resT$f - F0; ref <- orc; tol <- 1e-6 * max(1, abs(orc))
    miss <- !is.na(lrT) && lrT < orc - tol
    if (miss) { ref <- lrT; tol <- 1e-6 * max(1, abs(ref)) }
    inv_lr <- NA; inv_rel <- NA
    if (!is.null(cl$inv)) {
      d <- s$raw; iv <- cl$inv
      m2 <- two_path(iv$c * d$x, iv$d * d$m, iv$e * d$y)
      r2 <- run_T1_abq(m2, iv$qmap(q)); inv_lr <- r2$f - m2$f(m2$mle)
      inv_rel <- abs(inv_lr - lrT) / max(1, abs(lrT))
    }
    for (meth in c("T", "AUG")) {
      res <- if (meth == "T") resT else resA; lr <- res$f - F0; lr2 <- res$f_relaxed - F0
      rows[[length(rows) + 1]] <- data.frame(cell = cl$id, rep = r, method = meth, q = q, lr = lr, lr_relaxed = lr2,
        oracle = orc, ref = ref, oracle_miss = miss,
        success = !is.na(lr) && abs(lr - ref) <= tol, unresolved = is.na(lr),
        success_relaxed = !is.na(lr2) && abs(lr2 - ref) <= tol,
        inv_lr = if (meth == "T") inv_lr else NA, inv_rel = if (meth == "T") inv_rel else NA, sec = res$sec)
    }
  }
  cat("cell", cl$id, "done", format(Sys.time() - t_start), "\n")
}
res <- do.call(rbind, rows); res$wrong <- !res$success & !res$unresolved
write.csv(res, out_csv, row.names = FALSE)
