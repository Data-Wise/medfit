# 07-preflight.R: S0 preflight checks (a)-(e) of PLAN-native-sem-implementation-2026-10-09.md.
# Each check prints its measured value, the plan's expected value, and PASS or FAIL against the plan's decision rule.
# Reads RMediation's memory_exp data only; writes nothing outside results/.
suppressMessages({library(OpenMx); library(RMediation)})
mxOption(NULL, "Number of Threads", 1)
data(memory_exp, package = "RMediation")
d <- as.data.frame(memory_exp); d$x <- as.numeric(d$x) - 1
man <- c("x", "repetition", "imagery", "recall")
res <- list()
chk <- function(id, name, ok, value, expected, rule) {
  cat(sprintf("[%s] %s: %s | measured %s | plan %s | rule: %s\n", id, name, if (ok) "PASS" else "FAIL", value, expected, rule))
  res[[id]] <<- ok
}

# Correctly labeled model: x -> repetition = a1, x -> imagery = a2, x -> recall = cp, repetition -> recall = b1, imagery -> recall = b2.
build <- function(name = "m", means = TRUE, data = d, fixed = NULL, extra = NULL) {
  dat <- if (!is.data.frame(data)) mxData(observed = data$cov, type = "cov", numObs = n) else mxData(observed = data, type = "raw")
  lab <- function(l) if (!is.null(fixed) && l %in% names(fixed)) list(free = FALSE, values = fixed[[l]]) else list(free = TRUE, values = .2)
  p <- function(from, to, l) { o <- lab(l); mxPath(from = from, to = to, arrows = 1, free = o$free, values = o$values, labels = l) }
  parts <- list(p("x", "repetition", "a1"), p("x", "imagery", "a2"), p("x", "recall", "cp"),
                p("repetition", "recall", "b1"), p("imagery", "recall", "b2"),
                mxPath(from = man, arrows = 2, free = TRUE, values = .8))
  if (means) parts <- c(parts, list(mxPath(from = "one", to = man, arrows = 1, free = TRUE, values = .1)))
  m <- do.call(mxModel, c(list(name, type = "RAM", manifestVars = man), parts,
                          list(mxAlgebra(a1 * b1, name = "ind1"), dat)))
  if (!is.null(extra)) m <- mxModel(m, extra)
  m
}
fit <- function(m) { invisible(capture.output(f <- suppressMessages(mxTryHard(m, checkHess = FALSE, silent = TRUE, extraTries = 15)))); f }
ll <- function(f) f$output$Minus2LogLikelihood

# (a) Mean structure versus diffLL: identical with and without the `one` paths. OpenMx needs a means vector for raw data, so the
# no-means fits use the ML covariance matrix (n * cov / (n - 1)) with numObs = n: the -2LL differs by a constant, the diffLL must not.
n <- nrow(d); dc <- list(cov = cov(d[man]) * (n - 1) / n)
full_m  <- fit(build("full_m")); a_m <- fit(build("a_m", fixed = list(a1 = 0))); b_m <- fit(build("b_m", fixed = list(b1 = 0)))
full_n  <- fit(build("full_n", means = FALSE, data = dc)); a_n <- fit(build("a_n", means = FALSE, data = dc, fixed = list(a1 = 0)))
b_n <- fit(build("b_n", means = FALSE, data = dc, fixed = list(b1 = 0)))
dA_m <- ll(a_m) - ll(full_m); dB_m <- ll(b_m) - ll(full_m); dA_n <- ll(a_n) - ll(full_n); dB_n <- ll(b_n) - ll(full_n)
chk("a1", "diffLL a1 == 0, with means", abs(dA_m - 221.045546) < 1e-4, sprintf("%.6f", dA_m), "221.045546", "within 1e-4 of the plan value")
chk("a2", "diffLL b1 == 0, with means", abs(dB_m - 0.083100) < 1e-4, sprintf("%.6f", dB_m), "0.083100", "within 1e-4 of the plan value")
gap <- max(abs(dA_m - dA_n), abs(dB_m - dB_n))
chk("a3", "diffLL without means equals with means", is.finite(gap) && gap < 1e-6,
    sprintf("%.2e (a1 == 0: %.6f vs %.6f; b1 == 0: %.6f vs %.6f)", gap, dA_m, dA_n, dB_m, dB_n), "< 1e-6", "equal to 1e-6, else stop and ask the author")

