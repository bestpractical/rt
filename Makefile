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
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
#  GNU General Public License for more details.
#
# END LICENSE BLOCK

PERL 			= /usr/bin/perl

INSTALL 		= /bin/sh ./install-sh
RT_PREFIX		= /opt/rt3

CONFIG_FILE_PATH	= $(RT_PREFIX)/etc
CONFIG_FILE	     	= $(CONFIG_FILE_PATH)/RT_Config.pm
RT_LIB_PATH	     	= $(RT_PREFIX)/lib
RT_LEXICON_PATH	     	= $(RT_PREFIX)/local/po
MASON_HTML_PATH	 	= $(RT_PREFIX)/share/html
RT_SBIN_PATH		= $(RT_PREFIX)/sbin/

GETPARAM		=	$(PERL) -I$(RT_LIB_PATH) -e'use RT; RT::LoadConfig(); print $${$$RT::{$$ARGV[0]}};'


DB_TYPE		=		`${GETPARAM} DatabaseType`
DB_DATABASEHOST		=  `${GETPARAM} DatabaseHost`
DB_DATABASE	     =	     `${GETPARAM} DatabaseName`
DB_RT_USER	      =	      `${GETPARAM} DatabaseUser`
DB_RT_PASS	      =	      `${GETPARAM} DatabasePass`
DB_DBA			= root
TAG			= rtfm-2-0RC3


upgrade: install-lib install-html install-lexicon
install: upgrade initdb

html-install: install-html

install-html:
	for dir in `cd ./html/ && find . -type d -print`; do \
	  $(INSTALL) -d -m 0755 $(MASON_HTML_PATH)/$$dir ; \
	done
	for f in `cd ./html/ && find . -type f -print`; do \
	  $(INSTALL)  -m 0644 html/$$f	$(MASON_HTML_PATH)/$$f ; \
	done

install-lib:
	for dir in `cd ./lib/ && find . -type d -print`; do \
	  $(INSTALL) -d -m 0755 $(RT_LIB_PATH)/$$dir ; \
	done
	for f in `cd ./lib/ && find . -type f -name \*.pm -print`; do \
	  $(INSTALL)  -m 0644 lib/$$f  $(RT_LIB_PATH)/$$f ; \
	done

install-lexicon:
	for dir in `cd ./po/ && find . -type d -print`; do \
	  $(INSTALL) -d -m 0755 $(RT_LEXICON_PATH)/$$dir ; \
	done
	for f in `cd ./po/ && find . -type f -print`; do \
	 echo "Installing $(MASON_HTML_PATH)/$$f" ; \
	  $(INSTALL)  -m 0644 po/$$f  $(RT_LEXICON_PATH)/$$f ; \
	done

factory:
	cd lib; $(PERL) ../tools/factory.mysql $(DB_DATABASE) RT::FM

regenerate-catalogs:
	$(PERL) ../rt/sbin/extract-message-catalog po/*/*

initdb:
	$(PERL) $(RT_SBIN_PATH)/rt-setup-database --action schema --datadir ./etc/ --dba $(DB_DBA) --prompt-for-dba-password
	$(PERL) $(RT_SBIN_PATH)/rt-setup-database --action acl --datadir ./etc/ --dba $(DB_DBA) --prompt-for-dba-password


dropdb:

dropdb.Pg: etc/drop_schema.mysql
	psql -U $(DB_DBA) $(DB_DATABASE) < etc/drop_schema.Pg

dropdb.mysql: etc/drop_schema.mysql
	-mysql	$(DB_DATABASE) < etc/drop_schema.mysql

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
	find .	-type f -name \*~ |xargs rm
	find lib/t/autogen -type f |xargs rm


apachectl:
	/usr/sbin/apachectl stop
	sleep 1
	/usr/sbin/apachectl start


