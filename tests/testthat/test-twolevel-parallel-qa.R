# IG5 T2 oracle QA: cells the implementer's tests did not pin (each one caught a planted defect that the suite
# missed). Oracle for k = 3: lavaan's parameter table read by (lhs, op, rhs, level), never by label or key order.

skip_on_cran() # Windows check time (0.21.3): runs in CI and the local full run

skip_if_not_installed("lavaan")

test_that("k = 3 with a covariate: paths and the 14 x 14 vcov equal lavaan's, read by lhs/rhs/level", {
  # Three parallel mediators and a covariate W at both levels; unlabeled except for b3 (equated by a `==` row).
  fit <- tl_cached("tlq_fit_k3", {
    set.seed(11)
    J <- 120L
    n <- 6L
    id <- rep(seq_len(J), each = n)
    N <- J * n
    xb <- stats::rnorm(J)[id]
    xw <- stats::rnorm(N)
    wb <- stats::rnorm(J)[id]
    ww <- stats::rnorm(N)
    m1 <- 0.5 * xw + 0.7 * xb + 0.2 * ww + 0.3 * wb + 0.6 * stats::rnorm(J)[id] + stats::rnorm(N)
    m2 <- 0.3 * xw + 0.2 * xb - 0.2 * ww + 0.5 * stats::rnorm(J)[id] + stats::rnorm(N) + 0.4 * m1
    m3 <- -0.4 * xw + 0.5 * xb + 0.1 * ww + 0.6 * stats::rnorm(J)[id] + stats::rnorm(N)
    y <- 0.2 * xw + 0.3 * xb + 0.4 * m1 + 0.3 * m2 - 0.5 * m3 + 0.2 * ww + 0.5 * stats::rnorm(J)[id] +
      stats::rnorm(N)
    d <- data.frame(id = id, X = xw + xb, W = ww + wb, M1 = m1, M2 = m2, M3 = m3, Y = y)
    blk <- function(b3) {
      paste0(
        "  M1 ~ X + W\n  M2 ~ X + W\n  M3 ~ X + W\n  Y ~ M1 + M2 + ", b3, "*M3 + X + W\n",
        "  M1 ~~ M2 + M3\n  M2 ~~ M3\n"
      )
    }
    tl_fit(d, paste0("level: 1\n", blk("b3w"), "level: 2\n", blk("b3b"), "  b3w == b3b\n"))
  })
  meds <- c("M1", "M2", "M3")
  td <- tlp_extract(fit, mediator = meds)
  expect_true(S7::S7_inherits(td, TwoLevelParallelMediationData))
  pt <- lavaan::parTable(fit)
  row <- function(lhs, rhs, lev) {
    i <- which(pt$op == "~" & pt$lhs == lhs & pt$rhs == rhs & pt$level == lev)
    expect_length(i, 1L)
    i
  }
  idx <- unlist(lapply(1:2, function(lev) {
    c(vapply(meds, function(m) row(m, "X", lev), 1L), vapply(meds, function(m) row("Y", m, lev), 1L),
      row("Y", "X", lev))
  }))
  nm <- c(paste0(rep(c("a_", "b_"), each = 3L), meds, "_within"), "c_prime_within",
          paste0(rep(c("a_", "b_"), each = 3L), meds, "_between"), "c_prime_between")
  expect_identical(names(td@estimates), nm)
  expect_equal(unname(td@estimates), pt$est[idx], tolerance = 1e-12)
  V <- unclass(lavaan::vcov(fit))[pt$free[idx], pt$free[idx]]
  expect_identical(dim(td@vcov), c(14L, 14L))
  expect_equal(unname(td@vcov), unname(V), tolerance = 1e-12)
  expect_gt(abs(td@vcov["a_M1_within", "a_M3_within"]), 1e-6)
  # The third mediator's b is equated by a `==` row: found by stem, and only that mediator
  expect_identical(td@cross_level_equal, "b_M3")
  expect_identical(.twolevel_parallel_contrast_available(td), c(M1 = TRUE, M2 = TRUE, M3 = TRUE, total = TRUE))
})

