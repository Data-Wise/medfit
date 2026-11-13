# `control` accepts a plain list (the 0.17.0 meaning: raw nloptr options) or a `sem_control()` object (0.18.0 plan
# S2, ADR V-5). The object is resolved once, at entry of `fit_sem()` and `mbco_sem()`, to the same plain list, so a fit
# made either way is the same fit; the resolved search protocol is recorded in `fit@diagnostics$protocol`.

sc_model <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
sc_fiml_message <- paste0("FIML requires meanstructure = TRUE, observed/model SEs, no weights, ",
                          "empty control and n_starts = 3 or NULL")

sc_parts <- function(fit) {
  list(theta = fit@theta, vcov = fit@vcov, table = fit@table, defined = fit@defined, f = fit@f, n_obs = fit@n_obs,
       df = fit@df, converged = fit@converged, control = fit@internals$control, n_starts = fit@internals$n_starts,
       ledger = fit@diagnostics$ledger)
}

# every property but the call, which records how `control` was spelled
sc_same_fit <- function(x, y) {
  keep <- setdiff(S7::prop_names(x), "call")
  identical(S7::props(x, keep), S7::props(y, keep))
}

sc_fiml_data <- function() {
  set.seed(271L)
  n <- 240L
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + .25 * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M = m, Y = y)
  d[seq(1L, n, 5L), "X"] <- NA_real_
  d[seq(2L, n, 5L), "M"] <- NA_real_
  d[seq(3L, n, 5L), "Y"] <- NA_real_
  d
}
sc_fiml <- function(...) fit_sem("M ~ a*X\nY ~ b*M + cp*X", sc_fiml_data(), missing = "fiml", fixed_x = FALSE, ...)

test_that("a 0.17.0 call with a plain control list gives the 0.17.0 fit (R-4)", {
  base <- readRDS(test_path("fixtures", "sem-control-0.17.0.rds"))
  legacy <- fit_sem(sc_model, mediation_demo, control = list(maxeval = 20000L))
  plain <- fit_sem(sc_model, mediation_demo)
  mbco <- mbco_sem(legacy, "a", "b")
  # bit identity holds on the build that wrote the fixture; another BLAS or platform differs at about 1e-9
  same_build <- identical(base$source$platform, R.version$platform) &&
    identical(base$source$blas, extSoftVersion()[["BLAS"]]) &&
    identical(base$source$nloptr, as.character(utils::packageVersion("nloptr")))
  check <- if (same_build) {
    function(x, y) expect_identical(x, y)
  } else {
    function(x, y) expect_equal(x, y, tolerance = 1e-6)
  }
  for (case in list(list(legacy, base$legacy), list(plain, base$plain))) {
    got <- sc_parts(case[[1L]])
    check(got[c("theta", "vcov", "f", "df")], case[[2L]][c("theta", "vcov", "f", "df")])
    expect_identical(got[c("n_obs", "converged", "control", "n_starts")],
                     case[[2L]][c("n_obs", "converged", "control", "n_starts")])
  }
  check(unname(mbco$statistic), unname(base$mbco$statistic))
  expect_identical(legacy@internals$control, list(maxeval = 20000L))
  fiml <- sc_fiml()
  check(fiml@theta, base$fiml$theta)
  expect_identical(fiml@internals[c("control", "n_starts")], base$fiml[c("control", "n_starts")])
})

test_that("sem_control() validates its arguments and returns a printable object", {
  ctl <- sem_control()
  expect_s3_class(ctl, "medfit_sem_control")
  expect_identical(ctl$optimizer, "auto")
  expect_null(ctl$n_starts)
  expect_identical(ctl$nloptr, list())
  expect_output(print(ctl), "sem_control")
  expect_identical(sem_control(n_starts = 7)$n_starts, 7L)
  expect_error(sem_control(optimiser = "auto"), "unused argument")
  # a partial match is not taken: the misspelled name is reported
  expect_error(sem_control(n_start = 3), "unknown sem_control() argument: `n_start`", fixed = TRUE)
  expect_error(sem_control(nlopt = list()), "`nlopt`", fixed = TRUE)
  expect_error(sem_control(optimizer = "slqp"), "optimizer")
  expect_error(sem_control(optimizer = "nlminb"), "optimizer")
  expect_error(sem_control(n_starts = 0), "n_starts")
  expect_error(sem_control(n_starts = 2.5), "n_starts")
  expect_error(sem_control(nloptr = list(1)), "nloptr")
  expect_error(sem_control(nloptr = c(maxeval = 1)), "nloptr")
})

