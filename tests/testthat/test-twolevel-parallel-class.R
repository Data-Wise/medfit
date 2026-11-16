# TwoLevelParallelMediationData (IG5 T1, SPEC-IG5 D1): constructor, validator branches, within-only object,
# alias rows, registration, print. No lavaan needed: the objects are built by hand (`tlp_td()`).

test_that("a valid object for k = 2 carries named path vectors and the alias rows", {
  td <- tlp_td(k = 2L)
  expect_true(S7::S7_inherits(td, TwoLevelParallelMediationData))
  expect_identical(td@mediators, c("M1", "M2"))
  for (nm in c("a_within", "b_within", "a_between", "b_between")) {
    expect_identical(names(S7::prop(td, nm)), c("M1", "M2"), info = nm)
  }
  expect_length(td@c_prime_within, 1L)
  expect_length(td@c_prime_between, 1L)
  expect_identical(
    names(td@estimates),
    c("a_M1_within", "a_M2_within", "b_M1_within", "b_M2_within", "c_prime_within",
      "a_M1_between", "a_M2_between", "b_M1_between", "b_M2_between", "c_prime_between")
  )
  expect_identical(rownames(td@vcov), names(td@estimates))
  expect_equal(unname(td@estimates["b_M2_between"]), unname(td@b_between["M2"]))
})

test_that("a valid object for k = 3 has a 2(2k + 1) block", {
  td <- tlp_td(k = 3L)
  expect_identical(td@mediators, c("M1", "M2", "M3"))
  expect_identical(dim(td@vcov), c(14L, 14L))
  expect_length(td@a_between, 3L)
})

test_that("the class is exported and S4-registered", {
  expect_true("TwoLevelParallelMediationData" %in% getNamespaceExports("medfit"))
  expect_true(methods::is(tlp_td(), "medfit::TwoLevelParallelMediationData"))
  # a separate class, not a TwoLevelMediationData (D1)
  expect_false(S7::S7_inherits(tlp_td(), TwoLevelMediationData))
})

test_that("a within-only object keeps the within rows and all-NA between vectors", {
  td <- tlp_td(k = 2L, within_only = TRUE)
  expect_false(td@between_identified)
  expect_true(all(is.na(td@a_between)) && all(is.na(td@b_between)) && is.na(td@c_prime_between))
  expect_identical(names(td@a_between), c("M1", "M2"))
  expect_identical(dim(td@vcov), c(5L, 5L))
})

test_that("the validator requires at least two mediators", {
  meds <- "M1"
  one <- function(v) stats::setNames(v, meds)
  expect_error(
    tlp_td(mediators = meds, a_within = one(0.4), b_within = one(0.5), a_between = one(0.7),
           b_between = one(1.0)),
    "at least 2 mediators"
  )
})

test_that("the validator rejects a path vector whose length differs from mediators", {
  td <- tlp_td(k = 2L)
  for (nm in c("a_within", "b_within", "a_between", "b_between")) {
    long <- c(S7::prop(td, nm), M3 = 0.2)
    args <- stats::setNames(list(long), nm)
    expect_error(do.call(tlp_td, args), paste0(nm, " must have length 2"), info = nm)
    short <- S7::prop(td, nm)[1L]
    args <- stats::setNames(list(short), nm)
    expect_error(do.call(tlp_td, args), paste0(nm, " must have length 2"), info = nm)
  }
  # the within-only all-NA vectors are held to the same length
  expect_error(tlp_td(within_only = TRUE, a_between = c(M1 = NA_real_)), "a_between must have length 2")
})

test_that("the validator rejects duplicate, missing or empty mediator names", {
  expect_error(tlp_td(mediators = c("M1", "M1")), "unique")
  expect_error(tlp_td(mediators = c("M1", NA_character_)), "mediators")
  expect_error(tlp_td(mediators = c("M1", "")), "mediators")
})

test_that("the validator rejects path names that do not match mediators", {
  td <- tlp_td(k = 2L)
  for (nm in c("a_within", "b_within", "a_between", "b_between")) {
    v <- S7::prop(td, nm)
    swapped <- stats::setNames(v, rev(names(v)))
    args <- stats::setNames(list(swapped), nm)
    expect_error(do.call(tlp_td, args), paste0("names\\(", nm, "\\) must equal mediators"), info = nm)
    unnamed <- unname(v)
    args <- stats::setNames(list(unnamed), nm)
    expect_error(do.call(tlp_td, args), paste0("names\\(", nm, "\\) must equal mediators"), info = nm)
  }
})

