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
		s/<\/Layout>.*//s; 
		s/^#.*$//gm;
		s/^\s+//gim;
		s/\s+$/\n/gim;
		s/\+$/\/rt3/gim;
		# m4 will not let us just use $1, we need @S|@1
#		s/^((?:bin|sbin|libexec|data|sysconf|sharedstate|localstate|lib|include|oldinclude|plugin|info|man)dir)\s*:\s*(.*)$/@S|@1=@S|@2/gim;
		# uh, should be [:=], but m4 apparently substitutes something...
		s/^(.*?)\s*(?::|=)\s*(.*)$/\(test "x\@S|@@S|@1" = "xNONE" || test "x\@S|@@S|@1" = "x") && @S|@1=@S|@2/gim;
		 ' < $1 > $pldconf

		if test -s $pldconf; then
			rt_layout_name=$2
			. $pldconf
			changequote({,})
			for var in prefix exec_prefix bindir sbindir \
				 sysconfdir mandir libdir datadir htmldir \
				 localstatedir logfiledir masonstatedir plugindir \
				 sessionstatedir customdir custometcdir customhtmldir \
				 customlexdir customlibdir manualdir; do
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
	RT_SUBST_EXPANDED_ARG(datadir)
	RT_SUBST_EXPANDED_ARG(htmldir)
	RT_SUBST_EXPANDED_ARG(manualdir)
	RT_SUBST_EXPANDED_ARG(plugindir)
	RT_SUBST_EXPANDED_ARG(localstatedir)
	RT_SUBST_EXPANDED_ARG(logfiledir)
	RT_SUBST_EXPANDED_ARG(masonstatedir)
	RT_SUBST_EXPANDED_ARG(sessionstatedir)
	RT_SUBST_EXPANDED_ARG(customdir)
	RT_SUBST_EXPANDED_ARG(custometcdir)
	RT_SUBST_EXPANDED_ARG(customhtmldir)
	RT_SUBST_EXPANDED_ARG(customlexdir)
	RT_SUBST_EXPANDED_ARG(customlibdir)
])dnl
