# T8: aggregate tables for the few-clusters U4 package.
# Rerun from the repository root:  Rscript planning/studies/few-clusters/T8-tables.R
# Reads only the recorded results (T6-cells.csv, T6-parametrization.csv, T6-p1-cells.csv); writes the T8-*.csv
# tables and T8-tables.md beside them. Never edits a recorded result. Deterministic: no RNG, no timestamps.
#
# Definitions fixed here (T8 display choices, not new study cutoffs):
#   flags     small_J = J <= 20; low_icc = icc_x == .05 (implied ICC_M .039, below the adapter's icc_warn);
#             unbalanced = balance == "unequal". These only mark rows; no verdict uses them.
#   verdict   M8 cutoffs on P0 rate_fail = lavaan_error + nonconverged + adapter_error (the T6 definition):
#             "use" below .05, "caution" from .05 to .20 inclusive, "do not fit" above .20.
#             Borderline = the rate is within 2 MCSE of a cutoff.
#   proposal  (labeled PROPOSAL, not an M8 cutoff) coverage_ok = unconditional P0 delta coverage of NIE_W
#             at least .925, the lower end of the nominal band of T6-README (3.6 MCSE below .95 at R = 1000).
#   P1        derived columns are INFERENCE from recorded columns (per-dataset rows are outside git):
#             floor_bound_cov = (coverage_p1 - sens_coverage_p1) / at_bound_p1,
#             off_floor_cov   = sens_coverage_p1 / (1 - at_bound_p1).

here <- "planning/studies/few-clusters"
stopifnot(file.exists(file.path(here, "T6-cells.csv")))
rd <- function(f) utils::read.csv(file.path(here, f), stringsAsFactors = FALSE)
wr <- function(x, f) utils::write.csv(x, file.path(here, f), row.names = FALSE, na = "")

cells <- rd("T6-cells.csv")
par <- rd("T6-parametrization.csv")
p1list <- rd("T6-p1-cells.csv")
stopifnot(nrow(cells) == 1352L, nrow(par) == 392L, nrow(p1list) == 49L)

