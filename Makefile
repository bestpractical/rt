# $Header$
# 
#
# Request Tracker is Copyright 1997 Jesse Reed Vincent <jesse@fsck.com>
# RT is distribute under the terms of the GNU Public License

PERL			= 	/usr/bin/perl
RTUSER			=	rt
RTGROUP			=	rt
RT_VERSION		=	0.9.4
RT_PATH			=	/opt/rt

RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
RT_CGI_PATH		=	$(RT_BIN_PATH)/cgi
RT_TRANSACTIONS_PATH	= 	$(RT_PATH)/transactions
RT_TEMPLATE_PATH	=	$(RT_ETC_PATH)/templates
GLIMPSE_PATH		=       $(RT_TRANSACTIONS_PATH)/glimpse
RTMUX			=	$(RT_BIN_PATH)/rtmux.pl
#
# rt config
#
RT_CONFIG		=	$(RT_ETC_PATH)/config.pm
RT_MAIL_TAG		=	change-this-string-or-perish
RT_MAIL_ALIAS		=	rt\@your.domain.is.not.yet.set
#
#glimpse_index is where you keep the glimpseindex binary
#set it to null if you don't have glimpse
GLIMPSE_INDEX		=       /usr/local/bin/glimpseindex
RT_MYSQL_DATABASE		=	rt

# 
#set this to whatever program you want to send the mail that RT generates
#be aware, however, that RT expects to be able to set the From: line
#with sendmail's command line syntax 
MAIL_PROGRAM		= 	/usr/lib/sendmail
#
# Mysql related preferences
#
MYSQLDIR		=	/opt/mysql/bin
#
# change this password so nobody else can get into your rt databases
# (be sure not to use #, @ or $ characters)
#
RT_MYSQL_PASS           =       My!word%z0t
#
# leave this blank if the mysql database is on localhost
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


default:
	@echo "Read the readme"

install: dirs initialize nondestruct instruct

instruct:
	@echo "Congratulations. RT has been installed. "
	@echo "(Now, create a queue, add some users and start resolving requests)"

nondestruct: mux-links glimpse fixperms

all:
	@echo "Read the readme."
fixperms:
	chown -R $(RTUSER) $(RT_PATH)
	chgrp -R $(RTGROUP) $(RT_PATH)  
	chmod -R 770 $(RT_LIB_PATH)
	chmod -R 770 $(RT_ETC_PATH)
	chmod 4755 $(RTMUX)
	chmod 4755 $(RT_CGI_PATH)/nph-webrt.cgi
	chmod 4755 $(RT_CGI_PATH)/nph-admin-webrt.cgi

glimpse:
	-$(GLIMPSE_INDEX) -H $(GLIMPSE_PATH) $(RT_TRANSACTIONS_PATH)

dirs:
	mkdir -p $(RT_BIN_PATH)
	cp -rp ./bin/rtmux.pl $(RTMUX)
	mkdir -p $(RT_CGI_PATH)
	mkdir -p $(RT_ETC_PATH)/templates/queues
	cp -rp ./etc/* $(RT_ETC_PATH)
	mkdir -p $(RT_LIB_PATH)
	cp -rp ./lib/* $(RT_LIB_PATH)
	mkdir -p $(RT_TRANSACTIONS_PATH)
	mkdir -p $(RT_ETC_PATH)/templates/queues
	mkdir -p $(GLIMPSE_PATH)

mux-links: 
	rm -f $(RT_BIN_PATH)/rt
	ln -s $(RTMUX) $(RT_BIN_PATH)/rt
	rm -f $(RT_BIN_PATH)/rtadmin
	ln -s $(RTMUX) $(RT_BIN_PATH)/rtadmin
	rm -f $(RT_BIN_PATH)/rtq
	ln -s  $(RTMUX) $(RT_BIN_PATH)/rtq
	rm -f $(RT_CGI_PATH)/nph-webrt.cgi
	ln  $(RTMUX) $(RT_CGI_PATH)/nph-webrt.cgi
	rm -f $(RT_CGI_PATH)/nph-admin-webrt.cgi
	ln  $(RTMUX) $(RT_CGI_PATH)/nph-admin-webrt.cgi
	rm -f $(RT_BIN_PATH)/rt-mailgate
	ln -s $(RTMUX) $(RT_BIN_PATH)/rt-mailgate


initialize: database acls


database:
#	$(MYSQLDIR)/mysqladmin drop $(RT_MYSQL_DATABASE)
	-$(MYSQLDIR)/mysqladmin create $(RT_MYSQL_DATABASE)
	$(MYSQLDIR)/mysql $(RT_MYSQL_DATABASE) < etc/schema      

acls:
	-$(PERL) -p -e"s'!!RT_MYSQL_PASS!!'$(RT_MYSQL_PASS)'g;" $(RT_MYSQL_ACL) | $(MYSQLDIR)/mysql mysql
	$(MYSQLDIR)/mysqladmin reload


mux-replace:
	$(PERL) -p -i.orig -e"s's'!!RT_PATH!!'$(RT_PATH)'g;\
				  !!RT_VERSION!!'$(RT_VERSION)'g;"  $(RTMUX)

config-replace:
	 $(PERL) -p -i.bak  -e"\
	s'!!RT_PATH!!'$(RT_PATH)'g;\
        s'!!RT_TRANSACTIONS_PATH!!'$(RT_TRANSACTIONS_PATH)'g;\
        s'!!RT_TEMPLATE_PATH!!'$(RT_TEMPLATE_PATH)'g;\
        s'!!RTUSER!!'$(RTUSER)'g;\
        s'!!RTGROUP!!'$(RTGROUP)'g;\
        s'!!RT_MYSQL_PASS!!'$(RT_MYSQL_PASS)'g;\
        s'!!RT_MAIL_TAG!!'$(RT_MAIL_TAG)'g;\
        s'!!RT_MYSQL_HOST!!'$(RT_MYSQL_HOST)'g;\
        s'!!RT_MYSQL_DATABASE!!'$(RT_MYSQL_DATABASE)'g;\
        s'!!RT_MAIL_ALIAS!!'$(RT_MAIL_ALIAS)'g;\
        s'!!MAIL_PROGRAM!!'$(MAIL_PROGRAM)'g;\
        s'!!GLIMPSE_INDEX!!'$(GLIMPSE_INDEX)'g; " $(RT_CONFIG)
