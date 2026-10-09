# The accessor seam (S10, PR 3): the extractors read a fitted model only through
# an accessor list. Zero behavior change is the gate, shown three ways:
#   1. identity: every lavaan fixture extracted through the seam and through a
#      frozen copy of the pre-refactor extractor (helper-frozen-extract-lavaan.R)
#      gives identical S7 properties;
#   2. completeness: no direct lavaan:: call is left in R/extract-lavaan.R;
#   3. independence: a hand-built accessor list extracts with every lavaan
#      function mocked to error.
# Each has a planted defect that must turn it red.

testthat::skip_if_not_installed("lavaan")

demo <- local({
  d <- medfit::mediation_demo
  d$tm <- d$treatment * d$mediator1
  d
})

lab_simple <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + cp*treatment + covariate1"
plain_simple <- "mediator1 ~ treatment\noutcome ~ mediator1 + treatment"

fixtures <- list(
  labeled = list(
    fit = function() lavaan::sem(lab_simple, data = demo),
    args = list(treatment = "treatment", mediator = "mediator1", outcome = "outcome")
  ),
  labeled_std = list(
    fit = function() lavaan::sem(lab_simple, data = demo),
    args = list(treatment = "treatment", mediator = "mediator1", outcome = "outcome", standardized = TRUE)
  ),
  unlabeled = list(
    fit = function() lavaan::sem(plain_simple, data = demo),
    args = list(treatment = "treatment", mediator = "mediator1")
  ),
  custom_labels = list(
    fit = function() lavaan::sem("mediator1 ~ p*treatment\noutcome ~ q*mediator1 + r*treatment", data = demo),
    args = list(
      treatment = "treatment", mediator = "mediator1", outcome = "outcome",
      a_label = "p", b_label = "q", cp_label = "r"
    )
  ),
  serial = list(
    fit = function() {
      lavaan::sem(
        "mediator1 ~ treatment\nmediator2 ~ mediator1 + treatment\noutcome ~ mediator2 + mediator1 + treatment",
        data = demo
      )
    },
    args = list(treatment = "treatment", mediator = c("mediator1", "mediator2"), outcome = "outcome")
  ),
  parallel = list(
    fit = function() {
      lavaan::sem(
        paste(
          "mediator1 ~ treatment", "mediator2 ~ treatment", "mediator1 ~~ mediator2",
          "outcome ~ mediator1 + mediator2 + treatment", sep = "\n"
        ),
        data = demo
      )
    },
    args = list(treatment = "treatment", mediator = c("mediator1", "mediator2"), outcome = "outcome")
  ),
  interaction = list(
    fit = function() {
      lavaan::sem("mediator1 ~ treatment\noutcome ~ mediator1 + treatment + tm", data = demo, meanstructure = TRUE)
    },
    args = list(treatment = "treatment", mediator = "mediator1", outcome = "outcome", interaction = "tm")
  ),
  latent = list(
    fit = function() {
      lavaan::sem(
        "eta =~ mediator1 + mediator2 + mediator3\neta ~ a*treatment\noutcome ~ b*eta + cp*treatment",
        data = demo
      )
    },
    args = list(treatment = "treatment", mediator = "eta", outcome = "outcome")
  )
)

extract_new <- function(fit, args) do.call(extract_mediation_lavaan, c(list(fit), args))
# Looked up by name: the frozen copy is defined in a helper file, which the CI linter does not source.
extract_old <- function(fit, args) do.call(match.fun(".frozen_extract_mediation_lavaan"), c(list(fit), args))

test_that("every lavaan fixture extracts identically through the seam and the frozen pre-refactor code", {
  for (nm in names(fixtures)) {
    fit <- fixtures[[nm]]$fit()
    new <- extract_new(fit, fixtures[[nm]]$args)
    old <- extract_old(fit, fixtures[[nm]]$args)
    testthat::expect_identical(class(new), class(old), info = nm)
    testthat::expect_identical(S7::props(new), S7::props(old), info = nm)
  }
  # the fixtures cover all four extraction paths
  classes <- vapply(fixtures, function(f) class(extract_new(f$fit(), f$args))[1L], "")
  testthat::expect_true(all(
    c("medfit::MediationData", "medfit::SerialMediationData", "medfit::ParallelMediationData",
      "medfit::InteractionMediationData") %in% classes
  ))
})

