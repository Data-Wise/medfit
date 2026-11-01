source(testthat::test_path("helper-fiml-bootstrap.R"), local = TRUE)
fb_fits <- new.env(parent = emptyenv())
fb_fit <- function(direct = TRUE) {
  key <- if (direct) "free" else "zero"
  if (!exists(key, fb_fits, inherits = FALSE)) {
    fb_fits[[key]] <- fit_sem(fb_model(direct), fb_fixture(if (direct) "mar" else "mcar", direct),
                              missing = "fiml", fixed_x = FALSE)
  }
  fb_fits[[key]]
}

test_that("source arguments are named only and guarded before RNG or callback evaluation", {
  expect_true(all(c("source_fit", "effect") %in% names(formals(bootstrap_mediation))))
  set.seed(199L)
  before <- .Random.seed
  expect_error(bootstrap_mediation(source_fit = 1, effect = "nie", method = "parametric"), "SEMFit")
  expect_identical(.Random.seed, before)
  expect_error(bootstrap_mediation(effect = "nie"), "source_fit")
  expect_error(bootstrap_mediation(stop("callback forced"), source_fit = 1, effect = "nie"), "statistic_fn")
})

test_that("canonical symmetric covariance root preserves joint covariance and rejects repairs", {
  V <- matrix(c(4, 1, 1, 9), 2, dimnames = list(c("a", "b"), c("a", "b")))
  root <- .bootstrap_fiml_factor(V, c("a", "b"))
  expect_equal(root$factor %*% t(root$factor), V, tolerance = 1e-13)
  expect_equal(sweep(root$factor, 1, sqrt(diag(V)), `/`),
               t(sweep(root$factor, 1, sqrt(diag(V)), `/`)), tolerance = 1e-13)
  expect_error(.bootstrap_fiml_factor(V, c("a", "absent")), "names")
  bad <- V
  bad[1, 2] <- 10
  expect_error(.bootstrap_fiml_factor(bad, c("a", "b")), "symmetric")
  bad[2, 1] <- 10
  expect_error(.bootstrap_fiml_factor(bad, c("a", "b")), "semidefinite")
  expect_error(.bootstrap_fiml_factor(V * NA_real_, c("a", "b")), "finite")
  singular <- matrix(1, 2, 2, dimnames = dimnames(V))
  expect_equal(tcrossprod(.bootstrap_fiml_factor(singular, c("a", "b"))$factor), singular)
  roundoff <- singular
  roundoff[1, 2] <- roundoff[2, 1] <- 1 + .Machine$double.eps
  expect_length(.bootstrap_fiml_factor(roundoff, c("a", "b"))$clipped, 1L)
  bad <- V
  bad[1, 1] <- 0
  expect_error(.bootstrap_fiml_factor(bad, c("a", "b")), "positive")
})

test_that("Gaussian draws use all canonical coordinates and the original point estimate", {
  fit <- fb_fit()
  frozen <- fb_snapshot(fit)
  out <- bootstrap_mediation(source_fit = fit, effect = "te", method = "parametric", n_boot = 8L, seed = 123L)
  expect_identical(fb_snapshot(fit), frozen)
  expect_identical(out@inference$schema, "fiml-bootstrap-1")
  expect_identical(out@inference$status, "complete")
  expect_identical(out@inference$method_label, "Gaussian parameter-draw percentile interval")
  expect_identical(out@n_boot, 8L)
  expect_length(out@boot_estimates, 8L)
  expect_equal(out@estimate, unname(coef(fit)["a"] * coef(fit)["b"] + coef(fit)["cp"]))
  expect_equal(c(out@ci_lower, out@ci_upper),
               unname(stats::quantile(out@boot_estimates, c(.025, .975), type = 7)))
  root <- .bootstrap_fiml_factor(vcov(fit), names(coef(fit)))
  set.seed(123L)
  normals <- matrix(stats::rnorm(8L * length(coef(fit))), nrow = 8L, byrow = TRUE)
  draws <- sweep(normals %*% t(root$factor), 2, coef(fit), `+`)
  expect_equal(out@boot_estimates, unname(draws[, "a"] * draws[, "b"] + draws[, "cp"]))
  again <- bootstrap_mediation(source_fit = fit, effect = "te", method = "parametric", n_boot = 8L,
                               seed = 123L, parallel = TRUE, ncores = 2L)
  expect_identical(again@boot_estimates, out@boot_estimates)
  expect_output(print(out), "Gaussian parameter-draw")
  expect_output(show(out), "Gaussian parameter-draw")
  expect_identical(names(tidy(out)), c("term", "estimate", "std_error", "conf_low", "conf_high"))
  expect_identical(names(glance(out)), c("estimate", "ci_level", "method", "n_boot"))
})

