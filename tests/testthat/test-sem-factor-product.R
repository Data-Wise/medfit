# T6: a factor in a product (F5, D3, D4). `g:m` expands to one product per dummy (`g_b:m`, `g_c:m`), each through the
# canonical product name and rules 8 and 9. Oracles: the hand-coded twin, `lm()` per equation (a recursive model with
# products equals equation-wise OLS), and the model-test policy of the twin.

fp2_data <- function(n = 260L, seed = 41L) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  x <- rnorm(n)
  f <- 0.4 * x + rnorm(n)
  m <- 0.5 * x + 0.5 * (g == "b") + rnorm(n)
  y <- 0.4 * m + 0.2 * x + 0.3 * (g == "c") + 0.25 * m * (g == "b") + rnorm(n)
  d <- data.frame(y = y, m = m, x = x, f = f, g = g)
  list(factor = d, twin = transform(d, g_b = as.numeric(g == "b"), g_c = as.numeric(g == "c")))
}
fp2_same <- function(f, ft, info = NULL) {
  testthat::expect_true(all(is.finite(f@table$est)), info = info)
  testthat::expect_equal(f@table$rhs, ft@table$rhs, info = info)
  testthat::expect_equal(unname(f@table$est), unname(ft@table$est), tolerance = 1e-8, info = info)
  testthat::expect_equal(unname(f@table$se), unname(ft@table$se), tolerance = 1e-6, info = info)
  testthat::expect_equal(as.numeric(logLik(f)), as.numeric(logLik(ft)), tolerance = 1e-8, info = info)
  testthat::expect_equal(f@df, ft@df, info = info)
}
fp2_fit <- function(model, d) suppressMessages(suppressWarnings(fit_sem(model, d)))

test_that("g:m expands to one product per dummy and equals the hand-coded product twin", {
  d <- fp2_data()
  f <- fp2_fit("m ~ a*x + g\ny ~ b*m + x + g + g:m", d$factor)
  ft <- fp2_fit("m ~ a*x + g_b + g_c\ny ~ b*m + x + g_b + g_c + g_b:m + g_c:m", d$twin)
  fp2_same(f, ft)
  expect_setequal(f@table$rhs[f@table$lhs == "y" & f@table$op == "~"], c("m", "x", "g_b", "g_c", "g_b:m", "g_c:m"))
})

test_that("m:g is the same term as g:m", {
  d <- fp2_data()
  f1 <- fp2_fit("m ~ x\ny ~ m + x + g + g:m", d$factor)
  f2 <- fp2_fit("m ~ x\ny ~ m + x + g + m:g", d$factor)
  expect_equal(unname(f1@table$est), unname(f2@table$est), tolerance = 1e-10)
  expect_equal(f1@table$rhs, f2@table$rhs)
})

test_that("a factor that appears only inside a product still expands (no bare g term)", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + g:m", d$factor)
  ft <- fp2_fit("m ~ x\ny ~ m + x + g_b:m + g_c:m", d$twin)
  fp2_same(f, ft)
  expect_false(any(c("g_b", "g_c") %in% f@table$rhs[f@table$op == "~"]))
})

test_that("the estimates equal equation-wise OLS (independent oracle)", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + g + g:m", d$factor)
  ols <- stats::coef(stats::lm(y ~ m + x + g_b + g_c + g_b:m + g_c:m, d$twin))
  est <- f@table[f@table$lhs == "y" & f@table$op == "~", ]
  got <- stats::setNames(est$est, est$rhs)
  expect_true(all(is.finite(got)))
  # lm names an interaction in term order: m:g_b for the medfit term g_b:m
  expect_equal(unname(got[c("m", "x", "g_b", "g_c", "g_b:m", "g_c:m")]),
               unname(ols[c("m", "x", "g_b", "g_c", "m:g_b", "m:g_c")]), tolerance = 1e-6)
})

test_that("an explicit dummy product next to the bare factor product keeps its row and label, once", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + g + g:m + b*g_b:m", d$factor)
  rows <- f@table[f@table$lhs == "y" & f@table$op == "~", ]
  expect_equal(sum(rows$rhs == "g_b:m"), 1L)
  expect_equal(rows$label[rows$rhs == "g_b:m"], "b")
  expect_equal(sum(rows$rhs == "g_c:m"), 1L)
})

test_that("a single dummy product can be named (g_b:m) and only that product is built", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + g_b:m", d$factor)
  expect_true("g_b:m" %in% f@table$rhs)
  expect_false("g_c:m" %in% f@table$rhs)
  expect_false("g_c" %in% f@internals$ram$obs)
})

