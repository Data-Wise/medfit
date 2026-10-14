# Native SEM engine: the `:` product token (0.10.0 plan U1, amendment sections 3-4).
# A product `x:m` is an ordinary right-side regression term whose table name is canonical (`m:x`): the two factor
# names sorted in the C locale by one helper. Positive controls: a defect planted in the helper or the parser must
# turn the matching test red.

test_that("the canonical name sorts the factors in the C locale, whatever the order", {
  expect_identical(.sem_product_name("x", "m"), "m:x")
  expect_identical(.sem_product_name("m", "x"), "m:x")
  expect_identical(.sem_product_name("x", "m"), .sem_product_name("m", "x"))
  # C locale: upper case before lower case, digits before letters, "." before digits
  expect_identical(.sem_product_name("a", "B"), "B:a")
  expect_identical(.sem_product_name("B", "a"), "B:a")
  expect_identical(.sem_product_name("x1", "x.1"), "x.1:x1")
  expect_identical(.sem_product_name("X", "M"), "M:X")
  # the name is a function of the two names only
  expect_identical(names(formals(.sem_product_name)), c("a", "b"))
  expect_error(.sem_product_name("x", ""), "Assertion on 'b'")
  expect_error(.sem_product_name(c("x", "m"), "w"), "Assertion on 'a'")
})

test_that("`x:m` parses to one regression row named by the canonical product", {
  r <- .sem_parse("Y ~ X:M")$parameters
  expect_identical(r$op, "~")
  expect_identical(r$lhs, "Y")
  expect_identical(r$rhs, "M:X")
  expect_identical(.sem_parse("Y ~ M:X")$parameters$rhs, "M:X")
  expect_identical(.sem_parse("y ~ x:m")$parameters$rhs, "m:x")
  expect_identical(.sem_parse("y ~ m:x")$parameters$rhs, "m:x")
  # mixed with ordinary terms, in order, with the same row fields as any term
  r <- .sem_parse("y ~ x + m + x:m + w")$parameters
  expect_identical(r$rhs, c("x", "m", "m:x", "w"))
  expect_true(all(is.na(r$fixed)) && all(r$label == ""))
})

test_that("a modifier applies to the whole product", {
  r <- .sem_parse("y ~ b*x:m")$parameters
  expect_identical(c(r$rhs, r$label), c("m:x", "b"))
  r <- .sem_parse("y ~ 0.3*x:m")$parameters
  expect_identical(c(r$rhs, r$fixed), c("m:x", "0.3"))
  r <- .sem_parse("y ~ start(.5)*x:m + lower(0)*w")$parameters
  expect_identical(r$rhs, c("m:x", "w"))
  expect_equal(r$start, c(0.5, NA))
  r <- .sem_parse("y ~ lower(0)*m:x + upper(2)*x")$parameters
  expect_equal(c(r$lower, r$upper), c(0, NA, NA, 2))
  # a label is the way to name the coefficient; `x:m` alone is not a label
  expect_identical(.sem_parse("y ~ b*m:x")$parameters$label, "b")
})

test_that("a product on a comma left side expands one row per left-side name", {
  r <- .sem_parse("y1, y2 ~ x:m")$parameters
  expect_identical(r$lhs, c("y1", "y2"))
  expect_identical(r$rhs, c("m:x", "m:x"))
})

test_that("`:=` and `level:` are split off before the product token", {
  d <- .sem_parse("Y ~ a*X\nab:=a*2")
  expect_identical(d$constraints$op, ":=")
  expect_identical(d$constraints$lhs, "ab")
  expect_identical(.sem_parse("Y ~ a*X\nab :=a*2")$constraints$lhs, "ab")
  expect_identical(.sem_parse("level:1\nY ~ X")$parameters$level, 1L)
  r <- .sem_parse("level:1\nY ~ X:M\nlevel:2\nY ~ W")$parameters
  expect_identical(r$rhs, c("M:X", "W"))
  expect_identical(r$level, c(1L, 2L))
  # a product and a defined parameter in one model
  r <- .sem_parse("Y ~ a*X + b*X:M\nab:=a*b")
  expect_identical(r$parameters$rhs, c("X", "M:X"))
  expect_identical(r$constraints$lhs, "ab")
})

test_that("spaces around the colon are rejected (no implicit joins)", {
  msg <- "needs a variable name on each side, written without spaces"
  for (m in c("Y ~ x :m", "Y ~ x: m", "Y ~ x : m", "Y ~ x\t:m", "Y ~ :m", "Y ~ x:", "Y ~ x + :m", "Y ~ x:+m",
              "Y ~ 1:m", "Y ~ x:2", "Y ~ x:(m)", "Y ~ a*:m", "Y ~ start(1):m")) {
    expect_error(.sem_parse(m), msg, info = m)
  }
  # the same product written without spaces parses
  expect_no_error(.sem_parse("Y ~ x:m"))
  expect_no_error(.sem_parse("Y ~ x:m   +   w"))
})

