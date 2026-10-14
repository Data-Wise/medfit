# Why rule 9 excludes residual covariances in a product model (0.10.0 plan U4, rule 9; amendment section 2a).
#
# An endogenous product p = x * m1 makes joint ML differ from equation-wise OLS only through correlated equation
# residuals: with a free residual covariance the ML estimator is SUR/GLS, which equals OLS only when the regressor
# sets are nested or identical. True values: a1 = .7, a2 = .5, b1 = .4, b2 = .3, bp = .2; x has mean 2 (uncentered, so
# `m1 ~ x` is misfit against the product), residual correlation RHO = 0.8, n = 500, SEEDS = 10 seeds.
#   same   m1 ~ x + cv and m2 ~ x + cv (identical regressor sets: SUR = OLS even with correlated residuals)
#   diff   m1 ~ x + cv and m2 ~ x + c2 (NON-NESTED regressor sets: with correlated residuals GLS differs from OLS)
# Each is fitted without (`cvf = FALSE`) and with (`cvf = TRUE`) a free `m1 ~~ m2`; `gap` = max |SEM - OLS| over
# a1, a2, b1, b2, bp.
#
# PATH: PRODUCT_PATH=column (the default of this script) reaches the product through a PRECOMPUTED DATA COLUMN
# `p = x * m1`; PRODUCT_PATH=colon (entry script product-correlated-residuals-colon.R, gates.csv row
# "product-corr-colon") writes `x:m1` (canonical name `m1:x`). The model-fitting function is an argument (`fit_fun`,
# default `fit_sem()`). On the colon path rule 9 refuses every cvf = TRUE fit, which is the intended outcome: those rows
# record a NA gap and the gate reads a refusal as the rule working (rule_product_corr in product-gate-common.R). What
# the refused rows would have shown (the SUR leak) is recorded in `gap_column`, the same fit through the column path
# (which has no rule 9), so the colon gate still tests that the refusal is warranted: the `nocorr` mutant removes the
# leak and fails it. Rules 8 and 9 also fix auto-added pure-outcome residual covariances at 0 in a product model; this
# gate has one pure outcome (y), so completion adds none and the gate is unaffected.
#
# Rule (gates.csv row "product-corr"): 'match' rows (same x cvf in {FALSE, TRUE}, diff x FALSE) have gap <= 1e-5 (the
# optimizer's accuracy is about 1e-6 at these sizes; observed <= 1e-6); 'leak' rows (diff, cvf = TRUE) have gap >=
# 1e-4 in at
# least 80% of the seeds (observed 1e-3 to 1e-2 at n = 500 and rho = 0.8, a ratio of two to four orders over the
# match rows).
# `MUTANT=<name>` plants a defect; the gate must then exit 1:
#   nocorr    the generating residuals are independent (RHO = 0), so the leak disappears and the 'leak' rows fail
#   olsdrop   the OLS reference drops `cv` from the m1 equation, so even the 'match' rows disagree
# Run from the package root:  Rscript tests/sim/product-correlated-residuals.R   (SEEDS=10)

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  suppressMessages(pkgload::load_all(quiet = TRUE))
}
source("tests/sim/product-gate-common.R", local = TRUE)
# nolint start: object_usage_linter. (helpers come from the sourced files)

corr_truth <- c(a1 = 0.7, a2 = 0.5, b1 = 0.4, b2 = 0.3, bp = 0.2)

corr_data <- function(n, seed, rho) {
  set.seed(seed)
  x <- stats::rnorm(n, 2)
  cv <- stats::rnorm(n)
  c2 <- stats::rnorm(n)
  z <- matrix(stats::rnorm(2 * n), n, 2) %*% chol(matrix(c(1, rho, rho, 1), 2))
  m1 <- 0.7 * x + 0.5 * cv + z[, 1]
  m2 <- 0.5 * x + 0.5 * c2 + z[, 2]
  p <- x * m1
  y <- 0.4 * m1 + 0.3 * m2 + 0.3 * x + 0.2 * p + stats::rnorm(n)
  data.frame(x, cv, c2, m1, m2, y, p)
}

