# Builders for the comparison-engine tests: an injected reference (medfit's result) and injected engine runs, so the
# detection rules of .lr_assess() are tested without OpenMx or lavaan (#249, plan T1). `fit` is the unrestricted
# discrepancy on the LR scale; `residual` is |a*b| of the returned fit and `residual_scale` the natural unit of that
# product (the adapters compute it from the data), so feasibility does not depend on the units of the variables.

lr_ref <- function(lr = 0.5, accepted = TRUE, est = c(a = 0.1, b = 0.2, cp = 0.3), fit = 3.2) {
  list(lr = lr, accepted = accepted, est = est, fit = fit)
}

lr_run <- function(start = "default", lr = 0.5, converged = TRUE, residual = 0, residual_scale = 1,
                   jac_zero_at_start = NA) {
  list(start = start, lr = lr, converged = converged, residual = residual, residual_scale = residual_scale,
       jac_zero_at_start = jac_zero_at_start)
}

lr_engine <- function(engine = "openmx", runs = list(lr_run()), est = c(a = 0.1, b = 0.2, cp = 0.3),
                      version = "9.9.9", fit = 3.2) {
  list(engine = engine, version = version, est = est, fit = fit, runs = runs)
}
