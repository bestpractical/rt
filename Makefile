# $Header$
# 
#
# Request Tracker is Copyright 1997-2000 Jesse Vincent <jesse@fsck.com>
# RT is distributed under the terms of the GNU Public License

PERL			= 	/usr/bin/perl
RTUSER			=	rt
RTGROUP			=	rt

RT_VERSION_MAJOR	=	1
RT_VERSION_MINOR	=	3
RT_VERSION_PATCH	=	0

RT_VERSION =	$(RT_VERSION_MAJOR).$(RT_VERSION_MINOR).$(RT_VERSION_PATCH)
TAG 	   =	rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)

#
# RT_PATH is the name of the directory you want make to install RT in
#

RT_PATH			=	/opt/rt-1.3

#
# The rest of these paths are all configurable, but you probably don't want to 
# put them elsewhere
#

RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
RT_CGI_PATH		=	$(RT_BIN_PATH)/cgi
RT_HTML_PATH		=	$(RT_PATH)/WebRT/html
#
# The rtmux is the setuid script which invokes whichever rt program it needs to.
#

RT_PERL_MUX		=	$(RT_BIN_PATH)/rtmux.pl

#
# The following are the names of the various binaries which make up RT 
#
RT_ACTION_BIN		=	rt
RT_QUERY_BIN		=	rtq
RT_ADMIN_BIN		=	rtadmin
RT_MAILGATE_BIN		=	rt-mailgate

#
# The location of your rt configuration file
#

RT_CONFIG		=	$(RT_ETC_PATH)/config.pm

#
# RT_MAIL_TAG is the string that RT will look for in mail messages to
# figure out what ticket a new piece of mail belongs to
# Your domain name is recommended, so as not to pollute the TAG namespace.
# once you start using a given tag, you should probably never change it. 
# (otherwise, mail for existing tickets won't get put in the right place
#

RT_MAIL_TAG		=	change-this-string-or-perish

#
# RT_MAIL_ALIAS is the main mail alias for the RT system.  It should probably be
# rt\@host.domain.com, rather than the name of your primary queue. 
# (note that the \ before the @ is required)
#

RT_MAIL_ALIAS		=	rt\@your.domain.is.not.yet.set

#
# RT_USER_MIN_PASS specifies the minimum length of RT user passwords.  If you don't
# want such functionality, simply set it to 0
#
RT_USER_PASSWD_MIN	=	5


# While it earlier was possible to specify mail program and
# options here, newer versions of RT uses Mail::Internet
# instead. Hopefully, it will work straight out of the box.
# If not, ask for help at rt-users@lists.fsck.com


# Database options

# DB_HOME is where the Database's commandline tools live
# Note: $DB_HOME/bin is where the database binary tools are installed.
 
DB_HOME               = /usr

# Right now, the only working value for DB_TYPE is mysql.  If you're using
# Postgresql _and_ you're a hacker, you might want to try "Pg" as well.
# Please submit necessary patches to rt11@fsck.com

DB_TYPE                =	mysql


# Set DBA to the name of a unix account with the proper permissions and 
# environment to run your commandline SQL tools

# I don't think this should be needed.  At least not with mysql!
# Set DB_DBA to the name of a DB user with permission to create new databases 
# Set DB_DBA_PASSWORD to that user's password
DB_DBA                   =	root
DB_DBA_PASSWORD          =	
 
#
# Set this to the Fully Qualified Domain Name of your database server.
# If the database is local, rather than on a remote host, using "localhost" 
# will greatly enhance performance.

DB_HOST		=	localhost

#
# Set this to the canonical name of the interface RT will be talking to the mysql database on.
# If you said that the RT_DB_HOST above was "localhost," this should be too.
# This value will be used to grant rt access to the database.
# If you want to access the RT database from multiple hosts, you'll need
# to add more database rights. (This is not currently automated)
#

DB_RT_HOST			=	localhost

#
# set this to the name you want to give to the RT database in mysql
#

DB_DATABASE	=	RT

#
# Set this to the name of the rt database user
#

DB_RT_USER	=	RT

#
# Set this to the password used by the rt database user
#

DB_RT_PASS      =       password


#
# if you want to give the rt user different default privs, modify this file
#

DB_ACL		= 	$(RT_ETC_PATH)/acl.$(RT_DB)


#
# Web UI Configuration
#

# WEB_IMAGE_PATH defines the directory name to be used for images in
# the web documents.  This must match the ``Alias'' Apache config
# option mentioned in the README.

WEB_IMAGE_PATH			=	/webrt

####################################################################
# No user servicable parts below this line.  Frob at your own risk #
####################################################################

default:
	@echo "Read the README"

install: dirs initialize libs-install html-install config-replace mux-install mux-links fixperms instruct

