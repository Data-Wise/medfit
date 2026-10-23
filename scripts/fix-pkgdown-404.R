# pkgdown 2.2.1 makes missing inline-script src attributes absolute as /NA.
# Run after the site build; preserve real external scripts and inline content.
fix_pkgdown_404 <- function(path) {
  html <- xml2::read_html(path)
  scripts <- xml2::xml_find_all(html, ".//script[@src]")
  src <- xml2::xml_attr(scripts, "src")
  inline <- grepl("window.MathJax", xml2::xml_text(scripts), fixed = TRUE)
  broken <- !is.na(src) & grepl("/NA$", src) & inline
  if (any(broken)) {
    xml2::xml_attr(scripts[broken], "src") <- NULL
    xml2::write_html(html, path)
  }
  invisible(sum(broken))
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  root <- if (length(args)) args[[1L]] else "docs"
  pages <- list.files(root, pattern = "^404[.]html$", recursive = TRUE,
                      full.names = TRUE)
  for (page in pages) fix_pkgdown_404(page)
}
