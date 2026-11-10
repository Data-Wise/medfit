# Consistency guard for the probmed and RMediation comparison articles (D5): every row of each feature table has a
# probe that calls the dependent live, the status in the article equals the probe's, a planted edit is caught, and
# the numbers the prose quotes match a live computation. Skips when the vignettes or the dependent (at the
# version the article was checked against) are absent.

ec_text <- function(name) {
  p <- testthat::test_path("..", "..", "vignettes", "articles", name)
  testthat::skip_if(!file.exists(p), "vignettes are not available (installed or built package)")
  paste(readLines(p, warn = FALSE), collapse = "\n")
}

ec_rows <- function(txt) {
  lines <- strsplit(sub("(?s)^.*## Feature table", "", txt, perl = TRUE), "\n", fixed = TRUE)[[1]]
  lines <- lines[startsWith(lines, "|") & !grepl("^\\|[- |]+\\|$", lines)]
  cells <- lapply(strsplit(lines, "|", fixed = TRUE), function(x) trimws(x[-1]))
  cells <- cells[vapply(cells, length, 1L) == 4L]
  tab <- as.data.frame(do.call(rbind, cells), stringsAsFactors = FALSE)
  names(tab) <- c("feature", "medfit", "dependent", "status")
  tab[tab$feature != "Feature", ]
}

ec_works <- function(expr) {
  if (inherits(try(expr, silent = TRUE), "try-error")) "Unsupported" else "Supported"
}

ec_mismatch <- function(rows, probes) {
  out <- vapply(rows$feature, function(f) probes[[f]](), character(1))
  bad <- rows$status != out
  stats::setNames(out[bad], rows$feature[bad])
}

ec_none <- stats::setNames(character(), character())
ec_md <- function() medfit::mediation_demo

ec_objects <- function() {
  md <- ec_md()
  m1 <- stats::lm(mediator1 ~ treatment, md)
  list(
    simple = medfit::fit_mediation(outcome ~ treatment + mediator1, mediator1 ~ treatment, data = md,
                                   treatment = "treatment", mediator = "mediator1"),
    serial = medfit::extract_mediation(
      m1, model_y = stats::lm(outcome ~ mediator1 + mediator2 + treatment, md),
      mediator_models = list(stats::lm(mediator2 ~ treatment + mediator1, md)),
      treatment = "treatment", mediator = c("mediator1", "mediator2")
    ),
    parallel = medfit::extract_mediation(
      m1, model_y = stats::lm(outcome ~ mediator1 + mediator2 + treatment, md),
      mediator_models = list(stats::lm(mediator2 ~ treatment, md)),
      treatment = "treatment", mediator = c("mediator1", "mediator2"), structure = "parallel"
    ),
    interaction = medfit::extract_mediation(
      m1, model_y = stats::lm(outcome ~ mediator1 * treatment, md),
      treatment = "treatment", mediator = "mediator1"
    ),
    sem = medfit::fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment", md)
  )
}

pm_probes <- function() {
  o <- ec_objects()
  ex <- function(f) medfit::extract_mediation(f, treatment = "treatment", mediator = "mediator1")
  pm <- function(x) probmed::pmed(x, n_boot = 50, seed = 1)
  list(
    "P_med from `MediationData`" = function() ec_works(pm(o$simple)),
    "P_med from `ParallelMediationData`" = function() ec_works(pm(o$parallel)),
    "P_med from `SerialMediationData`" = function() ec_works(pm(o$serial)),
    "P_med from `InteractionMediationData`" = function() ec_works(pm(o$interaction)),
    "P_med from a `SEMFit` directly" = function() ec_works(pm(o$sem)),
    "P_med from a `SEMFit` after `extract_mediation()`" = function() ec_works(pm(ex(o$sem))),
    "Sensitivity analysis and alternative P_med estimators" = function() {
      ns <- getNamespaceExports("probmed")
      need <- c("pmed_sensitivity", "incr_pmed", "sobol_pmed", "wasserstein_pmed")
      if (all(need %in% ns)) "Supported" else "Unsupported"
    }
  )
}

