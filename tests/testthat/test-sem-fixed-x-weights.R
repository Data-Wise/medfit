# V6: weights, the sandwich and missing rows (spec S2 and plan rule on the estimation sample).

test_that("subset invariance holds with weights, model-based and sandwich", {
  d <- fx_data()
  set.seed(7)
  w <- stats::runif(nrow(d), 0.5, 2)
  for (se in c("model", "sandwich")) {
    free <- fit_sem(fx_syntax, d, weights = w, se_type = se)
    for (sel in list(TRUE, "covariate1", c("treatment", "covariate2"))) {
      fixed <- fit_sem(fx_syntax, d, weights = w, se_type = se, fixed_x = sel)
      sh <- fx_shared(free, fixed)
      tag <- paste(se, paste(sel, collapse = ","))
      expect_equal(unname(sh$est[[2L]]), unname(sh$est[[1L]]), tolerance = 1e-8, info = tag)
      expect_equal(unname(sh$se[[2L]]), unname(sh$se[[1L]]), tolerance = 1e-6, info = tag)
    }
  }
})

test_that("fixed values are the weighted moments of the estimation sample", {
  d <- fx_data()
  set.seed(8)
  w <- stats::runif(nrow(d), 0.5, 2)
  fixed <- fit_sem(fx_syntax, d, weights = w, fixed_x = "covariate1", meanstructure = TRUE)
  ws <- w * nrow(d) / sum(w)
  xbar <- sum(ws * d$covariate1) / nrow(d)
  tab <- fixed@table
  expect_equal(tab$est[tab$lhs == "covariate1" & tab$op == "~1"], xbar, tolerance = 1e-12)
  expect_equal(tab$est[tab$lhs == "covariate1" & tab$op == "~~" & tab$rhs == "covariate1"],
               sum(ws * (d$covariate1 - xbar)^2) / nrow(d), tolerance = 1e-12)
})

test_that("missing rows are dropped once and the fixed values come from the rows that remain", {
  d <- fx_data()
  d$covariate1[c(3, 40, 99)] <- NA
  free <- suppressMessages(fit_sem(fx_syntax, d))
  fixed <- suppressMessages(fit_sem(fx_syntax, d, fixed_x = TRUE))
  keep <- stats::complete.cases(d[, c("treatment", "mediator1", "outcome", "covariate1", "covariate2")])
  tab <- fixed@table
  v <- tab[tab$lhs == "treatment" & tab$op == "~~" & tab$rhs == "treatment", "est"]
  expect_equal(v, mean((d$treatment[keep] - mean(d$treatment[keep]))^2), tolerance = 1e-12)
  expect_identical(fixed@n_obs, free@n_obs)
  sh <- fx_shared(free, fixed)
  expect_equal(unname(sh$est[[2L]]), unname(sh$est[[1L]]), tolerance = 1e-6)
})
