autoconf; exec ./configure $@
dnl
dnl Process this file with autoconf to produce a configure script
dnl
dnl Embed in generated ./configure script the following CVS info:
AC_REVISION($Revision$)dnl

dnl Setup autoconf
AC_PREREQ([2.53])
AC_INIT(RT, m4_esyscmd([( git describe --tags || cat ./.tag 2> /dev/null || echo "rt-3.9.EXPORTED" )| tr -d "\n"]), [rt-bugs@bestpractical.com])
AC_CONFIG_SRCDIR([lib/RT.pm])

dnl Save our incant early since $@ gets overwritten by some macros.
dnl ${ac_configure_args} is available later, but it's quoted differently
dnl and undocumented.  See http://www.spinics.net/lists/ac/msg10022.html.
AC_SUBST(CONFIGURE_INCANT, "$0 $@")

dnl Extract RT version number components
AC_SUBST([rt_version_major],
	m4_bregexp(AC_PACKAGE_VERSION,[^rt-\(\w+\)\.\(\w+\)\.\(.+\)$],[\1]))
AC_SUBST([rt_version_minor],
	m4_bregexp(AC_PACKAGE_VERSION,[^rt-\(\w+\)\.\(\w+\)\.\(.+\)$],[\2]))
AC_SUBST([rt_version_patch],
	m4_bregexp(AC_PACKAGE_VERSION,[^rt-\(\w+\)\.\(\w+\)\.\(.+\)$],[\3]))
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

dnl BSD find uses -perm +xxxx, GNU find has deprecated this syntax in favour of
dnl -perm /xxx.
AC_MSG_CHECKING([checking version of find])
AS_IF([find --version 2>&1 | grep 'GNU'],
      [   FINDPERM="/"
          AC_MSG_RESULT([configuring for GNU find]) ],
      [   FINDPERM="+"
          AC_MSG_RESULT([configuring for BSD find]) ])

AC_SUBST([FINDPERM])

dnl WEB_HANDLER
AC_ARG_WITH(web-handler,
    AC_HELP_STRING([--with-web-handler=LIST],
	[comma separated list of web-handlers RT will be able to use.
         Default is fastcgi. Valid values are modperl1, modperl2, fastcgi and standalone.
         To successfully run RT you need only one.
        ]),
    WEB_HANDLER=$withval,
    WEB_HANDLER=fastcgi)
my_web_handler_test=$($PERL -e 'print "ok" unless grep $_ !~ /^(modperl1|modperl2|fastcgi|standalone)$/i, grep defined && length, split /\s*,\s*/, $ARGV@<:@0@:>@' $WEB_HANDLER)
if test "$my_web_handler_test" != "ok"; then
	AC_MSG_ERROR([Only modperl1, modperl2, fastcgi and standalone are valid web-handlers])
fi
AC_SUBST(WEB_HANDLER)

dnl Defaults paths for installation
AC_PREFIX_DEFAULT([/opt/rt4])
RT_ENABLE_LAYOUT


# ACRT_USER_EXISTS( users, variable, default )
# - users is a list of users [www apache www-docs]
#    from highest to lowest priority to high priority (i.e. first match)
# - variable is what you set with the result
#

AC_DEFUN([ACRT_USER_GUESS],
 [ 
   $2=$3
   for x in $1; do
    AC_MSG_CHECKING([if user $x exists]) 
     AS_IF([ $PERL -e"exit( defined getpwnam('$x') ? 0 : 1)" ],
           [ AC_MSG_RESULT([found]); $2=$x ; break],
           [ AC_MSG_RESULT([not found]) ])
   done
  ])
AC_DEFUN([ACRT_GROUP_GUESS],
 [ 
   $2=$3
   for x in $1; do
    AC_MSG_CHECKING([if group $x exists]) 
     AS_IF([ $PERL -e"exit( defined getgrnam('$x') ? 0 : 1)" ],
           [ AC_MSG_RESULT([found]); $2=$x ; break],
           [ AC_MSG_RESULT([not found]) ])
   done
  ])

dnl BIN_OWNER
AC_ARG_WITH(bin-owner,
	    AC_HELP_STRING([--with-bin-owner=OWNER],
	    		   [user that will own RT binaries (default root)]),
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
	    		   [group that will own RT binaries (default bin)]),
            LIBS_GROUP=$withval,
            LIBS_GROUP=bin)
