# D1 outcome ledger, reconciled with ADR D-11 and D-12 (planning/specs/ADR-native-solver-and-engines-2026-10-23.md):
# an unresolved required zero-product branch is still the classed error `medfit_error_no_convergence` (never a fit),
# and the ledger rides on it as `$ledger`. `mbco_sem()` keeps its unresolved result (#300: NA statistic, `unresolved`
# TRUE, a warning) and carries the same field; so does `compare_lr()`'s `$reference`. Evidence the consumers cannot
# trust (missing, malformed, mismatched) is refused with `medfit_error_ledger`.
# Stored inputs and injected conditions only; no generated samples.
outcome_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
outcome_data <- function() readRDS(testthat::test_path("fixtures", "memory_exp.rds"))
outcome_union <- paste(outcome_model, "a1*b1 == 0", sep = "\n")
no_conv <- function(msg) medfit:::.sem_no_convergence(msg)
# the value of an expression and the messages of the warnings it raised, in order
warned <- function(expr) {
  seen <- character()
  value <- withCallingHandlers(expr, warning = function(w) {
    seen <<- c(seen, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  list(value = value, warnings = seen)
}

test_that("public fits and MBCO retain versioned, correctly attributed ledgers", {
  d <- outcome_data()
  fit <- fit_sem(outcome_model, d, n_starts = 1L)
  res <- mbco_sem(fit, "a1", "b1")
  expect_identical(fit@diagnostics$ledger$schema_version, 1L)
  expect_identical(res$ledger$schema_version, 1L)
  expect_false(isTRUE(res$unresolved))
  nodes <- res$ledger$children
  expect_identical(vapply(nodes, `[[`, "", "id"), c("mbco/full", "mbco/null:1", "mbco/null:2"))
  expect_identical(nodes[[2]]$constraints$lhs, "a1")
  expect_identical(nodes[[3]]$constraints$lhs, "b1")
  expect_identical(.sem_node_sample(nodes[[2]], res$ledger), fit@data)
  expect_identical(nodes[[2]]$optimizer$state, "accepted")
  expect_identical(nodes[[2]]$feasibility, "witness")
  expect_identical(nodes[[2]]$covariance, "available")
  # stored known answers, unchanged
  expect_lt(abs(res$tests$diff_ll[1] - 221.045546), 1e-6)
  expect_lt(abs(res$tests$diff_ll[2] - 0.083100), 1e-6)
  expect_identical(unname(res$statistic), min(res$tests$diff_ll))
  union <- fit_sem(outcome_union, d, n_starts = 1L)
  ledger <- union@diagnostics$ledger
  expect_identical(ledger$enumeration, list(state = "complete", required = 2L))
  expect_identical(ledger$outcome, "resolved")
  expect_identical(union@internals$branch, "b1 == 0")
  # all-success minimum: the union's discrepancy is the smallest of its branches
  expect_identical(ledger$likelihood$f, min(vapply(ledger$children, function(x) x$likelihood$f, 0)))
  expect_lt(abs(nrow(d) * (union@f - fit@f) - 0.083100), 1e-6)
})

test_that("neither partial-failure ordering can return a surviving union fit; the D-11 error carries the ledger", {
  real <- .sem_fit_syntax
  for (failed in c("a1", "b1")) {
    local({
      seen <- character()
      testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
        if (!is.null(parsed)) {
          label <- parsed$constraints$lhs[1]
          seen <<- c(seen, label)
          if (label == failed) {
            warning(paste("notice", label))
            stop(structure(list(message = paste("blocked", label), call = NULL),
                           class = c("injected_branch_error", "error", "condition")))
          }
        }
        real(..., parsed = parsed)
      })
      err <- tryCatch(fit_sem(outcome_union, outcome_data(), n_starts = 1L), error = identity)
      # D-11 is unchanged: the same class, and no fit comes back
      expect_s3_class(err, "medfit_error_no_convergence")
      expect_false(S7::S7_inherits(err, SEMFit))
      expect_match(conditionMessage(err), "1 of 2 zero-product branches did not converge")
      expect_identical(seen, c("a1", "b1"))
      expect_identical(err$ledger$enumeration$state, "complete")
      expect_identical(err$ledger$outcome, "unresolved")
      children <- err$ledger$children
      bad <- children[[match(failed, c("a1", "b1"))]]
      expect_identical(bad$outcome, "unresolved")
      expect_identical(bad$feasibility, "unknown")
      expect_true("injected_branch_error" %in% bad$condition$class)
      expect_match(bad$notices$warnings[[1]]$message, failed)
      expect_false(grepl("notice", conditionMessage(err))) # the notice is in the ledger, not the message
      expect_length(err$ledger$notices$warnings, 0L)
      expect_length(bad$notices$warnings, 1L)
      expect_true(is.finite(err$best_survivor$f))
      # the survivor is named by its own node and carries that node's discrepancy
      survivor <- children[[match(failed, c("a1", "b1")) %% 2L + 1L]]
      expect_identical(err$best_survivor$id, survivor$id)
      expect_identical(err$best_survivor$f, survivor$likelihood$f)
      expect_null(err$p.value)
    })
  }
})

test_that("the ledger on the D-11 error is complete: every required branch, in order, with its own restriction", {
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed) && parsed$constraints$lhs[1] == "a1") stop("blocked a1")
    real(..., parsed = parsed)
  })
  err <- tryCatch(fit_sem(outcome_union, outcome_data(), n_starts = 1L), error = identity)
  led <- err$ledger
  expect_identical(led$schema_version, 1L)
  expect_identical(led$id, "fit")
  expect_true(is.na(led$parent_id))
  expect_identical(led$enumeration, list(state = "complete", required = 2L))
  expect_identical(vapply(led$children, `[[`, "", "id"), c("fit/branch:1", "fit/branch:2"))
  expect_identical(vapply(led$children, `[[`, "", "parent_id"), c("fit", "fit"))
  expect_identical(vapply(led$children, function(x) x$constraints$lhs[1], ""), c("a1", "b1"))
  # every node carries its own context: the estimation sample and likelihood domain it was attempted on
  for (child in led$children) {
    expect_true(is.data.frame(.sem_node_sample(child, led)))
    expect_identical(child$context$domain$objective, "normal_ml_discrepancy")
  }
  expect_identical(led$children[[1]]$outcome, "unresolved")
  expect_identical(led$children[[2]]$outcome, "resolved")
  # the ledger of an unresolved call never passes the validator that consumers apply to evidence
  expect_false(.sem_valid_outcome(led))
})

