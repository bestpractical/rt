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


