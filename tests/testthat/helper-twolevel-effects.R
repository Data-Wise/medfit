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
