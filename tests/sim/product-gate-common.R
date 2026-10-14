# Shared by the product-term gates (exo-product-null.R, exo-product-fixed-var.R, product-correlated-residuals.R,
# four-way-known-answer.R) and by tests/sim/run-gates.R, so the pass rule has exactly one implementation.
#
# PATH. The gates reach the product through a precomputed data column (`PRODUCT_PATH=column`, the default): the model
# writes `p` and the data holds `p = x * w`. The model-fitting function is an argument of each gate
# (`fit_fun(syntax, data)`, default `fit_sem()`), and `PRODUCT_PATH=colon` writes the product as `x:w` and drops the
# column from the data, so the same gates run through the `:` path (the null gate does, as gates.csv row
# "product-null-colon").

# Product term as written in a model: the column name, or the `:` spelling of its factors.
product_term <- function(path, a, b) if (identical(path, "colon")) paste0(a, ":", b) else "p"

# The canonical coefficient-name spelling of a product (amendment rule 7: C-locale sort of the two names).
product_name <- function(path, a, b) {
  if (identical(path, "colon")) paste(sort(c(a, b), method = "radix"), collapse = ":") else "p"
}

# Substitute the product term for the placeholder `P` in a model template.
product_syntax <- function(template, term) gsub("\\bP\\b", term, template)

# Data for a fit: the product column is kept only on the column path.
product_data <- function(d, path) if (identical(path, "colon")) d[setdiff(names(d), "p")] else d

# ---- shared by the exogenous-product gates (exo-product-null.R, exo-product-fixed-var.R) ---------------------------
# One replication of the true model m = .7 x + e; y = .4 m + .3 x + .3 w + .2 (x w) + e'. `endogenous` (the planted
# defect of the null gate) makes the model's product x * m instead of x * w. Returns c(chisq, df), NA on any failure
# (a failed fit, or a glance() that errors, is an unfitted replication, never an aborted gate).
exo_product_chisq <- function(fit_fun, path, template, n, seed, xdist, endogenous = FALSE) {
  tryCatch({
    set.seed(seed)
    if (xdist == "norm") {
      x <- stats::rnorm(n)
      w <- stats::rnorm(n)
    } else {
      x <- stats::rexp(n) - 1
      w <- stats::rexp(n) - 1
    }
    m <- 0.7 * x + stats::rnorm(n)
    y <- 0.4 * m + 0.3 * x + 0.3 * w + 0.2 * (x * w) + stats::rnorm(n)
    fac <- if (endogenous) c("x", "m") else c("x", "w")
    cols <- list(x = x, w = w, m = m)
    p <- cols[[fac[1]]] * cols[[fac[2]]]
    d <- data.frame(x, w, m, y, p)
    syn <- product_syntax(template, product_term(path, fac[1], fac[2]))
    f <- suppressWarnings(fit_fun(syn, product_data(d, path)))
    # `glance()` reports chi-square as NA for a model whose test is invalid (an endogenous product, a restricted
    # exogenous block); the gates must see the number, so they read the test-only accessor (plan F10).
    c(.sem_chisq(f), f@df) # nolint: object_usage_linter.
  }, error = function(e) c(NA_real_, NA_real_))
}

# Rejection rates and the mean chi-square over `reps` replications of one (distribution, template) cell.
exo_product_cell <- function(fit_fun, path, template, n, reps, xdist, cores, wrongdf = FALSE, endogenous = FALSE) {
  r <- do.call(rbind, parallel::mclapply(seq_len(reps), function(i) {
    exo_product_chisq(fit_fun, path, template, n, i, xdist, endogenous)
  }, mc.cores = cores))
  ok <- !is.na(r[, 1])
  df <- if (any(ok)) r[which(ok)[1], 2] else NA_real_
  p <- stats::pchisq(r[, 1], df + if (wrongdf) 1 else 0, lower.tail = FALSE)
  data.frame(df = df, reject05 = mean(p < 0.05, na.rm = TRUE), reject01 = mean(p < 0.01, na.rm = TRUE),
             mean_chisq = mean(r[ok, 1]), reps = reps, reps_ok = sum(ok))
}

# ---- pass rules, one function per gate; each returns data.frame(check, pass, detail) ----------------------------
.pg_chk <- function(check, ok, detail) {
  data.frame(check = check, pass = isTRUE(ok), detail = detail, stringsAsFactors = FALSE)
}
.pg_fmt <- function(x) format(x, digits = 3, scientific = FALSE)

