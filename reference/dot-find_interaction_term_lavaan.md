# Locate a treatment-by-mediator interaction term in a lavaan outcome equation

In lavaan the interaction enters as a product predictor of the outcome
(a data column, e.g. `XM`). This returns its coefficient name,
preferring an explicit `interaction` argument and otherwise trying
`treatment:mediator` / `mediator:treatment`. Returns `NA_character_`
when none is found.

## Usage

``` r
.find_interaction_term_lavaan(
  object,
  treatment,
  mediator,
  interaction = NULL,
  standardized = FALSE
)
```
