# Package Initialization
#
# This file contains .onLoad() for dynamic S7/S4 dispatch registration
# for suggested packages (lavaan, OpenMx)
#
# Note: S7 classes are registered with S4 in classes.R immediately after
# their definitions to avoid loading order issues.

.onLoad <- function(libname, pkgname) {
  # Note: S7 classes are registered with S4 in classes.R using S7::S4_register()
  # This happens immediately after class definitions during package loading.

  # S7::methods_register() is called in .onAttach() instead of here
  # because .onLoad() runs before R files are sourced, so classes don't exist yet.

  # Future: Register extraction methods for suggested packages
  # if (requireNamespace("lavaan", quietly = TRUE)) {
  #   lavaan_class <- S7::as_class(methods::getClass("lavaan", where = "lavaan"))
  #   S7::method(extract_mediation, lavaan_class) <- extract_mediation_lavaan
  # }
  #
  # if (requireNamespace("OpenMx", quietly = TRUE)) {
  #   # Similar pattern for OpenMx
  # }
}

.onAttach <- function(libname, pkgname) {
  # Register S7 methods for dispatch
  # This is called AFTER R files are sourced, so classes are defined and registered
  # Required for S7 methods on base R generics (print, summary, show) to work
  # in installed package context

  # Wrap in tryCatch because namespace may be locked during devtools operations
  tryCatch(
    S7::methods_register(),
    error = function(e) {
      # Silently fail if namespace is locked (e.g., during devtools::load_all)
      # Methods will still work via S4_register() in most contexts
      invisible(NULL)
    }
  )
}
