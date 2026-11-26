# Run from the package root: Rscript scripts/test-gate-shards.R
source("scripts/gate-shards.R")
k <- 3L
p <- plan_shards(k)
all_rest <- rest_gates()
ran <- unlist(p$gates)
stopifnot(
  !length(union_problems(ran, all_rest)),            # partition: every rest gate in exactly one shard
  all(lengths(p$gates) > 0L),
  identical(plan_shards(k)$gates, p$gates),          # deterministic
  !"reliability" %in% ran
)
# shared-script gates stay together
sm <- gate_script_map()
for (sc in unique(sm[all_rest])) {
  g <- intersect(names(sm)[sm == sc], all_rest)
  stopifnot(length(unique(vapply(g, function(x) which(vapply(p$gates, function(s) x %in% s, TRUE)), 1L))) == 1L)
}
stopifnot(sm[["constrained"]] == sm[["stationarity"]])
# every gate in gates.csv has a weight row (a missing row is allowed at run time but must be noticed in review)
wt <- utils::read.csv("tests/sim/gate-seconds.csv", stringsAsFactors = FALSE)
everything <- rest_gates(include_local = TRUE)
stopifnot(!length(setdiff(everything, wt$gate)), !length(setdiff(wt$gate, everything)))
# balance: greedy longest-first keeps the spread of the shard loads within the heaviest hosted gate
stopifnot(max(p$load) - min(p$load) <= max(wt$seconds[wt$gate %in% all_rest]))
# local-only tier: excluded from the hosted partition and the union check, included with include_local / --local-only,
# and the tier never swallows the required reliability gate
lo <- gate_local_only()
stopifnot(length(lo) > 0L, !any(lo %in% all_rest), !any(lo %in% ran), !"reliability" %in% lo,
          all(lo %in% everything), setequal(c(all_rest, lo), everything))
pl <- plan_shards(k, include_local = TRUE)
stopifnot(!length(union_problems(unlist(pl$gates), everything)), all(lo %in% unlist(pl$gates)))
# a shard file set that ran a local-only gate fails the hosted union check (planted defect), and passes with --local-only
d2 <- tempfile(); dir.create(d2)
for (s in seq_len(k)) writeLines(paste(pl$gates[[s]], collapse = ","), file.path(d2, sprintf("shard-gates-%d.txt", s)))
stopifnot(suppressWarnings(system2("Rscript", c("scripts/gate-shards.R", "union-check", d2), stdout = FALSE)) == 1L,
          system2("Rscript", c("scripts/gate-shards.R", "union-check", d2, "--local-only"), stdout = FALSE) == 0L)
# planted defects: the union check must reject a gate missing from every shard, a duplicate, an unknown gate
stopifnot(
  length(union_problems(setdiff(ran, "fiml"), all_rest)) == 1L,
  grepl("fiml", union_problems(setdiff(ran, "fiml"), all_rest)),
  length(union_problems(c(ran, "mlr"), all_rest)) == 1L,
  length(union_problems(c(ran, "nope"), all_rest)) == 1L
)
# a new gate without a weight row still lands in a shard, and a monotone shard count changes nothing else
a <- assign_shards(c(all_rest, "brand-new"), stats::setNames(wt$seconds, wt$gate), sm, k)
stopifnot(!length(union_problems(unlist(a$gates), c(all_rest, "brand-new"))))
for (kk in 1:4) stopifnot(!length(union_problems(unlist(plan_shards(kk)$gates), all_rest)))
# the CLI union check: a planted shard file set that lacks a gate fails, the real one passes
d <- tempfile(); dir.create(d)
for (s in seq_len(k)) writeLines(paste(p$gates[[s]], collapse = ","), file.path(d, sprintf("shard-gates-%d.txt", s)))
ok <- system2("Rscript", c("scripts/gate-shards.R", "union-check", d), stdout = FALSE)
writeLines(paste(p$gates[[2]][-1], collapse = ","), file.path(d, "shard-gates-2.txt")) # shard 2 drops a gate
bad <- suppressWarnings(system2("Rscript", c("scripts/gate-shards.R", "union-check", d), stdout = FALSE))
stopifnot(ok == 0L, bad == 1L)
cat("gate shards: PASS\n")
