# Normalize `m_star` for the joint branch

A scalar applies to every interacting mediator; a named vector must name
exactly the interacting mediators. The result is always named.

## Usage

``` r
.normalize_joint_m_star(m_star, interactions, supplied)
```

## Arguments

- m_star:

  As supplied.

- interactions:

  Mediators carrying a product, in mediator order.

- supplied:

  Logical: was `m_star` given at the call site?
