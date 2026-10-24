# Called by .github/workflows/risk-tier.yaml:  Rscript tests/sim/risk-tier.R <changed-files.txt> <body.txt> <head-ref>
# Exits 1 when the PR is high-risk and its checklist is incomplete; prints what to add.
args <- commandArgs(trailingOnly = TRUE)
file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
here <- if (length(file_arg)) dirname(sub("^--file=", "", file_arg[1L])) else "tests/sim"
source(file.path(here, "risk-lib.R"))
changed <- readLines(args[1L], warn = FALSE)
body <- paste(readLines(args[2L], warn = FALSE), collapse = "\n")
res <- risk_check(changed, readLines(file.path(here, "risk-files.txt"), warn = FALSE), body, args[3L])
if (!res$high) {
  cat("risk-tier: low risk (no optimizer file changed, or a release PR); no checklist needed\n")
  quit(status = 0L)
}
cat("risk-tier: HIGH risk; optimizer files changed:\n", paste0("  ", res$files, "\n"), sep = "")
if (!length(res$missing)) {
  cat("risk-tier: the admission checklist is complete\n")
  quit(status = 0L)
}
cat("risk-tier: the PR body needs a line for each of these admission checks, ticked ('- [x] N. ...') or\n",
    "'- [ ] N. n/a: <reason>':\n", sep = "")
for (n in res$missing) cat(sprintf("  %d. %s\n", n, risk_items[n]))
quit(status = 1L)
