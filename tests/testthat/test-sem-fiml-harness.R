test_that("FIML derivative oracle preserves polynomial curvature and names", {
  q <- c(x = 0, y = 2)
  fun <- function(q) c(q[["x"]]^2 + 3 * q[["x"]] * q[["y"]], q[["y"]]^2)
  expect_equal(fo_jacobian(fun, q), matrix(c(6, 0, 0, 4), 2), tolerance = 1e-8)
  expect_equal(fo_hessian(function(q) fun(q)[1], q, .01),
               matrix(c(2, 3, 3, 0), 2), tolerance = 1e-7)
})

test_that("FIML evidence output rejects caller-relative paths and survives CWD changes", {
  expect_error(fo_write_records(data.frame(x = 1), "relative.csv"), "absolute")
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  old <- setwd(tempdir())
  on.exit(setwd(old), add = TRUE)
  fo_write_records(data.frame(x = 1), path)
  expect_equal(utils::read.csv(path)$x, 1L)
})

test_that("FIML regression limits discriminate planted likelihood and affine defects", {
  q <- fo_truth("mar", TRUE)
  d <- fo_fixture("mar", TRUE)
  nll <- fo_nll(d, q)
  wrong_nll <- nll - sum(!is.na(d)) * log(2 * pi) / 2
  expect_gt(abs(nll - wrong_nll), 1e-7)
  affine <- fo_affine(q, c(3, .5, 2), c(2, -3, 4))
  back <- fo_affine(affine, 1 / c(3, .5, 2), -c(2, -3, 4) / c(3, .5, 2))
  expect_equal(back, q, tolerance = 1e-12)
  wrong <- back
  wrong[c("X~1", "M~1", "Y~1")] <- affine[c("X~1", "M~1", "Y~1")]
  expect_gt(max(abs(wrong - q)), 1e-5)
  J <- fo_jacobian(function(q) fo_affine(q, c(3, .5, 2), c(2, -3, 4)), q)
  V <- tcrossprod(J)
  wrong_v <- tcrossprod(diag(diag(J)))
  expect_gt(max(abs(V - wrong_v) / sqrt(outer(diag(V), diag(V)))), 1e-3)
  geometry <- fo_spectrum(fo_geometry(fo_fixture("unidentified", TRUE), q))
  expect_equal(sum(geometry > 1e-7), 7L)
  expect_lt(sum(geometry > 1e-7), length(q))
})
