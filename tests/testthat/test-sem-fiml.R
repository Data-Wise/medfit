fiml_data <- function(n = 240L, incomplete = TRUE) {
  set.seed(271L)
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + .25 * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M = m, Y = y)
  if (incomplete) {
    d[seq(1L, n, 5L), "X"] <- NA_real_
    d[seq(2L, n, 5L), "M"] <- NA_real_
    d[seq(3L, n, 5L), "Y"] <- NA_real_
  }
  d
}
fiml_model <- "M ~ a*X\nY ~ b*M + cp*X"
fiml_fit <- function(data = fiml_data(), model = fiml_model, ...) {
  fit_sem(model, data, missing = "fiml", fixed_x = FALSE, ...)
}

test_that("FIML opt-in is appended, exact and explicit about random X", {
  expect_identical(tail(names(formals(fit_sem)), 1L), "missing")
  for (bad in list("f", "unknown", NA_character_, character(), c("fiml", "listwise"))) {
    expect_error(fit_sem(fiml_model, fiml_data(), missing = bad), "missing")
  }
  expect_error(fit_sem(fiml_model, fiml_data(), missing = "fiml"), "fixed_x")
})

test_that("FIML retains partial rows and returns a raw likelihood", {
  d <- rbind(fiml_data(), c(NA_real_, NA_real_, NA_real_))
  f <- fiml_fit(d)
  expect_equal(nobs(f), 240L)
  expect_equal(f@n_dropped, 1L)
  expect_true(is.na(f@f) && is.na(f@df))
  expect_true(is.finite(as.numeric(logLik(f))))
  expect_equal(attr(logLik(f), "df"), 9L)
  expect_identical(f@internals$likelihood$method, "fiml")
  expect_equal(nrow(f@diagnostics$attempts), 6L)
})

test_that("both FIML routes preserve aliases, covariance and provenance", {
  d <- fiml_data()
  f <- fiml_fit(d)
  x <- extract_mediation(f, treatment = "X", mediator = "M")
  w <- fit_mediation(
    model = fiml_model, data = d, treatment = "X", mediator = "M", engine = "native",
    engine_args = list(missing = "fiml", fixed_x = FALSE)
  )
  for (m in list(x, w)) {
    expect_true(S7::S7_inherits(m, FIMLMediationData))
    expect_identical(m@source_package, "medfit")
    expect_identical(m@fit_context$method, "fiml")
    expect_identical(m@data, f@data)
    expect_equal(paths(m), c(a = coef(f)[["a"]], b = coef(f)[["b"]], c_prime = coef(f)[["cp"]]))
    expect_equal(as.numeric(nie(m)), coef(f)[["a"]] * coef(f)[["b"]])
    expect_equal(as.numeric(nde(m)), coef(f)[["cp"]])
    expect_equal(as.numeric(te(m)), coef(f)[["a"]] * coef(f)[["b"]] + coef(f)[["cp"]])
    expect_named(coef(m, "effects"), c("nie", "nde", "te"))
    expect_identical(coef(m, "all"), m@estimates)
    expect_identical(vcov(m), m@vcov)
    expect_equal(vcov(m)[c("a", "b", "c_prime"), c("a", "b", "c_prime")],
      unname(vcov(f)[c("a", "b", "cp"), c("a", "b", "cp")]),
      ignore_attr = TRUE
    )
    expect_identical(unserialize(serialize(m, NULL))@fit_context, m@fit_context)
    expect_identical(summary(m)$fit_context, m@fit_context)
    expect_output(print(m), "FIML, random X")
    a <- m@a_path
    b <- m@b_path
    G <- rbind(nie = c(b, a, 0), nde = c(0, 0, 1), te = c(b, a, 1))
    se <- sqrt(diag(G %*% vcov(f)[c("a", "b", "cp"), c("a", "b", "cp")] %*% t(G)))
    t <- generics::tidy(m, type = "effects", conf_int = TRUE)
    expect_equal(t$std_error, unname(se), tolerance = 1e-12)
    expect_warning(
      ci <- confint(m, parm = "effects"),
      "Normal approximation for NIE may be inaccurate.*extracted FIML data.*source_fit.*original fit"
    )
    expect_equal(unname(ci[, 1L]), t$conf_low, tolerance = 1e-12)
    expect_equal(unname(ci[, 2L]), t$conf_high, tolerance = 1e-12)
    for (type in c("all", "paths", "effects")) {
      expect_true(all(is.finite(generics::tidy(m, type = type, conf_int = TRUE)$std_error)))
    }
    expect_equal(nrow(confint(m, parm = "paths")), 3L)
  }
  expect_equal(as.numeric(logLik(f)), -f@internals$likelihood$nll)
  expect_equal(AIC(f), -2 * as.numeric(logLik(f)) + 18)
  expect_equal(BIC(f), -2 * as.numeric(logLik(f)) + log(nobs(f)) * 9)
  expect_output(print(f), "FIML, random X")
  expect_output(print(summary(f)), "FIML, random X")
  g <- generics::glance(f)
  expect_true(is.na(g$chisq) && is.na(g$df) && is.na(g$p_value))
  expect_match(attr(g, "note"), "FIML model test unavailable")
  expect_equal(g$logLik, as.numeric(logLik(f)))
})

