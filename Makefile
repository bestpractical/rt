# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002-2003 Jesse Vincent <jesse@bestpractical.com>
#  
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of version 2 of the GNU General Public License 
#  as published by the Free Software Foundation.
# 
#  A copy of that license should have arrived with this
#  software, but in any event can be snarfed from www.gnu.org.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
# END LICENSE BLOCK

PERL		    =       /usr/bin/perl

RT_PREFIX 		= /opt/rt3/
DBTYPE		=		mysql

CONFIG_FILE_PATH	=       $(RT_PREFIX)/etc
CONFIG_FILE	     =       $(CONFIG_FILE_PATH)/RT_Config.pm
RT_LIB_PATH	     =       $(RT_PREFIX)/lib
RT_LEXICON_PATH	     =       $(RT_PREFIX)/local/po
MASON_HTML_PATH	 =       $(RT_PREFIX)/share/html

GETPARAM		=       $(PERL) -I$(RT_LIB_PATH) -e'use RT; RT::LoadConfig(); print $${$$RT::{$$ARGV[0]}};'


DB_DATABASEHOST		=  `${GETPARAM} DatabaseHost`
DB_DATABASE	     =       `${GETPARAM} DatabaseName`
DB_RT_USER	      =       `${GETPARAM} DatabaseUser`
DB_RT_PASS	      =       `${GETPARAM} DatabasePass`
TAG			= rtfm-2-0RC1


upgrade: install-lib install-html install-lexicon
install: upgrade initdb

html-install: install-html

install-html:
	-mkdir $(MASON_HTML_PATH)/RTFM
	cp -rp html/* $(MASON_HTML_PATH)/
	chmod -R 755  $(MASON_HTML_PATH)


install-lib:
	cp -rp lib/* $(RT_LIB_PATH)
	chmod -R 755 $(RT_LIB_PATH)

install-lexicon:
	cp -rp po/* $(RT_LEXICON_PATH)

factory:
	cd lib; $(PERL) ../tools/factory.mysql $(DB_DATABASE) RT::FM

regenerate-catalogs:
	$(PERL) ../rt/sbin/extract-message-catalog po/*/*

initdb: initdb.$(DBTYPE)

dropdb: dropdb.$(DBTYPE)


initdb.mysql: etc/schema.mysql
	@echo "-------------------------------------------------------------"
	@echo "You will be prompted for $(DB_RT_USER)'s mysql password below"
	@echo "-------------------------------------------------------------"
	mysql -h $(DB_DATABASEHOST) -u $(DB_RT_USER) -p $(DB_RT_PASS) $(DB_DATABASE) < etc/schema.mysql

initdb.Pg: etc/schema.mysql
	@echo "-------------------------------------------------------------"
	@echo "You will be prompted for $(DB_RT_USER)'s postgres password below"
	@echo "-------------------------------------------------------------"
	psql -U pgsql $(DB_DATABASE) < etc/schema.Pg
	psql -U pgsql $(DB_DATABASE) < etc/acl.Pg

acl:
	grep -i "DROP " etc/drop_schema.Pg | cut -d" " -f 3 |cut -d\; -f 1 |xargs printf "GRANT SELECT, INSERT, UPDATE, DELETE ON %s to $(DB_RT_USER);\n" > etc/acl.Pg

dropdb.Pg: etc/drop_schema.mysql
	psql -U pgsql $(DB_DATABASE) < etc/drop_schema.Pg

dropdb.mysql: etc/drop_schema.mysql
	-mysql  $(DB_DATABASE) < etc/drop_schema.mysql

POD2TEST_EXE = tools/extract_pod_tests

testify-pods:
	[ -d lib/t/autogen ] || mkdir lib/t/autogen
	find lib -name \*pm |xargs -n 1 $(PERL) $(POD2TEST_EXE)
	find bin -type f |grep -v \~| xargs -n 1 $(PERL) $(POD2TEST_EXE)


license-tag:
	perl tools/license_tag

regression: dropdb testify-pods install
	$(PERL) lib/t/02regression.t


tag-and-release-baseline:
	aegis -cp -ind Makefile -output /tmp/Makefile.tagandrelease; \
	$(MAKE) -f /tmp/Makefile.tagandrelease tag-and-release-never-by-hand


# Running this target in a working directory is 
# WRONG WRONG WRONG.
# it will tag the current baseline with the version of RT defined 
# in the currently-being-worked-on makefile. which is wrong.
#you want tag-and-release-baseline

tag-and-release-never-by-hand:
	aegis --delta-name $(TAG)
	rm -rf /tmp/$(TAG)
	mkdir /tmp/$(TAG)
	cd /tmp/$(TAG); \
			 aegis -cp -ind -delta $(TAG) . ;\
			 chmod 600 Makefile;\
			 aegis --report --project rtfm.2 \
				--change 0 \
				--page_width 80 \
				--page_length 9999 \
				--output Changelog Change_Log;

	cd /tmp; tar czvf /home/ftp/pub/rt/devel/$(TAG).tar.gz $(TAG)/
	chmod 644 /home/ftp/pub/rt/devel/$(TAG).tar.gz

clean:
	find .  -type f -name \*~ |xargs rm
	find lib/t/autogen -type f |xargs rm


apachectl:
	/usr/sbin/apachectl stop
	sleep 1
	/usr/sbin/apachectl start