test_that("MBCO attempts every null, keeps its unresolved result and does not swap labels", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  real <- .sem_fit_syntax
  for (failed in c("a1", "b1", "both")) {
    local({
      seen <- character()
      testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
        label <- if (endsWith(model, "a1 == 0")) "a1" else "b1"
        seen <<- c(seen, label)
        if (failed %in% c(label, "both")) {
          warning(paste("refit notice", label))
          no_conv(paste("blocked", label))
        }
        real(model, ...)
      })
      out <- warned(mbco_sem(fit, "a1", "b1"))
      res <- out$value
      expect_s3_class(res, "mbco_sem")
      expect_true(isTRUE(res$unresolved))
      expect_true(is.na(res$statistic))
      expect_true(is.na(res$p.value))
      expect_identical(seen, c("a1", "b1"))
      expect_length(res$ledger$children, 3L)
      expect_identical(res$ledger$outcome, "unresolved")
      expect_identical(res$ledger$children[[2]]$constraints$lhs, "a1")
      expect_identical(res$ledger$children[[3]]$constraints$lhs, "b1")
      for (label in if (failed == "both") c("a1", "b1") else failed) {
        expect_false(any(grepl(paste("refit notice", label), out$warnings)))
        node <- res$ledger$children[[match(label, c("a1", "b1")) + 1L]]
        expect_identical(node$outcome, "unresolved")
        expect_identical(node$notices$warnings[[1]]$message, paste("refit notice", label))
      }
    })
  }
  # a resolved full union can still have an unresolved nested branch in a null
  full <- fit_sem(outcome_union, outcome_data(), n_starts = 1L)
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed) && parsed$constraints$lhs[1] == "a1") stop("nested blocked")
    real(..., parsed = parsed)
  })
  res <- suppressWarnings(mbco_sem(full, "a1", "b1"))
  expect_true(isTRUE(res$unresolved))
  expect_true(is.na(res$statistic))
  expect_identical(res$ledger$children[[2]]$children[[1]]$outcome, "unresolved")
  expect_identical(res$ledger$children[[3]]$children[[1]]$outcome, "unresolved")
})

