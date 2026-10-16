# Native SEM engine: product materialization (0.10.0 plan U3, amendment rule 7). `fit_sem()` builds each `x:m`
# term as a data column `x * m` named by the canonical product name, before the fixed_x moments are assigned and
# before listwise deletion. A pre-existing column is used only if it equals the product on the rows used.

pm_data <- function(n = 300L, seed = 41L) {
  set.seed(seed)
  x <- rnorm(n)
  m <- 0.5 * x + rnorm(n)
  y <- 0.3 * x + 0.4 * m + 0.25 * x * m + rnorm(n)
  data.frame(y = y, x = x, m = m)
}
pm_model <- "y ~ x + m + x:m\nm ~ x"

test_that("a product term fits from data without a prebuilt column", {
  d <- pm_data()
  fit <- fit_sem(pm_model, d)
  expect_true(fit@converged)
  expect_true("y~m:x" %in% names(coef(fit)))
  expect_false("y~x:m" %in% names(coef(fit)))
  expect_true("m:x" %in% fit@internals$ram$obs)
  expect_identical(fit@table$rhs[fit@table$op == "~" & grepl(":", fit@table$rhs)], "m:x")
})

test_that("both spellings in the syntax give identical fits", {
  d <- pm_data()
  a <- fit_sem("y ~ x + m + x:m\nm ~ x", d)
  b <- fit_sem("y ~ x + m + m:x\nm ~ x", d)
  expect_identical(names(coef(a)), names(coef(b)))
  expect_equal(coef(a), coef(b), tolerance = 1e-12)
  expect_equal(vcov(a), vcov(b), tolerance = 1e-12)
})

test_that("an explicit user-built column equals the materialized fit", {
  d <- pm_data()
  mat <- fit_sem(pm_model, d)
  for (nm in c("m:x", "x:m")) {
    d2 <- d
    d2[[nm]] <- d$x * d$m
    own <- fit_sem(pm_model, d2)
    expect_equal(coef(own), coef(mat), tolerance = 1e-12, info = nm)
    expect_equal(sqrt(diag(vcov(own))), sqrt(diag(vcov(mat))), tolerance = 1e-12, info = nm)
    expect_identical(names(coef(own)), names(coef(mat)))
  }
})

test_that("a mismatched pre-existing column errors, naming the column and both options", {
  d <- pm_data()
  for (nm in c("m:x", "x:m")) {
    d2 <- d
    d2[[nm]] <- d$x * d$m + 0.01
    expect_error(fit_sem(pm_model, d2), paste0("`", nm, "` in `data` is not the product"), fixed = TRUE)
    expect_error(fit_sem(pm_model, d2), "rename it, or drop it", fixed = TRUE)
  }
  d3 <- d
  d3[["m:x"]] <- as.character(d$x * d$m)
  expect_error(fit_sem(pm_model, d3), "is not the product")
})

test_that("a factor must be numeric, and an absent factor keeps the absent-column error", {
  d <- pm_data()
  d$m <- factor(sample(c("a", "b"), nrow(d), TRUE))
  expect_error(fit_sem("y ~ x + x:m", d), "needs numeric variables, but m is not numeric")
  d <- pm_data()
  d$m <- NULL
  expect_error(fit_sem("y ~ x + x:m", d), "not columns of `data`: m:x")
})

test_that("missing rows are dropped listwise and a matching pre-existing column survives the NAs", {
  d <- pm_data()
  d$x[c(3, 50)] <- NA
  d$m[7] <- NA
  expect_message(fit <- fit_sem(pm_model, d), "3 of 300 rows dropped")
  expect_identical(as.integer(fit@n_obs), 297L)
  d2 <- d
  d2[["m:x"]] <- d$x * d$m
  expect_message(own <- fit_sem(pm_model, d2), "3 of 300 rows dropped")
  expect_equal(coef(own), coef(fit), tolerance = 1e-12)
  # a mismatch on a dropped row is invisible; on a kept row it errors
  d3 <- d2
  d3[["m:x"]][3] <- 99
  expect_message(fit_sem(pm_model, d3), "dropped")
  d3[["m:x"]][4] <- 99
  expect_error(suppressMessages(fit_sem(pm_model, d3)), "is not the product")
})

test_that("weights work with a product term", {
  d <- pm_data()
  w <- runif(nrow(d), 0.5, 1.5)
  fit <- fit_sem(pm_model, d, weights = w, se_type = "sandwich")
  d$xm <- d$x * d$m
  # the product model fits the mean structure (U5), so the precomputed-column reference does too
  ref <- fit_sem("y ~ x + m + xm\nm ~ x", d, weights = w, se_type = "sandwich", meanstructure = TRUE)
  expect_equal(unname(coef(fit)), unname(coef(ref)), tolerance = 1e-6)
  expect_identical(gsub("m:x", "xm", names(coef(fit)), fixed = TRUE), names(coef(ref)))
})

