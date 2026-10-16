# T1: the factor pre-pass (`.sem_expand_factors()`), unit level. Not yet wired into the fit (T2).

fc_data <- function(n = 40L) {
  set.seed(11)
  data.frame(
    y = rnorm(n), x = rnorm(n), m = rnorm(n),
    g = factor(rep(c("a", "b", "c", "a"), length.out = n)),
    stringsAsFactors = FALSE
  )
}
fc_tab <- function(model) .sem_parse(model)$parameters

test_that("a factor on a regression's right side becomes one dummy per non-reference level", {
  d <- fc_data()
  out <- .sem_expand_factors(fc_tab("y ~ x + g\nm ~ x"), d, FALSE)
  expect_equal(out$table$rhs[out$table$lhs == "y"], c("x", "g_b", "g_c"))
  expect_equal(out$table$rhs[out$table$lhs == "m"], "x")
  expect_equal(out$table$id, seq_len(nrow(out$table)))
  expect_equal(out$data$g_b, as.numeric(d$g == "b"))
  expect_equal(out$data$g_c, as.numeric(d$g == "c"))
  expect_false("g_a" %in% names(out$data))
  expect_equal(out$map$g$reference, "a")
  expect_equal(out$map$g$dummies, c("g_b", "g_c"))
})

test_that("a model with no factor returns its inputs unchanged", {
  d <- fc_data()
  tab <- fc_tab("y ~ x + m")
  out <- .sem_expand_factors(tab, d, "x")
  expect_identical(out$table, tab)
  expect_identical(out$data, d)
  expect_identical(out$fixed_x, "x")
  expect_length(out$map, 0L)
})

test_that("a factor as an outcome is left alone (the numeric error stays)", {
  d <- fc_data()
  tab <- fc_tab("g ~ x")
  out <- .sem_expand_factors(tab, d, FALSE)
  expect_identical(out$table, tab)
  expect_identical(out$data, d)
})

test_that("the reference is levels(x)[1] and a character column sorts in the C locale", {
  d <- fc_data()
  d$g <- factor(d$g, levels = c("c", "a", "b"))
  out <- .sem_expand_factors(fc_tab("y ~ g"), d, FALSE)
  expect_equal(out$map$g$reference, "c")
  expect_equal(out$map$g$dummies, c("g_a", "g_b"))

  d$g <- c("b", "B", "a", "A")[rep(1:4, length.out = nrow(d))]
  out <- .sem_expand_factors(fc_tab("y ~ g"), d, FALSE)
  # C locale: "A" < "B" < "a" < "b"
  expect_equal(out$map$g$levels, c("A", "B", "a", "b"))
  expect_equal(out$map$g$reference, "A")
})

test_that("the character order does not depend on the session collation", {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old), add = TRUE)
  d <- fc_data()
  d$g <- c("b", "B", "a", "A")[rep(1:4, length.out = nrow(d))]
  seen <- character()
  for (loc in c("C", "en_US.UTF-8", "sv_SE.UTF-8")) {
    if (nzchar(Sys.setlocale("LC_COLLATE", loc))) {
      seen <- c(seen, loc)
      expect_equal(.sem_expand_factors(fc_tab("y ~ g"), d, FALSE)$map$g$levels, c("A", "B", "a", "b"))
    }
  }
  expect_true("C" %in% seen)
})

test_that("a numeric-looking level makes a valid dummy name", {
  d <- fc_data()
  d$g <- factor(ifelse(d$g == "a", "ref", "2"), levels = c("ref", "2"))
  out <- .sem_expand_factors(fc_tab("y ~ g"), d, FALSE)
  expect_equal(out$map$g$dummies, "g_2")
  expect_equal(out$data$g_2, as.numeric(d$g == "2"))
})

test_that("a logical column gives one 0/1 dummy and no reference", {
  d <- fc_data()
  d$g <- rep(c(TRUE, FALSE), length.out = nrow(d))
  out <- .sem_expand_factors(fc_tab("y ~ x + g"), d, FALSE)
  expect_equal(out$table$rhs[out$table$lhs == "y"], c("x", "g_TRUE"))
  expect_equal(out$data$g_TRUE, as.numeric(d$g))
})

test_that("a missing factor value gives NA in every dummy", {
  d <- fc_data()
  d$g[3] <- NA
  out <- .sem_expand_factors(fc_tab("y ~ g"), d, FALSE)
  expect_true(is.na(out$data$g_b[3]) && is.na(out$data$g_c[3]))
  expect_equal(sum(is.na(out$data$g_b)), 1L)
})

test_that("ordered factors and one-level factors are errors", {
  d <- fc_data()
  d$g <- factor(d$g, ordered = TRUE)
  expect_error(.sem_expand_factors(fc_tab("y ~ g"), d, FALSE), "ordered factor.*ordered = FALSE")
  d$g <- factor("a")[rep(1L, nrow(d))]
  expect_error(.sem_expand_factors(fc_tab("y ~ g"), d, FALSE), "only one level")
})

test_that("a dummy name that collides or is not a valid name is an error naming both sides", {
  d <- fc_data()
  d$g_b <- 1
  expect_error(.sem_expand_factors(fc_tab("y ~ g"), d, FALSE), "g_b.*already a column")
  d <- fc_data()
  d$g <- factor(ifelse(d$g == "a", "a", "b c"))
  expect_error(.sem_expand_factors(fc_tab("y ~ g"), d, FALSE), "level 'b c'.*invalid name `g_b c`")
})

test_that("two factors whose dummies would share a name are an error", {
  d <- fc_data()
  d$g <- factor(rep(c("a", "b_c"), length.out = nrow(d)))
  d$g_b <- factor(rep(c("a", "c"), length.out = nrow(d)))
  expect_error(.sem_expand_factors(fc_tab("y ~ g + g_b"), d, FALSE), "g_b_c")
})

test_that("a character fixed_x names all of a factor's dummies; a dummy name selects one", {
  d <- fc_data()
  tab <- fc_tab("y ~ x + g\nm ~ x")
  expect_equal(.sem_expand_factors(tab, d, "g")$fixed_x, c("g_b", "g_c"))
  expect_equal(.sem_expand_factors(tab, d, c("x", "g"))$fixed_x, c("x", "g_b", "g_c"))
  expect_equal(.sem_expand_factors(tab, d, "g_b")$fixed_x, "g_b")
  expect_identical(.sem_expand_factors(tab, d, TRUE)$fixed_x, TRUE)
  expect_identical(.sem_expand_factors(tab, d, FALSE)$fixed_x, FALSE)
})
