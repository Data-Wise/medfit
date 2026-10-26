# D2, reconciled with ADR D-11 and D-12 and the P1 ledger: a literal zero/nonzero contradiction is a syntax proof
# (an explicit `label == 0` and an explicit finite nonzero literal equality on the same parsed label). No tolerance,
# solver status or numerical rank is ever the proof. A certified-empty zero-product branch is retained in the ledger
# (outcome `excluded`, likelihood unavailable) and skipped; a union returns only if at least one branch resolves and
# every other branch resolves or carries a valid certificate. The failures stay `medfit_error_no_convergence` (D-11),
# with the typed subclasses `medfit_sem_infeasible` and `medfit_sem_empty_union` and the evidence in `$ledger`.
# Stored data and injected errors only; no generated samples.
d2_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
d2_data <- function() readRDS(testthat::test_path("fixtures", "memory_exp.rds"))
d2_mutate <- function(fun, old, new) {
  code <- paste(deparse(body(fun), width.cutoff = 500L), collapse = "\n")
  stopifnot(grepl(old, code, fixed = TRUE))
  body(fun) <- parse(text = sub(old, new, code, fixed = TRUE))[[1L]]
  fun
}

test_that("literal certificates distinguish exact contradiction from unknown constraints", {
  p <- .sem_parse(paste(d2_model, "a1 == 1\na1 == 0", sep = "\n"))
  cert <- .sem_literal_zero_certificate(p$parameters, p$constraints)
  expect_identical(cert$method, "literal_zero_nonzero")
  expect_identical(cert$label, "a1")
  expect_equal(cert$nonzero$value, 1)
  for (con in c("a1 == 0", "a1 == b1\na1 == 0", "a1 + b1 == 1\na1 == 0",
                "a1 > 1\na1 == 0", "a1 == 1e-999\na1 == 0")) {
    p <- .sem_parse(paste(d2_model, con, sep = "\n"))
    expect_null(.sem_literal_zero_certificate(p$parameters, p$constraints))
  }
  # Equality direction, finite signed/scientific literals and exact zero only: a tiny nonzero is nonzero.
  for (con in c("1 == a1\n0 == a1", "a1 == -1e-12\na1 == -0.0")) {
    p <- .sem_parse(paste(d2_model, con, sep = "\n"))
    expect_identical(.sem_literal_zero_certificate(p$parameters, p$constraints)$label, "a1")
  }
  p <- .sem_parse(paste(d2_model, "a1 == 0", sep = "\n"))
  p$parameters$fixed[p$parameters$label == "a1"] <- 1
  # Public syntax cannot label a fixed coefficient: mutable table values are not proof premises.
  expect_null(.sem_literal_zero_certificate(p$parameters, p$constraints))
  expect_null(.sem_literal_zero_certificate(p$parameters, p$constraints[FALSE, ]))
  # malformed evidence is unknown, without a warning
  expect_warning(expect_null(.sem_literal_zero_certificate(NULL, p$constraints)), NA)
})

