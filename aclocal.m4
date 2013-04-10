dnl aclocal.m4 generated automatically by aclocal 1.4-p6

dnl Copyright (C) 1994, 1995-8, 1999, 2001 Free Software Foundation, Inc.
dnl This file is free software; the Free Software Foundation
dnl gives unlimited permission to copy and/or distribute it,
dnl with or without modifications, as long as this notice is preserved.

dnl This program is distributed in the hope that it will be useful,
dnl but WITHOUT ANY WARRANTY, to the extent permitted by law; without
dnl even the implied warranty of MERCHANTABILITY or FITNESS FOR A
dnl PARTICULAR PURPOSE.

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
	      		     [Use a specific directory layout (Default: relative)]),
	      LAYOUT=$enableval)

if test "x$LAYOUT" = "x"; then
	LAYOUT="relative"
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
if test "x$rt_layout_name" != "xinplace" ; then
	AC_SUBST([COMMENT_INPLACE_LAYOUT], [""])
else
	AC_SUBST([COMMENT_INPLACE_LAYOUT], [# ])
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
		$PERL  -0777 -p -e "\$layout = '$2';"  -e '
		s/.*<Layout\s+$layout>//gims; 
		s/\<\/Layout\>.*//s; 
		s/^#.*$//m;
		s/^\s+//gim;
		s/\s+$/\n/gim;
		s/\+$/\/rt3/gim;
		# m4 will not let us just use $1, we need @S|@1
		s/^\s*((?:bin|sbin|libexec|data|sysconf|sharedstate|localstate|lib|include|oldinclude|info|man|html)dir)\s*:\s*(.*)$/@S|@1=@S|@2/gim;
		s/^\s*(.*?)\s*:\s*(.*)$/\(test "x\@S|@@S|@1" = "xNONE" || test "x\@S|@@S|@1" = "x") && @S|@1=@S|@2/gim;
		 ' < $1 > $pldconf

		if test -s $pldconf; then
			rt_layout_name=$2
			. $pldconf
			changequote({,})
			for var in prefix exec_prefix bindir sbindir \
				 sysconfdir mandir libdir datadir htmldir fontdir\
				 lexdir staticdir localstatedir logfiledir masonstatedir \
				 sessionstatedir customdir custometcdir customhtmldir \
				 customlexdir customstaticdir customplugindir customlibdir manualdir; do
				eval "val=\"\$$var\""
				val=`echo $val | sed -e 's:\(.\)/*$:\1:'`
				val=`echo $val | 
					sed -e 's:[\$]\([a-z_]*\):${\1}:g'`
				eval "$var='$val'"
			done
			changequote([,])
		else
			rt_layout_name=no
		fi
		#rm $pldconf
	fi
	RT_SUBST_EXPANDED_ARG(prefix)
	RT_SUBST_EXPANDED_ARG(exec_prefix)
	RT_SUBST_EXPANDED_ARG(bindir)
	RT_SUBST_EXPANDED_ARG(sbindir)
	RT_SUBST_EXPANDED_ARG(sysconfdir)
	RT_SUBST_EXPANDED_ARG(mandir)
	RT_SUBST_EXPANDED_ARG(libdir)
	RT_SUBST_EXPANDED_ARG(lexdir)
	RT_SUBST_EXPANDED_ARG(staticdir)
	RT_SUBST_EXPANDED_ARG(datadir)
	RT_SUBST_EXPANDED_ARG(htmldir)
	RT_SUBST_EXPANDED_ARG(fontdir)
	RT_SUBST_EXPANDED_ARG(manualdir)
	RT_SUBST_EXPANDED_ARG(plugindir)
	RT_SUBST_EXPANDED_ARG(localstatedir)
	RT_SUBST_EXPANDED_ARG(logfiledir)
	RT_SUBST_EXPANDED_ARG(masonstatedir)
	RT_SUBST_EXPANDED_ARG(sessionstatedir)
	RT_SUBST_EXPANDED_ARG(customdir)
	RT_SUBST_EXPANDED_ARG(custometcdir)
	RT_SUBST_EXPANDED_ARG(customplugindir)
	RT_SUBST_EXPANDED_ARG(customhtmldir)
	RT_SUBST_EXPANDED_ARG(customlexdir)
	RT_SUBST_EXPANDED_ARG(customstaticdir)
	RT_SUBST_EXPANDED_ARG(customlibdir)
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

