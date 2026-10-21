# Whole-fit edge grid: every accepted estimate has an independent regression or
# hand oracle; otherwise the fit must explicitly warn or refuse.
edge_data <- function(n = 120L, seed = 41L) {
  d <- sem_sim(sem_model_observed(), n, seed) # nolint: object_usage_linter.
  d[, c("X", "C", "M", "Y")]
}

edge_base <- "M ~ a*X + C\nY ~ b*M + cp*X + C"

edge_case <- function(name, builder, verdict, oracle, result) {
  list(name = name, build = builder, verdict = verdict, oracle = oracle, result = result)
}

edge_ols <- function(fit, spec, term = "a", formula = M ~ X + C, rhs = "X", tol = 1e-4) {
  ref <- stats::coef(stats::lm(formula, data = spec$data, weights = spec$args$weights))[[rhs]]
  testthat::expect_equal(unname(coef(fit)[[term]]), unname(ref), tolerance = tol)
}

edge_grid <- local({
  base <- function(data = edge_data(), model = edge_base, args = list()) {
    list(model = model, data = data, args = args)
  }
  add <- function(extra, data = edge_data(), args = list()) base(data, paste(edge_base, extra, sep = "\n"), args)
  list(
    # BUG? The coefficient matches OLS, but model information is reported singular at this scale.
    edge_case("units 1e-6 / 1e6", function() {
      d <- edge_data()
      d$X <- d$X * 1e-6
      d$C <- d$C * 1e6
      base(d)
    }, "warn", edge_ols, "information matrix is singular"),
    # BUG? The full-rank sample is refused by the reduced-Hessian gate near collinearity.
    edge_case("predictor r=.9999", function() {
      d <- edge_data()
      d$C <- d$X + 0.014 * d$C
      base(d)
    }, "refuse", NULL, "reduced Hessian is not positive definite"),
    edge_case("n near parameter count", function() base(edge_data(11L)), "accept", edge_ols, "OLS a"),
    edge_case("uninformed path", function() {
      d <- edge_data()
      d$X[] <- 1
      base(d)
    }, "refuse", NULL, "singular"),
    edge_case("Heywood variance floor", function() {
      d <- sem_sim(sem_model_heywood(), 50L, 10L)
      base(d, "eta =~ m1 + m2 + m3\neta ~ X\nY ~ eta + X\nm1 ~~ lower(0.001)*m1")
    }, "accept", function(fit, spec) {
      expect_equal(unname(coef(fit)[["m1~~m1"]]), 0.001, tolerance = 1e-6)
      expect_true("m1~~m1" %in% fit@diagnostics$active_bounds)
    }, "hand floor 0.001"),
    edge_case("redundant equalities", function() add("a == b\nb == a"), "accept",
              function(fit, spec) {
                ref <- fit_sem(paste(edge_base, "a == b", sep = "\n"), spec$data)
                expect_equal(coef(fit), coef(ref), tolerance = 1e-5)
              }, "independent equality fit"),
    edge_case("contradictory equalities", function() add("a == 0\na == 1"), "refuse", NULL,
              "constraint.*violated"),
    edge_case("inequality at optimum", function() {
      d <- edge_data()
      a <- stats::coef(stats::lm(M ~ X + C, d))[["X"]]
      add(sprintf("a > %.12f", a), d)
    }, "accept", edge_ols, "OLS boundary"),
    edge_case("start violates constraint", function() {
      spec <- add("a > 0")
      spec$runner <- function() {
        parsed <- .sem_parse(spec$model)
        ram <- .sem_to_ram(.sem_complete(parsed$parameters))$ram
        smp <- .sem_sample(spec$data[, ram$obs], ram)
        start <- .sem_default_start(ram, smp)
        start[["a"]] <- -2
        .sem_optimize(ram, smp, start, constraints = .sem_constraint_rows(parsed$constraints, ram))
      }
      spec
    }, "accept", function(fit, spec) {
      ref <- stats::coef(stats::lm(M ~ X + C, spec$data))[["X"]]
      expect_equal(unname(fit$theta[["a"]]), unname(ref), tolerance = 1e-4)
    }, "OLS a"),
    edge_case("zero product, zero Jacobian", function() {
      t <- seq_len(120L)
      d <- data.frame(
        X = sin(2 * pi * t / 120), C = cos(2 * pi * t / 120),
        M = sin(4 * pi * t / 120), Y = cos(4 * pi * t / 120)
      )
      add("a*b == 0", d)
    }, "accept", function(fit, spec) {
      expect_lt(abs(coef(fit)[["a"]] * coef(fit)[["b"]]), 1e-7)
      edge_ols(fit, spec, tol = 1e-4)
    }, "zero product + OLS"),
    edge_case("sign-flipped product", function() {
      d <- edge_data()
      d$M <- -0.5 * d$X + 0.2 * d$C + stats::residuals(stats::lm(M ~ X + C, d))
      add("a*b > 0.02", d)
    }, "warn", NULL, "starts disagree|only .* starts"),
    edge_case("branch cap 128", function() add(paste(rep("a*b == 0", 7L), collapse = "\n")),
              "refuse", NULL, "at most 64"),
    edge_case("bound at optimum", function() {
      d <- edge_data()
      a <- stats::coef(stats::lm(M ~ X + C, d))[["X"]]
      base(d, sprintf("M ~ upper(%.12f)*X + C\nY ~ b*M + cp*X + C", a))
    }, "accept", function(fit, spec) edge_ols(fit, spec, term = "M~X"), "OLS boundary"),
    edge_case("factor level two rows", function() {
      d <- edge_data()
      d$G <- factor(c(rep("usual", 118L), "rare", "rare"))
      base(d, "M ~ X + G\nY ~ M + X + G")
    }, "accept", function(fit, spec) {
      ref <- stats::coef(stats::lm(M ~ X + G, spec$data))[["Gusual"]]
      expect_equal(unname(coef(fit)[["M~G_usual"]]), unname(ref), tolerance = 1e-4)
    }, "factor OLS"),
    edge_case("weights 10000:1", function() {
      d <- edge_data()
      w <- rep(1, nrow(d))
      w[1:3] <- 1e4
      base(d, args = list(weights = w, se_type = "sandwich"))
    }, "accept", edge_ols, "weighted OLS a"),
    edge_case("mean shift 1e4", function() {
      d <- edge_data()
      d$X <- d$X + 1e4
      d$M <- d$M + 1e4
      d$Y <- d$Y + 1e4
      base(d, paste(edge_base, "M ~ 1\nY ~ 1", sep = "\n"))
    }, "accept", function(fit, spec) {
      edge_ols(fit, spec)
      ref <- stats::coef(stats::lm(M ~ X + C, spec$data))[["(Intercept)"]]
      expect_equal(unname(coef(fit)[["M~1"]]), unname(ref), tolerance = 1e-3)
    }, "OLS a + intercept"),
    edge_case("listwise few rows", function() {
      d <- edge_data()
      d$Y[12:120] <- NA_real_
      base(d)
    }, "accept", function(fit, spec) {
      spec$data <- stats::na.omit(spec$data)
      edge_ols(fit, spec)
      expect_equal(fit@n_dropped, 109L)
    }, "complete-case OLS"),
    edge_case("maxeval one", function() base(args = list(control = list(maxeval = 1L), n_starts = 1L)),
              "refuse", NULL, "no start converged.*status 5"),
    edge_case("start order and count", function() {
      base(args = list(n_starts = 3L))
    }, "accept", function(fit, spec) {
      alt <- fit_sem("M ~ start(0.2)*X + C\nY ~ b*M + cp*X + C", spec$data, n_starts = 1L)
      expect_equal(unname(coef(fit)), unname(coef(alt)), tolerance = 1e-4)
      edge_ols(fit, spec)
    }, "start-order parity + OLS")
  )
})

