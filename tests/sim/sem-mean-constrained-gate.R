# Constrained mean-structure gate for the native SEM engine (0.9.0 S5, Checkpoint B): intercept variants of
# the nonlinear gate. Fits with free, equated and nonlinearly constrained parameters on data whose mean is far
# from zero.
#
# Cells: 2 structures (simple, serial) x n in {100, 400} x SEEDS seeds (5 by default) x location shift in
# {0, 1e3, 1e5} (icpt: 0 and 1e3 only)
#   eq     `cp == a*b` with free intercepts
#   zero   `a*b == 0` with free intercepts (the exact two-branch split)
#   icpt   `i_m == i_y`, an equality between two intercepts
# Per run, the rule (a failing run fails the gate):
#   converged    the fit is accepted and its covariance is finite
#   feasible     the constraint holds to 1e-6
#   invariant    eq and zero: the paths a, b, cp and their standard errors do not move when the data's location does
#                (estimates within 1e-5, SEs within 1e-4 relative)
#   lavaan       at shift 0 (eq, icpt): native chi-square not above lavaan's by more than 1e-4, and equal to it (1e-3)
#                with estimates within 5e-4 when lavaan reaches the same optimum (SLSQP stops along the flat
#                constraint tangent: one cell sits 1.1e-5 above lavaan, and the covariance-only fit of that cell
#                does too, so the gap is the optimizer's, not the mean structure's)
# `MUTANT=<name>` plants a defect and the gate must then exit 1: badshift (the centered route is taken even when an
# intercept is constrained), nocenter (neither the centered route nor the centered gate, so shifted data meets the
# plain-coordinate gate); noshift (the route alone) is survivable by design: the centered gate covers it.
# Run from the package root:  Rscript tests/sim/sem-mean-constrained-gate.R
# Results: tests/sim/results/sem-mean-constrained-gate-<date>.csv, one row per fit, with the invariance ratio (<= 1
# passes) and the lavaan verdict where a comparison was made (a mutant run writes to the temporary directory)

suppressMessages(pkgload::load_all(quiet = TRUE))
if (!requireNamespace("lavaan", quietly = TRUE)) {
  stop("this gate needs lavaan (Suggests): without it the lavaan parity checks would be skipped, not failed", call. = FALSE)
}
seeds <- seq_len(as.integer(Sys.getenv("SEEDS", "5")))
mutant <- Sys.getenv("MUTANT", "")
if (mutant %in% c("badshift", "noshift", "nocenter")) {
  ns <- asNamespace("medfit")
  swap <- function(name, fn) {
    unlockBinding(name, ns)
    assign(name, fn, envir = ns)
  }
  if (mutant == "badshift") swap(".sem_shift_ok", function(...) TRUE)
  if (mutant == "noshift") swap(".sem_shift_ok", function(...) FALSE)
  if (mutant == "nocenter") {
    # no centered coordinates anywhere: the plain-coordinate gate and the plain route
    swap(".sem_shift_ok", function(...) FALSE)
    swap(".sem_center_map", function(...) NULL)
  }
}

structures <- list(
  simple = list(
    syntax = "M ~ a*X + i_m*1\nY ~ b*M + cp*X + i_y*1",
    sim = function(n) {
      x <- stats::rnorm(n)
      m <- 0.5 * x + stats::rnorm(n, sd = 0.8)
      data.frame(X = x, M = m, Y = 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7))
    },
    shifted = c("M", "Y")
  ),
  serial = list(
    syntax = "M1 ~ a*X + i_m*1\nM2 ~ M1 + X\nY ~ b*M2 + cp*X + i_y*1",
    sim = function(n) {
      x <- stats::rnorm(n)
      m1 <- 0.5 * x + stats::rnorm(n, sd = 0.8)
      m2 <- 0.3 * m1 + 0.2 * x + stats::rnorm(n, sd = 0.8)
      data.frame(X = x, M1 = m1, M2 = m2, Y = 0.4 * m2 + 0.2 * x + stats::rnorm(n, sd = 0.7))
    },
    shifted = c("M1", "M2", "Y")
  )
)
problems <- c(eq = "cp == a*b", zero = "a*b == 0", icpt = "i_m == i_y")
keep <- c("a", "b", "cp")

rows <- list()
for (sname in names(structures)) {
  st <- structures[[sname]]
  for (n in c(100L, 400L)) {
    for (seed in seeds) {
      set.seed(1000L * seed + n)
      d0 <- st$sim(n)
      for (shift in c(0, 1000, 1e5)) {
        d <- d0
        d[st$shifted] <- d[st$shifted] + shift
        for (pname in names(problems)) {
          # a constraint on an intercept keeps the plain coordinates: supported to mean/sd of 1e3, not 1e5
          if (pname == "icpt" && shift > 1000) next
          syn <- paste0(st$syntax, "\n", problems[[pname]])
          fit <- tryCatch(suppressWarnings(fit_sem(syn, d)), error = function(e) NULL)
          ok <- !is.null(fit) && isTRUE(fit@converged) && !anyNA(fit@vcov)
          th <- if (ok) fit@theta else NULL
          feas <- NA_real_
          if (ok) {
            feas <- switch(pname,
                           eq = abs(th[["cp"]] - th[["a"]] * th[["b"]]),
                           zero = abs(th[["a"]] * th[["b"]]),
                           icpt = abs(th[["i_m"]] - th[["i_y"]]))
          }
          rows[[length(rows) + 1L]] <- list(structure = sname, n = n, seed = seed, shift = shift, problem = pname,
                                            ok = ok, feas = feas, fit = fit)
        }
      }
    }
  }
}

