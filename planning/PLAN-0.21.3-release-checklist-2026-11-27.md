# medfit 0.21.3 release checklist (2026-11-27)

Why: CRAN's pretest of 0.21.2 (uploaded 2026-11-27, archived as failing) reported one new issue: Windows overall check
time 11 min against the 10-minute limit (tests 452 s, about 5 times the macOS time of 87 s). Debian passed with only the
version-jump NOTE. The open S7 issue on 0.3.2 (deadline 2026-12-11) is only closed by an accepted release, so 0.21.3
goes to CRAN. Target: tests at most about 250 s on Windows, so the whole check is under 8 minutes.

Authorization: the user said "Yes, start 0.21.3" on 2026-11-27. The tag, GitHub release and CRAN upload wait for the
user's go-ahead, as for 0.21.2.

| # | Step | State |
|---|---|---|
| R1 | 33 more test files skip on CRAN (CRAN-mode tests 105 s to 53 s locally) | done on this branch |
| R2 | Version, NEWS, README, articles, status for 0.21.3 | done on this branch |
| R3 | `scripts/check-local-full.sh` receipt for the release commit | pending |
| R4 | CRAN-mode check of the tarball built from the release tree; real timings and counts into cran-comments BEFORE the tag | pending |
| R5 | Prep PR to dev, then release PR dev to main (land all CI fixes on dev first) | pending |
| R6 | Tag, GitHub release, tagged-install smoke, back-merge to 0.21.3.9000 | needs go-ahead |
| R7 | User: win-builder (R-devel) on the tarball, then CRAN upload from the detached tag; read `Version: 0.21.3` in the email | user |
