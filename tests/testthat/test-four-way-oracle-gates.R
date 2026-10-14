# The gate harness (0.10.0 plan U8): the pass rules in tests/sim/product-gate-common.R, the product-path plumbing the
# gate scripts use (a precomputed column, or the `:` term; each product gate has a `-colon` twin), and the scripts'
# model-fitting-function argument. The gates themselves are run by tests/sim/run-gates.R and the scripts; these tests
# pin the rules and the plumbing, with planted defects: every rule must reject a frame that violates it.

common <- test_path("..", "sim", "product-gate-common.R")
skip_if_not(file.exists(common), "tests/sim is not shipped with the installed tests")
root <- normalizePath(test_path("..", ".."))
env <- new.env(parent = globalenv())
sys.source(common, envir = env)
spec_of <- function(gate) {
  s <- utils::read.csv(file.path(root, "tests", "sim", "gates.csv"), stringsAsFactors = FALSE, na.strings = c("NA", ""))
  s[s$gate == gate, , drop = FALSE]
}
failed <- function(v) v$check[!v$pass]

test_that("every new gate has exactly one gates.csv row and a rule", {
  for (g in c("product-null", "product-null-colon", "product-fixed-var", "product-fixed-var-colon", "product-corr",
              "product-corr-colon", "four-way-kat")) {
    expect_equal(nrow(spec_of(g)), 1L, info = g)
    expect_true(is.function(env$product_gate_rules[[g]]), info = g)
  }
})

test_that("product-null rule: passes a calibrated frame, rejects each violation", {
  s <- spec_of("product-null")
  ok <- data.frame(xdist = c("norm", "exp"), df = 2, reject05 = c(0.055, 0.056), mean_chisq = c(2.0, 2.05),
                   reps = 1000, reps_ok = 1000)
  expect_true(all(env$rule_product_null(ok, s)$pass))
  bad <- ok
  bad$reject05[1] <- 0.147
  expect_equal(failed(env$rule_product_null(bad, s)), "rejection at .05")
  bad <- ok
  bad$mean_chisq[2] <- 3.06
  expect_equal(failed(env$rule_product_null(bad, s)), "mean chi-square")
  bad <- ok
  bad$reps_ok[1] <- 500
  expect_equal(failed(env$rule_product_null(bad, s)), "fitted replications")
  expect_equal(failed(env$rule_product_null(ok[1, ], s)), "rows")
  expect_equal(failed(env$rule_product_null(ok[0, ], s)), "rows")
})

test_that("product-fixed-var rule: calibrated rows stay calibrated, documented-miscalibrated rows stay so", {
  s <- spec_of("product-fixed-var")
  ok <- data.frame(
    xdist = rep(c("norm", "exp"), each = 3), config = rep(c("free", "fixvar", "dropcov"), 2),
    expect = c("calibrated", "calibrated", "miscalibrated", "calibrated", "miscalibrated", "miscalibrated"),
    df = rep(c(2, 4, 7), 2), reject05 = c(0.055, 0.051, 0.249, 0.056, 0.383, 0.693),
    mean_chisq = c(2.0, 3.96, 10.88, 2.05, 9.54, 27.57), reps = 1000, reps_ok = 1000
  )
  expect_true(all(env$rule_product_fixed_var(ok, s)$pass))
  bad <- ok
  bad$reject05[2] <- 1 # a wrong fixed variance
  expect_true("calibrated rows: rejection at .05" %in% failed(env$rule_product_fixed_var(bad, s)))
  bad <- ok
  bad$reject05[5] <- 0.06 # the documented miscalibration healed: the policy evidence is gone
  expect_equal(failed(env$rule_product_fixed_var(bad, s)), "miscalibrated rows stay miscalibrated")
  bad <- ok
  bad$mean_chisq[1] <- 3
  expect_equal(failed(env$rule_product_fixed_var(bad, s)), "calibrated rows: mean chi-square")
})

