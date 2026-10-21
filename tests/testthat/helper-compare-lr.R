# Builders for the comparison-engine tests: an injected reference (medfit's result) and injected engine runs, so the
# detection rules of .lr_assess() are tested without OpenMx or lavaan (#249, plan T1).

lr_ref <- function(lr = 0.5, accepted = TRUE, est = c(a = 0.1, b = 0.2, cp = 0.3)) {
  list(lr = lr, accepted = accepted, est = est)
}

lr_run <- function(start = "default", lr = 0.5, converged = TRUE, residual = 0, jac_zero_at_start = NA) {
  list(start = start, lr = lr, converged = converged, residual = residual, jac_zero_at_start = jac_zero_at_start)
}

lr_engine <- function(engine = "openmx", runs = list(lr_run()), est = c(a = 0.1, b = 0.2, cp = 0.3),
                      version = "9.9.9") {
  list(engine = engine, version = version, est = est, runs = runs)
}
