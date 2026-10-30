# Study-only fixture; the acceptance harness supplies its independent generator.
prototype_near_singular <- function(generate, direct) {
  dat <- generate(271L, "complete", direct)
  cp <- if (direct) .25 else 0
  noise <- dat[, 3] - .7 - .6 * dat[, 2] - cp * dat[, 1]
  dat[, 3] <- .7 + .6 * dat[, 2] + cp * dat[, 1] + (.03 / .9) * noise
  dat[is.na(generate(271L, "nonmonotone_mcar", direct))] <- NA
  dat
}