test_that("source route refuses ambiguous arguments and unvalidated provenance before RNG", {
  fit <- fb_fit()
  cases <- list(list(), list(method = "param"), list(method = "plugin"),
                list(method = "parametric", effect = "ni"), list(method = "parametric", data = fit@data),
                list(method = "parametric", statistic_fn = NULL), list(method = "parametric", surprise = 1),
                list(method = "parametric", n_boot = 0), list(method = "parametric", ci_level = 1))
  for (args in cases) {
    if (is.null(args$effect)) args$effect <- "nie"
    set.seed(199L)
    before <- .Random.seed
    expect_error(do.call(bootstrap_mediation, c(list(source_fit = fit), args)))
    expect_identical(.Random.seed, before)
  }
  corrupted <- fit
  corrupted@theta[1] <- corrupted@theta[1] + 1
  expect_error(bootstrap_mediation(source_fit = corrupted, effect = "nie", method = "parametric"), "ledger")
})

test_that("row refits retain masks, duplicates, protocol and complete requested ledger", {
  fit <- fb_fit()
  frozen <- fb_snapshot(fit)
  out <- bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 2L, seed = 911L)
  expect_identical(fb_snapshot(fit), frozen)
  expect_identical(out@inference$status, "complete")
  expect_length(out@inference$replicates, 2L)
  set.seed(911L)
  indices <- lapply(1:2, function(i) sample.int(300L, 300L, replace = TRUE))
  expect_identical(lapply(out@inference$replicates, `[[`, "rows"), indices)
  expect_true(anyDuplicated(indices[[1]]) > 0L)
  expect_true(all(vapply(out@inference$replicates, function(x) x$status == "accepted", logical(1))))
  expect_equal(out@inference$frame$retained_n, 300L)
  expect_identical(out@inference$refit_protocol$n_starts, 3L)
})

test_that("failed refits withhold intervals and SD through every output path", {
  fit <- fb_fit()
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) stop("injected failure"), .package = "medfit")
  out <- bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 3L, seed = 911L)
  expect_identical(out@n_boot, 3L)
  expect_true(all(is.na(out@boot_estimates)))
  expect_identical(out@inference$status, "withheld")
  expect_identical(out@inference$failed, 3L)
  expect_true(all(is.na(confint(out))))
  expect_true(all(is.na(confint(out, level = .8))))
  expect_true(is.na(tidy(out)$std_error))
  expect_true(all(is.na(tidy(out)[c("conf_low", "conf_high")])))
  expect_output(print(out), "withheld")
  expect_match(out@inference$replicates[[1]]$reason, "injected failure")
})

test_that("fixed-zero paths and retained all-empty MCAR evidence are preserved", {
  fit <- fb_fit(FALSE)
  out <- bootstrap_mediation(source_fit = fit, effect = "nde", method = "parametric", n_boot = 8L, seed = 123L)
  expect_identical(out@boot_estimates, rep(0, 8L))
  expect_equal(c(out@estimate, out@ci_lower, out@ci_upper), c(0, 0, 0))
  expect_equal(out@inference$frame$collected_n, 303L)
  expect_equal(out@inference$frame$retained_n, 300L)
  expect_equal(out@inference$frame$dropped_n, 3L)
  expect_length(out@inference$parameters, 8L)
})

test_that("one unresolved replicate cannot become a survivor interval through stored bounds", {
  fit <- fb_fit()
  invocation <- 0L
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    invocation <<- invocation + 1L
    if (invocation == 2L) stop("one unresolved refit")
    fit
  }, .package = "medfit")
  out <- bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 3L, seed = 911L)
  expect_identical(is.na(out@boot_estimates), c(FALSE, TRUE, FALSE))
  expect_identical(out@inference$successful, 2L)
  expect_identical(out@inference$failed, 1L)
  # Even stale finite cached bounds may not bypass a withheld inference ledger.
  out@ci_lower <- -1
  out@ci_upper <- 1
  expect_true(all(is.na(confint(out, level = .8))))
  expect_true(all(is.na(tidy(out)[c("std_error", "conf_low", "conf_high")])))
  expect_true(all(is.na(summary(out)$ci)))
  expect_output(print(out), "Lower: +NA")
  expect_output(show(out), "withheld")
})

