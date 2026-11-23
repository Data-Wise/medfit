# Release-docs gates (ADR-docs-release-pipeline-2026-11-12, decisions RD-4 to RD-9).
# Each gate is a pure function over text, run on the real files and on a planted
# defect that must make it report a problem. Skips when the source tree is absent
# (installed or built package).

root_path <- function(...) testthat::test_path("..", "..", ...)
have_tree <- function() {
  file.exists(root_path("DESCRIPTION")) && dir.exists(root_path("vignettes", "articles")) &&
    file.exists(root_path("NEWS.md"))
}
read_lines <- function(...) readLines(root_path(...), warn = FALSE)

desc_version <- function() read.dcf(root_path("DESCRIPTION"), fields = "Version")[1L, 1L]
# a release version has three parts; a development version carries a fourth (0.17.0.9000)
is_release <- function(v) length(strsplit(v, "[.-]")[[1L]]) == 3L

stale_words <- "development version|unreleased"

# RD-4: NEWS opens with a heading for the version, and that section no longer says
# "unreleased" or "development version" once the version is a release
news_problems <- function(lines, v) {
  heads <- grep("^# ", lines)
  if (!length(heads) || lines[heads[1L]] != paste0("# medfit ", v)) {
    return(sprintf("NEWS.md does not open with '# medfit %s'", v))
  }
  end <- if (length(heads) > 1L) heads[2L] - 1L else length(lines)
  top <- lines[heads[1L]:end]
  hit <- grep(stale_words, top, ignore.case = TRUE, value = TRUE)
  if (is_release(v) && length(hit)) {
    return(paste("NEWS top section has stale wording:", substr(hit[1L], 1L, 60L)))
  }
  character()
}

# RD-5: pages that name the version they document name the DESCRIPTION version, and a
# release leaves no "development version"/"unreleased" in README or articles
prose_problems <- function(texts, v) {
  bad <- character()
  for (n in names(texts)) {
    pat <- "\\b(documents|describes|uses?) medfit [0-9]+(\\.[0-9]+){2,3}"
    claims <- regmatches(texts[[n]], gregexpr(pat, texts[[n]]))[[1L]]
    wrong <- claims[!grepl(paste0(" ", v, "$"), claims)]
    if (length(wrong)) bad <- c(bad, sprintf("%s says '%s', DESCRIPTION is %s", n, wrong[1L], v))
    if (is_release(v) && grepl(stale_words, texts[[n]], ignore.case = TRUE)) {
      bad <- c(bad, sprintf("%s has 'development version' or 'unreleased' in a release", n))
    }
  }
  bad
}

# RD-6: README carries a "What's new in <version>" block, and CITATION takes the version from DESCRIPTION
home_problems <- function(readme, citation, v) {
  bad <- character()
  if (!any(grepl(paste0("What's new in ", v), readme, fixed = TRUE))) {
    bad <- c(bad, sprintf("README has no \"What's new in %s\"", v))
  }
  if (!any(grepl("meta$Version", citation, fixed = TRUE)) || any(grepl("version [0-9]+\\.[0-9]+", citation))) {
    bad <- c(bad, "inst/CITATION does not take its version from DESCRIPTION")
  }
  bad
}

# RD-7: CLAUDE.md "Current status" names the version, and .STATUS' newest 40 lines mention it
status_problems <- function(claude, status, v) {
  bad <- character()
  line <- grep("^\\*\\*Current status:\\*\\*", claude, value = TRUE)
  if (length(line) != 1L || !grepl(v, substr(line, 1L, 160L), fixed = TRUE)) {
    bad <- c(bad, sprintf("CLAUDE.md 'Current status' does not name %s in its first 160 characters", v))
  }
  if (!any(grepl(v, utils::head(status, 40L), fixed = TRUE))) {
    bad <- c(bad, sprintf(".STATUS: none of the newest 40 lines mention %s", v))
  }
  bad
}

# RD-8: the FIML caveat is on the home page and on the FIML page, one sentence each (a marker, not a count of pages)
caveat <- "not statistically admitted"
caveat_problems <- function(readme, fiml) {
  as.character(c(
    if (!any(grepl(caveat, readme, fixed = TRUE))) "README lacks the FIML caveat",
    if (!any(grepl(caveat, fiml, fixed = TRUE))) "model-fiml.qmd lacks the FIML caveat"
  ))
}

