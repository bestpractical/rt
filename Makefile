# $Header$
# RT/FM is Copyright 2001 Jesse Vincent <jessebestpractical.com>
# RTFM is distributed under the terms of the GNU General Public License, version 2

RTFM_VERSION_MAJOR	=	0
RTFM_VERSION_MINOR	=	9
RTFM_VERSION_PATCH	=	6


RTFM_VERSION =	$(RTFM_VERSION_MAJOR).$(RTFM_VERSION_MINOR).$(RTFM_VERSION_PATCH)
TAG 	   =	rtfm-$(RTFM_VERSION_MAJOR)-$(RTFM_VERSION_MINOR)-$(RTFM_VERSION_PATCH)


DBNAME	=	rtfm
DBA	=	root
PERL	=	/usr/bin/perl




# {{{ Files and directories 

# BASE_PATH is the name of the directory you want make to install RT in
# RT must be installed in its own directory (don't set this to /usr/local)

BASE_PATH			=	/opt/rtfm

# The rest of these paths are all configurable, but you probably don't want to 
# put them elsewhere

LIB_PATH		=	$(BASE_PATH)/lib
ETC_PATH		=	$(BASE_PATH)/etc
BIN_PATH		=	$(BASE_PATH)/bin
SBIN_PATH		=	$(BASE_PATH)/sbin
MAN_PATH		=	$(BASE_PATH)/man
HTML_PATH		=	$(BASE_PATH)/html


# RT allows sites to overlay the default web ui with 
# local customizations Those files can be placed in LOCAL_HTML_PATH

LOCAL_HTML_PATH	=	$(BASE_PATH)/local/html


# RTFM needs to be able to write to DATA_PATH and SESSION_PATH
# RT will create and chown these directories. Don't just set them to /tmp
DATA_PATH		=       $(PATH)/data
SESSION_PATH	=       $(PATH)/sessiondata


# READABLE_DIR_MODE is the mode of directories that are generally meant to be
# accessable
READABLE_DIR_MODE	=	0755



# The location of your rt configuration file
CONFIGFILE		=	$(ETC_PATH)/rtfm_config.pm

# MODPERL_HANDLER is the mason handler script for mod_perl
MODPERL_HANDLER		=	$(BIN_PATH)/webmux.pl

			
createdb:
	mysqladmin create $(DBNAME) -u $(DBA) -p

dropdb:

	mysqladmin drop $(DBNAME) -u $(DBA) -p

genschema: dropdb createdb
	$(PERL) $(SBIN_PATH)/initdb mysql /usr/bin localhost '' $(DBA) $(DBNAME) generate

initdb: createdb
	mysql -u $(DBA) -p $(DBNAME) < etc/schema.mysql
	$(PERL) $(SBIN_PATH)/insertdata


factory: genschema
	$(PERL) $(SBIN_PATH)/factory $(DBNAME) RT::FM


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

make-dirs:
	[ -d $(LIB_PATH) ] || mkdir -p $(LIB_PATH)
	[ -d $(BIN_PATH) ] || mkdir -p $(BIN_PATH)
	[ -d $(SBIN_PATH) ] || mkdir -p $(SBIN_PATH)
	[ -d $(HTML_PATH) ] || mkdir -p $(HTML_PATH)
	[ -d $(ETC_PATH) ] || mkdir -p $(ETC_PATH)
	[ -d $(LOCAL_HTML_PATH) ] || mkdir -p $(LOCAL_HTML_PATH)

install: install-files replace-paths initdb

install-files: make-dirs install-config install-libs install-binaries

install-config:
	cp -rp ./etc/* $(ETC_PATH)

install-libs:
	cp -rp ./html/* $(HTML_PATH)
	cp -rp ./lib/* $(LIB_PATH)

install-binaries: 
	cp -rp ./bin/* $(BIN_PATH)	
	cp -rp ./sbin/* $(SBIN_PATH)	

replace-paths:
	$(PERL) -p -i -e " \
			   s'!!CONFIG_FILE_PATH!!'$(CONFIGFILE)'g;\
                           s'!!LIB_PATH!!'$(LIB_PATH)'g;"\
                $(MODPERL_HANDLER) $(BIN_PATH)/notify $(SBIN_PATH)/insertdata


upgrade: install-files replace-paths
