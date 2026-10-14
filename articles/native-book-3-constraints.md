# Native engine book, chapter 3: constrained estimation

Chapters
[1](https://data-wise.github.io/medfit/articles/native-book-1-mean-structure.md)
and
[2](https://data-wise.github.io/medfit/articles/native-book-2-scale.md)
minimized the discrepancy over all parameters. This chapter adds
constraints such as `a + b == 1.2` or `cp == a*b` and follows one fit
through every stage the engine runs: turning a constraint into a row,
handing the rows to the solver, judging the solution with the acceptance
gate, polishing it, and handling rows that repeat each other. The engine
is experimental.

|  |  |
|----|----|
| **You need** | Chapters 1 and 2; calculus of several variables (gradient, Hessian, Lagrange multipliers) |
| **You get** | the constraint rows the engine builds, a trace of the solver, the three checks of the acceptance gate with a failing example of each, the Newton polish derived and reproduced by hand, and the redundant-row rules shown on real fits |
| **Time** | about 50 minutes |

``` r
library(medfit)
```


    Attaching package: 'medfit'

    The following object is masked from 'package:stats':

        decompose

``` r
rd <- function(x, d = 4) round(x, d)
sci <- function(x) formatC(x, format = "e", digits = 1)
d <- mediation_demo
model <- "
  mediator1 ~ a * treatment
  outcome ~ b * mediator1 + cp * treatment
"

# Rebuild what fit_sem() builds before it optimizes: the parsed model, the RAM
# specification, the sample object and the constraint rows.
build <- function(text, data = d) {
  parsed <- medfit:::.sem_parse(text)
  tab <- medfit:::.sem_complete(parsed$parameters, NULL)
  conv <- medfit:::.sem_to_ram(tab)
  ram <- conv$ram
  smp <- medfit:::.sem_sample(data[, ram$obs], ram)
  list(ram = ram, smp = smp, cons = medfit:::.sem_constraint_rows(parsed$constraints, ram))
}
```

We use the same three-variable model throughout (no means, so the
parameters are three paths and three variances). The unconstrained fit
is saturated, with \\\text{df} = 0\\. Every constraint below therefore
costs one degree of freedom per independent equality.

## 1. From a constraint line to a row

A constraint line has two sides, a comparison and labels of free
parameters. The engine turns each line into the vector \\c(\theta) =
\text{lhs} - \text{rhs}\\ and a sense: an equality \\c(\theta) = 0\\ or
an inequality, always stored in the form \\c(\theta) \le 0\\ (a `>`
constraint is negated).

### Linear constraints

If \\c\\ is linear in the parameters, \\c(\theta) = a^\top\theta + b\\,
so two kinds of evaluation recover its pieces: \\b = c(0)\\ and, for
each parameter \\k\\, \\a_k = c(e_k) - c(0)\\ with \\e_k\\ the \\k\\th
unit vector. The engine does exactly this with its expression evaluator,
then divides \\a\\ and \\b\\ by the length of \\a\\. After that, \\a\\
has unit length, so the value of the row at \\\theta\\ is the signed
distance from \\\theta\\ to the constraint’s hyperplane, and the
tolerances that act on the rows themselves (the rank of the equality
rows, and the test for implied inequalities in Section 5) mean the same
thing for every constraint, however it was written. (The acceptance gate
of Section 3 measures the distance in natural units instead, rescaling
each row again.)

``` r
lin <- build(paste0(model, "a + b == 1.2\ncp < a\n"))
lin$ram$par_names
```

    [1] "a"                    "b"                    "cp"
    [4] "mediator1~~mediator1" "outcome~~outcome"     "treatment~~treatment"

``` r
lin$cons$eq
```

    $A
              [,1]      [,2] [,3] [,4] [,5] [,6]
    [1,] 0.7071068 0.7071068    0    0    0    0

    $b
    [1] -0.8485281

    $text
    [1] "a + b == 1.2"

``` r
lin$cons$ineq
```

    $A
               [,1] [,2]      [,3] [,4] [,5] [,6]
    [1,] -0.7071068    0 0.7071068    0    0    0

    $b
    [1] 0

    $text
    [1] "cp < a"

Check the first row by hand. The labels `a` and `b` are parameters here,
so write the row’s pieces out in words. For `a + b == 1.2`, \\c(\theta)
= \theta_a + \theta_b - 1.2\\: the row vector has 1 in the columns of
`a` and `b` and 0 elsewhere, and the constant is \\-1.2\\. The row
vector’s length is \\\sqrt 2\\ = 1.4142, so the normalized row is 0.7071
in the columns of `a` and `b` with constant -0.8485, which is what the
table shows. The second line, `cp < a`, is \\c(\theta) = \theta\_{cp} -
\theta_a \le 0\\: it has \\-1\\ at `a` and \\+1\\ at `cp`, divided by
\\\sqrt 2\\.

An inequality line with a single label and a number (`cp < 0.3`) is not
a row: the parser stores it as a bound on the parameter, which the
solver handles separately. (An equality such as `a == 1` stays a row.)
The rows are empty and the bound is set:

``` r
bnd_text <- paste0(model, "cp < 0.3\n")
bnd <- build(bnd_text)
bnd_conv <- medfit:::.sem_to_ram(medfit:::.sem_complete(medfit:::.sem_parse(bnd_text)$parameters, NULL))
c(constraint_lines = nrow(medfit:::.sem_parse(bnd_text)$constraints), upper_bound_of_cp = bnd_conv$upper[["cp"]])
```

     constraint_lines upper_bound_of_cp
                  0.0               0.3 

### Nonlinear constraints

`cp == a*b` is not linear. The engine keeps \\c(\theta) = cp - ab\\ as a
function (a closure over a checked expression tree) and evaluates its
gradient by central differences at every point, with step
\\\epsilon^{1/3}\max(\|\theta_k\|, u_k)\\, where \\\epsilon\\ is the
machine precision and \\u_k\\ the parameter’s natural unit (Section 2).
The analytic gradient is \\(-b, -a, 1)\\ for \\(a, b, cp)\\, which gives
something to check:

``` r
txt <- paste0(model, "cp == a*b\n")
nlb <- build(txt)
fit <- fit_sem(txt, d)
theta <- fit@theta
unit <- medfit:::.sem_step_floor(nlb$ram, nlb$smp)
nl <- nlb$cons$nl
cat("row text:", nl$text, "\n")
```

    row text: cp == a*b 

``` r
rbind(
  central_difference = nl$jac(theta, unit)[1, 1:3],
  analytic = c(-theta[["b"]], -theta[["a"]], 1)
) |>
  `colnames<-`(c("a", "b", "cp")) |>
  rd(6)
```

                               a         b cp
    central_difference -0.683163 -0.338117  1
    analytic           -0.683163 -0.338117  1

``` r
c(value_at_solution = nl$value(theta))
```

    value_at_solution
        -2.775558e-17 

The central difference reproduces the analytic gradient to six decimals,
and the constraint holds at the solution (the value is zero to
rounding).

A product that is set to zero (`a*b == 0`) is a special case. The set
where it holds is two lines, \\a = 0\\ or \\b = 0\\, that cross at \\a =
b = 0\\. There the gradient \\(b, a)\\ is zero and the constraint
qualification of Section 5 fails. Away from the crossing a local solver
follows the branch nearest its start and can stop on the worse one, a
local optimum. The engine therefore fits one linear model per factor
(`a == 0`, `b == 0`), each from the default start, and keeps the one
with the smaller discrepancy, a rule Chapter 5 puts to use. The two
branches here give two different minima:

``` r
zp <- fit_sem(paste0(model, "a*b == 0\n"), d)
branch_f <- c(`a == 0` = fit_sem(paste0(model, "a == 0\n"), d)@f,
              `b == 0` = fit_sem(paste0(model, "b == 0\n"), d)@f)
branch_f
```

        a == 0     b == 0
    0.04389351 0.40513506 

``` r
data.frame(chosen_branch = zp@internals$branch, discrepancy = zp@f)
```

      chosen_branch discrepancy
    1        a == 0  0.04389351

### Counting what a constraint removes

An equality removes one free parameter when its gradient is independent
of the others’. The number removed is the **rank** of the equality
gradients: stack them in a matrix and count its independent rows. The
degrees of freedom are \\\text{moments} - (q - \text{rank})\\:

``` r
fit_lin <- fit_sem(paste0(model, "a + b == 1.2\n"), d)
data.frame(
  model = c("no constraint", "a + b == 1.2", "cp == a*b"),
  q = c(length(fit_sem(model, d)@theta), length(fit_lin@theta), length(fit@theta)),
  rank_removed = c(0, fit_lin@internals$eq_rank, fit@internals$eq_rank),
  df = c(fit_sem(model, d)@df, fit_lin@df, fit@df)
)
```

              model q rank_removed df
    1 no constraint 6            0  0
    2  a + b == 1.2 6            1  1
    3     cp == a*b 6            1  1

## 2. The solver

The engine minimizes \\F\_{ML}(\theta)\\ subject to the rows with SLSQP,
the sequential least-squares quadratic programming algorithm of Kraft,
as implemented in the NLopt library and called through the `nloptr`
package. At each iterate SLSQP forms a quadratic model of the objective
(the gradient plus a quasi-Newton approximation of the curvature of the
Lagrangian) and linearizes the constraints. It then solves that small
quadratic program for a step and chooses a step length by a line search
on a merit function that penalizes constraint violation.

Two engine choices matter to what follows.

**Natural units.** SLSQP works on \\x = \theta / u\\ with \\u_k\\ the
parameter’s natural unit (`.sem_step_floor()`): the standard deviation
of the target over that of the source for a path, the product of the two
standard deviations for a (co)variance. The objective, gradient and
constraint rows are mapped into \\x\\ (a linear row \\a^\top\theta + b\\
becomes the row \\(a \odot u)^\top x + b\\), and the solution is mapped
back. A step of size 1 then means about the same in every parameter,
whatever the units of the data.

``` r
rd(stats::setNames(unit, nlb$ram$par_names), 3)
```

                       a                    b                   cp
                   2.200                1.221                2.686
    mediator1~~mediator1     outcome~~outcome treatment~~treatment
                   1.210                1.804                0.250 

**Defaults.** The first start is moment based (`.sem_default_start()`:
paths at 10% of the natural unit, variances at half the variable’s
variance, covariances at 0). Tolerances are `xtol_rel = 1e-10` and
`ftol_rel = 1e-12`.

A trace shows the iterations. We call the solver directly with a wrapper
that records each evaluation of the objective together with the
constraint violation, from the default start:

``` r
ram <- nlb$ram
smp <- nlb$smp
cons <- nlb$cons
lb <- rep(-Inf, ram$q)
ub <- rep(Inf, ram$q)
start <- medfit:::.sem_default_start(ram, smp)
obj <- medfit:::.sem_objective(ram, smp)
opts <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = 10000L)
trace_env <- new.env()
trace_env$rows <- list()
f_traced <- function(x) {
  value <- obj$f(x * unit)
  trace_env$rows[[length(trace_env$rows) + 1L]] <- c(objective = value, violation = abs(cons$nl$value(x * unit)))
  value
}
run <- medfit:::.sem_nlopt(
  start / unit, f_traced, function(x) obj$g(x * unit) * unit, lb / unit, ub / unit, opts,
  constraints = medfit:::.sem_nlopt_constraints(cons, unit)
)
tr <- do.call(rbind, trace_env$rows)
solution <- run$solution * unit
cat("status", run$status, "after", run$iterations, "iterations and", nrow(tr), "evaluations\n")
```

    status 3 after 22 iterations and 24 evaluations

``` r
signif(tr[c(1:6, nrow(tr) - 3:0), ], 3)
```

          objective violation
     [1,]    1.0800  2.42e-01
     [2,]    1.0800  2.42e-01
     [3,]    1.0800  2.42e-01
     [4,]    2.1400  2.10e+00
     [5,]    0.4240  3.19e-01
     [6,]    0.4240  3.19e-01
     [7,]    0.0105  1.19e-09
     [8,]    0.0105  2.99e-12
     [9,]    0.0105  6.25e-15
    [10,]    0.0105  2.78e-17

Rows that repeat one another are repeated evaluations at the same point
(the `nloptr` wrapper evaluates the start once to check the objective’s
return type, and the solver evaluates some points twice). The trace
starts at a point that violates the constraint (`violation` is \\\|cp -
ab\|\\), the violation falls by many orders of magnitude over the last
evaluations, and the objective settles at 0.0104708. The run ended with
NLopt status 3; the engine treats the codes 1 (generic success), 3 (the
objective stopped changing, `ftol_rel`) and 4 (the parameters stopped
moving, `xtol_rel`) as successes.

**Several starts.** A nonlinear constraint can have several local optima
(`a*b > 0.1` is feasible on two separate regions), so for such a model
the engine runs every start (the default one and up to `n_starts - 1`
perturbed ones, drawn under a fixed seed derived from the model) and
keeps the accepted solution with the lowest discrepancy, warning if the
accepted ones disagree. The attempts of this fit, from the engine’s own
optimizer:

``` r
o <- medfit:::.sem_optimize(ram, smp, start, constraints = cons)
attempts <- do.call(rbind, lapply(seq_along(o$attempts), function(i) {
  a <- o$attempts[[i]]
  data.frame(start = i, status = a$status, accepted = a$accepted, discrepancy = a$f,
             decrement = signif(a$decrement, 2))
}))
attempts
```

      start status accepted discrepancy decrement
    1     1      3     TRUE  0.01047077   9.1e-16
    2     2      3     TRUE  0.01047077   6.8e-14
    3     3      3     TRUE  0.01047077   5.7e-15
    4     4      3     TRUE  0.01047077   1.0e-13
    5     5      3     TRUE  0.01047077   4.3e-15

All 5 starts are accepted and reach the same discrepancy (the largest
spread is 8.9e-16), so no warning is raised.

## 3. The acceptance gate

A solver can stop for reasons that have nothing to do with having found
the optimum. The engine therefore accepts a solution only if it passes
three checks, in this order (besides guards against a non-finite
Hessian, an implied covariance that is not positive definite, and a
nearly singular reduced Hessian):

1.  the solver status is a success code (1, 3 or 4);
2.  every constraint holds to \\10^{-6}\\ in natural units;
3.  the **Newton decrement** on the active-constraint null space is at
    most \\10^{-3}\\, with a positive definite reduced Hessian.

Check 3 needs a derivation. We build it in four steps.

**Step 1: the stationarity condition.** At a constrained minimum with
active rows \\M\\ (the Jacobian of the active constraints, one row
each), the gradient \\g\\ of the objective is a combination of the
constraint gradients: \\g + M^\top\lambda = 0\\, the Lagrange condition,
with \\\lambda\\ the **multipliers**. Equivalently, \\g\\ has no
component along any direction \\p\\ that keeps the constraints, \\M p =
0\\.

**Step 2: the null space.** Let \\Z\\ be a matrix whose orthonormal
columns span the null space of \\M\\: every feasible direction is \\p =
Z w\\. The **reduced gradient** is \\g_r = Z^\top g\\, which is zero at
a constrained stationary point.

**Step 3: the curvature along the constraints.** For a linear constraint
the second derivative of the objective along \\Z\\ is \\H_r = Z^\top H
Z\\ with \\H\\ the Hessian of the objective. For a curved constraint the
constraint itself bends, and the right curvature is that of the
**Lagrangian**, \\H_L = H + \sum_i \lambda_i \nabla^2 c_i\\ over the
active nonlinear rows, so \\H_r = Z^\top H_L Z\\. (Reason: along a curve
\\\theta(t)\\ that stays on the constraint, the second derivative of the
objective is \\\dot\theta^\top H \dot\theta + g^\top \ddot\theta\\, and
the Lagrange condition \\g = -M^\top\lambda\\ turns the second term into
\\-\lambda^\top M \ddot\theta\\, which the curvature of the constraint,
\\\ddot c = 0 = M\ddot\theta + \dot\theta^\top \nabla^2 c\\\dot\theta\\,
converts to \\+\lambda\\\dot\theta^\top\nabla^2 c\\\dot\theta\\.)

**Step 4: the Newton decrement.** A second-order model of the objective
along the null space is \\q(w) = g_r^\top w + \tfrac12 w^\top H_r w\\.
If \\H_r\\ is positive definite its minimum is at \\w^\star = -H_r^{-1}
g_r\\ and the predicted decrease in the objective is \\\tfrac12 g_r^\top
H_r^{-1} g_r\\. The **Newton decrement** is

\\ \lambda_N = \sqrt{g_r^\top H_r^{-1} g_r} , \\

the size of the remaining gradient measured in the units of the
curvature. It does not depend on the units of the parameters. Rescale
them, \\\theta = D\xi\\ with \\D\\ diagonal. Then the gradient becomes
\\D g\\, the Hessian \\D H D\\ and the constraint rows \\M D\\ (chain
rule), so the feasible directions become \\D^{-1}\\ times the old ones.
The quadratic form \\g^\top Z (Z^\top H Z)^{-1} Z^\top g\\ is the same
for every basis \\Z\\ of one subspace (another basis is \\Z R\\ with
\\R\\ invertible, and the \\R\\ factors cancel), and substituting \\D
g\\, \\D H D\\ and the basis \\D^{-1} Z\\ cancels every \\D\\: for
example, without constraints \\(D g)^\top (D H D)^{-1} (D g) = g^\top
H^{-1} g\\. So one threshold, \\10^{-3}\\, works whatever the units of
the data.

We compute each piece for our fit. The helper `.sem_active_set()`
returns the active rows in natural units, the constraint distance, and
the null-space basis \\Z\\ (from a singular value decomposition of the
normalized active rows):

``` r
act <- medfit:::.sem_active_set(theta, ram, smp, lb, ub, cons)
gate <- medfit:::.sem_gate(theta, 3L, ram, smp, lb, ub, cons)
cat("active rows:", act$text[act$active_row], "\n")
```

    active rows: cp == a*b 

``` r
cat("constraint distance (natural units):", signif(act$dist, 3), "\n")
```

    constraint distance (natural units): 8.94e-18 

``` r
cat("null space basis Z:", nrow(act$z), "x", ncol(act$z), "(6 parameters, 1 active row)\n")
```

    null space basis Z: 6 x 5 (6 parameters, 1 active row)

``` r
x_grad <- medfit:::.sem_grad(theta, ram, smp) * act$u
x_hess <- medfit:::.sem_hess_f(theta, ram, smp) * outer(act$u, act$u)
lagrangian <- medfit:::.sem_lagrangian_hessian(x_hess, x_grad, act, cons, theta)
active_rows <- act$ax[act$active_row, , drop = FALSE]
multiplier <- qr.solve(t(active_rows), -x_grad)
cat("multiplier from g + M' lambda = 0:", rd(multiplier, 4), "\n")
```

    multiplier from g + M' lambda = 0: -0.0742 

``` r
reduced_gradient <- crossprod(act$z, x_grad)
cat("size of the reduced gradient:", signif(sqrt(sum(reduced_gradient^2)), 3), "\n")
```

    size of the reduced gradient: 1.04e-14 

``` r
rbind(objective_hessian_only = eigen(crossprod(act$z, x_hess %*% act$z))$values,
      with_lagrangian_term = eigen(crossprod(act$z, lagrangian %*% act$z))$values) |> rd(3)
```

                            [,1]  [,2]  [,3]  [,4] [,5]
    objective_hessian_only 3.305 2.396 2.092 1.076    1
    with_lagrangian_term   3.408 2.360 1.999 1.075    1

At the optimum the reduced gradient is zero (the Lagrange condition
holds with a nonzero multiplier, because the constraint is binding), so
the decrement is zero. The last table lists the eigenvalues of the
reduced Hessian built two ways. Both are positive, so this point passes
the second-order test either way, but the numbers differ: the Lagrangian
term \\\lambda\nabla^2 c\\ changes the curvature along the curved
constraint, and the engine uses the version with it. On a different
problem the two can disagree about the sign of an eigenvalue, and then
only the second is right (the objective’s Hessian alone can call a
saddle point of the constrained problem a minimum).

The gate’s own verdict combines all of this. Here it is, together with
three solutions that should be rejected, one for each check:

``` r
show <- function(g) data.frame(accepted = g$accepted, decrement = signif(g$decrement, 3), reason = g$reason)
# 1. a good solution
good <- medfit:::.sem_gate(theta, 3L, ram, smp, lb, ub, cons)
# 2. a feasible point that is not the optimum: move a, then put cp back on the curve cp = a * b
off <- theta
off["a"] <- off["a"] + 0.05
off["cp"] <- off["a"] * off["b"]
off_gate <- medfit:::.sem_gate(off, 3L, ram, smp, lb, ub, cons)
# 3. an infeasible point
broken <- theta
broken["cp"] <- broken["cp"] + 0.1
broken_gate <- medfit:::.sem_gate(broken, 3L, ram, smp, lb, ub, cons)
# 4. a good point with a failure status from the solver
status_gate <- medfit:::.sem_gate(theta, -4L, ram, smp, lb, ub, cons)
verdicts <- rbind(optimum = show(good), `feasible, not optimal` = show(off_gate), infeasible = show(broken_gate),
                  `bad solver status` = show(status_gate))
verdicts
```

                          accepted decrement
    optimum                   TRUE  5.69e-15
    feasible, not optimal    FALSE  3.96e-02
    infeasible               FALSE        NA
    bad solver status        FALSE        NA
                                                                                   reason
    optimum
    feasible, not optimal                             stationarity 3.96e-02 exceeds 1e-03
    infeasible            constraint 'cp == a*b' is violated by 3.22e-02 in natural units
    bad solver status                              nloptr status -4 is not a success code

(A fourth check is warn-only: the signs of the multipliers of active
inequalities and bounds are examined, and a wrong sign produces a
warning, except for an active bound, which rejects the solution.) Each
failing point is rejected for the right reason. The second one satisfies
the constraint exactly and is rejected only because its decrement is
large: that is the stationarity check doing its job.

Finally the scale-invariance claim. Multiply `outcome` by 1000. The
model keeps its form, because `cp == a*b` is preserved when \\b\\ and
\\cp\\ are both multiplied by 1000 (so \\cp' = 1000\\cp = a \cdot
1000\\b = a b'\\). Map the feasible but non-optimal point of the last
test to the new scale (\\b\\ and \\cp\\ times 1000, the residual
variance of `outcome` times \\10^6\\), build the new model on the
rescaled data, and compare the decrements:

``` r
d_big <- d
d_big$outcome <- d_big$outcome * 1000
big <- build(txt, d_big)
off_big <- off
off_big[c("b", "cp")] <- off_big[c("b", "cp")] * 1000
off_big["outcome~~outcome"] <- off_big["outcome~~outcome"] * 1000^2
gate_big <- medfit:::.sem_gate(off_big, 3L, big$ram, big$smp, lb, ub, big$cons)
c(original_data = off_gate$decrement, outcome_times_1000 = gate_big$decrement)
```

         original_data outcome_times_1000
            0.03958072         0.03958072 

The two decrements are the same number, although the parameters differ
by factors up to \\10^6\\: the gate works in natural units, which
rescale with the data, so its verdict does not depend on the units of
the data.

## 4. The Newton polish

SLSQP stops when the objective changes by less than `ftol_rel`, and
along a flat stretch of a curved constraint that can happen a little
before the true optimum. Our solver run did just that:

``` r
cat("distance of the SLSQP solution from the exact optimum:", signif(max(abs(solution - theta)), 3), "\n")
```

    distance of the SLSQP solution from the exact optimum: 8.1e-06 

``` r
gate_raw <- medfit:::.sem_gate(solution, run$status, ram, smp, lb, ub, cons)
c(accepted = gate_raw$accepted, decrement = signif(gate_raw$decrement, 3),
  violation = signif(abs(cons$nl$value(solution)), 3))
```

     accepted decrement violation
     1.00e+00  8.80e-06  1.19e-09 

The point passes the gate (its decrement is below \\10^{-3}\\) but is
8.1e-06 from the optimum in the largest coordinate. The engine then
takes Newton steps on the Karush-Kuhn-Tucker (KKT) system of the active
set. We derive the step.

**The KKT system.** Look for a point \\x + \delta\\ and multipliers
\\\nu\\ that satisfy the two conditions of a constrained stationary
point, linearized at the current \\x\\. Stationarity of the Lagrangian,
\\g + H_L\\\delta + M^\top\nu = 0\\ (the gradient of the Lagrangian
expanded to first order in \\\delta\\), and feasibility of the active
rows, \\c + M\delta = 0\\ (the constraint expanded to first order).
Stacked:

\\ \begin{pmatrix} H_L & M^\top \\ M & 0 \end{pmatrix} \begin{pmatrix}
\delta \\ \nu \end{pmatrix} = \begin{pmatrix} -g \\ -c \end{pmatrix} .
\\

This is Newton’s method for the equations \\\nabla_x L = 0\\, \\c = 0\\,
with one approximation: the multipliers \\\lambda\\ inside \\H_L\\ are
estimated at the current point by least squares from \\g + M^\top\lambda
= 0\\, as in Section 3, and \\\nu\\ is discarded after the step. Near
the solution that estimate converges to the true multipliers, so the
step does too. Solving the system gives a step that both reduces the
gradient and moves back toward the constraint. We code it, and iterate
from the SLSQP solution:

``` r
kkt_step <- function(th) {
  a <- medfit:::.sem_active_set(th, ram, smp, lb, ub, cons)
  g <- medfit:::.sem_grad(th, ram, smp) * a$u
  h <- medfit:::.sem_hess_f(th, ram, smp) * outer(a$u, a$u)
  hl <- medfit:::.sem_lagrangian_hessian(h, g, a, cons, th)
  m <- a$ax[a$active_row, , drop = FALSE]
  cval <- a$cval[a$active_row]
  k <- nrow(m)
  kkt <- rbind(cbind(hl, t(m)), cbind(m, matrix(0, k, k)))
  sol <- solve(kkt, c(-g, -cval))
  th + sol[seq_len(ram$q)] * a$u
}
path <- list(solution)
for (i in 1:4) path[[i + 1L]] <- kkt_step(path[[i]])
newton <- data.frame(
  iteration = 0:4,
  constraint_violation = vapply(path, function(t) signif(abs(cons$nl$value(t)), 3), numeric(1)),
  decrement = vapply(path, function(t) {
    signif(medfit:::.sem_gate(t, 3L, ram, smp, lb, ub, cons)$decrement, 3)
  }, numeric(1)),
  distance_from_exact_optimum = vapply(path, function(t) signif(max(abs(t - theta)), 3), numeric(1))
)
newton
```

      iteration constraint_violation decrement distance_from_exact_optimum
    1         0             1.19e-09  8.80e-06                    8.10e-06
    2         1             3.28e-12  1.07e-10                    1.18e-10
    3         2             2.78e-17  1.14e-13                    1.05e-13
    4         3             2.78e-17  8.11e-15                    9.18e-14
    5         4             2.78e-17  9.06e-16                    1.02e-13

The distance from the optimum falls from 8.1e-06 to 1.2e-10 in one step
and to rounding error in the next, and the constraint violation and the
decrement fall with it: Newton’s method converges quadratically near a
solution, so the error is roughly squared at each step until it reaches
rounding error. The engine’s own polish, `.sem_polish()`, adds
safeguards (it takes at most 8 steps, keeps a step only while a merit
function falls, refuses to move more than \\10^{-2}\\ natural units, and
gives up if the active set changes or the KKT matrix is singular), and
its result is accepted only if the gate accepts it again and the
discrepancy does not rise by more than \\10^{-8}\\. It lands where our
bare iteration does:

``` r
polished <- medfit:::.sem_polish(solution, ram, smp, lb, ub, cons)
c(polish_vs_my_iteration = max(abs(polished - path[[5]])),
  polish_vs_engine_fit = max(abs(polished - theta)),
  discrepancy_before = medfit:::.sem_fml(solution, ram, smp),
  discrepancy_after = medfit:::.sem_fml(polished, ram, smp))
```

    polish_vs_my_iteration   polish_vs_engine_fit     discrepancy_before
              0.000000e+00           1.021960e-13           1.047077e-02
         discrepancy_after
              1.047077e-02 

## 5. Redundant rows

Constraint sets sometimes repeat themselves, and that is a problem for a
solver. SLSQP assumes the active constraint gradients are linearly
independent (the *linear independence constraint qualification*, LICQ);
when two active rows are parallel it can stop with an error although the
constraints are consistent. The engine therefore protects the solver in
two ways.

**Dependent equalities.** The rows handed to the solver are an
independent subset (chosen from a pivoted QR decomposition of the row
matrix, which finds which rows add rank), while the acceptance gate
still checks every row. So a harmless repeat is dropped, and a
contradiction is still caught:

``` r
dup <- build(paste0(model, "a == b\nb == a\n"))
cat("rows built:", nrow(dup$cons$eq$A), "; independent rows sent to the solver:",
    nrow(medfit:::.sem_independent_rows(dup$cons$eq)$A), "; rank:", medfit:::.sem_eq_rank(dup$cons$eq), "\n")
```

    rows built: 2 ; independent rows sent to the solver: 1 ; rank: 1 

``` r
fit_dup <- fit_sem(paste0(model, "a == b\nb == a\n"), d)
fit_one <- fit_sem(paste0(model, "a == b\n"), d)
c(df_duplicates = fit_dup@df, df_single = fit_one@df,
  largest_estimate_difference = max(abs(fit_dup@theta - fit_one@theta)))
```

                  df_duplicates                   df_single
                              1                           1
    largest_estimate_difference
                              0 

The duplicated pair counts as one constraint (rank 1, so the degrees of
freedom are the same as with one line) and the estimates are identical.
Contradictory lines, by contrast, are reported by the gate (the error
names the violated row):

``` r
contradiction <- tryCatch(fit_sem(paste0(model, "a == 1\na == 2\n"), d), error = function(e) conditionMessage(e))
contradiction
```

    [1] "no start converged (5 tried); best attempt: status 3, stationarity NA; constraint 'a == 2' is violated by 4.54e-01 in natural units"

**Implied inequalities.** An inequality whose gradient lies in the span
of the equality gradients has a constant value on the set where the
equalities hold. If that constant satisfies it, the inequality is either
active everywhere on that set or never active, and an everywhere-active
row is another LICQ failure. Such a row is detected when its gradient
lies within \\10^{-12}\\ of the span of the independent equalities (the
rows have unit length, so this is an angle), and it is dropped from the
solver’s rows. The gate still checks it. We build the case `a == b`
together with `a < b`, whose value on the equality set is exactly 0, and
the case `a + b == 0.8` with `a + b < 0.9`, whose value on the equality
set is \\-0.1\\ before normalization (never active):

``` r
drop_check <- function(text) {
  bb <- build(text)
  kept <- medfit:::.sem_drop_implied_ineq(bb$cons$ineq, medfit:::.sem_independent_rows(bb$cons$eq))
  c(inequality_rows_built = nrow(bb$cons$ineq$A), rows_sent_to_the_solver = nrow(kept$A))
}
dropped <- rbind(`a == b with a < b` = drop_check(paste0(model, "a == b\na < b\n")),
                 `a + b == 0.8 with a + b < 0.9` = drop_check(paste0(model, "a + b == 0.8\na + b < 0.9\n")))
dropped
```

                                  inequality_rows_built rows_sent_to_the_solver
    a == b with a < b                                 1                       0
    a + b == 0.8 with a + b < 0.9                     1                       0

``` r
fit_imp <- fit_sem(paste0(model, "a == b\na < b\n"), d)
c(discrepancy_with_inequality = fit_imp@f, discrepancy_without = fit_one@f,
  largest_estimate_difference = max(abs(fit_imp@theta - fit_one@theta)))
```

    discrepancy_with_inequality         discrepancy_without
                     0.01167511                  0.01167511
    largest_estimate_difference
                     0.00000000 

``` r
fit_imp@diagnostics$active_constraints
```

    [1] "a == b" "a < b" 

The fit with the redundant inequality gives the same result as the fit
without it, and `active_constraints` still lists both rows, so the gate
knew about it. A row the equalities *violate* is not dropped:
near-dependence does not prove the set is infeasible, so the solver is
left to try and the gate reports the failure:

``` r
violated <- tryCatch(fit_sem(paste0(model, "a + b == 0.8\na + b < 0.5\n"), d), error = function(e) conditionMessage(e))
violated
```

    [1] "no start converged (5 tried); best attempt: status 5, stationarity NA; nloptr status 5 is not a success code; constraint 'a + b < 0.5' is violated by 1.35e-01 in natural units"

## 6. The covariance of a constrained fit

The standard errors of Chapter 5 come from the information matrix. With
active constraints the estimates cannot move in the directions that
violate them, so the covariance must be zero in those directions. Near
\\\hat\theta\\ the feasible points are \\\theta = \hat\theta + Z w\\ (to
first order), with \\w\\ unconstrained. In \\w\\ the information is
\\Z^\top I Z\\ (chain rule, as in Chapter 2), so
\\\operatorname{Var}(\hat w) \approx (Z^\top I Z)^{-1}\\, and mapping
back through \\\theta = \hat\theta + Z w\\ replaces \\I^{-1}\\ with

\\ V = Z\\(Z^\top I\\ Z)^{-1} Z^\top , \\

with \\Z\\ the null-space basis in \\\theta\\ units (`z_theta` from
`.sem_active_set()`). Compute it by hand from the expected information
and compare with the covariance the engine reports for the same setting:

``` r
fit_exp <- fit_sem(txt, d, information = "expected")
info <- medfit:::.sem_info_expected(fit_exp@theta, ram, smp, NULL)
act_exp <- medfit:::.sem_active_set(fit_exp@theta, ram, smp, lb, ub, cons)
zt <- act_exp$z_theta
v_hand <- zt %*% solve(t(zt) %*% info %*% zt) %*% t(zt)
c(difference_from_engine = max(abs(v_hand - fit_exp@vcov)), largest_entry = max(abs(v_hand)))
```

    difference_from_engine          largest_entry
              8.673617e-19           8.211061e-03 

``` r
cat("rank of V:", qr(fit_exp@vcov, tol = 1e-10)$rank, "of", ram$q, "parameters\n")
```

    rank of V: 5 of 6 parameters

\\V\\ has rank 5 and not 6: with one binding equality the six estimates
have five degrees of freedom of variation.

## 7. Cross-checks

lavaan accepts `cp == a*b` in the model text. OpenMx takes it as an
algebra and a constraint. Both fit the same model, and we compare the
chi-square, the degrees of freedom, the estimates and the standard
errors, from the expected and from the observed information (the
engine’s and lavaan’s must be set to the same one):

``` r
lv <- lavaan::sem(txt, d, fixed.x = FALSE, information = "expected")
```

    Warning: lavaan->lav_model_test():
       test = "browne.residual.nt.model" could not be computed and is ignored:
       lavaan->lav_test_browne(): Browne's test is not available (yet) when
       nonlinear equality constraints are involved.

``` r
lv_obs <- lavaan::sem(txt, d, fixed.x = FALSE, information = "observed")
```

    Warning: lavaan->lav_model_test():
       test = "browne.residual.nt.model" could not be computed and is ignored:
       lavaan->lav_test_browne(): Browne's test is not available (yet) when
       nonlinear equality constraints are involved.

``` r
nm <- names(fit@theta)
fit_obs <- fit_sem(txt, d, information = "observed")
data.frame(
  quantity = c("chisq", "df"),
  medfit = c(fit@n_obs * fit@f, fit@df),
  lavaan = c(lavaan::fitMeasures(lv, "chisq"), lavaan::fitMeasures(lv, "df"))
)
```

          quantity   medfit   lavaan
    chisq    chisq 4.188307 4.188307
    df          df 1.000000 1.000000

``` r
c(largest_estimate_difference = max(abs(fit@theta - lavaan::coef(lv)[nm])),
  se_difference_expected = max(abs(sqrt(diag(fit_exp@vcov)) - sqrt(diag(lavaan::vcov(lv)))[nm])),
  se_difference_observed = max(abs(sqrt(diag(fit_obs@vcov)) - sqrt(diag(lavaan::vcov(lv_obs)))[nm])))
```

    largest_estimate_difference      se_difference_expected
                   3.583168e-07                2.533682e-08
         se_difference_observed
                   5.012964e-08 

``` r
suppressMessages(library(OpenMx))
mxOption(NULL, "Number of Threads", 1)
dat <- d[, c("mediator1", "treatment", "outcome")]
vars <- names(dat)
mod <- mxModel(
  "constrained", type = "RAM", manifestVars = vars,
  mxPath(from = "treatment", to = "mediator1", values = 0.3, labels = "a"),
  mxPath(from = "mediator1", to = "outcome", values = 0.6, labels = "b"),
  mxPath(from = "treatment", to = "outcome", values = 0.2, labels = "cp"),
  mxPath(from = vars, arrows = 2, values = 1, labels = paste0("v_", vars)),
  mxPath(from = "one", to = vars, values = 0, labels = paste0("m_", vars)),
  mxAlgebra(a * b, name = "ab"),
  mxConstraint(cp == ab, name = "k"),
  mxData(dat, type = "raw")
)
run_mx <- mxRun(mod, silent = TRUE)
est_mx <- stats::setNames(summary(run_mx)$parameters$Estimate, summary(run_mx)$parameters$name)
fit_mean <- fit_sem(txt, d, meanstructure = TRUE)
data.frame(quantity = "-2 log L", medfit = -2 * as.numeric(logLik(fit_mean)),
           OpenMx = summary(run_mx)$Minus2LogLikelihood)
```

      quantity  medfit  OpenMx
    1 -2 log L 2980.31 2980.31

``` r
c(largest_estimate_difference = max(abs(est_mx[c("a", "b", "cp")] - fit@theta[c("a", "b", "cp")])))
```

    largest_estimate_difference
                    8.95911e-08 

``` r
stats::setNames(summary(run_mx)$parameters$Std.Error, summary(run_mx)$parameters$name)[c("a", "b", "cp")]
```

     a  b cp
    NA NA NA 

OpenMx’s `-2 log L` includes the means, which is why the native fit with
a mean structure is the comparison. Its standard errors for the three
parameters in the `mxConstraint` are printed last; when they are `NA`
(OpenMx does not always report standard errors under a nonlinear
equality), the standard errors are compared with lavaan only.

## Check yourself

1.  Why do rows have unit length, and what would break if they did not?
    (Answer: the tolerances that act on the rows, the rank of the
    equality rows and the \\10^{-12}\\ test for implied inequalities,
    would depend on how a constraint was written: `2*a + 2*b == 2.4` and
    `a + b == 1.2` would be treated differently.)
2.  For `a*b == 0.1`, what is the gradient of the row at \\a = b = 0\\?
    Why is that not the problem it is for `a*b == 0`? (Answer: \\(b, a)
    = 0\\ there, but \\a = b = 0\\ is infeasible for `a*b == 0.1`, whose
    feasible set, a hyperbola, has a nonzero gradient at every point.
    For `a*b == 0` the point \\a = b = 0\\ is feasible: it is where the
    two branches cross, and the solver can stop on either branch.)
3.  A fit is rejected with the reason `stationarity ... exceeds 1e-03`.
    Is the constraint satisfied? (Answer: yes, the constraint check
    comes first; the point is feasible but not yet an optimum, as in the
    `feasible, not optimal` row above.)

## Where next

[Chapter
4](https://data-wise.github.io/medfit/articles/native-book-4-fixed-x.md)
returns to the unconstrained discrepancy and asks what changes when the
moments of the exogenous variables are not parameters but data.
