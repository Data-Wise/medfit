# Package Initialization
#
# This file contains .onLoad() and .onAttach() hooks for S7 method registration
#
# Note: S7 classes are registered with S4 in classes.R immediately after
# their definitions using S7::S4_register()

# Track whether lavaan method has been registered to avoid duplicate registration
.medfit_env <- new.env(parent = emptyenv())
.medfit_env$lavaan_registered <- FALSE

.onLoad <- function(libname, pkgname) {
  # Register extraction methods for suggested packages (S4 classes)
  # Note: This must happen in .onLoad() for S4 compatibility

  # Register lavaan method if available (suppress messages)
  if (requireNamespace("lavaan", quietly = TRUE)) {
    tryCatch({
      suppressMessages(.register_lavaan_method())
      .medfit_env$lavaan_registered <- TRUE
    }, error = function(e) {
      # Silently fail if registration fails (e.g., lavaan not fully loaded)
      invisible(NULL)
    })
  }

  # Note: OpenMx integration postponed to future release
}

.onAttach <- function(libname, pkgname) {
  # Register S7 methods for dispatch
  # CRITICAL: S7 requires methods_register() to be called when the package loads
  # Unlike S3/S4, S7 uses dynamic run-time registration, not the NAMESPACE file
  # This ensures print, summary, and other S7 methods work in installed packages
  #
  # MUST be in .onAttach() not .onLoad() because:
  # - .onLoad() runs BEFORE R files are sourced (classes don't exist yet)
  # - .onAttach() runs AFTER R files are sourced (classes are defined and registered)
  #
  # Wrapped in tryCatch because namespace may be locked during package installation
  # In that case, methods are still available via S4_register() which happens in classes.R

  tryCatch(
    suppressMessages(S7::methods_register()),
    error = function(e) {
      # Silently fail if namespace is locked (e.g., during package installation)
      # Methods will still work via S4_register() in most contexts
      invisible(NULL)
    }
  )

  # Also try to register lavaan method in .onAttach() as fallback
  # This handles cases where lavaan wasn't available during .onLoad()
  # Only register if not already registered
  if (!.medfit_env$lavaan_registered &&
      requireNamespace("lavaan", quietly = TRUE)) {
    tryCatch({
      suppressMessages(.register_lavaan_method())
      .medfit_env$lavaan_registered <- TRUE
    }, error = function(e) {
      invisible(NULL)
    })
  }
}
