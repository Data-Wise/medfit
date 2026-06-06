# Locate a treatment-by-mediator interaction term in an outcome model

Returns the coefficient name of the `X:M` product term in `model_y`,
trying both orderings (`treatment:mediator` and `mediator:treatment`,
since the formula order determines which
[`lm()`](https://rdrr.io/r/stats/lm.html)/[`glm()`](https://rdrr.io/r/stats/glm.html)
emits). Returns `NA_character_` when no interaction term is present.

## Usage

``` r
.find_interaction_term(model_y, treatment, mediator)
```
