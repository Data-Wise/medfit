# ---- fixtures ------------------------------------------------------------------------------------------------------

gk_masks <- list(
  X = c(FALSE, TRUE, TRUE), M = c(TRUE, FALSE, TRUE), Y = c(TRUE, TRUE, FALSE),
  XM = c(FALSE, FALSE, TRUE), XY = c(FALSE, TRUE, FALSE), MY = c(TRUE, FALSE, FALSE),
  none = c(TRUE, TRUE, TRUE)
)
# kinds: complete, one-variable gaps, pairs, all seven non-empty patterns with empty rows, minimal (two rows per
# pattern) and a column observed exactly twice.
gk_data <- function(kind) {
  set.seed(4242L)
  n <- switch(kind, minimal = 14L, 61L)
  x <- .8 + stats::rnorm(n, sd = 1.1)
  m <- -.4 + .5 * x + stats::rnorm(n, sd = .8)
  y <- .7 + .6 * m + .25 * x + stats::rnorm(n, sd = .9)
  d <- cbind(X = x, M = m, Y = y)
  hide <- function(rows, cols) d[rows, cols] <<- NA_real_
  i <- seq_len(n)
  switch(kind,
    complete = NULL,
    x_gaps = hide(i %% 4L == 0L, "X"),
    m_gaps = hide(i %% 3L == 0L, "M"),
    y_gaps = hide(i %% 5L == 0L, "Y"),
    pairs = {
      hide(i %% 6L == 0L, c("X", "M"))
      hide(i %% 6L == 1L, c("M", "Y"))
      hide(i %% 6L == 2L, c("X", "Y"))
    },
    all7 = {
      nm <- c("X", "M", "Y")
      keep <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE), Y = c(FALSE, TRUE)))
      keep <- keep[-1L, , drop = FALSE]
      for (r in i) d[r, !keep[(r - 1L) %% 7L + 1L, ]] <- NA_real_
      d[c(10L, 33L), nm] <- NA_real_
    },
    minimal = {
      keep <- as.matrix(expand.grid(X = c(FALSE, TRUE), M = c(FALSE, TRUE), Y = c(FALSE, TRUE)))
      keep <- keep[-1L, , drop = FALSE]
      for (r in i) d[r, !keep[(r - 1L) %% 7L + 1L, ]] <- NA_real_
    },
    ytwo = {
      d[-c(3L, 40L), "Y"] <- NA_real_
      d[c(1L, 2L, 5L), "X"] <- NA_real_
    },
    stop("unknown kind")
  )
  d
}
gk_kinds <- c("complete", "x_gaps", "m_gaps", "y_gaps", "pairs", "all7", "minimal", "ytwo")
gk_theta <- function(direct, seed) {
  set.seed(seed)
  base <- c(a = .3, b = .4, cp = .2, vx = 1.1, vm = .8, vy = 1.2, ix = .1, im = -.1, iy = .05)
  out <- base + stats::runif(9, -.12, .12)
  names(out) <- names(base)
  if (!direct) out <- out[names(out) != "cp"]
  out
}