test_that("a structural error in a refit still stops: it is not an unresolved result", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) stop("planted structural error", call. = FALSE))
  err <- tryCatch(mbco_sem(fit, "a1", "b1"), error = identity)
  expect_false(inherits(err, "medfit_error_no_convergence"))
  expect_match(conditionMessage(err), "the refit with `a1 == 0` failed \\(planted structural error\\)")
})

test_that("missing, malformed and mismatched public evidence refuses inference", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  for (bad in list(NULL, list(schema_version = 999L), list(schema_version = 1L))) {
    altered <- fit
    altered@diagnostics$ledger <- bad
    expect_error(mbco_sem(altered, "a1", "b1"), class = "medfit_error_ledger")
  }
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    # Planted label swap: valid evidence for the other null must be rejected, not turned into an unresolved row.
    real(sub("a1 == 0$", "b1 == 0", model), ...)
  })
  expect_error(mbco_sem(fit, "a1", "b1"), class = "medfit_error_ledger")
})

test_that("all-failure and full-fit errors retain original conditions and classes without feasibility claims", {
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed)) stop("every branch blocked")
    real(..., parsed = parsed)
  })
  err <- tryCatch(fit_sem(outcome_union, outcome_data()), error = identity)
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_match(conditionMessage(err), "no branch of the zero-product constraints converged")
  expect_length(err$ledger$children, 2L)
  expect_true(all(vapply(err$ledger$children, function(x) x$outcome == "unresolved", TRUE)))
  expect_null(err$best_survivor)
  expect_null(err$p.value)
  # a data error keeps its class (it is not an optimizer failure) and carries the ledger
  full <- tryCatch(fit_sem("absent ~ a*x", outcome_data()), error = identity)
  expect_false(inherits(full, "medfit_error_no_convergence"))
  expect_match(conditionMessage(full), "not columns")
  expect_match(full$ledger$condition$message, "not columns")
  expect_identical(full$ledger$feasibility, "unknown")
  expect_identical(full$ledger$outcome, "unresolved")
})

test_that("over-cap refusal does not claim complete enumeration", {
  syntax <- paste(outcome_model, paste(rep("a1*b1 == 0", 7L), collapse = "\n"), sep = "\n")
  testthat::local_mocked_bindings(.sem_optimize = function(...) stop("optimizer must not run"))
  err <- tryCatch(fit_sem(syntax, outcome_data()), error = identity)
  expect_match(conditionMessage(err), "128 branches")
  expect_identical(err$ledger$enumeration, list(state = "not_enumerated", required = 128L))
  expect_length(err$ledger$children, 0L)
})

