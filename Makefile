# $Header$
# Request Tracker is Copyright 1996-2000 Jesse Vincent <jesse@fsck.com>
# RT is distributed under the terms of the GNU General Public License

PERL			= 	/usr/bin/perl

RT_VERSION_MAJOR	=	1
RT_VERSION_MINOR	=	3
RT_VERSION_PATCH	=	16

RT_VERSION =	$(RT_VERSION_MAJOR).$(RT_VERSION_MINOR).$(RT_VERSION_PATCH)
TAG 	   =	rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)

RTUSER			=	rt
RTGROUP			=	rt


# {{{ Files and directories 

# RT_PATH is the name of the directory you want make to install RT in
# RT must be installed in its own directory (don't set this to /usr/local)

RT_PATH			=	/opt/rt-1.3

# The rest of these paths are all configurable, but you probably don't want to 
# put them elsewhere

RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
WEBRT_HTML_PATH		=	$(RT_PATH)/WebRT/html
WEBRT_DATA_PATH		=       $(RT_PATH)/WebRT/data

# The location of your rt configuration file
RT_CONFIG		=	$(RT_ETC_PATH)/config.pm

# The rtmux is the script which invokes whichever rt program it needs to.
RT_PERL_MUX		=	$(RT_BIN_PATH)/rtmux.pl

# RT_WEB_MUX is the mason handler script for apache 
RT_WEB_MUX		=	$(RT_BIN_PATH)/webmux.pl

# The following are the names of the various binaries which make up RT 

RT_ACTION_BIN		=	rt
RT_QUERY_BIN		=	rtq
RT_ADMIN_BIN		=	rtadmin
RT_MAILGATE_BIN		=	rt-mailgate
RT_CGI_BIN		=	webrt.cgi

# }}}

# {{{ Database setup
#
# DB_TYPE defines what sort of database RT trys to talk to
# "mysql" is known to work.
# "Pg" gets you the preliminary postgres support. which needs a miracle
# "Oracle" is in the early stages of working.
#	 Dave Morgan <dmorgan@bartertrust.com> owns the oracle port

# Please submit necessary patches to rt11@fsck.com

DB_TYPE	        =	mysql

# DB_HOME is where the Database's commandline tools live
# Note: $DB_HOME/bin is where the database binary tools are installed.
 
DB_HOME	       = /opt/mysql

# Set DBA to the name of a unix account with the proper permissions and 
# environment to run your commandline SQL tools

# I don't think this should be needed.  At least not with mysql!
# Set DB_DBA to the name of a DB user with permission to create new databases 
# Set DB_DBA_PASSWORD to that user's password
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
# your database server

DB_DATABASE	=	RT2

# Set this to the name of the rt database user

DB_RT_USER	=	rt_user

# Set this to the password used by the rt database user
# *** Change This Before Installation***

DB_RT_PASS      =      rt_pass

# if you want to give the rt user different default privs, modify this file

DB_ACL		= 	$(RT_ETC_PATH)/acl.$(RT_DB)

# }}}

# {{{ Web configuration 

# The user your webserver runs as. needed so that webrt can cache mason
# objectcode
WEB_USER			=	nobody

# }}}


####################################################################
# No user servicable parts below this line.  Frob at your own risk #
####################################################################

default:
	@echo "Please read RT's readme before installing. Not doing so could"
	@echo "be dangerous."

install: dirs initialize upgrade instruct

instruct:
	@echo "Congratulations. RT has been installed. "
	@echo "You must now configure it by editing $(RT_CONFIG)."
	@echo "From here on in, you should refer to the users guide."

upgrade: config-replace upgrade-noclobber

upgrade-noclobber: libs-install html-install mux-install nondestruct

nondestruct: mux-links fixperms

all:
	@echo "Read the readme."

fixperms:
	chown -R $(RTUSER) $(RT_PATH)
	chgrp -R $(RTGROUP) $(RT_PATH)  
	chmod 0755 $(RT_PATH)
	chmod -R 755 $(RT_LIB_PATH)
	chmod -R 0750 $(RT_ETC_PATH)
	chmod 0755 $(RT_BIN_PATH)
	chmod 4755 $(RT_PERL_MUX)
	chmod 700  $(WEBRT_DATA_PATH)
	chown -R $(WEB_USER) $(WEBRT_DATA_PATH)

