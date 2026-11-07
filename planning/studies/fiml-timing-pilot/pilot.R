# FIML stage-0 timing pilot. Run from the repo root: Rscript planning/studies/fiml-timing-pilot/pilot.R [smoke]
args <- commandArgs(TRUE); smoke <- "smoke" %in% args
out <- "_agents_workspace/fiml-timing-pilot"; dir.create(out, recursive = TRUE, showWarnings = FALSE)
stopifnot(identical(system("git status --porcelain -- R DESCRIPTION NAMESPACE", intern = TRUE), character(0)))
src <- system("git rev-parse HEAD", intern = TRUE)
devtools::load_all(quiet = TRUE)
# Study-only override of the stage-0 guard (in-process, never committed).
utils::assignInNamespace(".fiml_source_inference_admitted", function() TRUE, ns = "medfit")
stopifnot(isTRUE(medfit:::.fiml_source_inference_admitted()))
writeLines(c(paste("source", src), R.version.string, paste("cores", parallel::detectCores()),
             paste("blas", extSoftVersion()[["BLAS"]]), paste("lavaan-free; medfit", as.character(packageVersion("medfit"))),
             paste("smoke", smoke), paste("start", format(Sys.time(), tz = "UTC", usetz = TRUE))),
           file.path(out, "env.txt"))
B <- if (smoke) 20L else 999L; ND <- 20000L; D <- if (smoke) 1L else 3L
TOTAL <- if (smoke) 300 else 7200; CELLCAP <- if (smoke) 60 else 900
gen <- function(n, miss, direct, seed) {
  set.seed(seed); a <- .4; b <- .4; cc <- if (direct) .2 else 0
  draw <- function(k) { x <- rnorm(k); m <- a * x + rnorm(k); y <- cc * x + b * m + rnorm(k); cbind(X = x, M = m, Y = y) }
  mask <- function(d) {
    k <- nrow(d)
    if (miss == "mar") { p <- plogis(log(.2 / .8) + .5 * d[, "X"]); d[runif(k) < p, "M"] <- NA; d[runif(k) < p, "Y"] <- NA }
    else { d[runif(k) < .2, "M"] <- NA; d[runif(k) < .2, "Y"] <- NA }
    d
  }
  if (miss != "empty") return(as.data.frame(mask(draw(n))))
  kept <- NULL; coll <- 0L
  while (NROW(kept) < n && coll < 10L * n) {
    d <- mask(draw(1L)); coll <- coll + 1L
    if (runif(1) < .1) d[] <- NA
    if (!all(is.na(d))) kept <- rbind(kept, d)
  }
  if (NROW(kept) < n) stop("collection cap reached")
  as.data.frame(kept)
}
cells <- expand.grid(n = c(200L, 500L), miss = c("mcar", "mar", "empty"), direct = c(TRUE, FALSE), stringsAsFactors = FALSE)
log <- list(); t0 <- Sys.time(); k <- 0L
timed <- function(expr, limit) {
  setTimeLimit(elapsed = max(limit, 1), transient = TRUE); on.exit(setTimeLimit())
  s <- proc.time()[["elapsed"]]
  r <- tryCatch({ force(expr); "ok" }, error = function(e) if (grepl("time limit", conditionMessage(e))) "timeout" else paste("error:", conditionMessage(e)))
  c(status = r, seconds = round(proc.time()[["elapsed"]] - s, 3))
}
for (i in seq_len(nrow(cells))) {
  cl <- cells[i, ]; cell_start <- Sys.time()
  for (d in seq_len(D)) for (meth in c("fit", "nonparametric", "parametric")) {
    left_total <- TOTAL - as.numeric(difftime(Sys.time(), t0, units = "secs"))
    left_cell <- CELLCAP - as.numeric(difftime(Sys.time(), cell_start, units = "secs"))
    k <- k + 1L
    row <- list(cell = i, n = cl$n, miss = cl$miss, direct = cl$direct, dataset = d, method = meth)
    if (left_total <= 1 || left_cell <= 1) { row$status <- if (left_total <= 1) "unattempted_total_cap" else "unattempted_cell_cap"; row$seconds <- NA }
    else {
      seed <- 9100000L + i * 100L + d
      dat <- tryCatch(gen(cl$n, cl$miss, cl$direct, seed), error = function(e) NULL)
      mod <- paste0("M ~ a*X\nY ~ b*M + ", if (cl$direct) "cp" else "0", "*X")
      lim <- min(left_total, left_cell)
      if (is.null(dat)) { row$status <- "generation_failed"; row$seconds <- NA }
      else {
        fit <- NULL
        if (meth == "fit") { r <- timed({ fit <- fit_sem(mod, dat, missing = "fiml", fixed_x = FALSE) }, lim) }
        else {
          fit <- tryCatch(fit_sem(mod, dat, missing = "fiml", fixed_x = FALSE), error = function(e) NULL)
          r <- if (is.null(fit)) c(status = "fit_failed", seconds = NA)
               else timed(bootstrap_mediation(source_fit = fit, effect = "nie", method = meth,
                                              n_boot = if (meth == "nonparametric") B else ND, seed = seed), lim)
        }
        row$status <- unname(r["status"]); row$seconds <- as.numeric(r["seconds"])
      }
    }
    log[[k]] <- as.data.frame(row)
    write.csv(do.call(rbind, log), file.path(out, if (smoke) "smoke-log.csv" else "pilot-log.csv"), row.names = FALSE)
    cat(sprintf("[%s] cell %d n=%d %s direct=%s d=%d %s -> %s %ss\n", format(Sys.time(), "%H:%M:%S"), i, cl$n, cl$miss, cl$direct, d, meth, row$status, row$seconds))
  }
}
print(aggregate(seconds ~ method + n, do.call(rbind, log), function(s) round(mean(s), 2)))
cat("elapsed total s:", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), "\n")
