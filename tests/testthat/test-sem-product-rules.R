# Native SEM engine: validity rules 8 and 9 for product terms (0.10.0 plan U4, amendment section 4 rules 8 and 9,
# GRILL H6). Rule 8 rejects a product whose factor is the equation's target or one of its descendants; rule 9
# rejects a product model outside the supported class (recursive, no residual covariance, no shared or fixed
# regression coefficient, no constraint on a coefficient, free and unshared intercepts). Every check reads the parsed
# or completed table, never data. Each rejected model is accepted again once its product term is removed.

pr_ok <- function(syntax, ...) {
  .sem_complete(.sem_parse(syntax)$parameters, ...)
}
pr_err <- function(syntax, pattern, ...) {
  expect_error(pr_ok(syntax, ...), pattern)
}

test_that("rule 8: a product factor that is the target or downstream of it is rejected", {
  pr_err("y ~ x + x:y", "equation for 'y'.*'x:y' uses 'y'.*target of its own equation")
  pr_err("y ~ y:x + x", "'x:y' uses 'y'")
  pr_err("y ~ x:z\nz ~ y", "'x:z' uses 'z'.*downstream of the target 'y'")
  pr_err("y ~ x:z\nz ~ w:y", "'x:z' uses 'z'.*downstream")
  pr_err("y ~ x:z\nz ~ w:u\nu ~ v:y", "'x:z' uses 'z'.*downstream")
  # an indicator of a latent target
  pr_err("eta =~ i1 + i2 + i3\neta ~ x:i1", "uses 'i1'.*downstream of the target 'eta'")
})

test_that("rule 8: a factor that is not downstream is accepted, and each rejection is accepted without the product", {
  expect_no_error(suppressMessages(pr_ok("y ~ x:z\nz ~ w")))
  expect_no_error(pr_ok("m ~ x\ny ~ m + x + x:m"))
  for (syn in c("y ~ x\nx ~ w", "y ~ x + z\nz ~ y", "y ~ x + z\nz ~ w + y", "eta =~ i1 + i2 + i3\neta ~ x")) {
    expect_no_error(pr_ok(syn))
  }
})

test_that("rule 8 needs no data and fails before the fit", {
  expect_error(pr_ok("y ~ x + x:y"), "rule 8")
  d <- data.frame(y = rnorm(40), x = rnorm(40))
  expect_error(fit_sem("y ~ x + x:y", d), "rule 8")
})

test_that("rule 9: a nonrecursive loop with a product is rejected", {
  pr_err("y ~ z + x:w\nz ~ y", "not recursive")
  expect_no_error(pr_ok("y ~ z + x\nz ~ y")) # 0.8.0 behavior without a product
})

test_that("rule 9: a shared regression label, a fixed coefficient and a constraint on a coefficient are rejected", {
  pr_err("m ~ a*x\ny ~ a*m + x:m", "label 'a' is used on more than one parameter")
  pr_err("m ~ x\ny ~ 0.3*x + x:m", "fixed coefficient")
  pr_err("m ~ x\ny ~ 0*x + x:m", "fixed coefficient")
  pr_err("m ~ a*x\ny ~ b*m + x:m\na == b", "names the coefficient label")
  pr_err("m ~ a*x\ny ~ b*m + x:m\na < 1", "names the coefficient label")
  pr_err("m ~ a*x\ny ~ b*m + x:m\nab := a*b\nab == 0.2", "names the coefficient label")
  # each is accepted without the product, and a defined parameter alone is allowed beside a product
  for (syn in c("m ~ a*x\ny ~ a*m", "m ~ x\ny ~ 0.3*x", "m ~ a*x\ny ~ b*m\na == b", "m ~ a*x\ny ~ b*m\na < 1")) {
    expect_no_error(pr_ok(syn))
  }
  expect_no_error(pr_ok("m ~ a*x\ny ~ b*m + x:m\nab := a*b"))
})