# RD-9: layout rules. Next block and hidden setup on each model page (the five sem engine pages included since
# 0.18.0); navbar at most 8 items; contrast of the navbar CSS
page_problems <- function(pages) {
  bad <- character()
  for (n in names(pages)) {
    p <- pages[[n]]
    if (!any(grepl("{.next-action}", p, fixed = TRUE))) bad <- c(bad, paste(n, "has no Next block"))
    i <- grep("#| label: setup", p, fixed = TRUE)
    if (length(i) && !any(grepl("#| include: false", p[i[1L]:min(i[1L] + 2L, length(p))], fixed = TRUE))) {
      bad <- c(bad, paste(n, "shows its setup chunk output"))
    }
  }
  bad
}
navbar_problems <- function(yml, max_items = 8L) {
  m <- regmatches(yml, regexpr("left: +\\[[^]]*\\]", yml))
  n <- length(strsplit(sub("left: +\\[", "", sub("\\]$", "", m)), ",")[[1L]])
  if (n > max_items) sprintf("navbar has %d items, limit %d", n, max_items) else character()
}
# every article is in exactly one navbar menu and every menu link resolves; `shared` pages (the model picker is both
# the Start entry and the head of the Models menu) may appear twice
menu_problems <- function(components, left, articles, shared = "models") {
  bad <- character()
  seen <- list()
  for (m in left) {
    items <- components[[m]]$menu
    for (i in items) {
      h <- i$href
      if (is.null(h) || !grepl("^articles/[a-z0-9-]+\\.html", h)) next
      pg <- sub("\\.html.*$", "", sub("^articles/", "", h))
      if (!pg %in% articles && pg != "index") bad <- c(bad, paste(m, "links to a missing article:", pg))
      seen[[pg]] <- unique(c(seen[[pg]], m))
    }
  }
  for (pg in names(seen)) {
    if (length(seen[[pg]]) > 1L && !pg %in% shared) {
      bad <- c(bad, paste(pg, "is in menus", paste(seen[[pg]], collapse = " and ")))
    }
  }
  miss <- setdiff(articles, c(names(seen), "index"))
  if (length(miss)) bad <- c(bad, paste("in no menu:", paste(miss, collapse = ", ")))
  bad
}
lum <- function(hex) {
  rgb <- strtoi(substring(sub("#", "", hex), c(1, 3, 5), c(2, 4, 6)), 16L) / 255
  sum(c(0.2126, 0.7152, 0.0722) * ifelse(rgb <= 0.03928, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4))
}
contrast <- function(a, b) {
  x <- sort(c(lum(a), lum(b)), decreasing = TRUE)
  (x[1L] + 0.05) / (x[2L] + 0.05)
}
contrast_problems <- function(scss, bg = "#d9dadb", min = 4.5) {
  # the darkest navbar background seen in the Lighthouse pass is the active item, #d9dadb
  scss <- paste(scss, collapse = "\n")
  cols <- regmatches(scss, gregexpr("(?<=color: )#[0-9a-fA-F]{6}", scss, perl = TRUE))[[1L]]
  if (!length(cols)) return("extra.scss sets no colors")
  low <- cols[vapply(cols, contrast, numeric(1), b = bg) < min]
  if (length(low)) paste("colors below 4.5:1 on", bg, ":", paste(low, collapse = " ")) else character()
}

# RD-10: every non-model article opens with a "Use this when" line before its first section and closes with a Next
# block (the model pages have their own gate above). The exemption list is explicit and small: a page named here skips
# the opener only, with the reason on the entry.
opener_exempt <- c(models = "the model picker is itself an index: its first table is the opener")

