# D3, reconciled with ADR D-11 and D-12 and the P1/P2 ledger: every node that carries zero-product rows retains
# `branch_map` (raw count, parser factor counts, structural restriction-set IDs, unique count) in its `$ledger`
# node. Execution is unchanged: all raw rows are fitted in their original order, ties go to the first. The 64-raw
# cap is checked with overflow-safe arithmetic before the grid is allocated; the over-cap node is `not_enumerated`
# and keeps its plain error (message text only gains non-scientific, 2^53-approximate and overflow wording).
# Stored data and injected objectives only; injected values are control payloads, not scientific results.
d3_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
d3_data <- function() readRDS(testthat::test_path("fixtures", "memory_exp.rds"))

test_that("raw cardinality is bounded before enumeration", {
  for (n in c(63L, 64L, 65L)) expect_equal(.sem_raw_count(n), n)
  expect_identical(.sem_raw_count(rep(2L, 2000L)), Inf)
  expect_error(.sem_raw_count(c(2L, 0L)), "positive")
  expect_identical(.sem_raw_count(c(7L, 9L)), 63L)
  expect_identical(.sem_raw_count(c(8L, 8L)), 64L)
  expect_identical(.sem_raw_count(c(5L, 13L)), 65L)
  expect_identical(.sem_raw_count(c(8L, 9L)), 72L)
  expect_identical(.sem_raw_count(rep(2L, 40L)), 2^40)
})

test_that("parsed 32/64/128 grids preserve execution, ties and fail before fitting", {
  model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
  data <- readRDS(testthat::test_path("fixtures", "memory_exp.rds"))
  payload <- .sem_fit_syntax(model, data, "expected", 1L, list(), NULL, "model")
  state <- new.env(parent = emptyenv())
  state$seen <- list()
  varying <- FALSE
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    state$seen[[length(state$seen) + 1L]] <- parsed$constraints$lhs
    out <- payload
    if (varying) out$f <- c(4, 1, 3, 2)[(length(state$seen) - 1L) %% 4L + 1L]
    out$constraints <- parsed$constraints
    out$ledger <- .sem_outcome(payload$ledger$context, parsed$constraints, result = out)
    out
  })
  for (n in c(5L, 6L)) {
    state$seen <- list()
    parsed <- .sem_parse(paste(model, paste(rep("a1*b1 == 0", n), collapse = "\n"), sep = "\n"))
    products <- .sem_zero_product_rows(parsed$constraints)
    fit <- .sem_fit_branches(parsed, products, data, "expected", 1L, list(), NULL, "model")
    expect_length(state$seen, 2^n)
    expected <- expand.grid(rep(list(c("a1", "b1")), n), stringsAsFactors = FALSE)
    expect_identical(state$seen, lapply(seq_len(nrow(expected)), function(i) unname(unlist(expected[i, ]))))
    expect_identical(state$seen[[1L]], rep("a1", n))
    expect_identical(fit$branch, rep("a1 == 0", n))
    expect_identical(fit$f, payload$f)
    expect_identical(fit$ledger$branch_map$unique_count, 3L)
    expect_true(.sem_valid_outcome(fit$ledger))
    for (field in names(fit$ledger$branch_map)) {
      bad <- fit$ledger
      bad$branch_map[[field]] <- "forged"
      expect_false(.sem_valid_outcome(bad))
    }
  }
  varying <- TRUE
  state$seen <- list()
  parsed <- .sem_parse(paste(model, "a1*b1 == 0\na1*b1 == 0", sep = "\n"))
  fit <- .sem_fit_branches(parsed, .sem_zero_product_rows(parsed$constraints),
                           data, "expected", 1L, list(), NULL, "model")
  expect_identical(fit$f, 1)
  expect_identical(fit$branch, c("b1 == 0", "a1 == 0"))
  expect_true(.sem_valid_outcome(fit$ledger))
  # Rows 2 and 3 encode the same mixed restriction set and tie below row 1.
  local({
    testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
      args <- list(...)
      expect_identical(args, list(NULL, data, "expected", 1L, list(), NULL, "model",
                                  meanstructure = NULL, fixed_x = FALSE, factors = NULL))
      out <- payload
      out$f <- c(4, 1, 1, 2)[state$index]
      state$index <- state$index + 1L
      out$constraints <- parsed$constraints
      expect_identical(out$constraints$rhs, c("0", "0"))
      out$ledger <- .sem_outcome(payload$ledger$context, parsed$constraints, result = out)
      out
    })
    state$index <- 1L
    tied <- .sem_fit_branches(parsed, .sem_zero_product_rows(parsed$constraints),
                              data, "expected", 1L, list(), NULL, "model")
    expect_identical(tied$branch, c("b1 == 0", "a1 == 0"))
    expect_identical(tied$f, 1)
    expect_identical(tied$ledger$branch_map$raw_to_canonical[2L],
                     tied$ledger$branch_map$raw_to_canonical[3L])
  })
  testthat::local_mocked_bindings(.sem_branch_grid = function(...) stop("grid must not be allocated"))
  for (n in c(7L, 40L, 60L, 2000L)) {
    state$seen <- list()
    parsed <- .sem_parse(paste(model, paste(rep("a1*b1 == 0", n), collapse = "\n"), sep = "\n"))
    err <- tryCatch(.sem_fit_branches(parsed, .sem_zero_product_rows(parsed$constraints),
                                      data, "expected", 1L, list(), NULL, "model"), error = identity)
    expect_s3_class(err, "error")
    expect_false(inherits(err, "medfit_error_ledger"))
    expect_length(state$seen, 0L)
    expect_identical(err$ledger$enumeration$state, "not_enumerated")
    expect_length(err$ledger$children, 0L)
    expect_null(err$ledger$branch_map$raw_to_canonical)
    count <- if (n == 7L) 128L else if (n == 40L) 2^40 else if (n == 60L) 2^60 else Inf
    expect_identical(err$ledger$enumeration$required, count)
    expect_identical(err$ledger$branch_map$raw_count, count)
    text <- switch(as.character(n), "7" = "128", "40" = "1099511627776",
                   "60" = "approximately 1152921504606846976", "2000" = "overflow (Inf)")
    expected_message <- paste0("the zero-product constraints give ", text,
                               " branches to fit; at most 64 are supported")
    expect_identical(conditionMessage(err), expected_message)
  }
})

