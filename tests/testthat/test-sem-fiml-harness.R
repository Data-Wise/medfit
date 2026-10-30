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
  record <- data.frame(
    cell = "mar-free", outcome = "fit", coefficient = 0, covariance = 0,
    nll = 0, fixed_nll = 0, geometry_min = 1, geometry_max = 1,
    information_min = 1, information_max = 1, modelcov_min = 1, modelcov_max = 1,
    modelcov_at = "reference optimum"
  )
  fo_write_records(record, path)
  expect_equal(utils::read.csv(path)$cell, "mar-free")
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

test_that("FIML oracle checks exact independent parameter sets before comparisons", {
  for (direct in c(TRUE, FALSE)) {
    q <- fo_truth("mar", direct)
    V <- diag(length(q))
    dimnames(V) <- list(names(q), names(q))
    expect_no_error(fo_assert_parameters(q, V, direct))
    expect_error(fo_assert_parameters(q[-1], V, direct), "coefficient")
    duplicated <- q
    names(duplicated)[length(q)] <- "a"
    expect_error(fo_assert_parameters(duplicated, V, direct), "coefficient")
    expect_error(fo_assert_parameters(c(q, extra = 0), V, direct), "coefficient")
    expect_error(fo_assert_parameters(q, V[-1, , drop = FALSE], direct), "covariance")
    malformed <- V
    colnames(malformed)[length(q)] <- "a"
    expect_error(fo_assert_parameters(q, malformed, direct), "covariance")
    malformed <- V
    rownames(malformed) <- NULL
    expect_error(fo_assert_parameters(q, malformed, direct), "covariance")
    expect_no_error(fo_assert_parameters(rev(q), V, direct))
  }
})

test_that("FIML evidence writer requires all declared spectral fields without duplicates", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  record <- data.frame(
    cell = "mar-free", outcome = "fit", coefficient = 0, covariance = 0,
    nll = 0, fixed_nll = 0, geometry_min = 1, geometry_max = 1,
    information_min = 1, information_max = 1, modelcov_min = 1, modelcov_max = 1,
    modelcov_at = "reference optimum"
  )
  expect_no_error(fo_write_records(record, path))
  expect_error(fo_write_records(record[, names(record) != "modelcov_min"], path), "schema")
  duplicated <- record
  names(duplicated)[ncol(duplicated)] <- "modelcov_min"
  expect_error(fo_write_records(duplicated, path), "schema")
  expect_error(fo_write_records(cbind(record, extra = 0), path), "schema")
  expect_equal(utils::read.csv(path)$modelcov_min, 1)
})
