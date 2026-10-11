# Consistency guard for the Guides pages: each guide-*.qmd is in the articles index
# and the Guides menu, and every article link on a guide resolves. The interval
# guide's statements are checked against the same fit it uses.

root_path <- function(...) testthat::test_path("..", "..", ...)

guide_names <- function() {
  d <- root_path("vignettes", "articles")
  testthat::skip_if_not(dir.exists(d), "vignettes are not available (installed or built package)")
  sub("\\.qmd$", "", list.files(d, pattern = "^guide-.*\\.qmd$"))
}

read_text <- function(p) paste(readLines(p, warn = FALSE), collapse = "\n")

test_that("every guide is in the articles index and the Guides menu", {
  guides <- guide_names()
  expect_length(guides, 4L)
  pk <- read_text(root_path("_pkgdown.yml"))
  for (g in guides) {
    expect_true(grepl(paste0("articles/", g, "`"), pk, fixed = TRUE), info = paste(g, "index"))
    expect_true(grepl(paste0("articles/", g, ".html"), pk, fixed = TRUE), info = paste(g, "menu"))
  }
})

test_that("every article link on the guides resolves", {
  for (g in guide_names()) {
    txt <- read_text(root_path("vignettes", "articles", paste0(g, ".qmd")))
    links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z-]+)\\.html[#)]", txt))[[1]])
    targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
    missing <- targets[!file.exists(root_path("vignettes", "articles", targets))]
    expect_identical(missing, character(), info = g)
  }
})

test_that("the interval guide's numbers and statements hold", {
  fy <- outcome ~ treatment + mediator1 + covariate1 + covariate2
  fm <- mediator1 ~ treatment + covariate1 + covariate2
  fit <- fit_mediation(fy, fm, data = mediation_demo, treatment = "treatment", mediator = "mediator1")
  indirect <- function(theta) theta["m_treatment"] * theta["y_mediator1"]

  delta <- tidy(fit, type = "effects", conf.int = TRUE)
  par_boot <- bootstrap_mediation(indirect,
    method = "parametric", mediation_data = fit,
    n_boot = 2000, seed = 1
  )
  refit_nie <- function(d) {
    unname(nie(fit_mediation(fy, fm, data = d, treatment = "treatment", mediator = "mediator1")))
  }
  np_boot <- bootstrap_mediation(refit_nie,
    method = "nonparametric", data = mediation_demo,
    n_boot = 300, seed = 1
  )
  # "agree to within about 0.01" on this dataset (0.02 allows the smaller bootstrap here)
  expect_lt(abs(delta$conf.low[1] - par_boot@ci_lower), 0.02)
  expect_lt(abs(delta$conf.high[1] - par_boot@ci_upper), 0.02)
  expect_lt(abs(np_boot@ci_lower - par_boot@ci_lower), 0.03)
  expect_lt(abs(np_boot@ci_upper - par_boot@ci_upper), 0.03)

  plug <- bootstrap_mediation(indirect, method = "plugin", mediation_data = fit)
  expect_true(is.na(plug@ci_lower))
  expect_true(is.na(plug@ci_upper))

  expect_warning(confint(fit, parm = "effects"), "Normal approximation for NIE may be inaccurate")
  expect_silent(tidy(fit, type = "effects", conf.int = TRUE))
  ci <- suppressWarnings(confint(fit, parm = "effects"))
  expect_equal(unname(ci["nie", ]), c(delta$conf.low[1], delta$conf.high[1]), tolerance = 1e-6)
})

test_that("a planted dangling link in a guide would be caught", {
  txt <- "see [x](guide-nope.html) and [y](guide-intervals.html)"
  links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z-]+)\\.html[#)]", txt))[[1]])
  targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
  existing <- c("guide-intervals.qmd")
  expect_identical(targets[!targets %in% existing], "guide-nope.qmd")
})