outside_code <- function(lines) {
  fence <- grepl("^\\s*(```|~~~)", lines)
  !(cumsum(fence) %% 2L == 1L | fence)
}
body_lines <- function(lines) {
  if (length(lines) && lines[1L] == "---") lines <- lines[-seq_len(which(lines[-1L] == "---")[1L] + 1L)]
  lines
}
article_problems <- function(pages, exempt = names(opener_exempt)) {
  bad <- character()
  for (n in names(pages)) {
    p <- pages[[n]]
    if (!any(grepl("{.next-action}", p, fixed = TRUE))) bad <- c(bad, paste(n, "has no Next block"))
    if (n %in% exempt) next
    b <- body_lines(p)
    live <- outside_code(b)
    open <- which(grepl("^\\*\\*Use this when:\\*\\*", b) & live)
    h2 <- which(grepl("^## ", b) & live & outside_div(b))
    if (!length(open)) {
      bad <- c(bad, paste(n, "has no 'Use this when' opener"))
    } else if (length(h2) && open[1L] > h2[1L]) {
      bad <- c(bad, paste(n, "has its 'Use this when' opener after the first section"))
    }
    rt <- grep("^\\*\\*Reading time:\\*\\*", b, value = TRUE)
    if (length(rt) && !all(grepl("^\\*\\*Reading time:\\*\\* [1-9][0-9]* min", rt))) {
      bad <- c(bad, paste(n, "has a malformed reading time"))
    }
  }
  bad
}

# pandoc ids of the headings at `level` ("##" for sections), outside code and outside a ::: div (a callout title is
# not a section and gets no id): an explicit {#id} wins, else lower case, punctuation dropped except _-., spaces to
# hyphens
outside_div <- function(lines) {
  depth <- cumsum(grepl("^:::+ *[{A-Za-z.]", lines)) - cumsum(grepl("^:::+ *$", lines))
  depth <= 0L
}
heading_ids_at <- function(lines, level = "##") {
  h <- lines[outside_code(lines) & outside_div(lines) & grepl(paste0("^", level, " +\\S"), lines)]
  h <- sub(paste0("^", level, " +"), "", h)
  explicit <- grepl("\\{[^}]*#[A-Za-z0-9_.:-]+[^}]*\\}\\s*$", h)
  txt <- gsub("[`*]", "", sub("\\s*\\{[^}]*\\}\\s*$", "", h))
  auto <- gsub("\\s+", "-", gsub("[^a-z0-9_ .-]", "", tolower(txt)))
  ifelse(explicit, sub("^.*\\{[^}]*#([A-Za-z0-9_.:-]+)[^}]*\\}\\s*$", "\\1", h), auto)
}
# explicit ids anywhere (a heading or a div attribute such as `::: {#first-check-your-version .callout-tip}`)
explicit_ids <- function(lines) {
  x <- lines[outside_code(lines)]
  m <- unlist(regmatches(x, gregexpr("\\{[^}]*#[A-Za-z0-9_.:-]+", x)))
  sub("^.*#", "", m)
}
anchor_ids <- function(x) gsub("^\\]\\(#|\\)$", "", unlist(regmatches(x, gregexpr("\\]\\(#[^)]+\\)", x))))

# the Troubleshooting page leads with a table of the most common errors, each row linking to its section, and a
# "Jump to" list that covers every section
trouble_problems <- function(lines) {
  start <- grep("^## Most common errors$", lines)
  if (!length(start)) return("guide-troubleshooting has no 'Most common errors' section")
  h2 <- grep("^## ", lines)
  sec <- lines[start:(c(h2[h2 > start], length(lines) + 1L)[1L] - 1L)]
  rows <- grep("^\\|", sec, value = TRUE)
  rows <- rows[-seq_len(min(2L, length(rows)))]
  bad <- character()
  if (length(rows) < 6L) bad <- c(bad, sprintf("'Most common errors' has %d rows, expected at least 6", length(rows)))
  one_link <- vapply(rows, function(r) length(anchor_ids(r)) == 1L, logical(1))
  if (!all(one_link)) bad <- c(bad, "a 'Most common errors' row lacks exactly one section link")
  ids <- unique(c(heading_ids_at(lines, "##"), heading_ids_at(lines, "###"), explicit_ids(lines)))
  dead <- setdiff(anchor_ids(sec), ids)
  if (length(dead)) bad <- c(bad, paste("dead link near the top:", paste(dead, collapse = ", ")))
  j <- grep("^\\*\\*Jump to:\\*\\*", sec)
  if (!length(j)) return(c(bad, "no 'Jump to' list"))
  k <- j[1L]
  while (k < length(sec) && nzchar(sec[k + 1L])) k <- k + 1L
  miss <- setdiff(setdiff(heading_ids_at(lines, "##"), "most-common-errors"), anchor_ids(sec[j[1L]:k]))
  if (length(miss)) bad <- c(bad, paste("'Jump to' lacks:", paste(miss, collapse = ", ")))
  bad
}