test_that("a certified-empty union branch is retained, skipped and publicly validated", {
  real <- .sem_fit_syntax
  calls <- character()
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed)) calls <<- c(calls, parsed$constraints$lhs[1])
    real(..., parsed = parsed)
  })
  model <- paste(d2_model, "a1*b1 == 0\na1 == 1", sep = "\n")
  fit <- fit_sem(model, d2_data(), n_starts = 1L)
  sibling <- fit_sem(paste(d2_model, "b1 == 0\na1 == 1", sep = "\n"), d2_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  expect_identical(calls, "b1") # the a1 branch never reached the optimizer
  expect_identical(node$outcome, "resolved")
  expect_identical(node$children[[1]]$outcome, "excluded")
  expect_identical(node$children[[1]]$feasibility, "certified_empty")
  expect_identical(node$children[[1]]$likelihood$state, "unavailable")
  expect_identical(node$children[[1]]$certificate$label, "a1")
  expect_identical(fit@internals$branch, "b1 == 0")
  expect_equal(fit@f, sibling@f, tolerance = 1e-12)
  expect_true(.sem_valid_outcome(node))
  # P1's storage: the sample lives on the root; a child on the same rows carries its digest only
  expect_true(is.data.frame(node$context[["sample"]]))
  expect_null(node$children[[1]]$context[["sample"]])
  expect_identical(.sem_node_sample(node$children[[1]], node), node$context[["sample"]])
  for (field in c("certificate", "constraints", "parameters", "digest")) {
    bad <- node
    if (field == "certificate") bad$children[[1]]$certificate$nonzero$value <- 2
    if (field == "constraints") bad$children[[1]]$constraints$rhs[2] <- "0"
    if (field == "parameters") bad$children[[1]]$context$model$parameters$fixed[1] <- 7
    if (field == "digest") bad$children[[1]]$context$sample_hash <- "forged"
    expect_false(.sem_valid_outcome(bad))
  }
  # This top-level a1 = 0 null is an all-empty union: an unresolved row (#300), never a successful leaf fit.
  expect_warning(res <- mbco_sem(fit, "a1", "b1"), "The MBCO statistic is not available")
  expect_s3_class(res, "mbco_sem")
  expect_true(res$unresolved)
  expect_true(is.na(res$p.value))
  expect_true(is.na(res$statistic))
  expect_match(res$tests$note[1], "a1 == 0", fixed = TRUE)
  null <- res$ledger$children[[2]]
  expect_identical(null$id, "mbco/null:1")
  expect_identical(null$parent_id, "mbco")
  expect_identical(null$context$model$syntax, paste0(model, "\na1 == 0"))
  expect_identical(null$outcome, "unresolved")
  expect_identical(null$likelihood, list(state = "unavailable", f = NA_real_))
  expect_identical(null$enumeration, list(state = "complete", required = 2L))
  expect_length(null$children, 2L)
  for (i in seq_len(2L)) {
    child <- null$children[[i]]
    expect_identical(child$id, paste0("mbco/null:1/branch:", i))
    expect_identical(child$parent_id, "mbco/null:1")
    expect_true(.sem_valid_exclusion(child))
    expect_identical(child$certificate$label, "a1")
  }
  # Intended assertions fail for a wrong node, missing proof, or a dropped branch.
  expect_failure(expect_identical(res$ledger$children[[1]]$id, "mbco/null:1"))
  bad <- null$children[[1]]
  bad$certificate <- NULL
  expect_failure(expect_true(.sem_valid_exclusion(bad)))
  bad <- null
  bad$children <- bad$children[-1L]
  expect_failure(expect_length(bad$children, 2L))
  # Other nulls retain the nested exclusion without weakening their LR gates.
  nested <- mbco_sem(fit, "a2", "cp")
  expect_true(is.finite(nested$p.value))
  for (i in seq_len(2L)) {
    parent <- nested$ledger$children[[i + 1L]]
    child <- parent$children[[1]]
    expect_identical(parent$id, paste0("mbco/null:", i))
    expect_identical(child$id, paste0(parent$id, "/branch:1"))
    expect_identical(child$parent_id, parent$id)
    expect_true(.sem_valid_exclusion(child))
  }
})

