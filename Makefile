DBNAME	=	rtfm
DBA	=	root
PERL	=	/usr/bin/perl

genschema:
	mysqladmin drop $(DBNAME) -u $(DBA)
	mysqladmin create $(DBNAME) -u $(DBA)
	$(PERL) ./tools/initdb mysql /usr/bin localhost '' $(DBA) $(DBNAME) generate
	mysql -u $(DBA) $(DBNAME) < etc/schema.mysql
	$(PERL) ./tools/factory $(DBNAME) RT::FM


