# Muffle only the warnings whose message contains `pattern` (a fixed string); any other warning still surfaces, so a
# new warning in the code under test is not hidden. Use it where a test provokes a known, expected advisory (a
# disagreeing-starts notice, a collation request the OS cannot honor, an all-missing row that lavaan drops).
muffle_warnings_matching <- function(expr, pattern) {
  withCallingHandlers(expr, warning = function(w) {
    if (grepl(pattern, conditionMessage(w), fixed = TRUE)) invokeRestart("muffleWarning")
  })
}
