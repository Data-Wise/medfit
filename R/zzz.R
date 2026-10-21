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

# Internal mutable package state (e.g. one-time user notifications). Parented on
# `emptyenv()` so nothing leaks in from the global environment.
.medfit_state <- new.env(parent = emptyenv())

# Emit `msg` via message() at most once per session, keyed by `id`. Used for
# advisory nudges that would otherwise spam tight refit loops (e.g. bootstrap).
.notify_once <- function(id, msg) {
  if (isTRUE(.medfit_state[[id]])) {
    return(invisible(FALSE))
  }
  .medfit_state[[id]] <- TRUE
  message(msg)
  invisible(TRUE)
}

# The IPW nudge, shared by the glm and native engines: model-based SEs are not valid under inverse-probability
# weighting. Once per session so tight refit loops are not spammed.
.notify_ipw_model_se <- function() {
  .notify_once(
    "ipw_model_se",
    paste0(
      "medfit: `weights` supplied with `se_type = \"model\"`. ",
      "Model-based standard errors are not valid under inverse-probability ",
      "weighting; pass `se_type = \"sandwich\"` for robust (HC) SEs. ",
      "(Shown once per session.)"
    )
  )
}

# Show-method body for S7 classes whose `show` is registered in `.onLoad()`.
# Kept as a named top-level function (not an inline body in `.onLoad`) so the
# `print()` call is not seen as a startup message by R CMD check.
.show_via_print <- function(object) {
  print(object)
}

.onLoad <- function(libname, pkgname) {
  .register_s4_unions()
  # Register S7 classes with S4 system
  # This must happen before methods_register() to avoid

  # "Class has not been registered with S4" errors
  S7::S4_register(MediationData)
  S7::S4_register(SerialMediationData)
  S7::S4_register(ParallelMediationData)
  S7::S4_register(InteractionMediationData)
  S7::S4_register(JointMediationData)
  S7::S4_register(ClusterMediationData)
  S7::S4_register(BootstrapResult)
  S7::S4_register(SEMFit)

  # Register S7 methods for dispatch
  # This is required for methods on generics from other packages. Development S7 (> 0.2.2) replaces
  # `methods_register()` with `S7_on_load()`; S7 0.2.2 and earlier have only the old function.
  if ("S7_on_load" %in% getNamespaceExports("S7")) {
    getExportedValue("S7", "S7_on_load")()
  } else {
    S7::methods_register()
  }

  # `show` is an S4 generic; registering an S7 method for it requires the class
  # to be S4-registered first, so it cannot live at source time in classes.R
  # (where it would run before .onLoad). Register it here, after S4_register().
  # Bind the generic to a local symbol first: the `method(...) <-` replacement
  # form cannot take a namespaced LHS (`methods::show`). The method body lives in
  # the top-level helper `.show_via_print()` so no literal `print()` call sits in
  # `.onLoad` (which R CMD check would flag as a startup message).
  show <- methods::show
  S7::method(show, ParallelMediationData) <- .show_via_print
  S7::method(show, InteractionMediationData) <- .show_via_print
  S7::method(show, JointMediationData) <- .show_via_print
  S7::method(show, ClusterMediationData) <- .show_via_print
  S7::method(show, SEMFit) <- .show_via_print

  # Explicitly register the S3 print method for `mediation_effect`.
  #
  # `mediation_effect` is a lightweight S3 class layered on top of `numeric`
  # (objects returned by nie()/nde()/te()/pm()). Because `print` is an
  # internal generic and the object's implicit class includes the base
  # `numeric` type, S3 dispatch to `print_mediation_effect` can fail to find
  # the method via the package's own method table -- `print()` then silently
  # falls back to `print.default`, showing the bare numeric value and the
  # raw class/type attributes instead of the formatted label.
  #
  # Registering the method here, into the standard S3 dispatch table,
  # guarantees `print()` reaches `print_mediation_effect` regardless of how
  # the package is loaded (installed or via load_all()).
  registerS3method("print", "mediation_effect", print_mediation_effect)
  registerS3method("print", "medfit_lr_comparison", print_lr_comparison)

  # Same issue for the `summary.*` print methods. `summary()` on the S7 data
  # objects returns a plain S3-classed list (e.g. class "summary_MediationData"),
  # but the `S3method(print, summary.*)` NAMESPACE directives are not activated
  # once `print` participates in S7 dispatch -- `print(summary(x))` then falls
  # back to `print.default` and dumps the raw list instead of the formatted
  # summary. Registering them here restores dispatch (installed or load_all()).
  registerS3method("print", "summary_MediationData", print_summary_mediation_data)
  registerS3method("print", "summary_BootstrapResult", print_summary_bootstrap_result)
  registerS3method("print", "summary_SerialMediationData", print_summary_serial_mediation_data)
  registerS3method("print", "summary_JointMediationData", print_summary_joint_mediation_data)
  registerS3method("print", "summary_ClusterMediationData", print_summary_cluster_mediation_data)
  registerS3method("print", "summary_SEMFit", print_summary_semfit)

  # tidy()/glance() methods for S7 objects (function names avoid dots, so NAMESPACE directives cannot register them)
  registerS3method("tidy", "S7_object", tidy_s7_object, envir = asNamespace("generics"))
  registerS3method("glance", "S7_object", glance_s7_object, envir = asNamespace("generics"))

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

  # Same for lme4's merMod (cluster-level mediation from mixed models)
  if (requireNamespace("lme4", quietly = TRUE)) {
    tryCatch({
      .register_lmer_method()
    }, error = function(e) {
      invisible(NULL)
    })
  }

  # Note: OpenMx integration postponed to future release
}

# Remove the method registrations and foreign generic aliases when the namespace unloads (S7 > 0.2.2 only).
.onUnload <- function(libpath) {
  if ("S7_on_unload" %in% getNamespaceExports("S7")) {
    getExportedValue("S7", "S7_on_unload")()
  }
}

# Build-time hook that records the `method<-()` placeholders (S7 > 0.2.2 only).
if ("S7_on_build" %in% getNamespaceExports("S7")) {
  getExportedValue("S7", "S7_on_build")()
}
