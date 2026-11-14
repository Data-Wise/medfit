# engine = "sem" is the name of medfit's maximum-likelihood SEM engine; "native" is its legacy spelling, still
# accepted silently (ADR-engine-vocabulary-and-controls V-1, V-2). fit_mediation() maps "sem" to "native" once at
# entry, so both spellings take the same route and give the same object.

sem_demo_model <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"

test_that("engine = 'sem' and engine = 'native' give identical fits on mediation_demo", {
  fit_sem_name <- fit_mediation(model = sem_demo_model, data = mediation_demo, treatment = "treatment",
                                mediator = "mediator1", engine = "sem")
  fit_legacy <- fit_mediation(model = sem_demo_model, data = mediation_demo, treatment = "treatment",
                              mediator = "mediator1", engine = "native")
  fit_legacy_2 <- fit_mediation(model = sem_demo_model, data = mediation_demo, treatment = "treatment",
                                mediator = "mediator1", engine = "native")
  expect_s7_class(fit_sem_name, MediationData)
  expect_identical(coef(fit_sem_name), coef(fit_legacy))
  expect_identical(vcov(fit_sem_name), vcov(fit_legacy))
  # family_y and family_m hold gaussian() objects whose closures get a fresh environment on every call, so two
  # engine = "native" fits are not base-identical either; "sem" adds no difference beyond that one.
  expect_true(identical(fit_sem_name, fit_legacy, ignore.environment = TRUE))
  expect_identical(identical(fit_sem_name, fit_legacy), identical(fit_legacy, fit_legacy_2))
  for (p in setdiff(S7::prop_names(fit_sem_name), c("family_y", "family_m"))) {
    expect_true(identical(S7::prop(fit_sem_name, p), S7::prop(fit_legacy, p)), info = p)
  }
  for (p in c("family_y", "family_m")) {
    expect_identical(S7::prop(fit_sem_name, p)[c("family", "link")], S7::prop(fit_legacy, p)[c("family", "link")])
  }
})

test_that("engine = 'native' stays silent (no warning, message or lifecycle signal)", {
  expect_no_condition(fit_mediation(model = sem_demo_model, data = mediation_demo, treatment = "treatment",
                                    mediator = "mediator1", engine = "native"))
  expect_no_condition(fit_mediation(model = sem_demo_model, data = mediation_demo, treatment = "treatment",
                                    mediator = "mediator1", engine = "sem"))
})

test_that("engine = 'sem' reports the same guard messages as engine = 'native'", {
  for (eng in c("sem", "native")) {
    expect_error(fit_mediation(data = mediation_demo, treatment = "treatment", mediator = "mediator1", engine = eng),
                 "engine = \"native\" needs `model`", fixed = TRUE)
  }
})

test_that("an unknown engine errors with the checkmate choice message, which lists 'sem'", {
  err <- expect_error(fit_mediation(outcome ~ treatment + mediator1, mediator1 ~ treatment, mediation_demo,
                                    "treatment", "mediator1", engine = "sems"),
                      "Assertion on 'engine' failed: Must be element of set", fixed = TRUE)
  for (eng in c("glm", "regmedint", "lmer", "sem", "native")) {
    expect_match(conditionMessage(err), paste0("'", eng, "'"), fixed = TRUE)
  }
})

test_that("`model` with the glm engine still errors", {
  expect_error(fit_mediation(outcome ~ treatment + mediator1, mediator1 ~ treatment, mediation_demo,
                             "treatment", "mediator1", model = sem_demo_model),
               "`model` is only used with engine = \"native\".", fixed = TRUE)
})
