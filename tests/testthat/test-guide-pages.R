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

  delta <- tidy(fit, type = "effects", conf_int = TRUE)
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
  expect_lt(abs(delta$conf_low[1] - par_boot@ci_lower), 0.02)
  expect_lt(abs(delta$conf_high[1] - par_boot@ci_upper), 0.02)
  expect_lt(abs(np_boot@ci_lower - par_boot@ci_lower), 0.03)
  expect_lt(abs(np_boot@ci_upper - par_boot@ci_upper), 0.03)

  plug <- bootstrap_mediation(indirect, method = "plugin", mediation_data = fit)
  expect_true(is.na(plug@ci_lower))
  expect_true(is.na(plug@ci_upper))

  expect_warning(confint(fit, parm = "effects"), "Normal approximation for NIE may be inaccurate")
  expect_silent(tidy(fit, type = "effects", conf_int = TRUE))
  ci <- suppressWarnings(confint(fit, parm = "effects"))
  expect_equal(unname(ci["nie", ]), c(delta$conf_low[1], delta$conf_high[1]), tolerance = 1e-6)
})

test_that("a planted dangling link in a guide would be caught", {
  txt <- "see [x](guide-nope.html) and [y](guide-intervals.html)"
  links <- unique(regmatches(txt, gregexpr("\\]\\(([a-z-]+)\\.html[#)]", txt))[[1]])
  targets <- paste0(gsub("^\\]\\(|\\.html[#)]$", "", links), ".qmd")
  existing <- c("guide-intervals.qmd")
  expect_identical(targets[!targets %in% existing], "guide-nope.qmd")
})

# Absolute links to the published site (https://data-wise.github.io/medfit/...) are not relative
# `](x.html)` links, so the tests above never see them. A dead `#installation` anchor shipped on four
# pages that way. These helpers resolve each such link to its source file and heading ids offline.
site_root <- "https://data-wise.github.io/medfit/"

site_link_pattern <- "https://data-wise\\.github\\.io/medfit/[^)\\s\"'>]*"

# Pandoc's auto identifier for a heading: lower case, drop punctuation except `_-.`, spaces to hyphens,
# strip anything before the first letter. An explicit `{#id}` wins.
heading_ids <- function(lines) {
  is_fence <- grepl("^\\s*(```|~~~)", lines)
  in_code <- cumsum(is_fence) %% 2L == 1L | is_fence
  h <- lines[!in_code & grepl("^#{1,6}\\s+\\S", lines)]
  explicit <- regmatches(h, regexpr("\\{[^}]*#[A-Za-z0-9_.:-]+[^}]*\\}", h))
  explicit <- sub("^.*#([A-Za-z0-9_.:-]+).*$", "\\1", explicit)
  txt <- sub("\\s*\\{[^}]*\\}\\s*$", "", sub("^#{1,6}\\s+", "", h))
  txt <- gsub("\\[([^]]*)\\]\\([^)]*\\)", "\\1", txt)
  txt <- gsub("[`*]", "", txt)
  auto <- tolower(txt)
  auto <- gsub("[^a-z0-9_ .-]", "", auto)
  auto <- gsub("\\s+", "-", auto)
  auto <- sub("^[^a-z]+", "", auto)
  unique(c(explicit, auto))
}

# Source file for a site URL: the home page is README.md, an article is vignettes/articles/<name>.qmd.
site_source <- function(url) {
  path <- sub("#.*$", "", sub(site_root, "", url, fixed = TRUE))
  if (path %in% c("", "index.html")) return(root_path("README.md"))
  m <- regmatches(path, regexec("^articles/([A-Za-z0-9_-]+)\\.html$", path))[[1]]
  if (length(m) == 2L) return(root_path("vignettes", "articles", paste0(m[2], ".qmd")))
  NA_character_
}

# Broken site links in `lines`: the page or the fragment has no source heading.
broken_site_links <- function(lines) {
  urls <- unique(unlist(regmatches(lines, gregexpr(site_link_pattern, lines, perl = TRUE))))
  urls <- sub("[.,;:]+$", "", urls)
  bad <- character()
  for (u in urls) {
    src <- site_source(u)
    if (is.na(src)) next # reference pages, news and other generated pages have no source here
    if (!file.exists(src)) {
      bad <- c(bad, u)
      next
    }
    frag <- sub("^[^#]*#?", "", u)
    if (nzchar(frag) && !frag %in% heading_ids(readLines(src, warn = FALSE))) bad <- c(bad, u)
  }
  bad
}

test_that("every absolute site link on the articles and README resolves to a page and a heading", {
  skip_on_cran()
  d <- root_path("vignettes", "articles")
  skip_if_not(dir.exists(d), "vignettes are not available (installed or built package)")
  files <- c(list.files(d, pattern = "\\.qmd$", full.names = TRUE), root_path("README.md"))
  skip_if_not(all(file.exists(files)), "README.md is not available")
  for (f in files) {
    lines <- readLines(f, warn = FALSE)
    expect_identical(broken_site_links(lines), character(), info = basename(f))
    expect_false(any(grepl("medfit/#installation", lines, fixed = TRUE)), info = basename(f))
  }
})

test_that("a planted dead site anchor would be caught, and a live one passes", {
  skip_on_cran()
  skip_if_not(file.exists(root_path("README.md")), "README.md is not available")
  expect_true("install" %in% heading_ids(readLines(root_path("README.md"), warn = FALSE)))
  planted <- paste0(
    "see [home](https://data-wise.github.io/medfit/#installation) ",
    "and [x](https://data-wise.github.io/medfit/#install)"
  )
  expect_identical(broken_site_links(planted), "https://data-wise.github.io/medfit/#installation")
  gone <- "[y](https://data-wise.github.io/medfit/articles/no-such-page.html#top)"
  expect_identical(broken_site_links(gone), "https://data-wise.github.io/medfit/articles/no-such-page.html#top")
})