test_that("64 raw branches retain distinct positional IDs even for repeated constraints", {
  syntax <- paste(outcome_model, paste(rep("a1*b1 == 0", 6L), collapse = "\n"), sep = "\n")
  fit <- fit_sem(syntax, outcome_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  expect_identical(node$enumeration, list(state = "complete", required = 64L))
  expect_length(node$children, 64L)
  expect_identical(vapply(node$children, `[[`, "", "id"), paste0("fit/branch:", 1:64))
  expect_identical(fit@f, min(vapply(node$children, function(x) x$likelihood$f, 0)))
  expect_true(.sem_valid_outcome(node))
})

test_that("duplicate and tampered branch IDs cannot forge resolved public evidence", {
  fit <- fit_sem(outcome_union, outcome_data(), n_starts = 1L)
  for (id in c("fit/branch:1", "unrelated")) {
    bad <- fit
    bad@diagnostics$ledger$children[[2]]$id <- id
    expect_error(mbco_sem(bad, "a1", "b1"), class = "medfit_error_ledger")
  }
  bad <- fit
  bad@diagnostics$ledger$children[[2]] <- bad@diagnostics$ledger$children[[1]]
  expect_error(mbco_sem(bad, "a1", "b1"), class = "medfit_error_ledger")
})

test_that("clean starts and the existing all-row and nonlinear gates survive the wrapper", {
  d <- outcome_data()
  real <- .sem_optimize
  starts <- list()
  testthat::local_mocked_bindings(.sem_optimize = function(ram, smp, start, ...) {
    starts[[length(starts) + 1L]] <<- list(given = start, default = .sem_default_start(ram, smp))
    real(ram, smp, start, ...)
  })
  fit_sem(outcome_union, d, n_starts = 1L)
  expect_length(starts, 2L)
  for (x in starts) expect_identical(x$given, x$default)
  tied <- fit_sem(paste(outcome_model, "a1 == b1", sep = "\n"), d, n_starts = 1L)
  expect_lt(abs(tied@theta["a1"] - tied@theta["b1"]), 1e-6)
  # the all-row gate still refuses contradictory constraints, and the refusal carries the ledger
  contra <- tryCatch(fit_sem(paste(outcome_model, "a1 == b1\na1 == b1 + 1", sep = "\n"), d, n_starts = 1L),
                     error = identity)
  expect_s3_class(contra, "error")
  expect_identical(contra$ledger$outcome, "unresolved")
  expect_identical(contra$ledger$feasibility, "unknown")
  nonlinear <- suppressWarnings(fit_sem(paste(outcome_model, "cp == a1*b1", sep = "\n"), d, n_starts = 1L))
  expect_lt(abs(nonlinear@theta["cp"] - nonlinear@theta["a1"] * nonlinear@theta["b1"]), 1e-6)
})

test_that("public consumers reject dropped acceptance state and nonfinite likelihood evidence", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  for (what in c("status", "likelihood", "sample")) {
    altered <- fit
    if (what == "status") altered@diagnostics$ledger$optimizer$status <- NULL
    if (what == "likelihood") altered@diagnostics$ledger$likelihood$f <- Inf
    if (what == "sample") altered@diagnostics$ledger$context[["sample"]] <- altered@data[-1, ]
    err <- tryCatch(mbco_sem(altered, "a1", "b1"), error = identity)
    expect_s3_class(err, "medfit_error_ledger")
    # a refusal of evidence is never an optimizer failure, so no caller can mistake it for one
    expect_false(inherits(err, "medfit_error_no_convergence"))
    expect_identical(err$ledger$schema_version, 1L)
    expect_identical(err$ledger$outcome, "unresolved")
  }
})

test_that("retained covariance and identification notices are distinct from optimizer acceptance", {
  real <- .sem_vcov
  testthat::local_mocked_bindings(.sem_vcov = function(...) {
    vc <- real(...)
    warning("injected singular information")
    vc[] <- NA_real_
    vc
  })
  fit <- suppressWarnings(fit_sem(outcome_model, outcome_data(), n_starts = 1L))
  node <- fit@diagnostics$ledger
  expect_identical(node$covariance, "unavailable")
  expect_identical(node$optimizer$state, "accepted")
  expect_identical(node$notices$warnings[[1]]$message, "injected singular information")
  union <- suppressWarnings(fit_sem(outcome_union, outcome_data(), n_starts = 1L))
  expect_length(union@diagnostics$ledger$notices$warnings, 0L)
  for (child in union@diagnostics$ledger$children) {
    expect_identical(child$notices$warnings[[1]]$message, "injected singular information")
  }
  res <- suppressWarnings(mbco_sem(fit, "a1", "b1"))
  expect_identical(res$ledger$children[[2]]$covariance, "unavailable")
  expect_true(is.finite(unname(res$statistic)))
  union_res <- suppressWarnings(mbco_sem(union, "a1", "b1"))
  for (null in union_res$ledger$children[-1]) {
    expect_identical(null$notices$warnings[[1]]$message, "injected singular information")
    expect_true(length(null$children) > 0L)
  }
})