test_that("parameter draws evaluate polynomials without truncating negative nuisance variances", {
  fit <- fb_fit()
  original_factor <- .bootstrap_fiml_factor
  testthat::local_mocked_bindings(.bootstrap_fiml_factor = function(V, parameters) {
    root <- original_factor(V, parameters)
    root$factor <- diag(100, length(parameters))
    dimnames(root$factor) <- list(parameters, parameters)
    root
  }, .package = "medfit")
  out <- bootstrap_mediation(source_fit = fit, effect = "nie", method = "parametric", n_boot = 8L, seed = 123L)
  set.seed(123L)
  normals <- matrix(stats::rnorm(8L * length(coef(fit))), nrow = 8L, byrow = TRUE)
  draws <- sweep(normals * 100, 2, coef(fit), `+`)
  colnames(draws) <- names(coef(fit))
  expect_true(any(draws[, "X~~X"] < 0))
  expect_identical(out@inference$status, "complete")
  expect_equal(out@boot_estimates, unname(draws[, "a"] * draws[, "b"]))
})

test_that("effect evaluation refuses nonfinite and nonscalar central functionals", {
  fit <- fb_fit()
  spec <- .sem_fiml_model(fit@model)
  props <- S7::props(extract_mediation(fit, treatment = "X", mediator = "M"))
  props$fit_context <- NULL
  template <- do.call(MediationData, props)
  theta <- fit@theta
  theta[spec$map[["a"]]] <- Inf
  expect_error(.bootstrap_fiml_effect(theta, spec, template, "nie"), "nonfinite FIML effect")
  testthat::local_mocked_bindings(nie = function(...) c(1, 2), .package = "medfit")
  expect_error(.bootstrap_fiml_effect(fit@theta, spec, template, "nie"), "nonfinite FIML effect")
})

test_that("defensive canonical theta guard rejects damage before RNG after the provenance guard", {
  fit <- fb_fit()
  testthat::local_mocked_bindings(.sem_fiml_require = function(...) invisible(NULL), .package = "medfit")
  for (damage in c("names", "nonfinite")) {
    damaged <- fit
    theta <- damaged@theta
    if (damage == "names") names(theta)[1] <- "wrong_parameter" else theta[1] <- NA_real_
    attr(damaged, "theta") <- theta
    set.seed(199L)
    before <- .Random.seed
    expect_error(bootstrap_mediation(source_fit = damaged, effect = "nie", method = "parametric"),
                 "finite canonical free parameters")
    expect_identical(.Random.seed, before)
  }
})

test_that("accepted refit warnings are muffled and retained in the replicate ledger", {
  fit <- fb_fit()
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    warning("accepted refit notice", call. = FALSE)
    fit
  }, .package = "medfit")
  expect_silent(out <- bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric",
                                           n_boot = 2L, seed = 911L))
  expect_identical(out@inference$status, "complete")
  expect_identical(lapply(out@inference$replicates, `[[`, "warnings"), rep(list("accepted refit notice"), 2L))
  expect_equal(out@boot_estimates, rep(unname(coef(fit)["a"] * coef(fit)["b"]), 2L))
})

test_that("inner interrupt records preserve the condition class and later unattempted IDs", {
  fit <- fb_fit()
  invocation <- 0L
  condition_class <- c("fixture_interrupt", "interrupt", "condition")
  testthat::local_mocked_bindings(.bootstrap_fiml_refit = function(...) {
    invocation <<- invocation + 1L
    if (invocation == 2L) stop(structure(list(message = "fixture stop", call = NULL), class = condition_class))
    fit
  }, .package = "medfit")
  out <- bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 3L, seed = 911L)
  expect_identical(out@inference$status, "incomplete")
  expect_identical(out@inference$replicates[[2]]$condition_class, condition_class)
  expect_identical(out@inference$replicates[[2]]$reason, "fixture stop")
  expect_identical(vapply(out@inference$replicates, `[[`, character(1), "status"),
                   c("accepted", "interrupted", "unattempted"))
  expect_true(all(is.na(confint(out))))
})

