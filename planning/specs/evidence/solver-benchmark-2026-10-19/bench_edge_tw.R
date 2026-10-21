## Addendum A1, DEVIATION 1 (RESULTS-A1.md): T1 with a warm start ("TW").
## The precommitted T1 (run_T1_abq) starts each full nlminb fit at the grid value of phi but with the
## nuisance parameters at their unconstrained MLE. TW starts it at the inner optimum found on the grid.
## This reruns T and TW on the same datasets as bench_edge.R (same seeds; AUG is not rerun) and on the
## decision cells 5-11 of bench.R (same seeds as bench_B/bench_C), relabelled D5-D11.
## Usage (repo root): Rscript .../bench_edge_tw.R <cells|all> <out_csv>
tw_args <- commandArgs(TRUE)
e <- readLines("docs/strategy/ideation-checks/solver-benchmark/bench_edge.R")
e <- sub("^edge_args <- commandArgs\\(TRUE\\)", "edge_args <- c('all', '/tmp/unused.csv')", e)
eval(parse(text = e[1:(grep("^rows <- list\\(\\); t_start", e) - 1)]))
a1_cells <- cells
## bench.R's cells and generator (defined after its "cells" header)
b <- readLines("docs/strategy/ideation-checks/solver-benchmark/bench.R")
b <- sub("^args <- commandArgs\\(TRUE\\)", "args <- c('all', '1', '/tmp/unused.csv', 'T,AUG')", b)
eval(parse(text = b[grep("^## -+ cells", b):(grep("^rows <- list\\(\\); t_start", b) - 1)]))
b_cells <- cells; cells <- a1_cells

run_T1_warm <- function(mod, q) {
  t0 <- Sys.time(); best <- NA
  for (s in c(-1, 1)) {
    toT <- function(u) c(s * exp(u[1]), q / (s * exp(u[1])), u[2], u[3], u[4])
    obj <- function(u) mod$f(toT(u))
    gr <- function(u) { t <- toT(u); gg <- mod$g(t); c(gg[1] * t[1] - gg[2] * t[2], gg[3], gg[4], gg[5]) }
    ctr <- log(max(abs(mod$mle[["a"]]), mod$se_a)); grid <- seq(ctr - 8, ctr + 8, length.out = 41)
    inn <- lapply(grid, function(ph) nlminb(mod$mle[3:5], function(v) obj(c(ph, v)), function(v) gr(c(ph, v))[2:4]))
    iv <- vapply(inn, `[[`, 0, "objective")
    for (k in order(iv)[1:3]) {
      o <- nlminb(c(grid[k], inn[[k]]$par), obj, gr)            # warm start: phi_k with its inner optimum
      if (o$convergence == 0 && is.finite(o$objective)) best <- min(best, o$objective, na.rm = TRUE)
    }
  }
  list(f = best, f_relaxed = best, infeasible = 0, sec = as.numeric(Sys.time() - t0, units = "secs"))
}

dcells <- lapply(5:11, function(id) list(id = paste0("D", id), R = 1000, bid = id))
all_cells <- c(cells, dcells); all_ids <- vapply(all_cells, `[[`, "", "id")
sel <- if (tw_args[1] == "all") seq_along(all_cells) else match(strsplit(tw_args[1], ",")[[1]], all_ids)
cat("R", R.version$major, R.version$minor, "\n")
rows <- list(); t_start <- Sys.time()
for (ci in sel) {
  cl <- all_cells[[ci]]
  if (is.null(cl$bid)) set.seed(BASE_A1 + ci) else { bc <- b_cells[[cl$bid]]; set.seed(BASE_SEED + bc$id) }
  if (nzchar(Sys.getenv("A1_SMOKE"))) cl$R <- as.integer(Sys.getenv("A1_SMOKE"))  # smoke test only
  for (r in seq_len(cl$R)) {
    s <- if (is.null(cl$bid)) cl$make() else list(mod = gen(bc), q = bc$q)
    mod <- s$mod; q <- s$q; F0 <- mod$f(mod$mle)
    orc <- if (!is.null(s$truth)) s$truth else oracle_abq(mod, q)
    res <- list(T = run_T1_abq(mod, q), TW = run_T1_warm(mod, q))
    lrs <- vapply(res, function(z) z$f - F0, 0); ref <- orc; tol <- 1e-6 * max(1, abs(orc))
    miss <- any(!is.na(lrs) & lrs < orc - tol)
    if (miss) { ref <- min(lrs, na.rm = TRUE); tol <- 1e-6 * max(1, abs(ref)) }
    inv <- c(T = NA, TW = NA)
    if (!is.null(cl$inv)) {
      d <- s$raw; iv <- cl$inv; m2 <- two_path(iv$c * d$x, iv$d * d$m, iv$e * d$y); F2 <- m2$f(m2$mle)
      inv["T"] <- abs(run_T1_abq(m2, iv$qmap(q))$f - F2 - lrs["T"]) / max(1, abs(lrs["T"]))
      inv["TW"] <- abs(run_T1_warm(m2, iv$qmap(q))$f - F2 - lrs["TW"]) / max(1, abs(lrs["TW"]))
    }
    for (meth in c("T", "TW")) rows[[length(rows) + 1]] <- data.frame(cell = cl$id, rep = r, method = meth, q = q,
      lr = lrs[[meth]], oracle = orc, ref = ref, oracle_miss = miss,
      success = !is.na(lrs[[meth]]) && abs(lrs[[meth]] - ref) <= tol, unresolved = is.na(lrs[[meth]]),
      inv_rel = inv[[meth]], sec = res[[meth]]$sec)
  }
  cat("cell", cl$id, "done", format(Sys.time() - t_start), "\n")
}
out <- do.call(rbind, rows); out$wrong <- !out$success & !out$unresolved
write.csv(out, tw_args[2], row.names = FALSE)
