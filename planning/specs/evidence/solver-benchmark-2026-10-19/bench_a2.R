## Addendum A2 (ADDENDUM-A2-DESIGN.md, precommitted f8e108a). Claude's code.
## Usage (repo root): Rscript docs/strategy/ideation-checks/solver-benchmark/bench_a2.R <cells|all> <out_csv>
a2_args <- commandArgs(TRUE)
e <- readLines("docs/strategy/ideation-checks/solver-benchmark/bench_edge.R")
e <- sub("^edge_args <- commandArgs\\(TRUE\\)", "edge_args <- c('all', '/tmp/unused.csv')", e)
eval(parse(text = e[1:(grep("^rows <- list\\(\\); t_start", e) - 1)]))

## Run f with its own RNG stream, leaving the data stream untouched.
iso <- function(seed, f) { old <- .Random.seed; on.exit(assign(".Random.seed", old, envir = globalenv())); set.seed(seed); f() }
chart <- function(mod, q, s) {
  toT <- function(u) c(s * exp(u[1]), q / (s * exp(u[1])), u[2], u[3], u[4])
  list(obj = function(u) mod$f(toT(u)),
       gr = function(u) { t <- toT(u); gg <- mod$g(t); c(gg[1] * t[1] - gg[2] * t[2], gg[3], gg[4], gg[5]) })
}
phgrid <- function(mod, n) { ctr <- log(max(abs(mod$mle[["a"]]), mod$se_a)); seq(ctr - 8, ctr + 8, length.out = n) }
ok <- function(o) o$convergence == 0 && is.finite(o$objective)

## TW family: inner fits on the grid, then full fits from the best `nbest` points, warm or cold.
tw <- function(mod, q, ngrid = 41, nbest = 3, cold = FALSE, rnd = FALSE) {
  best <- NA
  for (s in c(-1, 1)) {
    ch <- chart(mod, q, s); grid <- phgrid(mod, ngrid)
    inn <- lapply(grid, function(ph) { st <- mod$mle[3:5]; if (rnd) st <- st + rnorm(3)
      nlminb(st, function(v) ch$obj(c(ph, v)), function(v) ch$gr(c(ph, v))[2:4]) })
    iv <- vapply(inn, `[[`, 0, "objective")
    for (k in order(iv)[seq_len(nbest)]) {
      o <- nlminb(c(grid[k], if (cold) mod$mle[3:5] else inn[[k]]$par), ch$obj, ch$gr)
      if (ok(o)) best <- min(best, o$objective, na.rm = TRUE)
    }
  }
  best
}
## NP: numerical profile g(phi) with inner fits warm-started along the grid; optimize() per bracket.
np <- function(mod, q, ngrid = 41) {
  best <- NA
  for (s in c(-1, 1)) {
    ch <- chart(mod, q, s); grid <- phgrid(mod, ngrid); par <- mod$mle[3:5]; v <- numeric(ngrid); P <- vector("list", ngrid)
    for (k in seq_along(grid)) { o <- nlminb(par, function(w) ch$obj(c(grid[k], w)), function(w) ch$gr(c(grid[k], w))[2:4])
      v[k] <- o$objective; P[[k]] <- o$par; par <- o$par }
    g_from <- function(st) function(ph) nlminb(st, function(w) ch$obj(c(ph, w)), function(w) ch$gr(c(ph, w))[2:4])$objective
    loc <- c(which(diff(sign(diff(v))) > 0) + 1, which.min(v))
    for (k in unique(loc)) {
      lo <- grid[max(1, k - 1)]; hi <- grid[min(ngrid, k + 1)]
      o <- optimize(g_from(P[[k]]), c(lo, hi), tol = 1e-10); best <- min(best, o$objective, v[k], na.rm = TRUE)
    }
  }
  best
}
## PC: closed-form profile (observed model), 201-point grid in phi + optimize() per bracket.
pc <- function(mod, q, ngrid = 201) {
  x <- mod$x; m <- mod$m; y <- mod$y; n <- mod$n; sxx <- mod$sxx
  P <- function(a) n * log(sum((m - a * x)^2) / n) + n + n * log({ r <- y - (q / a) * m; (sum(r^2) - sum(x * r)^2 / sxx) / n }) + n
  best <- Inf
  for (s in c(-1, 1)) { grid <- phgrid(mod, ngrid); v <- vapply(grid, function(ph) P(s * exp(ph)), 0)
    loc <- unique(c(which(diff(sign(diff(v))) > 0) + 1, which.min(v)))
    for (k in loc) { o <- optimize(function(ph) P(s * exp(ph)), c(grid[max(1, k - 1)], grid[min(ngrid, k + 1)]), tol = 1e-10)
      best <- min(best, o$objective, v[k]) } }
  best
}
## TWs: TW on standardized data; LR is invariant, so return the LR directly.
tws_lr <- function(mod, q) {
  sx <- sd(mod$x); sm <- sd(mod$m); sy <- sd(mod$y); m2 <- two_path(mod$x / sx, mod$m / sm, mod$y / sy)
  tw(m2, q * sx / sy) - m2$f(m2$mle)
}
aug8 <- function(mod, q) {
  sts <- c(starts_for(mod, list(kind = "two", q = q)),
           lapply(1:4, function(i) { s <- mod$mle; s[1] <- rnorm(1, mod$mle[["a"]], 3 * mod$se_a); s[2] <- q / s[1]; s }))
  run_constrained("AUG", mod, con_prod(mod$idx), q, sts)$f
}