# documentation coverage: every export has an Rd alias
export_problems <- function(namespace, aliases) {
  ex <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", namespace, value = TRUE))
  ex <- gsub("\"", "", ex)
  miss <- setdiff(ex, aliases)
  if (!length(miss)) return(character())
  paste("exports without an Rd alias:", paste(utils::head(miss, 5L), collapse = ", "))
}

test_that("NEWS has a heading for the DESCRIPTION version and no stale wording in a release", {
  skip_if_not(have_tree(), "source tree not available")
  expect_identical(news_problems(read_lines("NEWS.md"), desc_version()), character())
})

test_that("planted defects: the NEWS gate catches a missing heading and stale wording", {
  ok <- c("# medfit 1.2.0", "", "* a feature", "# medfit 1.1.0", "* old, unreleased")
  expect_identical(news_problems(ok, "1.2.0"), character())
  expect_match(news_problems(c("# medfit 1.1.0", "* x"), "1.2.0"), "does not open")
  expect_match(news_problems(c("# medfit 1.2.0", "* (the adapter is unreleased)"), "1.2.0"), "stale wording")
  # a development version may still say it
  expect_identical(news_problems(c("# medfit 1.2.0.9000", "* unreleased"), "1.2.0.9000"), character())
})

test_that("README and articles name the DESCRIPTION version and carry no stale wording", {
  skip_if_not(have_tree(), "source tree not available")
  files <- c(list.files(root_path("vignettes", "articles"), "\\.qmd$", full.names = TRUE), root_path("README.md"))
  one <- function(f) paste(readLines(f, warn = FALSE), collapse = "\n")
  texts <- stats::setNames(lapply(files, one), basename(files))
  expect_identical(prose_problems(texts, desc_version()), character())
})

test_that("planted defects: the prose gate catches a stale version claim and stale wording", {
  expect_identical(prose_problems(list(a = "This site documents medfit 1.2.0."), "1.2.0"), character())
  expect_match(prose_problems(list(a = "This card describes medfit 1.1.0"), "1.2.0"), "DESCRIPTION is 1.2.0")
  expect_match(prose_problems(list(a = "in the development version"), "1.2.0"), "development version")
  expect_identical(prose_problems(list(a = "in the development version"), "1.2.0.9000"), character())
  expect_identical(prose_problems(list(a = "This site documents medfit 1.2.0.9000."), "1.2.0.9000"), character())
  expect_match(prose_problems(list(a = "This site documents medfit 1.2.0."), "1.2.0.9000"), "DESCRIPTION is 1.2.0.9000")
  expect_match(prose_problems(list(a = "This site documents medfit 1.2.0.9000."), "1.2.0"), "DESCRIPTION is 1.2.0")
  # "use medfit X" is a version claim too (the troubleshooting callout once said "use medfit 0.13.0")
  expect_match(prose_problems(list(a = "Examples on this site use medfit 1.1.0."), "1.2.0"), "DESCRIPTION is 1.2.0")
  expect_identical(prose_problems(list(a = "Examples on this site use medfit 1.2.0."), "1.2.0"), character())
  expect_identical(prose_problems(list(a = "Examples need the GitHub build, not CRAN's 0.3.2."), "1.2.0"), character())
})

test_that("README has the What's new block and CITATION takes the DESCRIPTION version", {
  skip_if_not(have_tree(), "source tree not available")
  expect_identical(home_problems(read_lines("README.md"), read_lines("inst", "CITATION"), desc_version()), character())
})

test_that("planted defects: the home gate catches a stale What's new and a hard-coded CITATION version", {
  cit <- "note = sprintf(\"R package version %s\", meta$Version)"
  expect_identical(home_problems("What's new in 1.2.0", cit, "1.2.0"), character())
  expect_match(home_problems("What's new in 1.1.0", cit, "1.2.0"), "What's new in 1.2.0")
  expect_match(home_problems("What's new in 1.2.0", "note = \"R package version 1.1.0\"", "1.2.0"), "CITATION")
})

