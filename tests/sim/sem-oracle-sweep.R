# Randomized observed-mediation optimizer oracle sweep. Run from the package root:
#   Rscript tests/sim/sem-oracle-sweep.R
#   MUTANT=badshift Rscript tests/sim/sem-oracle-sweep.R
# The ordinary run writes tests/sim/results/sem-oracle-sweep.csv; the mutant
# writes to tempdir(), exits nonzero, and must produce WRONG rows.
# Each case has a recorded seed. No medfit objective is used by the oracle.

suppressMessages(pkgload::load_all(quiet = TRUE))
source("tests/testthat/helper-sem.R")
mutant <- Sys.getenv("MUTANT", "")
if (!mutant %in% c("", "badshift")) stop("unknown MUTANT: ", mutant)
base_model <- "M ~ a*X\nY ~ b*M + cp*X"
tol_f <- 1e-6
tol_path <- 1e-4

# Profile Gaussian ML over a and b. For each pair, cp is the OLS path of
# Y - b M on X; the residual variances are their centered mean squares.
# The additive constants and the X contribution cancel against the saturated fit.
profile <- function(d) {
  x <- d$X - mean(d$X)
  m <- d$M - mean(d$M)
  y <- d$Y - mean(d$Y)
  vx <- mean(x^2)
  a0 <- sum(x * m) / sum(x^2)
  by <- stats::coef(stats::lm(Y ~ M + X, d))
  b0 <- unname(by["M"])
  cp0 <- unname(by["X"])
  vm0 <- mean((m - a0 * x)^2)
  vy0 <- mean((y - b0 * m - cp0 * x)^2)
  f <- function(a, b) {
    cp <- mean(x * (y - b * m)) / vx
    vm <- mean((m - a * x)^2)
    vy <- mean((y - b * m - cp * x)^2)
    log(vm / vm0) + log(vy / vy0)
  }
  list(f = f, ols = c(a = a0, b = b0, cp = cp0), vm0 = vm0, vy0 = vy0)
}

# Equalities are solved by eliminating b, then minimizing a scalar profile.
# For product equalities both sign branches are searched on a dense grid and
# refined locally. This also supplies the boundary oracle for inequalities.
boundary <- function(p, kind, k) {
  if (kind == "linear_a") {
    a <- k
    b <- p$ols[["b"]]
    return(list(a = a, b = b, f = p$f(a, b)))
  }
  if (kind == "linear_sum") {
    fn <- function(a) p$f(a, k - a)
    o <- stats::optimize(fn, c(-5, 5), tol = 1e-11)
    return(list(a = o$minimum, b = k - o$minimum, f = o$objective))
  }
  fn <- function(a) p$f(a, k / a)
  ranges <- list(c(-100, -1e-7), c(1e-7, 100))
  candidates <- lapply(ranges, function(z) {
    # A log grid resolves the neighborhood of zero as well as the tails.
    g <- sign(z[1]) * exp(seq(log(1e-7), log(100), length.out = 181L))
    g <- sort(g)
    val <- vapply(g, fn, numeric(1))
    j <- which.min(val)
    lo <- g[max(1L, j - 1L)]
    hi <- g[min(length(g), j + 1L)]
    if (lo == hi) {
      return(list(a = g[j], b = k / g[j], f = val[j]))
    }
    o <- stats::optimize(fn, c(lo, hi), tol = 1e-11)
    list(a = o$minimum, b = k / o$minimum, f = o$objective)
  })
  candidates[[which.min(vapply(candidates, `[[`, numeric(1), "f"))]]
}

