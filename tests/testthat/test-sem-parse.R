# Native SEM engine: model syntax parser (spec 4-8).
# Oracle: lavaan::lavParseModelString() on the core grammar, with bound folding
# applied to both sides (lavaan folds `a < 2` but leaves `3 < a`; spec 4.4 folds
# both). Extensions have their own expected tables. Positive controls: a defect
# planted in the parser must turn a test red.

par_cols <- c("lhs", "op", "rhs", "level", "fixed", "label", "start", "lower", "upper")

# lavaan's parse as our table: the `level:` rows dropped, character columns
# numeric, then the same folding applied to its constraint list.
sem_parse_oracle <- function(model) {
  skip_if_not_installed("lavaan")
  lav <- lavaan::lavParseModelString(model, as.data.frame. = TRUE)
  lav <- lav[lav$op != ":", , drop = FALSE]
  num <- function(x) {
    if (is.null(x)) {
      return(rep(NA_real_, nrow(lav)))
    }
    suppressWarnings(as.numeric(replace(x, x %in% c("", "NA"), NA)))
  }
  par <- data.frame(
    lhs = lav$lhs, op = lav$op, rhs = lav$rhs, level = as.integer(lav$block), fixed = num(lav$fixed),
    label = if (is.null(lav$label)) rep("", nrow(lav)) else lav$label, start = num(lav$start),
    lower = num(lav$lower), upper = num(lav$upper),
    stringsAsFactors = FALSE
  )
  cs <- attr(lav, "constraints")
  cons <- data.frame(
    op = vapply(cs, function(z) z$op, ""), lhs = vapply(cs, function(z) z$lhs, ""),
    rhs = vapply(cs, function(z) z$rhs, ""), level = rep(1L, length(cs)), stringsAsFactors = FALSE
  )
  .sem_fold_bounds(par, cons)
}

strip_ws <- function(x) gsub("\\s", "", x)

expect_matches_lavaan <- function(model, info = NULL) {
  ours <- .sem_parse(model)
  ref <- sem_parse_oracle(model)
  expect_equal(ours$parameters[, par_cols], ref$parameters[, par_cols], ignore_attr = TRUE, info = info)
  expect_equal(strip_ws(ours$constraints$op), strip_ws(ref$constraints$op), info = info)
  expect_equal(strip_ws(ours$constraints$lhs), strip_ws(ref$constraints$lhs), info = info)
  expect_equal(strip_ws(ours$constraints$rhs), strip_ws(ref$constraints$rhs), info = info)
}

core_models <- list(
  simple = "M ~ a*X\nY ~ b*M + cp*X\nind := a*b",
  serial = "M1 ~ a1*X\nM2 ~ d*M1 + a2*X\nY ~ b2*M2 + b1*M1 + cp*X\nind := a1*d*b2",
  parallel = paste(
    "M1 ~ a1*X", "M2 ~ a2*X", "M1 ~~ M2", "Y ~ b1*M1 + b2*M2 + cp*X",
    "ind1 := a1*b1", "ind2 := a2*b2", "total := ind1 + ind2", sep = "\n"
  ),
  latent = "eta =~ 1*m1 + m2 + m3\neta ~ a*X\nY ~ b*eta + cp*X\nind := a*b",
  equal_labels = "M ~ a*X\nY ~ a*M + cp*X\nM ~~ v*M\nY ~~ v*Y",
  equal_constraint = "M ~ a*X\nY ~ b*M\na == b",
  probe = paste(
    "M =~ 1*m1 + l2*m2 + m3", "M ~ a*X + start(0.2)*C", "Y ~ b*M + cp*X + lower(-1)*C",
    "Y ~~ upper(5)*Y", "m1 ~ 0*1", "ab := a*b", "a == b", "cp > 0", "a < 2", sep = "\n"
  ),
  bounds = "M ~ a*X\nY ~ b*M + cp*X\na < 2*3\ncp > -1\nb < 1",
  two_level = "level: 1\nY ~ X\nlevel: 2\nY ~ W",
  literals = "Y ~ .5*X + 1.*M\nM ~ 2e-1*Z\nZ ~ -0.5*W",
  intercepts = "m1 ~ 0*1\nm2 ~ 1\nm3 ~ i3*1",
  comments = "# header\nM ~ a*X # trailing\n! another comment\nY ~ b*M +\n  cp*X; M ~~ M",
  start_bounds = "Y ~ start(.5)*X + lower(0)*M + upper(2)*Z\nY ~~ start(1)*Y"
)

