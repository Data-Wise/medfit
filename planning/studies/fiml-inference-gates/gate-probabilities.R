# Exact acceptance-rule calculations only; no fitted models or simulations.
args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args)) args[[1L]] else "planning/studies/fiml-inference-gates"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
alpha <- 0.05
critical <- function(n, floor) {
  if (n == 0L) return(1L)
  x <- seq_len(n)
  bound <- stats::qbeta(alpha, x, n - x + 1L)
  hit <- which(bound >= floor)
  if (length(hit)) x[hit[[1L]]] else n + 1L
}
pass_prob <- function(n, floor, truth) {
  k <- critical(n, floor)
  stats::pbinom(k - 1L, n, truth, lower.tail = FALSE)
}
# Independent inversion check: exact CP critical count equals a one-sided
# binomial rejection threshold at the boundary, including discreteness.
for (n in c(100L, 500L, 1000L, 2000L)) {
  for (floor in c(0.90, 0.925, 0.95)) {
    k <- critical(n, floor)
    stopifnot(stats::pbinom(k - 1L, n, floor, lower.tail = FALSE) <= alpha + 1e-12)
    if (k > 1L) stopifnot(stats::pbinom(k - 2L, n, floor, lower.tail = FALSE) > alpha - 1e-12)
  }
}
coverage <- expand.grid(M = c(500L, 1000L, 2000L), truth = c(.925, .93, .94, .95, .96), KEEP.OUT.ATTRS = FALSE)
coverage$critical <- vapply(coverage$M, critical, integer(1), floor = .925)
coverage$pass <- mapply(pass_prob, coverage$M, .925, coverage$truth)
availability <- expand.grid(M = c(500L, 1000L, 2000L), truth = c(.95, .97, .98, .99, 1), KEEP.OUT.ATTRS = FALSE)
availability$critical <- vapply(availability$M, critical, integer(1), floor = .95)
availability$pass <- mapply(pass_prob, availability$M, .95, availability$truth)
# Hierarchical IID dataset model: A returned out of M; C covers among A.
# Dataset categories have probabilities 1-a, a*(1-c), a*c.
# This accounts for the shared C numerator and correlated gate decisions.
combined <- function(M, a, c) {
  A <- 0:M
  k_cond <- vapply(A, critical, integer(1), floor = .925)
  k_joint <- critical(M, .90)
  k <- pmax(k_cond, k_joint)
  accepted <- A >= critical(M, .95)
  sum(stats::dbinom(A, M, a) * accepted * stats::pbinom(k - 1L, A, c, lower.tail = FALSE))
}
joint <- expand.grid(M = c(500L, 1000L, 2000L), availability = c(.97, .98, .99, 1), coverage = c(.93, .94, .95, .96), KEEP.OUT.ATTRS = FALSE)
joint$pass_all_three <- mapply(combined, joint$M, joint$availability, joint$coverage)
stopifnot(all(joint$pass_all_three >= 0 & joint$pass_all_three <= 1))
# At a=1, joint coverage floor is weaker than conditional floor.
stopifnot(all(abs(subset(joint, availability == 1 & coverage == .95)$pass_all_three - vapply(c(500L, 1000L, 2000L), pass_prob, numeric(1), floor=.925, truth=.95)) < 1e-12))
families <- expand.grid(K = c(1L, 6L, 12L, 66L), KEEP.OUT.ATTRS = FALSE)
p <- combined(500L, .98, .95)
families$per_cell <- p
families$all_pass_if_independent <- p ^ families$K
families$union_bound_lower <- pmax(0, 1 - families$K * (1-p))
refit <- data.frame(target_availability = c(.95, .98, .99))
refit$q_at_B999 <- -expm1(log(refit$target_availability) / 999)
for (name in c("coverage", "availability", "joint", "families", "refit")) {
  utils::write.csv(get(name), file.path(out_dir, paste0(name, ".csv")), row.names=FALSE)
}
print(subset(coverage, M == 500 & truth == .95), row.names=FALSE)
print(subset(availability, M == 500), row.names=FALSE)
print(subset(joint, M == 500 & coverage == .95), row.names=FALSE)
print(families, row.names=FALSE)
print(refit, row.names=FALSE)
cat("Exact inversion, boundary and joint-model checks: PASS\n")
