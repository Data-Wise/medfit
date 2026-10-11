# Reliability study and gate calibration for the native SEM fit driver (plan S6, G4, G5, G2).
#
# Grid: four unconstrained structures x n in {50, 200, 1000} x REPS datasets (default 100) x data
# scales {0.01, 1, 100, 1000} x solver {SLSQP, L-BFGS} x start {default, random} x preconditioning
# {off, on: the solver works in each parameter's natural units} x mode {single start (no gate, no retry),
# Q9 retry (the gate with up to 4 perturbed retries)}.
# A fit matches when its implied covariance is within 1e-5 (relative to the largest entry) of lavaan's.
# Each mismatch is classified by the discrepancy: native above lavaan's by more than 1e-8 (native
# stalled), below (lavaan on a worse local solution), or equal with different estimates (flat).
# Every single-start run also records status, the Newton decrement and the Jacobi-scaled smallest Hessian
# eigenvalue, the inputs of the threshold calibration. Run from the package root:
#   REPS=100 Rscript tests/sim/sem-reliability.R        (REPS=5 for a quick check)
# Results: tests/sim/results/sem-reliability-<date>.csv.gz (one row per fit)

suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/testthat/helper-sem.R")
REPS <- as.integer(Sys.getenv("REPS", "100"))
SCALES <- c(0.01, 1, 100, 1000)
ALGOS <- c(SLSQP = "NLOPT_LD_SLSQP", LBFGS = "NLOPT_LD_LBFGS")
norm_pair <- function(x) {
  vapply(strsplit(x, "~~", fixed = TRUE), function(p) if (length(p) == 2) paste(sort(p), collapse = "~~") else p, character(1))
}

random_start <- function(base, ram, smp) {
  u <- .sem_step_floor(ram, smp)
  for (try in 1:20) {
    cand <- base + stats::runif(length(base), -0.5, 0.5) * u
    if (.sem_start_valid(cand, ram)) return(cand)
  }
  base
}

classify <- function(sigma_n, f_n, sigma_l, f_l) {
  ok <- max(abs(sigma_n - sigma_l)) / max(abs(sigma_l)) < 1e-5
  if (ok) return("match")
  if (f_n - f_l > 1e-8) "native_stalled" else if (f_n - f_l < -1e-8) "lavaan_worse" else "flat"
}

one <- function(i) {
  g <- grid[i, ]
  mod <- sem_models()[[g$structure]]
  seed <- 100000L * g$rep + g$n
  d0 <- sem_sim(mod, g$n, seed)
  rows <- list()
  # The reference is lavaan at scale 1, transported exactly to each scale (the discrepancy is scale invariant, so the
  # optimum at scale s is the transported optimum). lavaan itself stalls at large data units (x1000 in two structures),
  # so fitting it separately at each scale would make the reference the weaker engine.
  fit1 <- tryCatch(suppressWarnings(lavaan::sem(sem_lavaan_text(g$structure), d0, fixed.x = FALSE)), error = function(e) NULL)
  if (is.null(fit1) || !isTRUE(lavaan::lavInspect(fit1, "converged"))) return(NULL)
  lav <- lavaan::coef(fit1)
  pos <- match(norm_pair(sem_lavaan_names(mod$ram$par_names, mod$loadings)), norm_pair(names(lav)))
  if (anyNA(pos)) return(NULL)
  theta_1 <- stats::setNames(unname(lav)[pos], mod$ram$par_names)
  for (s in SCALES) {
    d <- d0 * s
    smp <- .sem_sample(d, mod$ram)
    theta_l <- sem_transport(theta_1, s)
    sigma_l <- .sem_implied(mod$ram, theta_l)
    f_l <- .sem_fml(theta_l, mod$ram, smp)
    base <- .sem_default_start(mod$ram, smp)
    set.seed(seed + 7L)
    starts <- list(default = base, random = random_start(base, mod$ram, smp))
    for (an in names(ALGOS)) {
      opts <- list(algorithm = ALGOS[[an]], xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = 10000L)
      for (sn in names(starts)) for (pc in c(FALSE, TRUE)) {
        base_row <- data.frame(g, scale = s, algo = an, start = sn, precond = pc, stringsAsFactors = FALSE)
        res <- tryCatch(.sem_solve_one(starts[[sn]], mod$ram, smp, rep(-Inf, mod$ram$q), rep(Inf, mod$ram$q), opts, pc), error = function(e) NULL)
        if (is.null(res)) {
          rows[[length(rows) + 1L]] <- cbind(base_row, mode = "single", class = "error", status = NA, f_native = NA, f_lavaan = f_l,
                                             decrement = NA, min_eig = NA, gate_accepts = NA, retries = NA)
        } else {
          sg <- tryCatch(.sem_implied(mod$ram, res$solution), error = function(e) NULL)
          gate <- .sem_gate(res$solution, res$status, mod$ram, smp, rep(-Inf, mod$ram$q), rep(Inf, mod$ram$q))
          cl <- if (is.null(sg)) "error" else classify(sg, .sem_fml(res$solution, mod$ram, smp), sigma_l, f_l)
          rows[[length(rows) + 1L]] <- cbind(base_row, mode = "single", class = cl, status = res$status,
                                             f_native = res$objective, f_lavaan = f_l, decrement = gate$decrement,
                                             min_eig = gate$min_eig, gate_accepts = gate$accepted, retries = NA)
        }
        rt <- tryCatch(suppressWarnings(.sem_optimize(mod$ram, smp, starts[[sn]], n_starts = 5L,
                                                      control = list(algorithm = ALGOS[[an]]), precondition = pc)),
                       error = function(e) NULL)
        if (is.null(rt)) {
          rows[[length(rows) + 1L]] <- cbind(base_row, mode = "retry", class = "no_start_converged", status = NA, f_native = NA,
                                             f_lavaan = f_l, decrement = NA, min_eig = NA, gate_accepts = FALSE, retries = NA)
        } else {
          cl <- classify(.sem_implied(mod$ram, rt$theta), rt$f, sigma_l, f_l)
          rows[[length(rows) + 1L]] <- cbind(base_row, mode = "retry", class = cl, status = rt$status, f_native = rt$f, f_lavaan = f_l,
                                             decrement = rt$decrement, min_eig = NA, gate_accepts = TRUE, retries = rt$retries)
        }
      }
    }
  }
  if (length(rows)) do.call(rbind, rows) else NULL
}