test_that("the core grammar matches lavParseModelString on every spec model", {
  for (nm in names(core_models)) {
    expect_matches_lavaan(core_models[[nm]], info = nm)
  }
})

test_that("the table has the spec 5 columns and types", {
  r <- .sem_parse(core_models$probe)
  expect_named(r, c("parameters", "constraints"))
  expect_named(r$parameters, c("id", par_cols[1:3], "level", "fixed", "label", "start", "lower", "upper"))
  expect_type(r$parameters$id, "integer")
  expect_identical(r$parameters$id, seq_len(nrow(r$parameters)))
  expect_type(r$parameters$level, "integer")
  for (cn in c("lhs", "op", "rhs", "label")) {
    expect_type(r$parameters[[cn]], "character")
  }
  for (cn in c("fixed", "start", "lower", "upper")) {
    expect_type(r$parameters[[cn]], "double")
  }
  expect_named(r$constraints, c("op", "lhs", "rhs", "level"))
  expect_type(r$constraints$level, "integer")
  intercept <- r$parameters[r$parameters$op == "~1", ]
  expect_identical(intercept$rhs, "")
  expect_equal(intercept$fixed, 0)
  expect_identical(nrow(.sem_parse("Y ~ X")$constraints), 0L)
  expect_identical(.sem_parse("Y ~ X")$constraints$level, integer())
})

test_that("bound folding writes upper and lower on every row with the label", {
  r <- .sem_parse("M ~ a*X\nY ~ a*M\nM ~~ v*M\na < 2\n-1 < a\nv > 0")
  expect_equal(r$parameters$upper[r$parameters$label == "a"], c(2, 2))
  expect_equal(r$parameters$lower[r$parameters$label == "a"], c(-1, -1))
  expect_equal(r$parameters$lower[r$parameters$label == "v"], 0)
  expect_identical(nrow(r$constraints), 0L)
  # The mirrored form folds here although lavaan keeps it as a constraint.
  expect_equal(.sem_parse("M ~ a*X\n3 > a")$parameters$upper, 3)
  expect_equal(.sem_parse("M ~ a*X\n3 < a")$parameters$lower, 3)
  # Anything that is not one label against one constant stays a constraint.
  r <- .sem_parse("M ~ a*X\nY ~ b*M\na < b\nab := a*b\nab > 0\na == 1\na < exp(b)")
  expect_identical(r$constraints$op, c("<", ":=", ">", "==", "<"))
  expect_true(all(is.na(r$parameters$upper)) && all(is.na(r$parameters$lower)))
  # Two bounds on one label keep the tighter one.
  expect_equal(.sem_parse("M ~ a*X\na < 2\na < 1")$parameters$upper, 1)
})

test_that("planted defect: removing bound folding turns the a < 2 row red", {
  expect_equal(.sem_parse("M ~ a*X\na < 2")$parameters$upper, 2)
  testthat::local_mocked_bindings(
    .sem_fold_bounds = function(parameters, constraints) list(parameters = parameters, constraints = constraints)
  )
  r <- .sem_parse("M ~ a*X\na < 2")
  expect_true(is.na(r$parameters$upper))
  expect_identical(r$constraints$op, "<")
})

test_that("comma shorthand expands to one statement per left-side name", {
  r <- .sem_parse("y1, y2 ~ x + z")
  expect_identical(r$parameters$lhs, c("y1", "y1", "y2", "y2"))
  expect_identical(r$parameters$rhs, c("x", "z", "x", "z"))
  skip_if_not_installed("lavaan")
  lav <- lavaan::lavParseModelString("y1, y2 ~ x", as.data.frame. = TRUE)
  # lavaan reads it as y2 ~ x and silently drops y1; ours keeps both.
  expect_identical(lav$lhs, "y2")
  expect_identical(.sem_parse("y1, y2 ~ x")$parameters$lhs, c("y1", "y2"))
})