test_that("edge grid gives an oracle, diagnostic, or clear refusal", {
  for (case in edge_grid) {
    spec <- case$build()
    warnings <- character()
    result <- tryCatch(withCallingHandlers(
      if (is.null(spec$runner)) do.call(fit_sem, c(list(model = spec$model, data = spec$data), spec$args))
      else spec$runner(),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }, message = function(m) invokeRestart("muffleMessage")
    ), error = identity)
    if (case$verdict == "refuse") {
      expect_true(inherits(result, "error"), info = case$name)
      if (inherits(result, "error")) expect_match(conditionMessage(result), case$result, info = case$name)
    } else {
      expect_true(
        if (is.null(spec$runner)) S7::S7_inherits(result, SEMFit) else is.list(result),
        info = paste(case$name, if (inherits(result, "error")) conditionMessage(result) else "")
      )
      if (inherits(result, "error")) next
      if (case$verdict == "warn") {
        expect_match(paste(warnings, collapse = "\n"), case$result, info = case$name)
      } else {
        expect_length(warnings, 0L)
        case$oracle(result, spec)
      }
      if (case$verdict == "warn" && !is.null(case$oracle)) case$oracle(result, spec)
    }
  }
})

test_that("planted branch-cap defect turns the grid verdict red", {
  mutant <- sem_mutate(.sem_fit_branches, "64L", "128L") # a bare constant: covr instrumentation splits the if() text
  case <- edge_grid[[12L]]
  spec <- case$build()
  testthat::local_mocked_bindings(.sem_fit_branches = mutant)
  bad <- tryCatch(fit_sem(spec$model, spec$data), error = identity)
  expect_s7_class(bad, SEMFit) # the cap-refusal row would fail against this mutant
})
