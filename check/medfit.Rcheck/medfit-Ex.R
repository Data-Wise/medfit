pkgname <- "medfit"
source(file.path(R.home("share"), "R", "examples-header.R"))
options(warn = 1)
base::assign(".ExTimings", "medfit-Ex.timings", pos = 'CheckExEnv')
base::cat("name\tuser\tsystem\telapsed\n", file=base::get(".ExTimings", pos = 'CheckExEnv'))
base::assign(".format_ptime",
function(x) {
  if(!is.na(x[4L])) x[1L] <- x[1L] + x[4L]
  if(!is.na(x[5L])) x[2L] <- x[2L] + x[5L]
  options(OutDec = '.')
  format(x[1L:3L], digits = 7L)
},
pos = 'CheckExEnv')

### * </HEADER>
library('medfit')

base::assign(".oldSearch", base::search(), pos = 'CheckExEnv')
base::assign(".old_wd", base::getwd(), pos = 'CheckExEnv')
cleanEx()
nameEx("BootstrapResult")
### * BootstrapResult

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: BootstrapResult
### Title: BootstrapResult S7 Class
### Aliases: BootstrapResult

### ** Examples

## Not run: 
##D # Parametric bootstrap result
##D result <- BootstrapResult(
##D   estimate = 0.15,
##D   ci_lower = 0.10,
##D   ci_upper = 0.20,
##D   ci_level = 0.95,
##D   boot_estimates = rnorm(1000, 0.15, 0.02),
##D   n_boot = 1000L,
##D   method = "parametric",
##D   call = NULL
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("BootstrapResult", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("MediationData")
### * MediationData

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: MediationData
### Title: MediationData S7 Class
### Aliases: MediationData

### ** Examples

## Not run: 
##D # Create a MediationData object
##D med_data <- MediationData(
##D   a_path = 0.5,
##D   b_path = 0.3,
##D   c_prime = 0.2,
##D   estimates = c(0.5, 0.3, 0.2),
##D   vcov = diag(3) * 0.01,
##D   sigma_m = 1.0,
##D   sigma_y = 1.2,
##D   treatment = "X",
##D   mediator = "M",
##D   outcome = "Y",
##D   mediator_predictors = "X",
##D   outcome_predictors = c("X", "M"),
##D   data = NULL,
##D   n_obs = 100L,
##D   converged = TRUE,
##D   source_package = "stats"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("MediationData", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("SerialMediationData")
### * SerialMediationData

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: SerialMediationData
### Title: SerialMediationData S7 Class
### Aliases: SerialMediationData

### ** Examples

## Not run: 
##D # Two-mediator serial mediation (X -> M1 -> M2 -> Y)
##D # Product-of-three: a * d * b
##D serial_data <- SerialMediationData(
##D   a_path = 0.5,       # X -> M1
##D   d_path = 0.4,       # M1 -> M2 (scalar for 2 mediators)
##D   b_path = 0.3,       # M2 -> Y
##D   c_prime = 0.1,      # X -> Y (direct)
##D   estimates = c(0.5, 0.4, 0.3, 0.1),
##D   vcov = diag(4) * 0.01,
##D   sigma_mediators = c(1.0, 1.1),  # SD for M1, M2 models
##D   sigma_y = 1.2,
##D   treatment = "X",
##D   mediators = c("M1", "M2"),
##D   outcome = "Y",
##D   mediator_predictors = list(
##D     c("X"),           # M1 ~ X
##D     c("X", "M1")      # M2 ~ X + M1
##D   ),
##D   outcome_predictors = c("X", "M1", "M2"),  # Y ~ X + M1 + M2
##D   data = NULL,
##D   n_obs = 100L,
##D   converged = TRUE,
##D   source_package = "lavaan"
##D )
##D 
##D # Three-mediator serial mediation (X -> M1 -> M2 -> M3 -> Y)
##D # Product-of-four: a * d21 * d32 * b
##D serial_data_3 <- SerialMediationData(
##D   a_path = 0.5,           # X -> M1
##D   d_path = c(0.4, 0.35),  # M1 -> M2, M2 -> M3 (vector for 3 mediators)
##D   b_path = 0.3,           # M3 -> Y
##D   c_prime = 0.1,
##D   estimates = c(0.5, 0.4, 0.35, 0.3, 0.1),
##D   vcov = diag(5) * 0.01,
##D   sigma_mediators = c(1.0, 1.1, 1.05),  # SD for M1, M2, M3 models
##D   sigma_y = 1.2,
##D   treatment = "X",
##D   mediators = c("M1", "M2", "M3"),
##D   outcome = "Y",
##D   mediator_predictors = list(
##D     c("X"),              # M1 ~ X
##D     c("X", "M1"),        # M2 ~ X + M1
##D     c("X", "M1", "M2")   # M3 ~ X + M1 + M2
##D   ),
##D   outcome_predictors = c("X", "M1", "M2", "M3"),
##D   data = NULL,
##D   n_obs = 100L,
##D   converged = TRUE,
##D   source_package = "lavaan"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("SerialMediationData", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("bootstrap_mediation")
### * bootstrap_mediation

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: bootstrap_mediation
### Title: Perform Bootstrap Inference for Mediation Statistics
### Aliases: bootstrap_mediation

### ** Examples

## Not run: 
##D # Parametric bootstrap for indirect effect
##D result <- bootstrap_mediation(
##D   statistic_fn = function(theta) theta["a"] * theta["b"],
##D   method = "parametric",
##D   mediation_data = med_data,
##D   n_boot = 5000,
##D   ci_level = 0.95,
##D   seed = 12345
##D )
##D 
##D # Nonparametric bootstrap with parallel processing
##D result <- bootstrap_mediation(
##D   statistic_fn = function(data) {
##D     # Refit models and compute statistic
##D     # ...
##D   },
##D   method = "nonparametric",
##D   data = mydata,
##D   n_boot = 5000,
##D   parallel = TRUE,
##D   seed = 12345
##D )
##D 
##D # Plugin estimator (no CI)
##D result <- bootstrap_mediation(
##D   statistic_fn = function(theta) theta["a"] * theta["b"],
##D   method = "plugin",
##D   mediation_data = med_data
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("bootstrap_mediation", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("extract_mediation")
### * extract_mediation

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: extract_mediation
### Title: Extract Mediation Structure from Fitted Models
### Aliases: extract_mediation

### ** Examples

## Not run: 
##D # Extract from lm models
##D fit_m <- lm(M ~ X + C, data = mydata)
##D fit_y <- lm(Y ~ X + M + C, data = mydata)
##D med_data <- extract_mediation(fit_m, model_y = fit_y,
##D                               treatment = "X", mediator = "M")
##D 
##D # Extract from lavaan model
##D library(lavaan)
##D model <- "
##D   M ~ a*X
##D   Y ~ b*M + cp*X
##D "
##D fit <- sem(model, data = mydata)
##D med_data <- extract_mediation(fit, treatment = "X", mediator = "M")
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("extract_mediation", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("extract_mediation_lavaan")
### * extract_mediation_lavaan

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: extract_mediation_lavaan
### Title: Extract Mediation Structure from lavaan Model
### Aliases: extract_mediation_lavaan
### Keywords: internal

### ** Examples

## Not run: 
##D library(lavaan)
##D 
##D # Define mediation model
##D model <- "
##D   M ~ a*X
##D   Y ~ b*M + cp*X
##D "
##D 
##D # Fit model
##D fit <- sem(model, data = mydata)
##D 
##D # Extract mediation structure
##D med_data <- extract_mediation(
##D   fit,
##D   treatment = "X",
##D   mediator = "M",
##D   outcome = "Y"
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("extract_mediation_lavaan", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
cleanEx()
nameEx("fit_mediation")
### * fit_mediation

flush(stderr()); flush(stdout())

base::assign(".ptime", proc.time(), pos = "CheckExEnv")
### Name: fit_mediation
### Title: Fit Mediation Models
### Aliases: fit_mediation

### ** Examples

## Not run: 
##D # Fit Gaussian mediation model
##D med_data <- fit_mediation(
##D   formula_y = Y ~ X + M + C,
##D   formula_m = M ~ X + C,
##D   data = mydata,
##D   treatment = "X",
##D   mediator = "M",
##D   engine = "glm"
##D )
##D 
##D # Fit with binary outcome
##D med_data <- fit_mediation(
##D   formula_y = Y ~ X + M + C,
##D   formula_m = M ~ X + C,
##D   data = mydata,
##D   treatment = "X",
##D   mediator = "M",
##D   engine = "glm",
##D   family_y = binomial()
##D )
## End(Not run)




base::assign(".dptime", (proc.time() - get(".ptime", pos = "CheckExEnv")), pos = "CheckExEnv")
base::cat("fit_mediation", base::get(".format_ptime", pos = 'CheckExEnv')(get(".dptime", pos = "CheckExEnv")), "\n", file=base::get(".ExTimings", pos = 'CheckExEnv'), append=TRUE, sep="\t")
### * <FOOTER>
###
cleanEx()
options(digits = 7L)
base::cat("Time elapsed: ", proc.time() - base::get("ptime", pos = 'CheckExEnv'),"\n")
grDevices::dev.off()
###
### Local variables: ***
### mode: outline-minor ***
### outline-regexp: "\\(> \\)?### [*]+" ***
### End: ***
quit('no')
