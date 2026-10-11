# Fixture 1 (S1 finding Q14): does the stationarity measure depend on the units of the data?
#
# Part A re-runs the surviving 04b stationarity table (three-variable mediation model, constraint a*b == 0,
# the 60 random user starts and the stalled start (0,0,0,.5,.5), seeds as in 04b) and repeats it with every
# variable multiplied by 0.01, 1 and 100. It compares the 04b measure (max |gradient + J' lambda| / max(1, max |gradient|))
# with the scale-free measure 0.7.0 uses, the Newton decrement on the null space of the constraint Jacobian.
# Part B runs the 0.7.0 gate itself (.sem_fit_syntax and .sem_gate, so the code in R/ is what is tested) on the
# linear cells the 04b real runs used (a + b == 0.2, a + b < 0.2, a + b > 0.2) at the same three scales,
# plus truncated runs that stop far from the optimum.
#
# Exploratory evidence, not package code. Run from this directory: Rscript 01-stationarity-units.R
# Exits nonzero if any ASSERT line fails. Seeds: data set.seed(3); user starts set.seed(11); multi-start perturbations seed i.
suppressMessages({
  library(nloptr)
  source("../native-sem-2026-10-08/common.R")
})
failures <- 0L
assert <- function(label, ok) {
  cat(sprintf("ASSERT %-4s %s\n", if (isTRUE(ok)) "PASS" else "FAIL", label))
  if (!isTRUE(ok)) failures <<- failures + 1L
}
# 0.001 is left out on purpose: common.R's fml() rejects an implied covariance whose smallest eigenvalue is <= 1e-10 (an absolute
# test), which at that scale rejects every start. That is the exploratory engine's own unit dependence, not the stationarity measure's.
scales <- c(0.01, 1, 100)

# ---- Part A: the 04b table at three data scales ----------------------------------------------------------
opts <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-14, maxeval = 2000)
set.seed(3)
n <- 300
X0 <- rnorm(n)
M0 <- .3 * X0 + rnorm(n)
Y0 <- .3 * M0 + .1 * X0 + rnorm(n)
set.seed(11)
U <- lapply(1:60, function(i) c(runif(2, -1, 1), runif(1, -.5, .5), runif(2, .3, 2)))
starts <- c(list(c(0, 0, 0, .5, .5)), U)
BEST <- NULL

one_scale <- function(sc) {
  S <- cov(data.frame(X = X0, M = M0, Y = Y0) * sc) * (n - 1) / n
  mod <- mk(c("X", "M", "Y"), c("X", "M", "Y"),
    list(to = c("M", "Y", "Y"), from = c("X", "M", "X"), lbl = c("a", "b", "cp"), val = rep(NA, 3)),
    list(a = c("X", "M", "Y"), b = c("X", "M", "Y"), lbl = c("vx", "vm", "vy"), val = c(S[1, 1], NA, NA))
  )
  f <- function(x) fml(mod, x, S)
  g <- function(x) gml(mod, x, S)
  hp <- function(x) x[1] * x[2]
  hpj <- function(x) c(x[2], x[1], 0, 0, 0)
  hess <- function(x) {
    e <- 1e-5
    H <- sapply(seq_along(x), function(k) {
      d <- replace(numeric(length(x)), k, e * max(abs(x[k]), 1))
      (g(x + d) - g(x - d)) / (2 * d[k])
    })
    (H + t(H)) / 2
  }
  rows <- lapply(seq_along(starts), function(i) {
    # the same start in the data's units: variances (the last two parameters) scale with the square of the data scale
    st <- starts[[i]] * c(1, 1, 1, sc^2, sc^2)
    o <- suppressWarnings(try(nloptr(st, f, g, eval_g_eq = hp, eval_jac_g_eq = hpj, opts = opts), silent = TRUE))
    if (inherits(o, "try-error")) {
      return(NULL)
    }
    x <- o$solution
    gx <- g(x)
    J <- matrix(hpj(x), nrow = 1)
    lam <- tryCatch(qr.solve(t(J), -gx), error = function(e) 0)
    old <- max(abs(gx + as.vector(t(J) %*% lam))) / max(1, max(abs(gx)))
    # scale-free: Newton decrement on the null space of J, in Jacobi-scaled coordinates
    sv <- svd(J, nu = 0, nv = 5)
    Z <- sv$v[, -1, drop = FALSE]
    Hr <- crossprod(Z, hess(x) %*% Z)
    gr <- as.vector(crossprod(Z, gx))
    dg <- diag(Hr)
    dec <- if (all(dg > 0)) {
      d <- 1 / sqrt(dg)
      sqrt(sum((gr * d) * solve(Hr * outer(d, d), gr * d)))
    } else {
      NA_real_
    }
    data.frame(scale = sc, start = i - 1L, status = o$status, F = o$objective, resid = abs(hp(x)), old_kkt = old, decrement = dec)
  })
  do.call(rbind, rows)
}
res <- do.call(rbind, lapply(scales, one_scale))
# F is a discrepancy of the covariance matrix, invariant to the common scale only up to the variance parameters; the class
# labels therefore use F at scale 1, as 04b did (BEST = 0.095154 is the better a = 0 solution).
BEST <- 0.095154
res$class <- ifelse(is.na(res$F), "error", ifelse(res$F < BEST + 1e-6, "better (a = 0)", ifelse(res$F < 0.107, "other local (b = 0)", "stalled/poor")))
cat("== Part A: 04b table, a*b == 0, 61 starts (the stalled start plus 60 random) at three data scales ==\n")
tab <- do.call(rbind, lapply(split(res, list(res$scale, res$class), drop = TRUE), function(d) {
  data.frame(scale = d$scale[1], class = d$class[1], n = nrow(d),
    old_min = signif(min(d$old_kkt, na.rm = TRUE), 3), old_max = signif(max(d$old_kkt, na.rm = TRUE), 3),
    dec_min = signif(min(d$decrement, na.rm = TRUE), 3), dec_max = signif(max(d$decrement, na.rm = TRUE), 3))
}))
rownames(tab) <- NULL
print(tab[order(tab$class, tab$scale), ], row.names = FALSE)
utils::write.csv(res, "results/01-stationarity-units-partA.csv", row.names = FALSE)