test_that("all-empty unions fail typed (still no_convergence) and feasible or unknown branches are never certified", {
  empty <- paste(d2_model, "a1*b1 == 0\na1 == 1\nb1 == 1", sep = "\n")
  testthat::local_mocked_bindings(.sem_optimize = function(...) stop("optimizer must not run"))
  err <- tryCatch(fit_sem(empty, d2_data(), n_starts = 1L), error = identity)
  expect_s3_class(err, "medfit_sem_empty_union")
  expect_s3_class(err, "medfit_error_no_convergence") # D-11: the class mbco_sem() and compare_lr() catch
  expect_match(conditionMessage(err), "no branch of the zero-product constraints converged")
  expect_false(grepl("Retained notices", conditionMessage(err), fixed = TRUE)) # notices live in the ledger only
  expect_true(all(vapply(err$ledger$children, function(x) x$feasibility == "certified_empty", TRUE)))
  expect_true(all(vapply(err$ledger$children, .sem_valid_exclusion, TRUE)))
  expect_null(err$best_survivor)
  expect_null(err$p.value)
  for (con in c("a1*b1 == 0", "a1*b1 == 0\na1 + b1 == 1")) {
    err <- tryCatch(fit_sem(paste(d2_model, con, sep = "\n"), d2_data(), n_starts = 1L), error = identity)
    expect_s3_class(err, "medfit_error_no_convergence")
    expect_true(all(vapply(err$ledger$children, function(x) x$feasibility == "unknown", TRUE)))
    expect_false(inherits(err, "medfit_sem_empty_union"))
  }
})

test_that("either branch ordering excludes only an exact proof and preserves the survivor", {
  for (product in c("a1*b1", "b1*a1")) {
    fit <- fit_sem(paste(d2_model, paste(product, "== 0"), "a1 == 1", sep = "\n"),
                   d2_data(), n_starts = 1L)
    children <- fit@diagnostics$ledger$children
    expect_equal(sum(vapply(children, .sem_valid_exclusion, TRUE)), 1)
    expect_identical(fit@internals$branch, "b1 == 0")
    expect_true(.sem_valid_outcome(fit@diagnostics$ledger))
  }
})

test_that("a skipped non-certified branch next to a certified one is still an error, never a partial fit", {
  real <- .sem_fit_syntax
  # branches: a1 == 0 (certified empty by a1 == 1), b1 == 0 (injected solver failure): no survivor stands alone
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed) && parsed$constraints$lhs[1] == "b1") .sem_no_convergence("injected failure")
    real(..., parsed = parsed)
  })
  err <- tryCatch(fit_sem(paste(d2_model, "a1*b1 == 0\na1 == 1", sep = "\n"), d2_data(), n_starts = 1L),
                  error = identity)
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_false(inherits(err, "medfit_sem_empty_union")) # a failure is unknown, not a proof
  expect_identical(vapply(err$ledger$children, `[[`, "", "feasibility"), c("certified_empty", "unknown"))
  expect_null(err$best_survivor)
})

test_that("ordinary infeasible fits fail typed before any optimizer call", {
  testthat::local_mocked_bindings(.sem_optimize = function(...) stop("optimizer must not run"))
  err <- tryCatch(fit_sem(paste(d2_model, "a1 == 1\na1 == 0", sep = "\n"),
                          d2_data(), n_starts = 1L), error = identity)
  expect_s3_class(err, "medfit_sem_infeasible")
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_true(.sem_valid_exclusion(err$ledger))
  expect_identical(err$ledger$certificate$label, "a1")
  expect_null(err$p.value)
})

