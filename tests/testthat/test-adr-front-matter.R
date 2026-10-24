# Decision log (QC plan Q-3 and Q-4, planning/specs/BRAINSTORM-optimizer-quality-control-2026-10-23.md): each ADR in
# planning/specs/ADR-*.md opens with YAML front matter holding a `decisions:` list, one entry per decision (`id`,
# `title`, `status`, `date`, optional `supersedes`). The QC article renders the log from these lists, so a malformed or
# duplicated entry must fail here. The ADR stays the single source; ids are unique across ADRs.

skip_if_not_installed("yaml")
specs <- test_path("..", "..", "planning", "specs")
adrs <- list.files(specs, pattern = "^ADR-.*\\.md$", full.names = TRUE)

adr_statuses <- c("accepted", "approved", "decided", "proposed", "conditional", "superseded")
adr_required <- c("id", "title", "status", "date")

# the decisions of one ADR text, or an error string naming what is wrong with its front matter
adr_decisions <- function(lines) {
  if (!length(lines) || !identical(lines[1L], "---")) return("no YAML front matter at the top")
  end <- which(lines[-1L] == "---")[1L] + 1L
  if (is.na(end)) return("front matter is not closed")
  meta <- tryCatch(yaml::yaml.load(paste(lines[2:(end - 1L)], collapse = "\n")), error = function(e) NULL)
  if (is.null(meta) || is.null(meta$decisions) || !length(meta$decisions)) return("no `decisions:` list")
  meta$decisions
}
adr_problems <- function(dec, adr_ids = character()) {
  if (is.character(dec)) return(dec)
  bad <- character()
  ids <- character()
  for (d in dec) {
    miss <- setdiff(adr_required, names(d))
    id <- if (is.null(d$id)) "?" else as.character(d$id)
    if (length(miss)) bad <- c(bad, sprintf("%s lacks %s", id, paste(miss, collapse = ", ")))
    if (!is.null(d$status) && !as.character(d$status) %in% adr_statuses) {
      bad <- c(bad, sprintf("%s has the unknown status '%s'", id, d$status))
    }
    if (!is.null(d$date) && !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", as.character(d$date))) {
      bad <- c(bad, sprintf("%s has the date '%s' (use YYYY-MM-DD)", id, d$date))
    }
    ids <- c(ids, id)
  }
  dup <- unique(c(ids[duplicated(ids)], intersect(ids, adr_ids)))
  if (length(dup)) bad <- c(bad, paste("duplicate id:", paste(dup, collapse = ", ")))
  sup <- unlist(lapply(dec, function(d) d$supersedes))
  unknown <- setdiff(sup, c(ids, adr_ids))
  if (length(unknown)) bad <- c(bad, paste("supersedes an unknown id:", paste(unknown, collapse = ", ")))
  bad
}

test_that("every ADR has well-formed front matter, and decision ids are unique across ADRs", {
  skip_if_not(dir.exists(specs), "planning/ is not shipped with the installed tests")
  skip_if(length(adrs) == 0L, "no ADR in this tree")
  seen <- character()
  for (f in adrs) {
    dec <- adr_decisions(readLines(f, warn = FALSE))
    expect_length(adr_problems(dec, seen), 0L)
    if (!is.character(dec)) seen <- c(seen, vapply(dec, function(d) as.character(d$id), ""))
  }
})

test_that("planted defects: each way front matter can be wrong is reported", {
  good <- c("---", "decisions:", "  - {id: X-1, title: t, status: decided, date: 2026-10-23}", "---", "# ADR")
  expect_length(adr_problems(adr_decisions(good)), 0L)
  expect_match(adr_problems(adr_decisions(c("# ADR")))[1L], "no YAML front matter")
  expect_match(adr_problems(adr_decisions(c("---", "decisions: []", "---")))[1L], "no `decisions:` list")
  no_title <- c("---", "decisions:", "  - {id: X-1}", "---")
  expect_match(adr_problems(adr_decisions(no_title))[1L], "lacks title, status, date")
  bad_status <- sub("decided", "maybe", good)
  expect_match(adr_problems(adr_decisions(bad_status))[1L], "unknown status 'maybe'")
  bad_date <- sub("2026-10-23", "Oct 23", good)
  expect_match(adr_problems(adr_decisions(bad_date))[1L], "YYYY-MM-DD")
  dup <- c("---", "decisions:", "  - {id: X-1, title: a, status: decided, date: 2026-10-23}",
           "  - {id: X-1, title: b, status: decided, date: 2026-10-23}", "---")
  expect_match(adr_problems(adr_decisions(dup))[1L], "duplicate id: X-1")
  expect_match(adr_problems(adr_decisions(good), adr_ids = "X-1")[1L], "duplicate id: X-1")
  sup <- sub("date: 2026-10-23}", "date: 2026-10-23, supersedes: Y-9}", good)
  expect_match(adr_problems(adr_decisions(sup))[1L], "supersedes an unknown id: Y-9")
})