test_that("planted defect: a seam that drops the label column changes the extraction", {
  fit <- fixtures$labeled$fit()
  acc <- .sem_accessors_lavaan(fit)
  acc$partable <- function() {
    pt <- lavaan::parTable(fit)
    pt$label <- NULL
    pt
  }
  expected <- extract_old(fit, fixtures$labeled$args)
  res <- tryCatch(extract_new(acc, fixtures$labeled$args), error = function(e) NULL)
  testthat::expect_true(is.null(res) || !identical(S7::props(res), S7::props(expected)))
})

# --- completeness gate ---------------------------------------------------------

direct_lavaan_calls <- function(lines) {
  code <- lines[!grepl("^\\s*#", lines)]
  grep("lavaan::", code, value = TRUE, fixed = TRUE)
}

test_that("no direct lavaan:: call is left in the extractor, and the accessor file holds them", {
  extractor <- testthat::test_path("..", "..", "R", "extract-lavaan.R")
  accessors <- testthat::test_path("..", "..", "R", "extract-sem.R")
  testthat::skip_if_not(file.exists(extractor) && file.exists(accessors), "package sources not available")
  testthat::expect_identical(direct_lavaan_calls(readLines(extractor)), character(0))
  testthat::expect_gte(length(direct_lavaan_calls(readLines(accessors))), 7L)
})

test_that("planted defect: one direct lavaan::lavInspect() call in a helper is caught", {
  extractor <- testthat::test_path("..", "..", "R", "extract-lavaan.R")
  testthat::skip_if_not(file.exists(extractor), "package sources not available")
  src <- readLines(extractor)
  i <- grep("^\\.lavaan_n_obs <- function", src)
  testthat::expect_length(i, 1L)
  planted <- append(src, "  as.integer(round(sum(lavaan::lavInspect(acc, \"nobs\"))))", after = i)
  hits <- direct_lavaan_calls(planted)
  testthat::expect_length(hits, 1L)
  testthat::expect_match(hits, "lavInspect")
})

# --- independence from lavaan --------------------------------------------------

test_that("a hand-built accessor list extracts with every lavaan function mocked to error", {
  fit <- fixtures$labeled$fit()
  args <- fixtures$labeled$args
  real <- .sem_accessors_lavaan(fit)
  values <- list(
    pt = real$param_table(FALSE), pt_std = real$param_table(TRUE), coef = real$coef(), vcov = real$vcov(),
    partable = real$partable(), data = real$data(), converged = real$converged(), nobs = real$nobs(),
    ov = real$names("ov"), ov_ord = real$names("ov.ord")
  )
  hand <- structure(
    list(
      param_table = function(standardized = FALSE) if (standardized) values$pt_std else values$pt,
      coef = function() values$coef,
      vcov = function() values$vcov,
      partable = function() values$partable,
      data = function() values$data,
      converged = function() values$converged,
      nobs = function() values$nobs,
      names = function(type) if (type == "ov.ord") values$ov_ord else values$ov
    ),
    class = "sem_accessors"
  )
  expected <- extract_new(fit, args)

  ns <- ls(asNamespace("lavaan"), all.names = TRUE)
  used <- intersect(
    c("parameterEstimates", "standardizedSolution", "coef", "vcov", "lavInspect", "parTable", "parameterTable",
      "lavNames"),
    ns
  )
  testthat::expect_gte(length(used), 6L)
  boom <- function(...) stop("lavaan was called", call. = FALSE)
  mocks <- stats::setNames(rep(list(boom), length(used)), used)
  do.call(testthat::local_mocked_bindings, c(mocks, list(.package = "lavaan")))

  # positive control: the mocks bite, a real fit now fails
  testthat::expect_error(extract_new(fit, args), "lavaan was called")
  res <- extract_new(hand, args)
  testthat::expect_identical(S7::props(res), S7::props(expected))
})