test_that("product-fixed-var-colon rule: four rows (no `fixvar` on a product), same calibration rules", {
  s <- spec_of("product-fixed-var-colon")
  expect_equal(s$expected_rows, 4)
  ok <- data.frame(
    xdist = rep(c("norm", "exp"), each = 2), config = rep(c("free", "dropcov"), 2), path = "colon",
    expect = rep(c("calibrated", "miscalibrated"), 2), df = rep(c(2, 7), 2), reject05 = c(0.055, 0.249, 0.056, 0.693),
    mean_chisq = c(2.0, 10.88, 2.05, 27.57), reps = 1000, reps_ok = 1000
  )
  expect_true(all(env$rule_product_fixed_var(ok, s)$pass))
  expect_equal(failed(env$rule_product_fixed_var(ok[-4, ], s)), "rows")
  bad <- ok
  bad$reject05[1] <- 0.2
  expect_true("calibrated rows: rejection at .05" %in% failed(env$rule_product_fixed_var(bad, s)))
  bad <- ok
  bad$reject05[4] <- 0.05
  expect_equal(failed(env$rule_product_fixed_var(bad, s)), "miscalibrated rows stay miscalibrated")
})

test_that("product-corr rule: match rows within the optimizer's accuracy, leak rows leak, rule 9 refusals pass", {
  s <- spec_of("product-corr")
  ok <- data.frame(
    design = rep(c("same", "diff"), each = 20), cvf = rep(rep(c(FALSE, TRUE), each = 10), 2), path = "column",
    expect = c(rep("match", 30), rep("leak", 10)), gap = c(rep(5e-7, 30), rep(2e-3, 10))
  )
  expect_true(all(env$rule_product_corr(ok, s)$pass))
  bad <- ok
  bad$gap[1:3] <- 1e-2
  expect_equal(failed(env$rule_product_corr(bad, s)), "match rows: SEM equals OLS")
  bad <- ok
  bad$gap[31:40] <- 1e-6 # no leak: the planted `nocorr` situation
  expect_equal(failed(env$rule_product_corr(bad, s)), "leak rows: SEM differs from OLS")
  bad <- ok
  bad$gap[5] <- NA
  expect_equal(failed(env$rule_product_corr(bad, s)), "fitted runs")
  # colon path: rule 9 refuses every free residual covariance; the leak is read from the column-path gap
  colon <- ok
  colon$path <- "colon"
  colon$gap_column <- ifelse(colon$cvf & colon$expect == "leak", 2e-3, NA)
  colon$gap[colon$cvf] <- NA
  colon$err <- ifelse(colon$cvf, "a product model cannot have a residual covariance (rule 9)", "")
  expect_true(all(env$rule_product_corr(colon, s)$pass))
  # the refused fits stopped leaking (the `nocorr` mutant): the colon gate fails on the column-path gap
  bad <- colon
  bad$gap_column[!is.na(bad$gap_column)] <- 1e-7
  expect_equal(failed(env$rule_product_corr(bad, s)), "leak rows: SEM differs from OLS")
  # the column fit of a refused leak row is missing: not silently skipped
  bad <- colon
  bad$gap_column[which(!is.na(bad$gap_column))[1]] <- NA
  expect_equal(failed(env$rule_product_corr(bad, s)), "leak rows: SEM differs from OLS")
  # a free residual covariance that was NOT refused on the colon path breaks the refusal check
  bad <- colon
  bad$gap[which(bad$cvf)[1]] <- 1e-7
  bad$err[which(bad$cvf)[1]] <- ""
  expect_true("rule 9 refuses every free residual covariance" %in% failed(env$rule_product_corr(bad, s)))
  # an unrelated failure is not a refusal: the gate must not read it as rule 9 working
  bad <- colon
  bad$err[bad$cvf] <- "could not parse x:m1"
  expect_true(all(c("fitted runs", "rule 9 refuses every free residual covariance") %in%
                    failed(env$rule_product_corr(bad, s))))
})

