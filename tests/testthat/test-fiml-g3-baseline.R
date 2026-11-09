# FI-G3 slice S0: frozen pre-serial baseline (spec V13/V14, rules R2 and R4). Two fixtures were dumped from the base
# commit (c5389f6d) by tests/testthat/fixtures/make-fiml-baseline-g3s1.R, before any serial code existed:
#   fiml-tables-before-g3s1.rds    every FIML table shape (simple, parallel j = 1 and 2, parallel residual covariance,
#                                  covariate-only k = 1 and 2, parallel x k = 1 and 2, each with a free and a fixed-zero
#                                  direct path), compared with identical().
#   fiml-refusals-before-g3s1.rds  condition class, stage and message of fit_sem(..., missing = "fiml",
#                                  fixed_x = FALSE) for near-miss syntaxes, compared byte for byte.
# After slice S1a (the serial router in front of the parallel and covariate routing) these must stay identical, EXCEPT
# the entries whose meaning S1a changes by design (spec 4.4, 4.1 items 1-2). Those are listed in `s1a_may_change`
# below; S1a updates the fixture for exactly those names, with the new text recorded in the same commit, and keeps
# this test asserting every other entry unchanged. Every entry named ser_* is a serial-looking syntax and is expected
# to change message or class once the serial parser answers it (refused for the serial reason instead of the
# parallel-flavored "unsupported FIML topology or correlated disturbances"). The one non-ser_ entry that changes is
# simple_serial_chain_bare (the gate probe `serial`: M1 ~ X, M2 ~ M1, Y ~ M2 + X, refused afterward for the omitted
# zeros of Q2); the same applies to `parallel_covariate_serial`, which is ser_sat1_m1m2_zero here. All par*, cov* and
# other simple_* entries are non-serial near misses and must not change (F8).
# S1a never rewrites the frozen pre-serial files: fiml-refusals-after-g3s1a.rds and fiml-tables-after-g3s1a.rds
# (made by make-fiml-after-g3s1a.R) pin the post-S1a answers and the 12 serial table cells.
b0_may_change <- function(nm) startsWith(nm, "ser_") || identical(nm, "simple_serial_chain_bare")

# Slice S1b (the saturated k = 0 serial shape becomes a public fit) changes the answer for exactly the entries below:
# they were refused as "not yet available" in the post-S1a dump and are accepted fits now. They are pinned against
# fiml-refusals-after-g3s1b.rds (made by make-fiml-after-g3s1b.R); the frozen pre-serial and post-S1a files are never
# rewritten. Every other entry must equal the post-S1a dump byte for byte.
b1_changed <- c("ser_sat0_zeros", "ser_reversed_sat")

b0_tables <- function() readRDS(test_path("fixtures", "fiml-tables-before-g3s1.rds"))
b0_refusals <- function() readRDS(test_path("fixtures", "fiml-refusals-before-g3s1.rds"))
b0_rebuild <- function() {
  tab <- list()
  for (d in c(TRUE, FALSE)) {
    tab[[paste0("simple", d)]] <- .sem_fiml_tables(d)
    for (j in 1:2) tab[[paste0("med", j, d)]] <- .sem_fiml_tables_med(j, d)
    tab[[paste0("medrc2", d)]] <- .sem_fiml_tables_med(2L, d, TRUE)
    for (k in 1:2) {
      tab[[paste0("cov", k, d)]] <- .sem_fiml_tables_cov(k, d)
      for (rc in c(FALSE, TRUE)) {
        tab[[paste0("parcov", k, if (rc) "rc" else "ind", d)]] <- .sem_fiml_tables_med(2L, d, rc, k)
      }
    }
    tab[[paste0("cov1wrap", d)]] <- .sem_fiml_tables_cov1(d)
  }
  tab
}
b0_observe <- function(model, data) {
  e <- tryCatch(fit_sem(model, data, missing = "fiml", fixed_x = FALSE), error = identity)
  if (!inherits(e, "error")) return(list(class = "<fit>", message = NA_character_, stage = NA_character_))
  list(class = class(e), message = conditionMessage(e), stage = if (is.null(e$stage)) NA_character_ else e$stage)
}

test_that("the table fixture holds every reachable shape, labels and fields included", {
  before <- b0_tables()
  expect_length(before, 22L)
  expect_identical(sort(names(before)), sort(names(b0_rebuild())))
  for (t in before) {
    expect_identical(names(t), c("vars", "a", "s", "m"))
    expect_identical(names(t$a), c("row", "col", "label", "value"))
    expect_identical(names(t$s), c("row", "col", "label", "value"))
    expect_identical(names(t$m), c("row", "label", "value"))
  }
})

test_that("the current table builders reproduce the pre-serial dump with identical()", {
  before <- b0_tables()
  now <- b0_rebuild()
  for (nm in names(before)) expect_identical(now[[nm]], before[[nm]], info = nm)
  # the single-mediator and covariate wrappers are the same tables as the general builders
  for (d in c(TRUE, FALSE)) {
    expect_identical(.sem_fiml_tables(d), before[[paste0("med1", d)]])
    expect_identical(.sem_fiml_tables_cov1(d), before[[paste0("cov1", d)]])
  }
})

