lib <- normalizePath(commandArgs(trailingOnly = TRUE)[1L], winslash = "/")
stopifnot(!isNamespaceLoaded("medfit"), packageVersion("S7") == "1.0.0")
ns <- loadNamespace("medfit", lib.loc = lib)
stopifnot(
  isNamespaceLoaded("medfit"),
  packageVersion("medfit", lib.loc = lib) == "0.3.2",
  identical(normalizePath(getNamespaceInfo(ns, "path"), winslash = "/"), file.path(lib, "medfit")),
  as.character(getNamespaceVersion("S7")) == "1.0.0"
)
unions <- c("medfit_numeric", "medfit_numeric_or_NULL", "medfit_list_or_NULL",
            "medfit_data_frame_or_NULL", "medfit_call_or_NULL")
registered <- lapply(unions, methods::getClassDef, where = ns, inherits = FALSE)
stopifnot(all(vapply(registered, methods::isClassUnion, logical(1))))
cat("PASS: fresh loadNamespace() of patched medfit 0.3.2 with S7 1.0.0; all five S4 unions registered\n")
