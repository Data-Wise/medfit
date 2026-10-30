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
    expect_warning(ci <- confint(m, parm = "effects"), "Normal approximation")
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
