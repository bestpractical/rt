# $Header$
# 
#
# Request Tracker is Copyright 1997 Jesse Reed Vincent <jesse@fsck.com>
# RT is distribute under the terms of the GNU Public License

PERL			= 	/usr/bin/perl
MYSQLDIR		=	/opt/mysql/bin
RTUSER			=	rt
RTGROUP			=	rt
RT_PATH			=	/opt/rt
RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
RT_CGI_PATH		=	$(RT_BIN_PATH)/cgi
RT_TRANSACTIONS_PATH	= 	$(RT_PATH)/transactions
GLIMPSE_PATH		=       $(RT_TRANSACTIONS_PATH)/glimpse
RTMUX			=	$(RT_BIN_PATH)/rtmux.pl

GLIMPSE_INDEX		=       /usr/local/bin/glimpseindex    
DATABASE		=	rt  
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
#	$(MYSQLDIR)/mysqladmin drop $(DATABASE)
	-$(MYSQLDIR)/mysqladmin create $(DATABASE)
	$(MYSQLDIR)/mysql $(DATABASE) < etc/schema      

acls:
	-$(MYSQLDIR)/mysql mysql < etc/mysql.acl
	$(MYSQLDIR)/mysqladmin reload


mux-replace:
	$(PERL) -p -i -e "s|!RT_DIR!|$(RT_PATH)|g;"  $(RTMUX)
