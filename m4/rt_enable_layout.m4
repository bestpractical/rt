dnl
dnl @synopsis RT_ENABLE_LAYOUT()
dnl
dnl Enable a specific directory layout for the installation to use.
dnl This configures a command-line parameter that can be specified
dnl at ./configure invocation.
dnl
dnl The use of this feature in this way is a little hackish, but
dnl better than a heap of options for every directory.
dnl
dnl This code is heavily borrowed *cough* from the Apache 2 code.
dnl

AC_DEFUN([RT_ENABLE_LAYOUT],[
AC_ARG_ENABLE(layout,
	      AC_HELP_STRING([--enable-layout=LAYOUT],
	      		     [Use a specific directory layout (Default: RT3)]),
	      LAYOUT=$enableval)

if test "x$LAYOUT" = "x"; then
	LAYOUT="RT3"
fi
RT_LAYOUT($srcdir/config.layout, $LAYOUT)
AC_MSG_CHECKING(for chosen layout)
if test "x$rt_layout_name" = "xno"; then
	if test "x$LAYOUT" = "xno"; then
		AC_MSG_RESULT(none)
	else
		AC_MSG_RESULT($LAYOUT)
	fi
	AC_MSG_ERROR([a valid layout must be specified (or the default used)])
else
	AC_SUBST(rt_layout_name)
	AC_MSG_RESULT($rt_layout_name)
fi
])