test_that("CLAUDE.md and .STATUS status lines name the DESCRIPTION version", {
  skip_if_not(have_tree() && file.exists(root_path("CLAUDE.md")) && file.exists(root_path(".STATUS")),
              "CLAUDE.md or .STATUS not available")
  expect_identical(status_problems(read_lines("CLAUDE.md"), read_lines(".STATUS"), desc_version()), character())
})

test_that("planted defects: the status gate catches a stale CLAUDE.md line and a stale .STATUS", {
  cl <- "**Current status:** 2026-11-12: **1.2.0 released** (see above)"
  expect_identical(status_problems(cl, "# 1.2.0 prep", "1.2.0"), character())
  old <- "**Current status:** 2026-10-31: **1.1.0 released**"
  expect_match(status_problems(old, "# 1.2.0", "1.2.0")[1L], "CLAUDE.md")
  expect_match(status_problems(cl, "# 1.1.0 prep", "1.2.0"), ".STATUS")
})

test_that("the FIML caveat is on the home page and on the FIML page", {
  skip_if_not(have_tree(), "source tree not available")
  expect_identical(caveat_problems(read_lines("README.md"), read_lines("vignettes", "articles", "model-fiml.qmd")),
                   character())
})

test_that("planted defects: the caveat gate names the page that lost the sentence", {
  expect_match(caveat_problems("nothing", "not statistically admitted"), "README")
  expect_match(caveat_problems("not statistically admitted", "nothing"), "model-fiml")
})

test_that("model pages follow the template, the navbar is short and its colors are readable", {
  skip_if_not(have_tree() && file.exists(root_path("_pkgdown.yml")), "source tree not available")
  dir <- root_path("vignettes", "articles")
  fs <- list.files(dir, "^model-.*\\.qmd$", full.names = TRUE)
  pages <- stats::setNames(lapply(fs, readLines, warn = FALSE), sub("\\.qmd$", "", basename(fs)))
  expect_identical(page_problems(pages), character())
  yml <- paste(readLines(root_path("_pkgdown.yml"), warn = FALSE), collapse = "\n")
  expect_identical(navbar_problems(yml), character())
  cfg <- yaml::yaml.load(yml)$navbar
  left <- cfg$structure$left
  arts <- sub("\\.qmd$", "", list.files(dir, "\\.qmd$"))
  expect_identical(menu_problems(cfg$components, setdiff(left, "home"), arts), character())
  skip_if_not(file.exists(root_path("pkgdown", "extra.scss")), "extra.scss not available")
  expect_identical(contrast_problems(readLines(root_path("pkgdown", "extra.scss"), warn = FALSE)), character())
})

test_that("planted defects: layout gates catch a missing Next block, shown setup, a long navbar and a pale color", {
  good <- c("#| label: setup", "#| include: false", "library(medfit)", "::: {.next-action}")
  expect_identical(page_problems(list(`model-x` = good)), character())
  expect_match(page_problems(list(`model-x` = good[1:3])), "no Next block")
  expect_match(page_problems(list(`model-x` = good[c(1, 3, 4)])), "setup chunk")
  expect_match(page_problems(list(`model-sem` = "no template yet")), "no Next block")  # no pending list
  expect_match(navbar_problems("left:  [a, b, c, d, e, f, g, h, i]"), "9 items")
  expect_identical(navbar_problems("left:  [a, b, c, d, e, f, g, h]"), character())
  comp <- list(a = list(menu = list(list(href = "articles/x.html"), list(href = "articles/y.html#top"))),
               b = list(menu = list(list(href = "articles/y.html"), list(href = "https://example.org"))))
  expect_identical(menu_problems(comp, c("a", "b"), c("x", "y")), "y is in menus a and b")
  expect_identical(menu_problems(comp, c("a", "b"), c("x", "y"), shared = "y"), character())
  expect_match(menu_problems(comp, c("a", "b"), c("x", "y", "z"), shared = "y"), "in no menu: z")
  expect_match(menu_problems(comp, "a", "x"), "missing article: y")
  expect_match(contrast_problems("a { color: #909294; }"), "below 4.5:1")
  expect_identical(contrast_problems("a { color: #3f4244; }"), character())
})