good <- res$class %in% c("better (a = 0)", "other local (b = 0)")
stall <- res$class == "stalled/poor"
cat(sprintf("\nconverged solutions: %g per scale on average; stalled/poor: %g per scale on average\n", sum(good) / length(scales), sum(stall) / length(scales)))
# Oracle 1: the scale-free decrement separates converged from stalled by at least 10x at every scale, around 1e-3.
for (sc in scales) {
  dg <- res$decrement[res$scale == sc & good]
  ds <- res$decrement[res$scale == sc & stall]
  hi_ok <- if (any(is.finite(dg))) max(dg[is.finite(dg)]) else NA_real_
  lo_st <- if (any(is.finite(ds))) min(ds[is.finite(ds)]) else NA_real_
  assert(sprintf("scale %-5g converged decrement max %.2e is >= 10x below 1e-3, stalled min %s is >= 10x above",
                 sc, hi_ok, format(lo_st, digits = 3)), isTRUE(hi_ok <= 1e-4) && isTRUE(lo_st >= 1e-2))
}
# Oracle 2 (the Q14 finding): across data scales, the largest converged value of the 04b measure moves by orders of
# magnitude, while the largest converged decrement stays within a factor of 10.
cmax <- function(col) vapply(scales, function(sc) max(res[[col]][res$scale == sc & good], na.rm = TRUE), 0)
old_max <- cmax("old_kkt")
dec_max <- cmax("decrement")
cat(sprintf("converged maximum by scale (%s): 04b measure %s | decrement %s\n", paste(scales, collapse = ", "),
            paste(format(old_max, digits = 3), collapse = " "), paste(format(dec_max, digits = 3), collapse = " ")))
assert(sprintf("04b measure depends on units: converged maximum moves %.1e-fold across scales", max(old_max) / min(old_max)),
       max(old_max) / min(old_max) >= 100)
assert(sprintf("the decrement does not: converged maximum moves %.1f-fold across scales", max(dec_max) / min(dec_max)),
       max(dec_max) / min(dec_max) <= 10)
# Report: the 04b measure's separation from the stalled start at each scale.
for (sc in scales) {
  o_good <- max(res$old_kkt[res$scale == sc & good], na.rm = TRUE)
  o_stall <- min(res$old_kkt[res$scale == sc & stall], na.rm = TRUE)
  cat(sprintf("04b measure at scale %-6g: converged max %.2e, stalled min %s, ratio %s; threshold 1e-3 %s\n", sc, o_good, format(o_stall, digits = 3),
              format(o_stall / o_good, digits = 3), if (o_good > 1e-3) "REJECTS a converged solution" else "accepts every converged solution"))
}

