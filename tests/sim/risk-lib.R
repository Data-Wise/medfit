# Risk tier of a pull request (plan Q-2 and review R-1): a PR is high-risk when it changes a file the optimizer sees
# (tests/sim/risk-files.txt). A high-risk PR must carry the seven-check admission checklist in its body, each item
# ticked or marked "n/a: <reason>"; the `risk-tier` workflow runs this, because a test cannot see a diff.

risk_items <- c("independent oracle", "reliability cell", "planted defect", "metamorphic invariance", "fault injection",
                "registration", "platform run")

risk_or <- function(a, b) if (is.null(a) || is.na(a)) b else a

risk_changed <- function(changed, risk_files) intersect(changed, risk_files)

# the checklist lines of a PR body -> the admission numbers that are ticked or n/a with a reason
risk_checked <- function(body) {
  lines <- trimws(unlist(strsplit(risk_or(body, ""), "\r?\n")))
  ok <- integer()
  for (n in seq_along(risk_items)) {
    ticked <- grepl(sprintf("^[-*] \\[[xX]\\] *%d[.)]", n), lines)
    na <- grepl(sprintf("^[-*] \\[ ?\\] *%d[.)] *n/a: *\\S", n), lines)
    if (any(ticked) || any(na)) ok <- c(ok, n)
  }
  ok
}

# list(high = logical, files = changed risk files, missing = admission items without a tick or an n/a reason)
risk_check <- function(changed, risk_files, body, head_ref = "") {
  files <- risk_changed(changed, risk_files)
  if (identical(head_ref, "dev") || !length(files)) return(list(high = FALSE, files = character(), missing = integer()))
  list(high = TRUE, files = files, missing = setdiff(seq_along(risk_items), risk_checked(body)))
}