test_that("four-way-kat rule: bias and SE ratio bounds, replication count, missing values", {
  s <- spec_of("four-way-kat")
  ok <- data.frame(scenario = "A", route = "hand", component = rep(c("cde", "te"), length.out = 84),
                   bias_z = rep(c(-1.5, 2), length.out = 84), se_ratio = rep(c(0.96, 1.05), length.out = 84),
                   reps = 1000, reps_ok = 1000)
  expect_true(all(env$rule_four_way_kat(ok, s)$pass))
  bad <- ok
  bad$bias_z[7] <- 4.5
  expect_equal(failed(env$rule_four_way_kat(bad, s)), "bias (Monte Carlo SEs)")
  bad <- ok
  bad$se_ratio[3] <- 1.25 # the dropped-covariate-term defect
  expect_equal(failed(env$rule_four_way_kat(bad, s)), "standard errors vs empirical SD")
  bad <- ok
  bad$se_ratio[3] <- NA
  expect_true("missing statistics" %in% failed(env$rule_four_way_kat(bad, s)))
  bad <- ok
  bad$reps_ok[1] <- 10
  expect_equal(failed(env$rule_four_way_kat(bad, s)), "fitted replications")
})

test_that("the gate's KAT tolerance in gates.csv is the helper's derivation rounded to two places", {
  expect_equal(spec_of("four-way-kat")$tol_se, round(fwo_kat_tolerance(1000)$se, 2))
  expect_equal(spec_of("four-way-kat")$tol_est, fwo_kat_tolerance(1000)$z)
})

test_that("the committed baselines pass their rules (control for the mutation tests above)", {
  for (g in c("product-null", "product-null-colon", "product-fixed-var", "product-fixed-var-colon", "product-corr",
              "product-corr-colon", "four-way-kat")) {
    s <- spec_of(g)
    files <- sort(list.files(file.path(root, "tests", "sim", "results"),
                             pattern = paste0("^", s$results_prefix, "-[0-9]{4}-[0-9]{2}-[0-9]{2}\\.csv$"),
                             full.names = TRUE))
    skip_if(!length(files), "no committed baseline yet")
    expect_true(all(env$product_gate_rules[[g]](utils::read.csv(files[length(files)]), s)$pass), info = g)
  }
})

test_that("product path helpers: column keeps `p`, colon writes the factors and drops the column", {
  expect_equal(env$product_term("column", "x", "w"), "p")
  expect_equal(env$product_term("colon", "x", "w"), "x:w")
  expect_equal(env$product_name("colon", "x", "m1"), "m1:x") # C-locale sort, amendment rule 7
  expect_equal(env$product_name("colon", "M", "x"), "M:x") # upper case sorts before lower case in the C locale
  expect_equal(env$product_name("column", "x", "m1"), "p")
  expect_equal(env$product_syntax("y ~ m + P\nP ~~ P", "x:w"), "y ~ m + x:w\nx:w ~~ x:w")
  expect_equal(env$product_syntax("y ~ m + P", "p"), "y ~ m + p")
  d <- data.frame(x = 1, w = 2, p = 2)
  expect_equal(names(env$product_data(d, "column")), c("x", "w", "p"))
  expect_equal(names(env$product_data(d, "colon")), c("x", "w"))
})

