# $Header$
# 
#
# Request Tracker is Copyright 1997 Jesse Reed Vincent <jesse@fsck.com>
# RT is distribute under the terms of the GNU Public License

CC			=	gcc
PERL			= 	/usr/bin/perl
RTUSER			=	rt
RTGROUP			=	rt

RT_VERSION_MAJOR	=	0
RT_VERSION_MINOR	=	99
RT_VERSION_PATCH	=	5pre1	

RT_VERSION =	$(RT_VERSION_MAJOR).$(RT_VERSION_MINOR).$(RT_VERSION_PATCH)

#
# RT_PATH is the name of the directory you want make to install RT in
#

RT_PATH			=	/opt/rt

#
# The rest of these paths are all configurable, but you probably don't want to 
# put them elsewhere
#

RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
RT_CGI_PATH		=	$(RT_BIN_PATH)/cgi
RT_TRANSACTIONS_PATH	= 	$(RT_PATH)/transactions

# Where you keep the templates for your various queues
RT_TEMPLATE_PATH	=	$(RT_ETC_PATH)/templates


#
# The rtmux is the setuid script which invokes whichever rt program it needs to.
#

RT_PERL_MUX		=	$(RT_BIN_PATH)/rtmux.pl
RT_WRAPPER		=	$(RT_BIN_PATH)/suid_wrapper

#
# The following are the names of the various binaries which make up RT 
#
RT_ACTION_BIN		=	rt
RT_QUERY_BIN		=	rtq
RT_ADMIN_BIN		=	rtadmin
RT_MAILGATE_BIN		=	rt-mailgate
RT_WEB_QUERY_BIN	=	nph-webrt.cgi
RT_WEB_ADMIN_BIN	=	nph-admin-webrt.cgi

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


# 
# set this to whatever program you want to send the mail that RT generates
# be aware, however, that RT expects to be able to set the From: line
# with sendmail's command line syntax. For versions of sendmail < 8.8 you may 
# need to remove some or all of the flags we're passing here.  However, nobody
# should be running a version of sendmail < 8.8
#
# If you're not running sendmail, you want to start off with your local sendmail
# "surrogate" with MAIL_OPTIONS set to -t
#
MAIL_PROGRAM		= 	/usr/lib/sendmail
MAIL_OPTIONS		=	-oi -t -ODeliveryMode=b -OErrorMode=m

#
# Mysql related preferences
#
# This is where your mysql binaries are located
#

MYSQLDIR		=	/usr/bin

# Mysql version can be 3.20, 3.21 or 3.22.  This setting determines the order 
# $rtuser and $rtpass are passed to MysqlPerl.  

MYSQL_VERSION		= 	3.22

#
# You can insert your "root" password for mysql to allow
# RT to create its databases.  Remove this password from this Makefile 
# AS SOON AS MAKE INSTALL FINISHES
#
# Alternatively, leave it commented and be prompted
#
#ROOT_MYSQL_PASS		=	My!word%z0t	

#
# this password is what RT will use to authenticate itself to mysql
# change this password so nobody else can get into your rt databases
# (be sure not to use #, @ or $ characters)
#

RT_MYSQL_PASS           =       My!word%z0t

#
# Set this to the domain name of your Mysql server
#

RT_MYSQL_HOST		=	localhost

#
# Set this to the FQDN of your RT server.  It'll be used by mysql to grant 
# rt on your RT server ACLS to the Mysql database.
#

RT_HOST			=	localhost

#
# set this to the name you want to give to the RT database in mysql
#

RT_MYSQL_DATABASE	=	rt

#
# if you want to give the rt user different default privs, modify this file
#

RT_MYSQL_ACL		= 	$(RT_ETC_PATH)/mysql.acl


#
# HTTPD CONFIGURATION
#


#
# where rt's httpd should look for its images
#

HTTPD_IMAGES_PATH 	= $(RT_LIB_PATH)/images

#
# where rt's httpd should keep its logs
#

HTTPD_LOG_DIR 		= /var/log/

#
# the error long for rt's httpd
# 

HTTPD_ERROR_LOG 	= $(HTTPD_LOG_DIR)/rt-httpd-errors

#
# the access log for rt's httpd
#
HTTPD_ACCESS_LOG 	= $(HTTPD_LOG_DIR)/rt-httpd-accesses

#
# what port the RT webserver should live on
#
HTTPD_PORT		= 8080

#
# what the http document should be on rt's web server
# 
HTTPD_ROOT		= /dev/null

# this is the prefix for where the RT cgi binaries should appear to live from 
# a web browser (the /path/to part of http://my.host/path/to/nph-webrt.cgi)

HTTPD_CGI_PREFIX	= /rt



####################################################################
# No user servicable parts below this line.  Frob at your own risk #
####################################################################