instruct:
	@echo "Congratulations. RT has been installed. "
	@echo "From here on in, you should refer to the users guide."

upgrade: libs-install config-replace mux-install nondestruct

upgrade-noclobber: libs-install html-install mux-install nondestruct

nondestruct: mux-links fixperms

all:
	@echo "Read the readme."
fixperms:
	chown -R $(RTUSER) $(RT_PATH)
	chgrp -R $(RTGROUP) $(RT_PATH)  
	chmod -R 755 $(RT_LIB_PATH)
	chmod -R 0750 $(RT_ETC_PATH)
	chmod 0755 $(RT_PATH)
	chmod 0755 $(RT_BIN_PATH)
	chmod 0755 $(RT_CGI_PATH)
	chmod 4755 $(RT_PERL_MUX)
	chmod 777  /opt/rt/WebRT/data
dirs:
	mkdir -p $(RT_BIN_PATH)
	mkdir -p $(RT_CGI_PATH)
	mkdir -p $(RT_ETC_PATH)
	cp -rp ./etc/* $(RT_ETC_PATH)

libs-install: 
	mkdir -p $(RT_LIB_PATH)
	cp -rp ./lib/* $(RT_LIB_PATH)    
	chmod -R 0755 $(RT_LIB_PATH)

html-install:
	mkdir -p $(RT_HTML_PATH)
	cp -rp ./webrt/* $(RT_HTML_PATH)
	chmod -R 0755 $(RT_HTML_PATH)

initialize: database acls


database:
	sh bin/initdb.$(DB_TYPE) '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DBA_PASSWORD)' '$(DB_DATABASE)'

acls:
	cp -rp ./bin/rtmux.pl $(RT_PERL_MUX)  
	$(PERL) -p -i.orig -e "	s'!!DB_TYPE!!'$(DB_TYPE)'g;\
				s'!!DB_HOST!!'$(DB_HOST)'g;\
			        s'!!DB_RT_PASS!!'$(DB_RT_PASS)'g;\
			        s'!!DB_RT_HOST!!'$(DB_RT_HOST)'g;\
			        s'!!DB_RT_USER!!'$(DB_RT_USER)'g;\
				s'!!DB_DATABASE!!'$(DB_DATABASE)'g;" $(RT_ETC_PATH)/acl.$(DB_TYPE)

	sh bin/initacls.$(DB_TYPE) '$(DB_HOME)' '$(DB_HOST)' '$(DB_DBA)' '$(DB_DBA_PASSWORD)' '$(DB_DATABASE)' '$(RT_ETC_PATH)/acl.$(DB_TYPE)'

mux-install:
	cp -rp ./bin/rtmux.pl $(RT_PERL_MUX)  
	$(PERL) -p -i.orig -e "s'!!RT_PATH!!'$(RT_PATH)'g;\
			      	s'!!RT_VERSION!!'$(RT_VERSION)'g;\
				s'!!RT_ACTION_BIN!!'$(RT_ACTION_BIN)'g;\
				s'!!RT_QUERY_BIN!!'$(RT_QUERY_BIN)'g;\
				s'!!RT_ADMIN_BIN!!'$(RT_ADMIN_BIN)'g;\
				s'!!RT_MAILGATE_BIN!!'$(RT_MAILGATE_BIN)'g;\
				s'!!RT_ETC_PATH!!'$(RT_ETC_PATH)'g;\
				s'!!RT_LIB_PATH!!'$(RT_LIB_PATH)'g;" $(RT_PERL_MUX)

mux-links:
	rm -f $(RT_BIN_PATH)/$(RT_ACTION_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_ACTION_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_ADMIN_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_ADMIN_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_QUERY_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_QUERY_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_MAILGATE_BIN)
	ln -s $(RT_PERL_MUX) $(RT_BIN_PATH)/$(RT_MAILGATE_BIN)




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
	s'!!RT_PATH!!'$(RT_PATH)'g;\
        s'!!RT_MAIL_TAG!!'$(RT_MAIL_TAG)'g;\
	s'!!RT_USER_PASSWD_MIN!!'$(RT_USER_PASSWD_MIN)'g;\
        s'!!RT_HOST!!'$(RT_HOST)'g;\
        s'!!RT_MAIL_ALIAS!!'$(RT_MAIL_ALIAS)'g;\
	s'!!WEB_IMAGE_PATH!!'$(WEB_IMAGE_PATH)'g;\
	s'!!WEB_AUTH_MECHANISM!!'$(WEB_AUTH_MECHANISM)'g;\
	s'!!WEB_AUTH_COOKIES_ALLOW_NO_PATH!!'$(WEB_AUTH_COOKIES_ALLOW_NO_PATH)'g;\
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