test_that("a tolerance or a solver status substituted for the literal proof fails the intended controls", {
  model <- paste(d2_model, "a1*b1 == 0\na1 == 1", sep = "\n")
  fit <- fit_sem(model, d2_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  forged <- node
  forged$children[[1]]$certificate <- NULL
  expect_false(.sem_valid_outcome(forged))
  # (1) unknown-as-empty validator: a node without proof would be accepted
  local({
    testthat::local_mocked_bindings(.sem_valid_exclusion = function(x) identical(x$outcome, "excluded"))
    expect_failure(expect_false(.sem_valid_outcome(forged)))
  })
  # (2) without the proof, a genuinely contradictory branch cannot be dropped as unknown
  local({
    testthat::local_mocked_bindings(.sem_literal_zero_certificate = function(...) NULL)
    expect_error(fit_sem(model, d2_data(), n_starts = 1L), class = "medfit_error_no_convergence")
  })
  # (3) a tolerance for exact zero: -1e-12 would count as zero and the contradiction is lost
  local({
    p <- .sem_parse(paste(d2_model, "a1 == -1e-12\na1 == -0.0", sep = "\n"))
    expect_identical(.sem_literal_zero_certificate(p$parameters, p$constraints)$label, "a1")
    tol <- d2_mutate(.sem_literal_zero_certificate, "x$value == 0", "abs(x$value) < 1e-8")
    tol <- d2_mutate(tol, "x$value != 0", "abs(x$value) >= 1e-8")
    expect_null(tol(p$parameters, p$constraints))
    expect_failure(expect_identical(tol(p$parameters, p$constraints)$label, "a1"))
  })
  # (4) a solver status for the proof: a failed branch declared empty turns an error into a returned minimum
  local({
    real <- .sem_fit_syntax
    cert <- .sem_literal_zero_certificate
    testthat::local_mocked_bindings(
      .sem_fit_syntax = function(..., parsed = NULL) {
        if (!is.null(parsed) && parsed$constraints$lhs[1] == "b1") .sem_no_convergence("injected failure")
        real(..., parsed = parsed)
      }
    )
    unmutated <- function() fit_sem(paste(d2_model, "a1*b1 == 0", sep = "\n"), d2_data(), n_starts = 1L)
    expect_error(unmutated(), class = "medfit_error_no_convergence")
    testthat::local_mocked_bindings(.sem_literal_zero_certificate = function(parameters, constraints) {
      cert(parameters, constraints) %||% if (constraints$lhs[1] == "b1") {
        list(method = "literal_zero_nonzero", label = "b1")
      }
    })
    expect_failure(expect_error(unmutated(), class = "medfit_error_no_convergence"))
  })
})

test_that("consistent parameter forgery cannot supply a contradiction premise", {
  fit <- fit_sem(paste(d2_model, "a1*b1 == 0", sep = "\n"), d2_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  node$context$model$parameters$fixed[node$context$model$parameters$label == "a1"] <- 1
  for (i in seq_along(node$children)) node$children[[i]]$context$model$parameters <- node$context$model$parameters
  child <- node$children[[1]]
  fake <- list(method = "literal_zero_nonzero", label = "a1",
               zero = list(label = "a1", value = 0, source = "constraint", row = 1L),
               nonzero = list(label = "a1", value = 1, source = "parameter", row = 1L))
  excluded <- .sem_excluded_outcome(child$context, child$constraints, fake)
  node$children[[1]] <- .sem_rebase_outcome(excluded, "fit/branch:1", "fit")
  node$likelihood$f <- node$children[[2]]$likelihood$f
  expect_false(.sem_valid_exclusion(node$children[[1]]))
  expect_false(.sem_valid_outcome(node))
})

test_that("a forged resolved parent with only excluded children refuses without warnings", {
  fit <- fit_sem(paste(d2_model, "a1*b1 == 0\na1 == 1", sep = "\n"), d2_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  node$constraints <- .sem_parse(paste(d2_model, "a1*b1 == 0\na1 == 1\nb1 == 1", sep = "\n"))$constraints
  node$children <- lapply(seq_len(2L), function(i) {
    cons <- node$constraints
    cons$lhs[1] <- c("a1", "b1")[i]
    proof <- .sem_literal_zero_certificate(node$context$model$parameters, cons)
    excluded <- .sem_excluded_outcome(node$context, cons, proof)
    .sem_rebase_outcome(excluded, paste0("fit/branch:", i), "fit")
  })
  expect_true(all(vapply(node$children, .sem_valid_exclusion, TRUE)))
  expect_warning(valid <- .sem_valid_outcome(node), NA)
  expect_false(valid)
})

# --- oracle QA additions (P2): survivors of planted defects and the compare_lr reference path ---

test_that("an underflowed literal is unknown, never a zero premise", {
  # `1e-999` parses to 0 in double precision: read as a zero it would contradict `a1 == 1`
  p <- .sem_parse(paste(d2_model, "a1 == 1e-999\na1 == 1", sep = "\n"))
  expect_null(.sem_literal_zero_certificate(p$parameters, p$constraints))
  p <- .sem_parse(paste(d2_model, "a1 == 0e0\na1 == 1", sep = "\n"))
  expect_identical(.sem_literal_zero_certificate(p$parameters, p$constraints)$label, "a1")
})

test_that("a failed branch next to a certified one and a fitted one is an error, not the fitted minimum", {
  real <- .sem_fit_syntax
  # three branches: a1 == 0 certified empty (a1 == 1), b1 == 0 injected failure, b2 == 0 fits
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed) && parsed$constraints$lhs[1] == "b1") .sem_no_convergence("injected failure")
    real(..., parsed = parsed)
  })
  err <- tryCatch(fit_sem(paste(d2_model, "a1*b1*b2 == 0\na1 == 1", sep = "\n"), d2_data(), n_starts = 1L),
                  error = identity)
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_false(inherits(err, "medfit_sem_empty_union"))
  expect_match(conditionMessage(err), "1 of 3 zero-product branches did not converge")
  expect_identical(vapply(err$ledger$children, `[[`, "", "feasibility"), c("certified_empty", "unknown", "witness"))
  expect_false(is.null(err$best_survivor))
})

