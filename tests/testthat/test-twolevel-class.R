# TwoLevelMediationData: constructor, validator branches, within-only object, alias rows, registration, print
# (#394, slice S2). No lavaan needed: the objects are built by hand.

test_that("a valid object carries the six paths as properties and as alias rows", {
  td <- tl_td()
  expect_true(S7::S7_inherits(td, TwoLevelMediationData))
  expect_equal(td@a_within, 0.4)
  expect_equal(td@c_prime_between, -0.1)
  expect_identical(
    names(td@estimates),
    c("a_within", "b_within", "c_prime_within", "a_between", "b_between", "c_prime_between")
  )
  expect_identical(rownames(td@vcov), names(td@estimates))
  expect_identical(td@source, "lavaan")
  expect_identical(td@between_parameterization, "latent")
})

test_that("the class is exported and S4-registered", {
  expect_true("TwoLevelMediationData" %in% getNamespaceExports("medfit"))
  td <- tl_td()
  expect_true(methods::is(td, "medfit::TwoLevelMediationData"))
})

test_that("a within-only object keeps three rows and NA between paths", {
  td <- tl_td(within_only = TRUE)
  expect_false(td@between_identified)
  expect_true(is.na(td@a_between) && is.na(td@b_between) && is.na(td@c_prime_between))
  expect_identical(names(td@estimates), c("a_within", "b_within", "c_prime_within"))
  expect_identical(dim(td@vcov), c(3L, 3L))
  expect_false(anyNA(td@vcov))
})

test_that("the validator rejects a within-only object that keeps between rows or properties", {
  full <- tl_td()
  expect_error(
    tl_td(within_only = TRUE, estimates = full@estimates, vcov = full@vcov),
    "between rows|alias rows|between_identified"
  )
  expect_error(tl_td(within_only = TRUE, a_between = 0.7), "NA")
  expect_error(
    tl_td(within_only = TRUE, cross_level_equal = "a"),
    "cross_level_equal"
  )
})

test_that("the validator rejects an identified object that lacks between rows", {
  w <- tl_td(within_only = TRUE)
  expect_error(
    tl_td(estimates = w@estimates, vcov = w@vcov),
    "alias rows"
  )
})

test_that("the validator checks scalars, design and dimensions", {
  expect_error(tl_td(a_within = NA_real_), "a_within")
  expect_error(tl_td(treatment = c("X", "Z")), "treatment")
  expect_error(tl_td(n_clusters = 99L), "n_clusters")
  expect_error(tl_td(n_clusters = 1L, cluster_sizes = 5L), "at least 2")
  expect_error(tl_td(cluster_sizes = c(rep(5L, 99L), 0L)), "cluster_sizes")
  td <- tl_td()
  bad <- td@vcov[1:5, 1:5]
  expect_error(tl_td(vcov = bad), "vcov|dimensions")
  nonsq <- td@vcov[, 1:5]
  expect_error(tl_td(vcov = nonsq), "square")
})

test_that("the validator checks names, dimnames, alias values and finiteness", {
  td <- tl_td()
  dup <- td@estimates
  names(dup)[2] <- "a_within"
  expect_error(tl_td(estimates = dup), "unique names")
  vc <- td@vcov
  dimnames(vc) <- list(rev(rownames(vc)), rev(colnames(vc)))
  expect_error(tl_td(vcov = vc), "dimnames")
  est <- td@estimates
  est["a_within"] <- 0.9
  expect_error(tl_td(estimates = est), "alias rows of estimates")
  vc2 <- td@vcov
  vc2[1, 1] <- NA_real_
  expect_error(tl_td(vcov = vc2), "finite")
})

test_that("the validator checks ICC range and source", {
  expect_error(tl_td(icc = c(X = 1.2, M = 0.3, Y = 0.4)), "icc")
  expect_error(tl_td(icc = c(X = -0.1, M = 0.3, Y = 0.4)), "icc")
  expect_error(tl_td(source = "mplus"), "source")
  expect_s3_class(tl_td(source = "native"), "S7_object")
})

test_that("print shows the design, paths, ICCs and the descriptive contrast", {
  td <- tl_td()
  out <- paste(utils::capture.output(print(td)), collapse = "\n")
  expect_match(out, "<TwoLevelMediationData>", fixed = TRUE)
  expect_match(out, "100 clusters", fixed = TRUE)
  expect_match(out, "ICC", fixed = TRUE)
  expect_match(out, "a_within", fixed = TRUE)
  expect_match(out, "descriptive", fixed = TRUE)
  expect_match(out, "within", fixed = TRUE)
  expect_identical(utils::capture.output(td), utils::capture.output(print(td)))
})

test_that("print of a within-only object says between is unidentified and prints no between NIE", {
  out <- paste(utils::capture.output(print(tl_td(within_only = TRUE))), collapse = "\n")
  expect_match(out, "within-only", fixed = TRUE)
  expect_match(out, "not identified", fixed = TRUE)
})

test_that("print flags equated paths and fixed paths", {
  out <- paste(utils::capture.output(print(tl_td(cross_level_equal = "a", fixed_paths = "c_prime_between"))),
               collapse = "\n")
  expect_match(out, "equated across levels: a", fixed = TRUE)
  expect_match(out, "fixed: c_prime_between", fixed = TRUE)
})


# --- Hardening 6: validator gaps ---

test_that("the validator rejects non-finite estimates, an asymmetric or negative-variance vcov", {
  td <- tl_td()
  est <- td@estimates
  est[["b_between"]] <- Inf
  expect_error(tl_td(estimates = est), "estimates must be finite")
  est <- td@estimates
  est[["a_within"]] <- NA_real_
  expect_error(tl_td(estimates = est), "estimates must be finite")

  vc <- td@vcov
  vc[1, 2] <- vc[1, 2] + 0.5
  expect_error(tl_td(vcov = vc), "symmetric")
  vc <- td@vcov
  vc[2, 2] <- -0.01
  expect_error(tl_td(vcov = vc), "diagonal")
  # a tiny asymmetry from floating point is accepted
  vc <- td@vcov
  vc[1, 2] <- 1e-14
  expect_no_error(tl_td(vcov = vc))
})

test_that("the validator rejects fixed_paths that are not path rows of the estimates", {
  expect_error(tl_td(fixed_paths = "a_other"), "fixed_paths")
  expect_error(tl_td(within_only = TRUE, fixed_paths = "a_between"), "fixed_paths")
  expect_no_error(tl_td(fixed_paths = c("a_within", "c_prime_between")))
})

test_that("the validator requires n_obs to equal the sum of cluster_sizes", {
  expect_error(tl_td(n_obs = 499L), "n_obs")
  expect_error(tl_td(n_obs = 501L), "cluster_sizes")
})