test_that("unsupported products error naming the feature", {
  cases <- c(
    "Y ~ x:x" = "product 'x:x' of a variable with itself is not supported",
    "Y ~ b*X:X" = "product 'X:X' of a variable with itself is not supported",
    "Y ~ x:m:w" = "three-way or higher product \\('x:m:w'\\) is not supported",
    "Y ~ x:m:w:z" = "three-way or higher product \\('x:m:w:z'\\)",
    "Y ~ x:x:m" = "three-way or higher product",
    "Y ~ x:.5" = "malformed product",
    "Y ~ x:m*w" = "malformed modifier 'x:m'"
  )
  for (i in seq_along(cases)) {
    expect_error(.sem_parse(names(cases)[i]), cases[[i]], info = names(cases)[i])
  }
})

test_that("a product inside an expression (constraint, defined parameter, directive) errors", {
  msg <- "product term ':' is only valid on the right side of a regression, not inside the expression"
  for (m in c("Y ~ a*X\na == x:m", "Y ~ a*X\nab := a*x:m", "Y ~ a*X\nCONSTRAINT(a < x:m)", "Y ~ a*X\nx:m > a",
              "Y ~ a*X\nab := x:m")) {
    expect_error(.sem_parse(m), msg, info = m)
  }
  # other uses of the colon in an expression keep their old errors
  expect_error(.sem_parse("Y ~ a*X\nab := base::sqrt(a)"), "disallowed call head")
})

test_that("a product as a left side errors naming the feature", {
  for (m in c("x:m ~ y", "x:m ~~ y", "x:m =~ y", "y1, x:m ~ w", "x:m ~ 1")) {
    expect_error(.sem_parse(m), "product term ':' cannot be a left side", info = m)
  }
})

test_that("a product is a regression term only: not a loading, not in a (co)variance", {
  expect_error(.sem_parse("eta =~ x:m"), "only valid on the right side of a regression \\('~'\\), not of '=~'")
  expect_error(.sem_parse("Y ~ X\nX ~~ x:m"), "only valid on the right side of a regression \\('~'\\), not of '~~'")
  expect_error(.sem_parse("Y ~ X\nX ~~ a*x:m"), "'x:m'")
})

test_that("a product of a latent variable errors (latent products are not supported)", {
  model <- "eta =~ m1 + m2 + m3\ny ~ eta + x\n"
  for (term in c("eta:x", "x:eta")) {
    expect_error(.sem_parse(paste0(model, "y ~ ", term)), "involves a latent variable", info = term)
  }
  expect_error(.sem_parse(paste0(model, "m1 ~ eta:x")), "product '.*' involves a latent variable")
  # the message names the product as written
  expect_error(.sem_parse(paste0(model, "y ~ x:eta")), "'x:eta'")
  # a product of two observed variables beside a latent variable is fine
  expect_no_error(.sem_parse(paste0(model, "y ~ x:w")))
})

test_that("a product factor counts as a variable for the label-clash check", {
  expect_error(.sem_parse("y ~ x:m + x*w"), "label 'x' is also a variable name")
  expect_error(.sem_parse("y ~ x:m\nm := 1"), "defined parameter 'm' clashes")
})

test_that("models without a product parse exactly as before", {
  r <- .sem_parse("M ~ a*X\nY ~ b*M + cp*X\nab := a*b")
  expect_identical(r$parameters$rhs, c("X", "M", "X"))
  expect_false(any(grepl(":", r$parameters$rhs, fixed = TRUE)))
  expect_identical(
    names(r$parameters), c("id", "lhs", "op", "rhs", "level", "fixed", "label", "start", "lower", "upper")
  )
})

test_that("planted defect: skipping the sort in the canonical name turns the identity test red", {
  bad <- sem_mutate(.sem_product_name, "sort(c(a, b), method = \"radix\")", "c(a, b)")
  expect_identical(bad("m", "x"), "m:x")
  expect_false(identical(bad("x", "m"), bad("m", "x")))
  testthat::local_mocked_bindings(.sem_product_name = bad)
  # the parser inherits the defect: `x:m` is not rewritten to the canonical `m:x`
  expect_identical(.sem_parse("y ~ x:m")$parameters$rhs, "x:m")
  expect_false(identical(.sem_parse("y ~ x:m")$parameters$rhs, .sem_parse("y ~ m:x")$parameters$rhs))
})

test_that("planted defect: sorting in the session locale instead of C turns the C-locale test red", {
  bad <- sem_mutate(.sem_product_name, "method = \"radix\"", "method = \"shell\"")
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old), add = TRUE)
  skip_if(identical(suppressWarnings(Sys.setlocale("LC_COLLATE", "en_US.UTF-8")), ""), "en_US locale not available")
  expect_identical(.sem_product_name("a", "B"), "B:a") # radix ignores the locale
  expect_identical(bad("a", "B"), "a:B") # a locale-aware sort does not: the C-locale test would fail
})

test_that("planted defect: dropping the product branch of the tokenizer turns `x:m` into an error", {
  bad <- sem_mutate(.sem_tokens, "startsWith(s, \":\")", "FALSE")
  testthat::local_mocked_bindings(.sem_tokens = bad)
  expect_error(.sem_parse("y ~ x:m"), "unexpected character ':'")
})
