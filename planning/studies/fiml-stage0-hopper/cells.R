# Stage-0 cell grid (60 cells) and seed policy. DRAFT: factor values are the README proposals.
stage0_cells <- function() {
  g <- expand.grid(n = c(200L, 500L), regime = c("nonzero", "b_null", "a_null", "joint_null", "local"),
                   miss = c("mcar", "mar", "empty"), direct = c(TRUE, FALSE), stringsAsFactors = FALSE)
  g$cell <- seq_len(nrow(g))
  ab <- function(r, n) switch(r, nonzero = c(.4, .4), b_null = c(.4, 0), a_null = c(0, .4),
                              joint_null = c(0, 0), local = rep(1 / sqrt(n), 2))
  P <- t(mapply(ab, g$regime, g$n))
  g$a <- P[, 1]; g$b <- P[, 2]; g$c <- ifelse(g$direct, .2, 0)
  g$truth_nie <- g$a * g$b; g$truth_nde <- g$c; g$truth_te <- g$c + g$a * g$b
  g
}
# Confirmatory seeds are disjoint from the pilot (9100101..9101203): 7,000,000 + cell*10,000 + dataset.
stage0_seed <- function(cell, dataset) 7000000L + as.integer(cell) * 10000L + as.integer(dataset)
