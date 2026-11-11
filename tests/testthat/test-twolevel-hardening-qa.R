# Independent QA of the two-level hardening (#394): boundary hand calculations, scale invariance, post.check
# never erroring, the refit environment through bootstrap_mediation(), the validator against every real extractor
# output, and .safe_se against sqrt(). Oracles: hand arithmetic, lavaan's own post.check, closed form.

.qa_eps <- sqrt(.Machine$double.eps)  # 1.4901161193847656e-08

val <- function(e) as.numeric(unclass(e))

# A valid object whose within-level NIE is (a * b), NDE is cp (so TE = a * b + cp), between level as in tl_td().
qa_td <- function(a, b, cp, level = "within") {
  est <- c(a_within = 0.4, b_within = 0.5, c_prime_within = 0.3,
           a_between = 0.7, b_between = 1.5, c_prime_between = -0.1)
  if (level == "within") est[c("a_within", "b_within", "c_prime_within")] <- c(a, b, cp)
  else est[c("a_between", "b_between", "c_prime_between")] <- c(a, b, cp)
  args <- as.list(est)
  args$estimates <- est
  do.call(tl_td, args)
}

test_that("QA1: the PM threshold is sqrt(eps) * max(|NIE|, |NDE|), at hand-computed boundaries", {
  # nie = 1, nde = -1 + d  =>  te = d, threshold = 1.4901161e-08 * 1
  below <- 1.4e-8
  above <- 1.6e-8
  expect_true(is.na(val(suppressWarnings(pm(qa_td(1, 1, -1 + below))))))
  expect_equal(val(pm(qa_td(1, 1, -1 + above))), 1 / above, tolerance = 1e-6)
  # nie = 1, nde = -1 + 2e-8 => te = 2e-8 > threshold 1.49e-8, so PM is defined
  expect_false(is.na(val(pm(qa_td(1, 1, -1 + 2e-8)))))
  # te = nie + nde; nie = -2, nde = 2 + 2.0e-8 => te 2.0e-8, thr = 2 * 1.49e-8 = 2.98e-8 => undefined
  expect_true(is.na(val(suppressWarnings(pm(qa_td(-2, 1, 2 + 2e-8))))))
  # same te with the max governed by the larger effect, nie = -2, nde = 2 + 4e-8 => te 4e-8 > 2.98e-8 => defined
  expect_equal(val(pm(qa_td(-2, 1, 2 + 4e-8))), -2 / 4e-8, tolerance = 1e-6)
  # exact zero stays undefined
  expect_true(is.na(val(suppressWarnings(pm(qa_td(1, 1, -1))))))
  # between level obeys the same rule
  expect_true(is.na(val(suppressWarnings(pm(qa_td(1, 1, -1 + below, "between"), level = "between")))))
  expect_equal(val(pm(qa_td(1, 1, -1 + above, "between"), level = "between")), 1 / above, tolerance = 1e-6)
})

test_that("QA1: the rule is scale invariant (an absolute epsilon rule is not)", {
  for (s in c(1e-6, 1, 1e6)) {
    expect_true(is.na(val(suppressWarnings(pm(qa_td(s, 1, s * (-1 + 1e-9)))))), info = s)
    expect_equal(val(pm(qa_td(s, 1, s * (-1 + 1e-6)))), 1 / 1e-6, tolerance = 1e-5, info = s)
  }
})

test_that("QA1: pm() on real fits is numerically identical to NIE / TE and warns only on the undefined case", {
  skip_if_not_installed("lavaan")
  for (nm in c("base", "fixed_x_false", "robust", "x_small_between", "shared_label", "j20")) {
    td <- tl_extract(tl_fixture(nm))
    for (lv in c("within", "between")) {
      a <- S7::prop(td, paste0("a_", lv))
      b <- S7::prop(td, paste0("b_", lv))
      cp <- S7::prop(td, paste0("c_prime_", lv))
      expect_no_warning(p <- pm(td, level = lv))
      expect_identical(unname(val(p)), a * b / (a * b + cp), info = paste(nm, lv))
    }
  }
})

test_that("QA3: lavaan's post.check never errors, so .twolevel_admissible has no error to swallow", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  small <- tl_sim(J = 12L, n = 3L, seed = 5)
  fits <- list(
    converged = tl_fixture("base"),
    inadmissible = tl_fit(small),
    nonconverged = suppressWarnings(lavaan::sem(tl_model(), data = d, cluster = "id", control = list(iter.max = 3))),
    se_none = tl_fit(d, se = "none"),
    no_fit = suppressWarnings(lavaan::sem(tl_model(), data = d, cluster = "id", do.fit = FALSE))
  )
  want <- c(converged = TRUE, inadmissible = FALSE, nonconverged = TRUE, se_none = TRUE, no_fit = TRUE)
  for (nm in names(fits)) {
    raw <- expect_no_error(suppressWarnings(lavaan::lavInspect(fits[[nm]], "post.check")))
    expect_identical(raw, unname(want[nm]), info = nm)
    expect_identical(medfit:::.twolevel_admissible(fits[[nm]]), unname(want[nm]), info = nm)
    # extract_mediation: success or the classed "unusable" error, never an unclassed one
    res <- tryCatch(suppressWarnings(tl_extract(fits[[nm]])), error = function(e) e)
    if (inherits(res, "error")) expect_s3_class(res, "medfit_error_twolevel_unusable") else
      expect_identical(res@admissible, unname(want[nm]) & TRUE, info = nm)
  }
  # the inadmissible fit is extracted with admissible = FALSE and a classed warning, as before the change
  w <- tl_catch(extract_mediation(fits$inadmissible, treatment = "X", mediator = "M", outcome = "Y"),
                "medfit_warning_twolevel_inadmissible")
  expect_s3_class(w, "medfit_warning_twolevel_inadmissible")
  expect_false(suppressWarnings(tl_extract(fits$inadmissible))@admissible)
})

