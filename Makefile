# $Header$
# 
#
# Request Tracker is Copyright 1997 Jesse Reed Vincent <jesse@fsck.com>
# RT is distribute under the terms of the GNU Public License

PERL			= 	/usr/bin/perl
MYSQLDIR		=	/opt/mysql/bin
RTUSER			=	rt
RTGROUP			=	rt
RT_PATH			=	/projects/rt
RT_LIB_PATH		=	$(RT_PATH)/lib
RT_ETC_PATH		=	$(RT_PATH)/etc
RT_BIN_PATH		=	$(RT_PATH)/bin
RT_CGI_PATH		=	$(RT_BIN_PATH)/cgi
RT_TRANSACTIONS_PATH	= 	$(RT_PATH)/transactions
GLIMPSE_PATH		=       $(RT_TRANSACTIONS_PATH)/glimpse
RTMUX			=	$(RT_BIN_PATH)/rtmux.pl
TRANSACT_NUMFILE 	=	$(RT_ETC_PATH)/transact-num
REQUEST_NUMFILE 	=	$(RT_ETC_PATH)/request-num

GLIMPSE_INDEX		=       /usr/local/bin/glimpseindex    
DATABASE		=	rt  
default:
	@echo "Read the readme"

install: dirs  initialize nondestruct instruct

instruct:
	@echo "Congratulations. RT has been installed. "
	@echo "(Now, create a queue, add some users and start fixing problems)"

nondestruct: suidrt glimpse fixperms

all:
	@echo "Read the readme."
fixperms:
	chown -R $(RTUSER) $(RT_PATH)
	chgrp -R $(RTGROUP) $(RT_PATH)  
	chmod -R 770 $(RT_LIB_PATH)
	chmod -R 770 $(RT_ETC_PATH)
	chmod 4111 $(RT_BIN_PATH)/suidrt
	chmod 4111 $(RT_CGI_PATH)/nph-webrt.cgi
	chmod 4111 $(RT_CGI_PATH)/nph-admin-webrt.cgi
	chmod 4110 $(RT_BIN_PATH)/transactnum
	chmod 4110 $(RT_BIN_PATH)/reqnum

glimpse:
	-$(GLIMPSE_INDEX) -H $(GLIMPSE_PATH) $(RT_TRANSACTIONS_PATH)

dirs:
	mkdir -p $(RT_BIN_PATH)
	mkdir -p $(RT_CGI_PATH)
	mkdir -p $(RT_ETC_PATH)/templates/queues
	cp -rp ./etc $(RT_ETC_PATH)
	mkdir -p $(RT_LIB_PATH)
	cp -rp ./etc $(RT_LIB_PATH)
	mkdir -p $(RT_TRANSACTIONS_PATH)
	mkdir -p $(RT_ETC_PATH)/templates/queues
	mkdir -p $(GLIMPSE_PATH)

suidrt: 
	$(CC) src/suidrt.c -DRTMUX=\"$(RTMUX)\" -DPERL=\"$(PERL)\" -o $(RT_BIN_PATH)/suidrt
	rm -f $(RT_BIN_PATH)/rt
	ln -s $(RT_BIN_PATH)/suidrt $(RT_BIN_PATH)/rt
	rm -f $(RT_BIN_PATH)/rtadmin
	ln -s $(RT_BIN_PATH)/suidrt $(RT_BIN_PATH)/rtadmin
	rm -f $(RT_BIN_PATH)/rtq
	ln -s  $(RT_BIN_PATH)/suidrt $(RT_BIN_PATH)/rtq
	rm -f $(RT_CGI_PATH)/nph-webrt.cgi
	ln  $(RT_BIN_PATH)/suidrt $(RT_CGI_PATH)/nph-webrt.cgi
	rm -f $(RT_CGI_PATH)/nph-admin-webrt.cgi
	ln  $(RT_BIN_PATH)/suidrt $(RT_CGI_PATH)/nph-admin-webrt.cgi
	rm -f $(RT_BIN_PATH)/rt-mailgate
	ln -s $(RT_BIN_PATH)/suidrt $(RT_BIN_PATH)/rt-mailgate

transactnum: 
	$(CC) locking-counter.c -DNUMFILE=\"$(TRANSACT_NUMFILE)\" -DGROUP=\"$(RTGROUP)\" -o $(RT_BIN_PATH)/transactnum

reqnum: 
	$(CC) locking-counter.c -DNUMFILE=\"$(REQUEST_NUMFILE)\" -DGROUP=\"$(RTGROUP)\" -o $(RT_BIN_PATH)/reqnum


initialize: nums database acls

nums: reqnum transactnum
#Those - signs are because setting the reqnum to 0 seems to cause make to
#die.  Is there a more elegant solution?
	-$(RT_BIN_PATH)/reqnum -set 0
	-$(RT_BIN_PATH)/transactnum -set 0

database:
#	$(MYSQLDIR)/mysqladmin drop $(DATABASE)
	-$(MYSQLDIR)/mysqladmin create $(DATABASE)
	$(MYSQLDIR)/mysql $(DATABASE) < etc/schema      

acls:
	-$(MYSQLDIR)/mysql mysql < etc/mysql.acl
	$(MYSQLDIR)/mysqladmin reload

