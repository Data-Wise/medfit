# Unit tests for R/utils.R internal helpers (testthat 3e).
#
# `.expand_vcov_with_aliases()` is the shared engine that appends named path
# aliases (a, b, c_prime, d1, ...) to a source covariance matrix, copying the
# FULL source row/column -- not just the diagonal variance -- so off-diagonal
# covariances (e.g. cov(b, c_prime)) survive. It is exercised indirectly by the
# lm/glm and lavaan extractors; these are direct, construction-based unit tests
# (no model fitting), so a regression in the helper is caught at its source.

# A labelled source covariance for two independent "equations" (mimics the lm
# extractor's prefixed coefficients). Block-diagonal across equations, with a
# non-zero within-equation off-diagonal cov(y_M, y_X) = 3.
make_src <- function() {
  m <- matrix(
    c(4, 1, 0, 0,
      1, 9, 0, 0,
      0, 0, 16, 3,
      0, 0, 3, 25),
    nrow = 4, byrow = TRUE
  )
  dimnames(m) <- list(
    c("m_X", "m_M", "y_M", "y_X"),
    c("m_X", "m_M", "y_M", "y_X")
  )
  m
}

# Standard alias->source mapping: a<-m_X, b<-y_M, c_prime<-y_X.
std_idx <- function() c(a = 1L, b = 3L, c_prime = 4L)

# ==============================================================================
# Shape, names, and preservation of the original block
# ==============================================================================

test_that("aliases are appended with correct dimensions and names", {
  out <- .expand_vcov_with_aliases(make_src(), std_idx(), c("a", "b", "c_prime"))

  expect_equal(dim(out), c(7L, 7L))
  expect_identical(
    rownames(out),
    c("m_X", "m_M", "y_M", "y_X", "a", "b", "c_prime")
  )
  expect_identical(rownames(out), colnames(out))
})

test_that("the original source block is preserved unchanged", {
  src <- make_src()
  out <- .expand_vcov_with_aliases(src, std_idx(), c("a", "b", "c_prime"))
  expect_equal(out[seq_len(4), seq_len(4)], src)
})

test_that("output is symmetric", {
  out <- .expand_vcov_with_aliases(make_src(), std_idx(), c("a", "b", "c_prime"))
  expect_equal(out, t(out))
})

# ==============================================================================
# Full row/column copy (variance + cross-covariances), not diagonal-only
# ==============================================================================

test_that("alias diagonal equals its source variance", {
  src <- make_src()
  out <- .expand_vcov_with_aliases(src, std_idx(), c("a", "b", "c_prime"))
  expect_equal(out[["a", "a"]], src[["m_X", "m_X"]])             # 4
  expect_equal(out[["b", "b"]], src[["y_M", "y_M"]])             # 16
  expect_equal(out[["c_prime", "c_prime"]], src[["y_X", "y_X"]]) # 25
})

test_that("alias inherits the full cross-covariance with the original block", {
  src <- make_src()
  out <- .expand_vcov_with_aliases(src, std_idx(), c("a", "b", "c_prime"))
  # a <- m_X: covariance with m_M is 1
  expect_equal(out[["a", "m_M"]], src[["m_X", "m_M"]])  # 1
  expect_equal(out[["m_M", "a"]], src[["m_M", "m_X"]])  # symmetric
  # b <- y_M: covariance with y_X is 3
  expect_equal(out[["b", "y_X"]], src[["y_M", "y_X"]])  # 3
})

test_that("alias-to-alias covariance is preserved (cov(b, c_prime) survives)", {
  src <- make_src()
  out <- .expand_vcov_with_aliases(src, std_idx(), c("a", "b", "c_prime"))
  # b <- y_M, c_prime <- y_X: same equation, source cov = 3 must carry over.
  expect_equal(out[["b", "c_prime"]], src[["y_M", "y_X"]])  # 3
  expect_equal(out[["c_prime", "b"]], src[["y_X", "y_M"]])
  # a (equation 1) vs b (equation 2): independent, must stay 0.
  expect_equal(out[["a", "b"]], 0)
  expect_equal(out[["a", "c_prime"]], 0)
})

# ==============================================================================
# NA source index -> zero-variance placeholder
# ==============================================================================

test_that("an NA source index leaves the alias as an all-zero row/column", {
  src <- make_src()
  # c_prime not resolvable (e.g. direct path absent) -> NA placeholder.
  idx <- c(a = 1L, b = 3L, c_prime = NA_integer_)
  out <- .expand_vcov_with_aliases(src, idx, c("a", "b", "c_prime"))

  expect_equal(unname(out["c_prime", ]), rep(0, 7))
  expect_equal(unname(out[, "c_prime"]), rep(0, 7))
  # Resolvable aliases are unaffected.
  expect_equal(out[["b", "b"]], src[["y_M", "y_M"]])
  expect_equal(out[["b", "c_prime"]], 0)  # one side NA -> 0
})

# ==============================================================================
# Serial-style aliases (a, d1, b, c_prime)
# ==============================================================================

test_that("serial d-label aliases expand correctly with preserved off-diagonals", {
  # Serial chain source: m1_X, m2_M1, y_M2, y_X with cov(y_M2, y_X) = 1.5.
  m <- diag(c(2, 5, 7, 11))
  m[3, 4] <- 1.5
  m[4, 3] <- 1.5
  dimnames(m) <- list(
    c("m1_X", "m2_M1", "y_M2", "y_X"),
    c("m1_X", "m2_M1", "y_M2", "y_X")
  )
  idx <- c(a = 1L, d1 = 2L, b = 3L, c_prime = 4L)
  out <- .expand_vcov_with_aliases(m, idx, c("a", "d1", "b", "c_prime"))

  expect_equal(dim(out), c(8L, 8L))
  expect_equal(out[["a", "a"]], 2)
  expect_equal(out[["d1", "d1"]], 5)
  expect_equal(out[["b", "b"]], 7)
  expect_equal(out[["b", "c_prime"]], 1.5)  # within-equation cov preserved
  expect_equal(out[["a", "d1"]], 0)         # separate equations -> independent
  expect_equal(out[["d1", "b"]], 0)
  expect_equal(out, t(out))
})

# ==============================================================================
# Edge cases
# ==============================================================================

test_that("a single alias expands to one new row/column", {
  src <- make_src()
  out <- .expand_vcov_with_aliases(src, c(a = 1L), "a")
  expect_equal(dim(out), c(5L, 5L))
  expect_equal(out[["a", "a"]], src[["m_X", "m_X"]])
  expect_equal(out[["a", "m_M"]], src[["m_X", "m_M"]])
})

test_that("no aliases returns the source matrix unchanged in value", {
  src <- make_src()
  out <- .expand_vcov_with_aliases(src, integer(0), character(0))
  expect_equal(dim(out), dim(src))
  expect_equal(unname(out), unname(src))
})
