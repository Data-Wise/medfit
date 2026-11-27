# medfit 0.21.2 release checklist (2026-11-26)

Why: CRAN's pretest of the withdrawn 0.21.1.9000 upload also blocks 0.21.1 (Windows check time 29 min, Rd note), and CRAN
has an open issue on 0.3.2 (`ERROR:from:upgrade:S7`, deadline 2026-12-11). 0.21.2 is the version to upload.

Authorization: the standing goal covered 0.21.1. The tag, the GitHub release and the CRAN upload for 0.21.2 wait for
the user's go-ahead.

| # | Step | State |
|---|---|---|
| R1 | CRAN-fix PR merged into dev (Rd `\usage`, check time, S7) | done (#564) |
| R2 | Prep PR (this branch): version, NEWS, cran-comments, README, articles, status | done (#563) |
| R3 | Release PR dev to main, required checks green | done (#566, 17 checks green; fixes #567 and #568 first) |
| R4 | `scripts/check-local-full.sh` receipt for the release commit | done (receipt in #565) |
| R5 | CRAN-mode check of the tarball built from the tag (`git archive`), timings into cran-comments | done (1 NOTE, tests 87 s) |
| R6 | Tag, GitHub release, tagged-install smoke, back-merge to 0.21.2.9000 | done (v0.21.2 at 28e809c6) |
| R7 | CRAN upload from the detached tag; read `Version: 0.21.2` in the confirmation email | user |
