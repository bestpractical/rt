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
