# BEGIN LICENSE BLOCK
# 
#  Copyright (c) 2002 Jesse Vincent <jesse@bestpractical.com>
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

CONFIG_FILE_PATH	=       /opt/rt3/etc
CONFIG_FILE	     =       $(CONFIG_FILE_PATH)/RT_Config.pm

GETPARAM		=       $(PERL) -e'require "$(CONFIG_FILE)"; print $${$$RT::{$$ARGV[0]}};'

RT_LIB_PATH	     =       `$(GETPARAM) "LibPath"`
MASON_HTML_PATH	 =       `$(GETPARAM) "MasonComponentRoot"`

DB_DATABASE	     =       `${GETPARAM} DatabaseName`
DB_RT_USER	      =       `${GETPARAM} DatabaseUser`
DB_RT_PASS	      =       `${GETPARAM} DatabasePass`

TAG			= rtfm-2-snap

install: install-lib initdb

install-lib:
	cp -rvp lib/* $(RT_LIB_PATH)

factory:
	cd lib; $(PERL) ../tools/factory.mysql $(DB_DATABASE) RT::FM

initdb: etc/schema.mysql
	mysql  $(DB_DATABASE) < etc/schema.mysql

dropdb: etc/drop_schema.mysql
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
	$(MAKE) -f /tmp/Makefile.tagandrelease tag-and-release


# Running this target in a working directory is 
# WRONG WRONG WRONG.
# it will tag the current baseline with the version of RT defined 
# in the currently-being-worked-on makefile. which is wrong.
#  you want tag-and-release-baseline

tag-and-release:
	aegis --delta-name $(TAG)
	rm -rf /tmp/$(TAG)
	mkdir /tmp/$(TAG)
	cd /tmp/$(TAG); \
		aegis -cp -ind -delta $(TAG) . ;\
		chmod 600 Makefile;\
	 #       aegis --report --project fm.$(VERSION_MAJOR) \
	 #	     --page_width 80 \
	 #	     --page_length 9999 \
	 #	     --change $(VERSION_MINOR) --output Changelog Change_Log

	cd /tmp; tar czvf /home/ftp/pub/rt/devel/$(TAG).tar.gz $(TAG)/
	chmod 644 /home/ftp/pub/rt/devel/$(TAG).tar.gz


