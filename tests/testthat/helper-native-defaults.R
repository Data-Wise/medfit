# 0.14.0 default-change warning (plan T5). The suite has hundreds of fit_sem() calls that leave fixed_x and
# meanstructure unset; marking both warnings as already shown keeps them quiet. test-native-defaults.R resets the
# state inside each test with local_native_defaults_unshown(), which restores it on exit.
medfit:::.native_defaults_reset(shown = TRUE)

local_native_defaults_unshown <- function(env = parent.frame()) {
  old <- medfit:::.native_defaults_state()
  medfit:::.native_defaults_reset(shown = FALSE)
  withr::defer(medfit:::.native_defaults_reset(shown = old), envir = env)
  invisible(old)
}

# Reporter check: testthat reports any test that leaves the state changed (a reset without restore would let the
# class reach the rest of the suite).
testthat::set_state_inspector(function() {
  list(medfit_native_defaults_shown = medfit:::.native_defaults_state())
})