rm_probes <- function() {
  o <- ec_objects()
  ex <- function(f) medfit::extract_mediation(f, treatment = "treatment", mediator = "mediator1")
  md <- ec_md()
  list(
    "Interval for the NIE of a `MediationData`" = function() ec_works(RMediation::ci(o$simple)),
    "Interval for the NIE of a `SerialMediationData`" = function() ec_works(RMediation::ci(o$serial)),
    "Interval from a `ParallelMediationData`" = function() ec_works(RMediation::ci(o$parallel)),
    "Interval from an `InteractionMediationData`" = function() ec_works(RMediation::ci(o$interaction)),
    "Interval from a `SEMFit` directly" = function() ec_works(RMediation::ci(o$sem)),
    "Interval from a `SEMFit` after `extract_mediation()`" = function() ec_works(RMediation::ci(ex(o$sem))),
    "MBCO for a restricted and a full `SEMFit`" = function() {
      m <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
      ec_works(RMediation::mbco(medfit::fit_sem(paste0(m, "\na == 0"), md), o$sem))
    },
    "Quantile of a product of two normals" = function() {
      ec_works(RMediation::qprodnormal(0.5, mu.x = 0.5, mu.y = 0.6, se.x = 0.1, se.y = 0.1))
    }
  )
}

test_that("probmed table: rows are exactly the probed features and statuses equal live calls", {
  skip_if_not_installed("probmed", "0.4.1")
  rows <- ec_rows(ec_text("probmed-comparison.qmd"))
  expect_setequal(rows$feature, names(pm_probes()))
  expect_true(all(rows$status %in% c("Supported", "Partial", "Unsupported")))
  expect_identical(ec_mismatch(rows, pm_probes()), ec_none)
})

test_that("RMediation table: rows are exactly the probed features and statuses equal live calls", {
  skip_if_not_installed("RMediation", "1.11.1")
  rows <- ec_rows(ec_text("rmediation-comparison.qmd"))
  expect_setequal(rows$feature, names(rm_probes()))
  expect_true(all(rows$status %in% c("Supported", "Partial", "Unsupported")))
  expect_identical(ec_mismatch(rows, rm_probes()), ec_none)
})

test_that("planted defect: flipping a status in either table is caught", {
  skip_if_not_installed("probmed", "0.4.1")
  skip_if_not_installed("RMediation", "1.11.1")
  pr <- ec_rows(ec_text("probmed-comparison.qmd"))
  pr$status[pr$feature == "P_med from `SerialMediationData`"] <- "Supported"
  expect_named(ec_mismatch(pr, pm_probes()), "P_med from `SerialMediationData`")
  rr <- ec_rows(ec_text("rmediation-comparison.qmd"))
  rr$status[rr$feature == "Interval from a `ParallelMediationData`"] <- "Supported"
  expect_named(ec_mismatch(rr, rm_probes()), "Interval from a `ParallelMediationData`")
})

test_that("the probmed article's numbers match a live fit", {
  skip_if_not_installed("probmed", "0.4.1")
  txt <- ec_text("probmed-comparison.qmd")
  o <- ec_objects()
  expect_equal(round(as.numeric(medfit::nie(o$simple)), 3), 0.325)
  expect_equal(round(as.numeric(medfit::nde(o$simple)), 3), 0.041)
  p <- probmed::pmed(o$simple, n_boot = 500, seed = 1)
  expect_equal(round(p@estimate, 3), 0.569)
  expect_equal(round(as.numeric(c(p@ci_lower, p@ci_upper)), 2), c(0.54, 0.61))
  expect_equal(round(p@ie_estimate, 3), 0.329)
  for (frag in c("0.325", "0.041", "0.569", "0.536 to 0.608", "0.329")) {
    expect_true(grepl(frag, txt, fixed = TRUE), info = frag)
  }
})

test_that("the RMediation article's intervals and MBCO agreement match live calls", {
  skip_if_not_installed("RMediation", "1.11.1")
  txt <- ec_text("rmediation-comparison.qmd")
  o <- ec_objects()
  dop <- RMediation::ci(o$simple, type = "dop")
  expect_equal(round(dop$CI, 3), c(0.172, 0.488))
  delta <- suppressWarnings(stats::confint(o$simple, parm = "effects"))["nie", ]
  expect_equal(round(unname(delta), 3), c(0.168, 0.483))
  mc <- withr::with_seed(1L, RMediation::ci(o$simple, type = "MC", n.mc = 1e5))
  expect_lt(max(abs(mc$CI - dop$CI)), 0.003)
  m <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
  md <- ec_md()
  pa <- RMediation::mbco(medfit::fit_sem(paste0(m, "\na == 0"), md), o$sem)$p_value
  pb <- RMediation::mbco(medfit::fit_sem(paste0(m, "\nb == 0"), md), o$sem)$p_value
  ps <- medfit::mbco_sem(o$sem, "a", "b")$p.value
  expect_equal(max(pa, pb), ps, tolerance = 1e-6)
  expect_equal(signif(ps, 3), 2.79e-05)
  for (frag in c("0.172 to 0.488", "0.168 to 0.483", "2.79e-05")) {
    expect_true(grepl(frag, txt, fixed = TRUE), info = frag)
  }
})
