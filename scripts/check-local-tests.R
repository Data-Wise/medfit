# Test in source mode using the same entry point as the local and full suites.
local({
  elapsed <- function() proc.time()[["elapsed"]]

  description <- read.dcf("DESCRIPTION")
  fields <- intersect(c("Depends", "Imports", "LinkingTo", "Suggests"), colnames(description))
  dependencies <- unlist(strsplit(description[1, fields], ",", fixed = TRUE), use.names = FALSE)
  dependencies <- sub("[[:space:](].*$", "", trimws(dependencies))
  packages <- unique(c("devtools", "pkgload", "testthat", "R6", setdiff(dependencies, c("", "R"))))
  cat("R:", R.version.string, "\nR.home:", R.home(), "\n")
  cat("Library paths:", paste(.libPaths(), collapse = .Platform$path.sep), "\n")
  cat("Source:", description[1, "Package"], description[1, "Version"], getwd(), "\n")
  parallel <- Sys.getenv("TESTTHAT_PARALLEL", unset = NA_character_)
  cat("TESTTHAT_PARALLEL:", if (is.na(parallel)) "unset" else parallel, "\n")
  if (is.na(parallel) && "Config/testthat/parallel" %in% colnames(description)) {
    parallel <- description[1, "Config/testthat/parallel"]
  }
  parallel_requested <- isTRUE(toupper(parallel) == "TRUE")
  if (parallel_requested) {
    cat("test_timing mode=parallel_requested file_wall_time=unavailable\n")
  }
  for (package in packages) {
    path <- find.package(package, quiet = TRUE)
    if (length(path)) {
      version <- utils::packageVersion(package, lib.loc = dirname(path))
      cat("Dependency:", package, format(version), path, "\n")
    } else {
      cat("Dependency:", package, "not installed\n")
    }
  }

  timed_reporter <- R6::R6Class(
    "LocalGateReporter",
    inherit = testthat::ProgressReporter,
    public = list(
      started_at = NULL,
      current_file = NULL,
      file_started_at = NULL,
      files = 0L,
      start_reporter = function(...) {
        cat(sprintf("test_setup finish seconds=%.3f\n", elapsed() - self$started_at))
        super$start_reporter(...)
      },
      start_file = function(file) {
        self$files <- self$files + 1L
        self$current_file <- encodeString(basename(file), quote = '"')
        event <- if (parallel_requested) "replay_start" else "start"
        cat("test_file ", event, " file=", self$current_file, "\n", sep = "")
        flush(stdout())
        self$file_started_at <- proc.time()
        super$start_file(file)
      },
      end_file = function() {
        if (parallel_requested) {
          cat("test_file replay_finish file=", self$current_file, "\n", sep = "")
        } else {
          duration <- proc.time() - self$file_started_at
          cat(sprintf(
            "test_file finish file=%s seconds=%.3f user_seconds=%.3f system_seconds=%.3f\n",
            self$current_file, duration[["elapsed"]], duration[["user.self"]], duration[["sys.self"]]
          ))
        }
        flush(stdout())
        super$end_file()
      }
    )
  )

  reporter <- timed_reporter$new()
  reporter$started_at <- elapsed()
  results <- devtools::test(reporter = reporter, stop_on_failure = FALSE)
  if (is.null(results)) {
    stop("No testthat results were returned.", call. = FALSE)
  }
  results <- as.data.frame(results)
  cat(sprintf(
    "test_totals files=%d blocks=%d passed=%d failed=%d errors=%d warnings=%d skipped=%d\n",
    reporter$files, nrow(results), sum(results$passed), sum(results$failed), sum(results$error),
    sum(results$warning), sum(results$skipped)
  ))
  if (any(results$failed > 0L | results$error)) {
    quit(status = 1L)
  }
})
