# Few-clusters design study, task T6: write the P1 cell list (decision M7, 2026-11-17: P1 runs where P0's
# inadmissible rate in the T5 pilot exceeds 10%) from the committed T5 cell table.
#   Rscript tests/sim/twolevel-few-clusters-t6-p1.R
# Reads planning/studies/few-clusters/T5-cells.csv, writes planning/studies/few-clusters/T6-p1-cells.csv; the
# harness test checks that the rule reproduces the committed list (49 cells).

source("tests/sim/twolevel-few-clusters-lib.R")
source("tests/sim/twolevel-few-clusters-t6-lib.R")
dir <- "planning/studies/few-clusters"
cells <- utils::read.csv(file.path(dir, "T5-cells.csv"), stringsAsFactors = FALSE)
p1 <- fc_t6_p1_cells(cells, cutoff = .10)
utils::write.csv(p1, file.path(dir, "T6-p1-cells.csv"), row.names = FALSE)
cat(sprintf("%d of %d cells exceed the 10%% inadmissible rate -> %s\n", nrow(p1), nrow(cells),
            file.path(dir, "T6-p1-cells.csv")))
