# $Header$
# Request Tracker is Copyright 1996-2001 Jesse Vincent <jessebestpractical.com>
# RT is distributed under the terms of the GNU General Public License, version 2

PERL			= 	/usr/bin/perl

RT_VERSION_MAJOR	=	2
RT_VERSION_MINOR	=	0
RT_VERSION_PATCH	=	9pre6


RT_VERSION =	$(RT_VERSION_MAJOR).$(RT_VERSION_MINOR).$(RT_VERSION_PATCH)
TAG 	   =	rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)

BRANCH			=	HEAD


RTGROUP			=	rt



# User which should own rt binaries
BIN_OWNER		=	root

# User that should own all of RT's libraries. generally root.
LIBS_OWNER 		=	root

# Group that should own all of RT's libraries. generally root.
LIBS_GROUP		=	bin



# {{{ Files and directories 

# DESTDIR allows you to specify that RT be installed somewhere other than
# where it will eventually reside

DESTDIR			=	


# RT_PATH is the name of the directory you want make to install RT in
# RT must be installed in its own directory (don't set this to /usr/local)

RT_PATH			=	/opt/rt2

# The rest of these paths are all configurable, but you probably don't want to 
# put them elsewhere

RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
RT_MAN_PATH		=	$(RT_PATH)/man
MASON_HTML_PATH		=	$(RT_PATH)/WebRT/html


# RT allows sites to overlay the default web ui with 
# local customizations Those files can be placed in MASON_LOCAL_HTML_PATH

MASON_LOCAL_HTML_PATH	=	$(RT_PATH)/local/WebRT/html

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
# THIS HANDLER IS NOT CURRENTLY SUPPORTED
RT_FASTCGI_HANDLER		=	$(RT_BIN_PATH)/mason_handler.fcgi

# RT_SPEEDYCGI_HANDLER is the mason handler script for SpeedyCGI
# THIS HANDLER IS NOT CURRENTLY SUPPORTED
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

# If you're not running your database server on its default port, 
# specifiy the port the database server is running on below.
# It's generally safe to leave this blank 

DB_PORT		=	

#
# Set this to the canonical name of the interface RT will be talking to the 
# database on. # If you said that the RT_DB_HOST above was "localhost," this 
# should be too. This value will be used to grant rt access to the database.
# If you want to access the RT database from multiple hosts, you'll need
# to grant those database rights by hand.
#

DB_RT_HOST	=	localhost

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