test_that("non-model articles open with 'Use this when' and end with a Next block; Troubleshooting leads well", {
  skip_if_not(have_tree(), "source tree not available")
  fs <- list.files(root_path("vignettes", "articles"), "\\.qmd$", full.names = TRUE)
  fs <- fs[!startsWith(basename(fs), "model-")]
  pages <- stats::setNames(lapply(fs, readLines, warn = FALSE), sub("\\.qmd$", "", basename(fs)))
  expect_gt(length(pages), 20L)
  expect_true(all(names(opener_exempt) %in% names(pages)))  # an exemption for a page that is gone is stale
  expect_identical(article_problems(pages), character())
  expect_identical(trouble_problems(pages[["guide-troubleshooting"]]), character())
})

test_that("planted defects: the article gate catches a missing opener, a late one, a missing Next block, a bad time", {
  good <- c("---", "title: x", "---", "Intro.", "", "::: {.callout-note}", "**Use this when:** you need x.\\",
            "**Reading time:** 3 min", ":::", "", "## Section", "", "::: {.next-action}", "**Next:** y", ":::")
  expect_identical(article_problems(list(a = good)), character())
  no_open <- good[!grepl("Use this when", good, fixed = TRUE)]
  expect_match(article_problems(list(a = no_open)), "a has no 'Use this when' opener")
  late <- c(good[1:5], "## Section", "", good[6:9], good[13:15])
  expect_match(article_problems(list(a = late)), "after the first section")
  expect_match(article_problems(list(a = good[1:12])), "a has no Next block")
  expect_match(article_problems(list(a = sub("3 min", "0 min", good))), "malformed reading time")
  expect_match(article_problems(list(a = sub("3 min", "soon", good))), "malformed reading time")
  # the explicit exemption skips the opener only: a page without a Next block is still caught
  bare <- no_open[1:11]
  expect_identical(article_problems(list(a = bare), exempt = "a"), "a has no Next block")
  expect_identical(article_problems(list(a = c(bare, "::: {.next-action}")), exempt = "a"), character())
  # an opener inside a code chunk does not count
  fenced <- c(good[1:5], "```", "**Use this when:** x", "```", "## Section", "::: {.next-action}")
  expect_match(article_problems(list(a = fenced)), "has no 'Use this when' opener")
})

test_that("planted defects: the Troubleshooting gate catches dead and missing links and a lost section", {
  skip_if_not(have_tree(), "source tree not available")
  tr <- read_lines("vignettes", "articles", "guide-troubleshooting.qmd")
  expect_identical(trouble_problems(tr), character())
  dead_row <- trouble_problems(sub("(#two-level-mediation)", "\\1-x", tr))  # also breaks the jump link: two problems
  expect_true(any(grepl("dead link near the top: two-level-mediation-x", dead_row, fixed = TRUE)))
  # the callout title is not a section: a link to its auto id is dead unless the div carries the id
  no_id <- sub("{#first-check-your-version .callout-tip}", "{.callout-tip}", tr, fixed = TRUE)
  expect_match(trouble_problems(no_id), "dead link near the top: first-check-your-version")
  jump <- grep("^\\*\\*Jump to:", tr)
  no_jump <- sub("\\| \\[Cluster\\]\\(#cluster-engine\\) ", "", tr)
  expect_match(trouble_problems(no_jump), "'Jump to' lacks: cluster-engine")
  expect_length(jump, 1L)
  new_section <- append(tr, c("## A new section", "", "text", ""), after = length(tr))
  expect_match(trouble_problems(new_section), "'Jump to' lacks: a-new-section")
  renamed <- sub("## Most common errors", "## Common errors", tr, fixed = TRUE)
  expect_match(trouble_problems(renamed), "no 'Most common errors'")
  first_row <- grep("^\\| `object 'mediation_demo'", tr)
  expect_match(trouble_problems(tr[-first_row]), "at least 6")
})

