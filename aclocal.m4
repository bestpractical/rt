# aclocal.m4 generated automatically by aclocal 1.6.3 -*- Autoconf -*-

# Copyright 1996, 1997, 1998, 1999, 2000, 2001, 2002
# Free Software Foundation, Inc.
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.

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

dnl
dnl @synopsis RT_LAYOUT(configlayout, layoutname)
dnl
dnl This macro reads an Apache-style layout file (specified as the
dnl configlayout parameter), and searches for a specific layout
dnl (named using the layoutname parameter).
dnl
dnl The entries for a given layout are then inserted into the
dnl environment such that they become available as substitution
dnl variables. In addition, the rt_layout_name variable is set
dnl (but not exported) if the layout is valid.
dnl
dnl This code is heavily borrowed *cough* from the Apache 2 codebase.
dnl

AC_DEFUN([RT_LAYOUT],[
	if test ! -f $srcdir/config.layout; then
		AC_MSG_WARN([Layout file $srcdir/config.layout not found])
		rt_layout_name=no
	else
		pldconf=./config.pld
		changequote({,})
		sed -e "1,/[  ]*<[lL]ayout[   ]*$2[   ]*>[    ]*/d" \
		    -e '/[    ]*<\/Layout>[   ]*/,$d' \
		    -e "s/^[  ]*//g" \
		    -e "s/:[  ]*/=\'/g" \
		    -e "s/[   ]*$/'/g" \
		    $1 > $pldconf
		changequote([,])
		if test -s $pldconf; then
			rt_layout_name=$2
			. $pldconf
			changequote({,})
			for var in prefix exec_prefix bindir sbindir \
				 sysconfdir mandir libdir datadir htmldir \
				 localstatedir logfiledir masonstatedir \
				 sessionstatedir customdir customhtmldir \
				 customlexdir; do
				eval "val=\"\$$var\""
				case $val in
				*+)
					val=`echo $val | sed -e 's;\+$;;'`
					eval "$var=\"\$val\""
					autosuffix=yes
					;;
				*)
					autosuffix=no
					;;
				esac
				val=`echo $val | sed -e 's:\(.\)/*$:\1:'`
				val=`echo $val | 
					sed -e 's:[\$]\([a-z_]*\):${\1}:g'`
				if test "$autosuffix" = "yes"; then
					if echo $val | grep rt3 >/dev/null; then
						addtarget=no
					else
						addtarget=yes
					fi
					if test "$addtarget" = "yes"; then
						val="$val/rt3"
					fi
				fi
				eval "$var='$val'"
			done
			changequote([,])
		else
			rt_layout_name=no
		fi
		rm $pldconf
	fi
	RT_SUBST_EXPANDED_ARG(prefix)
	RT_SUBST_EXPANDED_ARG(exec_prefix)
	RT_SUBST_EXPANDED_ARG(bindir)
	RT_SUBST_EXPANDED_ARG(sbindir)
	RT_SUBST_EXPANDED_ARG(sysconfdir)
	RT_SUBST_EXPANDED_ARG(mandir)
	RT_SUBST_EXPANDED_ARG(libdir)
	RT_SUBST_EXPANDED_ARG(datadir)
	RT_SUBST_EXPANDED_ARG(htmldir)
	RT_SUBST_EXPANDED_ARG(localstatedir)
	RT_SUBST_EXPANDED_ARG(logfiledir)
	RT_SUBST_EXPANDED_ARG(masonstatedir)
	RT_SUBST_EXPANDED_ARG(sessionstatedir)
	RT_SUBST_EXPANDED_ARG(customdir)
	RT_SUBST_EXPANDED_ARG(customhtmldir)
	RT_SUBST_EXPANDED_ARG(customlexdir)
])dnl

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

dnl
dnl @synopsis	RT_EXPAND_VAR(baz, $fraz)
dnl
dnl Iteratively expands the second parameter, until successive iterations
dnl yield no change. The result is then assigned to the first parameter.
dnl
dnl This code is heavily borrowed from the Apache 2 codebase.
dnl

AC_DEFUN([RT_EXPAND_VAR],[
	ap_last=''
	ap_cur='$2'
	while test "x${ap_cur}" != "x${ap_last}"; do
		ap_last="${ap_cur}"
		ap_cur=`eval "echo ${ap_cur}"`
	done
	$1="${ap_cur}"
])

