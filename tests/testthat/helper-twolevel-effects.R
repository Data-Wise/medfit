# Helpers for the TwoLevelMediationData effect and inference tests (#394, S2 PR2); the fixtures themselves
# are in helper-twolevel.R.

# A hand-built object whose joint vcov carries a non-zero cross-level covariance block.
tl_td_cov <- function(...) {
  nms <- c("a_within", "b_within", "c_prime_within", "a_between", "b_between", "c_prime_between")
  sd <- c(0.10, 0.12, 0.09, 0.25, 0.30, 0.22)
  R <- diag(6)
  R[1, 4] <- R[4, 1] <- -0.4
  R[2, 5] <- R[5, 2] <- 0.3
  R[3, 6] <- R[6, 3] <- 0.2
  R[1, 2] <- R[2, 1] <- 0.1
  vc <- R * outer(sd, sd)
  dimnames(vc) <- list(nms, nms)
  tl_td(vcov = vc, ...)
}

# Hand delta SE, written independently of the package's gradient builder.
tl_hand_se <- function(td, g) {
  nms <- names(td@estimates)
  gv <- stats::setNames(rep(0, length(nms)), nms)
  gv[names(g)] <- g
  sqrt(drop(t(gv) %*% td@vcov %*% gv))
}

# The base fit with lavaan `:=` definitions of every effect: the O3 oracle for estimates and SEs.
tl_defined_fit <- function() {
  tl_cached("fit_defined", tl_fit(tl_sim(), paste0(
    tl_model(),
    "nie_w := a*b\nnie_b := a2*b2\ncontr := a*b - a2*b2\nte_w := a*b + cp\nte_b := a2*b2 + cp2\n",
    "pm_w := a*b / (a*b + cp)\npm_b := a2*b2 / (a2*b2 + cp2)\n"
  )))
}

# lavaan's `:=` label for each effect term it defines.
tl_defined_labels <- c(nie_within = "nie_w", nie_between = "nie_b", nie_contrast = "contr", te_within = "te_w",
                       te_between = "te_b", pm_within = "pm_w", pm_between = "pm_b")

# TRUE when every effect SE of `td` matches lavaan's := SE to 1e-8 (relative). A boolean, so a planted
# defect is asserted with expect_false() (an expectation helper would report one failure per term).
tl_o3_se_ok <- function(td, fit) {
  pe <- lavaan::parameterEstimates(fit)
  ti <- tidy(td, type = "effects")
  all(vapply(names(tl_defined_labels), function(nm) {
    row <- pe[pe$op == ":=" & pe$label == tl_defined_labels[[nm]], ]
    abs(ti$std_error[ti$term == nm] - row$se) / row$se < 1e-8
  }, logical(1)))
}

# --- Two parallel mediators (IG5 T3) ---

# The lavaan labels of the ten paths of a tlp fixture; a path shared across levels carries its within label.
tlp_defined_labels <- function(name = "base") {
  lab <- tlp_lavaan_rows()
  if (name %in% c("shared_a1", "shared_ab1")) lab[["a_M1_between"]] <- "a1"
  if (identical(name, "shared_ab1")) lab[["b_M1_between"]] <- "b1"
  lab
}

# A tlp fixture refit with lavaan `:=` definitions of every effect: the independent oracle for the parallel
# effects and their delta SEs. Returns the fit; `tlp_defined_terms()` maps each effect term to its label.
tlp_defined_fit <- function(name = "base") {
  tl_cached(paste0("tlp_fit_defined_", name), {
    model <- switch(name,
      base = tlp_model(),
      shared_a1 = tlp_model(between_a1 = "a1*X"),
      shared_ab1 = tlp_model(between_a1 = "a1*X", between_y = "b1*M1 + b2B*M2 + cpB*X"),
      stop("unknown fixture: ", name)
    )
    l <- tlp_defined_labels(name)
    ind <- function(m, lev) sprintf("%s*%s", l[[paste0("a_", m, "_", lev)]], l[[paste0("b_", m, "_", lev)]])
    tot <- function(lev) sprintf("(%s + %s)", ind("M1", lev), ind("M2", lev))
    defs <- c(
      sprintf("s1w := %s", ind("M1", "within")), sprintf("s2w := %s", ind("M2", "within")),
      sprintf("niew := %s", tot("within")), sprintf("tew := %s + cp", tot("within")),
      sprintf("pmw := %s / (%s + cp)", tot("within"), tot("within")),
      sprintf("s1b := %s", ind("M1", "between")), sprintf("s2b := %s", ind("M2", "between")),
      sprintf("nieb := %s", tot("between")), sprintf("teb := %s + cpB", tot("between")),
      sprintf("pmb := %s / (%s + cpB)", tot("between"), tot("between")),
      if (!identical(name, "shared_ab1")) sprintf("s1c := %s - %s", ind("M1", "within"), ind("M1", "between")),
      sprintf("s2c := %s - %s", ind("M2", "within"), ind("M2", "between")),
      sprintf("contr := %s - %s", tot("within"), tot("between"))
    )
    tl_fit(tlp_sim(), paste0(model, paste(defs, collapse = "\n"), "\n"))
  })
}

# Effect term -> lavaan label (`:=` rows, plus the NDE path labels).
tlp_defined_terms <- function(name = "base") {
  out <- c(nie_M1_within = "s1w", nie_M2_within = "s2w", nie_within = "niew", nde_within = "cp",
           te_within = "tew", pm_within = "pmw", nie_M1_between = "s1b", nie_M2_between = "s2b",
           nie_between = "nieb", nde_between = "cpB", te_between = "teb", pm_between = "pmb",
           nie_M1_contrast = "s1c", nie_M2_contrast = "s2c", nie_contrast = "contr")
  if (identical(name, "shared_ab1")) out <- out[names(out) != "nie_M1_contrast"]
  out
}

# Max absolute differences between the object's effect estimates/SEs (tidy) and lavaan's `:=` rows.
tlp_defined_diff <- function(td, fit, name = "base") {
  pe <- lavaan::parameterEstimates(fit)
  terms <- tlp_defined_terms(name)
  ti <- suppressWarnings(tidy(td, type = "effects"))
  row <- function(lab) pe[!is.na(pe$label) & pe$label == lab, , drop = FALSE][1L, ]
  ref <- do.call(rbind, lapply(terms, row))
  got <- ti[match(names(terms), ti$term), ]
  c(estimate = max(abs(got$estimate - ref$est)), std_error = max(abs(got$std_error - ref$se)))
}

# Boolean: every effect estimate and SE of `td` equals lavaan's `:=` value to `tol` (absolute). Asserted with
# expect_true() normally and expect_false() under a planted defect.
tlp_defined_ok <- function(td, fit, name = "base", tol = 1e-6) {
  d <- tlp_defined_diff(td, fit, name)
  all(is.finite(d)) && all(d < tol)
}

# Zero every `@vcov` entry that pairs a row of mediator `m1` with a row of mediator `m2` (both levels): the
# planted cross-mediator defect. The validator is bypassed (S7::props<- would re-validate; the matrix stays
# symmetric, so it is valid anyway).
tlp_zero_cross_mediator <- function(td, m1 = "M1", m2 = "M2") {
  vc <- td@vcov
  r1 <- grepl(paste0("_", m1, "_"), rownames(vc))
  r2 <- grepl(paste0("_", m2, "_"), rownames(vc))
  vc[r1, r2] <- 0
  vc[r2, r1] <- 0
  td@vcov <- vc
  td
}