test_that("the product slope and its standard error equal the OLS values (mean-structure model)", {
  d <- pm_data(n = 500L)
  fit <- fit_sem("y ~ 1 + x + m + x:m\nm ~ 1 + x", d)
  ols <- lm(y ~ x + m + I(x * m), d)
  est <- coef(ols)
  # SLSQP stops about 5e-8 from the optimum (the optimizer's convergence criterion), so 1e-6 leaves a margin of
  # twenty without admitting a wrong model.
  expect_equal(unname(coef(fit)["y~m:x"]), unname(est["I(x * m)"]), tolerance = 1e-6)
  expect_equal(unname(coef(fit)["y~x"]), unname(est["x"]), tolerance = 1e-6)
  expect_equal(unname(coef(fit)["y~m"]), unname(est["m"]), tolerance = 1e-6)
  expect_equal(unname(coef(fit)["y~1"]), unname(est["(Intercept)"]), tolerance = 1e-6)
  # ML divides by n, OLS by n - k: the SEs differ by that factor
  k <- length(est)
  se_ols <- sqrt(diag(vcov(ols))) * sqrt((nrow(d) - k) / nrow(d))
  se <- sqrt(diag(vcov(fit)))
  expect_equal(unname(se["y~m:x"]), unname(se_ols["I(x * m)"]), tolerance = 1e-4)
  # a mediator covariate: m ~ x is the other equation
  expect_equal(unname(coef(fit)["m~x"]), unname(coef(lm(m ~ x, d))["x"]), tolerance = 1e-6)
})

test_that("fixed_x = TRUE with a product: its row gets the sample moment and every other row keeps its value", {
  d <- pm_data()
  fit <- fit_sem(pm_model, d, fixed_x = TRUE)
  tab <- fit@table
  fx <- tab[tab$fixed_x, ]
  expect_true("m:x" %in% c(fx$lhs, fx$rhs))
  expect_false(anyNA(fx$est))
  xm <- d$x * d$m
  var_row <- fx[fx$lhs == "m:x" & fx$op == "~~" & fx$rhs == "m:x", ]
  expect_equal(var_row$est, mean((xm - mean(xm))^2), tolerance = 1e-12)
  vx <- fx[fx$lhs == "x" & fx$op == "~~" & fx$rhs == "x", ]
  expect_equal(vx$est, mean((d$x - mean(d$x))^2), tolerance = 1e-12)
  cov_row <- fx[(fx$lhs == "x" & fx$rhs == "m:x") | (fx$lhs == "m:x" & fx$rhs == "x"), ]
  expect_equal(cov_row$est[1], mean((d$x - mean(d$x)) * (xm - mean(xm))), tolerance = 1e-12)
  # structural estimates match the free fit
  free <- fit_sem(pm_model, d)
  sh <- intersect(names(coef(free)), names(coef(fit)))
  sh <- sh[grepl("^[ym]~[a-z]", sh) & !grepl("~~", sh)]
  expect_true(length(sh) >= 3L)
  expect_equal(coef(fit)[sh], coef(free)[sh], tolerance = 1e-5)
})

test_that("fits without a product are unchanged by the materializer", {
  d <- pm_data()
  plain <- fit_sem("y ~ x + m\nm ~ x", d)
  expect_false(any(grepl(":", names(coef(plain)))))
  out <- .sem_materialize_products(plain@table, d)
  expect_identical(out$checks, list())
  expect_identical(out$data, d)
})

test_that("planted defect (a): checking the pre-existing column before deletion fails on data with NAs", {
  fx_skip_covr()
  d <- pm_data()
  d$x[3] <- NA
  d[["m:x"]] <- d$x * d$m
  expect_message(fit_sem(pm_model, d), "dropped") # the real code accepts it
  bad <- sem_mutate(.sem_fit_syntax, ".sem_check_product_columns(mat$checks, keep)",
                    ".sem_check_product_columns(mat$checks, rep(TRUE, length(keep)))")
  expect_error(suppressMessages(bad(pm_model, d)), "is not the product")
})

test_that("planted defect (b): a wrongly ordered column name breaks the table, coef() and the lookup", {
  fx_skip_covr()
  d <- pm_data()
  bad <- sem_mutate(.sem_materialize_products, "data[[.sem_product_name(f[1L], f[2L])]] <- built",
                    "data[[paste(rev(f), collapse = \":\")]] <- built")
  testthat::local_mocked_bindings(.sem_materialize_products = bad)
  # the model names the canonical m:x; with the column named x:m the fit cannot find it
  expect_error(fit_sem("y ~ x + m + x:m", d), "not columns of `data`: m:x")
  # and the helper's output no longer holds the column a lookup by .sem_product_name() asks for
  out <- bad(.sem_parse("y ~ x + m + x:m")$parameters, d)$data
  expect_false(.sem_product_name("x", "m") %in% names(out))
})

test_that("planted defect (c): building after the absent-column check leaves every fixed_x row unassigned", {
  fx_skip_covr()
  d <- pm_data()
  ok <- fit_sem(pm_model, d, fixed_x = TRUE)
  expect_false(anyNA(ok@table$est[ok@table$fixed_x]))
  bad <- sem_mutate(.sem_fit_syntax, ".sem_assign_fixed_x(tab, mat$data, weights)",
                    ".sem_assign_fixed_x(tab, data, weights)")
  # the fixed rows stay unassigned, so the model counts their parameters as free and runs out of moments
  expect_error(bad(pm_model, d, fixed_x = TRUE), "more free parameters")
})
