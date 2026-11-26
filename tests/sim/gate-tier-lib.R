# The local-only gate tier (tests/sim/gates-local-only.txt). Sourced by run-gates.R and scripts/gate-shards.R.
gate_local_only <- function(path = file.path("tests", "sim", "gates-local-only.txt")) {
  x <- trimws(sub("#.*$", "", readLines(path, warn = FALSE)))
  x[nzchar(x)]
}
gate_drop_local_only <- function(spec, local_only, enabled) {
  if (enabled) spec else spec[!spec$gate %in% local_only, , drop = FALSE]
}