test_that("FIML matches lavaan observed likelihood and full covariance", {
  skip_if_not_installed("lavaan")
  d <- fiml_data()
  for (direct in c(TRUE, FALSE)) {
    model <- if (direct) fiml_model else "M ~ a*X\nY ~ b*M + 0*X"
    f <- fiml_fit(d, model)
    r <- lavaan::sem(model,
      data = d, missing = "ml", fixed.x = FALSE,
      meanstructure = TRUE, information = "observed"
    )
    expect_equal(coef(f), lavaan::coef(r)[names(coef(f))], tolerance = 1e-5)
    expect_equal(as.numeric(logLik(f)), as.numeric(lavaan::logLik(r)), tolerance = 1e-7)
    V <- lavaan::vcov(r)[names(coef(f)), names(coef(f))]
    expect_lt(max(abs(vcov(f) - V) / outer(sqrt(diag(V)), sqrt(diag(V)))), 1e-3)
    if (!direct) {
      x <- extract_mediation(f, treatment = "X", mediator = "M")
      expect_identical(as.numeric(nde(x)), 0)
      expect_true(all(vcov(x)["c_prime", ] == 0))
      expect_true(all(vcov(x)[, "c_prime"] == 0))
      expect_true(is.finite(generics::tidy(x, type = "effects")$std_error[1L]))
    }
  }
})

test_that("FIML guards deferred routes before RNG changes", {
  f <- fiml_fit()
  x <- extract_mediation(f, treatment = "X", mediator = "M")
  old <- fit_sem(fiml_model, fiml_data(incomplete = FALSE), fixed_x = FALSE)
  set.seed(123)
  rng <- .Random.seed
  for (m in list(f, x)) {
    for (method in c("parametric", "plugin", "nonparametric")) {
      expect_error(bootstrap_mediation(function(z) 1,
                     method = method, mediation_data = m,
                     n_boot = 2L, seed = 42L
                   ), "FIML")
      expect_identical(.Random.seed, rng)
    }
  }
  expect_error(pm(x), "FIML")
  expect_error(quick(x), "FIML")
  expect_error(generics::glance(x), "FIML")
  expect_error(confint(x, method = "boot"), "FIML")
  expect_error(mbco_sem(f, a = "a", b = "b"), "FIML")
  expect_error(compare_lr(f, paths = c("a", "b")), "FIML")
  expect_error(anova(f, f), "FIML")
  expect_error(anova(old, f), "FIML")
  expect_error(AIC(old, f), "FIML")
  expect_error(BIC(f, old), "FIML")
  expect_identical(.Random.seed, rng)
})

test_that("FIML validates settings and topology before the numerical kernel", {
  called <- FALSE
  testthat::local_mocked_bindings(.sem_fiml_fit = function(...) {
    called <<- TRUE
    stop("called kernel")
  })
  for (args in list(
    list(fixed_x = TRUE), list(fixed_x = "X"), list(meanstructure = FALSE),
    list(meanstructure = NULL), list(information = "expected"), list(se_type = "sandwich"),
    list(weights = rep(1, 240)), list(n_starts = 1L), list(control = list(maxeval = 1))
  )) {
    a <- modifyList(list(model = fiml_model, data = fiml_data(), missing = "fiml", fixed_x = FALSE),
      args,
      keep.null = TRUE
    )
    expect_error(do.call(fit_sem, a), "FIML")
  }
  for (model in c(
    "M~a*X\nY~b*M+cp*X\na==b", "M~a*X\nY~a*M+cp*X",
    "M~a*X\nY~b*M+cp*X\nM~~Y", "M~a*X\nY~b*M+cp*X\nab:=a*b",
    "M~0*X\nY~b*M+cp*X", "M~a*X\nY~b*M+cp*X\nX~0*1"
  )) {
    expect_error(fiml_fit(model = model), "FIML")
  }
  expect_false(called)
})

