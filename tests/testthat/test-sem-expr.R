# Native SEM engine: constraint expressions (spec 4.2a-b, 4.5a-f, section 7).
# Oracles: R's own parse() and eval() on the same text for valid expressions;
# the spec 7 rejection table with a pinned regex per row; planted defects
# (positive controls) that must turn a check red.

vals <- c(a = 1.5, b = 2)

test_that("the 28 rejection inputs are rejected with the construct named", {
  rej <- c(
    'base::system("echo hi")' = "disallowed call head",
    'get("system")("echo hi")' = "disallowed call head",
    "(function() 1)()" = "disallowed call head",
    'do.call("system", list("echo hi"))' = "'do.call' is not in the math allowlist",
    "Recall(a)" = "'Recall' is not in the math allowlist",
    "ifelse(a > 0, a, b)" = "'ifelse' is not in the math allowlist",
    "if (a) 1 else 2" = "'if' is not in the math allowlist",
    "a[1]" = "'\\[' is not in the math allowlist",
    "a$b" = "'\\$' is not in the math allowlist",
    "a <- 3" = "'<-' is not in the math allowlist",
    "a = 3" = "'=' is not in the math allowlist",
    "~a" = "'~' is not in the math allowlist",
    '"abc"' = "disallowed literal '\"abc\"' \\(character\\)",
    "TRUE" = "disallowed literal 'TRUE' \\(logical\\)",
    "NA" = "disallowed literal 'NA' \\(logical\\)",
    "5L" = "disallowed literal '5L' \\(integer\\)",
    "1i" = "disallowed literal '0\\+1i' \\(complex\\)",
    "Inf" = "disallowed literal 'Inf'",
    "1e999" = "disallowed literal 'Inf'",
    "0x10" = "hexadecimal literals are not supported",
    "exp(a, b)" = "'exp' called with 2 argument",
    "log(x = a)" = "named arguments are not allowed in 'log'",
    "exp" = "'exp' is a function name and cannot be used as a parameter label",
    "`a b`" = "unknown parameter label 'a b'",
    "unknown * a" = "unknown parameter label 'unknown'",
    'a; system("x")' = "must be a single expression",
    "1 +" = "does not parse",
    "1e" = "does not parse"
  )
  expect_length(rej, 28L)
  for (i in seq_along(rej)) {
    expect_error(.sem_expr_eval(names(rej)[i], vals), rej[[i]], info = names(rej)[i])
  }
})

test_that("a label containing 0x is not a hexadecimal literal", {
  expect_equal(.sem_expr_eval("a0x1 + 1", c(a0x1 = 1)), 2)
})

test_that("the 14 valid expressions equal R's own evaluation of the same text", {
  ok <- c(
    "-2^2", "a*b", "a^2 + b^2", "exp(a)/sqrt(b+1)", "min(a, b, 3)", "log(a, 2)", "pnorm(a) - 0.5",
    "2^-1", "1e-3*a", ".5 + a", "1. * a", "1e3*a", "2E-2*a", "a^.5"
  )
  expect_length(ok, 14L)
  for (tx in ok) {
    expect_equal(.sem_expr_eval(tx, vals), eval(parse(text = tx), as.list(vals)), tolerance = 1e-14, info = tx)
  }
})

test_that("precedence and associativity follow R", {
  expect_equal(.sem_expr_eval("-2^2"), -4)
  expect_equal(.sem_expr_eval("2^3^2"), 512)
  expect_equal(.sem_expr_eval("2^-1"), 0.5)
})

test_that("the result guard rejects the 8 non-finite results and accepts the 5 boundary expressions", {
  bad <- c("1/0", "0/0", "(-1)^.5", "log(-1)", "sqrt(-1)", "exp(1000)", "qnorm(2)", "1/(a - 1.5)")
  for (tx in bad) {
    expect_error(.sem_expr_eval(tx, vals), "did not evaluate to one finite real number", info = tx)
  }
  expect_error(.sem_expr_eval("1/(a - 1.5)", vals), "a = 1.5, b = 2", fixed = TRUE)
  good <- c("log(1)", "1/a", "sqrt(b)", "(-8)^2", "0*a")
  for (tx in good) {
    expect_true(is.finite(.sem_expr_eval(tx, vals)), info = tx)
  }
})