test_that("rule 9: a label shared with a loading or variance, and an inline bound, are rejected", {
  pr_err("eta =~ l*y1 + y2\nm ~ l*x\ny ~ m + x:m", "label 'l' is used on more than one parameter")
  pr_err("m ~ v*x\ny ~ m + x:m\ny ~~ v*y", "label 'v' is used on more than one parameter")
  pr_err("m ~ x\ny ~ lower(0)*m + x:m", "has a bound")
  pr_err("m ~ x\ny ~ m + x:m\ny ~ upper(1)*1", "has a bound")
  expect_no_error(pr_ok("m ~ x\ny ~ lower(0)*m"))
})

test_that("rule 9: a product model without the parsed constraint table errors instead of skipping the check", {
  p <- .sem_parse("m ~ a*x\ny ~ b*m + x:m\na == b")$parameters
  attr(p, "all_constraints") <- NULL
  expect_error(.sem_complete(p), "constraint table")
})

test_that("rule 9: a residual covariance between outcomes is rejected, on the completed table", {
  pr_err("m1 ~ x\nm2 ~ x\ny ~ m1 + m2 + x:m1\nm1 ~~ m2", "residual covariance")
  pr_err("m1 ~ x\nm2 ~ x\ny ~ m1 + m2 + x:m1\nm1 ~~ 0*m2", "residual covariance")
  expect_no_error(pr_ok("m1 ~ x\nm2 ~ x\ny ~ m1 + m2\nm1 ~~ m2"))
})

test_that("rule 9 (H6): completion fixes the auto-added outcome covariance at 0 in a product model, with one note", {
  syn <- "m ~ x\ny ~ m + x + x:m\nz ~ w"
  msgs <- character()
  tab <- withCallingHandlers(pr_ok(syn), message = function(cnd) {
    msgs <<- c(msgs, conditionMessage(cnd))
    invokeRestart("muffleMessage")
  })
  expect_length(msgs, 1L)
  expect_match(msgs, "y ~~ z.*fixed at 0")
  row <- tab[tab$op == "~~" & tab$lhs == "y" & tab$rhs == "z", ]
  expect_identical(nrow(row), 1L)
  expect_identical(row$fixed, 0)
  expect_identical(row$user, 0L)
  # the no-product twin keeps the free covariance, silently, and is unchanged
  expect_silent(twin <- pr_ok("m ~ x\ny ~ m + x\nz ~ w"))
  trow <- twin[twin$op == "~~" & twin$lhs == "y" & twin$rhs == "z", ]
  expect_true(is.na(trow$fixed))
  # a product model with no pure-outcome pair has nothing to fix and says nothing
  expect_silent(pr_ok("m ~ x\ny ~ m + x + x:m"))
})

test_that("rule 9 intercept clause: fixed, shared-label and constrained intercepts are rejected", {
  pr_err("y ~ x + m + x:m\nm ~ x\ny ~ 0*1", "intercept.*fixed")
  pr_err("y ~ x + m + x:m\nm ~ x\ny ~ 1.5*1", "intercept.*fixed")
  pr_err("y ~ b*x + m + x:m\nm ~ x\ny ~ b*1", "label 'b' is used on more than one parameter")
  pr_err("y ~ x + m + x:m\nm ~ x\ny ~ b0*1\nm ~ b0*1", "shares the label 'b0'")
  pr_err("y ~ x + m + x:m\nm ~ x\ny ~ b0*1\nb0 == 1", "intercept.*in a constraint")
  pr_err("y ~ x + m + x:m\nm ~ x\ny ~ b0*1\nb0 < 1", "intercept.*in a constraint")
  # free, unlabeled or uniquely labeled intercepts are accepted
  expect_no_error(pr_ok("y ~ x + m + x:m\nm ~ x\ny ~ 1\nm ~ 1"))
  expect_no_error(pr_ok("y ~ x + m + x:m\nm ~ x\ny ~ b0*1\nm ~ b1*1"))
  # each of the rejected ones is accepted without the product
  for (syn in c("y ~ x + m\nm ~ x\ny ~ 0*1", "y ~ b*x + m\nm ~ x\ny ~ b*1", "y ~ x + m\nm ~ x\ny ~ b0*1\nb0 == 1")) {
    expect_no_error(pr_ok(syn))
  }
})

