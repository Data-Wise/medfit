# Shared fixtures for the fixed_x tests (0.9.0, plan tasks V1-V8). The contract these tests pin:
#   fit_sem(..., fixed_x = FALSE | TRUE | <names>); resolved names in `fit@internals$fixed_x`;
#   `fit@table$fixed_x` (logical flag, separate from a user `0*`); fixed rows carry est = the sample moment and
#   se NA; `fit@theta`, `vcov()`, `coef()` exclude them; `glance()$fixed_x` is the comma-joined names ("" if none).

fx_syntax <- paste0(
  "mediator1 ~ a*treatment + covariate1 + covariate2\n",
  "outcome ~ b*mediator1 + cp*treatment + covariate1 + covariate2"
)
fx_exo <- c("treatment", "covariate1", "covariate2")

# covr rewrites the package code a mutation test edits, so those tests run outside coverage only.
fx_skip_covr <- function() {
  testthat::skip_if(identical(Sys.getenv("R_COVR"), "true"), "covr instruments the code the mutation edits")
}

fx_data <- function() medfit::mediation_demo

# Estimates and standard errors of the structural parameters two fits share. The exogenous (co)variances and means
# are left out: a still-free one has a conditional SE once its neighbors are fixed, which is not the claim.
fx_shared <- function(free, fixed, exo = fx_exo) {
  shared <- intersect(names(free@theta), names(fixed@theta))
  alt <- paste(exo, collapse = "|")
  shared <- shared[!grepl(paste0("^(", alt, ")(~~(", alt, ")|~1)$"), shared)]
  list(
    names = shared,
    est = list(free@theta[shared], fixed@theta[shared]),
    se = list(sqrt(diag(free@vcov))[shared], sqrt(diag(fixed@vcov))[shared])
  )
}

# Number of exogenous moment parameters a fixed set removes (no mean structure): a variance per variable plus a
# covariance per pair with another exogenous variable (selected or not).
fx_n_removed <- function(selected, exo = fx_exo, mean = FALSE) {
  k <- length(selected)
  others <- length(setdiff(exo, selected))
  as.integer(k + k * (k - 1) / 2 + k * others + if (mean) k else 0)
}