test_that("FIML rows, arbitrary variable names and unavailable NIE origin are explicit", {
  d <- fiml_data()
  d[seq(1L, nrow(d), 3L), 1L] <- NA
  d[seq(2L, nrow(d), 3L), 2L] <- NA
  d[seq(3L, nrow(d), 3L), 3L] <- NA
  names(d) <- c("exposure", "middle", "response")
  d$irrelevant <- NA_real_
  f <- fiml_fit(d, "response ~ middle + exposure\nmiddle ~ exposure")
  expect_equal(nobs(f), nrow(d))
  expect_equal(f@internals$likelihood$rows$complete, 0L)
  x <- extract_mediation(f, treatment = "exposure", mediator = "middle")
  expect_true(all(is.finite(paths(x))))
  expect_error(extract_mediation(f, treatment = "exposure", mediator = "middle", standardized = TRUE), "FIML")
  props <- S7::props(x)
  props$a_path <- props$b_path <- 0
  ctx <- props$fit_context
  ctx$parameter_hash <- rlang::hash(list(props$estimates, props$vcov, props$a_path, props$b_path, props$c_prime))
  props$fit_context <- ctx
  z <- do.call(FIMLMediationData, props)
  expect_identical(as.numeric(nie(z)), 0)
  t <- generics::tidy(z, type = "effects", conf_int = TRUE)
  expect_true(is.na(t$std_error[1L]) && is.na(t$conf_low[1L]) && is.na(t$conf_high[1L]))
  expect_match(attr(t, "note"), "zero delta gradient")
  expect_warning(ci <- confint(z, parm = "effects"), "Normal approximation")
  expect_true(all(is.na(ci["nie", ])))
  expect_true(all(is.finite(ci["nde", ])))
})

test_that("FIML rejects invalid columns and keeps failure attempts", {
  for (value in list(rep(Inf, 240L), factor(rep(1:2, 120L)), rep(TRUE, 240L), rep(1, 240L))) {
    d <- fiml_data()
    d$X <- value
    e <- tryCatch(fiml_fit(d), error = identity)
    expect_s3_class(e, "medfit_sem_fiml_error")
    expect_identical(e$stage, "input")
    expect_null(e$attempts)
    expect_s3_class(e$parent, "error")
  }
  d <- fiml_data(incomplete = FALSE)
  d[1:120, "Y"] <- NA
  d[121:240, c("X", "M")] <- NA
  e <- tryCatch(fiml_fit(d), error = identity)
  expect_s3_class(e, "medfit_sem_fiml_error")
  expect_match(conditionMessage(e), "rank deficient")
  expect_equal(nrow(e$attempts), 6L)
  expect_equal(length(e$solver_calls), 9L)
  expect_equal(sum(vapply(e$solver_calls, function(z) z$phase == "refinement", logical(1))), 3L)
  expect_true(all(is.finite(e$attempts$status)))
})

test_that("FIML evidence is bound to rows, settings, covariance and attempts", {
  f <- fiml_fit()
  for (field in c("data", "settings", "covariance", "attempts", "marker", "ledger")) {
    m <- f
    if (field == "data") {
      d <- m@data
      d[1L, 2L] <- d[1L, 2L] + 1
      m@data <- d
    } else if (field == "covariance") {
      m@vcov <- 2 * m@vcov
    } else if (field %in% c("settings", "marker")) {
      v <- m@internals
      if (field == "settings") v$n_starts <- 1L else v$likelihood$method <- "listwise"
      m@internals <- v
    } else {
      dg <- m@diagnostics
      if (field == "attempts") dg$attempts$status[1L] <- -1L else dg$ledger$binding <- "forged"
      m@diagnostics <- dg
    }
    for (consumer in list(coef, vcov, nobs, logLik, summary, generics::tidy, generics::glance, confint)) {
      expect_error(consumer(m), class = "medfit_error_ledger")
    }
  }
})