test_that("public fit and nested MBCO retain maps and refuse forged evidence", {
  model <- paste("repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery",
                 "a1*b1 == 0\na1*b1 == 0", sep = "\n")
  data <- readRDS(testthat::test_path("fixtures", "memory_exp.rds"))
  fit <- fit_sem(model, data, n_starts = 1L)
  map <- fit@diagnostics$ledger$branch_map
  expect_identical(map$state, "complete")
  expect_identical(map$raw_count, 4L)
  expect_identical(map$factor_counts, c(2L, 2L))
  expect_identical(map$unique_count, 3L)
  expect_identical(map$raw_to_canonical,
                   c("11:2:a12:==1:0", "11:2:a12:==1:011:2:b12:==1:0",
                     "11:2:a12:==1:011:2:b12:==1:0", "11:2:b12:==1:0"))
  result <- mbco_sem(fit, "a2", "cp", n_starts = 1L)
  expect_true(is.finite(result$p.value))
  root <- result$ledger
  root_ref <- list(context = list(sample = root$context[["sample"]]), hash = rlang::hash(root$context[["sample"]]))
  nodes <- root$children
  expect_length(nodes, 3L)
  expect_identical(nodes[[1L]]$branch_map, map)
  for (i in seq_along(nodes)) {
    node <- nodes[[i]]
    expect_identical(node$id, if (i == 1L) "mbco/full" else paste0("mbco/null:", i - 1L))
    expect_identical(node$branch_map$raw_count, 4L)
    expect_identical(node$branch_map$factor_counts, c(2L, 2L))
    expect_identical(node$branch_map$unique_count, 3L)
    expect_length(node$branch_map$raw_to_canonical, 4L)
    expect_identical(node$branch_map$raw_to_canonical[2L], node$branch_map$raw_to_canonical[3L])
    expect_identical(node$likelihood$f, min(vapply(node$children, function(x) x$likelihood$f, 0)))
    expect_true(.sem_valid_outcome(node, node$id, "mbco", root_ref))
    for (j in seq_along(node$children)) {
      child <- node$children[[j]]
      expect_identical(child$id, paste0(node$id, "/branch:", j))
      expect_identical(child$parent_id, node$id)
      expect_null(child$branch_map)
    }
  }
  for (field in names(map)) {
    bad <- fit
    bad@diagnostics$ledger$branch_map[[field]] <- "forged"
    expect_error(mbco_sem(bad, "a2", "cp", n_starts = 1L), class = "medfit_error_ledger")
  }
  bad <- fit
  bad@diagnostics$ledger$children[[1L]]$branch_map <- list(state = "complete")
  expect_error(mbco_sem(bad, "a2", "cp", n_starts = 1L), class = "medfit_error_ledger")
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    out <- real(model, ...)
    if (!is.null(model) && endsWith(model, "\na2 == 0")) out$ledger$branch_map$unique_count <- 999L
    out
  })
  err <- tryCatch(mbco_sem(fit, "a2", "cp", n_starts = 1L), error = identity)
  expect_s3_class(err, "medfit_error_ledger")
  expect_null(err$p.value)
  expect_identical(err$ledger$rejected_evidence$branch_map$unique_count, 999L)
})

