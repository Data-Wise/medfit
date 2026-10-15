# T5: missing data with a factor covariate (F7, D2). Dummies are built from the full column before listwise deletion, so
# the coefficient set never depends on which rows survive; a dummy that is constant in the rows the fit uses is an
# error that names it. The oracle is the hand-coded twin on the same complete rows.

fm_data <- function(n = 160L, seed = 31L) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  x <- rnorm(n)
  m <- 0.5 * x + 0.5 * (g == "b") + rnorm(n)
  y <- 0.4 * m + 0.3 * (g == "c") + rnorm(n)
  data.frame(y = y, m = m, x = x, g = g)
}
fm_twin <- function(d) transform(d, g_b = as.numeric(g == "b"), g_c = as.numeric(g == "c"))
fm_model <- "m ~ a*x + g\ny ~ b*m + g"
fm_twin_model <- "m ~ a*x + g_b + g_c\ny ~ b*m + g_b + g_c"
fm_msgs <- function(expr) {
  msgs <- character()
  val <- withCallingHandlers(expr, message = function(e) {
    msgs <<- c(msgs, conditionMessage(e))
    invokeRestart("muffleMessage")
  })
  list(value = val, messages = msgs)
}
fm_same <- function(f, ft, loglik = TRUE) {
  expect_true(all(is.finite(f@table$est)))
  expect_equal(unname(f@table$est), unname(ft@table$est), tolerance = 1e-8)
  expect_equal(unname(f@table$se), unname(ft@table$se), tolerance = 1e-6)
  if (loglik) {
    expect_equal(as.numeric(logLik(f)), as.numeric(logLik(ft)), tolerance = 1e-8)
  }
  expect_equal(f@n_obs, ft@n_obs)
  expect_equal(f@n_dropped, ft@n_dropped)
}

test_that("an NA in the factor drops the row once; the fit and the message equal the twin's", {
  d <- fm_data()
  d$g[c(3, 40, 77)] <- NA
  r <- fm_msgs(fit_sem(fm_model, d))
  rt <- fm_msgs(fit_sem(fm_twin_model, fm_twin(d)))
  expect_equal(r$value@n_obs, nrow(d) - 3L)
  expect_equal(r$value@n_dropped, 3L)
  expect_equal(r$messages, rt$messages)
  expect_match(r$messages, "3 of 160 rows dropped")
  fm_same(r$value, rt$value)
})

test_that("an NA in the outcome drops the row, and the row's dummies go with it", {
  d <- fm_data()
  d$y[c(5, 6, 90, 91)] <- NA
  f <- suppressMessages(fit_sem(fm_model, d))
  ft <- suppressMessages(fit_sem(fm_twin_model, fm_twin(d)))
  expect_equal(f@n_obs, nrow(d) - 4L)
  expect_equal(nrow(f@data), f@n_obs)
  fm_same(f, ft)
})

test_that("NAs in the factor and the outcome on different rows drop each row once", {
  d <- fm_data()
  d$g[1:4] <- NA
  d$y[3:8] <- NA
  f <- suppressMessages(fit_sem(fm_model, d))
  expect_equal(f@n_dropped, 8L) # rows 1-8, row 3 and 4 counted once
})

test_that("sampling weights are not changed by the expansion", {
  d <- fm_data()
  set.seed(5)
  w <- runif(nrow(d), 0.5, 2)
  f <- fit_sem(fm_model, d, weights = w, se_type = "sandwich")
  ft <- fit_sem(fm_twin_model, fm_twin(d), weights = w, se_type = "sandwich")
  fm_same(f, ft, loglik = FALSE) # logLik() is undefined for a weighted fit
  d$g[2] <- NA
  f2 <- suppressMessages(fit_sem(fm_model, d, weights = w, se_type = "sandwich"))
  ft2 <- suppressMessages(fit_sem(fm_twin_model, fm_twin(d), weights = w, se_type = "sandwich"))
  fm_same(f2, ft2, loglik = FALSE)
})

