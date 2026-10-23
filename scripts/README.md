# Website checks

After a local pkgdown build, run `Rscript scripts/fix-pkgdown-404.R docs`.
The Pages workflow runs this automatically before deployment. It removes the
invalid `/NA` source attribute that pkgdown 2.2.1 adds to inline MathJax
configuration on the 404 page; other script URLs are preserved.

Run `Rscript scripts/test-fix-pkgdown-404.R` to check the repair independently.
The repair is idempotent and does nothing when pkgdown produces a correct page.