# gate "product-null": rows xdist x path; calibration of the normal-theory test for an exogenous product.
#   tol_est = half-width of the band around the nominal 0.05 rejection rate (derivation: the Monte Carlo SE of a rate
#   near 0.05 over 1000 replications is 0.007, so 0.02 is about 2.9 SE); tol_se = allowed |mean chi-square - df|
#   (SE of the mean is sqrt(2 df / 1000) = 0.063 at df 2, so 0.15 is about 2.4 SE); min_pass = fraction of
#   replications that must have fitted.
rule_product_null <- function(d, s) {
  if (!nrow(d)) {
    return(.pg_chk("rows", FALSE, sprintf("0 rows, expected %d", s$expected_rows)))
  }
  rbind(
    .pg_chk("rows", nrow(d) == s$expected_rows, sprintf("%d rows, expected %d", nrow(d), s$expected_rows)),
    .pg_chk("fitted replications", all(d$reps_ok >= s$min_pass * d$reps),
            sprintf("smallest fraction %s, need at least %s", .pg_fmt(min(d$reps_ok / d$reps)), .pg_fmt(s$min_pass))),
    .pg_chk("rejection at .05", all(abs(d$reject05 - 0.05) <= s$tol_est),
            sprintf("range %s to %s, band 0.05 +/- %s", .pg_fmt(min(d$reject05)), .pg_fmt(max(d$reject05)),
                    .pg_fmt(s$tol_est))),
    .pg_chk("mean chi-square", all(abs(d$mean_chisq - d$df) <= s$tol_se),
            sprintf("max |mean - df| %s, limit %s", .pg_fmt(max(abs(d$mean_chisq - d$df))), .pg_fmt(s$tol_se)))
  )
}

# gate "product-fixed-var": rows xdist x configuration; each row carries `expect` = "calibrated" or "miscalibrated".
#   calibrated rows: rejection within tol_est of 0.05 and |mean chi-square / df - 1| <= tol_se (relative);
#   miscalibrated rows (documented in the amendment, section 2a: a skewed factor's variance fixed, or covariances
#   dropped by the pairing rule): rejection at .05 of at least min_pass. This pins the evidence behind the model-test
#   policy: if a miscalibrated configuration ever becomes calibrated, the policy can be relaxed deliberately.
rule_product_fixed_var <- function(d, s) {
  if (!nrow(d)) {
    return(.pg_chk("rows", FALSE, sprintf("0 rows, expected %d", s$expected_rows)))
  }
  cal <- d$expect == "calibrated"
  mis <- d$expect == "miscalibrated"
  # the colon path cannot write the `fixvar` configuration (no `~~` statement on a product), so it has two rows fewer
  n_exp <- s$expected_rows - if ("path" %in% names(d) && all(d$path == "colon")) 2L else 0L
  rbind(
    .pg_chk("rows", nrow(d) == n_exp, sprintf("%d rows, expected %d", nrow(d), n_exp)),
    .pg_chk("fitted replications", all(d$reps_ok >= 0.99 * d$reps),
            sprintf("smallest fraction %s, need at least 0.99", .pg_fmt(min(d$reps_ok / d$reps)))),
    .pg_chk("calibrated rows: rejection at .05", all(abs(d$reject05[cal] - 0.05) <= s$tol_est),
            sprintf("%d rows, range %s to %s, band 0.05 +/- %s", sum(cal), .pg_fmt(min(d$reject05[cal])),
                    .pg_fmt(max(d$reject05[cal])), .pg_fmt(s$tol_est))),
    .pg_chk("calibrated rows: mean chi-square", all(abs(d$mean_chisq[cal] / d$df[cal] - 1) <= s$tol_se),
            sprintf("max relative gap %s, limit %s", .pg_fmt(max(abs(d$mean_chisq[cal] / d$df[cal] - 1))),
                    .pg_fmt(s$tol_se))),
    .pg_chk("miscalibrated rows stay miscalibrated", sum(mis) > 0 && all(d$reject05[mis] >= s$min_pass),
            sprintf("%d rows, smallest rejection %s, need at least %s", sum(mis),
                    if (any(mis)) .pg_fmt(min(d$reject05[mis])) else "none", .pg_fmt(s$min_pass)))
  )
}