test_that("every export has an Rd alias", {
  skip_if_not(have_tree() && dir.exists(root_path("man")), "man/ not available")
  rd <- list.files(root_path("man"), "\\.Rd$", full.names = TRUE)
  aliases <- unlist(lapply(rd, function(f) {
    l <- readLines(f, warn = FALSE)
    sub("^\\\\alias\\{(.*)\\}$", "\\1", grep("^\\\\alias\\{", l, value = TRUE))
  }))
  expect_identical(export_problems(readLines(root_path("NAMESPACE"), warn = FALSE), aliases), character())
})

test_that("planted defect: the export gate catches an undocumented export", {
  expect_identical(export_problems("export(a)", "a"), character())
  expect_match(export_problems(c("export(a)", "export(b)"), "a"), "without an Rd alias: b")
})

# ADR-engine-vocabulary V-8 step 2: the sem engine articles were renamed in 0.18.0. Every old article address needs a
# `redirects:` entry to an article that exists, and the local redirect template must carry the #fragment
# (pkgdown's default meta refresh drops it).
renamed_articles <- c(
  "model-native", "model-native-latent", "model-native-constraints", "model-native-multi", "model-native-factors",
  "native-guide", "native-quickstart", "native-tutorial", "native-defaults-0-15"
)
redirect_problems <- function(redirects, articles, template) {
  from <- vapply(redirects, function(r) as.character(r[[1L]]), "")
  to <- vapply(redirects, function(r) as.character(r[[2L]]), "")
  out <- character()
  for (old in renamed_articles) {
    i <- match(sprintf("articles/%s.html", old), from)
    if (is.na(i)) {
      out <- c(out, sprintf("no redirect for articles/%s.html", old))
      next
    }
    target <- sub("^articles/(.*)\\.html$", "\\1", to[i])
    if (!target %in% articles || target %in% renamed_articles) {
      out <- c(out, sprintf("articles/%s.html redirects to a missing article: %s", old, to[i]))
    }
    if (old %in% articles) out <- c(out, sprintf("old article %s.qmd still exists", old))
  }
  txt <- paste(template, collapse = "\n")
  if (!grepl("location.hash", txt, fixed = TRUE) || !grepl("{{{url}}}", txt, fixed = TRUE)) {
    out <- c(out, "layout-redirect.html does not append location.hash to {{{url}}}")
  }
  out
}

test_that("every renamed sem engine article redirects, with its #fragment, to an existing article", {
  skip_if_not(have_tree() && file.exists(root_path("_pkgdown.yml")), "source tree not available")
  skip_if_not_installed("yaml")
  tpl <- root_path("pkgdown", "templates", "layout-redirect.html")
  expect_true(file.exists(tpl))
  redirects <- yaml::read_yaml(root_path("_pkgdown.yml"))$redirects
  articles <- sub("\\.qmd$", "", list.files(root_path("vignettes", "articles"), "\\.qmd$"))
  expect_identical(redirect_problems(redirects, articles, readLines(tpl, warn = FALSE)), character())
})

test_that("planted defects: the redirect gate catches a missing redirect, a bad target and a hash-dropping template", {
  articles <- c("model-sem", "model-sem-latent", "model-sem-constraints", "model-sem-multi", "model-sem-factors",
                "sem-guide", "sem-quickstart", "sem-tutorial", "sem-defaults-0-15")
  good <- Map(function(o, n) c(sprintf("articles/%s.html", o), sprintf("articles/%s.html", n)),
              renamed_articles, articles)
  tpl <- 'window.location.replace("{{{url}}}" + window.location.hash);'
  expect_identical(redirect_problems(unname(good), articles, tpl), character())
  expect_match(redirect_problems(unname(good[-6L]), articles, tpl), "no redirect for articles/native-guide.html")
  bad <- good
  bad[[1L]][2L] <- "articles/model-nowhere.html"
  expect_match(redirect_problems(unname(bad), articles, tpl), "missing article")
  expect_match(redirect_problems(unname(good), c(articles, "native-guide"), tpl), "still exists")
  expect_match(redirect_problems(unname(good), articles, '<meta http-equiv="refresh" content="0;URL={{{url}}}" />'),
               "location.hash")
})