test_that("complete-data FIML and exact original row IDs retain restricted capabilities", {
  d <- rbind(fiml_data(incomplete = FALSE), c(NA_real_, NA_real_, NA_real_))
  # Duplicate labels cannot substitute for original positional IDs.
  attr(d, "row.names") <- rep("same", nrow(d))
  f <- fiml_fit(d)
  expect_identical(f@internals$likelihood$rows$retained, 1:240)
  expect_identical(f@internals$likelihood$rows$empty, 241L)
  expect_equal(f@internals$likelihood$rows$complete, 240L)
  expect_equal(length(f@diagnostics$solver_calls), 9L)
  x <- extract_mediation(f, treatment = "X", mediator = "M")
  expect_error(pm(x), "FIML")
  expect_error(quick(x), "FIML")
  expect_error(generics::glance(x), "FIML")
  expect_error(confint(f, method = "boot"), "FIML")
  expect_error(extract_mediation(f, treatment = "X", mediator = "M", decomposition = "four_way"), "FIML")
})

test_that("FIML roles follow topology despite colliding labels", {
  f <- fiml_fit(model = "M ~ b*X\nY ~ a*M + c_prime*X")
  x <- extract_mediation(f, treatment = "X", mediator = "M")
  expect_equal(paths(x), c(a = coef(f)[["b"]], b = coef(f)[["a"]], c_prime = coef(f)[["c_prime"]]))
  expect_identical(x@fit_context$source_theta, coef(f))
  expect_identical(x@fit_context$source_vcov, vcov(f))
  expect_identical(x@fit_context$source_roles, c(a = "b", b = "a", c_prime = "c_prime"))
  props <- S7::props(x)
  props$fit_context$source_vcov[1L, 1L] <- props$fit_context$source_vcov[1L, 1L] * 2
  expect_error(do.call(FIMLMediationData, props), "fit_context")
  expect_equal(vcov(x)[c("a", "b", "c_prime"), c("a", "b", "c_prime")],
    unname(vcov(f)[c("b", "a", "c_prime"), c("b", "a", "c_prime")]),
    ignore_attr = TRUE
  )
  G <- rbind(
    c(coef(f)[["a"]], coef(f)[["b"]], 0), c(0, 0, 1),
    c(coef(f)[["a"]], coef(f)[["b"]], 1)
  )
  expected <- sqrt(diag(G %*% vcov(f)[c("b", "a", "c_prime"), c("b", "a", "c_prime")] %*% t(G)))
  expect_equal(generics::tidy(x, type = "effects")$std_error, unname(expected))
})


test_that("post-solver adapter failures retain all completed solver evidence", {
  testthat::local_mocked_bindings(
    .sem_fiml_require = function(...) stop("planted adapter fault"),
    .package = "medfit"
  )
  err <- tryCatch(fiml_fit(), error = identity)
  expect_s3_class(err, "medfit_sem_fiml_error")
  expect_match(conditionMessage(err$parent), "planted adapter fault")
  expect_equal(nrow(err$attempts), 6L)
  expect_length(err$solver_calls, 9L)
})

test_that("FIML IC comparisons inspect every class before external likelihood calls", {
  f <- fiml_fit()
  zero <- fiml_fit(model = "M ~ a*X\nY ~ b*M + 0*X")
  old <- fit_sem(fiml_model, fiml_data(incomplete = FALSE), fixed_x = FALSE)
  external <- stats::lm(Y ~ M + X, data = fiml_data(incomplete = FALSE))
  state <- new.env(parent = emptyenv())
  state$calls <- 0L
  spy_loglik <- function(object, ...) {
    state$calls <- state$calls + 1L
    structure(-1, class = "logLik", df = 1, nobs = 240L)
  }
  rlang::local_bindings(logLik.fiml_external_spy = spy_loglik, .env = globalenv())
  spy <- structure(list(), class = "fiml_external_spy")
  changed <- fiml_fit(fiml_data()[seq_len(230L), ])
  for (fun in list(AIC, BIC)) {
    expect_error(fun(f, external), "FIML")
    expect_error(fun(f, spy), "FIML")
    expect_identical(state$calls, 0L)
    expect_error(fun(f, old), "FIML")
    expect_error(fun(f, changed), "identical")
    expect_true(is.finite(fun(f)))
    out <- fun(f, zero)
    expect_equal(out[[2L]], c(fun(f), fun(zero)))
    expect_true(is.finite(fun(old, external)[[2L]][1L]))
  }
})