test_that("duplicate mappings are structural and permutation stable", {
  cons <- data.frame(lhs = c("a*b", "b*a"), op = "==", rhs = "0")
  map <- .sem_branch_map(cons)
  expect_identical(map$raw_count, 4L)
  expect_identical(map$unique_count, 3L)
  expect_identical(map$raw_to_canonical[1L], map$raw_to_canonical[4L])
  flipped <- cons[2:1, , drop = FALSE]
  expect_setequal(.sem_branch_map(flipped)$raw_to_canonical, map$raw_to_canonical)
  cons$lhs <- c("a*a*b", "a*b")
  expect_identical(.sem_branch_map(cons)$raw_count, 4L)
  large <- cons[rep(1L, 7L), , drop = FALSE]
  expect_identical(.sem_branch_map(large)$raw_count, 128L)
  expect_null(.sem_branch_map(large)$raw_to_canonical)
  expect_identical(.sem_branch_map(large)$state, "not_enumerated")
  single <- cons[1L, , drop = FALSE]
  single$lhs <- "a*b"
  original <- .sem_branch_map(single)
  single$lhs <- "b*a"
  reversed <- .sem_branch_map(single)
  expect_identical(reversed$raw_to_canonical, rev(original$raw_to_canonical))
  expect_identical(reversed$unique_count, original$unique_count)
  # Similar-looking digit-bearing labels must not collapse to one ID.
  single$lhs <- "a1*a11"
  expect_identical(.sem_branch_map(single)$unique_count, 2L)
  expect_length(unique(.sem_branch_map(single)$raw_to_canonical), 2L)
  overlap <- data.frame(lhs = c("a*b", "a*c"), op = "==", rhs = "0")
  expect_identical(.sem_branch_map(overlap)$unique_count, 4L)
})

test_that("mapping parse failures retain the original typed error", {
  cons <- data.frame(lhs = "a*", op = "==", rhs = "0")
  original <- simpleError("original fitting failure")
  node <- .sem_outcome(NULL, cons, error = original)
  expect_identical(node$condition$message, "original fitting failure")
  expect_identical(node$branch_map$state, "unavailable")
  expect_false(.sem_valid_outcome(node))
  err <- tryCatch(.sem_abort_outcome(conditionMessage(original), node), error = identity)
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_identical(err$ledger$branch_map$state, "unavailable")
  expect_match(conditionMessage(err), "original fitting failure")
})

test_that("a map is stored once per node, survives sample compaction and is checked against the node's constraints", {
  model <- paste(d3_model, "a1*b1 == 0", sep = "\n")
  fit <- fit_sem(model, d3_data(), n_starts = 1L)
  node <- fit@diagnostics$ledger
  expect_identical(node$branch_map$raw_count, 2L)
  expect_identical(node$branch_map$unique_count, 2L)
  # children carry the sample by digest only; the map check must not need `$sample` on them
  expect_null(node$children[[1L]]$context[["sample"]])
  expect_true(.sem_valid_outcome(node))
  # a map belonging to other constraints is refused, even when it is itself well formed
  other <- node
  other$branch_map <- .sem_branch_map(data.frame(lhs = c("a1*b1", "a2*b2"), op = "==", rhs = "0"))
  expect_false(.sem_valid_outcome(other))
  # a node without zero-product rows has no map, and a forged one is refused
  plain <- fit_sem(d3_model, d3_data(), n_starts = 1L)@diagnostics$ledger
  expect_null(plain$branch_map)
  plain$branch_map <- node$branch_map
  expect_false(.sem_valid_outcome(plain))
})

