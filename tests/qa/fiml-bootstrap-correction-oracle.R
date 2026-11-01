# Independent correction QA: all accepted fits replayed from immutable matrix.
devtools::load_all(quiet = TRUE)
workspace <- "_agents_workspace/fiml-bounded-inference"
a <- readRDS(file.path(workspace, "qa-matrix.rds"))$artifacts[["mar-free"]]
fit <- a$fit
assert <- function(x) if (!isTRUE(x)) stop("independent correction assertion failed")
interrupt <- function() {
  stop(structure(list(message = "QA parent interrupt", call = NULL), class = c("interrupt", "condition")))
}
assert_incomplete <- function(out, status, expected_rows) {
  assert(identical(out@inference$status, "incomplete"))
  assert(identical(vapply(out@inference$replicates, `[[`, integer(1), "id"), seq_along(status)))
  assert(identical(vapply(out@inference$replicates, `[[`, character(1), "status"), status))
  assert(identical(lapply(out@inference$replicates, `[[`, "rows"), expected_rows))
  assert(identical(is.na(out@boot_estimates), status != "accepted"))
  assert(out@inference$successful == sum(status == "accepted"))
  assert(out@inference$failed == sum(status != "accepted"))
  assert(out@inference$interrupted == sum(status == "interrupted"))
  assert(out@inference$unattempted == sum(status == "unattempted"))
  out@ci_lower <- -100
  out@ci_upper <- 100
  for (level in c(.01, .5, .8, .95, .99)) assert(all(is.na(confint(out, level = level))))
  assert(all(is.na(tidy(out)[c("std_error", "conf_low", "conf_high")])))
  assert(all(is.na(summary(out)$ci)))
  assert(any(grepl("Lower: +NA", capture.output(print(out)))))
  assert(any(grepl("incomplete", capture.output(show(out)))))
}
# A child interrupt is injected after one complete batch so retained work is nontrivial.
for (use_parallel in c(FALSE, TRUE)) {
  args <- list(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 6L,
               seed = 911L, parallel = use_parallel, ncores = 2L)
  out <- testthat::with_mocked_bindings(
    do.call(bootstrap_mediation, args),
    .bootstrap_fiml_refit = function(source, rows) {
      if (identical(rows, a$indices[[4]])) interrupt()
      fit
    }, .package = "medfit"
  )
  assert_incomplete(out, c(rep("accepted", 3L), "interrupted", rep("unattempted", 2L)), a$indices[1:6])
}
cat("Sequential and actual two-worker child interruptions: complete ledger/accessors PASS\n")
# Parent interruption can only know that the active batch is unavailable, never that it completed.
state <- new.env(parent = emptyenv())
state$batches <- 0L
parent_result <- testthat::with_mocked_bindings(
  testthat::with_mocked_bindings(
    bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 6L,
                        seed = 911L, parallel = TRUE, ncores = 2L),
    .bootstrap_fiml_refit = function(...) fit, .package = "medfit"
  ),
  mclapply = function(X, FUN, ...) {
    state$batches <- state$batches + 1L
    if (state$batches == 2L) interrupt()
    lapply(X, FUN)
  }, .package = "parallel"
)
assert_incomplete(parent_result, c(rep("accepted", 2L), rep("interrupted", 2L), rep("unattempted", 2L)),
                  a$indices[1:6])
assert(state$batches == 2L)
# Named mutant: claiming an unavailable parent batch was accepted must fail the independent status assertion.
mutant <- parent_result
metadata <- mutant@inference
metadata$replicates[[3]]$status <- "accepted"
mutant@inference <- metadata
expected_status <- c(rep("accepted", 2L), rep("interrupted", 2L), rep("unattempted", 2L))
label_failure <- tryCatch(assert_incomplete(mutant, expected_status, a$indices[1:6]), error = identity)
assert(inherits(label_failure, "error"))
cat("Parent batch interruption: honest unavailable IDs, later unattempted IDs, label mutant PASS\n")
# Replay accepted original fits: new executor must preserve every original bit without another fit.
replay <- function(source, rows) {
  id <- which(vapply(a$indices, identical, logical(1), rows))
  assert(length(id) == 1L)
  a$native[[id]]
}
outputs <- lapply(c(FALSE, TRUE), function(use_parallel) {
  testthat::with_mocked_bindings(
    bootstrap_mediation(source_fit = fit, effect = "nie", method = "nonparametric", n_boot = 12L,
                        seed = 911L, parallel = use_parallel, ncores = 2L),
    .bootstrap_fiml_refit = replay, .package = "medfit"
  )
})
for (out in outputs) {
  assert(identical(out@boot_estimates, a$out@boot_estimates))
  assert(identical(c(out@estimate, out@ci_lower, out@ci_upper),
                   c(a$out@estimate, a$out@ci_lower, a$out@ci_upper)))
}
args <- list(source_fit = fit, effect = "te", method = "parametric", n_boot = 8L, seed = 123L)
sequential <- do.call(bootstrap_mediation, args)
parallel_result <- do.call(bootstrap_mediation, c(args, list(parallel = TRUE, ncores = 2L)))
assert(identical(parallel_result@boot_estimates, sequential@boot_estimates))
assert(identical(c(parallel_result@ci_lower, parallel_result@ci_upper),
                 c(sequential@ci_lower, sequential@ci_upper)))
cat("Original numerical artifact exact neutrality and seeded sequential/parallel row/draw equality PASS\n")
saveRDS(list(status = "PASS", parent = parent_result, row = outputs, draws = sequential),
        file.path(workspace, "qa-correction.rds"))