test_that("a notice raised inside the pipeline keeps its condition class in the ledger", {
  testthat::local_mocked_bindings(.sem_fit_pipeline = function(...) {
    warning(structure(class = c("planted_notice", "warning", "condition"),
                      list(message = "classed notice", call = NULL)))
    stop("pipeline blocked", call. = FALSE)
  })
  err <- tryCatch(fit_sem(outcome_model, outcome_data(), n_starts = 1L), error = identity)
  expect_match(conditionMessage(err), "pipeline blocked")
  expect_identical(err$ledger$notices$warnings[[1]]$class[1], "planted_notice")
})

test_that("MBCO keeps boundary notices on a typed refit failure", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    r <- real(model, ...)
    if (endsWith(model, "a1 == 0")) {
      warning("boundary warning before typed failure")
      message("boundary message before typed failure")
      # the node a real failure leaves: no likelihood, the condition, the notices raised below
      node <- .sem_outcome(r$ledger$context, r$ledger$constraints, error = simpleError("typed refit failure"))
      node$notices$warnings <- list(.sem_condition_record(simpleWarning("inner typed notice")))
      .sem_abort_outcome("typed refit failure", node)
    }
    r
  })
  out <- warned(mbco_sem(fit, "a1", "b1"))
  res <- out$value
  expect_true(isTRUE(res$unresolved))
  node <- res$ledger$children[[2]]
  expect_identical(node$notices$warnings[[1]]$message, "inner typed notice")
  expect_true("boundary warning before typed failure" %in%
                vapply(node$notices$warnings, `[[`, "", "message"))
  expect_true("boundary message before typed failure\n" %in%
                vapply(node$notices$messages, `[[`, "", "message"))
  expect_false(any(grepl("boundary warning before typed failure", out$warnings)))
  expect_true(is.na(res$p.value))
})

# Mutants replace source text in a function body; they run in every check except under covr.
outcome_mutate <- function(fun, old, new) {
  code <- paste(deparse(body(fun), width.cutoff = 500L), collapse = "\n")
  stopifnot(grepl(old, code, fixed = TRUE))
  body(fun) <- parse(text = sub(old, new, code, fixed = TRUE))[[1L]]
  fun
}

