# Native SEM engine: the model-test policy for a product term (0.10.0 plan U6, amendment section 2a, F4/F9/F10).
# A product with an endogenous factor (`x:m` with `m ~ x`), or a restricted exogenous (co)variance block, makes the
# global chi-square invalid. The fit warns once, `glance()` and `summary()` report the test as NA with a note,
# `anova()` and `mbco_sem()` refuse naming the product, and `information = "expected"` is refused for an endogenous
# product. The population gate reads the statistic through the internal `.sem_chisq()`.

# Codex's counterexample (amendment section 2a): m = .7 x + e, y = .4 m + .3 x + .2 x m + e', X uncentered.
pmt_data <- function(n = 600L, seed = 17L, xmean = 2) {
  set.seed(seed)
  x <- stats::rnorm(n) + xmean
  w <- stats::rnorm(n)
  m <- 0.7 * x + stats::rnorm(n)
  y <- 0.4 * m + 0.3 * x + 0.2 * x * m + 0.3 * w + stats::rnorm(n)
  data.frame(x = x, w = w, m = m, y = y)
}
pmt_endo <- "m ~ x\ny ~ m + x + x:m"
pmt_exo <- "m ~ x\ny ~ m + x + w + x:w"
pmt_fit <- function(model, data = pmt_data(), ...) {
  suppressWarnings(fit_sem(model, data, se_type = "sandwich", ...))
}

test_that("population gate: coefficients equal equation-wise OLS, the chi-square is far above its critical value", {
  d <- pmt_data(n = 20000L)
  fit <- pmt_fit(pmt_endo, d)
  ols_m <- stats::coef(stats::lm(m ~ x, d))
  ols_y <- stats::coef(stats::lm(y ~ m + x + I(x * m), d))
  # Tolerance 1e-6, derived from the optimizer's convergence criterion: SLSQP stops on ftol_rel = 1e-12 of F, and
  # near the optimum F - F* = (1/2) d' H d, so the iterate is within sqrt(2e-12 F / h_min) of the optimum, about
  # 1e-6 / 10 for these curvatures. Measured at n = 20000 (plan F9): max |SEM - OLS| between 3.5e-8 and 7.1e-8, so
  # 1e-6 leaves a margin above 14, and the "1e-8" of the first draft of the gate is not claimed.
  tol <- 1e-6
  expect_equal(unname(coef(fit)["m~x"]), unname(ols_m["x"]), tolerance = tol)
  expect_equal(unname(coef(fit)["y~m"]), unname(ols_y["m"]), tolerance = tol)
  expect_equal(unname(coef(fit)["y~x"]), unname(ols_y["x"]), tolerance = tol)
  expect_equal(unname(coef(fit)["y~m:x"]), unname(ols_y["I(x * m)"]), tolerance = tol)
  # the global test is far from chi-square: read through the internal accessor, since glance() reports NA
  chisq <- .sem_chisq(fit)
  expect_gt(chisq, 100 * stats::qchisq(0.95, fit@df))
  expect_true(is.na(generics::glance(fit)$chisq))
  expect_equal(chisq, fit@n_obs * fit@f)
})

test_that("centered X: the same model gives a small statistic, so the verdict depends on the data, not on NA", {
  fit <- pmt_fit(pmt_endo, pmt_data(n = 20000L, xmean = 0))
  expect_lt(.sem_chisq(fit), 30)
})

test_that(".sem_chisq() is NA for a weighted fit and clamps a saturated fit's roundoff", {
  d <- pmt_data()
  w <- stats::runif(nrow(d), 0.5, 1.5)
  fit <- suppressWarnings(fit_sem(pmt_exo, d, weights = w, se_type = "sandwich"))
  expect_true(is.na(.sem_chisq(fit)))
  sat <- fit_sem("y ~ x", d)
  expect_gte(.sem_chisq(sat), 0)
})