one <- function(i) {
  family <- c("A", "B", "C")[(i - 1L) %/% 60L + 1L]
  seed <- 720000L + i
  set.seed(seed)
  n <- sample(80:400, 1L)
  a <- stats::runif(1L, -0.8, 0.8)
  b <- stats::runif(1L, -0.8, 0.8)
  cp <- stats::runif(1L, -0.5, 0.5)
  if (family == "A") {
    s <- 10^stats::runif(3L, -2, 3)
  } else {
    s <- c(1, 1, 1)
  }
  x <- stats::rnorm(n) * s[1L]
  m <- (a * x / s[1L] + stats::rnorm(n)) * s[2L]
  y <- (b * m / s[2L] + cp * x / s[1L] + stats::rnorm(n)) * s[3L]
  d <- data.frame(X = x, M = m, Y = y)
  p <- profile(d)
  variant <- "none"
  if (family == "B") {
    variant <- c("linear_a_eq", "linear_sum_eq", "linear_a_gt", "linear_sum_gt")[(i - 1L) %% 4L + 1L]
  } else if (family == "C") {
    variant <- c("product_eq", "product_gt")[(i - 1L) %% 2L + 1L]
  }
  k <- if (family == "B") {
    if (grepl("linear_a", variant)) {
      p$ols[["a"]] + stats::runif(1L, -0.35, 0.35)
    } else {
      sum(p$ols[c("a", "b")]) + stats::runif(1L, -0.35, 0.35)
    }
  } else if (family == "C") {
    p$ols[["a"]] * p$ols[["b"]] + stats::runif(1L, 0.04, 0.18)
  } else {
    NA_real_
  }
  kind <- if (grepl("linear_a", variant)) "linear_a" else if (grepl("linear_sum", variant)) "linear_sum" else "product"
  boundary_fit <- if (family == "A") NULL else boundary(p, kind, k)
  g0 <- if (kind == "linear_a") {
    p$ols[["a"]]
  } else if (kind == "linear_sum") {
    sum(p$ols[c("a", "b")])
  } else {
    p$ols[["a"]] * p$ols[["b"]]
  }
  feasible_ols <- family != "A" && grepl("_gt$", variant) && g0 > k
  oracle <- if (family == "A" || feasible_ols) list(a = p$ols[["a"]], b = p$ols[["b"]], f = 0) else boundary_fit
  constraint <- switch(variant,
    none = "",
    linear_a_eq = sprintf("a == %.17g", k),
    linear_sum_eq = sprintf("a + b == %.17g", k),
    linear_a_gt = sprintf("a > %.17g", k),
    linear_sum_gt = sprintf("a + b > %.17g", k),
    product_eq = sprintf("a*b == %.17g", k),
    product_gt = sprintf("a*b > %.17g", k)
  )
  syntax <- if (nzchar(constraint)) paste(base_model, constraint, sep = "\n") else base_model
  warnings <- character()
  error <- ""
  fit <- tryCatch(
    withCallingHandlers(fit_sem(syntax, d, n_starts = if (family == "C") 3L else 2L,
                                fixed_x = FALSE, meanstructure = NULL),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      error <<- conditionMessage(e)
      NULL
    }
  )
  gap <- NA_real_
  feas <- NA_real_
  f_gap <- NA_real_
  optimum <- ""
  if (is.null(fit)) {
    outcome <- "refused"
  } else {
    theta <- fit@theta
    ah <- unname(theta["a"])
    bh <- unname(theta["b"])
    gh <- if (kind == "linear_a") ah else if (kind == "linear_sum") ah + bh else ah * bh
    feas <- if (family == "A") 0 else if (grepl("_eq$", variant)) abs(gh - k) else max(0, k - gh)
    f_ind <- p$f(ah, bh)
    f_gap <- f_ind - oracle$f
    optimum <- if (is.null(fit@diagnostics$optimum$status)) "" else fit@diagnostics$optimum$status
    # Compare the reported objective with an independent likelihood as well.
    objective_gap <- abs(unname(fit@f) - f_ind)
    if (family == "A") {
      paths <- c("a", "b", "cp")
      path_gap <- max(abs(theta[paths] - p$ols[paths]) / pmax(1, abs(p$ols[paths])))
      gap <- max(path_gap, objective_gap)
      bad <- path_gap > tol_path || objective_gap > tol_f
    } else {
      gap <- max(abs(f_gap), objective_gap, feas)
      bad <- feas > 1e-6 || f_gap < -tol_f || f_gap > tol_f || objective_gap > tol_f
    }
    flagged <- length(warnings) > 0L || optimum %in% c("disagreed", "single")
    outcome <- if (bad && !flagged) "WRONG" else if (flagged) "flagged" else "correct"
  }
  data.frame(
    seed = seed, family = family, n = n, scale = paste(signif(s, 4), collapse = ";"),
    constraint = constraint, outcome = outcome, max_abs_error = gap, feasibility = feas,
    f_gap = f_gap, warning = paste(warnings, collapse = " | "), error = error, optimum = optimum
  )
}

run_all <- function() do.call(rbind, lapply(seq_len(180L), one))
started <- proc.time()[["elapsed"]]
rows <- if (mutant == "badshift") {
  testthat::with_mocked_bindings(
    run_all(),
    .sem_optimize = sem_mutate(
      .sem_optimize,
      "theta = stats::setNames(fit$theta, ram$par_names)",
      "theta = stats::setNames(replace(fit$theta, 1L, fit$theta[1L] + 0.2), ram$par_names)"
    ),
    .package = "medfit"
  )
} else {
  run_all()
}
seconds <- proc.time()[["elapsed"]] - started
out_dir <- if (nzchar(mutant)) tempdir() else "tests/sim/results"
dir.create(out_dir, showWarnings = FALSE)
out_file <- file.path(out_dir, "sem-oracle-sweep.csv")
utils::write.csv(rows, out_file, row.names = FALSE)
print(with(rows, table(family, outcome)))
cat(sprintf("elapsed %.1f seconds; WRONG %d; results %s\n", seconds, sum(rows$outcome == "WRONG"), out_file))
any_wrong <- any(rows$outcome == "WRONG")
verdict <- if (any_wrong) "FAIL" else "PASS"
if (nzchar(mutant)) verdict <- if (any_wrong) "MUTANT DETECTED" else "MUTANT MISSED"
cat(verdict, "\n", sep = "")
if (nzchar(mutant)) stopifnot(any(rows$outcome == "WRONG")) else stopifnot(!any(rows$outcome == "WRONG"))