AC_SUBST(LIBS_GROUP)

dnl DB_TYPE
AC_ARG_WITH(db-type,
	    AC_HELP_STRING([--with-db-type=TYPE],
	    		   [sort of database RT will use (default: mysql) (mysql, Pg, Oracle and SQLite are valid)]), 
            DB_TYPE=$withval,
            DB_TYPE=mysql)
if test "$DB_TYPE" != 'mysql' -a "$DB_TYPE" != 'Pg' -a "$DB_TYPE" != 'SQLite' -a "$DB_TYPE" != 'Oracle' ; then
	AC_MSG_ERROR([Only Oracle, Pg, mysql and SQLite are valid db types])
fi
AC_SUBST(DB_TYPE)

dnl DATABASE_ENV_PREF
if test "$DB_TYPE" = 'Oracle'; then
	test "x$ORACLE_HOME" = 'x' && AC_MSG_ERROR([Please declare the ORACLE_HOME environment variable])
	DATABASE_ENV_PREF="\$ENV{'ORACLE_HOME'} = '$ORACLE_HOME';"
fi

AC_SUBST(DATABASE_ENV_PREF)

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
if test "$DB_TYPE" = "Pg" ; then
        DB_DBA="postgres"
else
        DB_DBA="root"
fi
AC_ARG_WITH(db-dba,
	    AC_HELP_STRING([--with-db-dba=DBA],
	    		   [name of database administrator (default: root or postgres)]),
            DB_DBA=$withval,
            DB_DBA="$DB_DBA")
AC_SUBST(DB_DBA)

dnl DB_DATABASE
AC_ARG_WITH(db-database,
	    AC_HELP_STRING([--with-db-database=DBNAME],
	    		   [name of the database to use (default: rt4)]),
            DB_DATABASE=$withval,
            DB_DATABASE=rt4)
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
            ACRT_USER_GUESS([www www-data apache httpd nobody],[WEB_USER],[www])
)
AC_SUBST(WEB_USER)

dnl WEB_GROUP
AC_ARG_WITH(web-group,
	    AC_HELP_STRING([--with-web-group=GROUP],
		           [group the web server runs as (default: www)]),
            WEB_GROUP=$withval,
            ACRT_GROUP_GUESS([www www-data apache httpd nogroup nobody],[WEB_GROUP], [www]))
AC_SUBST(WEB_GROUP)

dnl RTGROUP
AC_ARG_WITH(rt-group,
	    AC_HELP_STRING([--with-rt-group=GROUP],
	    		   [group to own all files (default: rt)]),
            RTGROUP=$withval,
            ACRT_GROUP_GUESS([rt3 rt $WEB_GROUP],[RTGROUP], [rt]))
AC_SUBST(RTGROUP)

dnl INSTALL AS ME
my_group=$($PERL -MPOSIX=getgid -le 'print scalar getgrgid getgid')
my_user=${USER:-$LOGNAME}
AC_ARG_WITH(my-user-group,
            AC_HELP_STRING([--with-my-user-group],
                           [set all users and groups to current user/group]),
            RTGROUP=$my_group
            BIN_OWNER=$my_user
            LIBS_OWNER=$my_user
            LIBS_GROUP=$my_group
            WEB_USER=$my_user
            WEB_GROUP=$my_group)

# Test for valid database names
AC_MSG_CHECKING([if database name is set])
          AS_IF([ echo $DB_DATABASE | $PERL -e 'exit(1) unless <> =~ /\S/' ],
                [ AC_MSG_RESULT([yes]) ],
                [ AC_MSG_ERROR([no.  database name is not set]) ]
               )

dnl Dependencies for testing and developing RT
AC_ARG_WITH(developer,[],RT_DEVELOPER=$withval,RT_DEVELOPER="0")
AC_ARG_ENABLE(developer,
            AC_HELP_STRING([--enable-developer],
                           [Add dependencies needed for testing and developing RT]),
            RT_DEVELOPER=$enableval,
            RT_DEVELOPER=$RT_DEVELOPER)
if test "$RT_DEVELOPER" = yes; then
        RT_DEVELOPER="1"
else
        RT_DEVELOPER="0"
fi
AC_SUBST(RT_DEVELOPER)