test_that("removing ID validation lets a duplicate-ID ledger escape its intended assertion", {
  # covr rewrites function bodies, so the text these mutants replace is not there under coverage
  testthat::skip_on_covr()
  fit <- fit_sem(outcome_union, outcome_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  node$children[[2]]$id <- node$children[[1]]$id
  expect_false(.sem_valid_outcome(node))
  mutant <- outcome_mutate(.sem_valid_outcome, "identical(x$id, id)", "TRUE")
  testthat::local_mocked_bindings(.sem_valid_outcome = mutant)
  expect_true(.sem_valid_outcome(node))
  expect_failure(expect_false(.sem_valid_outcome(node)))
})

test_that("survivor-success, status-drop and label-swap mutants fail intended assertions", {
  # covr rewrites function bodies, so the text these mutants replace is not there under coverage
  testthat::skip_on_covr()
  d <- outcome_data()
  full <- fit_sem(outcome_model, d, n_starts = 1L)
  branch_fun <- .sem_fit_branches
  real <- .sem_fit_syntax
  # Controlled hidden branch has reference LR 1; the only returned candidate has LR 9.
  # This is an injected fault case, not evidence about an actual failed optimum.
  for (failed in c("a1", "b1")) local({
    testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
      if (!is.null(parsed) && parsed$constraints$lhs[1] == failed) stop("hidden reference LR 1")
      out <- real(..., parsed = parsed)
      if (!is.null(parsed)) {
        out$f <- full@f + 9 / nrow(d)
        out$ledger$likelihood$f <- out$f
      }
      out
    })
    get <- function() tryCatch(fit_sem(outcome_union, d, n_starts = 1L), error = identity)
    good <- get()
    expect_s3_class(good, "medfit_error_no_convergence")
    expect_equal(nrow(d) * (good$best_survivor$f - full@f), 9)
    # the mutant drops D-11's skipped-branch guard and rebuilds the ledger as if the survivor stood alone
    mutant <- outcome_mutate(branch_fun, "if (length(skipped))", "if (FALSE)")
    mutant <- outcome_mutate(mutant, "out$ledger <- ledger",
                             "out$ledger <- .sem_outcome(context, parsed$constraints, out)")
    # Also bypass the independent consumer validator: otherwise it correctly catches this mutant first.
    # This keeps the numeric control; it weakens no assertion.
    testthat::local_mocked_bindings(.sem_fit_branches = mutant,
                                    .sem_require_outcome = function(...) invisible(NULL))
    bad <- get()
    expect_true(S7::S7_inherits(bad, SEMFit)) # the mutant runs, rather than throwing incidentally
    expect_equal(nrow(d) * (bad@f - full@f), 9)
    expect_failure(expect_s3_class(bad, "medfit_error_no_convergence"))
  })
  local({
    dropped <- outcome_mutate(.sem_as_semfit, '"ledger"', '"omitted_ledger"')
    testthat::local_mocked_bindings(.sem_as_semfit = dropped)
    bad <- fit_sem(outcome_model, d, n_starts = 1L)
    expect_failure(expect_identical(bad@diagnostics$ledger$schema_version, 1L))
  })
  local({
    swapped <- outcome_mutate(mbco_sem, "tested <- paths[i]", "tested <- rev(paths)[i]")
    # the MBCO root rebuilds each null from the tested path, so the mutant is refused before it returns
    expect_error(swapped(full, "a1", "b1"), class = "medfit_error_ledger")
  })
})

test_that("outer pipeline notices survive a typed nested failure", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  node$outcome <- "unresolved"
  node$notices$warnings <- list(list(message = "inner warning", class = "simpleWarning"))
  testthat::local_mocked_bindings(.sem_fit_pipeline = function(...) {
    warning("outer pipeline warning")
    message("outer pipeline message")
    .sem_abort_outcome("nested failure", node)
  })
  err <- tryCatch(fit_sem(outcome_model, outcome_data(), n_starts = 1L), error = identity)
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_identical(conditionMessage(err), "nested failure")
  expect_identical(err$ledger$notices$warnings[[2]]$message, "outer pipeline warning")
  expect_identical(err$ledger$notices$messages[[1]]$message, "outer pipeline message\n")
})

test_that("sample attributes and valid factor/fixed-x domains survive; altered domains and child drops refuse", {
  d <- outcome_data()
  attr(d, "provenance") <- "existing stored fixture"
  fit <- fit_sem(outcome_model, d, n_starts = 1L, fixed_x = TRUE)
  res <- mbco_sem(fit, "a1", "b1")
  expect_true(is.finite(unname(res$statistic)))
  expect_identical(.sem_node_sample(res$ledger$children[[1]], res$ledger), fit@data)
  altered <- fit
  altered@diagnostics$ledger$context$domain$information <- "expected"
  expect_error(mbco_sem(altered, "a1", "b1"), class = "medfit_error_ledger")
  union <- fit_sem(outcome_union, d, n_starts = 1L)
  # Finite child evidence must agree with the objective of the union winner.
  altered <- union
  altered@diagnostics$ledger$children[[1]]$likelihood$f <- union@f - 1
  expect_error(mbco_sem(altered, "a1", "b1"), class = "medfit_error_ledger")
  altered <- union
  for (i in seq_along(altered@diagnostics$ledger$children)) {
    altered@diagnostics$ledger$children[[i]]$likelihood$f <- union@f + i
  }
  expect_error(mbco_sem(altered, "a1", "b1"), class = "medfit_error_ledger")
  altered <- union
  altered@diagnostics$ledger$children <- altered@diagnostics$ledger$children[2]
  altered@diagnostics$ledger$enumeration$required <- 1L
  expect_error(mbco_sem(altered, "a1", "b1"), class = "medfit_error_ledger")
  d$group <- factor(d$repetition > mean(d$repetition))
  model <- paste(outcome_model, "repetition ~ group", "a1*b1 == 0", sep = "\n")
  factor_fit <- fit_sem(model, d, n_starts = 1L)
  expect_identical(factor_fit@diagnostics$ledger$context$domain$factors, factor_fit@internals$factors)
  expect_true(is.finite(unname(mbco_sem(factor_fit, "a1", "b1")$statistic)))
})