corr_one <- function(fit_fun, path, d, design, cvf, mutant = "") {
  r <- corr_gap(fit_fun, path, d, design, cvf, mutant)
  # the leak evidence the colon path cannot produce for a refused fit: the same model through the column
  r$gap_column <- if (identical(path, "colon") && cvf && design == "diff") { # only the leak rows are judged on it
    corr_gap(fit_fun, "column", d, design, cvf, mutant)$gap
  } else {
    NA_real_
  }
  r
}

corr_gap <- function(fit_fun, path, d, design, cvf, mutant = "") {
  prod_term <- product_term(path, "x", "m1")
  m2_rhs <- if (design == "same") "x + cv" else "x + c2"
  syn <- paste0("m1 ~ x + cv\nm2 ~ ", m2_rhs, "\ny ~ m1 + m2 + x + ", prod_term, if (cvf) "\nm1 ~~ m2" else "")
  l1 <- if (identical(mutant, "olsdrop")) m1 ~ x else m1 ~ x + cv
  l2 <- if (design == "same") m2 ~ x + cv else m2 ~ x + c2
  fy <- stats::lm(y ~ m1 + m2 + x + p, d)
  ols <- c(a1 = stats::coef(stats::lm(l1, d))[["x"]], a2 = stats::coef(stats::lm(l2, d))[["x"]],
           b1 = stats::coef(fy)[["m1"]], b2 = stats::coef(fy)[["m2"]], bp = stats::coef(fy)[["p"]])
  f <- tryCatch(suppressWarnings(fit_fun(syn, product_data(d, path))), error = function(e) e)
  if (inherits(f, "error")) {
    return(list(gap = NA_real_, gap_truth = NA_real_, err = conditionMessage(f)))
  }
  cf <- stats::coef(f)
  pn <- paste0("y~", product_name(path, "x", "m1")) # nolint: object_usage_linter.
  sem <- c(a1 = cf[["m1~x"]], a2 = cf[["m2~x"]], b1 = cf[["y~m1"]], b2 = cf[["y~m2"]], bp = cf[[pn]])
  list(gap = max(abs(sem - ols)), gap_truth = max(abs(sem - corr_truth)), err = "")
}

gate_product_corr <- function(fit_fun = fit_sem, path = Sys.getenv("PRODUCT_PATH", "column"),
                              seeds = as.integer(Sys.getenv("SEEDS", "10")), n = 500L,
                              mutant = Sys.getenv("MUTANT", ""),
                              rho = if (identical(mutant, "nocorr")) 0 else 0.8) {
  stopifnot(mutant %in% c("", "nocorr", "olsdrop"), path %in% c("column", "colon"))
  rows <- list()
  for (seed in seq_len(seeds)) {
    d <- corr_data(n, 17L + seed, rho)
    for (design in c("same", "diff")) {
      for (cvf in c(FALSE, TRUE)) {
        r <- corr_one(fit_fun, path, d, design, cvf, mutant)
        rows[[length(rows) + 1L]] <- data.frame(
          design = design, cvf = cvf, seed = seed, path = path,
          expect = if (design == "diff" && cvf) "leak" else "match",
          gap = r$gap, gap_truth = r$gap_truth, gap_column = r$gap_column, err = r$err, mutant = mutant,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  res <- gate_product_corr()
  print(stats::aggregate(cbind(gap, gap_truth) ~ design + cvf, res, max), digits = 3)
  sfx <- product_path_suffix(Sys.getenv("PRODUCT_PATH", "column"))
  if (!nzchar(Sys.getenv("MUTANT", ""))) product_write_results(res, paste0("product-correlated-residuals", sfx))
  quit(status = product_gate_status(paste0("product-corr", sfx), res, product_gate_spec(paste0("product-corr", sfx))))
}
# nolint end
