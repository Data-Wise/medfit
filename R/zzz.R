# Package Initialization
#
# This file contains .onLoad() hook for S7 method registration
#
# S7 Method Registration:
# - S7 uses dynamic run-time registration, not the NAMESPACE file (unlike S3/S4)
# - S4_register() must be called for each S7 class before methods_register()
# - methods_register() must be called in .onLoad() per S7 documentation
# - See: https://rconsortium.github.io/S7/articles/packages.html
#
# Note on "Overwriting method" messages during development:
# - This is a known issue with devtools::load_all() (GitHub issue #474)
# - Methods get registered twice: during sourcing and in .onLoad()
# - This does NOT affect installed packages, only development workflows
# - See: https://github.com/RConsortium/S7/issues/474

.onLoad <- function(libname, pkgname) {
  # Register S7 classes with S4 system
  # This must happen before methods_register() to avoid

  # "Class has not been registered with S4" errors
  S7::S4_register(MediationData)
  S7::S4_register(SerialMediationData)
  S7::S4_register(BootstrapResult)

  # Register S7 methods for dispatch
  # This is required for methods on generics from other packages
  S7::methods_register()

  # Register extraction methods for suggested packages (S4 classes)
  # lavaan is in Suggests, so we register dynamically if available
  if (requireNamespace("lavaan", quietly = TRUE)) {
    tryCatch({
      .register_lavaan_method()
    }, error = function(e) {
      # Silently fail if registration fails (e.g., lavaan not fully loaded)
      invisible(NULL)
    })
  }

  # Note: OpenMx integration postponed to future release
}
