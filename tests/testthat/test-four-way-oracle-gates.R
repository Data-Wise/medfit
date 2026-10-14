# The gate harness (0.10.0 plan U8): the pass rules in tests/sim/product-gate-common.R, the product-path plumbing the
# gate scripts use (precomputed column now, `:` later), and the scripts' model-fitting-function argument. The gates
# themselves are run by tests/sim/run-gates.R and the scripts; these tests pin the rules and the plumbing, with
# planted defects: every rule must reject a frame that violates it.

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
  for (g in c("product-null", "product-fixed-var", "product-corr", "four-way-kat")) {
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
  colon <- ok
  colon$path <- "colon"
  colon$gap[colon$cvf] <- NA # rule 9 refuses a free residual covariance on the colon path
  colon$err <- ifelse(colon$cvf, "a product model cannot have a residual covariance (rule 9)", "")
  expect_true(all(env$rule_product_corr(colon, s)$pass))
  # an unrelated failure is not a refusal: the gate must not read it as rule 9 working
  colon$err[colon$cvf] <- "could not parse x:m1"
  expect_equal(failed(env$rule_product_corr(colon, s)), c("fitted runs", "leak rows: SEM differs from OLS"))
})

test_that("four-way-kat rule: bias and SE ratio bounds, replication count, missing values", {
  s <- spec_of("four-way-kat")
  ok <- data.frame(scenario = "A", route = "hand", component = rep(c("cde", "te"), length.out = 63),
                   bias_z = rep(c(-1.5, 2), length.out = 63), se_ratio = rep(c(0.96, 1.05), length.out = 63),
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
  for (g in c("product-null", "product-fixed-var", "product-corr", "four-way-kat")) {
    s <- spec_of(g)
    files <- sort(list.files(file.path(root, "tests", "sim", "results"),
                             pattern = paste0("^", s$results_prefix, "-.*\\.csv$"), full.names = TRUE))
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
  genv <- new.env(parent = globalenv())
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
  seen <- list()
  genv$gate_product_fixed_var(spy, "column", reps = 1, n = 50, mutant = "wrongvar", cores = 1)
  expect_true(any(grepl("x ~~ 2*x", vapply(seen, `[[`, "", "syntax"), fixed = TRUE)))
  # correlated-residuals gate: the endogenous product is m1:x on the colon path
  seen <- list()
  res <- genv$gate_product_corr(spy, "colon", seeds = 1, n = 50)
  expect_true(all(grepl("y ~ m1 + m2 + x + x:m1", vapply(seen, `[[`, "", "syntax"), fixed = TRUE)))
  expect_true(all(is.na(res$gap)))
  expect_error(genv$gate_product_null(spy, "colon", reps = 1, n = 50, mutant = "bogus", cores = 1))
})

test_that("the column path runs end to end through fit_sem() and reports a frame with the gate's columns", {
  skip_if_not_installed("withr")
  withr::local_dir(root)
  genv <- new.env(parent = globalenv())
  genv$MEDFIT_GATE_SOURCE_ONLY <- TRUE
  sys.source(file.path("tests", "sim", "exo-product-null.R"), envir = genv)
  res <- genv$gate_product_null(fit_sem, "column", reps = 6, n = 200, cores = 1)
  expect_equal(res$reps_ok, c(6, 6))
  expect_true(all(res$df == 2))
  expect_true(all(c("xdist", "df", "reject05", "mean_chisq", "reps", "reps_ok") %in% names(res)))
})
