# Constrained cell of the SE gate for the native SEM engine (plan S15, G3) and the stationarity
# re-check (G2, stationarity half).
#
# Cells: `a == b` against OpenMx with one shared label, and `a == 0` against the OpenMx model with
# the path fixed at zero; n in {50, 200, 1000} x 20 seeds. Data are drawn from the oracle model, so the
# constraint holds in truth. The oracle is OpenMx on S * n / (n - 1) with numObs = n. Reports the maximum
# relative SE difference per cell against the frozen K10 tolerance of 1e-3.
#
# Stationarity re-check: the Q14 decrement of every accepted start, every start the gate rejected, and
# deliberately truncated runs (maxeval 3, 6, 10) that stop far from the optimum. The rule is that the
# S6 threshold sits at least 10x above the largest converged decrement and at least 10x below the
# smallest stall. This script reports the table; it never changes the constant.
# Run from the package root:  Rscript tests/sim/sem-constrained-gate.R
# Results: tests/sim/results/sem-constrained-gate-<date>.csv and -stationarity-<date>.csv

suppressMessages({
  pkgload::load_all(quiet = TRUE)
  library(OpenMx)
})
source("tests/testthat/helper-sem.R")
mxOption(NULL, "Number of Threads", 1)

base <- "M ~ a*X\nY ~ b*M + cp*X"
cells <- list(
  equal = list(extra = "a == b", oracle = sem_model_equal_paths(), ours = c("a", "b"), omx = "a"),
  zero = list(extra = "a == 0", oracle = sem_model_zero_path(), ours = character(), omx = NULL)
)
grid <- expand.grid(cell = names(cells), n = c(50, 200, 1000), seed = 1:20, stringsAsFactors = FALSE)

setup <- function(text, d) {
  parsed <- .sem_parse(text)
  conv <- .sem_to_ram(.sem_complete(parsed$parameters))
  smp <- .sem_sample(d[, conv$ram$obs], conv$ram)
  list(ram = conv$ram, smp = smp, cons = .sem_constraint_rows(parsed$constraints, conv$ram),
       start = .sem_default_start(conv$ram, smp), q = conv$ram$q)
}

one <- function(i) {
  g <- grid[i, ]
  cl <- cells[[g$cell]]
  mod <- cl$oracle
  d <- sem_sim(mod, g$n, 1000L * g$seed + g$n)
  row <- data.frame(g, native_ok = FALSE, omx_ok = FALSE, est_gap = NA_real_, rel_se = NA_real_)
  fit <- tryCatch(
    suppressWarnings(.sem_fit_syntax(paste0(base, "\n", cl$extra), d, "observed")),
    error = function(e) NULL
  )
  att <- NULL
  if (!is.null(fit)) {
    row$native_ok <- TRUE
    att <- do.call(rbind, lapply(seq_along(fit$attempts), function(k) {
      a <- fit$attempts[[k]]
      dec <- if (is.null(a$decrement)) NA_real_ else a$decrement
      data.frame(g, kind = if (isTRUE(a$accepted)) "accepted" else "rejected", dec = dec)
    }))
    smp <- .sem_sample(d, mod$ram)
    om <- tryCatch(sem_openmx(mod, smp), error = function(e) NULL)
    if (!is.null(om) && om$output$status$code <= 1) {
      row$omx_ok <- TRUE
      sm <- summary(om)$parameters
      nm <- mod$ram$par_names[as.integer(sub("^p", "", sm$name))]
      se_o <- stats::setNames(sm[["Std.Error"]], nm)
      est_o <- stats::setNames(sm$Estimate, nm)
      se_n <- sqrt(diag(fit$vcov))
      # native names a, b, cp; oracle names a, `Y ~ X`; map them
      map <- c(cp = "Y ~ X", `X ~~ X` = "X ~~ X", `M ~~ M` = "M ~~ M", `Y ~~ Y` = "Y ~~ Y")
      pairs <- if (g$cell == "equal") c(map, a = "a", b = "a") else c(map, b = "Y ~ M")
      row$rel_se <- max(abs(se_n[names(pairs)] / se_o[unname(pairs)] - 1))
      row$est_gap <- max(abs(fit$theta[names(pairs)] - est_o[unname(pairs)]))
    }
  }
  # truncated runs: stalls far from the optimum
  st <- NULL
  if (!is.null(fit) && g$n == 200) {
    s <- setup(paste0(base, "\n", cl$extra), d)
    lb <- rep(-Inf, s$q)
    ub <- rep(Inf, s$q)
    u <- .sem_step_floor(s$ram, s$smp)
    st <- do.call(rbind, lapply(c(3L, 6L, 10L), function(k) {
      opts <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = k)
      res <- tryCatch(.sem_solve_one(s$start, s$ram, s$smp, lb, ub, opts, cons = s$cons), error = function(e) NULL)
      if (is.null(res)) return(NULL)
      gate <- .sem_gate(res$solution, 4L, s$ram, s$smp, lb, ub, s$cons)
      dist <- max(abs(res$solution - fit$theta[s$ram$par_names]) / u)
      data.frame(g, kind = "truncated", maxeval = k, dec = gate$decrement, dist = dist)
    }))
  }
  list(row = row, att = att, st = st)
}
out <- parallel::mclapply(seq_len(nrow(grid)), one, mc.cores = max(1L, parallel::detectCores() - 1L))
res <- do.call(rbind, lapply(out, `[[`, "row"))
att <- do.call(rbind, lapply(out, `[[`, "att"))
st <- do.call(rbind, lapply(out, `[[`, "st"))

