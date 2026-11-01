# Deterministic decision-power calculations only: no FIML fits or simulations.
alpha <- .05
floor_cond <- .925
floor_available <- .95
floor_joint <- .90
critical <- function(n, p) {
  if (n == 0L) return(1L)
  x <- seq_len(n)
  hits <- which(stats::qbeta(alpha, x, n - x + 1L) >= p)
  if (length(hits)) hits[1L] else n + 1L
}
calc <- function(M, a, c) {
  A <- 0:M
  kc <- vapply(A, critical, integer(1), p = floor_cond)
  ka <- critical(M, floor_available)
  kj <- critical(M, floor_joint)
  p <- sum(stats::dbinom(A, M, a) * (A >= ka) *
             stats::pbinom(pmax(kc, kj) - 1L, A, c, lower.tail = FALSE))
  list(p = p, kc = kc, ka = ka, kj = kj)
}
# Independent conditioning: C is binomial first, then A-C | C is binomial.
calc_by_cover <- function(M, a, c, crit) {
  C <- 0:M
  max_A <- findInterval(C, crit$kc) - 1L
  lo <- pmax(crit$ka - C, 0L)
  hi <- max_A - C
  remaining <- M - C
  q <- a * (1 - c) / (1 - a * c)
  range_prob <- stats::pbinom(hi, remaining, q) -
    stats::pbinom(lo - 1L, remaining, q)
  sum(stats::dbinom(C, M, a * c) * (C >= crit$kj) *
        ifelse(hi >= lo, range_prob, 0))
}
K <- 228L
K_zero <- 60L
grid <- expand.grid(M = c(500L, 1000L, 2000L, 2500L, 3000L),
                    availability = c(.97, .98, .99),
                    coverage = c(.93, .94, .95, .96))
grid$power <- NA_real_
grid$zero_availability_failure <- NA_real_
for (m in unique(grid$M)) {
  base <- calc(m, .98, .95)
  # Invert each critical count via binomial tails, independent of qbeta.
  for (p in c(floor_cond, floor_available, floor_joint)) {
    for (n in c(100L, 500L, m)) {
      k <- critical(n, p)
      stopifnot(stats::pbinom(k - 1L, n, p, lower.tail = FALSE) <= alpha + 1e-12,
                stats::pbinom(k - 2L, n, p, lower.tail = FALSE) > alpha - 1e-12)
    }
  }
  check <- calc_by_cover(m, .98, .95, base)
  stopifnot(abs(check - base$p) < 1e-10)
  for (i in which(grid$M == m)) {
    A <- 0:m
    grid$power[i] <- sum(stats::dbinom(A, m, grid$availability[i]) *
      (A >= base$ka) * stats::pbinom(pmax(base$kc, base$kj) - 1L, A,
                                    grid$coverage[i], lower.tail = FALSE))
    grid$zero_availability_failure[i] <- stats::pbinom(
      base$ka - 1L, m, grid$availability[i])
  }
  # Given exact-zero correctness, the availability gate implies the other two.
  stopifnot(base$ka >= base$kj,
            stats::qbeta(alpha, base$ka, 1L) >= floor_cond)
}
# This bound covers regular decisions only, not structural/completeness checks.
grid$regular_lower <- pmax(0, 1 - K * (1 - grid$power))
# Conditional on exact-zero correctness and complete, valid execution/records.
# Union bound needs no independence between cells, effects, or methods.
grid$conditional_stage_lower <- pmax(0, 1 - K * (1 - grid$power) -
                                      K_zero * grid$zero_availability_failure)
utils::write.csv(grid, "planning/studies/fiml-admission-design/power.csv", row.names = FALSE)
print(subset(grid, coverage == .95 & availability == .98), row.names = FALSE)
cat("Independent conditioning and binomial inversion checks: PASS\n")