test_that("an endogenous product warns once at fit, naming the product", {
  expect_warning(fit_sem(pmt_endo, pmt_data(), se_type = "sandwich"), "model test is not valid.*'m:x'.*endogenous")
  w <- character()
  withCallingHandlers(
    fit_sem(pmt_endo, pmt_data(), se_type = "sandwich"),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(w, 1L)
  # without the sandwich the SE advice is a second, separate warning
  w <- character()
  withCallingHandlers(
    fit_sem(pmt_endo, pmt_data()),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )
  expect_length(w, 2L)
  expect_match(w[2L], "se_type = \"sandwich\"")
})

test_that("an exogenous product is unrestricted: no model-test warning, a real test, and the sandwich advice only", {
  expect_no_warning(fit_sem(pmt_exo, pmt_data(), se_type = "sandwich"))
  expect_warning(fit_sem(pmt_exo, pmt_data()), "w:x.*se_type = \"sandwich\"")
  fit <- pmt_fit(pmt_exo)
  g <- generics::glance(fit)
  expect_false(is.na(g$chisq))
  expect_false(is.na(g$p_value))
  expect_equal(g$df, fit@df)
  expect_null(attr(g, "note"))
  expect_null(fit@internals$ram$modeltest)
})

test_that("a model without a product is unchanged: silent, a test, nothing stored", {
  d <- pmt_data()
  expect_no_warning(fit <- fit_sem("m ~ x\ny ~ m + x", d))
  g <- generics::glance(fit)
  expect_false(is.na(g$chisq))
  expect_equal(g$chisq, fit@n_obs * fit@f)
  expect_null(fit@internals$ram$modeltest)
  expect_null(summary(fit)$model_test_note)
})

test_that("glance() and summary() report the test as NA with a note for an endogenous product", {
  fit <- pmt_fit(pmt_endo)
  g <- generics::glance(fit)
  expect_true(all(is.na(g[c("chisq", "df", "p_value")])))
  expect_false(is.na(g$logLik)) # the likelihood and its criteria stay defined
  expect_match(attr(g, "note"), "model test not valid with a product of an endogenous variable.*'m:x'")
  s <- summary(fit)
  expect_true(is.na(s$df))
  expect_match(s$model_test_note, "model test not valid")
  expect_output(print(s), "model test not valid with a product of an endogenous variable")
  expect_output(print(fit), "model test not valid")
})

test_that("anova() and mbco_sem() refuse an endogenous product, naming it", {
  full <- pmt_fit(pmt_endo)
  restricted <- pmt_fit("m ~ x\ny ~ m + x:m")
  expect_error(anova(full, restricted), "anova\\(\\) is not available.*'m:x'")
  expect_error(anova(restricted, full), "anova\\(\\) is not available.*'m:x'")
  lab <- pmt_fit("m ~ a*x\ny ~ b*m + x + x:m")
  expect_error(mbco_sem(lab, "a", "b"), "mbco_sem\\(\\) is not available.*'m:x'")
  # the same two calls work on the no-product twins
  twin <- fit_sem("m ~ a*x\ny ~ b*m + x", pmt_data())
  expect_no_error(mbco_sem(twin, "a", "b"))
})

test_that("a restricted exogenous block is refused too: fixed, labeled, bounded and left-out (co)variances", {
  cases <- list(
    fixed = c("x ~~ 1*x", "'x ~~ x' is fixed"),
    labeled = c("x ~~ vx*x", "'x ~~ x' is labeled"),
    bounded = c("x ~~ vx*x\nvx > 0.2", "'x ~~ x'.*(labeled|bounded)"),
    dropped = c("x ~~ x", "'.*' is missing")
  )
  for (nm in names(cases)) {
    model <- paste(pmt_exo, cases[[nm]][1L], sep = "\n")
    expect_warning(
      fit <- fit_sem(model, pmt_data(), se_type = "sandwich", fixed_x = FALSE, meanstructure = NULL), "model test is not valid.*exogenous \\(co\\)variance",
      info = nm
    )
    expect_match(.sem_modeltest_reason(fit), cases[[nm]][2L], info = nm)
    expect_true(is.na(generics::glance(fit)$chisq), info = nm)
    restricted <- suppressWarnings(fit_sem(paste(pmt_exo, "w ~~ 1*w", cases[[nm]][1L], sep = "\n"), pmt_data(),
                                           se_type = "sandwich", fixed_x = FALSE, meanstructure = NULL))
    expect_error(anova(fit, restricted), "anova\\(\\) is not available", info = nm)
  }
  # the exogenous product alone is unrestricted, and so is a block the engine completed
  expect_null(.sem_modeltest_reason(pmt_fit(pmt_exo)))
})

test_that("fixed_x moments are not a restriction; an endogenous product stays invalid with fixed_x", {
  g <- generics::glance(pmt_fit(pmt_exo, fixed_x = TRUE))
  expect_false(is.na(g$chisq))
  expect_true(is.na(generics::glance(pmt_fit(pmt_endo, fixed_x = TRUE))$chisq))
  # a statement on one exogenous variable's variance beside a fixed_x selection of the others leaves covariances out
  expect_warning(
    fit_sem(paste(pmt_exo, "w ~~ w", sep = "\n"), pmt_data(), fixed_x = c("x"), se_type = "sandwich"),
    "exogenous \\(co\\)variance"
  )
})

test_that("information = 'expected' is refused for an endogenous product, and only for it", {
  expect_error(
    fit_sem(pmt_endo, pmt_data(), information = "expected", se_type = "sandwich"),
    "expected.*'m:x'.*endogenous.*observed"
  )
  # an exogenous product keeps the expected information, and the default stays observed
  expect_no_error(suppressWarnings(fit_sem(pmt_exo, pmt_data(), information = "expected", se_type = "sandwich")))
  expect_equal(pmt_fit(pmt_endo)@information, "observed")
})

test_that("planted defect: without the endogenous-factor check the model test is not refused", {
  fx_skip_covr()
  mutant <- sem_mutate(.sem_product_modeltest, "endo <- c(r$ov_y, r$lv_y, r$ind)", "endo <- character()")
  local_mocked_bindings(.sem_product_modeltest = mutant)
  expect_no_warning(full <- fit_sem(pmt_endo, pmt_data(), se_type = "sandwich"))
  restricted <- fit_sem("m ~ x\ny ~ m + x:m", pmt_data(), se_type = "sandwich")
  expect_no_error(anova(full, restricted)) # the refusal is gone: this is what the check prevents
  expect_false(is.na(generics::glance(full)$chisq))
  # and the information refusal goes with it
  expect_no_error(fit_sem(pmt_endo, pmt_data(), information = "expected", se_type = "sandwich"))
})

test_that("planted defect: dropping the refusal in the checker lets anova() run on a flagged fit", {
  fx_skip_covr()
  full <- pmt_fit(pmt_endo)
  restricted <- pmt_fit("m ~ x\ny ~ m + x:m")
  expect_error(anova(full, restricted), "not available")
  mutant <- sem_mutate(.sem_check_modeltest, "if (!is.null(reason))", "if (FALSE)")
  local_mocked_bindings(.sem_check_modeltest = mutant)
  expect_no_error(anova(full, restricted))
})

test_that("the null gate runs through the `:` path and equals the column path, replication by replication", {
  skip_if_not_installed("withr")
  common <- test_path("..", "sim", "exo-product-null.R")
  skip_if_not(file.exists(common), "tests/sim is not shipped with the installed tests")
  withr::local_dir(normalizePath(test_path("..", "..")))
  genv <- new.env(parent = asNamespace("medfit"))
  genv$MEDFIT_GATE_SOURCE_ONLY <- TRUE
  sys.source(file.path("tests", "sim", "exo-product-null.R"), envir = genv)
  col <- genv$gate_product_null(fit_sem, "column", reps = 6, n = 200, cores = 1)
  colon <- genv$gate_product_null(fit_sem, "colon", reps = 6, n = 200, cores = 1)
  expect_equal(colon$reps_ok, c(6, 6))
  expect_equal(colon$mean_chisq, col$mean_chisq, tolerance = 1e-5)
  expect_true(all(colon$df == 2))
  # the endogenous mutant is MEASURED on the colon path although glance() reports its test as NA
  bad <- genv$gate_product_null(fit_sem, "colon", reps = 6, n = 200, mutant = "endogenous", cores = 1)
  expect_equal(bad$reps_ok, c(6, 6)) # all fitted and read: the gate's columns carry numbers, not NA
  # the gate has its own gates.csv row and rule
  spec <- utils::read.csv(file.path("tests", "sim", "gates.csv"), stringsAsFactors = FALSE)
  expect_equal(sum(spec$gate == "product-null-colon"), 1L)
})

test_that("an indicator of a latent variable is endogenous: its product is flagged", {
  set.seed(5)
  n <- 500L
  x <- stats::rnorm(n) + 1
  eta <- 0.5 * x + stats::rnorm(n)
  d <- data.frame(x = x, m1 = eta + 0.5 * stats::rnorm(n), m2 = eta + 0.5 * stats::rnorm(n))
  d$y <- eta + x + stats::rnorm(n)
  model <- "eta =~ m1 + m2\neta ~ x\ny ~ eta + x + x:m1"
  fit <- suppressWarnings(fit_sem(model, d, se_type = "sandwich"))
  expect_match(.sem_modeltest_reason(fit), "'m1:x'.*endogenous factor \\('m1'\\)")
  expect_true(is.na(generics::glance(fit)$chisq))
})

test_that("a call that fails reports its error and no policy warning", {
  d <- pmt_data()
  expect_no_warning(try(fit_sem(pmt_endo, d[c("x", "y")], se_type = "model"), silent = TRUE))
  expect_error(suppressWarnings(fit_sem(pmt_endo, d[c("x", "y")])), "not columns of `data`")
})

test_that("the committed colon-path baseline passes the null-gate rule", {
  common <- test_path("..", "sim", "product-gate-common.R")
  skip_if_not(file.exists(common), "tests/sim is not shipped with the installed tests")
  env <- new.env(parent = globalenv())
  sys.source(common, envir = env)
  spec <- utils::read.csv(test_path("..", "sim", "gates.csv"), stringsAsFactors = FALSE, na.strings = c("NA", ""))
  s <- spec[spec$gate == "product-null-colon", , drop = FALSE]
  files <- list.files(test_path("..", "sim", "results"), "^exo-product-null-colon-.*\\.csv$", full.names = TRUE)
  expect_gte(length(files), 1L)
  d <- utils::read.csv(files[length(files)])
  expect_true(all(env$rule_product_null(d, s)$pass))
  expect_true(is.function(env$product_gate_rules[["product-null-colon"]]))
  d$reject05[1] <- 0.3 # a miscalibrated frame is rejected
  expect_false(all(env$rule_product_null(d, s)$pass))
})