test_that("D2 names the low-ICC mediator when the mediators are not passed in sorted order", {
  fit <- tlp_fixture("low_icc_m2")
  w <- tl_catch(extract_mediation(fit, "X", c("M2", "M1"), "Y"), "medfit_between_unidentified")
  expect_s3_class(w, "medfit_between_unidentified")
  expect_match(conditionMessage(w), "the ICC of the mediator 'M2'", fixed = TRUE)
  expect_no_match(conditionMessage(w), "the ICC of the mediator 'M1'", fixed = TRUE)
  # Every low mediator is named, not only the first
  real <- .twolevel_icc
  testthat::local_mocked_bindings(.twolevel_icc = function(fit) {
    icc <- real(fit)
    icc[c("M1", "M2")] <- 0.001
    icc
  })
  w <- tl_catch(extract_mediation(tlp_fixture("base"), "X", c("M1", "M2"), "Y"), "medfit_between_unidentified")
  expect_match(conditionMessage(w), "the ICC of the mediator 'M1'", fixed = TRUE)
  expect_match(conditionMessage(w), "the ICC of the mediator 'M2'", fixed = TRUE)
})

test_that("a within-only object has no contrast available for any mediator or the total", {
  td <- tlp_extract(tlp_fixture("low_icc_m2"))
  expect_false(td@between_identified)
  expect_identical(.twolevel_parallel_contrast_available(td), c(M1 = FALSE, M2 = FALSE, total = FALSE))
})

test_that("the weak-ICC warning fires for a small ICC in any mediator, not only the first", {
  fit <- tlp_fixture("base")
  real <- .twolevel_icc
  for (low in c("M1", "M2")) {
    testthat::local_mocked_bindings(.twolevel_icc = function(fit) {
      icc <- real(fit)
      icc[[low]] <- 0.03
      icc
    })
    w <- tl_catch(extract_mediation(fit, "X", c("M1", "M2"), "Y"), "medfit_warning_between_weak")
    expect_s3_class(w, "medfit_warning_between_weak")
    expect_true(tlp_extract(fit)@between_identified)
  }
})

test_that("a non-finite between entry of the 10 x 10 block is found in the between rows (k = 2)", {
  fit <- tlp_fixture("base")
  real <- .twolevel_subvcov
  testthat::local_mocked_bindings(.twolevel_subvcov = function(V, key) {
    v <- real(V, key)
    i <- match("b_M2_between", key$path)
    v[i, i] <- NaN
    v
  })
  w <- tl_catch(extract_mediation(fit, "X", c("M1", "M2"), "Y"), "medfit_between_unidentified")
  expect_s3_class(w, "medfit_between_unidentified")
  expect_match(conditionMessage(w), "a between-level covariance entry is not finite", fixed = TRUE)
  td <- tlp_extract(fit)
  expect_false(td@between_identified)
  expect_identical(dim(td@vcov), c(5L, 5L))
})

test_that("the covariate-as-mediator refusal is decided per level; true serial and in-model covariates are unchanged", {
  # W is regressed on X within, but at the between level it only predicts M1: a covariate there, named at that level
  fit <- tl_cached("tlq_covariate_between", tl_fit(tlp_sim_w(), paste0(
    "level: 1\n  M1 ~ X\n  W ~ X\n  Y ~ M1 + W + X\n",
    "level: 2\n  M1 ~ X + W\n  Y ~ M1 + W + X\n"
  )))
  err <- tl_catch(extract_mediation(fit, "X", c("M1", "W"), "Y"), "medfit_error_twolevel_unsupported")
  expect_s3_class(err, "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "(no 'W ~ X' row at the between level); it predicts the mediator 'M1'",
               fixed = TRUE)
  # A genuine serial row (M2 regressed on X too) keeps the serial message at either level
  for (lev in c("within", "between")) {
    err <- tl_catch(extract_mediation(tlp_fixture(paste0("serial_", lev)), "X", c("M1", "M2"), "Y"),
                    "medfit_error_twolevel_unsupported")
    expect_match(conditionMessage(err), sprintf("('M2 ~ M1' at the %s level): serial mediation", lev), fixed = TRUE)
    expect_no_match(conditionMessage(err), "is not regressed on the treatment", fixed = TRUE)
  }
  # W in the model but not declared a mediator: no refusal
  expect_true(S7::S7_inherits(tlp_extract(tlp_fixture("covariate_w")), TwoLevelParallelMediationData))
})