test_that("the 0.14.0 refit settings are recorded in the ledger and agree with the fit", {
  d <- outcome_data()
  fit <- fit_sem(outcome_model, d, n_starts = 1L, fixed_x = "x", meanstructure = TRUE)
  dom <- fit@diagnostics$ledger$context$domain
  expect_identical(dom$fixed_x, fit@internals$fixed_x)
  expect_true(dom$meanstructure)
  res <- mbco_sem(fit, "a1", "b1")
  for (node in res$ledger$children[-1]) {
    expect_identical(node$context$domain$fixed_x, fit@internals$fixed_x)
    expect_true(node$context$domain$meanstructure)
  }
})

test_that("compare_lr() carries the ledger of an unresolved reference", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    if (endsWith(model, "a1 == 0")) no_conv("planted refit failure")
    real(model, ...)
  })
  ref <- suppressWarnings(medfit:::.lr_reference(fit, c("a1", "b1")))
  expect_false(ref$accepted)
  expect_true(is.na(ref$lr))
  expect_identical(ref$ledger$outcome, "unresolved")
  expect_identical(ref$ledger$children[[2]]$outcome, "unresolved")
  expect_identical(ref$ledger$children[[3]]$outcome, "resolved")
})

test_that("a refused ledger raised inside an MBCO refit keeps its class and is not an unresolved row", {
  fit <- fit_sem(outcome_model, outcome_data(), n_starts = 1L)
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) medfit:::.sem_abort_ledger("planted refusal", NULL))
  err <- tryCatch(mbco_sem(fit, "a1", "b1"), error = identity)
  expect_s3_class(err, "medfit_error_ledger")
  expect_false(inherits(err, "medfit_error_no_convergence"))
})

test_that("error messages keep their pre-ledger text when notices preceded the error; notices live in the ledger", {
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed) && parsed$constraints$lhs[1] == "a1") {
      warning("notice a1")
      message("message a1")
      no_conv("blocked a1")
    }
    real(..., parsed = parsed)
  })
  err <- tryCatch(fit_sem(outcome_union, outcome_data(), n_starts = 1L), error = identity)
  expected <- sprintf(
    paste0("%d of %d zero-product branches did not converge, so the constrained optimum is not certified ",
           "(the best of the other branches has discrepancy %s):\n  %s"),
    1L, 2L, format(err$best_survivor$f, digits = 8), "a1 == 0: blocked a1"
  )
  expect_identical(conditionMessage(err), expected)
  bad <- err$ledger$children[[1]]
  expect_identical(bad$notices$warnings[[1]]$message, "notice a1")
  expect_identical(bad$notices$messages[[1]]$message, "message a1\n")
  # an ordinary fit error, with notices raised before it
  testthat::local_mocked_bindings(.sem_fit_pipeline = function(...) {
    warning("early warning")
    message("early message")
    stop("pipeline blocked", call. = FALSE)
  })
  full <- tryCatch(fit_sem(outcome_model, outcome_data(), n_starts = 1L), error = identity)
  expect_identical(conditionMessage(full), "pipeline blocked")
  expect_identical(full$ledger$notices$warnings[[1]]$message, "early warning")
  expect_identical(full$ledger$notices$messages[[1]]$message, "early message\n")
})

