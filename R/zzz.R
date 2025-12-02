# Package Initialization
#
# This file contains .onLoad() for dynamic S7/S4 dispatch registration
# for suggested packages (lavaan, OpenMx)
#
# Note: S7 classes are registered with S4 in classes.R immediately after
# their definitions to avoid loading order issues.

.onLoad <- function(libname, pkgname) {
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
