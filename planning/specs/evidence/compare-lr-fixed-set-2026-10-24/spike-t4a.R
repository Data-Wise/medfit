# T4a spike: can compare_lr() represent a fit's fixed exogenous set (all, a named subset, a lenient subset) and a
# saturated mean structure in lavaan and OpenMx, so its LR equals medfit's own deviance difference?
suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages({library(lavaan); library(OpenMx)})
mxOption(NULL, "Optimality tolerance", 1e-12); mxOption(NULL, "Feasibility tolerance", 1e-12)
d <- mediation_demo
n <- nrow(d)
vars <- c("treatment", "covariate1", "mediator1", "outcome")
S <- cov(d[, vars]) * (n - 1) / n            # ML (N denominator) sample moments
mu <- colMeans(d[, vars])
base <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + cp*treatment + covariate1\n"
null <- "b == 0"
fmt <- function(x) formatC(x, digits = 17, format = "g")

med_lr <- function(fx, ms, extra = "") {
  f1 <- fit_sem(paste0(base, extra), d, fixed_x = fx, meanstructure = ms)
  f0 <- fit_sem(paste0(base, extra, null), d, fixed_x = fx, meanstructure = ms)
  n * (f0@f - f1@f)
}

# lavaan with fixed.x = FALSE and the fixed set written as fixed rows at the sample moments
fixed_rows <- function(set, ms) {
  rows <- character()
  for (i in seq_along(set)) for (j in i:length(set))
    rows <- c(rows, sprintf("%s ~~ %s*%s", set[i], fmt(S[set[i], set[j]]), set[j]))
  if (ms) rows <- c(rows, sprintf("%s ~ %s*1", set, fmt(mu[set])))
  paste(rows, collapse = "\n")
}
lav_lr <- function(set, ms, extra = "", logical = NULL) {
  m1 <- paste0(base, extra, if (length(set)) fixed_rows(set, ms))
  args <- list(data = d, meanstructure = ms, fixed.x = if (is.null(logical)) FALSE else logical,
               likelihood = "normal", information = "observed")
  f1 <- do.call(lavaan::sem, c(list(m1), args))
  f0 <- do.call(lavaan::sem, c(list(paste0(m1, "\n", null)), args))
  unname(2 * (logLik(f1) - logLik(f0)))
}

out <- list()
add <- function(cell, med, other, engine) out[[length(out) + 1L]] <<- data.frame(cell, engine, medfit = med, other,
                                                                                  diff = abs(med - other))
exo <- c("treatment", "covariate1")
for (ms in c(FALSE, TRUE)) {
  tag <- if (ms) "+means" else ""
  add(paste0("free", tag), med_lr(FALSE, ms), lav_lr(character(), ms), "lavaan rows")
  add(paste0("all", tag), med_lr(TRUE, ms), lav_lr(exo, ms), "lavaan rows")
  add(paste0("all", tag), med_lr(TRUE, ms), lav_lr(character(), ms, logical = TRUE), "lavaan fixed.x=TRUE")
  add(paste0("subset covariate1", tag), med_lr("covariate1", ms), lav_lr("covariate1", ms), "lavaan rows")
  # lenient subset: treatment free because the model writes a statement on it, covariate1 fixed
  add(paste0("lenient", tag), med_lr("covariate1", ms, "treatment ~~ treatment\n"),
      lav_lr("covariate1", ms, "treatment ~~ treatment\n"), "lavaan rows")
  # conditional-likelihood check: LR under a fixed set equals LR with everything free
  add(paste0("cond: all vs free", tag), med_lr(TRUE, ms), med_lr(FALSE, ms), "medfit vs medfit")
}

# OpenMx: RAM model on raw data (means) or cov data, fixed paths at the sample moments for the fixed set
omx_fit <- function(set, ms, b_free) {
  paths <- list(
    mxPath("treatment", "mediator1", labels = "a"), mxPath("covariate1", "mediator1"),
    mxPath("mediator1", "outcome", free = b_free, values = if (b_free) 0.3 else 0, labels = "b"),
    mxPath("treatment", "outcome", labels = "cp"), mxPath("covariate1", "outcome"),
    mxPath(c("mediator1", "outcome"), arrows = 2, values = 1))
  free_exo <- setdiff(exo, set)
  for (i in seq_along(exo)) for (j in i:length(exo)) {
    fx <- exo[i] %in% set && exo[j] %in% set
    paths[[length(paths) + 1L]] <- mxPath(exo[i], exo[j], arrows = 2, free = !fx, values = S[exo[i], exo[j]])
  }
  if (ms) paths[[length(paths) + 1L]] <- mxPath("one", vars, free = !(vars %in% set), values = mu[vars])
  data <- if (ms) mxData(d[, vars], type = "raw") else mxData(S * n / (n - 1), type = "cov", numObs = n)
  m <- do.call(mxModel, c(list("m", type = "RAM", manifestVars = vars), paths, list(data)))
  mxRun(m, silent = TRUE)
}
omx_lr <- function(set, ms) {
  f1 <- omx_fit(set, ms, TRUE); f0 <- omx_fit(set, ms, FALSE)
  f0$output$fit - f1$output$fit   # -2logL difference (cov data: same discrepancy up to a constant)
}
for (ms in c(FALSE, TRUE)) {
  tag <- if (ms) "+means" else ""
  add(paste0("all", tag), med_lr(TRUE, ms), omx_lr(exo, ms), "OpenMx paths")
  add(paste0("subset covariate1", tag), med_lr("covariate1", ms), omx_lr("covariate1", ms), "OpenMx paths")
}
res <- do.call(rbind, out)
print(res, digits = 10, row.names = FALSE)
write.csv(res, "spike-t4a.csv", row.names = FALSE)