# (b) OpenMx SEs under mxConstraint: NA for the constrained parameter; others differ from the fixed-parameter model.
con <- fit(build("con", extra = mxConstraint(a1 == 0, name = "c1")))
fx  <- a_m
se_of <- function(f) { s <- suppressWarnings(summary(f)$parameters); setNames(s[["Std.Error"]], s$name) }
se_c <- tryCatch(se_of(con), error = function(e) NULL); se_f <- tryCatch(se_of(fx), error = function(e) NULL)
na_con <- !is.null(se_c) && ("a1" %in% names(se_c)) && is.na(se_c[["a1"]])
shared <- setdiff(intersect(names(se_c), names(se_f)), "a1")
rels <- abs(se_c[shared] - se_f[shared]) / se_f[shared]
rel <- if (length(shared)) max(rels, na.rm = TRUE) else NA
struct <- intersect(shared, c("a2", "cp", "b1", "b2"))
cat(sprintf("    per-parameter relative SE difference: %s\n", paste(sprintf("%s %.2e", shared, rels), collapse = "; ")))
est_c <- coef(con); est_f <- coef(fx); cpn <- "cp"
cat(sprintf("    cp: SE %.6f (mxConstraint) vs %.6f (fixed); estimate %.6f vs %.6f (relative estimate difference %.2e)\n", se_c[[cpn]], se_f[[cpn]], est_c[[cpn]], est_f[[cpn]], abs(est_c[[cpn]] - est_f[[cpn]]) / abs(est_f[[cpn]])))
cat(sprintf("    structural paths only (a2, cp, b1, b2): max %.2e\n", max(rels[struct], na.rm = TRUE)))
chk("b1", "constrained parameter SE is NA under mxConstraint", isTRUE(na_con), as.character(isTRUE(na_con)), "TRUE", "Q8: no mxConstraint in SE oracles")
chk("b2", "other SEs differ from fixed-parameter model", is.finite(rel) && rel > 1e-5 && rel < 1e-2, sprintf("%.2e", rel), "up to 4.1e-4", "Q8 stands if a difference of this order appears")

# (c) The nonlinear MBCO trap: ind1 == 0 lands at a1 = 0 under mxTryHard (seeds 1-3 identical).
for (s in 1:3) {
  set.seed(s)
  nl <- fit(build(paste0("nl", s), extra = mxConstraint(ind1 == 0, name = "ind0")))
  est <- coef(nl)
  dl <- ll(nl) - ll(full_m)
  chk(paste0("c", s), sprintf("nonlinear ind1 == 0, seed %d", s), abs(dl - 221.045546) < 1e-2 && abs(est[["a1"]]) < 1e-3,
      sprintf("diffLL %.6f, a1 = %.2e, b1 = %.4f", dl, est[["a1"]], est[["b1"]]), "diffLL 221.045546 at a1 = 0 (the b1 = 0 optimum is 0.083100)",
      "J2 MBCO known-answer = min(diffLL(a1 == 0), diffLL(b1 == 0)) from the two linear solves")
}
chk("c4", "min of the two linear solves", abs(min(dA_m, dB_m) - 0.083100) < 1e-4, sprintf("%.6f", min(dA_m, dB_m)), "0.083100", "S19 known-answer")

# (d) RMediation's mbco() Rd example as written is mislabeled: the self-path x -> x is dropped and the labels shift.
endVar <- c("x", "repetition", "imagery", "recall")
ex <- mxModel("ex", type = "RAM", manifestVars = man,
  mxPath(from = "x", to = endVar, arrows = 1, free = TRUE, values = .2, labels = c("a1", "a2", "cp")),
  mxPath(from = "repetition", to = "recall", arrows = 1, free = TRUE, values = .2, labels = "b1"),
  mxPath(from = "imagery", to = "recall", arrows = 1, free = TRUE, values = .2, labels = "b2"),
  mxPath(from = man, arrows = 2, free = TRUE, values = .8),
  mxPath(from = "one", to = endVar, arrows = 1, free = TRUE, values = .1),
  mxAlgebra(a1 * b1, name = "ind1"), mxAlgebra(a2 * b2, name = "ind2"),
  mxData(observed = d, type = "raw"))
Am <- ex$A$labels
shift <- c(rep_lab = Am["repetition", "x"], img_lab = Am["imagery", "x"], rec_lab = Am["recall", "x"])
chk("d1", "labels shift in the Rd example", identical(unname(shift), c("a2", "cp", "a1")), paste(shift, collapse = ","), "a2,cp,a1 (x->repetition, x->imagery, x->recall)",
    "if not shifted the as-written value is correct; S19 then drops the separate correctly-labeled assertions")
ex_full <- fit(ex)
ex_null <- fit(mxModel(ex, mxConstraint(ind1 == 0, name = "ind1_eq0_constr"), name = "ex_null"))
dl_ex <- ll(ex_null) - ll(ex_full)
chk("d2", "as-written example diffLL", abs(dl_ex - 0.060332) < 1e-4, sprintf("%.6f", dl_ex), "0.060332", "S19 reproduces as written (literal J2) and the correctly labeled values")

# (e) Versions.
vs <- sapply(c("lavaan", "OpenMx", "nloptr", "RMediation"), function(p) as.character(packageVersion(p)))
cat("[e] versions:", paste(names(vs), vs, collapse = "; "), "| plan: lavaan 0.7-2, OpenMx 2.22.11, nloptr 2.2.1\n")
cat("[g] budgets are recorded in the plan (always-on test file <= 10 s; one fit of a p <= 10 model < 5 ms median, 05b SLSQP 2.6 ms); see results/05b-optimizer-speed.out\n")

bad <- names(res)[!unlist(res)]
if (length(bad)) { cat("PREFLIGHT FAILED:", paste(bad, collapse = ", "), "\n"); quit(status = 1) }
cat("PREFLIGHT OK: all", length(res), "checks passed\n")
