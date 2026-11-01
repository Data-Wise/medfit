# Final-gates serialization diagnostic receipt

Date: 2026-11-01. This is a **post-execution receipt**, not a preregistration.
Statistical admission remains deferred; the frozen six-cell matrix was not rerun.

The first final installed-package suite under covr completed with two failures in
whole-object serialization immutability assertions. The gate owner declared a narrow
diagnostic in a message before execution, but did not put that declaration in a
tracked fixture manifest before execution. This violates the tracked preregistration
requirement; the deviation cannot be undone and is retained without a budget reset.

Exactly one diagnostic source fit ran using the already frozen MAR/free fixture:
`fb_model(TRUE)`, `fb_fixture("mar", TRUE)`, n300, seed271, missing=`fiml`,
fixed_x=FALSE. It used the retained covr-instrumented installation, then B8 Gaussian
parameter draws at seed123; zero refits, zero lavaan calls and zero additional cells.
The one diagnostic command used 3.512708166 wall /3.469105 child CPU seconds and is
recorded in the shared verification.jsonl. No subsequent diagnostic fit is permitted
without a tracked pre-execution declaration.

Direct saved evidence: one whole-source serialized byte changes (offset4011823),
while every S7 source property serializes identically before and after. The changed
serialized attribute is `S7_class`, a closure descriptor; source property values
remain unchanged. Both unserialized objects and their attributes compare equal via
all.equal, although identical on the entire unserialized objects is false. The exact
R closure flag meaning has not been established; no conclusion about that flag is
used to waive immutability. Implementation and independent QA must replace brittle
format-level equality with meaningful property/attribute checks that still detect
real source mutations, then verify under instrumentation and without it.

Artifacts: `_agents_workspace/fiml-bounded-inference/diagnose-immutability.R`,
`immutability-diagnosis.rds`, retained coverage library/traces and failed full-suite
results. Gate owner ran no full-suite retry and no new optimizer study.
