# Package Initialization
#
# This file contains .onLoad() for dynamic S7/S4 dispatch registration
# for suggested packages (lavaan, OpenMx)
#
# Note: S7 classes are registered with S4 in classes.R immediately after
# their definitions to avoid loading order issues.

.onLoad <- function(libname, pkgname) {
  # Note: S7 classes are registered with S4 in classes.R using S7::S4_register()
  # This happens immediately after class definitions to ensure proper loading.
  #
  # S7::methods_register() is not needed here because:
  # 1. S7 methods are defined at package build time, not load time
  # 2. Calling it in .onLoad() causes errors because classes aren't loaded yet
  # 3. S7 method dispatch works automatically after S4 registration

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
