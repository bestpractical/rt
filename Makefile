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
RT_VERSION_MINOR	=	9
RT_VERSION_PATCH	=	10

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
RT_GLIMPSE_PATH		=       $(RT_TRANSACTIONS_PATH)/glimpse


#
# The rtmux is the setuid script which invokes whichever rt program it needs to.
#

RT_PERL_MUX		=	$(RT_BIN_PATH)/rtmux.pl
RT_WRAPPER		=	$(RT_BIN_PATH)/suid_wrapper

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
# glimpse_index is where you keep the glimpseindex binary
# set it to null if you don't have glimpse
# (glimpse functionality isn't yet used)
#

GLIMPSE_INDEX		=       /usr/local/bin/glimpseindex

# 
# set this to whatever program you want to send the mail that RT generates
# be aware, however, that RT expects to be able to set the From: line
# with sendmail's command line syntax. For versions of sendmail < 8.8 you may need
# to remove some or all of the flags we're passing here.  However, nobody should be 
# running a version of sendmail < 8.8
#

MAIL_PROGRAM		= 	/usr/lib/sendmail -oi -t -ODeliveryMode=b -OErrorMode=m

#
# Mysql related preferences
#
# This is where your mysql binaries are located
#

MYSQLDIR		=	/opt/mysql/bin

# Mysql version can be 3.20 or 3.21.  This setting determines the order 
# $rtuser and $rtpass are passed to MysqlPerl.  

MYSQL_VERSION		= 	3.20

#
# this password is what RT will use to authenticate itself to mysql
# change this password so nobody else can get into your rt databases
# (be sure not to use #, @ or $ characters)
#

RT_MYSQL_PASS           =       My!word%z0t

#
# Set this to the domain name of your Mysql server
# leave this blank for enhanced speed if the mysql database is on localhost
#

RT_MYSQL_HOST		=	

#
# set this to the name you want to give to the RT database in mysql
#

RT_MYSQL_DATABASE	=	rt

#
# if you want to give the rt user different default privs, modify this file
#

RT_MYSQL_ACL		= 	$(RT_ETC_PATH)/mysql.acl



####################################################################
# No user servicable parts below this line.  Frob at your own risk #
####################################################################

default:
	@echo "Read the readme"

install: dirs mux-install libs-install initialize config-replace nondestruct instruct

suid-wrapper:
	$(CC) etc/suidrt.c -DPERL=\"$(PERL)\" -DRT_PERL_MUX=\"$(RT_PERL_MUX)\" -o $(RT_WRAPPER)

instruct:
	@echo "Congratulations. RT has been installed. "
	@echo "(Now, create a queue, add some users and start resolving requests)"

upgrade: libs-install config-replace mux-install nondestruct