test_that("optimizer = 'slsqp' with a different nloptr algorithm is a conflict (fault injection)", {
  expect_error(sem_control(optimizer = "slsqp", nloptr = list(algorithm = "NLOPT_LD_MMA")),
               class = "medfit_error_sem_control_conflict")
  expect_silent(sem_control(optimizer = "slsqp", nloptr = list(algorithm = "NLOPT_LD_SLSQP")))
  # "auto" leaves the algorithm to the nloptr list, as a plain list does
  expect_silent(sem_control(optimizer = "auto", nloptr = list(algorithm = "NLOPT_LD_MMA")))
})

test_that("the resolver turns a list or an object into the same plain nloptr list", {
  r_list <- .sem_resolve_control(list(maxeval = 20000L), NULL, FALSE, "listwise")
  r_obj <- .sem_resolve_control(sem_control(nloptr = list(maxeval = 20000L)), NULL, FALSE, "listwise")
  r_slsqp <- .sem_resolve_control(sem_control(optimizer = "slsqp", nloptr = list(maxeval = 20000L)), NULL, FALSE,
                                  "listwise")
  expect_identical(r_list$control, list(maxeval = 20000L))
  expect_identical(r_obj$control, r_list$control)
  expect_identical(r_slsqp$control, r_list$control)
  # the default object is the empty list itself, not a named empty list
  expect_identical(.sem_resolve_control(sem_control(), NULL, FALSE, "listwise")$control, list())
  expect_identical(.sem_resolve_control(list(), NULL, FALSE, "listwise")$control, list())
  # a plain list keeps its 0.17.0 meaning: every entry goes to nloptr, even one named `n_starts`
  legacy <- .sem_resolve_control(list(n_starts = 7L), NULL, FALSE, "listwise")
  expect_identical(legacy$control, list(n_starts = 7L))
  expect_null(legacy$n_starts)
  # the effective algorithm is what nloptr runs: the default, or the list's own entry
  expect_identical(r_list$protocol$optimizer, "NLOPT_LD_SLSQP")
  expect_identical(.sem_resolve_control(list(algorithm = "NLOPT_LD_MMA"), NULL, FALSE, "listwise")$protocol$optimizer,
                   "NLOPT_LD_MMA")
  expect_error(.sem_resolve_control("maxeval", NULL, FALSE, "listwise"), "control")
})

test_that("optimizer = 'auto', 'slsqp' and the legacy list give identical listwise fits (metamorphic invariance)", {
  legacy <- fit_sem(sc_model, mediation_demo, control = list(maxeval = 20000L))
  auto <- fit_sem(sc_model, mediation_demo, control = sem_control(nloptr = list(maxeval = 20000L)))
  slsqp <- fit_sem(sc_model, mediation_demo,
                   control = sem_control(optimizer = "slsqp", nloptr = list(maxeval = 20000L)))
  expect_true(sc_same_fit(legacy, auto))
  expect_true(sc_same_fit(legacy, slsqp))
  expect_identical(auto@internals$control, list(maxeval = 20000L))
  default <- fit_sem(sc_model, mediation_demo)
  expect_true(sc_same_fit(default, fit_sem(sc_model, mediation_demo, control = sem_control())))
  expect_true(sc_same_fit(default, fit_sem(sc_model, mediation_demo, control = list())))
  expect_identical(default@internals$control, list())
  # planted defect: a different nloptr option is a different fit, so the comparison can fail
  expect_false(sc_same_fit(default, legacy))
})

test_that("fit_mediation() forwards a sem_control() object through engine_args", {
  a <- fit_mediation(data = mediation_demo, treatment = "treatment", mediator = "mediator1", engine = "native",
                     model = sc_model, engine_args = list(control = list(maxeval = 20000L)))
  b <- fit_mediation(data = mediation_demo, treatment = "treatment", mediator = "mediator1", engine = "native",
                     model = sc_model, engine_args = list(control = sem_control(nloptr = list(maxeval = 20000L))))
  expect_identical(coef(a), coef(b))
  expect_identical(vcov(a), vcov(b))
  expect_error(
    fit_mediation(data = mediation_demo, treatment = "treatment", mediator = "mediator1", engine = "native",
                  model = sc_model, engine_args = list(n_starts = 5L, control = sem_control(n_starts = 7L))),
    class = "medfit_error_sem_control_conflict"
  )
})

test_that("mbco_sem() gives the same result on a fit made with sem_control() or the plain list", {
  f_list <- fit_sem(sc_model, mediation_demo, control = list(maxeval = 20000L))
  f_obj <- fit_sem(sc_model, mediation_demo, control = sem_control(nloptr = list(maxeval = 20000L)))
  expect_identical(f_obj@internals$control, f_list@internals$control)
  m_list <- mbco_sem(f_list, "a", "b")
  m_obj <- mbco_sem(f_obj, "a", "b")
  expect_identical(m_obj$statistic, m_list$statistic)
  expect_identical(m_obj$tests, m_list$tests)
  # an explicit control argument to mbco_sem() is resolved the same way
  m_arg <- mbco_sem(f_list, "a", "b", control = sem_control(nloptr = list(maxeval = 20000L)))
  expect_identical(m_arg$statistic, mbco_sem(f_list, "a", "b", control = list(maxeval = 20000L))$statistic)
  expect_identical(m_arg$statistic, m_list$statistic)
})

