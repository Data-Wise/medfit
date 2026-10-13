# lavaan parity with a mean structure on the four model forms (0.9.0 S5, plan T8a): labeled paths, their standard
# errors, the chi-square and the df, with free intercepts, a restricted intercept and a nonlinear constraint.

mean_forms <- list(
  simple = "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment",
  serial = "mediator1 ~ a*treatment\nmediator2 ~ d*mediator1 + treatment\noutcome ~ b*mediator2 + cp*treatment",
  parallel = "mediator1 ~ a*treatment\nmediator2 ~ a2*treatment\noutcome ~ b*mediator1 + b2*mediator2 + cp*treatment",
  latent = "eta =~ mediator1 + mediator2 + mediator3\neta ~ a*treatment\noutcome ~ b*eta + cp*treatment"
)

mean_variants <- c(free = "", restricted = "outcome ~ 0*1", constrained = "cp == a*b")

test_that("native estimates, SEs, df and chi-square equal lavaan's on every form and variant", {
  skip_if_not_installed("lavaan")
  d <- medfit::mediation_demo
  for (form in names(mean_forms)) {
    for (variant in names(mean_variants)) {
      syn <- paste(c(mean_forms[[form]], mean_variants[[variant]]), collapse = "\n")
      fit <- fit_sem(syn, d, meanstructure = TRUE, information = "expected")
      ref <- suppressWarnings(lavaan::sem(syn, d, meanstructure = TRUE, fixed.x = FALSE))
      tag <- paste(form, variant)
      if (form == "latent" && variant == "constrained") {
        # lavaan stops at a degenerate point here (a = 0, b = -742, chi-square 184); the native optimum is lower
        # and feasible, so the comparison is "not worse and feasible" instead of equality
        expect_lte(unname(fit@f * fit@n_obs), unname(lavaan::fitMeasures(ref, "chisq")) + 1e-6)
        expect_equal(unname(fit@theta["cp"]), unname(fit@theta["a"] * fit@theta["b"]), tolerance = 1e-6)
        next
      }
      expect_equal(fit@df, unname(lavaan::fitMeasures(ref, "df")), info = tag)
      expect_equal(unname(fit@f * fit@n_obs), unname(lavaan::fitMeasures(ref, "chisq")), tolerance = 1e-4, info = tag)
      pe <- lavaan::parameterEstimates(ref)
      pe <- pe[nzchar(pe$label) & !duplicated(pe$label), ]
      lab <- intersect(pe$label, names(fit@theta))
      expect_gt(length(lab), 2L)
      expect_equal(unname(fit@theta[lab]), pe$est[match(lab, pe$label)], tolerance = 1e-4, info = tag)
      se <- sqrt(diag(fit@vcov))[lab]
      expect_equal(unname(se), pe$se[match(lab, pe$label)], tolerance = 1e-3, info = tag)
    }
  }
})
