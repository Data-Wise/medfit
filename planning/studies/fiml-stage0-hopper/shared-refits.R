# STUDY-ONLY patch (never enters R/, dev, main or a release branch): share one set of row refits across
# the NIE/NDE/TE calls of the same dataset. Valid only because a call's resamples depend on (seed, B, n)
# alone, so the three single-effect calls use identical rows and therefore identical refits.
# Mechanism: wrap medfit:::.bootstrap_fiml_refit in-process with a cache keyed by the resampled rows;
# a failed refit's condition is cached and re-signalled, so failure records are identical too.
study_shared_refits_install <- function(key_fun = function(rows) rlang::hash(rows)) {
  orig <- get(".bootstrap_fiml_refit", envir = asNamespace("medfit"))
  cache <- new.env(parent = emptyenv())
  wrapped <- function(source, rows) {
    k <- paste(rlang::hash(source@data), key_fun(rows), sep = "|")
    hit <- cache[[k]]
    if (is.null(hit)) {
      hit <- tryCatch(list(ok = TRUE, value = orig(source, rows)),
                      error = function(e) list(ok = FALSE, value = e))
      cache[[k]] <- hit
    }
    if (hit$ok) hit$value else stop(hit$value)
  }
  utils::assignInNamespace(".bootstrap_fiml_refit", wrapped, ns = "medfit")
  list(reset = function() rm(list = ls(cache, all.names = TRUE), envir = cache),
       size = function() length(ls(cache, all.names = TRUE)),
       restore = function() utils::assignInNamespace(".bootstrap_fiml_refit", orig, ns = "medfit"),
       orig = orig)
}