r4 <- function(x) round(x, 4)
verdict <- function(rate) ifelse(rate < 0.05, "use", ifelse(rate <= 0.20, "caution", "do not fit"))
borderline <- function(rate, mcse) abs(rate - 0.05) <= 2 * mcse | abs(rate - 0.20) <= 2 * mcse
md_table <- function(df) {
  df[] <- lapply(df, function(x) ifelse(is.na(x), "", format(x, trim = TRUE)))
  c(paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1L, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}

# ---- (a) per-cell table, P0 --------------------------------------------------------------------------------------
p0 <- cells[cells$arm == "p0", ]
cell_cols <- c("cell_id", "J", "n", "icc_x", "balance", "nie_b", "rate_fail", "rate_fail_mcse", "rate_nonconverged",
               "rate_adapter_error", "rate_within_only", "rate_inadmissible", "rate_clean")
base <- unique(p0[, cell_cols])
base <- base[order(base$cell_id), ]
stopifnot(nrow(base) == 120L, !anyDuplicated(base$cell_id))
pick <- function(iv, est, col, nm) {
  s <- p0[p0$interval == iv & p0$estimand == est, c("cell_id", col)]
  stopifnot(nrow(s) == 120L)
  names(s)[2] <- nm
  s
}
for (spec in list(c("delta", "nie_within", "coverage", "cov_nie_w_delta"),
                  c("delta", "nie_within", "ccov", "ccov_nie_w_delta"),
                  c("delta", "nie_between", "coverage", "cov_nie_b_delta"),
                  c("delta", "nie_between", "ccov", "ccov_nie_b_delta"),
                  c("mc", "nie_within", "coverage", "cov_nie_w_mc"),
                  c("mc", "nie_between", "coverage", "cov_nie_b_mc"))) {
  base <- merge(base, pick(spec[1], spec[2], spec[3], spec[4]), by = "cell_id")
}
base <- base[order(base$cell_id), ]
base$small_J <- base$J <= 20
base$low_icc <- base$icc_x == 0.05
base$unbalanced <- base$balance == "unequal"
base$in_p1 <- base$cell_id %in% p1list$cell_id
base$verdict_failure <- verdict(base$rate_fail)
base$borderline_failure <- borderline(base$rate_fail, base$rate_fail_mcse)
base$proposal_coverage_ok <- base$cov_nie_w_delta >= 0.925
num <- vapply(base, is.numeric, NA) & !names(base) %in% c("cell_id", "J", "n")
base[num] <- lapply(base[num], r4)
wr(base, "T8-per-cell.csv")

# ---- (b) P0 against P1 ---------------------------------------------------------------------------------------------
p1c <- cells[cells$arm == "p1" & cells$interval == "delta", ]
p1extra <- unique(p1c[, c("cell_id", "rate_within_only", "rate_clean")])
names(p1extra) <- c("cell_id", "rate_within_only_p1", "rate_clean_p1")
avail <- p1c[, c("cell_id", "estimand", "availability")]
names(avail)[3] <- "availability_p1"
pp <- merge(par, p1extra, by = "cell_id")
pp <- merge(pp, avail, by = c("cell_id", "estimand"))
pp$floor_bound_cov <- (pp$coverage_p1 - pp$sens_coverage_p1) / pp$at_bound_p1
pp$off_floor_cov <- pp$sens_coverage_p1 / (1 - pp$at_bound_p1)
pp$at_bound_ok <- pp$at_bound_p1 > 0 & pp$at_bound_p1 < 1
stopifnot(all(pp$at_bound_ok))
# Between-level effects have no interval for a within-only fit, so floor_bound_cov counts a floor-bound within-only
# fit as a miss. at_bound is computed for every converged fit, within-only included (fc_analyze() in
# tests/sim/twolevel-few-clusters-lib.R). A within-only fit off the floor has no interval, so it is a miss among the off-floor fits:
# w_off <= (1 - at_bound) * (1 - off_floor_cov). With wo = the within-only rate, the floor-bound fits that have an
# interval number between at_bound - wo (every within-only fit at the floor) and at_bound - wo + w_off_max. Their
# coverage lies in [hits / (at_bound - wo + w_off_max), min(1, hits / (at_bound - wo))], hits = coverage_p1 -
# sens_coverage_p1. INFERENCE from recorded columns.
btw <- pp$estimand %in% c("nie_between", "nie_contrast", "c_prime_between")
hits_fb <- pp$coverage_p1 - pp$sens_coverage_p1
w_off_max <- (1 - pp$at_bound_p1) * (1 - pp$off_floor_cov)
pp$w_off_max <- ifelse(btw, w_off_max, NA_real_)
n_ab_int <- pp$at_bound_p1 - pp$rate_within_only_p1
pp$floor_bound_with_interval_cov_lo <- ifelse(btw, hits_fb / (n_ab_int + w_off_max), NA_real_)
pp$floor_bound_with_interval_cov_hi <- ifelse(btw, pmin(1, hits_fb / n_ab_int), NA_real_)
stopifnot(all(pp$at_bound_p1[btw] >= pp$rate_within_only_p1[btw]))
# Exact identities used in the README (checked, not assumed):
nb <- pp[pp$interval == "delta" & pp$estimand == "nie_between", ]
stopifnot(max(abs(nb$availability_p1 - nb$rate_clean_p1)) < 1e-9,
          max(abs(nb$ccov_p1 - nb$coverage_p1 / nb$availability_p1)) < 1e-9)
pp <- pp[order(pp$cell_id, pp$interval, pp$estimand), ]
pp[vapply(pp, is.numeric, NA) & !names(pp) %in% c("cell_id", "J", "n", "R")] <-
  lapply(pp[vapply(pp, is.numeric, NA) & !names(pp) %in% c("cell_id", "J", "n", "R")], r4)
wr(pp[, c("cell_id", "J", "n", "icc_x", "balance", "nie_b", "interval", "estimand", "coverage_p0", "coverage_p1",
          "at_bound_p1", "floor_bound_cov", "floor_bound_with_interval_cov_lo", "floor_bound_with_interval_cov_hi",
          "w_off_max", "off_floor_cov", "sens_coverage_p1", "ccov_p0", "ccov_p1",
          "availability_p1", "rate_within_only_p1", "rate_fail_p0", "rate_fail_p1", "inadmissible_t5_p0")],
   "T8-p0-p1.csv")

summ <- function(x) {
  if (all(is.na(x))) return(c(median = NA_real_, min = NA_real_, max = NA_real_))
  c(median = stats::median(x, na.rm = TRUE), min = min(x, na.rm = TRUE), max = max(x, na.rm = TRUE))
}
ppd <- pp[pp$interval == "delta", ]
sm <- do.call(rbind, lapply(split(ppd, ppd$estimand), function(g) {
  data.frame(estimand = g$estimand[1], cells = nrow(g),
             cov_p0_median = summ(g$coverage_p0)[1], cov_p1_median = summ(g$coverage_p1)[1],
             at_bound_median = summ(g$at_bound_p1)[1], at_bound_min = summ(g$at_bound_p1)[2],
             at_bound_max = summ(g$at_bound_p1)[3],
             floor_bound_median = summ(g$floor_bound_cov)[1], floor_bound_min = summ(g$floor_bound_cov)[2],
             floor_bound_max = summ(g$floor_bound_cov)[3],
             floor_bound_with_interval_lo_min = summ(g$floor_bound_with_interval_cov_lo)[2],
             floor_bound_with_interval_lo_median = summ(g$floor_bound_with_interval_cov_lo)[1],
             floor_bound_with_interval_hi_median = summ(g$floor_bound_with_interval_cov_hi)[1],
             w_off_max_max = summ(g$w_off_max)[3], off_floor_median = summ(g$off_floor_cov)[1],
             sens_median = summ(g$sens_coverage_p1)[1], ccov_p1_median = summ(g$ccov_p1)[1],
             availability_p1_median = summ(g$availability_p1)[1], stringsAsFactors = FALSE)
}))
byj <- do.call(rbind, lapply(split(ppd, list(ppd$estimand, ppd$J)), function(g) {
  data.frame(estimand = g$estimand[1], J = g$J[1], cells = nrow(g), cov_p0 = summ(g$coverage_p0)[1],
             cov_p1 = summ(g$coverage_p1)[1], at_bound = summ(g$at_bound_p1)[1],
             floor_bound = summ(g$floor_bound_cov)[1], off_floor = summ(g$off_floor_cov)[1],
             sens = summ(g$sens_coverage_p1)[1], ccov_p1 = summ(g$ccov_p1)[1], stringsAsFactors = FALSE)
}))
sm[-1] <- lapply(sm[-1], r4)
byj[-(1:3)] <- lapply(byj[-(1:3)], r4)
rownames(sm) <- rownames(byj) <- NULL
wr(sm, "T8-p0-p1-summary.csv")
wr(byj, "T8-p0-p1-by-j.csv")

# ---- (e) P1 selection against T6 ------------------------------------------------------------------------------------
# The selection rule (M7) read T5-cells.csv `inadmissible`, the overlapping rate (a fit counts when it is not
# admissible, whatever else it is, so within-only fits are included). `inadmissible_t5` in T6-cells.csv is the same
# definition on the T6 data; `rate_inadmissible` is the exclusive T6 category (identified, converged, not admissible).
t5 <- rd("T5-cells.csv")
sel <- merge(t5[, c("cell_id", "J", "n", "icc_x", "balance", "nie_b", "inadmissible")],
             unique(p0[, c("cell_id", "inadmissible_t5", "rate_inadmissible", "rate_within_only")]), by = "cell_id")
names(sel)[names(sel) == "inadmissible"] <- "t5_pilot_overlap"
names(sel)[names(sel) == "inadmissible_t5"] <- "t6_overlap"
names(sel)[names(sel) == "rate_inadmissible"] <- "t6_exclusive"
sel$selected_p1 <- sel$t5_pilot_overlap > 0.10
stopifnot(identical(sort(sel$cell_id[sel$selected_p1]), sort(p1list$cell_id)))
sel$below_10_in_t6_overlap <- sel$selected_p1 & sel$t6_overlap <= 0.10
sel$above_10_in_t6_overlap_not_selected <- !sel$selected_p1 & sel$t6_overlap > 0.10
sel$below_10_in_t6_exclusive <- sel$selected_p1 & sel$t6_exclusive <= 0.10
sel$exclusive_below_10_not_selected_overlap_above <- !sel$selected_p1 & sel$t6_overlap > 0.10 & sel$t6_exclusive <= 0.10
sel <- sel[order(sel$cell_id), ]
wr(sel, "T8-p1-selection.csv")

# ---- (d) decision table -------------------------------------------------------------------------------------------
groups <- unique(base[, c("n", "balance", "icc_x")])
groups <- groups[order(groups$balance, groups$n, groups$icc_x), ]
dec <- do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
  g <- groups[i, ]
  rows <- lapply(sort(unique(base$J)), function(j) {
    s <- base[base$n == g$n & base$balance == g$balance & base$icc_x == g$icc_x & base$J == j, ]
    stopifnot(nrow(s) == 2L)
    w <- s[which.max(s$rate_fail), ]
    data.frame(n = g$n, balance = g$balance, icc_x = g$icc_x, J = j, cell_ids = paste(s$cell_id, collapse = "+"),
               rate_fail_min = min(s$rate_fail), rate_fail_max = max(s$rate_fail),
               verdict_failure = verdict(max(s$rate_fail)), borderline = any(s$borderline_failure),
               cov_nie_w_delta_min = min(s$cov_nie_w_delta), cov_nie_b_delta_min = min(s$cov_nie_b_delta),
               proposal_coverage_ok = all(s$proposal_coverage_ok), stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}))
stopifnot(nrow(dec) == 60L)
wr(dec, "T8-decision-table.csv")

# Compact matrix: worst of the two NIE_B cells per J; code U = use, C = caution, X = do not fit, * = borderline.
code <- c(use = "U", caution = "C", `do not fit` = "X")
dm <- do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
  g <- dec[dec$n == groups$n[i] & dec$balance == groups$balance[i] & dec$icc_x == groups$icc_x[i], ]
  g <- g[order(g$J), ]
  cellv <- paste0(code[g$verdict_failure], ifelse(g$borderline, "*", ""), " ", sprintf("%.3f", g$rate_fail_max))
  out <- data.frame(balance = groups$balance[i], n = groups$n[i], icc_x = groups$icc_x[i], t(cellv))
  names(out)[4:8] <- paste0("J", g$J)
  out
}))
wr(dm, "T8-decision-matrix.csv")

