# Extracted from test-docs-release.R:289

# prequel ----------------------------------------------------------------------
root_path <- function(...) testthat::test_path("..", "..", ...)
have_tree <- function() {
  file.exists(root_path("DESCRIPTION")) && dir.exists(root_path("vignettes", "articles")) &&
    file.exists(root_path("NEWS.md"))
}
read_lines <- function(...) readLines(root_path(...), warn = FALSE)
desc_version <- function() read.dcf(root_path("DESCRIPTION"), fields = "Version")[1L, 1L]
is_release <- function(v) length(strsplit(v, "[.-]")[[1L]]) == 3L
stale_words <- "development version|unreleased"
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
caveat <- "not statistically admitted"
caveat_problems <- function(readme, fiml) {
  as.character(c(
    if (!any(grepl(caveat, readme, fixed = TRUE))) "README lacks the FIML caveat",
    if (!any(grepl(caveat, fiml, fixed = TRUE))) "model-fiml.qmd lacks the FIML caveat"
  ))
}
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
explicit_ids <- function(lines) {
  x <- lines[outside_code(lines)]
  m <- unlist(regmatches(x, gregexpr("\\{[^}]*#[A-Za-z0-9_.:-]+", x)))
  sub("^.*#", "", m)
}
anchor_ids <- function(x) gsub("^\\]\\(#|\\)$", "", unlist(regmatches(x, gregexpr("\\]\\(#[^)]+\\)", x))))
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
export_problems <- function(namespace, aliases) {
  ex <- sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", namespace, value = TRUE))
  ex <- gsub("\"", "", ex)
  miss <- setdiff(ex, aliases)
  if (!length(miss)) return(character())
  paste("exports without an Rd alias:", paste(utils::head(miss, 5L), collapse = ", "))
}

# test -------------------------------------------------------------------------
skip_if_not(have_tree() && file.exists(root_path("CLAUDE.md")) && file.exists(root_path(".STATUS")),
              "CLAUDE.md or .STATUS not available")
expect_identical(status_problems(read_lines("CLAUDE.md"), read_lines(".STATUS"), desc_version()), character())
