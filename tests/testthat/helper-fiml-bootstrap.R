# Frozen bounded implementation/QA sources; see planning/fixtures/FI-B-implementation-freeze-2026-11-01.md.
fb_fixture <- function(kind, direct) {
  set.seed(271L)
  n <- 300L
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + (if (direct) .25 else 0) * x + stats::rnorm(n, sd = .9)
  d <- data.frame(X = x, M = m, Y = y)
  if (kind == "mar") {
    d[stats::runif(n) < stats::plogis(-1.3 + .7 * x), "M"] <- NA_real_
    d[stats::runif(n) < stats::plogis(-1.1 - .6 * x), "Y"] <- NA_real_
  } else if (kind == "mcar") {
    set.seed(613L)
    masks <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE), Y = c(FALSE, TRUE)))[-1L, ]
    d[!masks[sample.int(7L, n, replace = TRUE), ]] <- NA_real_
    d <- rbind(d, data.frame(X = rep(NA_real_, 3L), M = NA_real_, Y = NA_real_))
  } else if (kind != "complete") {
    stop("unknown fixture")
  }
  d
}

fb_model <- function(direct) paste0("M ~ a*X\nY ~ b*M + ", if (direct) "cp" else "0", "*X")
