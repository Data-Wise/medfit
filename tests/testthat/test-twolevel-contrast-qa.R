# Independent oracle QA of the two-level contrast rule (C-Q1) and numeric equality detector (C-Q2).
# Own fits (a second seed, an unbalanced design, linear and nonlinear equality forms); oracles are lavaan's
# own `:=` (value and delta SE) and a hand delta method on lavaan's free-parameter vcov. Written by the
# oracle QA agent, independent of test-twolevel-contrast.R.

qa_defs <- list(
  free = list(tl_model(), "a*b - a2*b2", character(0)),
  a_label = list(tl_model(within = "a*X", between = "a*X"), "a*b - a*b2", "a"),
  b_label = list(tl_model_b_shared(), "a*b - a2*b", "b"),
  alg_a = list(paste0(tl_model(), "  a^2 - a2^2 == 0\n"), "a*b - a2*b2", "a"),
  alg_b = list(paste0(tl_model(), "  b^2 - b2^2 == 0\n"), "a*b - a2*b2", "b"),
  lin_a = list(paste0(tl_model(), "  a - a2 == 0\n"), "a*b - a2*b2", "a"),
  dbl_a = list(paste0(tl_model(), "  2*a == 2*a2\n"), "a*b - a2*b2", "a"),
  both_label = list(tl_model_b_shared(within = "a*X", between = "a*X"), "a*b - a*b", c("a", "b")),
  alg_ab = list(paste0(tl_model(), "  a^2 - a2^2 == 0\n  b^2 - b2^2 == 0\n"), "a*b - a2*b2", c("a", "b")),
  dbl_ab = list(paste0(tl_model(), "  2*a == 2*a2\n  2*b == 2*b2\n"), "a*b - a2*b2", c("a", "b"))
)

qa_hand <- function(fit) {
  pt <- lavaan::parTable(fit)
  V <- lavaan::vcov(fit)
  pick <- function(level, l, r) {
    x <- pt[pt$op == "~" & pt$level == level & pt$lhs == l & pt$rhs == r, ]
    list(est = x$est, free = x$free)
  }
  aw <- pick(1, "M", "X")
  bw <- pick(1, "Y", "M")
  ab <- pick(2, "M", "X")
  bb <- pick(2, "Y", "M")
  g <- numeric(nrow(V))
  g[aw$free] <- g[aw$free] + bw$est
  g[bw$free] <- g[bw$free] + aw$est
  g[ab$free] <- g[ab$free] - bb$est
  g[bb$free] <- g[bb$free] - ab$est
  c(est = aw$est * bw$est - ab$est * bb$est, se = sqrt(max(drop(t(g) %*% V %*% g), 0)))
}

qa_check <- function(d, key) {
  spec <- qa_defs[[key]]
  fit <- tl_fit(d, paste0(spec[[1]], "nc := ", spec[[2]], "\n"))
  td <- tl_extract(fit)
  expect_true(td@between_identified, info = key)
  expect_identical(td@cross_level_equal, spec[[3]], info = key)
  t <- suppressWarnings(tidy(td, type = "effects"))
  row <- t[t$term == "nie_contrast", ]
  if (all(c("a", "b") %in% spec[[3]])) {
    expect_true(is.na(row$estimate), info = key)
    expect_true(is.na(row$std_error), info = key)
    expect_error(twolevel_statistic(td, "nie_contrast"), class = "medfit_error_twolevel_constrained")
    expect_warning(e <- nie(td, level = "contrast"), class = "medfit_warning_twolevel_constrained")
    expect_true(is.na(as.numeric(unclass(e))))
  } else {
    pe <- lavaan::parameterEstimates(fit)
    o <- pe[pe$op == ":=" & pe$lhs == "nc", ]
    h <- qa_hand(fit)
    expect_equal(row$estimate, o$est, tolerance = 1e-4, info = key)
    expect_equal(row$std_error, o$se, tolerance = 1e-4, info = key)
    expect_equal(row$estimate, unname(h["est"]), tolerance = 1e-4, info = key)
    expect_equal(row$std_error, unname(h["se"]), tolerance = 1e-4, info = key)
    expect_gt(row$std_error, 0)
    expect_type(twolevel_statistic(td, "nie_contrast"), "closure")
  }
}

test_that("QA: contrast and delta SE match lavaan := and a hand delta method (seed 777)", {
  skip_if_not_installed("lavaan")
  d <- tl_cached("qa_d777", tl_sim(seed = 777L))
  for (key in names(qa_defs)) qa_check(d, key)
})

test_that("QA: unbalanced clusters, a-only, b-only, linear both", {
  skip_if_not_installed("lavaan")
  d <- tl_cached("qa_unbal", {
    x <- tl_sim(J = 60L, n = 8L, seed = 11L)
    set.seed(9)
    x[unlist(lapply(split(seq_len(nrow(x)), x$id), function(ix) ix[seq_len(sample(3:8, 1))])), ]
  })
  for (key in c("a_label", "b_label", "alg_a", "alg_b", "dbl_ab")) qa_check(d, key)
})

test_that("QA: detector has no false positive on free fits and keeps unequal-but-collinear pairs unflagged", {
  skip_if_not_installed("lavaan")
  td <- tl_extract(tl_fixture("base"))
  expect_identical(td@cross_level_equal, character(0))
  expect_true(.twolevel_contrast_available(td))
  for (p in c("a", "b", "c_prime")) {
    nm <- paste0(p, c("_within", "_between"))
    est <- c(S7::prop(td, nm[1]), S7::prop(td, nm[2]))
    expect_false(.twolevel_pair_equal(est, td@vcov[nm, nm]), info = p)
  }
  v <- function(r, s = 0.01) matrix(c(s, r * s, r * s, s), 2)
  expect_true(.twolevel_pair_equal(c(0.5, 0.5 + 9e-9), v(1)))
  expect_false(.twolevel_pair_equal(c(0.5, 0.5 + 9e-9), v(0.9)))        # equal estimates, free pair
  expect_false(.twolevel_pair_equal(c(0.5, -0.5), v(-1)))               # perfect anticorrelation
  expect_false(.twolevel_pair_equal(c(0.5, 1), matrix(c(1, 2, 2, 4), 2) * 0.01)) # proportional, corr 1
  expect_false(.twolevel_pair_equal(c(1e-7, 3e-7), diag(1e-8, 2)))       # both near zero, unequal, sizable SE
  expect_true(.twolevel_pair_equal(c(1e-7, 1e-7 + 1e-12), v(1, 1e-8)))   # both near zero, equated
  expect_true(.twolevel_pair_equal(c(550, 550 + 1e-9), v(1, 1e4)))       # large scale, equated
  expect_false(.twolevel_pair_equal(c(550, 551), v(1, 1e4)))             # large scale, unequal
  expect_false(.twolevel_pair_equal(c(0.5, 0.5), matrix(NA_real_, 2, 2)))
})

test_that("QA: algebraic equality at a rescaled outcome (Y x 100) is still detected", {
  skip_if_not_installed("lavaan")
  d <- tl_cached("qa_y100", {
    x <- tl_sim(seed = 20261110L)
    x$M <- x$M * 100
    x$Y <- x$Y * 100
    x
  })
  fit <- tl_fit(d, paste0(tl_model(), "  a^2 - a2^2 == 0\n  b^2 - b2^2 == 0\n"))
  expect_identical(tl_extract(fit)@cross_level_equal, c("a", "b"))
})
