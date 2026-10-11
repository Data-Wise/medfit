# Shared data and lavaan fits for test-probmed-names.R (issue #106).
#
# Same generator as the probmed reproduction in the issue: binary treatment,
# one observed Gaussian mediator, n = 400.

probmed_names_data <- function(n = 400L, seed = 1L) {
  set.seed(seed)
  X <- stats::rbinom(n, 1, 0.5)
  C <- stats::rnorm(n)
  M <- 1 + 0.5 * X + 0.3 * C + stats::rnorm(n)
  Y <- 2 + 0.4 * M + 0.2 * X + 0.2 * C + stats::rnorm(n)
  data.frame(X = X, M = M, Y = Y, C = C)
}

# Named list of lavaan fits of the simple single-mediator model, one per
# specification the alias rows must survive. Requires lavaan.
probmed_names_fits <- function(data = probmed_names_data()) {
  m_plain <- "M ~ X\n Y ~ M + X"
  list(
    unlabeled = lavaan::sem(m_plain, data = data),
    labeled = lavaan::sem("M ~ a*X\n Y ~ b*M + cp*X", data = data),
    meanstructure = lavaan::sem(m_plain, data = data, meanstructure = TRUE),
    free_x = lavaan::sem(m_plain, data = data, fixed.x = FALSE),
    covariate = lavaan::sem("M ~ X + C\n Y ~ M + X + C", data = data)
  )
}