test_that("post-return solver evaluation faults retain completed calls and failed attempt", {
  original_eval <- .sem_fiml_eval
  original_solver <- .sem_solve_one
  state <- new.env(parent = emptyenv())
  state$completed <- list()
  fault <- structure(list(message = "planted post-return fault", call = NULL, marker = "original"),
                     class = c("fiml_test_postreturn", "error", "condition"))
  testthat::local_mocked_bindings(
    .sem_solve_one = function(...) {
      r <- original_solver(...)
      state$completed[[length(state$completed) + 1L]] <- r$status
      r
    },
    .sem_fiml_eval = function(theta, p, derivative = TRUE) {
      if (identical(substitute(theta), quote(run$theta))) stop(fault)
      original_eval(theta, p, derivative)
    },
    .package = "medfit"
  )
  err <- tryCatch(fiml_fit(), error = identity)
  expect_s3_class(err, "medfit_sem_fiml_error")
  expect_identical(err$stage, "numerical")
  expect_s3_class(err$parent, "fiml_test_postreturn")
  expect_identical(err$parent$marker, "original")
  expect_match(err$reason, "planted post-return fault")
  expect_length(state$completed, 1L)
  expect_length(err$solver_calls, length(state$completed))
  expect_identical(err$solver_calls[[1L]]$status, state$completed[[1L]])
  expect_identical(err$solver_calls[[1L]]$solver, "slsqp")
  expect_equal(nrow(err$attempts), 1L)
  expect_identical(err$attempts$status, state$completed[[1L]])
  expect_false(err$attempts$accepted)
  expect_match(err$attempts$reason, "planted post-return fault")
})

test_that("FIML rejects insufficient marginals and invalid completed role topology before solving", {
  testthat::local_mocked_bindings(.sem_fiml_fit = function(...) stop("solver must not run"), .package = "medfit")
  d <- fiml_data()
  d$X[-1L] <- NA_real_
  err <- tryCatch(fiml_fit(d), error = identity)
  expect_s3_class(err, "medfit_sem_fiml_error")
  expect_identical(err$stage, "input")
  expect_match(err$reason, "insufficient observations")
  expect_null(err$attempts)
  expect_null(err$solver_calls)
  err <- tryCatch(fiml_fit(model = "M ~ X\nY ~ X"), error = identity)
  expect_s3_class(err, "medfit_sem_fiml_error")
  expect_identical(err$stage, "input")
  expect_match(err$reason, "exactly three observed variables")
  expect_null(err$attempts)
})

test_that("actual solver exceptions retain failed rows and continue the remaining real attempts", {
  original_solver <- .sem_solve_one
  original_nlminb <- stats::nlminb
  state <- new.env(parent = emptyenv())
  state$slsqp <- state$nlminb <- 0L
  sl_fault <- structure(list(message = "planted SLSQP exception", call = NULL),
                        class = c("fiml_solver_fault", "error", "condition"))
  nl_fault <- structure(list(message = "planted nlminb refinement exception", call = NULL),
                        class = c("fiml_solver_fault", "error", "condition"))
  testthat::local_mocked_bindings(.sem_solve_one = function(...) {
    state$slsqp <- state$slsqp + 1L
    if (state$slsqp == 1L) stop(sl_fault)
    original_solver(...)
  }, .package = "medfit")
  testthat::local_mocked_bindings(nlminb = function(...) {
    state$nlminb <- state$nlminb + 1L
    if (state$nlminb == 2L) stop(nl_fault)
    original_nlminb(...)
  }, .package = "stats")
  f <- fiml_fit()
  a <- f@diagnostics$attempts
  calls <- f@diagnostics$solver_calls
  expect_equal(nrow(a), 6L)
  expect_length(calls, 9L)
  expect_identical(state$slsqp, 3L)
  expect_identical(state$nlminb, 6L)
  failed <- a[!a$accepted, ]
  expect_equal(nrow(failed), 2L)
  expect_true(all(is.na(failed$status) & is.na(failed$nll) & is.na(failed$stationarity)))
  expect_true(is.na(failed$first_status[1L]))
  expect_identical(failed$first_status[2L], 0L)
  expect_identical(failed$reason, c(conditionMessage(sl_fault), conditionMessage(nl_fault)))
  expect_identical(calls[[1L]]$condition, sl_fault)
  expect_identical(calls[[5L]]$condition, nl_fault)
  expect_identical(calls[[5L]]$phase, "refinement")
  expect_true(all(c("slsqp", "nlminb") %in% a$solver[a$accepted]))
  expect_true(is.finite(as.numeric(logLik(f))))
})

