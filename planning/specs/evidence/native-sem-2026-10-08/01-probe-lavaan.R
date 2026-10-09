suppressMessages(library(lavaan)); cat("lavaan", as.character(packageVersion("lavaan")), "\n")
m <- "
M =~ 1*m1 + l2*m2 + m3
M ~ a*X + start(0.2)*C
Y ~ b*M + cp*X + lower(-1)*C
Y ~~ upper(5)*Y
m1 ~ 0*1
ab := a*b
a == b
cp > 0
a < 2
"
p <- lavParseModelString(m, as.data.frame.=TRUE)
print(p[, c("lhs","op","rhs","block","fixed","label","start","lower","upper")], row.names=FALSE)
cat("constraints:", paste(vapply(attr(p,"constraints"), function(z) paste(z$lhs, z$op, z$rhs), ""), collapse=" | "), "\n")
p2 <- lavParseModelString("level: 1\n Y ~ X\nlevel: 2\n Y ~ W", as.data.frame.=TRUE); print(p2[, c("lhs","op","rhs","block")], row.names=FALSE)
cat("comma:\n"); print(lavParseModelString("y1, y2 ~ x", as.data.frame.=TRUE)[,c("lhs","op","rhs")])
