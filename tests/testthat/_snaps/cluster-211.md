# print() and summary() end with the estimand and assumptions block

    Code
      print(snap_object(TRUE))
    Output
      <ClusterMediationData>
        X -> M -> Y  (clusters: school)
        a = +0.5000   b_within = +0.3000   b_between = +0.6000   c' = +0.2000
        NIE (a * b_between) = +0.3000
        n = 400 in 40 clusters (sizes 8 to 12)   |   within outcome model, model SEs
      Estimand and assumptions:
        Design: treatment `X` assigned to 40 clusters (`school`, sizes 8 to 12); linear mixed
          models with a random cluster intercept, mediator entering through the observed
          cluster mean.
        - All rows: linear models with no mediator-by-treatment or mediator-by-covariate
          products; treatment randomized; clusters intact.
        - Own (a * b_within): no unmeasured lower-level M-Y confounding; additive upper-level
          confounders are allowed because level-1 covariates are cluster-mean centered.
        - Spillover, NIE and NDE: also no unmeasured upper-level M-Y confounding.
        - TE: no assumption beyond randomization of the treatment.
        - Own/spillover split: a cross-world assumption across individuals in a cluster; no
          treatment-induced M-Y confounding.
        - Interference only through the observed cluster mean of the mediator and none
          between clusters; members missing from the analysis rows are assumed not to drive
          their peers' outcomes.

---

    Code
      print(summary(snap_object(TRUE)))
    Output
      Summary of ClusterMediationData
      ===============================
      
      X -> M -> Y, clusters `school`
      
      Effects (unit contrast 0 -> 1):
                       estimate std.error conf.low conf.high
      NIE                  0.30    0.0857   0.1320    0.4680
      NDE                  0.20    0.1414  -0.0772    0.4772
      Total                0.50    0.1669   0.1729    0.8271
      Own (a*b_within)     0.15    0.0406   0.0704    0.2296
      Spillover            0.15    0.0721   0.0087    0.2913
        95% normal-approximation intervals (model SEs).
        Own and spillover are the cluster-average, large-cluster approximation.
        D-own gap |a (b_between - b_within)| / H = 0.01562 (own SE 0.04062)
      
      Path coefficients:
              a  b_within b_between   c_prime 
            0.5       0.3       0.6       0.2 
      
      Estimand and assumptions:
        Design: treatment `X` assigned to 40 clusters (`school`, sizes 8 to 12); linear mixed
          models with a random cluster intercept, mediator entering through the observed
          cluster mean.
        - All rows: linear models with no mediator-by-treatment or mediator-by-covariate
          products; treatment randomized; clusters intact.
        - Own (a * b_within): no unmeasured lower-level M-Y confounding; additive upper-level
          confounders are allowed because level-1 covariates are cluster-mean centered.
        - Spillover, NIE and NDE: also no unmeasured upper-level M-Y confounding.
        - TE: no assumption beyond randomization of the treatment.
        - Own/spillover split: a cross-world assumption across individuals in a cluster; no
          treatment-induced M-Y confounding.
        - Interference only through the observed cluster mean of the mediator and none
          between clusters; members missing from the analysis rows are assumed not to drive
          their peers' outcomes.
      
      Sample Size: 400 in 40 clusters
      Converged:   Yes 
      Source:      lme4 

---

    Code
      print(snap_object(FALSE))
    Output
      <ClusterMediationData>
        X -> M -> Y  (clusters: school)
        a = +0.5000   b_within = +0.3000   b_between = +0.6000   c' = +0.2000
        NIE (a * b_between) = +0.3000
        n = 400 in 40 clusters (sizes 8 to 12)   |   within outcome model, model SEs
      Estimand and assumptions:
        Design: treatment `X` assigned to 40 clusters (`school`, sizes 8 to 12); linear mixed
          models with a random cluster intercept, mediator entering through the observed
          cluster mean.
        - All rows: linear models with no mediator-by-treatment or mediator-by-covariate
          products; treatment randomized; clusters intact.
        - Own (a * b_within): no unmeasured lower-level M-Y confounding. Level-1 covariates
          in the outcome model have no cluster-mean companion, so robustness to upper-level
          confounding does NOT hold.
        - Spillover, NIE and NDE: also no unmeasured upper-level M-Y confounding.
        - TE: no assumption beyond randomization of the treatment.
        - Own/spillover split: a cross-world assumption across individuals in a cluster; no
          treatment-induced M-Y confounding.
        - Interference only through the observed cluster mean of the mediator and none
          between clusters; members missing from the analysis rows are assumed not to drive
          their peers' outcomes.

---

    Code
      print(summary(snap_object(FALSE)))
    Output
      Summary of ClusterMediationData
      ===============================
      
      X -> M -> Y, clusters `school`
      
      Effects (unit contrast 0 -> 1):
                       estimate std.error conf.low conf.high
      NIE                  0.30    0.0857   0.1320    0.4680
      NDE                  0.20    0.1414  -0.0772    0.4772
      Total                0.50    0.1669   0.1729    0.8271
      Own (a*b_within)     0.15    0.0406   0.0704    0.2296
      Spillover            0.15    0.0721   0.0087    0.2913
        95% normal-approximation intervals (model SEs).
        Own and spillover are the cluster-average, large-cluster approximation.
        D-own gap |a (b_between - b_within)| / H = 0.01562 (own SE 0.04062)
      
      Path coefficients:
              a  b_within b_between   c_prime 
            0.5       0.3       0.6       0.2 
      
      Estimand and assumptions:
        Design: treatment `X` assigned to 40 clusters (`school`, sizes 8 to 12); linear mixed
          models with a random cluster intercept, mediator entering through the observed
          cluster mean.
        - All rows: linear models with no mediator-by-treatment or mediator-by-covariate
          products; treatment randomized; clusters intact.
        - Own (a * b_within): no unmeasured lower-level M-Y confounding. Level-1 covariates
          in the outcome model have no cluster-mean companion, so robustness to upper-level
          confounding does NOT hold.
        - Spillover, NIE and NDE: also no unmeasured upper-level M-Y confounding.
        - TE: no assumption beyond randomization of the treatment.
        - Own/spillover split: a cross-world assumption across individuals in a cluster; no
          treatment-induced M-Y confounding.
        - Interference only through the observed cluster mean of the mediator and none
          between clusters; members missing from the analysis rows are assumed not to drive
          their peers' outcomes.
      
      Sample Size: 400 in 40 clusters
      Converged:   Yes 
      Source:      lme4 