test_that("an excluded node is counted resolved only with a valid proof, and every field of it is checked", {
  fit <- fit_sem(paste(d2_model, "a1*b1 == 0\na1 == 1", sep = "\n"), d2_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  good <- node$children[[1]]
  expect_true(.sem_valid_exclusion(good))
  ok <- list(converged = TRUE, f = 1, status = 1L)
  expect_identical(.sem_outcome(node$context, node$constraints, result = ok, children = list(good))$outcome,
                   "resolved")
  forged <- good
  forged$certificate <- NULL
  expect_identical(.sem_outcome(node$context, node$constraints, result = ok, children = list(forged))$outcome,
                   "unresolved")
  tamper <- list(
    schema_version = function(x) { x$schema_version <- 2L; x },
    outcome = function(x) { x$outcome <- "resolved"; x },
    feasibility = function(x) { x$feasibility <- "witness"; x },
    optimizer = function(x) { x$optimizer$state <- "accepted"; x },
    likelihood = function(x) { x$likelihood <- list(state = "available", f = 1); x },
    enumeration = function(x) { x$enumeration <- list(state = "complete", required = 1L); x },
    children = function(x) { x$children <- list(x); x }
  )
  for (field in names(tamper)) {
    expect_false(.sem_valid_exclusion(tamper[[field]](good)), info = field)
  }
})

test_that("compare_lr() treats an all-empty zero-product null as an unresolved reference, with one warning", {
  skip_if_not_installed("lavaan")
  empty <- tryCatch(fit_sem(paste(d2_model, "a1*b1 == 0\na1 == 1\nb1 == 1", sep = "\n"), d2_data(), n_starts = 1L),
                    error = identity)
  expect_s3_class(empty, "medfit_sem_empty_union")
  # compare_lr() refuses a constrained fit, so the all-empty null is the typed error a refit raises
  fit <- suppressWarnings(fit_sem(d2_model, d2_data(), n_starts = 1L, fixed_x = FALSE, meanstructure = NULL))
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) stop(empty))
  seen <- character()
  res <- withCallingHandlers(compare_lr(fit, c("a1", "b1"), engine = "lavaan"),
                             warning = function(w) {
                               seen <<- c(seen, conditionMessage(w))
                               invokeRestart("muffleWarning")
                             })
  expect_s3_class(res, "medfit_lr_comparison")
  expect_identical(res$verdict, "unresolved")
  expect_false(res$reference$accepted)
  expect_true(is.na(res$reference$lr))
  expect_length(seen, 1L)
  expect_match(seen, "literal zero/nonzero contradiction", fixed = TRUE)
})
