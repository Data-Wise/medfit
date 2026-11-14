# TwoLevelMediationData provenance (0.18.0 plan S4, spec R-12 to R-15): the optional `source_version`
# property, `lavaan_version` that may be empty for a fit lavaan did not make, the one reader
# `.twolevel_source_version()`, and objects saved by medfit 0.17.0.

# --- Test 1: every 0.17.0 call constructs with unchanged stored values (R-12, R-13) ---
# Planted defect: make `source_version` required.

test_that("0.17.0 constructor calls store unchanged values and an empty source_version", {
  td <- tl_td()
  expect_identical(td@source_version, character(0))
  expect_identical(td@lavaan_version, "0.7.3")
  expect_identical(td@source, "lavaan")
  expect_identical(td@source_package, "lavaan")
  expect_identical(.twolevel_source_version(td), "0.7.3")

  nat <- tl_td(source = "native")
  expect_identical(nat@source_version, character(0))
  expect_identical(nat@source, "native")
  expect_identical(nat@lavaan_version, "0.7.3")

  wo <- tl_td(within_only = TRUE)
  expect_identical(wo@source_version, character(0))
})

# --- Test 2: a fit lavaan did not make needs no lavaan version (R-13, R-14) ---
# Planted defect: restore the length-1 check on `lavaan_version`.

test_that("lavaan_version may be empty when source_version is given", {
  td <- tl_td(source = "native", source_package = "medfit", lavaan_version = character(0),
              source_version = "0.18.0")
  expect_identical(td@lavaan_version, character(0))
  expect_identical(.twolevel_source_version(td), "0.18.0")

  s <- summary(td)
  expect_identical(s$provenance[["source_version"]], "0.18.0")
  txt <- paste(utils::capture.output(print(s)), collapse = "\n")
  expect_match(txt, "native 0.18.0", fixed = TRUE)
  expect_match(paste(utils::capture.output(print(td)), collapse = "\n"), "native 0.18.0 fit", fixed = TRUE)

  # Neither version: the reader says so instead of returning character(0)
  none <- tl_td(source = "native", source_package = "medfit", lavaan_version = character(0))
  expect_identical(.twolevel_source_version(none), NA_character_)
  expect_no_error(utils::capture.output(print(summary(none))))

  # source_version wins over lavaan_version when both are set
  both <- tl_td(source_version = "0.7.4")
  expect_identical(.twolevel_source_version(both), "0.7.4")

  # A supplied lavaan_version is checked as in 0.17.0: one non-missing value
  expect_error(tl_td(lavaan_version = c("0.6.1", "0.6.2")), "lavaan_version must")
  expect_error(tl_td(lavaan_version = NA_character_), "lavaan_version must")
})

# --- Test 3: source_version is validated on construction and on assignment (R-12) ---
# Planted defect: drop the length check.

test_that("source_version rejects several values, NA and the empty string, also through @<-", {
  bad <- list(c("a", "b"), NA_character_, "")
  for (v in bad) {
    expect_error(tl_td(source_version = v), "source_version must")
    td <- tl_td()
    expect_error(td@source_version <- v, "source_version must")
  }
  td <- tl_td()
  td@source_version <- "0.18.0"
  expect_identical(.twolevel_source_version(td), "0.18.0")
  td@source_version <- character(0)
  expect_identical(.twolevel_source_version(td), "0.7.3")
})

# --- Test 4: an object saved by medfit 0.17.0 (R-14) ---
# The fixture keeps its 0.17.0 class definition after readRDS(), which has no `source_version` property.
# Planted defect: read `x@source_version` directly in the reader.

test_that("an object saved by medfit 0.17.0 prints, summarizes and reports its lavaan version", {
  path <- test_path("fixtures", "twolevel-0.17.0.rds")
  expect_true(file.exists(path))
  old <- readRDS(path)
  expect_false(S7::prop_exists(old, "source_version"))
  expect_true(S7::S7_inherits(old))
  expect_identical(.twolevel_source_version(old), old@lavaan_version)
  expect_true(nzchar(old@lavaan_version))

  out <- paste(utils::capture.output(print(old)), collapse = "\n")
  expect_match(out, "<TwoLevelMediationData>", fixed = TRUE)
  expect_match(out, paste0("lavaan ", old@lavaan_version, " fit"), fixed = TRUE)
  s <- summary(old)
  expect_identical(s$provenance[["source_version"]], old@lavaan_version)
  txt <- paste(utils::capture.output(print(s)), collapse = "\n")
  expect_match(txt, paste("lavaan", old@lavaan_version), fixed = TRUE)
})

# --- The lavaan extractor stores the same version in both fields ---

test_that("the lavaan extractor sets source_version equal to lavaan_version", {
  skip_if_not_installed("lavaan")
  td <- tl_extract(tl_defined_fit())
  expect_length(td@source_version, 1L)
  expect_identical(td@source_version, td@lavaan_version)
  expect_identical(.twolevel_source_version(td), td@lavaan_version)
})