test_that("n_starts given at the top level and in sem_control() must agree (R-8)", {
  expect_error(fit_sem(sc_model, mediation_demo, n_starts = 5L, control = sem_control(n_starts = 7L)),
               class = "medfit_error_sem_control_conflict")
  # the defaulted 5 is not a supplied value: the object's 7 is used
  f7 <- fit_sem(sc_model, mediation_demo, control = sem_control(n_starts = 7L))
  expect_identical(f7@internals$n_starts, 7L)
  expect_identical(f7@diagnostics$protocol$n_starts, 7L)
  # the same value in both places is not a conflict; either place alone works
  f7b <- fit_sem(sc_model, mediation_demo, n_starts = 7L, control = sem_control(n_starts = 7L))
  f7c <- fit_sem(sc_model, mediation_demo, n_starts = 7L)
  expect_true(sc_same_fit(f7, f7b))
  expect_true(sc_same_fit(f7, f7c))
  # mbco_sem(): same rule; with neither, the fit's stored n_starts is used
  fit <- fit_sem(sc_model, mediation_demo)
  expect_error(mbco_sem(fit, "a", "b", n_starts = 5L, control = sem_control(n_starts = 7L)),
               class = "medfit_error_sem_control_conflict")
  m7 <- mbco_sem(fit, "a", "b", control = sem_control(n_starts = 7L))
  expect_identical(m7$statistic, mbco_sem(fit, "a", "b", n_starts = 7L, control = list())$statistic)
  # the two null refits ran with the object's 7 starts (the fit itself was made with 5)
  refit_starts <- vapply(utils::tail(m7$ledger$children, 2L), function(k) k$context$settings$n_starts, numeric(1))
  expect_identical(refit_starts, c(7, 7))
  expect_identical(utils::head(m7$ledger$children, 1L)[[1L]]$context$settings$n_starts, 5L)
  expect_identical(.sem_resolve_control(sem_control(n_starts = 7L), NULL, FALSE, "listwise")$n_starts, 7L)
  expect_null(.sem_resolve_control(sem_control(), NULL, FALSE, "listwise")$n_starts)
  expect_identical(.sem_resolve_control(sem_control(), 4L, TRUE, "listwise")$n_starts, 4L)
})

test_that("FIML takes the default sem_control() and refuses every other setting (R-7)", {
  base <- sc_fiml()
  obj <- sc_fiml(control = sem_control())
  expect_true(sc_same_fit(base, obj))
  expect_identical(obj@internals$control, list())
  expect_true(sc_same_fit(base, sc_fiml(control = sem_control(n_starts = 3L))))
  for (bad in list(sem_control(n_starts = 5L), sem_control(nloptr = list(maxeval = 20000L)))) {
    err <- expect_error(sc_fiml(control = bad), class = "medfit_sem_fiml_error")
    expect_identical(conditionMessage(err), sc_fiml_message)
  }
  # the 0.17.0 refusals keep their message
  expect_error(sc_fiml(control = list(maxeval = 20000L)), sc_fiml_message, fixed = TRUE)
  expect_error(sc_fiml(n_starts = 5L), sc_fiml_message, fixed = TRUE)
  # FIML's SLSQP-plus-nlminb protocol is not selectable
  err <- expect_error(sc_fiml(control = sem_control(optimizer = "slsqp")), class = "medfit_sem_fiml_error")
  expect_match(conditionMessage(err), "optimizer = \"auto\"", fixed = TRUE)
})

test_that("the resolved search protocol is recorded in diagnostics$protocol (R-9)", {
  fit <- fit_sem(sc_model, mediation_demo)
  expect_identical(fit@diagnostics$protocol, list(
    version = 1L, estimator = "listwise", optimizer = "NLOPT_LD_SLSQP", n_starts = 5L,
    start_rule = "model_start_then_perturbed"
  ))
  slsqp <- fit_sem(sc_model, mediation_demo, control = sem_control(optimizer = "slsqp"))
  expect_identical(slsqp@diagnostics$protocol, fit@diagnostics$protocol)
  expect_identical(fit_sem(sc_model, mediation_demo, n_starts = 2L)@diagnostics$protocol$n_starts, 2L)
  fiml <- sc_fiml(control = sem_control())
  expect_identical(fiml@diagnostics$protocol, list(
    version = 1L, estimator = "fiml", optimizer = c("NLOPT_LD_SLSQP", "nlminb"), n_starts = 3L,
    start_rule = "fiml_three_fixed_per_solver"
  ))
  # no second slot named `control`: the raw nloptr list stays in internals only
  expect_null(fit@diagnostics$control)
})