test_that("the gate scripts take a model-fitting function and route the product through the chosen path", {
  skip_if_not_installed("withr")
  withr::local_dir(root)
  genv <- new.env(parent = asNamespace("medfit"))
  genv$MEDFIT_GATE_SOURCE_ONLY <- TRUE
  for (f in c("exo-product-null.R", "exo-product-fixed-var.R", "product-correlated-residuals.R")) {
    sys.source(file.path("tests", "sim", f), envir = genv)
  }
  seen <- list()
  spy <- function(syntax, data) {
    seen[[length(seen) + 1L]] <<- list(syntax = syntax, cols = names(data))
    stop("spy")
  }
  # null gate: the fit function is called with the right spelling and data, and its failure counts as an unfitted run
  res <- genv$gate_product_null(spy, "colon", reps = 2, n = 50, mutant = "", cores = 1)
  expect_equal(res$reps_ok, c(0, 0))
  expect_true(all(grepl("y ~ m + x + w + x:w", vapply(seen, `[[`, "", "syntax"), fixed = TRUE)))
  expect_false(any(vapply(seen, function(z) "p" %in% z$cols, logical(1))))
  seen <- list()
  genv$gate_product_null(spy, "column", reps = 1, n = 50, mutant = "", cores = 1)
  expect_true(all(grepl("y ~ m + x + w + p", vapply(seen, `[[`, "", "syntax"), fixed = TRUE)))
  expect_true(all(vapply(seen, function(z) "p" %in% z$cols, logical(1))))
  # the endogenous mutant writes the product of x and m
  seen <- list()
  genv$gate_product_null(spy, "colon", reps = 1, n = 50, mutant = "endogenous", cores = 1)
  expect_true(all(grepl("x:m", vapply(seen, `[[`, "", "syntax"), fixed = TRUE)))
  # fixed-variance gate: the colon path skips `fixvar` (no `~~` on a product in the grammar)
  seen <- list()
  res <- genv$gate_product_fixed_var(spy, "colon", reps = 1, n = 50, mutant = "", cores = 1)
  expect_setequal(unique(res$config), c("free", "dropcov"))
  expect_false(any(grepl("~~ x:w|x:w ~~", vapply(seen, `[[`, "", "syntax"))))
  expect_equal(env$product_path_suffix("colon"), "-colon")
  expect_equal(env$product_path_suffix("column"), "")
  # the colon path has no `fixvar` configuration to corrupt: `wrongvar` restricts the `free` block instead
  seen <- list()
  genv$gate_product_fixed_var(spy, "colon", reps = 1, n = 50, mutant = "wrongvar", cores = 1)
  syn <- vapply(seen, `[[`, "", "syntax")
  expect_true(any(grepl("y ~ m + x + w + x:w\nx ~~ 2*x\nw ~~ 2*w", syn, fixed = TRUE)))
  seen <- list()
  genv$gate_product_fixed_var(spy, "colon", reps = 1, n = 50, mutant = "", cores = 1)
  expect_false(any(grepl("2*x", vapply(seen, `[[`, "", "syntax"), fixed = TRUE)))
  seen <- list()
  genv$gate_product_fixed_var(spy, "column", reps = 1, n = 50, mutant = "wrongvar", cores = 1)
  expect_true(any(grepl("x ~~ 2*x", vapply(seen, `[[`, "", "syntax"), fixed = TRUE)))
  # correlated-residuals gate: the product is x:m1 on the colon path (the free-covariance fits also fit the column
  # path, `p`, for the leak evidence)
  seen <- list()
  res <- genv$gate_product_corr(spy, "colon", seeds = 1, n = 50)
  syn <- vapply(seen, `[[`, "", "syntax")
  expect_true(all(grepl("y ~ m1 + m2 + x + x:m1", syn, fixed = TRUE) | grepl("y ~ m1 + m2 + x + p", syn, fixed = TRUE)))
  expect_equal(sum(grepl("x + p", syn, fixed = TRUE)), 1L) # only the (diff, cvf = TRUE) leak row
  expect_true(all(is.na(res$gap)))
  expect_true("gap_column" %in% names(res))
  expect_error(genv$gate_product_null(spy, "colon", reps = 1, n = 50, mutant = "bogus", cores = 1))
})

test_that("the column path runs end to end through fit_sem() and reports a frame with the gate's columns", {
  skip_if_not_installed("withr")
  withr::local_dir(root)
  genv <- new.env(parent = asNamespace("medfit"))
  genv$MEDFIT_GATE_SOURCE_ONLY <- TRUE
  sys.source(file.path("tests", "sim", "exo-product-null.R"), envir = genv)
  res <- genv$gate_product_null(fit_sem, "column", reps = 6, n = 200, cores = 1)
  expect_equal(res$reps_ok, c(6, 6))
  expect_true(all(res$df == 2))
  expect_true(all(c("xdist", "df", "reject05", "mean_chisq", "reps", "reps_ok") %in% names(res)))
})