test_that("an unavailable returned evaluation is refused while other genuine candidates remain usable", {
  original <- .sem_fiml_eval
  state <- new.env(parent = emptyenv())
  state$returned <- 0L
  testthat::local_mocked_bindings(.sem_fiml_eval = function(theta, p, derivative = TRUE) {
    if (identical(substitute(theta), quote(run$theta))) {
      state$returned <- state$returned + 1L
      if (state$returned == 1L) return(NULL)
    }
    original(theta, p, derivative)
  }, .package = "medfit")
  f <- fiml_fit()
  a <- f@diagnostics$attempts
  expect_identical(state$returned, 6L)
  expect_false(a$accepted[1L])
  expect_true(is.na(a$nll[1L]))
  expect_identical(a$stationarity[1L], Inf)
  expect_match(a$reason[1L], "stationarity")
  expect_true(all(a$accepted[-1L]))
  expect_length(f@diagnostics$solver_calls, 9L)
  expect_true(is.finite(as.numeric(logLik(f))))
})

test_that("FIML requires accepted raw statuses from both optimizers", {
  original <- .sem_solve_one
  testthat::local_mocked_bindings(.sem_solve_one = function(...) {
    r <- original(...)
    r$status <- -1L
    r
  }, .package = "medfit")
  err <- tryCatch(fiml_fit(), error = identity)
  expect_s3_class(err, "medfit_sem_fiml_error")
  expect_match(err$reason, "no accepted candidate for each optimizer")
  expect_equal(nrow(err$attempts), 6L)
  expect_length(err$solver_calls, 9L)
  a <- err$attempts
  expect_true(all(a$status[a$solver == "slsqp"] == -1L))
  expect_true(all(!a$accepted[a$solver == "slsqp"]))
  expect_true(all(a$accepted[a$solver == "nlminb"]))
  expect_true(all(vapply(err$solver_calls[1:3], function(x) x$status == -1L, logical(1))))
})

test_that("FIML refuses disagreeing accepted likelihoods and retains the full evidence", {
  original <- .sem_fiml_eval
  state <- new.env(parent = emptyenv())
  state$returned <- 0L
  testthat::local_mocked_bindings(.sem_fiml_eval = function(theta, p, derivative = TRUE) {
    e <- original(theta, p, derivative)
    if (identical(substitute(theta), quote(run$theta))) {
      state$returned <- state$returned + 1L
      if (state$returned == 1L) e$value <- e$value + .01 * p$n
    }
    e
  }, .package = "medfit")
  err <- tryCatch(fiml_fit(), error = identity)
  expect_s3_class(err, "medfit_sem_fiml_error")
  expect_match(err$reason, "likelihoods disagree")
  expect_equal(nrow(err$attempts), 6L)
  expect_length(err$solver_calls, 9L)
  expect_true(all(err$attempts$accepted))
  expect_gt(diff(range(err$attempts$nll)) / 240L, .009)
})

test_that("FIML refuses invalid observed information after all actual solver calls", {
  original_geometry <- .sem_fiml_geometry
  original_hessian <- .sem_fiml_hessian
  for (kind in c("nonfinite", "nonpositive", "ill_conditioned")) {
    state <- new.env(parent = emptyenv())
    state$final <- FALSE
    testthat::local_mocked_bindings(
      .sem_fiml_geometry = function(...) {
        out <- original_geometry(...)
        state$final <- TRUE
        out
      },
      .sem_fiml_hessian = function(theta, p) {
        if (!state$final) return(original_hessian(theta, p))
        H <- diag(length(theta))
        if (kind == "nonfinite") H[1L, 1L] <- NA_real_
        if (kind == "nonpositive") H[1L, 1L] <- 0
        if (kind == "ill_conditioned") H[1L, 2L] <- H[2L, 1L] <- 1 - 1e-12
        H
      }, .package = "medfit"
    )
    err <- tryCatch(fiml_fit(), error = identity)
    expect_s3_class(err, "medfit_sem_fiml_error")
    expect_match(err$reason, "ill-conditioned observed information")
    expect_equal(nrow(err$attempts), 6L)
    expect_length(err$solver_calls, 9L)
    expect_true(all(err$attempts$accepted))
    expect_true(all(is.finite(err$attempts$status)))
    expect_s3_class(err$parent, "medfit_sem_fiml_error")
  }
})
