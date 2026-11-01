# Independent structural snapshot QA; saved accepted source, zero optimizer calls.
devtools::load_all(quiet = TRUE)
library(testthat)
source("tests/testthat/helper-fiml-bootstrap.R")
workspace <- "_agents_workspace/fiml-bounded-inference"
saved <- readRDS(file.path(workspace, "qa-matrix.rds"))
fit <- saved$artifacts[["mar-free"]]$fit
fb_fit <- function(...) fit
wanted <- c(
  "effect evaluation refuses nonfinite and nonscalar central functionals",
  "defensive canonical theta guard rejects damage before RNG after the provenance guard",
  "accepted refit warnings are muffled and retained in the replicate ledger",
  "inner interrupt records preserve the condition class and later unattempted IDs",
  "malformed worker results retain every requested ID and withhold survivor intervals",
  "printed summaries label method and inference status",
  "immutability snapshot detects every property and instance or constructor attribute mutation",
  "constructor snapshots detect nested code and source-reference metadata changes"
)
expressions <- as.list(parse("tests/testthat/test-bootstrap-fiml.R"))
selected <- Filter(function(x) {
  is.call(x) && identical(x[[1]], as.name("test_that")) && x[[2]] %in% wanted
}, expressions)
stopifnot(length(selected) == length(wanted))
invisible(lapply(selected, eval))
source("tests/testthat/test-bootstrap-fiml-execution.R")
test_that("independent nested validator and metadata mutants cannot hide inside structural descriptors", {
  validator <- function(x = 2) {
    if (x > 0) list(ok = TRUE, value = x + 1) else stop("bad")
  }
  attr(validator, "srcref") <- structure(1:8, class = "srcref", srcfile = new.env(parent = emptyenv()))
  container <- list(validator = validator, nested = expression(fun(a = 1, b = quote(x + 2))))
  before <- fb_constructor_state(container)
  for (kind in c("body", "formal", "reference", "annotation", "environment", "nested_call")) {
    mutant <- container
    if (kind == "body") body(mutant$validator)[[2]][[3]][[3]][[3]] <- 7
    if (kind == "formal") formals(mutant$validator)$x <- 9
    if (kind == "reference") attr(mutant$validator, "srcref")[2] <- 9L
    if (kind == "annotation") attr(attr(mutant$validator, "srcref"), "annotation") <- list(extra = 1)
    if (kind == "environment") environment(mutant$validator) <- new.env(parent = environment(validator))
    if (kind == "nested_call") mutant$nested[[1]][[3]][[2]][[3]] <- 8
    expect_false(identical(fb_constructor_state(mutant), before), info = kind)
  }
  expect_identical(fb_constructor_state(container), before)
  for (method in c("parametric", "nonparametric")) {
    original <- fb_snapshot(fit)
    out <- testthat::with_mocked_bindings(
      bootstrap_mediation(source_fit = fit, effect = "nie", method = method, n_boot = 2L, seed = 123L),
      .bootstrap_fiml_refit = function(...) fit, .package = "medfit"
    )
    expect_identical(fb_snapshot(fit), original)
    expect_identical(out@inference$status, "complete")
  }
})
cat("Independent snapshot and seven automatic branch contracts PASS; zero actual fits\n")
saveRDS(list(status = "PASS", candidate = "a51a843", selected = wanted),
        file.path(workspace, "qa-snapshot.rds"))