nondestruct: mux-links glimpse fixperms

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
	cp -rp ./etc/* $(RT_ETC_PATH)
	mkdir -p $(RT_TRANSACTIONS_PATH)
	mkdir -p $(RT_GLIMPSE_PATH)

libs-install: 
	mkdir -p $(RT_LIB_PATH)
	cp -rp ./lib/* $(RT_LIB_PATH)    
	chmod -R 0755 $(RT_LIB_PATH)

glimpse:
	-$(GLIMPSE_INDEX) -H $(RT_GLIMPSE_PATH) $(RT_TRANSACTIONS_PATH)


initialize: database acls


database:
#	$(MYSQLDIR)/mysqladmin drop $(RT_MYSQL_DATABASE)
	-$(MYSQLDIR)/mysqladmin create $(RT_MYSQL_DATABASE)
	$(MYSQLDIR)/mysql $(RT_MYSQL_DATABASE) < etc/schema      

acls:
	-$(PERL) -p -e "if ('$(RT_MYSQL_HOST)' eq '') { s'!!RT_MYSQL_HOST!!'localhost'g}\
			else { s'!!RT_MYSQL_HOST!!'$(RT_MYSQL_HOST)'g }\
		s'!!RT_MYSQL_PASS!!'$(RT_MYSQL_PASS)'g;\
		s'!!RTUSER!!'$(RTUSER)'g;\
		s'!!RT_MYSQL_DATABASE!!'$(RT_MYSQL_DATABASE)'g;\
		" $(RT_MYSQL_ACL) | $(MYSQLDIR)/mysql mysql
	$(MYSQLDIR)/mysqladmin reload


mux-install:
	cp -rp ./bin/rtmux.pl $(RT_PERL_MUX)  
	$(PERL) -p -i.orig -e "s'!!RT_PATH!!'$(RT_PATH)'g;\
			      s'!!RT_VERSION!!'$(RT_VERSION)'g;" $(RT_PERL_MUX)

mux-links: suid-wrapper
	rm -f $(RT_BIN_PATH)/rt
	ln -s $(RT_WRAPPER) $(RT_BIN_PATH)/rt
	rm -f $(RT_BIN_PATH)/rtadmin
	ln -s $(RT_WRAPPER) $(RT_BIN_PATH)/rtadmin
	rm -f $(RT_BIN_PATH)/rtq
	ln -s  $(RT_WRAPPER) $(RT_BIN_PATH)/rtq
	rm -f $(RT_BIN_PATH)/rt-mailgate
	ln -s $(RT_WRAPPER) $(RT_BIN_PATH)/rt-mailgate
	rm -f $(RT_CGI_PATH)/nph-webrt.cgi
	ln  $(RT_WRAPPER) $(RT_CGI_PATH)/nph-webrt.cgi
	rm -f $(RT_CGI_PATH)/nph-admin-webrt.cgi
	ln  $(RT_WRAPPER) $(RT_CGI_PATH)/nph-admin-webrt.cgi
	chmod 4755 $(RT_CGI_PATH)/nph-webrt.cgi
	chmod 4755 $(RT_CGI_PATH)/nph-admin-webrt.cgi

config-replace:
	mv $(RT_ETC_PATH)/config.pm $(RT_ETC_PATH)/config.pm.old
	cp -rp ./etc/config.pm $(RT_ETC_PATH)
	$(PERL) -p -i -e "\
	s'!!RT_PATH!!'$(RT_PATH)'g;\
        s'!!RT_TRANSACTIONS_PATH!!'$(RT_TRANSACTIONS_PATH)'g;\
        s'!!RT_TEMPLATE_PATH!!'$(RT_TEMPLATE_PATH)'g;\
	s'!!RT_GLIMPSE_PATH!!'$(RT_GLIMPSE_PATH)'g;\
        s'!!RTUSER!!'$(RTUSER)'g;\
        s'!!RTGROUP!!'$(RTGROUP)'g;\
        s'!!RT_MYSQL_PASS!!'$(RT_MYSQL_PASS)'g;\
        s'!!RT_MAIL_TAG!!'$(RT_MAIL_TAG)'g;\
        s'!!RT_MYSQL_HOST!!'$(RT_MYSQL_HOST)'g;\
        s'!!RT_MYSQL_DATABASE!!'$(RT_MYSQL_DATABASE)'g;\
        s'!!RT_MAIL_ALIAS!!'$(RT_MAIL_ALIAS)'g;\
        s'!!MAIL_PROGRAM!!'$(MAIL_PROGRAM)'g;\
	s'!!MYSQL_VERISON!!'$(MYSQL_VERSION)'g;\
	s'!!GLIMPSE_INDEX!!'$(GLIMPSE_INDEX)'g; " $(RT_CONFIG)

dist:
	cvs tag -F rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERSION_PATCH)

	cvs export -r rt-$(RT_VERSION_MAJOR)-$(RT_VERSION_MINOR)-$(RT_VERISON_PATCH) -d /tmp/rt-$(RT_VERSION) rt
	cd /tmp; tar czvf /home/ftp/pub/rt/devel/rt-$(RT_VERSION).tar.gz rt-$(RT_VERSION)/
