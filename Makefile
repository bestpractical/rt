# $Header$
# Request Tracker is Copyright 1996-2001 Jesse Vincent <jesse@fsck.com>
# RT is distributed under the terms of the GNU General Public License

PERL			= 	/usr/bin/perl

RT_VERSION_MAJOR	=	1
RT_VERSION_MINOR	=	3
RT_VERSION_PATCH	=	90


RT_VERSION =	$(RT_VERSION_MAJOR).$(RT_VERSION_MINOR).$(RT_VERSION_PATCH)
TAG 	   =	rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)

RTGROUP			=	rt



# User which should own rt binaries
BIN_OWNER		=	root

# User that should own all of RT's libraries. generally root.
LIBS_OWNER 		=	root

# Group that should own all of RT's libraries. generally root.
LIBS_GROUP		=	bin



# {{{ Files and directories 

# RT_PATH is the name of the directory you want make to install RT in
# RT must be installed in its own directory (don't set this to /usr/local)

RT_PATH			=	/opt/rt2

# The rest of these paths are all configurable, but you probably don't want to 
# put them elsewhere

RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
MASON_HTML_PATH		=	$(RT_PATH)/WebRT/html

# RT needs to be able to write to MASON_DATA_PATH and MASON_SESSION_PATH
# RT will create and chown these directories. Don't just set them to /tmp
MASON_DATA_PATH		=       $(RT_PATH)/WebRT/data
MASON_SESSION_PATH	=       $(RT_PATH)/WebRT/sessiondata

RT_LOG_PATH             =       /tmp

# RT_READABLE_DIR_MODE is the mode of directories that are generally meant to be
# accessable
RT_READABLE_DIR_MODE	=	0755



# The location of your rt configuration file
RT_CONFIG		=	$(RT_ETC_PATH)/config.pm

# RT_MODPERL_HANDLER is the mason handler script for mod_perl
RT_MODPERL_HANDLER		=	$(RT_BIN_PATH)/webmux.pl

# RT_FASTCGI_HANDLER is the mason handler script for FastCGI
RT_FASTCGI_HANDLER		=	$(RT_BIN_PATH)/mason_handler.fcgi

# RT_SPEEDYCGI_HANDLER is the mason handler scropt for SpeedyCGI
RT_SPEEDYCGI_HANDLER		=	$(RT_BIN_PATH)/mason_handler.scgi

# The following are the names of the various binaries which make up RT 

RT_CLI_BIN		=	$(RT_BIN_PATH)/rt
RT_CLI_ADMIN_BIN	=	$(RT_BIN_PATH)/rtadmin
RT_MAILGATE_BIN		=	$(RT_BIN_PATH)/rt-mailgate

# }}}

# {{{ Database setup

#
# DB_TYPE defines what sort of database RT trys to talk to
# "mysql" is known to work.
# "Pg" is known to work
# "Oracle" is in the early stages of working.


DB_TYPE	        =	mysql

# DB_HOME is where the Database's commandline tools live
# Note: $DB_HOME/bin is where the database binary tools are installed.
 
DB_HOME	      	= /usr

# Set DBA to the name of a unix account with the proper permissions and 
# environment to run your commandline SQL tools

# Set DB_DBA to the name of a DB user with permission to create new databases 
# Set DB_DBA_PASSWORD to that user's password (if you don't, you'll be prompted
# later)

# For mysql, you probably want 'root'
# For Pg, you probably want 'postgres' 
# For oracle, you want 'system'

DB_DBA	           =	root
DB_DBA_PASSWORD	  =	
 
#
# Set this to the Fully Qualified Domain Name of your database server.
# If the database is local, rather than on a remote host, using "localhost" 
# will greatly enhance performance.

DB_HOST		=	localhost

#
# Set this to the canonical name of the interface RT will be talking to the 
# database on. # If you said that the RT_DB_HOST above was "localhost," this 
# should be too. This value will be used to grant rt access to the database.
# If you want to access the RT database from multiple hosts, you'll need
# to grant those database rights by hand.
#

DB_RT_HOST			=	localhost

# set this to the name you want to give to the RT database in 
# your database server. For Oracle, this should be the name of your sid

DB_DATABASE	=	rt2

# Set this to the name of the rt database user

DB_RT_USER	=	rt_user

# Set this to the password used by the rt database user
# *** Change This Before Installation***

DB_RT_PASS      =      rt_pass

# }}}

# {{{ Web configuration 

# The user your webserver runs as. needed so that webrt can cache mason
# objectcode

WEB_USER			=	www-data
WEB_GROUP			=	rt

# }}}


####################################################################
# No user servicable parts below this line.  Frob at your own risk #
####################################################################

default:
	@echo "Please read RT's readme before installing. Not doing so could"
	@echo "be dangerous."