grid <- expand.grid(structure = names(sem_models()), n = c(50, 200, 1000), rep = seq_len(REPS), stringsAsFactors = FALSE)
cores <- max(1L, parallel::detectCores() - 1L)
safe_one <- function(i) {
  withCallingHandlers(
    tryCatch(one(i), error = function(e) structure(paste0("task ", i, ": ", conditionMessage(e), " | ", trace), class = "worker_error")),
    error = function(e) trace <<- paste(utils::tail(vapply(sys.calls(), function(cl) substr(paste(deparse(cl)[1], collapse = ""), 1, 60), ""), 6), collapse = " > ")
  )
}
trace <- ""
out <- parallel::mclapply(seq_len(nrow(grid)), safe_one, mc.cores = cores)
bad <- vapply(out, function(x) inherits(x, "worker_error"), logical(1))
if (any(bad)) {
  cat(sprintf("%d of %d dataset tasks failed; first messages:\n", sum(bad), length(out)))
  print(utils::head(unique(unlist(out[bad])), 3))
}
res <- do.call(rbind, out[!bad])
res$match <- res$class == "match"

cat(sprintf("\n%d datasets, %d fits recorded (datasets where lavaan did not converge at scale 1 skipped)\n", nrow(grid), nrow(res)))
cat("\nReliability (fraction matching lavaan), by solver, start, mode and scale:\n")
rel <- stats::aggregate(match ~ algo + start + precond + mode + scale, res, mean)
print(rel, digits = 3)
cat("\nWorst cell (structure x n) per solver, start and mode:\n")
cellrel <- stats::aggregate(match ~ algo + start + precond + mode + structure + n, res, mean)
print(do.call(rbind, lapply(split(cellrel, list(cellrel$algo, cellrel$start, cellrel$precond, cellrel$mode), drop = TRUE), function(x) x[which.min(x$match), ])), digits = 3)
cat("\nMismatch classes (single start):\n")
print(table(res$class[res$mode == "single"], res$algo[res$mode == "single"], res$precond[res$mode == "single"]))
cat("\nMismatch classes (Q9 retry):\n")
print(table(res$class[res$mode == "retry"], res$algo[res$mode == "retry"], res$precond[res$mode == "retry"]))

cat("\nCalibration of the Newton-decrement threshold (single-start runs with a success status):\n")
sg <- res[res$mode == "single" & res$status %in% c(1, 3, 4), ]
sg$grp <- paste(sg$scale, sg$algo, sg$precond)
cal <- do.call(rbind, lapply(split(sg, sg$grp), function(x) {
  conv <- x$decrement[x$match & !is.na(x$decrement)]
  stall <- x$decrement[x$class == "native_stalled" & !is.na(x$decrement)]
  data.frame(scale = x$scale[1], algo = x$algo[1], precond = x$precond[1], n_conv = length(conv), max_conv = if (length(conv)) max(conv) else NA_real_,
             n_stall = length(stall), min_stall = if (length(stall)) min(stall, na.rm = TRUE) else NA_real_)
}))
cal$ratio <- cal$min_stall / cal$max_conv
print(cal, digits = 3)
cat("\nJacobi-scaled smallest Hessian eigenvalue: converged quantiles and stalled/flat minimum\n")
print(stats::quantile(sg$min_eig[sg$match], c(0, .001, .01, .05), na.rm = TRUE), digits = 3)
print(summary(sg$min_eig[!sg$match & !is.na(sg$min_eig)]), digits = 3)

ver <- sapply(c("lavaan", "nloptr", "MASS"), function(p) as.character(utils::packageVersion(p)))
res$versions <- paste(names(ver), ver, collapse = "; ")
dir.create("tests/sim/results", showWarnings = FALSE)
utils::write.csv(res, gzfile(sprintf("tests/sim/results/sem-reliability-%s.csv.gz", Sys.Date())), row.names = FALSE)
