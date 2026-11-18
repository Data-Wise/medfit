# Few-clusters design study, task T6 (planning/PLAN-few-clusters-design-study-2026-11-16.md): the P1 cell selection,
# the row and failure-category checks, and the per-cell summaries of the main delta and MC run. Sourced after
# tests/sim/twolevel-few-clusters-lib.R (fc_grid(), fc_estimands, fc_boot_effects, fc_covered()); used by
# tests/sim/twolevel-few-clusters-t6-p1.R and tests/sim/twolevel-few-clusters-t6-aggregate.R, and checked in
# tests/testthat/test-twolevel-few-clusters-harness.R.
#
# Every check here stops: an aggregation that is short of R rows, or whose failure categories do not add up to R,
# is an error, never a warning (task T6 verification).

# Decision M7 (2026-11-17): P1 runs where P0's inadmissible rate in the T5 pilot exceeds 10%. The T5 rate
# (`inadmissible` in T5-cells.csv) is mean(identified status known & !admissible) over the R = 500 attempted datasets,
# so it overlaps the within-only rate; the rule uses that column as committed.
fc_t6_p1_cells <- function(cells, cutoff = .10) {
  checkmate::assert_data_frame(cells, min.rows = 1, .var.name = "cells")
  checkmate::assert_subset(c("cell_id", "J", "n", "icc_x", "balance", "nie_b", "R", "inadmissible"), names(cells),
                           .var.name = "names(cells)")
  checkmate::assert_number(cutoff, lower = 0, upper = 1, .var.name = "cutoff")
  out <- cells[cells$inadmissible > cutoff, c("cell_id", "J", "n", "icc_x", "balance", "nie_b", "R", "inadmissible")]
  names(out)[names(out) == "R"] <- "t5_R"
  names(out)[names(out) == "inadmissible"] <- "t5_inadmissible"
  out$cell_id <- as.integer(out$cell_id)
  out <- out[order(out$cell_id), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# Exhaustive, mutually exclusive failure categories of one dataset and arm, in the order the harness reaches them.
# A lavaan fit that does not converge is refused by the adapter, so it lands in `nonconverged` (an adapter error on a
# non-converged fit); `adapter_error` is any other refusal.
fc_t6_status_levels <- c("lavaan_error", "nonconverged", "adapter_error", "within_only", "inadmissible", "clean")

# One logical column per category. The predicates are written independently, not as an if-else chain, so that a row
# matching none or several of them shows up as a count that does not add up to R.
fc_t6_status_matrix <- function(rows) {
  blank <- function(x) is.na(x) | x == ""
  lav <- !blank(rows$lavaan_error)
  adp <- !blank(rows$adapter_error)
  conv <- rows$converged
  ident <- rows$between_identified
  adm <- rows$admissible
  cbind(
    lavaan_error = lav,
    nonconverged = conv %in% FALSE,
    adapter_error = adp & conv %in% TRUE,
    within_only = conv %in% TRUE & ident %in% FALSE,
    inadmissible = conv %in% TRUE & ident %in% TRUE & adm %in% FALSE,
    clean = conv %in% TRUE & ident %in% TRUE & adm %in% TRUE
  )
}

# Category of each row; call only after fc_t6_status_counts() has passed.
fc_t6_status <- function(rows) {
  m <- fc_t6_status_matrix(rows)
  fc_t6_status_levels[apply(m, 1L, which)]
}

# Counts per (cell, arm) and category; stops when a group's counts do not sum to its R rows.
fc_t6_status_counts <- function(rows, reps) {
  checkmate::assert_data_frame(rows, min.rows = 1, .var.name = "rows")
  checkmate::assert_count(reps, positive = TRUE, .var.name = "reps")
  m <- fc_t6_status_matrix(rows)
  groups <- split(seq_len(nrow(rows)), rows[c("cell_id", "arm")], drop = TRUE, sep = "/")
  out <- do.call(rbind, lapply(names(groups), function(g) {
    i <- groups[[g]]
    cnt <- colSums(m[i, , drop = FALSE])
    if (sum(cnt) != length(i) || length(i) != reps) {
      stop(sprintf("failure categories of %s sum to %d, not to its %d rows (R = %d)", g, sum(cnt), length(i), reps),
           call. = FALSE)
    }
    data.frame(cell_id = rows$cell_id[i[1]], arm = rows$arm[i[1]], R = length(i), t(cnt), stringsAsFactors = FALSE)
  }))
  out[fc_t6_status_levels] <- lapply(out[fc_t6_status_levels], as.integer)
  out$R <- as.integer(out$R)
  rownames(out) <- NULL
  out
}

# Every cell has exactly replicates 1..R under P0, and under P1 exactly in the P1 cells; no other (cell, arm) group.
fc_t6_check_rows <- function(rows, reps, cells, p1_cells) {
  checkmate::assert_data_frame(rows, min.rows = 1, .var.name = "rows")
  checkmate::assert_count(reps, positive = TRUE, .var.name = "reps")
  checkmate::assert_integerish(cells, any.missing = FALSE, min.len = 1, .var.name = "cells")
  checkmate::assert_integerish(p1_cells, any.missing = FALSE, .var.name = "p1_cells")
  checkmate::assert_subset(p1_cells, cells, .var.name = "p1_cells")
  want <- c(paste0(cells, "/p0"), if (length(p1_cells)) paste0(p1_cells, "/p1"))
  key <- paste0(rows$cell_id, "/", rows$arm)
  stray <- setdiff(unique(key), want)
  if (length(stray)) stop("rows outside the design: ", paste(stray, collapse = ", "), call. = FALSE)
  missing <- setdiff(want, key)
  if (length(missing)) stop("no rows for ", paste(missing, collapse = ", "), call. = FALSE)
  for (g in want) {
    r <- rows$rep[key == g]
    if (length(r) != reps) stop(sprintf("%s has %d rows, not R = %d", g, length(r), reps), call. = FALSE)
    if (!setequal(r, seq_len(reps)) || anyDuplicated(r)) {
      stop(sprintf("%s does not hold replicates 1 to %d exactly once", g, reps), call. = FALSE)
    }
  }
  invisible(TRUE)
}

# Monte Carlo standard errors: a proportion over R datasets, and a mean over its non-missing values.
fc_t6_mcse_prop <- function(p, r) sqrt(p * (1 - p) / r)
fc_t6_mcse_mean <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) < 2L) return(NA_real_)
  stats::sd(x) / sqrt(length(x))
}

