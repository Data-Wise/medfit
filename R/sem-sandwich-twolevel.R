# Cluster-robust (CR0) sandwich for the native two-level fit (IG2,
# planning/specs/SCOPE-IG2-cluster-robust-se-2026-11-19.md). The two-level log-likelihood is a sum over clusters,
# log L = sum_j log L_j, and log L_j depends on the data only through the cluster's own statistics (ybar_j, z_j,
# SSW_j). The score of cluster j is therefore the gradient of the likelihood of a one-cluster sample: `.sem_eval_ml2()`
# on that sample returns g_j = -2 / n_j d log L_j / d theta, so s_j = -n_j / 2 g_j. The meat is sum_j s_j s_j' with no
# small-sample factor (CR0, decision D3); `.sem_vcov()` takes it with the observed information as the bread and
# projects it onto the tangent space of active constraints (D4). The per-size pooling of `.sem_sample_ml2()` is kept
# for the likelihood itself (R/sem-ml.R is untouched, D2): pooled statistics give the sum of the scores but not the
# outer products.

# One-cluster samples, in the shape of `.sem_sample_ml2()` (built by it, so the cluster statistics have one
# definition), one per cluster in the order of `factor(data[[cluster]])`.
.sem_ml2_cluster_samples <- function(data, ram, cluster) {
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  checkmate::assert_string(cluster, .var.name = "cluster")
  checkmate::assert_names(names(data), must.include = c(ram$within, ram$between, cluster), .var.name = "data")
  sets <- list(within = ram$within, between = ram$between)
  idx <- split(seq_len(nrow(data)), factor(data[[cluster]]))
  lapply(idx, function(i) .sem_sample_ml2(data[i, , drop = FALSE], sets, cluster))
}

# Per-cluster scores d log L_j / d theta: a J x q matrix, rows in the order of `factor(data[[cluster]])`. Their column
# sums are the score of the whole sample, -N / 2 times the gradient of `.sem_eval_ml2()`.
.sem_scores_ml2 <- function(theta, ram, data, cluster) {
  checkmate::assert_numeric(theta, len = ram$q, any.missing = FALSE, .var.name = "theta")
  samples <- .sem_ml2_cluster_samples(data, ram, cluster)
  scores <- vapply(samples, function(s) -s$n / 2 * .sem_eval_ml2(theta, ram, s, TRUE)$g, numeric(ram$q))
  out <- t(matrix(scores, ram$q, length(samples)))
  dimnames(out) <- list(names(samples), ram$par_names)
  out
}

# CR0 meat: sum_j s_j s_j' over the clusters, q x q in theta units.
.sem_meat_ml2 <- function(theta, ram, data, cluster) {
  crossprod(.sem_scores_ml2(theta, ram, data, cluster))
}