test_that("CONSTRAINT(...) equals the bare constraint", {
  bare <- .sem_parse("M ~ a*X\nY ~ b*M\na + b == 0\na < b\nab := a*b")
  directive <- .sem_parse("M ~ a*X\nY ~ b*M\nCONSTRAINT(a + b == 0)\nCONSTRAINT(a < b)\nab := a*b")
  expect_identical(directive, bare)
  expect_identical(.sem_parse("M ~ a*X\nCONSTRAINT(\n a == 1)")$constraints$rhs, "1")
})

test_that("levels are recorded and fitting-time errors are not the parser's job", {
  r <- .sem_parse("level: 1\nY ~ X\nlevel: 2\nY ~ W\nlevel: 1\nY ~~ Y")
  expect_identical(r$parameters$level, c(1L, 2L, 1L))
  r <- .sem_parse("level: 2\nY ~ a*X\na == 1")
  expect_identical(r$constraints$level, 2L)
})

test_that("comments, separators, literals and continuation lines", {
  r <- .sem_parse("# c\nY ~ a*X # t\n! also\nM ~ b*X ; Z ~ .5*X + 1.*M")
  expect_identical(r$parameters$lhs, c("Y", "M", "Z", "Z"))
  expect_equal(r$parameters$fixed, c(NA, NA, 0.5, 1))
  # `+`, `,`, `*` and an open parenthesis continue a statement.
  expect_identical(.sem_parse("Y ~ X +\n Z")$parameters$rhs, c("X", "Z"))
  expect_identical(.sem_parse("y1,\n y2 ~ x")$parameters$lhs, c("y1", "y2"))
  expect_identical(.sem_parse("Y ~ cp*\n X")$parameters$label, "cp")
  expect_identical(.sem_parse("Y ~ a*X\nCONSTRAINT(\n a\n == 1)")$constraints$lhs, "a")
  expect_equal(.sem_parse("m ~ 0*1")$parameters$fixed, 0)
  expect_identical(.sem_parse("m ~ 0*1")$parameters$op, "~1")
  expect_equal(.sem_parse("Y ~ start(NA)*X")$parameters$start, NA_real_)
  expect_equal(.sem_parse("Y ~ start(-.5)*X")$parameters$start, -0.5)
  expect_equal(.sem_parse("Y ~ lower(-1)*X + upper(+2)*Z")$parameters[c("lower", "upper")],
               data.frame(lower = c(-1, NA), upper = c(NA, 2)), ignore_attr = TRUE)
})

test_that("planted defect: the oracle drops y1 from `y1, y2 ~ x` and the parser must not", {
  skip_if_not_installed("lavaan")
  ref <- lavaan::lavParseModelString("y1, y2 ~ x", as.data.frame. = TRUE)
  expect_false("y1" %in% ref$lhs)
  expect_true("y1" %in% .sem_parse("y1, y2 ~ x")$parameters$lhs)
})

# Spec 7 rejection table (parser rows) and unsupported syntax, each by name.
test_that("unsupported operators and blocks error by name", {
  bad <- c(
    "F <~ x1 + x2" = "operator '<~' is not supported",
    "y ~*~ z" = "operator '~\\*~' is not supported",
    "y |~ x" = "operator '\\|~' is not supported",
    "F :~ x1" = "operator ':~' is not supported",
    "y | t1" = "operator '\\|' is not supported",
    "y ~ x %% 2" = "operator '%' is not supported",
    "group: 1\ny ~ x" = "'group:' blocks are not supported",
    "class: 1\ny ~ x" = "'class:' blocks are not supported",
    "block: 1\ny ~ x" = "'block:' blocks are not supported",
    "`a b` ~ x" = "quoted names and strings are not supported"
  )
  for (i in seq_along(bad)) {
    expect_error(.sem_parse(names(bad)[i]), bad[[i]], info = names(bad)[i])
  }
})