# Minimum grid J at which every cell of a (n, balance, icc_x) group, at that J and at every larger J, is below a cutoff.
min_j <- function(g, cut) {
  js <- sort(unique(g$J))
  ok <- vapply(js, function(j) all(g$rate_fail_max[g$J >= j] < cut), NA)
  if (!any(ok)) NA_integer_ else min(js[ok])
}
mj <- do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
  g <- dec[dec$n == groups$n[i] & dec$balance == groups$balance[i] & dec$icc_x == groups$icc_x[i], ]
  data.frame(n = groups$n[i], balance = groups$balance[i], icc_x = groups$icc_x[i],
             min_J_below_20pct = min_j(g, 0.20), min_J_below_5pct = min_j(g, 0.05),
             rate_fail_max_at_J100 = g$rate_fail_max[g$J == 100], stringsAsFactors = FALSE)
}))
wr(mj, "T8-min-j.csv")
mj_all <- do.call(rbind, lapply(split(dec, list(dec$n, dec$balance)), function(g) {
  data.frame(n = g$n[1], balance = g$balance[1], min_J_below_20pct_all_icc = min_j(g, 0.20),
             min_J_below_5pct_all_icc = min_j(g, 0.05), stringsAsFactors = FALSE)
}))
rownames(mj_all) <- NULL
wr(mj_all, "T8-min-j-all-icc.csv")