cols <- c("structure", "n", "seed", "shift", "problem", "ok", "feas")
res <- do.call(rbind, lapply(rows, function(r) data.frame(r[cols])))
inv <- numeric()
inv_row <- rep(NA_real_, length(rows)) # per-run invariance ratio (worst of estimate/1e-5 and SE/1e-4)
lav_row <- rep(NA, length(rows)) # per-run lavaan verdict, NA where no comparison was made
lav_bad <- 0L
lav_n <- 0L
for (i in seq_along(rows)) {
  r <- rows[[i]]
  if (!r$ok || r$shift == 0 || r$problem == "icpt") next
  same_cell <- function(q) {
    q$structure == r$structure && q$n == r$n && q$seed == r$seed && q$shift == 0 && q$problem == r$problem
  }
  base <- Filter(same_cell, rows)[[1L]]
  if (!base$ok) next
  est <- max(abs(r$fit@theta[keep] - base$fit@theta[keep]))
  sb <- sqrt(diag(base$fit@vcov))[keep]
  se <- max(abs(sqrt(diag(r$fit@vcov))[keep] - sb)) / max(sb)
  inv <- c(inv, max(est / 1e-5, se / 1e-4))
  inv_row[i] <- max(est / 1e-5, se / 1e-4)
  if (nzchar(Sys.getenv("DEBUG")) && max(est / 1e-5, se / 1e-4) > 1) {
    cat(r$structure, r$n, r$seed, r$problem, "est", est, "se", se, "\n")
  }
}
{
  for (ri in seq_along(rows)) {
    r <- rows[[ri]]
    if (!r$ok || r$shift != 0 || r$problem == "zero") next
    st <- structures[[r$structure]]
    syn <- paste0(st$syntax, "\n", problems[[r$problem]])
    d <- NULL
    set.seed(1000L * r$seed + r$n)
    d <- st$sim(r$n)
    ref <- tryCatch(suppressWarnings(lavaan::sem(syn, d, meanstructure = TRUE, fixed.x = FALSE)),
                    error = function(e) NULL)
    if (is.null(ref) || !lavaan::lavInspect(ref, "converged")) next
    lav_n <- lav_n + 1L
    chi <- unname(lavaan::fitMeasures(ref, "chisq"))
    nat <- r$fit@f * r$fit@n_obs
    same <- abs(nat - chi) < 1e-3
    est_ok <- !same || max(abs(r$fit@theta[keep] - lavaan::coef(ref)[keep]), na.rm = TRUE) < 5e-4
    lav_row[ri] <- !(nat > chi + 1e-4 || !est_ok)
    if (nat > chi + 1e-4 || !est_ok) {
      lav_bad <- lav_bad + 1L
      if (nzchar(Sys.getenv("DEBUG"))) {
        cat("lavaan", r$structure, r$n, r$seed, r$problem, "native", nat, "lav", chi, "\n")
      }
    }
  }
}
if (nzchar(Sys.getenv("DEBUG"))) {
  print(res[!res$ok, ])
  print(round(sort(inv, decreasing = TRUE)[1:5], 2))
}
res$invariance <- inv_row
res$lavaan_ok <- lav_row
out_dir <- if (nzchar(mutant)) tempdir() else "tests/sim/results"
dir.create(out_dir, showWarnings = FALSE)
utils::write.csv(res, file.path(out_dir, sprintf("sem-mean-constrained-gate-%s.csv", Sys.Date())), row.names = FALSE)
cat(sprintf(paste0("runs: %d; converged %d; feasible <= 1e-6: %d; invariance pairs %d (worst ratio %.3g); ",
                   "lavaan runs %d, bad %d\n"),
            nrow(res), sum(res$ok), sum(res$feas <= 1e-6, na.rm = TRUE), length(inv),
            if (length(inv)) max(inv) else NA_real_, lav_n, lav_bad))
checks <- c(
  cells = nrow(res) == 2L * 2L * length(seeds) * (3L * 2L + 2L),
  converged = all(res$ok),
  feasible = all(res$feas <= 1e-6, na.rm = TRUE),
  invariant = length(inv) > 0L && all(inv <= 1),
  lavaan = lav_n > 0L && lav_bad == 0L
)
cat("\n")
for (nm in names(checks)) cat(sprintf("%-12s %s\n", nm, if (isTRUE(checks[[nm]])) "PASS" else "FAIL"))
if (!all(checks)) {
  cat("\nRULE NOT MET\n")
  quit(status = 1)
}
cat("\nRULE MET\n")