test_that("a product of two categorical columns, or of one with itself, is an error naming both", {
  d <- fp2_data()
  d$factor$h <- factor(sample(c("u", "v"), nrow(d$factor), replace = TRUE))
  expect_error(fit_sem("y ~ m + g:h", d$factor), "`g:h`.*both.*categorical")
  expect_error(fit_sem("y ~ m + g:g", d$factor), "'g:g' of a variable with itself")
})

test_that("a label or fixed value on a factor product is an error that names the dummy products", {
  d <- fp2_data()
  expect_error(fit_sem("m ~ x\ny ~ m + b*g:m", d$factor), "`b\\*g:m`.*g_b:m, g_c:m")
  expect_error(fit_sem("m ~ x\ny ~ m + 0.5*g:m", d$factor), "g_b:m, g_c:m")
})

test_that("the model-test policy is the twin's: chi-square NA, anova and mbco_sem refuse alike", {
  d <- fp2_data()
  f <- fp2_fit("m ~ a*x\ny ~ b*m + g + g:m", d$factor)
  ft <- fp2_fit("m ~ a*x\ny ~ b*m + g_b + g_c + g_b:m + g_c:m", d$twin)
  expect_true(is.na(generics::glance(f)$chisq))
  expect_equal(is.na(generics::glance(f)$chisq), is.na(generics::glance(ft)$chisq))
  msg <- function(fit) tryCatch(mbco_sem(fit, paths = c("a", "b")), error = function(e) conditionMessage(e))
  expect_type(msg(f), "character")
  expect_equal(gsub("g_b|g_c|g", "G", msg(f)), gsub("g_b|g_c|g", "G", msg(ft)))
})

test_that("a factor product with exogenous factors fits as the twin; mbco_sem() reaches the same refit error", {
  d <- fp2_data()
  f <- fp2_fit("m ~ a*x\ny ~ b*m + x + g + g:x", d$factor)
  ft <- fp2_fit("m ~ a*x\ny ~ b*m + x + g_b + g_c + g_b:x + g_c:x", d$twin)
  fp2_same(f, ft)
  expect_false(is.na(generics::glance(f)$chisq))
  # a refit with a label constraint is refused with products (rule 9) the same way for the twin; a missing-column
  # error here would mean the factor was not rewritten through the stored map
  msg <- function(fit) tryCatch(mbco_sem(fit, paths = c("a", "b")), error = function(e) conditionMessage(e))
  expect_match(msg(f), "rule 9")
  expect_equal(msg(f), msg(ft))
})

test_that("fixed_x names the factor of a product: the dummies are fixed as in the twin", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + g + g:x", d$factor)
  f2 <- suppressMessages(suppressWarnings(fit_sem("m ~ x\ny ~ m + x + g + g:x", d$factor, fixed_x = "g")))
  ft2 <- suppressMessages(suppressWarnings(
    fit_sem("m ~ x\ny ~ m + x + g_b + g_c + g_b:x + g_c:x", d$twin, fixed_x = c("g_b", "g_c"))
  ))
  expect_true(all(is.finite(f@table$est)))
  fp2_same(f2, ft2)
})

test_that("the product row is named in the canonical order for any variable name", {
  fx_skip_covr()
  d <- fp2_data()
  f <- fp2_fit("f ~ x\ny ~ f + x + g + g:f", d$factor) # `f` sorts before `g_b`: the canonical name is f:g_b
  expect_true("f:g_b" %in% f@table$rhs)
  bad <- sem_mutate(.sem_row_expansion, ".sem_product_name(d, other)", "paste0(d, \":\", other)")
  testthat::local_mocked_bindings(.sem_row_expansion = bad)
  expect_error(fit_sem("f ~ x\ny ~ f + x + g + g:f", d$factor), "not columns of `data`: g_b:f")
})

test_that("the four-way decomposition refuses a factor product and says the effects differ by the factor (D4)", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x + g\ny ~ x + m + x:m + g + g:m", d$factor)
  expect_error(extract_mediation(f, treatment = "x", mediator = "m"), "differ by `g`")
  expect_error(extract_mediation(f, treatment = "x", mediator = "m"), "g_b:m|g_c:m")
})

test_that("a model without a factor product is unchanged by the product expansion", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + x:m", d$factor[, c("y", "m", "x")])
  expect_true("m:x" %in% f@table$rhs)
})