test_that("planted defect: removing the result guard lets 1/0 and 0/0 through", {
  unguarded <- function(text) {
    e <- .sem_expr_parse(text)
    eval(e, list2env(.sem_funs, parent = emptyenv()))
  }
  expect_identical(unguarded("1/0"), Inf)
  expect_true(is.nan(suppressWarnings(unguarded("0/0"))))
  expect_error(.sem_expr_eval("1/0"), "finite real number")
  expect_error(.sem_expr_eval("0/0"), "finite real number")
})

test_that("planted defect: rebinding exp fools an all.names() check but not the locked evaluator", {
  flag <- FALSE
  exp <- function(x) {
    flag <<- TRUE
    base::exp(x)
  }
  txt <- "exp(a) + b"
  naive_ok <- function(text, labels) {
    length(setdiff(all.names(.sem_expr_parse(text)), c(names(.sem_fun_arity), labels))) == 0L
  }
  expect_true(naive_ok(txt, c("a", "b")))
  invisible(eval(.sem_expr_parse(txt), list(a = 1, b = 2), environment()))
  expect_true(flag)
  flag <- FALSE
  expect_equal(.sem_expr_eval(txt, c(a = 1, b = 2)), base::exp(1) + 2, tolerance = 1e-14)
  expect_false(flag)
})

# Spec 4.5a / 4.5f item 1.
lin_table <- c(
  "a*b" = FALSE, "a+b-0.5" = TRUE, "a-2*b" = TRUE, "exp(a)-1" = FALSE, "a^2" = FALSE, "a*0+b" = TRUE,
  "abs(a)-b" = FALSE, "(a-b)*(a+b)" = FALSE, "2*(a+b)/3" = TRUE, "a/b" = FALSE, "-a + 3" = TRUE,
  "exp(1)*a" = TRUE, "a*b - a*b + a" = FALSE, "a^1" = FALSE, "min(a, b)" = FALSE, "1e3*a - b" = TRUE
)

test_that("the 16-expression linearity table gives the stated classes", {
  expect_length(lin_table, 16L)
  for (i in seq_along(lin_table)) {
    expect_identical(.sem_expr_linear(names(lin_table)[i]), lin_table[[i]], info = names(lin_table)[i])
  }
})

# Rebuild .sem_tree_linear with one rule changed; the edit is asserted so a
# stale pattern fails loudly instead of testing nothing.
lin_mutant <- function(from, to) {
  src <- paste(deparse(.sem_tree_linear), collapse = "\n")
  mut <- sub(from, to, src)
  stopifnot(!identical(mut, src))
  eval(parse(text = mut), environment(.sem_tree_linear))
}

test_that("planted defect: a product of two labeled factors called linear flips a*b and (a-b)*(a+b)", {
  mut <- lin_mutant("sum\\(!vapply\\(a,\\s*const, TRUE\\)\\) <= 1L &&\\s*", "")
  for (tx in c("a*b", "(a-b)*(a+b)")) {
    expect_true(mut(.sem_expr_parse(tx)), info = tx)
    expect_false(.sem_tree_linear(.sem_expr_parse(tx)), info = tx)
  }
})

test_that("planted defect: an unknown call called linear flips abs(a)-b and min(a, b)", {
  mut <- lin_mutant("\\bFALSE\\b", "TRUE")
  for (tx in c("abs(a)-b", "min(a, b)")) {
    expect_true(mut(.sem_expr_parse(tx)), info = tx)
    expect_false(.sem_tree_linear(.sem_expr_parse(tx)), info = tx)
  }
})

test_that("defined names are substituted before the linearity walk", {
  defs <- c(ind = "a*b", s = "a + b")
  expect_false(.sem_expr_linear("ind - 0.1", defs))
  expect_true(.sem_expr_linear("s - 1", defs))
  expect_false(.sem_constraint_linear("ind", "0", defs))
  expect_true(.sem_constraint_linear("s", "1", defs))
  expect_true(.sem_constraint_linear("a", "2*b"))
  expect_false(.sem_constraint_linear("a*b", "0"))
  chained <- c(u = "a + b", v = "u*2")
  expect_true(.sem_expr_linear("v", chained))
  expect_error(.sem_expr_linear("p", c(p = "q", q = "p")), "cycle")
})

test_that("labels of an expression exclude function names", {
  expect_setequal(.sem_expr_labels("exp(a) + log(b, 2)*c"), c("a", "b", "c"))
})
