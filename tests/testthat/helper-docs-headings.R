# The anchor pandoc gives a heading line (text after the `#`s, as written): an explicit `{#id}`
# attribute wins, as in `## New text {#old-id}`; otherwise the auto identifier (lowercase,
# backticks and punctuation dropped, underscores, hyphens and periods kept, spaces to hyphens,
# a leading number and dot dropped). A rename that keeps the old anchor uses the explicit form.
docs_heading_anchor <- function(h) {
  explicit <- regmatches(h, regexpr("\\{[^}]*#[A-Za-z0-9_.:-]+[^}]*\\}\\s*$", h))
  if (length(explicit)) return(sub("^.*#([A-Za-z0-9_.:-]+)[^}]*\\}\\s*$", "\\1", explicit))
  h <- sub("^[0-9]+\\.\\s*", "", h)
  h <- gsub("`", "", tolower(h))
  h <- gsub("[^a-z0-9 _.-]", "", h)
  gsub(" +", "-", trimws(h))
}