dnl RT's GraphViz dependency charts
AC_CHECK_PROG([RT_GRAPHVIZ], [dot], "yes", "no")
AC_ARG_WITH(graphviz,[],RT_GRAPHVIZ=$withval)
AC_ARG_ENABLE(graphviz,
            AC_HELP_STRING([--enable-graphviz],
                           [Turns on support for RT's GraphViz dependency charts]),
            RT_GRAPHVIZ=$enableval)
if test "$RT_GRAPHVIZ" = yes; then
        RT_GRAPHVIZ="1"
else
        RT_GRAPHVIZ="0"
fi
AC_SUBST(RT_GRAPHVIZ)

dnl RT's GD pie and bar charts
AC_CHECK_PROG([RT_GD], [gdlib-config], "yes", "no")
AC_ARG_WITH(gd,[],RT_GD=$withval)
AC_ARG_ENABLE(gd,
            AC_HELP_STRING([--enable-gd],
                           [Turns on support for RT's GD pie and bar charts]),
            RT_GD=$enableval)
if test "$RT_GD" = yes; then
        RT_GD="1"
else
        RT_GD="0"
fi
AC_SUBST(RT_GD)

dnl RT's GPG support
AC_CHECK_PROG([RT_GPG_DEPS], [gpg], "yes", "no")
if test "$RT_GPG_DEPS" = yes; then
        RT_GPG_DEPS="1"
else
        RT_GPG_DEPS="0"
fi
AC_ARG_ENABLE(gpg,
            AC_HELP_STRING([--enable-gpg],
                           [Turns on GNU Privacy Guard (GPG) support]),
            RT_GPG=$enableval)
if test "$RT_GPG" = yes; then
        RT_GPG="1"
        RT_GPG_DEPS="1"
else
        if test "$RT_GPG" = no; then
                RT_GPG="0"
                RT_GPG_DEPS="0"
        else
                RT_GPG="0"
        fi
fi
AC_SUBST(RT_GPG_DEPS)
AC_SUBST(RT_GPG)


dnl RT's SMIME support
AC_CHECK_PROG([RT_SMIME_DEPS], [openssl], "yes", "no")
if test "$RT_SMIME_DEPS" = yes; then
        RT_SMIME_DEPS="1"
else
        RT_SMIME_DEPS="0"
fi
AC_ARG_ENABLE(smime,
            AC_HELP_STRING([--enable-smime],
                           [Turns on Secure MIME (SMIME) support]),
            RT_SMIME=$enableval)
if test "$RT_SMIME" = yes; then
        RT_SMIME="1"
        RT_SMIME_DEPS="1"
else
        if test "$RT_SMIME" = no; then
                RT_SMIME="0"
                RT_SMIME_DEPS="0"
        else
                RT_SMIME="0"
        fi
fi
AC_SUBST(RT_SMIME_DEPS)
AC_SUBST(RT_SMIME)

dnl Dependencies for external auth
AC_ARG_WITH(externalauth,[],RT_EXTERNALAUTH=$withval,RT_EXTERNALAUTH="0")
AC_ARG_ENABLE(externalauth,
            AC_HELP_STRING([--enable-externalauth],
                           [Add dependencies needed for external auth]),
            RT_EXTERNALAUTH=$enableval,
            RT_EXTERNALAUTH=$RT_EXTERNALAUTH)
if test "$RT_EXTERNALAUTH" = yes; then
        RT_EXTERNALAUTH="1"
else
        RT_EXTERNALAUTH="0"
fi
AC_SUBST(RT_EXTERNALAUTH)

dnl ExternalStorage
AC_ARG_WITH(attachment-store,
	    AC_HELP_STRING([--with-attachment-store=TYPE],
	    		   [which attachment storage RT will use for attachments (default: database) (database, disk, S3 and Dropbox are valid)]), 
            ATTACHMENT_STORE=$withval,
            ATTACHMENT_STORE=database)
if test "$ATTACHMENT_STORE" != 'database' -a "$ATTACHMENT_STORE" != 'disk' -a "$ATTACHMENT_STORE" != 'S3' -a "$ATTACHMENT_STORE" != 'Dropbox' ; then
	AC_MSG_ERROR([Only database, disk, S3 and Dropbox are valid db types])
fi
AC_SUBST(ATTACHMENT_STORE)

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
AC_SUBST([RT_LEXICON_PATH],			${exp_lexdir})
AC_SUBST([RT_STATIC_PATH],			${exp_staticdir})
AC_SUBST([RT_ETC_PATH],			${exp_sysconfdir})
AC_SUBST([CONFIG_FILE_PATH],		${exp_sysconfdir})
AC_SUBST([RT_BIN_PATH],			${exp_bindir})
AC_SUBST([RT_SBIN_PATH],		${exp_sbindir})
AC_SUBST([RT_VAR_PATH],			${exp_localstatedir})
AC_SUBST([RT_MAN_PATH],			${exp_mandir})
AC_SUBST([RT_FONT_PATH],			${exp_fontdir})
AC_SUBST([RT_PLUGIN_PATH],			${exp_plugindir})
AC_SUBST([MASON_DATA_PATH],		${exp_masonstatedir})
AC_SUBST([MASON_SESSION_PATH],		${exp_sessionstatedir})
AC_SUBST([MASON_HTML_PATH],		${exp_htmldir})
AC_SUBST([LOCAL_ETC_PATH],		${exp_custometcdir})
AC_SUBST([MASON_LOCAL_HTML_PATH],	${exp_customhtmldir})
AC_SUBST([LOCAL_LEXICON_PATH],		${exp_customlexdir})
AC_SUBST([LOCAL_STATIC_PATH],		${exp_customstaticdir})
AC_SUBST([LOCAL_LIB_PATH],		${exp_customlibdir})
AC_SUBST([LOCAL_PLUGIN_PATH],		${exp_customplugindir})
AC_SUBST([RT_LOG_PATH],			${exp_logfiledir})

if test ${exp_sysconfdir} = "etc" -o ${exp_sysconfdir} = "etc/rt"; then
AC_SUBST([RT_PATH_R],			${exp_prefix})
AC_SUBST([RT_DOC_PATH_R],			${exp_prefix}/${exp_manualdir})
AC_SUBST([RT_LOCAL_PATH_R],		${exp_prefix}/${exp_customdir})
AC_SUBST([RT_LIB_PATH_R],			${exp_prefix}/${exp_libdir})
AC_SUBST([RT_ETC_PATH_R],			${exp_prefix}/${exp_sysconfdir})
AC_SUBST([CONFIG_FILE_PATH_R],		${exp_prefix}/${exp_sysconfdir})
AC_SUBST([RT_BIN_PATH_R],			${exp_prefix}/${exp_bindir})
AC_SUBST([RT_SBIN_PATH_R],		${exp_prefix}/${exp_sbindir})
AC_SUBST([RT_VAR_PATH_R],			${exp_prefix}/${exp_localstatedir})
AC_SUBST([RT_MAN_PATH_R],			${exp_prefix}/${exp_mandir})
AC_SUBST([RT_FONT_PATH_R],			${exp_prefix}/${exp_fontdir})
AC_SUBST([RT_LEXICON_PATH_R],			${exp_prefix}/${exp_lexdir})
AC_SUBST([RT_STATIC_PATH_R],			${exp_prefix}/${exp_staticdir})
AC_SUBST([RT_PLUGIN_PATH_R],		${exp_prefix}/${exp_plugindir})
AC_SUBST([MASON_DATA_PATH_R],		${exp_prefix}/${exp_masonstatedir})
AC_SUBST([MASON_SESSION_PATH_R],		${exp_prefix}/${exp_sessionstatedir})
AC_SUBST([MASON_HTML_PATH_R],		${exp_prefix}/${exp_htmldir})
AC_SUBST([LOCAL_ETC_PATH_R],		${exp_prefix}/${exp_custometcdir})
AC_SUBST([MASON_LOCAL_HTML_PATH_R],	${exp_prefix}/${exp_customhtmldir})
AC_SUBST([LOCAL_LEXICON_PATH_R],		${exp_prefix}/${exp_customlexdir})
AC_SUBST([LOCAL_STATIC_PATH_R],		${exp_prefix}/${exp_customstaticdir})
AC_SUBST([LOCAL_LIB_PATH_R],		${exp_prefix}/${exp_customlibdir})
AC_SUBST([LOCAL_PLUGIN_PATH_R],		${exp_prefix}/${exp_customplugindir})
AC_SUBST([RT_LOG_PATH_R],			${exp_prefix}/${exp_logfiledir})
else
AC_SUBST([RT_PATH_R],			${exp_prefix})
AC_SUBST([RT_DOC_PATH_R],			${exp_manualdir})
AC_SUBST([RT_LOCAL_PATH_R],		${exp_customdir})
AC_SUBST([RT_LIB_PATH_R],			${exp_libdir})
AC_SUBST([RT_LEXICON_PATH_R],			${exp_lexdir})
AC_SUBST([RT_STATIC_PATH_R],			${exp_staticdir})
AC_SUBST([RT_ETC_PATH_R],			${exp_sysconfdir})
AC_SUBST([RT_PLUGIN_PATH_R],		${exp_plugindir})
AC_SUBST([CONFIG_FILE_PATH_R],		${exp_sysconfdir})
AC_SUBST([RT_BIN_PATH_R],			${exp_bindir})
AC_SUBST([RT_SBIN_PATH_R],		${exp_sbindir})
AC_SUBST([RT_VAR_PATH_R],			${exp_localstatedir})
AC_SUBST([RT_MAN_PATH_R],			${exp_mandir})
AC_SUBST([RT_FONT_PATH_R],			${exp_fontdir})
AC_SUBST([MASON_DATA_PATH_R],		${exp_masonstatedir})
AC_SUBST([MASON_SESSION_PATH_R],		${exp_sessionstatedir})
AC_SUBST([MASON_HTML_PATH_R],		${exp_htmldir})
AC_SUBST([LOCAL_ETC_PATH_R],		${exp_custometcdir})
AC_SUBST([MASON_LOCAL_HTML_PATH_R],	${exp_customhtmldir})
AC_SUBST([LOCAL_LEXICON_PATH_R],		${exp_customlexdir})
AC_SUBST([LOCAL_STATIC_PATH_R],		${exp_customstaticdir})
AC_SUBST([LOCAL_PLUGIN_PATH_R],		${exp_customplugindir})
AC_SUBST([LOCAL_LIB_PATH_R],		${exp_customlibdir})
AC_SUBST([RT_LOG_PATH_R],			${exp_logfiledir})

fi

dnl Configure the output files, and generate them.

dnl Binaries that should be +x
AC_CONFIG_FILES([
                 etc/upgrade/3.8-ical-extension
                 etc/upgrade/4.0-customfield-checkbox-extension
                 etc/upgrade/generate-rtaddressregexp
                 etc/upgrade/sanity-check-stylesheets
                 etc/upgrade/shrink-cgm-table
                 etc/upgrade/shrink-transactions-table
                 etc/upgrade/switch-templates-to
                 etc/upgrade/time-worked-history
                 etc/upgrade/upgrade-articles
                 etc/upgrade/upgrade-assets
                 etc/upgrade/vulnerable-passwords
                 etc/upgrade/upgrade-sla
                 sbin/rt-ldapimport
                 sbin/rt-attributes-viewer
                 sbin/rt-preferences-viewer
                 sbin/rt-session-viewer
                 sbin/rt-dump-metadata
                 sbin/rt-setup-database
                 sbin/rt-test-dependencies
                 sbin/rt-email-digest
                 sbin/rt-email-dashboards
                 sbin/rt-externalize-attachments
                 sbin/rt-clean-sessions
                 sbin/rt-shredder
                 sbin/rt-validator
                 sbin/rt-validate-aliases
                 sbin/rt-email-group-admin
                 sbin/rt-server
                 sbin/rt-server.fcgi
                 sbin/standalone_httpd
                 sbin/rt-setup-fulltext-index
                 sbin/rt-fulltext-indexer
                 sbin/rt-serializer
                 sbin/rt-importer
                 sbin/rt-passwd
                 bin/rt-crontool
                 bin/rt-mailgate
                 bin/rt],
                [chmod ug+x $ac_file]
               )

dnl All other generated files
AC_CONFIG_FILES([
                 Makefile
                 etc/RT_Config.pm
                 lib/RT/Generated.pm
                 t/data/configs/apache2.2+mod_perl.conf
                 t/data/configs/apache2.2+fastcgi.conf
                 t/data/configs/apache2.4+mod_perl.conf
                 t/data/configs/apache2.4+fastcgi.conf],
               )
AC_OUTPUT