# Agreement of the failure verdict with the proposal coverage flag, cell level.
agree <- as.data.frame(table(verdict_failure = base$verdict_failure, proposal_coverage_ok = base$proposal_coverage_ok))
wr(agree, "T8-verdict-vs-coverage.csv")

# ---- (c) adapter-threshold evidence -------------------------------------------------------------------------------
pc <- p0[p0$interval == "delta" & p0$estimand %in% c("nie_within", "nie_between"), ]
ev_j <- do.call(rbind, lapply(sort(unique(base$J)), function(j) {
  b <- base[base$J == j, ]
  nb0 <- pc[pc$J == j & pc$estimand == "nie_between", ]
  wf <- unique(p0[p0$J == j, c("cell_id", "warn_few_clusters")])
  data.frame(J = j, cells = nrow(b), warn_few_clusters_mean = mean(wf$warn_few_clusters),
             rate_fail_median = stats::median(b$rate_fail), rate_fail_max = max(b$rate_fail),
             rate_fail_max_n20_equal = max(b$rate_fail[b$n == 20 & b$balance == "equal"]),
             rate_fail_max_n5_equal = max(b$rate_fail[b$n == 5 & b$balance == "equal"]),
             rate_fail_max_n5_unequal = max(b$rate_fail[b$n == 5 & b$balance == "unequal"]),
             cov_nie_w_delta_median = stats::median(b$cov_nie_w_delta),
             nie_w_cells_in_band = sum(b$cov_nie_w_delta > 0.925 & b$cov_nie_w_delta < 0.975),
             ccov_nie_w_delta_median = stats::median(b$ccov_nie_w_delta, na.rm = TRUE),
             ccov_nie_b_delta_median = stats::median(b$ccov_nie_b_delta, na.rm = TRUE), stringsAsFactors = FALSE)
}))
ev_j[-(1:2)] <- lapply(ev_j[-(1:2)], r4)
wr(ev_j, "T8-threshold-evidence-by-j.csv")
ev_i <- do.call(rbind, lapply(sort(unique(base$icc_x)), function(i) {
  wb <- unique(p0[p0$icc_x == i, c("cell_id", "warn_between_weak")])
  b <- base[base$icc_x == i, ]
  data.frame(icc_x = i, cells = nrow(b),
             warn_between_weak_mean = mean(wb$warn_between_weak),
             within_only_mean = mean(b$rate_within_only), within_only_J10 = mean(b$rate_within_only[b$J == 10]),
             within_only_J100 = mean(b$rate_within_only[b$J == 100]),
             inadmissible_mean = mean(b$rate_inadmissible), clean_J10 = mean(b$rate_clean[b$J == 10]),
             clean_J100 = mean(b$rate_clean[b$J == 100]),
             cov_nie_b_delta_J100_median = stats::median(b$cov_nie_b_delta[b$J == 100]),
             ccov_nie_b_delta_J100_median = stats::median(b$ccov_nie_b_delta[b$J == 100], na.rm = TRUE),
             stringsAsFactors = FALSE)
}))
ev_i[-(1:2)] <- lapply(ev_i[-(1:2)], r4)
wr(ev_i, "T8-threshold-evidence-by-icc.csv")