test_that("a level present only in dropped rows is an error that names the dummy and the cause", {
  d <- fm_data()
  d$y[d$g == "c"] <- NA
  expect_error(suppressMessages(fit_sem(fm_model, d)), "`g_c`.*level 'c' of `g`.*dropped for missing values")
})

test_that("a declared level that no row has is an error that names the dummy", {
  d <- fm_data()
  d$g <- factor(as.character(d$g), levels = c("a", "b", "c", "z"))
  expect_error(fit_sem(fm_model, d), "`g_z`.*level 'z' of `g`.*no row")
})

test_that("a dummy that is 1 in every row the fit uses is an error naming it", {
  d <- fm_data()
  d$g <- droplevels(d$g[, drop = TRUE])
  d$g <- factor(as.character(d$g), levels = c("a", "b"))
  d$g[is.na(d$g)] <- "b"
  d$y[d$g == "a"] <- NA
  expect_error(suppressMessages(fit_sem(fm_model, d)), "`g_b`.*level 'b' of `g`.*every row")
})

test_that("a logical covariate that is constant gets the same error", {
  d <- fm_data()
  d$g <- TRUE
  expect_error(fit_sem("m ~ x + g\ny ~ m + g", d), "`g_TRUE`.*every row")
})

test_that("an mbco_sem() refit after deletion equals the twin's (the stored data holds only kept rows)", {
  d <- fm_data()
  d$g[c(2, 30)] <- NA
  f <- suppressMessages(fit_sem(fm_model, d))
  r <- mbco_sem(f, paths = c("a", "b"))
  rt <- mbco_sem(suppressMessages(fit_sem(fm_twin_model, fm_twin(d))), paths = c("a", "b"))
  expect_true(is.finite(r$statistic))
  expect_equal(r$statistic, rt$statistic, tolerance = 1e-6)
})

test_that("a logical covariate with NAs: the cause is named for both ways the dummy can go constant", {
  d <- fm_data()
  d$L <- rep(c(TRUE, FALSE), length.out = nrow(d))
  d$y[!d$L] <- NA # only TRUE rows survive: g_TRUE is 1 everywhere
  expect_error(suppressMessages(fit_sem("m ~ x + L\ny ~ m + L", d)), "`L_TRUE`.*every row the fit uses")
  d <- fm_data()
  d$L <- rep(c(TRUE, FALSE), length.out = nrow(d))
  d$y[d$L] <- NA # TRUE occurs only in dropped rows
  expect_error(suppressMessages(fit_sem("m ~ x + L\ny ~ m + L", d)), "`L_TRUE`.*only in rows dropped")
})

test_that("a level whose rows all have zero weight is an error naming the dummy", {
  d <- fm_data()
  w <- ifelse(d$g == "c", 0, 1)
  expect_error(fit_sem(fm_model, d, weights = w, se_type = "sandwich"), "`g_c`.*zero weight")
})

test_that("the named error holds with a zero-product constraint, a mean structure, a product and fixed_x", {
  d <- fm_data()
  d$g <- factor(as.character(d$g), levels = c("a", "b", "c", "z"))
  cases <- list(
    paste0(fm_model, "\na*b == 0"),
    paste0(fm_model, "\nm ~ 1"),
    "m ~ a*x + g\ny ~ b*m + g + x:m"
  )
  for (mod in cases) {
    expect_error(suppressMessages(fit_sem(mod, d)), "`g_z`.*no row has this level", info = mod)
  }
  expect_error(fit_sem(fm_model, d, fixed_x = "g"), "`g_z`.*no row has this level")
})

test_that("a dummy used only in the outcome equation is checked too", {
  d <- fm_data()
  d$y[d$g == "c"] <- NA
  expect_error(suppressMessages(fit_sem("m ~ x\ny ~ m + g", d)), "`g_c`")
})