# Interval columns of an estimand: the delta interval of tidy(), or the MC percentile interval (three effects).
fc_t6_interval <- function(rows, e, interval) {
  if (interval == "delta") {
    list(lo = rows[[paste0("lo_", e)]], hi = rows[[paste0("hi_", e)]])
  } else {
    list(lo = rows[[paste0("mc_lo_", e)]], hi = rows[[paste0("mc_hi_", e)]])
  }
}

# Per (cell, arm) group, interval and estimand (plan section 6): the failure categories (counts and rates, which add
# up to R), the T5-comparable overlapping rates, unconditional coverage (a missing interval is a miss) with MCSE and
# the miss on each side, conditional coverage over clean fits with an interval (NA below 100, MCSE on the realized
# denominator), bias and its MCSE, median relative bias (NA where the truth is 0), SE ratio (median SE over the
# empirical SD, delta only), median width and availability. P1 adds the at-bound rate and a sensitivity coverage that
# counts an at-bound fit as a miss.
fc_t6_summary <- function(rows, min_cond = 100L) {
  checkmate::assert_data_frame(rows, min.rows = 1, .var.name = "rows")
  checkmate::assert_count(min_cond, .var.name = "min_cond")
  blank <- function(x) is.na(x) | x == ""
  groups <- split(seq_len(nrow(rows)), rows[c("cell_id", "arm")], drop = TRUE)
  intervals <- c("delta", if (any(grepl("^mc_lo_", names(rows)))) "mc")
  out <- lapply(groups, function(i) {
    r <- rows[i, , drop = FALSE]
    n_r <- nrow(r)
    st <- fc_t6_status(r)
    clean <- st == "clean"
    known <- !is.na(r$between_identified)
    base <- data.frame(
      cell_id = r$cell_id[1], J = r$J[1], n = r$n[1], icc_x = r$icc_x[1], balance = r$balance[1],
      nie_b = r$nie_b[1], arm = r$arm[1], R = n_r, stringsAsFactors = FALSE
    )
    for (s in fc_t6_status_levels) base[[paste0("n_", s)]] <- sum(st == s)
    for (s in fc_t6_status_levels) base[[paste0("rate_", s)]] <- mean(st == s)
    fail <- st %in% c("lavaan_error", "nonconverged", "adapter_error")
    base$rate_fail <- mean(fail)
    base$rate_fail_mcse <- fc_t6_mcse_prop(mean(fail), n_r)
    base$inadmissible_t5 <- mean(known & !r$admissible %in% TRUE)
    base$neg_l2_var <- mean(r$neg_l2_var %in% TRUE)
    base$at_bound <- if (r$arm[1] == "p1") mean(r$at_bound %in% TRUE) else NA_real_
    for (w in c("between_weak", "few_clusters", "inadmissible", "between_unidentified")) {
      col <- paste0("warn_", w)
      base[[col]] <- if (col %in% names(r)) mean(r[[col]] %in% TRUE) else NA_real_
    }
    base$lavaan_warn <- if ("n_lavaan_warn" %in% names(r)) mean(r$n_lavaan_warn > 0) else NA_real_
    base$fit_s_median <- stats::median(r$fit_time)
    base$mc_s_median <- if ("mc_time" %in% names(r)) stats::median(r$mc_time, na.rm = TRUE) else NA_real_
    do.call(rbind, lapply(intervals, function(iv) {
      ests <- if (iv == "delta") fc_estimands else fc_boot_effects
      do.call(rbind, lapply(ests, function(e) {
        truth <- r[[paste0("truth_", e)]]
        ci <- fc_t6_interval(r, e, iv)
        has <- !is.na(ci$lo) & !is.na(ci$hi)
        hit <- has & ci$lo <= truth & truth <= ci$hi
        p <- mean(hit)
        cond <- clean & has
        n_c <- sum(cond)
        pc <- if (n_c >= min_cond) mean(hit[cond]) else NA_real_
        est <- r[[paste0("est_", e)]]
        se <- r[[paste0("se_", e)]]
        ok <- !is.na(est)
        err <- est[ok] - truth[ok]
        rel <- if (all(truth[ok] != 0)) stats::median(err / truth[ok]) else NA_real_
        sens <- if (r$arm[1] == "p1") mean(hit & !r$at_bound %in% TRUE) else NA_real_
        cbind(base, interval = iv, estimand = e, truth = truth[1],
              coverage = p, coverage_mcse = fc_t6_mcse_prop(p, n_r),
              miss_low = mean(has & ci$hi < truth), miss_high = mean(has & ci$lo > truth),
              n_cond = n_c, ccov = pc, ccov_mcse = if (is.na(pc)) NA_real_ else fc_t6_mcse_prop(pc, n_c),
              sens_coverage = sens, availability = mean(has),
              width_median = if (any(has)) stats::median(ci$hi[has] - ci$lo[has]) else NA_real_,
              n_est = sum(ok), bias = if (any(ok)) mean(err) else NA_real_, bias_mcse = fc_t6_mcse_mean(err),
              rel_bias_median = rel,
              se_ratio = if (iv == "delta" && sum(ok) > 2L) stats::median(se[ok]) / stats::sd(est[ok]) else NA_real_,
              mc_fail = if (iv == "mc") mean(!blank(r[[paste0("mc_err_", e)]])) else NA_real_,
              stringsAsFactors = FALSE)
      }))
    }))
  })
  out <- do.call(rbind, out)
  out <- out[order(out$cell_id, out$arm, out$interval, match(out$estimand, fc_estimands)), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# P0/P1 comparison on the P1 cells (plan section 5): the same datasets under both arms (same seeds), paired by rep.
# Per cell, interval and estimand: each arm's coverage, bias and SE ratio, the paired coverage difference P1 - P0 with
# MCSE sd(I_p1 - I_p0) / sqrt(R), failure rates, P0's inadmissible rate, P1's at-bound rate and sensitivity coverage,
# and median fit times.
fc_t6_parametrization <- function(rows, p1_cells) {
  checkmate::assert_data_frame(rows, min.rows = 1, .var.name = "rows")
  checkmate::assert_integerish(p1_cells, any.missing = FALSE, min.len = 1, .var.name = "p1_cells")
  rows <- rows[rows$cell_id %in% p1_cells, , drop = FALSE]
  s <- fc_t6_summary(rows)
  intervals <- unique(s$interval)
  out <- lapply(p1_cells, function(cid) {
    r0 <- rows[rows$cell_id == cid & rows$arm == "p0", , drop = FALSE]
    r1 <- rows[rows$cell_id == cid & rows$arm == "p1", , drop = FALSE]
    r1 <- r1[match(r0$rep, r1$rep), , drop = FALSE]
    if (nrow(r0) != nrow(r1) || anyNA(r1$rep)) stop("cell ", cid, ": P0 and P1 rows do not pair", call. = FALSE)
    do.call(rbind, lapply(intervals, function(iv) {
      ests <- if (iv == "delta") fc_estimands else fc_boot_effects
      do.call(rbind, lapply(ests, function(e) {
        hit <- function(r) {
          ci <- fc_t6_interval(r, e, iv)
          t <- r[[paste0("truth_", e)]]
          h <- ci$lo <= t & t <= ci$hi
          !is.na(h) & h
        }
        d <- as.numeric(hit(r1)) - as.numeric(hit(r0))
        a0 <- s[s$cell_id == cid & s$arm == "p0" & s$interval == iv & s$estimand == e, ]
        a1 <- s[s$cell_id == cid & s$arm == "p1" & s$interval == iv & s$estimand == e, ]
        data.frame(
          cell_id = cid, J = a0$J, n = a0$n, icc_x = a0$icc_x, balance = a0$balance, nie_b = a0$nie_b,
          interval = iv, estimand = e, R = nrow(r0),
          coverage_p0 = a0$coverage, coverage_p1 = a1$coverage, coverage_diff = mean(d),
          coverage_diff_mcse = if (length(d) > 1L) stats::sd(d) / sqrt(length(d)) else NA_real_,
          ccov_p0 = a0$ccov, ccov_p1 = a1$ccov, sens_coverage_p1 = a1$sens_coverage,
          bias_p0 = a0$bias, bias_p1 = a1$bias, bias_mcse_p0 = a0$bias_mcse, bias_mcse_p1 = a1$bias_mcse,
          se_ratio_p0 = a0$se_ratio, se_ratio_p1 = a1$se_ratio,
          rate_fail_p0 = a0$rate_fail, rate_fail_p1 = a1$rate_fail,
          rate_nonconverged_p0 = a0$rate_nonconverged, rate_nonconverged_p1 = a1$rate_nonconverged,
          inadmissible_t5_p0 = a0$inadmissible_t5, at_bound_p1 = a1$at_bound,
          fit_s_median_p0 = a0$fit_s_median, fit_s_median_p1 = a1$fit_s_median,
          stringsAsFactors = FALSE
        )
      }))
    }))
  })
  out <- do.call(rbind, out)
  rownames(out) <- NULL
  out
}

# Top-level aggregation: the row check, the failure-category check, then the two tables. Errors, never warnings.
fc_t6_aggregate <- function(rows, reps, cells, p1_cells) {
  fc_t6_check_rows(rows, reps = reps, cells = cells, p1_cells = p1_cells)
  counts <- fc_t6_status_counts(rows, reps = reps)
  list(
    counts = counts,
    cells = fc_t6_summary(rows),
    parametrization = if (length(p1_cells)) fc_t6_parametrization(rows, p1_cells) else NULL
  )
}