cat("SE gate, constrained cells (maximum relative SE difference against OpenMx):\n")
print(do.call(rbind, lapply(split(res, list(res$cell, res$n), drop = TRUE), function(df) {
  data.frame(runs = nrow(df), failed = sum(!df$native_ok | !df$omx_ok), max_rel_se = max(df$rel_se, na.rm = TRUE),
             max_est_gap = max(df$est_gap, na.rm = TRUE))
})), digits = 3)
worst <- max(res$rel_se, na.rm = TRUE)
cat(sprintf("\nWorst relative SE difference %.3e against the frozen tolerance 1e-3: %s\n", worst,
            if (worst <= 1e-3) "PASS" else "FAIL"))

cat("\nStationarity re-check (Q14 decrement):\n")
acc <- att$dec[att$kind == "accepted"]
rej <- att$dec[att$kind == "rejected" & is.finite(att$dec)]
far <- st[is.finite(st$dec) & st$dist > 1e-2, ]
cat(sprintf("accepted starts: %d, largest decrement %.3e\n", length(acc), max(acc, na.rm = TRUE)))
cat(sprintf("rejected-by-gate starts with a finite decrement: %d, smallest %s\n", length(rej),
            if (length(rej)) format(min(rej), digits = 3) else "none"))
cat(sprintf("truncated runs more than 1e-2 (natural units) from the optimum: %d, smallest decrement %s\n",
            nrow(far), if (nrow(far)) format(min(far$dec), digits = 3) else "none"))
thr <- .sem_stat_tol
lo <- max(acc, na.rm = TRUE)
hi <- min(c(rej, far$dec), Inf)
cat(sprintf("threshold %.0e: %.1fx above the largest converged value, %s below the smallest stall -> %s\n",
            thr, thr / lo, if (is.finite(hi)) sprintf("%.1fx", hi / thr) else "no stall observed",
            if (thr >= 10 * lo && thr <= hi / 10) "RULE MET" else "RULE NOT MET: ask the author, keep the constant"))

ver <- sapply(c("OpenMx", "nloptr"), function(p) as.character(utils::packageVersion(p)))
res$versions <- paste(names(ver), ver, collapse = "; ")
dir.create("tests/sim/results", showWarnings = FALSE)
utils::write.csv(res, sprintf("tests/sim/results/sem-constrained-gate-%s.csv", Sys.Date()), row.names = FALSE)
keep <- c("cell", "n", "seed", "kind", "dec")
utils::write.csv(rbind(att[, keep], st[, keep]),
                 sprintf("tests/sim/results/sem-constrained-stationarity-%s.csv", Sys.Date()), row.names = FALSE)
