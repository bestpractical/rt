dnl
dnl Process this file with autoconf to produce a configure script
dnl
dnl Embed in generated ./configure script the following CVS info:
AC_REVISION($Revision: 1.1 $)dnl

dnl Setup autoconf
AC_PREREQ(2.53)
AC_INIT(RT, [3.0.4], [rt-3.0-bugs@fsck.com])
AC_CONFIG_SRCDIR([lib/RT.pm.in])

dnl Extract RT version number components
AC_SUBST([rt_version_major],
	m4_bregexp(AC_PACKAGE_VERSION,[^\(\w+\)\.\(\w+\)\(\.\(\w+\)\)?],[\1]))
AC_SUBST([rt_version_minor],
	m4_bregexp(AC_PACKAGE_VERSION,[^\(\w+\)\.\(\w+\)\(\.\(\w+\)\)?],[\2]))
AC_SUBST([rt_version_patch],
	m4_bregexp(AC_PACKAGE_VERSION,[^\(\w+\)\.\(\w+\)\(\.\(\w+\)\)?],[\4]))
test "x$rt_version_major" = 'x' && rt_version_major=0
test "x$rt_version_minor" = 'x' && rt_version_minor=0
test "x$rt_version_patch" = 'x' && rt_version_patch=0

dnl Check for programs
AC_PROG_INSTALL
AC_ARG_VAR([PERL],[Perl interpreter command])
AC_PATH_PROG([PERL], [perl], [not found])
if test "$PERL" = 'not found'; then
	AC_MSG_ERROR([cannot use $PACKAGE_NAME without perl])
fi
dnl SPEED_BIN
AC_ARG_WITH(speedycgi,
	    AC_HELP_STRING([--with-speedycgi=/path/to/speedy],
	    		   [path to your speedycgi binary, if it exists]),
            SPEEDY_BIN=$withval,
            SPEEDY_BIN=/usr/local/bin/speedy) 
AC_SUBST(SPEEDY_BIN)


dnl Defaults paths for installation
AC_PREFIX_DEFAULT([/opt/rt3])
RT_ENABLE_LAYOUT

dnl RTGROUP
AC_ARG_WITH(rt-group,
	    AC_HELP_STRING([--with-rt-group=GROUP],
	    		   [group to own all files (default: rt)]),
            RTGROUP=$withval,
            RTGROUP=rt)
AC_SUBST(RTGROUP)

dnl BIN_OWNER
AC_ARG_WITH(bin-owner,
	    AC_HELP_STRING([--with-bin-owner=OWNER],
	    		   [user that will own rt binaries (default root)]),
            BIN_OWNER=$withval,
            BIN_OWNER=root)
AC_SUBST(BIN_OWNER)

dnl LIBS_OWNER
AC_ARG_WITH(libs-owner,
	    AC_HELP_STRING([--with-libs-owner=OWNER],
	    		   [user that will own RT libraries (default root)]),
            LIBS_OWNER=$withval,
            LIBS_OWNER=root)
AC_SUBST(LIBS_OWNER)

dnl LIBS_GROUP
AC_ARG_WITH(libs-group,
	    AC_HELP_STRING([--with-libs-group=GROUP],
	    		   [group that will own rt binaries (default bin)]),
            LIBS_GROUP=$withval,
            LIBS_GROUP=bin)
AC_SUBST(LIBS_GROUP)

dnl DB_TYPE
AC_ARG_WITH(db-type,
	    AC_HELP_STRING([--with-db-type=TYPE],
	    		   [sort of database RT will use (default: mysql) (mysql and Pg are valid)]), 
            DB_TYPE=$withval,
            DB_TYPE=mysql)
if test "$DB_TYPE" != 'mysql' -a "$DB_TYPE" != 'Pg' -a "$DB_TYPE" != 'SQLite'; then
	AC_MSG_ERROR([Only Pg and mysql are valid db types])
fi
AC_SUBST(DB_TYPE)

dnl DB_HOST
AC_ARG_WITH(db-host,
	    AC_HELP_STRING([--with-db-host=HOSTNAME],
	    		   [FQDN of database server (default: localhost)]),
            DB_HOST=$withval,
            DB_HOST=localhost)
AC_SUBST(DB_HOST)

dnl DB_PORT
AC_ARG_WITH(db-port,
	    AC_HELP_STRING([--with-db-port=PORT],
	    		   [port on which the database listens on]),
            DB_PORT=$withval,
            DB_PORT=)
AC_SUBST(DB_PORT)

dnl DB_RT_HOST
AC_ARG_WITH(db-rt-host,
	    AC_HELP_STRING([--with-db-rt-host=HOSTNAME],
	    		   [FQDN of RT server which talks to the database server (default: localhost)]),
            DB_RT_HOST=$withval,
            DB_RT_HOST=localhost)