test_that("a 64-branch ledger stores the sample once and serializes near the size of the data", {
  d <- outcome_data()
  big <- d[rep(seq_len(nrow(d)), length.out = 40000L), ]
  syntax <- paste(outcome_model, paste(rep("a1*b1 == 0", 6L), collapse = "\n"), sep = "\n")
  fit <- fit_sem(syntax, big, n_starts = 1L)
  led <- fit@diagnostics$ledger
  data_size <- length(serialize(fit@data, NULL))
  expect_lt(length(serialize(led, NULL)), 3 * data_size)
  expect_true(is.data.frame(led$context[["sample"]]))
  expect_true(all(vapply(led$children, function(x) is.null(x$context[["sample"]]), TRUE)))
  # every consumer still resolves a child's sample, and the ledger stays valid
  expect_true(.sem_valid_outcome(led))
  for (child in led$children) expect_identical(.sem_node_sample(child, led), fit@data)
  res <- mbco_sem(fit, "a1", "b1")
  expect_lt(length(serialize(res$ledger, NULL)), 4 * data_size)
  expect_identical(.sem_node_sample(res$ledger$children[[2]], res$ledger), fit@data)
  expect_identical(.sem_node_sample(res$ledger$children[[2]]$children[[1]], res$ledger), fit@data)
  # a child whose digest does not match the root sample is refused
  forged <- fit
  forged@diagnostics$ledger$children[[3]]$context$sample_hash <- "forged"
  expect_false(.sem_valid_outcome(forged@diagnostics$ledger))
  expect_error(mbco_sem(forged, "a1", "b1"), class = "medfit_error_ledger")
  other <- fit
  other@diagnostics$ledger$children[[3]]$context$sample_hash <- rlang::hash(big[-1, ])
  expect_error(mbco_sem(other, "a1", "b1"), class = "medfit_error_ledger")
})

test_that("forged, mismatched or missing sample digests are refused and never resolve to the root sample", {
  d <- outcome_data()
  fit <- fit_sem(outcome_union, d, n_starts = 1L)
  led <- fit@diagnostics$ledger
  # structure first: two children, both hold only a digest, the root holds the sample
  expect_identical(vapply(led$children, `[[`, "", "id"), c("fit/branch:1", "fit/branch:2"))
  expect_true(all(vapply(led$children, function(x) is.null(x$context[["sample"]]), TRUE)))
  expect_identical(.sem_node_sample(led$children[[1]], led), fit@data)
  forgeries <- list(
    wrong_digest = function(l) {
      l$children[[2]]$context$sample_hash <- "forged"
      l
    },
    other_sample = function(l) {
      l$children[[1]]$context$sample_hash <- rlang::hash(d[-1, ])
      l
    },
    root_sample_removed = function(l) {
      l$context[["sample"]] <- NULL
      l
    },
    no_sample_no_hash = function(l) {
      l$children[[1]]$context$sample_hash <- NULL
      l
    },
    root_digest_tampered = function(l) {
      l$context$sample_hash <- "forged"
      l
    },
    child_other_rows = function(l) {
      l$children[[1]]$context[["sample"]] <- d[-1, ]
      l
    }
  )
  for (nm in names(forgeries)) {
    altered <- fit
    altered@diagnostics$ledger <- forgeries[[nm]](led)
    expect_false(.sem_valid_outcome(altered@diagnostics$ledger), label = nm)
    expect_error(mbco_sem(altered, "a1", "b1"), class = "medfit_error_ledger")
  }
  # the resolver itself never hands back the root sample for a digest that does not match it
  bad <- led$children[[1]]
  bad$context$sample_hash <- "forged"
  expect_null(.sem_node_sample(bad, led))
  bad$context$sample_hash <- NULL
  expect_null(.sem_node_sample(bad, led))
})