test_that("a product-only factor: a dummy made constant by an NA in the other side is named", {
  d <- fp2_data()
  d$factor$m[d$factor$g == "c"] <- NA # g_c is constant (0) in the rows left, and g appears only inside g:m
  expect_error(suppressMessages(fit_sem("m ~ x\ny ~ m + x + g:m", d$factor)), "^dummy `g_c`.*only in rows dropped")
})

test_that("a product-only factor: a level whose rows all have zero weight is named", {
  d <- fp2_data()
  w <- ifelse(d$factor$g == "c", 0, 1)
  expect_error(fit_sem("m ~ x\ny ~ m + g:x", d$factor, weights = w, se_type = "sandwich"),
               "^dummy `g_c`.*zero weight")
})

test_that("a product-only factor: mbco_sem() reaches the same refit error as the twin (not a missing-column error)", {
  d <- fp2_data()
  f <- fp2_fit("m ~ a*x\ny ~ b*m + x + g:x", d$factor)
  ft <- fp2_fit("m ~ a*x\ny ~ b*m + x + g_b:x + g_c:x", d$twin)
  fp2_same(f, ft)
  msg <- function(fit) tryCatch(mbco_sem(fit, paths = c("a", "b")), error = function(e) conditionMessage(e))
  expect_match(msg(f), "rule 9")
  expect_equal(msg(f), msg(ft))
})

test_that("the stored map rewrites product rows when the factor column is absent (direct, below the public API)", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + g + g:m", d$factor)
  tab <- .sem_parse("m ~ x\ny ~ m + x + g + g:m")$parameters
  out <- .sem_expand_factors(tab, f@data, FALSE, factors = f@internals$factors)
  expect_setequal(out$table$rhs[out$table$lhs == "y"], c("m", "x", "g_b", "g_c", "g_b:m", "g_c:m"))
  # product-only: the stored data holds the product columns, not the dummies
  f2 <- fp2_fit("m ~ x\ny ~ m + x + g:x", d$factor)
  expect_false(any(c("g_b", "g_c") %in% names(f2@data)))
  tab2 <- .sem_parse("m ~ x\ny ~ m + x + g:x")$parameters
  out2 <- .sem_expand_factors(tab2, f2@data, FALSE, factors = f2@internals$factors)
  expect_setequal(out2$table$rhs[out2$table$lhs == "y"], c("m", "x", "g_b:x", "g_c:x"))
})

test_that("fixed_x naming a product-only factor gets a message that says so", {
  d <- fp2_data()
  expect_error(fit_sem("m ~ x\ny ~ m + x + g:x", d$factor, fixed_x = "g"), "`g`, which appears only inside products")
})

test_that("a latent named like a generated dummy is an error", {
  d <- fp2_data()
  expect_error(fit_sem("g_b =~ x + f\nm ~ g_b + x\ny ~ m + g:m", d$factor), "g_b.*already a column|collid|latent")
})

test_that("a product of dummy references of two factor columns fits, equals the twin, and is what `g:h` suggests", {
  d <- fp2_data()
  set.seed(3)
  d$factor$h <- factor(sample(c("u", "v"), nrow(d$factor), replace = TRUE))
  d$twin$h <- d$factor$h
  d$twin$h_v <- as.numeric(d$twin$h == "v")
  err <- tryCatch(fit_sem("m ~ x\ny ~ m + x + g:h", d$factor), error = function(e) conditionMessage(e))
  expect_match(err, "g_b:h_v", fixed = TRUE)
  f <- fp2_fit("m ~ x\ny ~ m + x + g_b:h_v", d$factor)
  ft <- fp2_fit("m ~ x\ny ~ m + x + g_b:h_v", d$twin)
  fp2_same(f, ft)
})

test_that("the reversed spelling of an explicit dummy product dedupes against the bare factor product", {
  d <- fp2_data()
  f <- fp2_fit("m ~ x\ny ~ m + x + g:m + b*m:g_b", d$factor)
  rows <- f@table[f@table$lhs == "y" & f@table$op == "~", ]
  expect_equal(sum(rows$rhs == "g_b:m"), 1L)
  expect_equal(rows$label[rows$rhs == "g_b:m"], "b")
})

test_that("a logical covariate in a product expands to its one dummy product", {
  d <- fp2_data()
  d$factor$L <- rep(c(TRUE, FALSE), length.out = nrow(d$factor))
  f <- fp2_fit("m ~ x\ny ~ m + x + L + L:m", d$factor)
  expect_true(all(c("L_TRUE", "L_TRUE:m") %in% f@table$rhs))
})
