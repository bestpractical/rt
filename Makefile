# $Header$
# RT/FM is Copyright 2001 Jesse Vincent <jessebestpractical.com>
# RTFM is distributed under the terms of the GNU General Public License, version 2

RTFM_VERSION_MAJOR	=	0
RTFM_VERSION_MINOR	=	9
RTFM_VERSION_PATCH	=	0


RTFM_VERSION =	$(RTFM_VERSION_MAJOR).$(RTFM_VERSION_MINOR).$(RTFM_VERSION_PATCH)
TAG 	   =	rtfm-$(RTFM_VERSION_MAJOR)-$(RTFM_VERSION_MINOR)-$(RTFM_VERSION_PATCH)


DBNAME	=	rtfm
DBA	=	root
PERL	=	/usr/bin/perl


createdb:
	mysqladmin create $(DBNAME) -u $(DBA)

dropdb:

	mysqladmin drop $(DBNAME) -u $(DBA)

genschema: dropdb createdb
	$(PERL) ./tools/initdb mysql /usr/bin localhost '' $(DBA) $(DBNAME) generate

initdb: createdb
	mysql -u $(DBA) $(DBNAME) < etc/schema.mysql

factory: genschema
	$(PERL) ./tools/factory $(DBNAME) RT::FM


commit:
	cvs commit

predist: commit
	cvs tag -F $(TAG)
	rm -rf /tmp/$(TAG)
	cvs co -D now -d /tmp/$(TAG)  fm
	cd /tmp/$(TAG); chmod 600 Makefile; /usr/local/bin/cvs2cl.pl \
		--no-wrap --follow rt-1-1 --separate-header \
		--window 120
	cd /tmp; tar czvf /home/jesse/public_html/projects/rtfm/$(TAG).tar.gz $(TAG)/
	chmod 644 /home/jesse/public_html/projects/rtfm/$(TAG).tar.gz

dist: commit predist
