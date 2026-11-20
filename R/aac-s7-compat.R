# S7 compatibility for classes with a property named `call`.
#
# S7 1.0.0 changed `new_object(_parent, ...)` to collect its dots with
# `collect_dots(..., call = sys.call(-1))`, so a property passed as
# `call = call` binds to that formal and is dropped: a required `@call`
# fails validation and an optional one is silently NULL. S7 1.0.0 also
# accepts the properties as one unnamed list, which avoids the clash; S7 0.2.2
# does not. `.s7_call_safe()` rebuilds a class with a constructor that keeps
# the generated formals and picks the form at run time, so one installed
# medfit works with either S7. Remove once S7 forwards a `call` property.

.s7_dots_take_list <- function() {
  "_parent" %in% names(formals(S7::new_object))
}

.s7_call_safe <- function(cls) {
  ctor <- attr(cls, "constructor")
  nms <- names(formals(ctor))
  syms <- lapply(nms, as.name)
  names(syms) <- nms
  props <- as.call(c(quote(list), syms))
  body(ctor) <- bquote(
    if (.s7_dots_take_list()) {
      S7::new_object(S7::S7_object(), .(props))
    } else .(body(ctor))
  )
  S7::new_class(
    cls@name,
    parent = cls@parent,
    package = cls@package,
    properties = cls@properties,
    abstract = cls@abstract,
    validator = cls@validator,
    constructor = ctor
  )
}