dirs:
	mkdir -p $(RT_BIN_PATH)
	mkdir -p $(WEBRT_DATA_PATH)
	mkdir -p $(RT_ETC_PATH)
	cp -rp ./etc/* $(RT_ETC_PATH)

libs-install: 
	mkdir -p $(RT_LIB_PATH)
	cp -rp ./lib/* $(RT_LIB_PATH)    
	chmod -R 0755 $(RT_LIB_PATH)

html-install:
	mkdir -p $(WEBRT_HTML_PATH)
	cp -rp ./webrt/* $(WEBRT_HTML_PATH)
	chmod -R 0755 $(WEBRT_HTML_PATH)

initialize: database acls


database:
	sh bin/initdb.$(DB_TYPE) '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DBA_PASSWORD)' '$(DB_DATABASE)' '$(DB_RT_USER)' '$(DB_RT_PASS)'

acls:
	$(PERL) -p -i.orig -e " s'!!DB_TYPE!!'$(DB_TYPE)'g;\
				s'!!DB_HOST!!'$(DB_HOST)'g;\
				s'!!DB_RT_PASS!!'$(DB_RT_PASS)'g;\
				s'!!DB_RT_HOST!!'$(DB_RT_HOST)'g;\
				s'!!DB_RT_USER!!'$(DB_RT_USER)'g;\
				s'!!DB_DATABASE!!'$(DB_DATABASE)'g;" $(RT_ETC_PATH)/acl.$(DB_TYPE)

	sh bin/initacls.$(DB_TYPE) '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DBA_PASSWORD)' '$(DB_DATABASE)' '$(RT_ETC_PATH)/acl.$(DB_TYPE)'

mux-install:
	cp -rp ./bin/rtmux.pl $(RT_PERL_MUX)
	cp -rp ./bin/webmux.pl $(RT_WEB_MUX)

	$(PERL) -p -i.orig -e "s'!!RT_PATH!!'$(RT_PATH)'g;\
			      	s'!!RT_VERSION!!'$(RT_VERSION)'g;\
				s'!!RT_ACTION_BIN!!'$(RT_ACTION_BIN)'g;\
				s'!!RT_QUERY_BIN!!'$(RT_QUERY_BIN)'g;\
				s'!!RT_ADMIN_BIN!!'$(RT_ADMIN_BIN)'g;\
				s'!!RT_MAILGATE_BIN!!'$(RT_MAILGATE_BIN)'g;\
				s'!!RT_CGI_BIN!!'$(RT_CGI_BIN)'g;\
				s'!!WEBRT_HTML_PATH!!'$(WEBRT_HTML_PATH)'g;\
				s'!!WEBRT_DATA_PATH!!'$(WEBRT_DATA_PATH)'g;\
				s'!!RT_ETC_PATH!!'$(RT_ETC_PATH)'g;\
				s'!!RT_LIB_PATH!!'$(RT_LIB_PATH)'g;" $(RT_PERL_MUX) $(RT_WEB_MUX)

mux-links:
	rm -f $(RT_BIN_PATH)/$(RT_ACTION_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_ACTION_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_ADMIN_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_ADMIN_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_QUERY_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_QUERY_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_MAILGATE_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_MAILGATE_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_CGI_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_CGI_BIN)




config-replace:
	mv $(RT_ETC_PATH)/config.pm $(RT_ETC_PATH)/config.pm.old
	cp -rp ./etc/config.pm $(RT_ETC_PATH)
	$(PERL) -p -i -e "\
	s'!!DB_TYPE!!'$(DB_TYPE)'g;\
	s'!!DB_HOST!!'$(DB_HOST)'g;\
	s'!!DB_RT_PASS!!'$(DB_RT_PASS)'g;\
	s'!!DB_RT_USER!!'$(DB_RT_USER)'g;\
	s'!!RT_USER!!'$(RT_USER)'g;\
	s'!!RT_GROUP!!'$(RT_GROUP)'g;\
	s'!!DB_DATABASE!!'$(DB_DATABASE)'g;\
	" $(RT_CONFIG)


commit:
	cvs commit

predist: commit
	cvs tag -r rt-1-1 -F $(TAG)
	rm -rf /tmp/$(TAG)
	cvs export -D now -d /tmp/$(TAG) -r rt-1-1 rt
	cd /tmp; tar czvf /home/ftp/pub/rt/devel/$(TAG).tar.gz $(TAG)/
	chmod 644 /home/ftp/pub/rt/devel/$(TAG).tar.gz

dist: commit predist
	rm -rf /home/ftp/pub/rt/devel/rt.tar.gz
	ln -s ./rt-$(RT_VERSION).tar.gz /home/ftp/pub/rt/devel/rt.tar.gz