install: dirs initialize.$(DB_TYPE) upgrade insert instruct

instruct:
	@echo "Congratulations. RT has been installed. "
	@echo "You must now configure it by editing $(RT_CONFIG)."
	@echo "From here on in, you should refer to the users guide."

insert: insert-install
	$(PERL) $(RT_ETC_PATH)/insertdata

upgrade: config-replace upgrade-noclobber

upgrade-noclobber: libs-install html-install bin-install nondestruct

nondestruct: fixperms

testdeps:
	$(PERL) ./tools/testdeps -warn $(DB_TYPE)

fixdeps:
	$(PERL) ./tools/testdeps -fix $(DB_TYPE)



all:
	@echo "Read the readme."

fixperms:
	# Make the libraries readable
	chmod -R $(RT_READABLE_DIR_MODE) $(RT_PATH)
	chown -R $(LIBS_OWNER) $(RT_LIB_PATH)
	chgrp -R $(LIBS_GROUP) $(RT_LIB_PATH)

	chown -R $(BIN_OWNER) $(RT_BIN_PATH)
	chgrp -R $(RTGROUP) $(RT_BIN_PATH)


	chmod $(RT_READABLE_DIR_MODE) $(RT_BIN_PATH)
	chmod $(RT_READABLE_DIR_MODE) $(RT_BIN_PATH)	

	chmod 0555 $(RT_ETC_PATH)
	chmod 0500 $(RT_ETC_PATH)/*

	#TODO: the config file should probably be able to have its
	# owner set seperately from the binaries.
	chown -R $(BIN_OWNER) $(RT_ETC_PATH)
	chgrp -R $(RTGROUP) $(RT_ETC_PATH)

	chmod 0550 $(RT_CONFIG)

	# Make the interfaces executable and setgid rt
	chown $(BIN_OWNER) $(RT_MAILGATE_BIN) $(RT_FASTCGI_HANDLER) \
		$(RT_SPEEDYCGI_HANDLER) $(RT_CLI_BIN) $(RT_CLI_ADMIN_BIN)

	chgrp $(RTGROUP) $(RT_MAILGATE_BIN) $(RT_FASTCGI_HANDLER) \
		$(RT_SPEEDYCGI_HANDLER) $(RT_CLI_BIN) $(RT_CLI_ADMIN_BIN)

	chmod 0755  $(RT_MAILGATE_BIN) $(RT_FASTCGI_HANDLER) \
		$(RT_SPEEDYCGI_HANDLER) $(RT_CLI_BIN) $(RT_CLI_ADMIN_BIN)

	chmod g+s $(RT_MAILGATE_BIN) $(RT_FASTCGI_HANDLER) \
		$(RT_SPEEDYCGI_HANDLER) $(RT_CLI_BIN) $(RT_CLI_ADMIN_BIN)

	# Make the web ui readable by all. 
	chmod -R  u+rwX,go-w,go+rX $(MASON_HTML_PATH)
	chown -R $(LIBS_OWNER) $(MASON_HTML_PATH)
	chgrp -R $(LIBS_GROUP) $(MASON_HTML_PATH)

	# Make the web ui's data dir writable
	chmod 0700  $(MASON_DATA_PATH) $(MASON_SESSION_PATH)
	chown -R $(WEB_USER) $(MASON_DATA_PATH) $(MASON_SESSION_PATH)
	chgrp -R $(WEB_GROUP) $(MASON_DATA_PATH) $(MASON_SESSION_PATH)
dirs:
	mkdir -p $(RT_BIN_PATH)
	mkdir -p $(MASON_DATA_PATH)
	mkdir -p $(MASON_SESSION_PATH)
	mkdir -p $(RT_ETC_PATH)
	mkdir -p $(RT_LIB_PATH)
	mkdir -p $(MASON_HTML_PATH)

libs-install: 
	[ -d $(RT_LIB_PATH) ] || mkdir $(RT_LIB_PATH)
	chown -R $(LIBS_OWNER) $(RT_LIB_PATH)
	chgrp -R $(LIBS_GROUP) $(RT_LIB_PATH)
	chmod -R $(RT_READABLE_DIR_MODE) $(RT_LIB_PATH)
	( cd ./lib; \
	  $(PERL) Makefile.PL LIB=$(RT_LIB_PATH) \
	    && make \
	    && make test \
	    && $(PERL) -p -i -e " s'!!RT_VERSION!!'$(RT_VERSION)'g;" blib/lib/RT.pm ;\
	    make install \
	)

html-install:
	cp -rp ./webrt/* $(MASON_HTML_PATH)



genschema:
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DATABASE)' generate


initialize.Pg: createdb initdb.dba acls 

initialize.mysql: createdb acls initdb.rtuser

initialize.Oracle: acls initdb.rtuser

acls:
	cp etc/acl.$(DB_TYPE) '$(RT_ETC_PATH)/acl.$(DB_TYPE)'
	$(PERL) -p -i -e " s'!!DB_TYPE!!'$(DB_TYPE)'g;\
				s'!!DB_HOST!!'$(DB_HOST)'g;\
				s'!!DB_RT_PASS!!'$(DB_RT_PASS)'g;\
				s'!!DB_RT_HOST!!'$(DB_RT_HOST)'g;\
				s'!!DB_RT_USER!!'$(DB_RT_USER)'g;\
				s'!!DB_DATABASE!!'$(DB_DATABASE)'g;" $(RT_ETC_PATH)/acl.$(DB_TYPE)
	bin/initacls.$(DB_TYPE) '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DBA_PASSWORD)' '$(DB_DATABASE)' '$(RT_ETC_PATH)/acl.$(DB_TYPE)' 



dropdb: 
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DATABASE)' drop


createdb: 
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DATABASE)' create
initdb.dba:
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DATABASE)' insert

initdb.rtuser:
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_RT_USER)' '$(DB_DATABASE)' insert



insert-install:
	cp -rp ./tools/import-1.0-to-2.0 ./tools/insertdata\
		 $(RT_ETC_PATH)
	$(PERL) -p -i -e " s'!!RT_ETC_PATH!!'$(RT_ETC_PATH)'g;\
		           s'!!RT_LIB_PATH!!'$(RT_LIB_PATH)'g;"\
		$(RT_ETC_PATH)/insertdata $(RT_ETC_PATH)/import-1.0-to-2.0

bin-install:
	cp -p ./bin/webmux.pl $(RT_MODPERL_HANDLER)
	cp -p ./bin/rt-mailgate $(RT_MAILGATE_BIN)
	cp -p ./bin/rtadmin $(RT_CLI_ADMIN_BIN)
	cp -p ./bin/rt $(RT_CLI_BIN)
	cp -p ./bin/mason_handler.fcgi $(RT_FASTCGI_HANDLER)
	cp -p ./bin/mason_handler.scgi $(RT_SPEEDYCGI_HANDLER)

	$(PERL) -p -i -e "s'!!RT_PATH!!'$(RT_PATH)'g;\
				s'!!PERL!!'$(PERL)'g;\
			      	s'!!RT_VERSION!!'$(RT_VERSION)'g;\
				s'!!RT_ETC_PATH!!'$(RT_ETC_PATH)'g;\
				s'!!RT_LIB_PATH!!'$(RT_LIB_PATH)'g;"\
		$(RT_MODPERL_HANDLER) $(RT_FASTCGI_HANDLER) \
		$(RT_SPEEDYCGI_HANDLER) $(RT_CLI_BIN) $(RT_CLI_ADMIN_BIN) \
		$(RT_MAILGATE_BIN)


config-replace:
	-[ -f $(RT_CONFIG) ] && mv $(RT_CONFIG) $(RT_CONFIG).old && \
	 chmod 000 $(RT_CONFIG).old
	cp -rp ./etc/config.pm $(RT_CONFIG)
	$(PERL) -p -i -e "\
	s'!!DB_TYPE!!'$(DB_TYPE)'g;\
	s'!!DB_HOST!!'$(DB_HOST)'g;\
	s'!!DB_RT_PASS!!'$(DB_RT_PASS)'g;\
	s'!!DB_RT_USER!!'$(DB_RT_USER)'g;\
	s'!!DB_DATABASE!!'$(DB_DATABASE)'g;\
	s'!!MASON_HTML_PATH!!'$(MASON_HTML_PATH)'g;\
	s'!!MASON_SESSION_PATH!!'$(MASON_SESSION_PATH)'g;\
	s'!!MASON_DATA_PATH!!'$(MASON_DATA_PATH)'g;\
	s'!!RT_LOG_PATH!!'$(RT_LOG_PATH)'g;\
	s'!!RT_VERSION!!'$(RT_VERSION)'g;\
	" $(RT_CONFIG)


commit:
	cvs commit

predist: commit
	cvs tag -r rt-1-1 -F $(TAG)
	rm -rf /tmp/$(TAG)
	cvs co -D now -d /tmp/$(TAG) -r rt-1-1 rt
	cd /tmp/$(TAG); chmod 600 Makefile; /usr/local/bin/cvs2cl.pl \
		--no-wrap --follow rt-1-1 --separate-header \
		--window 120
	cd /tmp; tar czvf /home/ftp/pub/rt/devel/$(TAG).tar.gz $(TAG)/
	chmod 644 /home/ftp/pub/rt/devel/$(TAG).tar.gz

dist: commit predist
	rm -rf /home/ftp/pub/rt/devel/rt.tar.gz
	ln -s ./$(TAG).tar.gz /home/ftp/pub/rt/devel/rt.tar.gz