test_that("the near-miss refusals keep their class, stage and message byte for byte", {
  fx <- b0_refusals()
  expect_gte(length(fx$models), 90L)
  expect_identical(names(fx$models), names(fx$results))
  # Slice S1a (the serial router) changes the answer for serial syntax by design: those entries are pinned against
  # the post-S1a fixture below; every other entry still matches the frozen pre-serial dump byte for byte.
  for (nm in setdiff(names(fx$models), names(fx$models)[vapply(names(fx$models), b0_may_change, logical(1))])) {
    got <- b0_observe(fx$models[[nm]], fx$data)
    expect_identical(got$class, fx$results[[nm]]$class, info = nm)
    expect_identical(got$stage, fx$results[[nm]]$stage, info = nm)
    expect_identical(got$message, fx$results[[nm]]$message, info = nm)
  }
})

test_that("the entries S1a may change match the post-S1a fixture, and none of them is an accepted fit", {
  before <- b0_refusals()
  after <- readRDS(test_path("fixtures", "fiml-refusals-after-g3s1a.rds"))
  expect_identical(after$models, before$models)
  expect_identical(after$data, before$data)
  for (nm in setdiff(names(after$models), b1_changed)) {
    got <- b0_observe(after$models[[nm]], after$data)
    expect_identical(got$class, after$results[[nm]]$class, info = nm)
    expect_identical(got$stage, after$results[[nm]]$stage, info = nm)
    expect_identical(got$message, after$results[[nm]]$message, info = nm)
    # outside the declared set the post-S1a dump is the frozen pre-serial one
    if (!b0_may_change(nm)) expect_identical(after$results[[nm]], before$results[[nm]], info = nm)
    if (b0_may_change(nm)) expect_false(identical(after$results[[nm]]$class, "<fit>"), info = nm)
  }
  # the entries S1b changed were refused by the not-yet-available reason after S1a
  for (nm in b1_changed) {
    expect_match(after$results[[nm]]$message, "serial FIML is not yet available", info = nm)
  }
  # serial syntax is now answered by the serial parser: no serial entry still carries the parallel-flavored message
  # unless it is not a serial syntax by the router's rule (one outcome, two other endogenous variables, a mediator-
  # to-mediator regression)
  moved <- names(after$models)[vapply(names(after$models), function(nm) {
    b0_may_change(nm) && !identical(after$results[[nm]]$message, before$results[[nm]]$message)
  }, logical(1))]
  expect_gte(length(moved), 25L)
  expect_true(all(c("ser_sat0_zeros", "simple_serial_chain_bare", "ser_chain1_zeros") %in% moved))
})

test_that("the serial tables of the 12 policy cells are frozen with identical() for S2 to S4", {
  fx <- readRDS(test_path("fixtures", "fiml-tables-after-g3s1a.rds"))
  expect_length(fx, 12L)
  for (sc in c(TRUE, FALSE)) for (k in 0:2) for (d in c(TRUE, FALSE)) {
    nm <- paste0(if (sc) "sat" else "chain", k, if (d) "free" else "fixed")
    expect_identical(.sem_fiml_tables_ser(d, k, sc), fx[[nm]], info = nm)
  }
  # the pre-serial tables are not the serial ones: no builder answers for the other
  expect_false(identical(.sem_fiml_tables_ser(TRUE, 0L, FALSE), .sem_fiml_tables_med(1L, TRUE)))
})

test_that("the refusal fixture covers the entries S1a may change and the ones it must not", {
  fx <- b0_refusals()
  nm <- names(fx$models)
  expect_true(all(grepl("^(ser|par|cov|simple)", nm)))
  expect_gte(sum(vapply(nm, b0_may_change, logical(1))), 30L)
  expect_gte(sum(!vapply(nm, b0_may_change, logical(1))), 45L)
  # admitted parallel neighbors still fit, so a later router must not start refusing them
  fit_names <- nm[vapply(fx$results, function(r) identical(r$class, "<fit>"), logical(1))]
  expect_identical(sort(fit_names), c("par0_free", "par0_zero", "par1_free", "par2_free"))
})

test_that("S1b: the post-S1b dump pins the entries that became fits and every other entry as it was after S1a", {
  a1 <- readRDS(test_path("fixtures", "fiml-refusals-after-g3s1a.rds"))
  b1 <- readRDS(test_path("fixtures", "fiml-refusals-after-g3s1b.rds"))
  expect_identical(b1$models, a1$models)
  expect_identical(b1$data, a1$data)
  for (nm in names(b1$models)) {
    got <- b0_observe(b1$models[[nm]], b1$data)
    expect_identical(got$class, b1$results[[nm]]$class, info = nm)
    expect_identical(got$stage, b1$results[[nm]]$stage, info = nm)
    expect_identical(got$message, b1$results[[nm]]$message, info = nm)
    if (nm %in% b1_changed) {
      expect_identical(b1$results[[nm]]$class, "<fit>", info = nm)
    } else {
      expect_identical(b1$results[[nm]], a1$results[[nm]], info = nm)
    }
  }
  # the chain and k >= 1 serial entries keep the not-yet-available reason
  nya <- names(b1$models)[vapply(b1$results, function(r) isTRUE(grepl("not yet available", r$message)), logical(1))]
  expect_true(all(c("ser_chain0_zeros", "ser_chain1_zeros", "ser_sat1_zeros", "ser_sat2_zeros") %in% nya))
  expect_false(any(c("ser_sat0_zeros", "ser_reversed_sat") %in% nya))
})
