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
  S7::S4_register(ParallelMediationData)
  S7::S4_register(InteractionMediationData)
  S7::S4_register(BootstrapResult)

  # Register S7 methods for dispatch
  # This is required for methods on generics from other packages
  S7::methods_register()

  # `show` is an S4 generic; registering an S7 method for it requires the class
  # to be S4-registered first, so it cannot live at source time in classes.R
  # (where it would run before .onLoad). Register it here, after S4_register().
  # Bind the generic to a local symbol first: the `method(...) <-` replacement
  # form cannot take a namespaced LHS (`methods::show`).
  show <- methods::show
  S7::method(show, ParallelMediationData) <- function(object) {
    print(object)
  }
  S7::method(show, InteractionMediationData) <- function(object) {
    print(object)
  }

  # Explicitly register the S3 print method for `mediation_effect`.
  #
  # `mediation_effect` is a lightweight S3 class layered on top of `numeric`
  # (objects returned by nie()/nde()/te()/pm()). Because `print` is an
  # internal generic and the object's implicit class includes the base
  # `numeric` type, S3 dispatch to `print.mediation_effect` can fail to find
  # the method via the package's own method table -- `print()` then silently
  # falls back to `print.default`, showing the bare numeric value and the
  # raw class/type attributes instead of the formatted label.
  #
  # Registering the method here, into the standard S3 dispatch table,
  # guarantees `print()` reaches `print.mediation_effect` regardless of how
  # the package is loaded (installed or via load_all()).
  registerS3method("print", "mediation_effect", print.mediation_effect)

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