test_that("an all-NA outcome keeps the existing error, not a factor message", {
  d <- fm_data()
  d$y <- NA_real_
  expect_error(suppressMessages(fit_sem(fm_model, d)), "must be numeric: y|no complete|at least 1 rows")
  expect_false(inherits(try(suppressMessages(fit_sem(fm_model, d)), silent = TRUE), "SEMFit"))
})

test_that("planted defect: dummies built after listwise deletion lose the level silently and the test catches it", {
  fx_skip_covr()
  d <- fm_data()
  d$g <- as.character(d$g)
  d$y[d$g == "c"] <- NA
  expect_error(suppressMessages(fit_sem(fm_model, d)), "`g_c`")
  orig <- .sem_expand_factors
  late <- function(...) {
    a <- list(...)
    vars <- intersect(c(a[[1]]$lhs, a[[1]]$rhs), names(a[[2]]))
    a[[2]] <- a[[2]][stats::complete.cases(a[[2]][, vars, drop = FALSE]), , drop = FALSE]
    do.call(orig, a)
  }
  testthat::local_mocked_bindings(.sem_expand_factors = late)
  # the defect: no error, a smaller model, the level quietly dropped
  f <- suppressMessages(fit_sem(fm_model, d))
  expect_false("g_c" %in% f@table$rhs)
  expect_true("g_b" %in% f@table$rhs)
  expect_equal(f@n_obs, sum(!is.na(d$y)))
})

test_that("the zero-product precheck sees product inputs: a level lost to an NA in a product factor is named", {
  d <- fm_data()
  set.seed(9)
  d$z <- rnorm(nrow(d))
  d$w <- rnorm(nrow(d))
  d$z[d$g == "c"] <- NA # z occurs only inside the product z:w, so the rows go at materialization
  mod <- "m ~ a*x + g + z:w\ny ~ b*m + g\na*b == 0"
  # anchored: the precheck's purpose is the named error itself, not the "no branch converged" wrapper around it
  expect_error(suppressMessages(fit_sem(mod, d)), "^dummy `g_c`.*only in rows dropped for missing values")
})

test_that("the precheck rows match the fit's: a latent that shares a name with a data column is not an input", {
  set.seed(12)
  n <- 220L
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  eta <- rnorm(n)
  d <- data.frame(x1 = eta + rnorm(n, sd = 0.5), x2 = 0.8 * eta + rnorm(n, sd = 0.5),
                  x3 = 0.7 * eta + rnorm(n, sd = 0.5), g = g)
  d$m <- 0.5 * eta + 0.4 * (g == "b") + rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * (g == "c") + rnorm(n)
  d$L <- NA_real_ # a data column named like the latent, unrelated to it, NA where g == "c"
  d$L[g != "c"] <- 0
  mod <- "L =~ x1 + x2 + x3\nm ~ a*L + g\ny ~ b*m + g\na*b == 0"
  expect_s7_class(suppressWarnings(suppressMessages(fit_sem(mod, d))), SEMFit)
})

test_that("the named zero-product error holds with a product input also used elsewhere, weights, and fixed_x", {
  d <- fm_data()
  set.seed(9)
  d$z <- rnorm(nrow(d))
  d$w <- rnorm(nrow(d))
  d$z[d$g == "c"] <- NA
  other <- "m ~ a*x + g + z:w\ny ~ b*m + g + z\na*b == 0"
  expect_error(suppressMessages(fit_sem(other, d)), "^dummy `g_c`.*dropped for missing values")
  mod <- "m ~ a*x + g + z:w\ny ~ b*m + g\na*b == 0"
  expect_error(suppressMessages(fit_sem(mod, d, weights = runif(nrow(d), 0.5, 2), se_type = "sandwich")),
               "^dummy `g_c`")
  expect_error(suppressMessages(fit_sem(mod, d, fixed_x = "g")), "^dummy `g_c`")
})
