# print and summary of a hand-built SEMFit are stable

    Code
      print(fit)
    Output
      SEMFit (native maximum likelihood)
      ==================================
      
        Observations:  20 (2 dropped for missing values)
        Parameters:    6 free, 1 df
        Information:   observed
        Converged:     Yes
        Active:        M ~~ M
      
      Defined parameters:
        ab              0.2000  (SE 0.0316)
      
      Use summary() for the parameter table and diagnostics.

---

    Code
      print(summary(fit))
    Output
      Summary of SEMFit
      =================
      
      Observations: 20 (2 dropped for missing values, listwise deletion)
      Degrees of freedom: 1
      Information: observed
      Converged: Yes
      
      Parameters:
         name est     se       z      p
            a 0.5 0.0500 10.0000 <1e-04
            b 0.4 0.0400 10.0000 <1e-04
        Y ~ X 0.2 0.0300  6.6667 <1e-04
       M ~~ M 0.8 0.1000  8.0000 <1e-04
       Y ~~ Y 0.7 0.0894  7.8262 <1e-04
       X ~~ X 1.0 0.1095  9.1287 <1e-04
      
      Defined parameters:
       name expr est     se
         ab  a*b 0.2 0.0316
      
      Diagnostics:
        Optimizer status: 4; stationarity 2.50e-08; retries 0
        Active bounds: M ~~ M
        Active constraints: none
        Improper solution: no
        Multiplier sign check: ok