default:
	@echo "Read the readme"

install: dirs mux-install libs-install initialize config-replace httpd.conf-replace nondestruct instruct

suid-wrapper:
	$(CC) etc/suidrt.c -DPERL=\"$(PERL)\" -DRT_PERL_MUX=\"$(RT_PERL_MUX)\" -o $(RT_WRAPPER)

instruct:
	@echo "Congratulations. RT has been installed. "
	@echo "(Now, create a queue, add some users and start resolving requests)"

upgrade: libs-install config-replace mux-install nondestruct

upgrade-noclobber: libs-install mux-install nondestruct

nondestruct: mux-links fixperms

all:
	@echo "Read the readme."
fixperms:
	chown -R $(RTUSER) $(RT_PATH)
	chgrp -R $(RTGROUP) $(RT_PATH)  
	chmod -R 755 $(RT_LIB_PATH)
	chmod -R 0700 $(RT_ETC_PATH)
	chmod 0755 $(RT_PATH)
	chmod 0755 $(RT_BIN_PATH)
	chmod 0755 $(RT_CGI_PATH)
	chmod 0755 $(RT_PERL_MUX)
	chmod 4111 $(RT_WRAPPER)

dirs:
	mkdir -p $(RT_BIN_PATH)
	mkdir -p $(RT_CGI_PATH)
	mkdir -p $(RT_ETC_PATH)
	cp -rp ./etc/* $(RT_ETC_PATH)
	mkdir -p $(RT_TRANSACTIONS_PATH)

libs-install: 
	mkdir -p $(RT_LIB_PATH)
	cp -rp ./lib/* $(RT_LIB_PATH)    
	chmod -R 0755 $(RT_LIB_PATH)


initialize: database acls


database:
#	$(MYSQLDIR)/mysqladmin drop $(RT_MYSQL_DATABASE)
	-$(MYSQLDIR)/mysqladmin -h $(RT_MYSQL_HOST) -u root -p$(ROOT_MYSQL_PASS) create $(RT_MYSQL_DATABASE)
	$(MYSQLDIR)/mysql -h $(RT_MYSQL_HOST) -u root -p$(ROOT_MYSQL_PASS) $(RT_MYSQL_DATABASE) < etc/schema      

acls:
	-$(PERL) -p$(ROOT_MYSQL_PASS) -e "if ('$(RT_HOST)' eq '') { s'!!RT_HOST!!'localhost'g}\
			else { s'!!RT_HOST!!'$(RT_HOST)'g }\
		s'!!RT_MYSQL_PASS!!'$(RT_MYSQL_PASS)'g;\
		s'!!RTUSER!!'$(RTUSER)'g;\
		s'!!RT_MYSQL_DATABASE!!'$(RT_MYSQL_DATABASE)'g;\
		" $(RT_MYSQL_ACL) | $(MYSQLDIR)/mysql mysql
	$(MYSQLDIR)/mysqladmin -h $(RT_MYSQL_HOST) -u root -p$(ROOT_MYSQL_PASS) reload


mux-install:
	cp -rp ./bin/rtmux.pl $(RT_PERL_MUX)  
	$(PERL) -p -i.orig -e "s'!!RT_PATH!!'$(RT_PATH)'g;\
			      	s'!!RT_VERSION!!'$(RT_VERSION)'g;\
				s'!!RT_ACTION_BIN!!'$(RT_ACTION_BIN)'g;\
				s'!!RT_QUERY_BIN!!'$(RT_QUERY_BIN)'g;\
				s'!!RT_ADMIN_BIN!!'$(RT_ADMIN_BIN)'g;\
				s'!!RT_MAILGATE_BIN!!'$(RT_MAILGATE_BIN)'g;\
				s'!!RT_WEB_QUERY_BIN!!'$(RT_WEB_QUERY_BIN)'g;\
				s'!!RT_WEB_ADMIN_BIN!!'$(RT_WEB_ADMIN_BIN)'g;\
				s'!!RT_ETC_PATH!!'$(RT_ETC_PATH)'g;\
				s'!!RT_LIB_PATH!!'$(RT_LIB_PATH)'g;" $(RT_PERL_MUX)

mux-links: suid-wrapper
	rm -f $(RT_BIN_PATH)/$(RT_ACTION_BIN)
	ln -s $(RT_WRAPPER) $(RT_BIN_PATH)/$(RT_ACTION_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_ADMIN_BIN)
	ln -s $(RT_WRAPPER) $(RT_BIN_PATH)/$(RT_ADMIN_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_QUERY_BIN)
	ln -s $(RT_WRAPPER) $(RT_BIN_PATH)/$(RT_QUERY_BIN)

	rm -f $(RT_BIN_PATH)/$(RT_MAILGATE_BIN)
	ln -s $(RT_WRAPPER) $(RT_BIN_PATH)/$(RT_MAILGATE_BIN)




	rm -f $(RT_CGI_PATH)/$(RT_WEB_QUERY_BIN)
	ln  $(RT_WRAPPER) $(RT_CGI_PATH)/$(RT_WEB_QUERY_BIN)
	chmod 4755 $(RT_CGI_PATH)/$(RT_WEB_QUERY_BIN)

	rm -f $(RT_CGI_PATH)/$(RT_WEB_ADMIN_BIN)
	ln  $(RT_WRAPPER) $(RT_CGI_PATH)/$(RT_WEB_ADMIN_BIN)
	chmod 4755 $(RT_CGI_PATH)/$(RT_WEB_ADMIN_BIN)

config-replace:
	mv $(RT_ETC_PATH)/config.pm $(RT_ETC_PATH)/config.pm.old
	cp -rp ./etc/config.pm $(RT_ETC_PATH)
	$(PERL) -p -i -e "\
	s'!!RT_PATH!!'$(RT_PATH)'g;\
        s'!!RT_TRANSACTIONS_PATH!!'$(RT_TRANSACTIONS_PATH)'g;\
        s'!!RT_TEMPLATE_PATH!!'$(RT_TEMPLATE_PATH)'g;\
        s'!!RTUSER!!'$(RTUSER)'g;\
        s'!!RTGROUP!!'$(RTGROUP)'g;\
        s'!!RT_MYSQL_PASS!!'$(RT_MYSQL_PASS)'g;\
        s'!!RT_MAIL_TAG!!'$(RT_MAIL_TAG)'g;\
	s'!!RT_USER_PASSWD_MIN!!'$(RT_USER_PASSWD_MIN)'g;\
        s'!!RT_MYSQL_HOST!!'$(RT_MYSQL_HOST)'g;\
        s'!!RT_MYSQL_DATABASE!!'$(RT_MYSQL_DATABASE)'g;\
        s'!!RT_MAIL_ALIAS!!'$(RT_MAIL_ALIAS)'g;\
        s'!!MAIL_PROGRAM!!'$(MAIL_PROGRAM)'g;\
	s'!!MAIL_OPTIONS!!'$(MAIL_OPTIONS)'g;\
	s'!!MYSQL_VERSION!!'$(MYSQL_VERSION)'g; " $(RT_CONFIG)

httpd.conf-replace:
	mv $(RT_ETC_PATH)/httpd/cern/httpd.conf $(RT_ETC_PATH)/httpd/cern/httpd.conf.old
	cp -rp ./etc/httpd/cern/httpd.conf $(RT_ETC_PATH)/httpd/cern
	$(PERL) -p -i -e "\
        s'!!RTUSER!!'$(RTUSER)'g;\
        s'!!RTGROUP!!'$(RTGROUP)'g;\
        s'!!HTTPD_PORT!!'$(HTTPD_PORT)'g;\
        s'!!HTTPD_ROOT!!'$(HTTPD_ROOT)'g;\
        s'!!HTTPD_ERROR_LOG!!'$(HTTPD_ERROR_LOG)'g;\
        s'!!HTTPD_ACCESS_LOG!!'$(HTTPD_ACCESS_LOG)'g;\
        s'!!RT_CGI_PATH!!'$(RT_CGI_PATH)'g;\
        s'!!HTTPD_IMAGES_PATH!!'$(HTTPD_IMAGES_PATH)'g;\
        s'!!HTTPD_CGI_PREFIX!!'$(HTTPD_CGI_PREFIX)'g; " $(RT_ETC_PATH)/httpd/cern/httpd.conf


predist:
	cvs commit
	cvs tag -F rt-pre$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)
	rm -rf /tmp/rt-pre$(RT_VERSION)
	cvs export -D now -d /tmp/rt-pre$(RT_VERSION) rt
	cd /tmp; tar czvf /home/ftp/pub/rt/devel/rt-pre$(RT_VERSION).tar.gz rt-pre$(RT_VERSION)/
	chmod 644 /home/ftp/pub/rt/devel/rt-pre$(RT_VERSION).tar.gz
dist:
	cvs commit
	cvs tag -F rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)
	rm -rf /tmp/rt-$(RT_VERSION)
	cvs export -D now -d /tmp/rt-$(RT_VERSION) rt
	cd /tmp; tar czvf /home/ftp/pub/rt/devel/rt-$(RT_VERSION).tar.gz rt-$(RT_VERSION)/
	cd /home/ftp/pub/rt/devel/
	rm -rf ./rt.tar.gz
	ln -s ./rt-$(RT_VERSION).tar.gz ./rt.tar.gz
	chmod 644 /home/ftp/pub/rt/devel/rt-$(RT_VERSION).tar.gz
