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

INSTALL 		= /bin/sh ./install-sh -c
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



PRODUCT			= RTFM
TAG			= 2-0-2rc1
CANONICAL_REPO		= svn+ssh://svn.bestpractical.com/svn/bps-public/rtfm/
CANONICAL_REPO_TAGS		= $(CANONICAL_REPO)/tags/
CANONICAL_REPO_TRUNK		= $(CANONICAL_REPO)/trunk/
TMP_DIR			= /tmp
RELEASE_DIR		= /home/ftp/pub/rt/release



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

libs-install: install-lib

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


tag-and-release:
	svn cp $(CANONICAL_REPO_TRUNK) $(CANONICAL_REPO_TAGS)/$(TAG) 
	svn export $(CANONICAL_REPO_TAGS)/$(TAG) $(TMP_DIR)/$(PRODUCT)-$(TAG)
	svn log -v $(CANONICAL_REPO_TAGS)/$(TAG) > $(TMP_DIR)/$(PRODUCT)-$(TAG)/Changelog		
	(cd $(TMP_DIR); tar czf $(PRODUCT)-$(TAG).tar.gz $(PRODUCT)-$(TAG))
	 gpg --detach-sign $(TMP_DIR)/$(PRODUCT)-$(TAG).tar.gz
	 gpg --verify $(TMP_DIR)/$(PRODUCT)-$(TAG).tar.gz.sig
	 cp $(TMP_DIR)/$(PRODUCT)-$(TAG).tar.gz* $(RELEASE_DIR) 


clean:
	find .	-type f -name \*~ |xargs rm
	find lib/t/autogen -type f |xargs rm


apachectl:
	/usr/sbin/apachectl stop
	sleep 1
	/usr/sbin/apachectl start