test_that("rule 9: a fixed_x row is allowed, a user-fixed intercept still is not", {
  syn <- "y ~ x + m + x:m\nm ~ x"
  tab <- pr_ok(syn, fixed_x = TRUE)
  expect_true(any(tab$fixed_x))
  expect_true(all(tab$user[tab$fixed_x] == 0L))
  expect_error(pr_ok(paste0(syn, "\ny ~ 0*1"), fixed_x = TRUE), "intercept.*fixed")
  # end to end: the fit runs, and the structural estimates equal the free-moment fit
  set.seed(8)
  n <- 400L
  x <- rnorm(n)
  m <- 0.5 * x + rnorm(n)
  d <- data.frame(y = 0.3 * x + 0.4 * m + 0.25 * x * m + rnorm(n), x = x, m = m)
  fixed <- fit_sem(syn, d, fixed_x = TRUE, meanstructure = TRUE)
  free <- fit_sem(syn, d, meanstructure = TRUE)
  keep <- c("y~x", "y~m", "y~m:x", "m~x")
  expect_equal(coef(fixed)[keep], coef(free)[keep], tolerance = 1e-5)
})

test_that("the no-product model and every fixed_x = FALSE fit are untouched", {
  tab <- pr_ok("m ~ x\ny ~ m + x\nz ~ w")
  expect_false(.sem_has_product(tab))
  expect_no_error(pr_ok("m ~ a*x\ny ~ a*m\nm ~ 0*1"))
})

# Planted defects: each must turn the matching test above red. fx_skip_covr() because covr rewrites the code a
# mutation edits.
test_that("planted defect (a): no descendant search in rule 8 loses the rule 8 error", {
  fx_skip_covr()
  syn <- "y ~ x:z\nz ~ y"
  expect_error(pr_ok(syn), "rule 8")
  mutant <- sem_mutate(.sem_check_product_parsed, "f %in% .sem_reach(edges, target)", "FALSE")
  local_mocked_bindings(.sem_check_product_parsed = mutant)
  # the downstream product is no longer named by rule 8 (the loop clause of rule 9 is all that is left)
  msg <- tryCatch(pr_ok(syn), error = conditionMessage)
  expect_false(grepl("rule 8", msg, fixed = TRUE))
  # with no loop, the descendant search is the only thing standing: `z ~ w:y` makes z a descendant of y
  expect_error(pr_ok("y ~ x:z\nz ~ w:y"), "not recursive")
})

test_that("planted defect (b): no residual-covariance check on the completed table lets m1 ~~ m2 through", {
  fx_skip_covr()
  syn <- "m1 ~ x\nm2 ~ x\ny ~ m1 + m2 + x:m1\nm1 ~~ m2"
  expect_error(pr_ok(syn), "residual covariance")
  mutant <- sem_mutate(.sem_check_product_completed, "length(cv)", "0L")
  local_mocked_bindings(.sem_check_product_completed = mutant)
  expect_no_error(suppressMessages(pr_ok(syn)))
})

test_that("planted defect (c): no intercept clause lets a fixed intercept through", {
  fx_skip_covr()
  syn <- "y ~ x + m + x:m\nm ~ x\ny ~ 0*1"
  expect_error(pr_ok(syn), "intercept.*fixed")
  mutant <- sem_mutate(.sem_check_product_completed, "length(fx)", "0L")
  local_mocked_bindings(.sem_check_product_completed = mutant)
  expect_no_error(pr_ok(syn))
})