test_that("every row of the spec 7 syntax table has a pinned error", {
  bad <- c(
    "Y ~ a*X\na <= 2" = "comparison '<=' is not supported",
    "Y ~ a*X\na >= 2" = "comparison '>=' is not supported",
    "Y ~ a*X\na != 2" = "comparison '!=' is not supported",
    "Y ~ x, z" = "a comma on the right side is not supported",
    "Y ~ x\nCONSTRAINT(a == 1) + 2" = "unexpected text after CONSTRAINT",
    "Y ~ a*X\nCONSTRAINT(CONSTRAINT(a == 1))" = "cannot be nested",
    "Y ~ a*X\nCONSTRAINT(a == 1, a == 2)" = "found a comma",
    "Y ~ a*X\nCONSTRAINT(a == 1 == 2)" = "exactly one comparison",
    "Y ~ a*X\nCONSTRAINT(a == 1" = "unbalanced parentheses",
    "Y ~ a*X\na == 1 < 2" = "exactly one comparison",
    "Y ~ a*X\na + 1" = "expected one comparison",
    "Y ~ a*X\n== 1" = "an expression on both sides",
    "Y ~ a*X\na == q" = "unknown parameter label 'q'",
    "Y ~ a*X\na == system(1)" = "'system' is not in the math allowlist",
    "Y ~ a*X\na == exp(1, 2)" = "'exp' called with 2 argument",
    "Y ~ a*X\nab := a*b" = "unknown parameter label 'b'",
    "Y ~ a*X\nab := 1\nab := 2" = "'ab' is defined more than once",
    "Y ~ a*X\na := 1" = "defined parameter 'a' clashes",
    "Y ~ a*X\nexp := 1" = "defined parameter name 'exp' is a reserved word",
    "Y ~ a*X\n:= 1" = "malformed defined parameter",
    "Y ~ a*X\nab :=" = "malformed defined parameter",
    "Y ~ a*a" = "label 'a' is also a variable name",
    "Y ~ exp*X" = "label 'exp' is a reserved word",
    "Y ~ start*X" = "label 'start' is a reserved word",
    "Y ~ level*X" = "label 'level' is a reserved word",
    "Y ~ CONSTRAINT*X" = "label 'CONSTRAINT' is a reserved word",
    "Y ~ a*b*X" = "more than one modifier on a term",
    "Y ~ start(.5)*lower(0)*X" = "more than one modifier on a term",
    "Y ~ start(a)*X" = "malformed modifier 'start\\(a\\)'",
    "Y ~ lower(NA)*X" = "malformed modifier 'lower\\(NA\\)'",
    "Y ~ NA*X" = "NA is allowed in start\\(\\) only",
    "Y ~ *X" = "nothing before '\\*'",
    "Y ~ 5L*X" = "malformed number '5L",
    "Y ~ 0x10*X" = "malformed number",
    "Y ~ 1e*X" = "malformed number",
    "Y ~ @X" = "unexpected character '@'",
    "Y ~ 1 + X" = "an intercept must be its own statement",
    "Y ~ 2" = "only valid as the intercept",
    "Y ~~ 1" = "only valid as the intercept",
    "Y ~ X ~ Z" = "more than one relation operator",
    "Y ~ " = "empty right side",
    "Y ~ X +" = "empty term",
    "~ X" = "invalid left side",
    "y z ~ X" = "invalid left side",
    "level: x\nY ~ X" = "malformed level line",
    "level:\nY ~ X" = "malformed level line",
    "Y ~ a*X\nab := a\nxy := ab + zz" = "unknown parameter label 'zz'"
  )
  for (i in seq_along(bad)) {
    expect_error(.sem_parse(names(bad)[i]), bad[[i]], info = gsub("\n", " | ", names(bad)[i]))
  }
})

test_that("defined-parameter cycles error", {
  expect_error(.sem_parse("Y ~ a*X\np := q + a\nq := p"), "defined parameters form a cycle: p -> q -> p")
  expect_error(.sem_parse("Y ~ a*X\np := p + a"), "form a cycle")
  expect_no_error(.sem_parse("Y ~ a*X\np := q + a\nq := a*2"))
})

test_that("an empty model or one without parameters errors", {
  expect_error(.sem_parse(""), "model syntax is empty")
  expect_error(.sem_parse("# only a comment"), "model syntax is empty")
  expect_error(.sem_parse("level: 1"), "has no parameters")
  expect_error(.sem_parse("a == 1"), "has no parameters")
  expect_error(.sem_parse(character()), "model")
  expect_error(.sem_parse(NA_character_), "model")
})

test_that("a character vector of lines parses like one string", {
  expect_identical(.sem_parse(c("M ~ a*X", "Y ~ b*M")), .sem_parse("M ~ a*X\nY ~ b*M"))
})
