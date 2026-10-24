args <- commandArgs(TRUE); S <- args[1]; v <- args[2]
.libPaths(c(file.path(S, paste0("lib_", v)), .libPaths())); Sys.setenv(NOT_CRAN = "true")
all <- readRDS(file.path(S, "medfit-all.rds")); b <- all$base; d <- all[[v]]
bad <- function(x) x$failed > 0 | x$error
files <- unique(d$file[bad(d) & !paste(d$file, d$test) %in% paste(b$file, b$test)[bad(b)]])
library(testthat); library(medfit)
out <- list()
for (f in files) {
  r <- test_file(file.path(S, "src_base", "tests", "testthat", f), package = "medfit", load_package = "installed",
                 reporter = ListReporter$new(), stop_on_failure = FALSE)
  for (t in r) for (res in t$results) if (inherits(res, c("expectation_failure", "expectation_error"))) {
    out[[length(out) + 1]] <- data.frame(file = f, test = t$test, kind = class(res)[1],
      msg = substr(gsub("\\s+", " ", conditionMessage(res)), 1, 260))
  }
}
o <- do.call(rbind, out); saveRDS(o, file.path(S, sprintf("why-%s.rds", v)))
cat(nrow(o), "failure records\n")