test_that("malformed worker results retain every requested ID and withhold survivor intervals", {
  fit <- fb_fit()
  testthat::local_mocked_bindings(.bootstrap_fiml_execute = function(B, run, ...) {
    list(run(1L), structure("worker failed", class = "try-error"), list(record = list(id = 3L)))
  }, .bootstrap_fiml_refit = function(...) fit, .package = "medfit")
  out <- bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 3L, seed = 911L)
  expect_identical(out@n_boot, 3L)
  expect_identical(is.na(out@boot_estimates), c(FALSE, TRUE, TRUE))
  expect_identical(vapply(out@inference$replicates, `[[`, integer(1), "id"), 1:3)
  expect_identical(out@inference$status, "withheld")
  expect_identical(out@inference$replicates[[2]]$reason, "worker failed")
  expect_true(all(is.na(confint(out, level = .8))))
  expect_true(is.na(tidy(out)$std_error))
})

test_that("printed summaries label method and inference status", {
  out <- bootstrap_mediation(source_fit = fb_fit(), effect = "nie", method = "parametric", n_boot = 8L, seed = 123L)
  expect_output(print(summary(out)), "Gaussian parameter-draw percentile interval")
  expect_output(print(summary(out)), "Inference status: complete")
})

test_that("immutability snapshot detects every property and instance or constructor attribute mutation", {
  fit <- fb_fit()
  frozen <- fb_snapshot(fit)
  for (key in names(S7::props(fit))) {
    mutated <- fit
    value <- attr(mutated, key)
    if (is.data.frame(value)) {
      value$.mutation_probe <- rep(TRUE, nrow(value))
    } else if (is.list(value)) {
      value$.mutation_probe <- TRUE
    } else if (is.numeric(value)) {
      if (!length(value)) value <- 1 else value[1] <- if (is.na(value[1])) 0 else value[1] + 1
    } else if (is.character(value)) {
      value[1] <- paste0(value[1], "_mutated")
    } else if (is.logical(value)) {
      value[1] <- !value[1]
    } else {
      value <- quote(mutated_call())
    }
    # Deliberately bypass property validation: the snapshot must catch even malformed mutations.
    attr(mutated, key) <- value
    expect_false(identical(fb_snapshot(mutated), frozen), info = key)
  }
  mutated <- fit
  attr(mutated, "unexpected_source_attribute") <- TRUE
  expect_false(identical(fb_snapshot(mutated), frozen))
  mutated <- fit
  attr(mutated, "class") <- c(class(mutated), "unexpected_class")
  expect_false(identical(fb_snapshot(mutated), frozen))
  mutated <- fit
  constructor <- S7::S7_class(mutated)
  body(constructor) <- quote(NULL)
  attr(mutated, "S7_class") <- constructor
  expect_false(identical(fb_snapshot(mutated), frozen))
  expect_true(S7::S7_inherits(fit, SEMFit))
  expect_identical(fb_snapshot(fit), frozen)
})

test_that("constructor snapshots detect nested code and source-reference metadata changes", {
  original <- quote(function(x) x + 1)
  reference <- structure(1:8, class = "srcref", srcfile = new.env(parent = emptyenv()), annotation = list(a = 1))
  attr(original, "srcref") <- reference
  frozen <- fb_constructor_state(original)
  mutated <- original
  mutated[[3]][[3]] <- 2
  expect_false(identical(fb_constructor_state(mutated), frozen))
  mutated <- original
  attr(mutated, "srcref")[1] <- 2L
  expect_false(identical(fb_constructor_state(mutated), frozen))
  mutated <- original
  reference <- attr(mutated, "srcref")
  attr(reference, "annotation") <- list(b = 1)
  attr(mutated, "srcref") <- reference
  expect_false(identical(fb_constructor_state(mutated), frozen))
  mutated <- original
  reference <- attr(mutated, "srcref")
  attr(reference, "srcfile") <- new.env(parent = emptyenv())
  attr(mutated, "srcref") <- reference
  expect_false(identical(fb_constructor_state(mutated), frozen))
  expect_identical(fb_constructor_state(original), frozen)
})
