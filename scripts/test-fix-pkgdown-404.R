source("scripts/fix-pkgdown-404.R")
path <- tempfile(fileext = ".html")
writeLines(paste0(
  '<html><script src="https://example.org/NA">window.MathJax={};</script>',
  '<script src="https://example.org/real.js"></script>',
  '<script src="https://example.org/NA">fallback();</script></html>'
), path)
stopifnot(fix_pkgdown_404(path) == 1L, fix_pkgdown_404(path) == 0L)
scripts <- xml2::xml_find_all(xml2::read_html(path), ".//script")
stopifnot(
  is.na(xml2::xml_attr(scripts[[1]], "src")),
  xml2::xml_text(scripts[[1]]) == "window.MathJax={};",
  xml2::xml_attr(scripts[[2]], "src") == "https://example.org/real.js",
  xml2::xml_attr(scripts[[3]], "src") == "https://example.org/NA"
)
unlink(path)
cat("404 repair: PASS\n")