# ---- markdown rendering of every table (for review; the CSVs are the record) --------------------------------------
shown <- base
any_flag <- shown$small_J | shown$low_icc | shown$unbalanced
shown$cell_id <- ifelse(any_flag, paste0("**", shown$cell_id, "**"), shown$cell_id)
shown$flags <- paste0(ifelse(shown$small_J, "SJ ", ""), ifelse(shown$low_icc, "LI ", ""),
                      ifelse(shown$unbalanced, "UB", ""))
shown$flags <- trimws(shown$flags)
shown$fail <- sprintf("%.3f", shown$rate_fail)
shown$verdict <- paste0(shown$verdict_failure, ifelse(shown$borderline_failure, " (borderline)", ""))
out <- c("# T8 tables (generated by T8-tables.R; the CSVs are the record)", "",
         "Flags: SJ = J <= 20, LI = ICC_X .05, UB = unequal cluster sizes. A bold cell id carries a flag.", "",
         "## Per-cell table (P0, delta and MC intervals)", "",
         md_table(shown[, c("cell_id", "J", "n", "icc_x", "balance", "nie_b", "flags", "fail", "verdict",
                            "rate_within_only", "rate_inadmissible", "cov_nie_w_delta", "ccov_nie_w_delta",
                            "cov_nie_b_delta", "ccov_nie_b_delta", "cov_nie_w_mc", "cov_nie_b_mc", "in_p1")]), "",
         "## Decision table by (n, balance, ICC_X) and J: worst of the two NIE_B cells", "",
         md_table(transform(dec[, c("n", "balance", "icc_x", "J", "cell_ids", "rate_fail_min", "rate_fail_max",
                                    "verdict_failure", "borderline", "proposal_coverage_ok")])), "",
         "## Decision matrix (worst NIE_B cell's P0 failure rate; U use, C caution, X do not fit, * borderline)", "",
         md_table(dm), "",
         "## Minimum grid J below each cutoff, by (n, balance, ICC_X)", "", md_table(mj), "",
         "## Minimum grid J below each cutoff, all ICC levels together", "", md_table(mj_all), "",
         "## P0 against P1, delta interval, medians over the 49 P1 cells", "", md_table(sm), "",
         "## P0 against P1 by J, delta interval, medians", "", md_table(byj), "",
         "## Threshold evidence by J", "", md_table(ev_j), "",
         "## Threshold evidence by ICC_X", "", md_table(ev_i), "",
         "## P1 selection (M7) against T6 rates, cells whose class changes under any definition", "",
         md_table(sel[sel$below_10_in_t6_overlap | sel$above_10_in_t6_overlap_not_selected |
                      sel$below_10_in_t6_exclusive | sel$exclusive_below_10_not_selected_overlap_above |
                      sel$cell_id %in% c(1106),
                      c("cell_id", "J", "n", "icc_x", "balance", "t5_pilot_overlap", "t6_overlap", "t6_exclusive",
                        "selected_p1")]), "",
         "## Failure verdict against the proposal coverage flag (cells)", "", md_table(agree), "")
writeLines(out, file.path(here, "T8-tables.md"))
cat("T8 tables written under", here, "\n")