upgrade: dirs config-replace upgrade-noclobber 

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
	chmod -R $(RT_READABLE_DIR_MODE) $(DESTDIR)/$(RT_PATH)
	chown -R $(LIBS_OWNER) $(DESTDIR)/$(RT_LIB_PATH)
	chgrp -R $(LIBS_GROUP) $(DESTDIR)/$(RT_LIB_PATH)

	chown -R $(BIN_OWNER) $(DESTDIR)/$(RT_BIN_PATH)
	chgrp -R $(RTGROUP) $(DESTDIR)/$(RT_BIN_PATH)


	chmod $(RT_READABLE_DIR_MODE) $(DESTDIR)/$(RT_BIN_PATH)
	chmod $(RT_READABLE_DIR_MODE) $(DESTDIR)/$(RT_BIN_PATH)	

	chmod 0755 $(DESTDIR)/$(RT_ETC_PATH)
	chmod 0500 $(DESTDIR)/$(RT_ETC_PATH)/*

	#TODO: the config file should probably be able to have its
	# owner set seperately from the binaries.
	chown -R $(BIN_OWNER) $(DESTDIR)/$(RT_ETC_PATH)
	chgrp -R $(RTGROUP) $(DESTDIR)/$(RT_ETC_PATH)

	chmod 0550 $(DESTDIR)/$(RT_CONFIG)

	# Make the interfaces executable and setgid rt
	chown $(BIN_OWNER) $(DESTDIR)/$(RT_MAILGATE_BIN) \
			$(DESTDIR)/$(RT_FASTCGI_HANDLER) \
			$(DESTDIR)/$(RT_SPEEDYCGI_HANDLER) \
			$(DESTDIR)/$(RT_CLI_BIN) \
			$(DESTDIR)/$(RT_CLI_ADMIN_BIN)

	chgrp $(RTGROUP) $(DESTDIR)/$(RT_MAILGATE_BIN) \
			$(DESTDIR)/$(RT_FASTCGI_HANDLER) \
			$(DESTDIR)/$(RT_SPEEDYCGI_HANDLER) \
			$(DESTDIR)/$(RT_CLI_BIN) \
			$(DESTDIR)/$(RT_CLI_ADMIN_BIN)

	chmod 0755  	$(DESTDIR)/$(RT_MAILGATE_BIN) \
			$(DESTDIR)/$(RT_FASTCGI_HANDLER) \
			$(DESTDIR)/$(RT_SPEEDYCGI_HANDLER) \
			$(DESTDIR)/$(RT_CLI_BIN) \
			$(DESTDIR)/$(RT_CLI_ADMIN_BIN)

	chmod g+s 	$(DESTDIR)/$(RT_MAILGATE_BIN) \
			$(DESTDIR)/$(RT_FASTCGI_HANDLER) \
			$(DESTDIR)/$(RT_SPEEDYCGI_HANDLER) \
			$(DESTDIR)/$(RT_CLI_BIN) \
			$(DESTDIR)/$(RT_CLI_ADMIN_BIN)

	# Make the web ui readable by all. 
	chmod -R  u+rwX,go-w,go+rX 	$(DESTDIR)/$(MASON_HTML_PATH) \
					$(DESTDIR)/$(MASON_LOCAL_HTML_PATH)
	chown -R $(LIBS_OWNER) 	$(DESTDIR)/$(MASON_HTML_PATH) \
				$(DESTDIR)/$(MASON_LOCAL_HTML_PATH)
	chgrp -R $(LIBS_GROUP) 	$(DESTDIR)/$(MASON_HTML_PATH) \
				$(DESTDIR)/$(MASON_LOCAL_HTML_PATH)

	# Make the web ui's data dir writable
	chmod 0770  	$(DESTDIR)/$(MASON_DATA_PATH) \
			$(DESTDIR)/$(MASON_SESSION_PATH)
	chown -R $(WEB_USER) 	$(DESTDIR)/$(MASON_DATA_PATH) \
				$(DESTDIR)/$(MASON_SESSION_PATH)
	chgrp -R $(WEB_GROUP) 	$(DESTDIR)/$(MASON_DATA_PATH) \
				$(DESTDIR)/$(MASON_SESSION_PATH)
dirs:
	mkdir -p $(DESTDIR)/$(RT_BIN_PATH)
	mkdir -p $(DESTDIR)/$(MASON_DATA_PATH)
	mkdir -p $(DESTDIR)/$(MASON_SESSION_PATH)
	mkdir -p $(DESTDIR)/$(RT_ETC_PATH)
	mkdir -p $(DESTDIR)/$(RT_LIB_PATH)
	mkdir -p $(DESTDIR)/$(MASON_HTML_PATH)
	mkdir -p $(DESTDIR)/$(MASON_LOCAL_HTML_PATH)

libs-install: 
	[ -d $(DESTDIR)/$(RT_LIB_PATH) ] || mkdir $(DESTDIR)/$(RT_LIB_PATH)
	chown -R $(LIBS_OWNER) $(DESTDIR)/$(RT_LIB_PATH)
	chgrp -R $(LIBS_GROUP) $(DESTDIR)/$(RT_LIB_PATH)
	chmod -R $(RT_READABLE_DIR_MODE) $(DESTDIR)/$(RT_LIB_PATH)
	( cd ./lib; \
	  $(PERL) Makefile.PL INSTALLSITELIB=$(DESTDIR)/$(RT_LIB_PATH) \
			      INSTALLMAN1DIR=$(DESTDIR)/$(RT_MAN_PATH)/man1 \
			      INSTALLMAN3DIR=$(DESTDIR)/$(RT_MAN_PATH)/man3 \
	    && make \
	    && make test \
	    && $(PERL) -p -i -e " s'!!RT_VERSION!!'$(RT_VERSION)'g;" blib/lib/RT.pm ;\
	    make install \
			   INSTALLSITEMAN1DIR=$(DESTDIR)/$(RT_MAN_PATH)/man1 \
			   INSTALLSITEMAN3DIR=$(DESTDIR)/$(RT_MAN_PATH)/man3 \
	)

html-install:
	cp -rp ./webrt/* $(DESTDIR)/$(MASON_HTML_PATH)



genschema:
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_PORT)' '$(DB_DBA)' '$(DB_DATABASE)' generate


initialize.Pg: createdb initdb.dba acls 

initialize.mysql: createdb acls initdb.rtuser

initialize.Oracle: acls initdb.rtuser

acls:
	cp etc/acl.$(DB_TYPE) '$(DESTDIR)/$(RT_ETC_PATH)/acl.$(DB_TYPE)'
	$(PERL) -p -i -e " s'!!DB_TYPE!!'"$(DB_TYPE)"'g;\
				s'!!DB_HOST!!'"$(DB_HOST)"'g;\
				s'!!DB_RT_PASS!!'"$(DB_RT_PASS)"'g;\
				s'!!DB_RT_HOST!!'"$(DB_RT_HOST)"'g;\
				s'!!DB_RT_USER!!'"$(DB_RT_USER)"'g;\
				s'!!DB_DATABASE!!'"$(DB_DATABASE)"'g;" $(DESTDIR)/$(RT_ETC_PATH)/acl.$(DB_TYPE)
	bin/initacls.$(DB_TYPE) '$(DB_HOME)' '$(DB_HOST)' '$(DB_PORT)' '$(DB_DBA)' '$(DB_DBA_PASSWORD)' '$(DB_DATABASE)' '$(DESTDIR)/$(RT_ETC_PATH)/acl.$(DB_TYPE)' 



dropdb: 
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_PORT)' '$(DB_DBA)' '$(DB_DATABASE)' drop


createdb: 
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_PORT)' '$(DB_DBA)' '$(DB_DATABASE)' create
initdb.dba:
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_PORT)' '$(DB_DBA)' '$(DB_DATABASE)' insert

initdb.rtuser:
	$(PERL)	tools/initdb '$(DB_TYPE)' '$(DB_HOME)' '$(DB_HOST)' '$(DB_PORT)' '$(DB_RT_USER)' '$(DB_DATABASE)' insert



insert-install:
	cp -rp ./tools/insertdata \
		 $(DESTDIR)/$(RT_ETC_PATH)
	$(PERL) -p -i -e " s'!!RT_ETC_PATH!!'$(RT_ETC_PATH)'g;\
		           s'!!RT_LIB_PATH!!'$(RT_LIB_PATH)'g;"\
		$(DESTDIR)/$(RT_ETC_PATH)/insertdata

bin-install:
	cp -p ./bin/webmux.pl $(DESTDIR)/$(RT_MODPERL_HANDLER)
	cp -p ./bin/rt-mailgate $(DESTDIR)/$(RT_MAILGATE_BIN)
	cp -p ./bin/rtadmin $(DESTDIR)/$(RT_CLI_ADMIN_BIN)
	cp -p ./bin/rt $(DESTDIR)/$(RT_CLI_BIN)
	cp -p ./bin/mason_handler.fcgi $(DESTDIR)/$(RT_FASTCGI_HANDLER)
	cp -p ./bin/mason_handler.scgi $(DESTDIR)/$(RT_SPEEDYCGI_HANDLER)

	$(PERL) -p -i -e "s'!!RT_PATH!!'"$(RT_PATH)"'g;\
				s'!!PERL!!'"$(PERL)"'g;\
			      	s'!!RT_VERSION!!'"$(RT_VERSION)"'g;\
				s'!!RT_ETC_PATH!!'"$(RT_ETC_PATH)"'g;\
				s'!!RT_LIB_PATH!!'"$(RT_LIB_PATH)"'g;"\
		$(DESTDIR)/$(RT_MODPERL_HANDLER) \
		$(DESTDIR)/$(RT_FASTCGI_HANDLER) \
		$(DESTDIR)/$(RT_SPEEDYCGI_HANDLER) \
		$(DESTDIR)/$(RT_CLI_BIN) \
		$(DESTDIR)/$(RT_CLI_ADMIN_BIN) \
		$(DESTDIR)/$(RT_MAILGATE_BIN)


config-replace:
	-[ -f $(DESTDIR)/$(RT_CONFIG) ] && \
		mv $(DESTDIR)/$(RT_CONFIG) $(DESTDIR)/$(RT_CONFIG).old && \
	 	chmod 000 $(DESTDIR)/$(RT_CONFIG).old
	cp -rp ./etc/config.pm $(DESTDIR)/$(RT_CONFIG)
	$(PERL) -p -i -e "\
	s'!!DB_TYPE!!'"$(DB_TYPE)"'g;\
	s'!!DB_HOST!!'"$(DB_HOST)"'g;\
	s'!!DB_PORT!!'"$(DB_PORT)"'g;\
	s'!!DB_RT_PASS!!'"$(DB_RT_PASS)"'g;\
	s'!!DB_RT_USER!!'"$(DB_RT_USER)"'g;\
	s'!!DB_DATABASE!!'"$(DB_DATABASE)"'g;\
	s'!!MASON_HTML_PATH!!'"$(MASON_HTML_PATH)"'g;\
	s'!!MASON_LOCAL_HTML_PATH!!'"$(MASON_LOCAL_HTML_PATH)"'g;\
	s'!!MASON_SESSION_PATH!!'"$(MASON_SESSION_PATH)"'g;\
	s'!!MASON_DATA_PATH!!'"$(MASON_DATA_PATH)"'g;\
	s'!!RT_LOG_PATH!!'"$(RT_LOG_PATH)"'g;\
	s'!!RT_VERSION!!'"$(RT_VERSION)"'g;\
	" $(DESTDIR)/$(RT_CONFIG)


commit:
	cvs commit

predist: commit
	cvs tag -r $(BRANCH) -F $(TAG)
	rm -rf /tmp/$(TAG)
	cvs co -D now -d /tmp/$(TAG) -r $(BRANCH) rt
	cd /tmp/$(TAG); chmod 600 Makefile; /usr/local/bin/cvs2cl.pl \
		--no-wrap --follow $(BRANCH) --separate-header \
		--window 120
	cd /tmp; tar czvf /home/ftp/pub/rt/devel/$(TAG).tar.gz $(TAG)/
	chmod 644 /home/ftp/pub/rt/devel/$(TAG).tar.gz

dist: commit predist
	rm -rf /home/ftp/pub/rt/devel/rt.tar.gz
	ln -s ./$(TAG).tar.gz /home/ftp/pub/rt/devel/rt.tar.gz


rpm:
	(cd ..; tar czvf /usr/src/redhat/SOURCES/rt.tar.gz rt)
	rpm -ba etc/rt.spec