ids <- vapply(cells, `[[`, "", "id")
sel <- if (a2_args[1] == "all") seq_along(cells) else match(strsplit(a2_args[1], ",")[[1]], ids)
cat("R", R.version$major, R.version$minor, "| nloptr", as.character(packageVersion("nloptr")), "\n")
rows <- list(); t_start <- Sys.time()
for (ci in sel) {
  cl <- cells[[ci]]; set.seed(BASE_A1 + ci)
  if (nzchar(Sys.getenv("A1_SMOKE"))) cl$R <- as.integer(Sys.getenv("A1_SMOKE"))
  for (r in seq_len(cl$R)) {
    s <- cl$make(); mod <- s$mod; q <- s$q; F0 <- unname(mod$f(mod$mle))
    orc <- if (!is.null(s$truth)) s$truth else oracle_abq(mod, q)
    sd2 <- 777000L + 1000L * ci + r
    tm <- list(); lr <- c(
      T = (function() { t0 <- Sys.time(); v <- tw(mod, q, cold = TRUE) - F0; tm$T <<- Sys.time() - t0; v })(),
      TW = (function() { t0 <- Sys.time(); v <- tw(mod, q) - F0; tm$TW <<- Sys.time() - t0; v })(),
      TW11 = tw(mod, q, 11, 1) - F0, TW21 = tw(mod, q, 21, 1) - F0,
      TWr = iso(sd2, function() tw(mod, q, rnd = TRUE)) - F0,
      NP = (function() { t0 <- Sys.time(); v <- np(mod, q) - F0; tm$NP <<- Sys.time() - t0; v })(),
      PC = pc(mod, q) - F0, TWs = tws_lr(mod, q),
      AUG8 = iso(sd2 + 1L, function() aug8(mod, q)) - F0)
    names(lr) <- c("T", "TW", "TW11", "TW21", "TWr", "NP", "PC", "TWs", "AUG8")
    ref <- orc; tol <- 1e-6 * max(1, abs(orc)); miss <- any(!is.na(lr) & lr < orc - tol)
    if (miss) { ref <- min(lr, na.rm = TRUE); tol <- 1e-6 * max(1, abs(ref)) }
    inv <- setNames(rep(NA_real_, length(lr)), names(lr))
    if (!is.null(cl$inv)) {
      d <- s$raw; iv <- cl$inv; m2 <- two_path(iv$c * d$x, iv$d * d$m, iv$e * d$y); F2 <- m2$f(m2$mle); q2 <- iv$qmap(q)
      rel <- function(a, b) abs(a - b) / max(1, abs(b))
      inv["TW"] <- rel(tw(m2, q2) - F2, lr[["TW"]]); inv["NP"] <- rel(np(m2, q2) - F2, lr[["NP"]])
      inv["PC"] <- rel(pc(m2, q2) - F2, lr[["PC"]]); inv["TWs"] <- rel(tws_lr(m2, q2), lr[["TWs"]])
    }
    rows[[length(rows) + 1]] <- data.frame(cell = cl$id, rep = r, method = names(lr), q = q, lr = unname(lr), oracle = orc,
      ref = ref, oracle_miss = miss, success = !is.na(lr) & abs(lr - ref) <= tol, unresolved = is.na(lr),
      inv_rel = unname(inv), sec = c(as.numeric(tm$T, units = "secs"), as.numeric(tm$TW, units = "secs"), NA, NA, NA,
                                     as.numeric(tm$NP, units = "secs"), NA, NA, NA))
  }
  cat("cell", cl$id, "done", format(Sys.time() - t_start), "\n")
}
out <- do.call(rbind, rows); out$wrong <- !out$success & !out$unresolved
write.csv(out, a2_args[2], row.names = FALSE)
