dnl
dnl @synopsis	RT_SUBST_EXPANDED_ARG(var)
dnl
dnl Export (via AC_SUBST) a given variable, along with an expanded
dnl version of the variable (same name, but with exp_ prefix).
dnl
dnl This code is heavily borrowed *cough* from the Apache 2 source.
dnl

AC_DEFUN([RT_SUBST_EXPANDED_ARG],[
	RT_EXPAND_VAR(exp_$1, [$]$1)
	AC_SUBST($1)
	AC_SUBST(exp_$1)
])