# gate "product-corr": rows design x residual-covariance flag x seed; `gap` = max |SEM - equation-wise OLS|.
#   `expect` = "match": the SEM estimates equal equation-wise OLS (recursive model with uncorrelated residuals, or
#   identical regressor sets) within tol_est (the optimizer's 1e-6, tenfold margin);
#   `expect` = "leak": non-nested regressor sets with a free residual covariance (the SUR/GLS estimator), where the
#   gap must exceed tol_se in at least min_pass of the rows. This is the evidence for rule 9 (no residual covariance
#   in a product model).
rule_product_corr <- function(d, s) {
  if (!nrow(d)) {
    return(.pg_chk("rows", FALSE, sprintf("0 rows, expected %d", s$expected_rows)))
  }
  # On the colon path rule 9 refuses a model with a free residual covariance: a NA gap there is the rule working, but
  # only when the recorded error names the feature (an unrelated failure is a failed run, not a refusal).
  err <- if ("err" %in% names(d)) as.character(d$err) else rep("", nrow(d))
  refused <- d$path == "colon" & d$cvf & is.na(d$gap) & grepl("residual covariance", err, ignore.case = TRUE)
  match_rows <- d$expect == "match" & !is.na(d$gap)
  leak <- d$expect == "leak" & !refused
  share <- if (any(leak)) mean(d$gap[leak] >= s$tol_se, na.rm = TRUE) else 1
  rbind(
    .pg_chk("rows", nrow(d) == s$expected_rows, sprintf("%d rows, expected %d", nrow(d), s$expected_rows)),
    .pg_chk("fitted runs", !anyNA(d$gap[!refused]),
            sprintf("%d runs without a gap, %d refused by rule 9", sum(is.na(d$gap[!refused])), sum(refused))),
    .pg_chk("match rows: SEM equals OLS", any(match_rows) && isTRUE(max(d$gap[match_rows]) <= s$tol_est),
            sprintf("%d rows, max gap %s, limit %s", sum(match_rows),
                    if (any(match_rows)) .pg_fmt(max(d$gap[match_rows])) else "none", .pg_fmt(s$tol_est))),
    .pg_chk("leak rows: SEM differs from OLS", isTRUE(share >= s$min_pass),
            sprintf("%.0f%% of %d rows at or above %s, need at least %.0f%%", 100 * share, sum(leak),
                    .pg_fmt(s$tol_se), 100 * s$min_pass))
  )
}

# gate "four-way-kat": rows scenario x route x component. bias_z = (mean estimate - truth) / (SD / sqrt(reps));
#   tol_est bounds |bias_z|; se_ratio = RMS reported SE / empirical SD, tol_se bounds |se_ratio - 1|.
#   Derivation of tol_se at 1000 replications: the SD of a sample SD is 1/sqrt(2 (R - 1)) = 2.2% of it, so four
#   sigmas is 0.090; add 0.03 for the second-order terms of the delta method that the empirical SD includes
#   (observed |se_ratio - 1| <= 0.03 at R = 2000, n = 400): 0.12. tol_est = 4 sigmas.
rule_four_way_kat <- function(d, s) {
  if (!nrow(d)) {
    return(.pg_chk("rows", FALSE, sprintf("0 rows, expected %d", s$expected_rows)))
  }
  rbind(
    .pg_chk("rows", nrow(d) == s$expected_rows, sprintf("%d rows, expected %d", nrow(d), s$expected_rows)),
    .pg_chk("fitted replications", all(d$reps_ok >= s$min_pass * d$reps),
            sprintf("smallest fraction %s, need at least %s", .pg_fmt(min(d$reps_ok / d$reps)), .pg_fmt(s$min_pass))),
    .pg_chk("missing statistics", !anyNA(d$bias_z) && !anyNA(d$se_ratio),
            sprintf("%d NA bias_z, %d NA se_ratio", sum(is.na(d$bias_z)), sum(is.na(d$se_ratio)))),
    .pg_chk("bias (Monte Carlo SEs)", isTRUE(max(abs(d$bias_z)) <= s$tol_est),
            sprintf("max |bias_z| %s, limit %s", .pg_fmt(max(abs(d$bias_z))), .pg_fmt(s$tol_est))),
    .pg_chk("standard errors vs empirical SD", isTRUE(max(abs(d$se_ratio - 1)) <= s$tol_se),
            sprintf("max |se_ratio - 1| %s, limit %s", .pg_fmt(max(abs(d$se_ratio - 1))), .pg_fmt(s$tol_se)))
  )
}

product_gate_rules <- list(
  "product-null" = rule_product_null, "product-null-colon" = rule_product_null,
  "product-fixed-var" = rule_product_fixed_var,
  "product-corr" = rule_product_corr, "four-way-kat" = rule_four_way_kat
)

# Used by each script: print its verdict from its own results and return the exit status (0 met, 1 not met).
product_gate_status <- function(gate, res, spec_row) {
  v <- product_gate_rules[[gate]](res, spec_row)
  for (j in seq_len(nrow(v))) {
    cat(sprintf("  %-4s %-40s %s\n", if (v$pass[j]) "ok" else "FAIL", v$check[j], v$detail[j]))
  }
  cat(sprintf("\n%s\n", if (all(v$pass)) "RULE MET" else "RULE NOT MET"))
  if (all(v$pass)) 0L else 1L
}

# The gate's row of gates.csv, read from the package root.
product_gate_spec <- function(gate) {
  s <- utils::read.csv("tests/sim/gates.csv", stringsAsFactors = FALSE, na.strings = c("NA", ""))
  s <- s[s$gate == gate, , drop = FALSE]
  stopifnot(nrow(s) == 1L)
  s
}

product_write_results <- function(res, prefix) {
  dir.create("tests/sim/results", showWarnings = FALSE)
  utils::write.csv(res, sprintf("tests/sim/results/%s-%s.csv", prefix, Sys.Date()), row.names = FALSE)
}
