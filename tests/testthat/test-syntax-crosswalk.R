# The syntax crosswalk article (vignettes/articles/syntax-crosswalk.qmd) shows semopy output saved in
# tests/sim/oracles/semopy-simple.csv. This keeps the saved output tied to the native fit without Python: a change to
# the native engine that moves the simple model breaks this test, not only the site build.

test_that("the saved semopy output matches fit_sem() with fixed_x = TRUE", {
  csv <- test_path("..", "sim", "oracles", "semopy-simple.csv")
  skip_if_not(file.exists(csv), "tests/sim is not in the installed tests")
  semopy <- utils::read.csv(csv)
  expect_identical(nrow(semopy), 5L)
  labels <- c("mediator1~treatment" = "a", "outcome~mediator1" = "b", "outcome~treatment" = "cp")
  key <- paste0(semopy$lhs, semopy$op, semopy$rhs)
  semopy$term <- ifelse(key %in% names(labels), labels[key], key)
  fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment", mediation_demo, fixed_x = TRUE)
  native <- as.data.frame(generics::tidy(fit))
  i <- match(semopy$term, native$term)
  expect_false(anyNA(i))
  expect_lt(max(abs(semopy$estimate - native$estimate[i])), 1e-5)
  expect_lt(max(abs(semopy$std_error - native$std_error[i])), 1e-5)
  # planted defect: semopy's default stopping rule (a = 0.456039) is outside the tolerance
  expect_gt(abs(0.4560389726 - native$estimate[native$term == "a"]), 1e-5)
})