test_that("QA4: bootstrap_mediation() with a refit statistic resolves the call's names where it was called", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  run <- function(rebind = NULL) {
    ctl <- list(iter.max = 500)  # lavaan stores `control = ctl`: a symbol, resolved in THIS frame at refit time
    fit <- suppressWarnings(lavaan::sem(tl_model(), data = d, cluster = "id", control = ctl))
    if (!is.null(rebind)) ctl <- rebind  # the frame that calls twolevel_statistic() now holds a different `ctl`
    stat <- twolevel_statistic(fit, "nie_within", treatment = "X", mediator = "M", outcome = "Y")
    suppressWarnings(bootstrap_mediation(stat, method = "nonparametric", data = d, cluster = "id",
                                         n_boot = 12L, seed = 3L))
  }
  good <- run()
  expect_true(all(is.finite(good@boot_estimates)))
  # iter.max = 1 cannot converge: every replicate is NA if (and only if) the calling frame's `ctl` is the one used
  expect_error(run(list(iter.max = 1)), "Too many bootstrap samples failed")
})

test_that("QA5/6: every real extractor output passes the strengthened validator", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- tl_sim()
  dn <- d
  set.seed(9)
  dn$M[sample(nrow(dn), 50)] <- NA
  dn$X[sample(nrow(dn), 30)] <- NA
  set.seed(4)
  keep <- unlist(lapply(split(seq_len(nrow(d)), d$id), function(ix) ix[seq_len(sample(2:5, 1))]))
  fits <- list(
    base = tl_fixture("base"), unlabeled = tl_fixture("unlabeled"), fixed_x_false = tl_fixture("fixed_x_false"),
    robust = tl_fixture("robust"), fiml = tl_fixture("fiml"), shared_label = tl_fixture("shared_label"),
    equal_rows = tl_fixture("equal_rows"), x_centered = tl_fixture("x_centered"),
    x_small_between = tl_fixture("x_small_between"), x_randomized = tl_fixture("x_randomized"),
    j20 = tl_fixture("j20"), listwise_na = tl_fit(dn), unbalanced = tl_fit(d[keep, ]),
    weak_icc = tl_fit(tl_sim(sd_xb = 0.15)),
    fixed_between = tl_fit(d, "level: 1\n M ~ a*X\n Y ~ b*M + cp*X\nlevel: 2\n M ~ a2*X\n Y ~ 0.9*M + cp2*X\n"),
    fixed_within = tl_fit(d, "level: 1\n M ~ 0.4*X\n Y ~ b*M + cp*X\nlevel: 2\n M ~ a2*X\n Y ~ b2*M + cp2*X\n"),
    fixed_between_within_only = tl_fit(
      tl_sim(x_mode = "centered"),
      "level: 1\n M ~ a*X\n Y ~ b*M + cp*X\nlevel: 2\n M ~ 0.3*X\n Y ~ b2*M + cp2*X\n"
    )
  )
  for (nm in names(fits)) {
    td <- tl_extract(fits[[nm]])
    expect_no_error(S7::validate(td))
    expect_equal(td@n_obs, sum(td@cluster_sizes), info = nm)
    expect_true(all(td@fixed_paths %in% names(td@estimates)), info = nm)
    expect_true(isSymmetric(unname(td@vcov), tol = 1e-8), info = nm)
  }
})

test_that("QA6: each new validator rule fires on its own planted defect", {
  expect_error(tl_td(n_obs = 499L), "n_obs must equal")
  expect_error(tl_td(fixed_paths = "a_other"), "fixed_paths must name")
  est <- c(a_within = 0.4, b_within = 0.5, c_prime_within = 0.3, a_between = 0.7, b_between = NA,
           c_prime_between = -0.1)
  expect_error(tl_td(estimates = est), "finite")
  vc <- diag(0.01, 6)
  dimnames(vc) <- list(names(est), names(est))
  vc[1, 2] <- 0.005
  est[5] <- 1.5
  expect_error(tl_td(estimates = est, vcov = vc), "symmetric")
  vc[1, 2] <- 0
  vc[3, 3] <- -0.01
  expect_error(tl_td(estimates = est, vcov = vc), "non-negative")
  # tolerance side: a roundoff-sized asymmetry and a roundoff-sized negative diagonal are accepted
  vc[3, 3] <- 0.01
  vc[1, 2] <- 1e-12
  expect_no_error(tl_td(estimates = est, vcov = vc))
})

test_that("QA7: .safe_se is bit-identical to sqrt() for valid variances and NA plus one classed warning otherwise", {
  set.seed(2)
  v <- c(0, .Machine$double.xmin, 1e-300, 2.5, pi, 1e300, 10^runif(1e4, -20, 20))
  expect_no_warning(s <- medfit:::.safe_se(v, "x"))
  expect_identical(s, sqrt(v))
  nv <- c(a = 4, b = -1, c = NA, d = Inf, e = 9)
  w <- tl_catch(medfit:::.safe_se(nv, "x"), "medfit_warning_vcov_diagonal")
  expect_s3_class(w, "medfit_warning_vcov_diagonal")
  r <- suppressWarnings(medfit:::.safe_se(nv, "x"))
  expect_identical(r, c(a = 2, b = NA, c = NA, d = NA, e = 3))
})