test_that("over-cap refusal is decided by the raw count alone and never runs the literal check", {
  # D3 decision for the author: the cap is a property of the raw grid, so a model over 64 raw rows is refused even
  # when a literal zero/nonzero contradiction (D2) would have excluded branches. No certificate is built, no
  # branch is fitted and the ledger carries the not-enumerated map.
  fits <- 0L
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(..., parsed = NULL) {
    if (!is.null(parsed)) fits <<- fits + 1L
    real(..., parsed = parsed)
  })
  certs <- 0L
  real_cert <- .sem_literal_zero_certificate
  testthat::local_mocked_bindings(.sem_literal_zero_certificate = function(...) {
    certs <<- certs + 1L
    real_cert(...)
  })
  model <- paste(c(d3_model, rep("a1*b1 == 0", 7L), "a1 == 1"), collapse = "\n")
  err <- tryCatch(fit_sem(model, d3_data(), n_starts = 1L), error = identity)
  expect_match(conditionMessage(err), "give 128 branches to fit; at most 64 are supported", fixed = TRUE)
  expect_identical(fits, 0L)
  expect_identical(certs, 0L)
  expect_identical(err$ledger$enumeration, list(state = "not_enumerated", required = 128L))
  expect_identical(err$ledger$branch_map$state, "not_enumerated")
  expect_identical(err$ledger$branch_map$raw_count, 128L)
  expect_length(err$ledger$children, 0L)
  expect_false(inherits(err, "medfit_sem_empty_union"))
})

test_that("the 2^53 text boundary, the 65 cap boundary and a missing map are pinned (oracle QA)", {
  # exactness is claimed up to and including 2^53; the first double above it is the first "approximately"
  expect_identical(.sem_raw_count_text(2^53), "9007199254740992")
  expect_identical(.sem_raw_count_text(.sem_raw_count(rep(2L, 53L))), "9007199254740992")
  expect_identical(.sem_raw_count_text(2^53 + 2), "approximately 9007199254740994")
  expect_identical(.sem_raw_count_text(2^54), "approximately 18014398509481984")
  expect_identical(.sem_raw_count_text(2^64), "approximately 18446744073709551616")
  expect_identical(.sem_raw_count_text(2^31), "2147483648")
  expect_identical(.sem_raw_count_text(Inf), "overflow (Inf)")
  expect_false(grepl("[0-9]e[+-]?[0-9]", .sem_raw_count_text(.Machine$double.xmax)))
  # the cap: 65 raw rows are refused (parser products carry at most five labels here, so the grid is posed directly),
  # (the 64 side is the 2^6 grid above); nothing is fitted for 65
  parsed <- .sem_parse(d3_model)
  posed <- function(counts) {
    lapply(seq_along(counts), function(j) list(row = j, factors = paste0("f", seq_len(counts[j]))))
  }
  fits <- 0L
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    fits <<- fits + 1L
    stop("must not fit")
  })
  err <- tryCatch(.sem_fit_branches(parsed, posed(c(5L, 13L)), d3_data(), "expected", 1L, list(), NULL, "model"),
                  error = identity)
  expect_identical(conditionMessage(err),
                   "the zero-product constraints give 65 branches to fit; at most 64 are supported")
  expect_identical(err$ledger$enumeration, list(state = "not_enumerated", required = 65L))
  expect_identical(fits, 0L)
})

test_that("a zero-product ledger without its map is refused, by the validator and by mbco_sem()", {
  # a ledger saved by a dev build between P1 and P3 has no `branch_map`; v0.14.0 has no ledger at all
  fit <- fit_sem(paste(d3_model, "a1*b1 == 0", sep = "\n"), d3_data(), n_starts = 1L)
  expect_true(.sem_valid_outcome(fit@diagnostics$ledger))
  legacy <- fit
  legacy@diagnostics$ledger["branch_map"] <- list(NULL)
  expect_false("branch_map" %in% names(legacy@diagnostics$ledger) && !is.null(legacy@diagnostics$ledger$branch_map))
  expect_false(.sem_valid_outcome(legacy@diagnostics$ledger))
  expect_error(mbco_sem(legacy, "a2", "cp", n_starts = 1L), class = "medfit_error_ledger")
  # a node without products needs no map, with or without the slot
  plain <- fit_sem(d3_model, d3_data(), n_starts = 1L)@diagnostics$ledger
  plain["branch_map"] <- NULL
  expect_true(.sem_valid_outcome(plain))
})
