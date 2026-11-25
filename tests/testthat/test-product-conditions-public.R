# QA (P2(c)): the product refusals as a user reaches them. test-product-conditions.R triggers the syntax refusals
# through the internal `.sem_parse()`; `fit_sem()` re-raises a parse error in `.sem_fit_syntax()`, and `mbco_sem()` wraps
# a refit failure, so a class set at the source can be lost on the way out. Each case here goes through the exported
# function a user calls and asks for the same classes.

pcp_data <- function(n = 120L, seed = 5L) {
  withr::local_seed(seed)
  d <- data.frame(x = rnorm(n), w = rnorm(n), c = rnorm(n))
  d$m <- 0.5 * d$x + rnorm(n)
  d$y <- 0.4 * d$m + 0.3 * d$x + 0.2 * d$x * d$w + rnorm(n)
  d$g <- factor(sample(c("a", "b", "c"), n, TRUE))
  d$h <- factor(sample(c("u", "v"), n, TRUE))
  d
}
pcp_err <- function(expr) tryCatch({ force(expr); NULL }, error = function(e) e)

# list(class, message fragment, exported trigger)
pcp_cases <- function() {
  list(
    list("medfit_error_product_syntax", "needs a variable name on each side",
         function() fit_sem("y ~ x + x :w", pcp_data())),
    list("medfit_error_product_syntax", "of a variable with itself", function() fit_sem("y ~ x:x", pcp_data())),
    list("medfit_error_product_syntax", "three-way or higher", function() fit_sem("y ~ x:w:c", pcp_data())),
    list("medfit_error_product_syntax", "cannot be a left side", function() fit_sem("x:w ~ y", pcp_data())),
    list("medfit_error_product_syntax", "only valid on the right side of a regression",
         function() fit_sem("eta =~ x:w", pcp_data())),
    list("medfit_error_product_syntax", "not inside the expression",
         function() fit_sem("m ~ a*x\ny ~ b*m + x:w\nab := a:b", pcp_data())),
    # reachable through a numeric factor (the tokenizer lets `:.5` through): the "unreachable" defensive branch
    list("medfit_error_product_syntax", "malformed product", function() fit_sem("y ~ x:.5", pcp_data())),
    list("medfit_error_product_syntax", "malformed product", function() .sem_parse("y ~ .5:x")),
    list("medfit_error_product_latent", "involves a latent variable",
         function() fit_sem("eta =~ m + y + c\nw ~ eta + x\nw ~ eta:x", pcp_data())),
    list("medfit_error_product_duplicate", "are the same product", function() fit_sem("y ~ x:w + w:x", pcp_data())),
    # categorical columns (sem-factor.R): two categorical sides; fixed_x naming a column that only appears in products
    list("medfit_error_product_syntax", "both sides are categorical columns", function() fit_sem("y ~ g:h", pcp_data())),
    list("medfit_error_product_syntax", "appears only inside products",
         function() fit_sem("y ~ g:x + m", pcp_data(), fixed_x = "g")),
    # mbco_sem() refits with `a == 0` on a supported product model; the rule-9 refusal is wrapped in the refit message
    list("medfit_error_product_constraint", "names the coefficient label", function() {
      f <- suppressWarnings(fit_sem("m ~ a*x\ny ~ b*m + x + x:w", pcp_data(), se_type = "sandwich"))
      mbco_sem(f, paths = c("a", "b"))
    })
  )
}

test_that("a product refusal reached through fit_sem() and mbco_sem() keeps its class, parent class and message", {
  for (case in pcp_cases()) {
    err <- pcp_err(case[[3L]]())
    info <- paste(case[[1L]], case[[2L]])
    expect_false(is.null(err), info = info)
    expect_true(inherits(err, case[[1L]]), info = info)
    expect_true(inherits(err, "medfit_error_product"), info = info)
    expect_match(conditionMessage(err), case[[2L]], fixed = TRUE, info = info)
  }
})