test_that("the validator applies the within-only NA rules", {
  td <- tlp_td(k = 2L)
  # within paths are always finite
  bad <- td@a_within
  bad[["M2"]] <- NA_real_
  expect_error(tlp_td(a_within = bad), "a_within must be finite")
  expect_error(tlp_td(c_prime_within = NA_real_), "c_prime_within")
  # identified: between paths finite
  bad <- td@b_between
  bad[["M1"]] <- NA_real_
  expect_error(tlp_td(b_between = bad), "b_between must be finite when between_identified is TRUE")
  expect_error(tlp_td(c_prime_between = NA_real_), "c_prime_between must be finite")
  # within-only: every between value NA, no between rows, no equated paths
  w <- tlp_td(k = 2L, within_only = TRUE)
  part <- w@a_between
  part[["M1"]] <- 0.7
  expect_error(tlp_td(within_only = TRUE, a_between = part), "a_between must be NA when between_identified is FALSE")
  expect_error(tlp_td(within_only = TRUE, c_prime_between = 0.1), "c_prime_between must be NA")
  expect_error(
    tlp_td(within_only = TRUE, estimates = td@estimates, vcov = td@vcov),
    "must not carry between rows"
  )
  expect_error(tlp_td(within_only = TRUE, cross_level_equal = "a_M1"), "cross_level_equal")
  # identified object without its between rows
  expect_error(tlp_td(estimates = w@estimates, vcov = w@vcov), "alias rows")
})

test_that("the validator checks alias values, dimnames, scalars and design", {
  td <- tlp_td(k = 2L)
  est <- td@estimates
  est["b_M2_within"] <- 0.9
  expect_error(tlp_td(estimates = est), "alias rows of estimates")
  vc <- td@vcov
  dimnames(vc) <- list(rev(rownames(vc)), rev(colnames(vc)))
  expect_error(tlp_td(vcov = vc), "dimnames")
  expect_error(tlp_td(vcov = td@vcov[1:5, 1:5]), "dimensions")
  expect_error(tlp_td(treatment = c("X", "Z")), "treatment")
  expect_error(tlp_td(n_clusters = 99L), "n_clusters")
  expect_error(tlp_td(icc = c(X = 1.2, M1 = 0.3, M2 = 0.3, Y = 0.4)), "icc")
  expect_error(tlp_td(source = "mplus"), "source")
  expect_error(tlp_td(fixed_paths = "a_M9_within"), "fixed_paths")
  expect_error(tlp_td(parameter_table = data.frame(path = "a")), "parameter_table")
  vc <- td@vcov
  vc[1, 2] <- vc[1, 2] + 0.5
  expect_error(tlp_td(vcov = vc), "symmetric")
  expect_error(tlp_td(source_version = ""), "source_version")
})

test_that("planted defect: an alias row keyed to the wrong mediator is caught", {
  td <- tlp_td(k = 2L)
  est <- td@estimates
  # swap the values of the two b rows: names stay, values no longer match the properties
  est[c("b_M1_within", "b_M2_within")] <- est[c("b_M2_within", "b_M1_within")]
  expect_error(tlp_td(estimates = est), "alias rows of estimates")
})

test_that("print shows the design, each mediator's paths per level and the total NIE", {
  td <- tlp_td(k = 2L)
  out <- paste(utils::capture.output(print(td)), collapse = "\n")
  expect_match(out, "<TwoLevelParallelMediationData>", fixed = TRUE)
  expect_match(out, "X -> {M1, M2} -> Y", fixed = TRUE)
  expect_match(out, "100 clusters", fixed = TRUE)
  expect_match(out, "ICC", fixed = TRUE)
  expect_match(out, "M2", fixed = TRUE)
  expect_match(out, "c_prime_within", fixed = TRUE)
  nie_w <- sum(td@a_within * td@b_within)
  expect_match(out, sprintf("%+.4f", nie_w), fixed = TRUE)
  expect_identical(utils::capture.output(td), utils::capture.output(print(td)))
})

test_that("print of a within-only object says the between level is not identified", {
  out <- paste(utils::capture.output(print(tlp_td(k = 3L, within_only = TRUE))), collapse = "\n")
  expect_match(out, "within-only", fixed = TRUE)
  expect_match(out, "not identified", fixed = TRUE)
  expect_false(grepl("NIE between", out, fixed = TRUE))
})

test_that("print flags equated, fixed and inadmissible fits", {
  out <- paste(utils::capture.output(print(tlp_td(cross_level_equal = "a_M1", fixed_paths = "c_prime_between",
                                                  admissible = FALSE))), collapse = "\n")
  expect_match(out, "equated across levels: a_M1", fixed = TRUE)
  expect_match(out, "fixed: c_prime_between", fixed = TRUE)
  expect_match(out, "not admissible", fixed = TRUE)
})