# ---- Part B: the 0.7.0 gate on the real package ----------------------------------------------------------
suppressMessages(pkgload::load_all("../../../..", quiet = TRUE))
cat("\n== Part B: 0.7.0 gate (.sem_fit_syntax, .sem_gate) on the 04b linear cells ==\n")
base <- "M ~ a*X\nY ~ b*M + cp*X"
cells <- c(eq = "a + b == 0.2", lt = "a + b < 0.2", gt = "a + b > 0.2", none = "")
rowsB <- list()
for (sc in scales) {
  d <- data.frame(X = X0, M = M0, Y = Y0) * sc
  for (cn in names(cells)) {
    txt <- if (nzchar(cells[[cn]])) paste0(base, "\n", cells[[cn]]) else base
    fit <- tryCatch(suppressWarnings(.sem_fit_syntax(txt, d, "observed")), error = function(e) NULL)
    if (is.null(fit)) {
      rowsB[[length(rowsB) + 1L]] <- data.frame(scale = sc, cell = cn, kind = "fit_error", maxeval = NA, a = NA, b = NA, decrement = NA, sign_check = NA)
      next
    }
    rowsB[[length(rowsB) + 1L]] <- data.frame(scale = sc, cell = cn, kind = "fit", maxeval = NA, a = unname(fit$theta["a"]),
      b = unname(fit$theta["b"]), decrement = fit$decrement, sign_check = fit$sign_check)
    parsed <- .sem_parse(txt)
    conv <- .sem_to_ram(.sem_complete(parsed$parameters))
    smp <- .sem_sample(d[, conv$ram$obs], conv$ram)
    cons <- .sem_constraint_rows(parsed$constraints, conv$ram)
    st <- .sem_default_start(conv$ram, smp)
    lb <- rep(-Inf, conv$ram$q)
    ub <- rep(Inf, conv$ram$q)
    for (k in c(3L, 6L, 10L)) {
      op <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = k)
      r <- tryCatch(.sem_solve_one(st, conv$ram, smp, lb, ub, op, cons = cons), error = function(e) NULL)
      if (is.null(r)) next
      gate <- .sem_gate(r$solution, 4L, conv$ram, smp, lb, ub, cons)
      far <- max(abs(r$solution - fit$theta[conv$ram$par_names]) / .sem_step_floor(conv$ram, smp))
      rowsB[[length(rowsB) + 1L]] <- data.frame(scale = sc, cell = cn, kind = if (far > 1e-2) "truncated_far" else "truncated_near",
        maxeval = k, a = NA, b = NA, decrement = gate$decrement, sign_check = NA_character_)
    }
  }
}
B <- do.call(rbind, rowsB)
utils::write.csv(B, "results/01-stationarity-units-partB.csv", row.names = FALSE)
print(do.call(rbind, lapply(split(B, list(B$cell, B$scale, B$kind), drop = TRUE), function(d) {
  data.frame(cell = d$cell[1], scale = d$scale[1], kind = d$kind[1], n = nrow(d),
    dec_min = signif(min(d$decrement, na.rm = TRUE), 3), dec_max = signif(max(d$decrement, na.rm = TRUE), 3))
})), row.names = FALSE)
fits <- B[B$kind == "fit", ]
assert("every 0.7.0 fit is accepted (no fit_error) in every cell and scale", !any(B$kind == "fit_error") && nrow(fits) == length(cells) * length(scales))
assert(sprintf("0.7.0 fit decrements are all <= 1e-6 (max %.2e), at every scale", max(fits$decrement)), max(fits$decrement) <= 1e-6)
for (cn in names(cells)) {
  d <- fits[fits$cell == cn, ]
  assert(sprintf("cell %-4s: path estimates a, b are identical across data scales (spread %.1e)", cn, max(diff(range(d$a)), diff(range(d$b)))),
         max(diff(range(d$a)), diff(range(d$b))) <= 1e-6)
}
far <- B[B$kind == "truncated_far", ]
assert(sprintf("truncated runs far from the optimum (%d) have decrement >= 1e-2 (min %.2e): 10x above the 1e-3 threshold", nrow(far), min(far$decrement, na.rm = TRUE)),
       nrow(far) > 0 && min(far$decrement, na.rm = TRUE) >= 1e-2)

ver <- sapply(c("nloptr"), function(p) as.character(utils::packageVersion(p)))
cat(sprintf("\nR %s; nloptr %s; medfit %s\n", getRversion(), ver, utils::packageVersion("medfit")))
if (failures > 0L) {
  cat(sprintf("\nFAILED: %d assertion(s)\n", failures))
  quit(status = 1)
}
cat("\nall assertions passed\n")