AC_SUBST(DB_RT_HOST)

dnl DB_DATABASE_ADMIN
AC_ARG_WITH(db-dba,
	    AC_HELP_STRING([--with-db-dba=DBA],
	    		   [name of database administrator (default: root)]),
            DB_DBA=$withval,
            DB_DBA=root)
AC_SUBST(DB_DBA)

dnl DB_DATABASE
AC_ARG_WITH(db-database,
	    AC_HELP_STRING([--with-db-database=DBNAME],
	    		   [name of the database to use (default: rt3)]),
            DB_DATABASE=$withval,
            DB_DATABASE=rt3)
AC_SUBST(DB_DATABASE)

dnl DB_RT_USER
AC_ARG_WITH(db-rt-user,
	    AC_HELP_STRING([--with-db-rt-user=DBUSER],
	    		   [name of database user (default: rt_user)]),
            DB_RT_USER=$withval,
            DB_RT_USER=rt_user)
AC_SUBST(DB_RT_USER)

dnl DB_RT_PASS
AC_ARG_WITH(db-rt-pass,
	    AC_HELP_STRING([--with-db-rt-pass=PASSWORD],
	    		   [password for database user (default: rt_pass)]),
            DB_RT_PASS=$withval,
            DB_RT_PASS=rt_pass)
AC_SUBST(DB_RT_PASS)

dnl WEB_USER
AC_ARG_WITH(web-user,
	    AC_HELP_STRING([--with-web-user=USER],
	    		   [user the web server runs as (default: www)]),
            WEB_USER=$withval,
            WEB_USER=www)
AC_SUBST(WEB_USER)

dnl WEB_GROUP
AC_ARG_WITH(web-group,
            AC_HELP_STRING([--with-web-group=GROUP],
		           [group the web server runs as (default: www)]),
            WEB_GROUP=$withval,
            WEB_GROUP=www)
AC_SUBST(WEB_GROUP)

dnl This section maps the variable names this script 'natively' generates
dnl to their existing names. They should be removed from here as the .in
dnl files are changed to use the new names.

dnl version numbers
AC_SUBST(RT_VERSION_MAJOR,		${rt_version_major})
AC_SUBST(RT_VERSION_MINOR,		${rt_version_minor})
AC_SUBST(RT_VERSION_PATCH,		${rt_version_patch})

dnl layout paths
AC_SUBST([RT_PATH],			${exp_prefix})
AC_SUBST([RT_DOC_PATH],			${exp_manualdir})
AC_SUBST([RT_LOCAL_PATH],		${exp_customdir})
AC_SUBST([RT_LIB_PATH],			${exp_libdir})
AC_SUBST([RT_ETC_PATH],			${exp_sysconfdir})
AC_SUBST([CONFIG_FILE_PATH],		${exp_sysconfdir})
AC_SUBST([RT_BIN_PATH],			${exp_bindir})
AC_SUBST([RT_SBIN_PATH],		${exp_sbindir})
AC_SUBST([RT_VAR_PATH],			${exp_localstatedir})
AC_SUBST([RT_MAN_PATH],			${exp_mandir})
AC_SUBST([MASON_DATA_PATH],		${exp_masonstatedir})
AC_SUBST([MASON_SESSION_PATH],		${exp_sessionstatedir})
AC_SUBST([MASON_HTML_PATH],		${exp_htmldir})
AC_SUBST([LOCAL_ETC_PATH],		${exp_custometcdir})
AC_SUBST([MASON_LOCAL_HTML_PATH],	${exp_customhtmldir})
AC_SUBST([LOCAL_LEXICON_PATH],		${exp_customlexdir})
AC_SUBST([LOCAL_LIB_PATH],		${exp_customlibdir})
AC_SUBST([DESTDIR],			${exp_prefix})
AC_SUBST([RT_LOG_PATH],			${exp_logfiledir})

dnl Configure the output files, and generate them.

AC_CONFIG_FILES([
		 sbin/rt-setup-database
                 sbin/rt-test-dependencies
                 Makefile
		 etc/RT_Config.pm
		 lib/RT.pm
                 lib/t/00smoke.t
                 lib/t/01harness.t
                 lib/t/02regression.t
                 lib/t/03web.pl
                 lib/t/04_send_email.pl
 		 bin/mason_handler.fcgi
 		 bin/mason_handler.scgi
 		 bin/mason_handler.svc
 		 bin/rt-commit-handler
 		 bin/rt-crontool
 		 bin/rt-mailgate
 		 bin/webmux.pl]
                )
AC_OUTPUT
