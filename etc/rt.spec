Summary: rt Request Tracker

Name: rt
Version: 2.0.9pre5
Release: 1
Group: Applications/Web
Packager: Jesse Vincent <jesse@bestpractical.com>
Vendor: http://www.fsck.com/projects/rt
Requires: perl
Requires: mod_perl > 1.22
Requires: perl-DBI >= 1.18
Requires: perl-DBIx-DataSource >= 0.02
Requires: perl-DBIx-SearchBuilder >= 0.47
Requires: perl-HTML-Parser
Requires: perl-MLDBM
Requires: perl-libnet
Requires: perl-CGI.pm >= 2.78
Requires: perl-Params-Validate >= 0.02
Requires: perl-HTML-Mason >= 0.896
Requires: perl-libapreq
Requires: perl-Apache-Session >= 1.53
Requires: perl-MIME-tools >= 5.411
Requires: perl-MailTools >= 1.20
Requires: perl-Getopt-Long >= 2.24
Requires: perl-Tie-IxHash
Requires: perl-TimeDate
Requires: perl-Time-HiRes
Requires: perl-Text-Wrapper
Requires: perl-Text-Template
Requires: perl-File-Spec >= 0.8
Requires: perl-FreezeThaw
Requires: perl-Storable
Requires: perl-File-Temp
Requires: perl-Log-Dispatch >= 1.6                     

Source: http://www.fsck.com/pub/rt/release/%{name}.tar.gz
 
Copyright: GPL 
BuildRoot: /var/tmp/rt-root

%description
RT is an industrial-grade ticketing system. It lets a group
of people intelligently and efficiently manage requests
submitted by a community of users. RT is used by systems
administrators, customer support staffs, NOCs, developers
and even marketing departments at over a thousand sites
around the world. 

%prep
groupadd rt || true
%setup -q -n %{name}

%build

%install

if [ x$RPM_BUILD_ROOT != x ]; then
rm -rf $RPM_BUILD_ROOT
fi

#
# Perform all the non-site specfic steps whilst building the package
#
make dirs libs-install html-install bin-install  DESTDIR=$RPM_BUILD_ROOT
#
# fixperms needs these, so make fake empty files
touch $RPM_BUILD_ROOT/opt/rt2/etc/insertdata $RPM_BUILD_ROOT/opt/rt2/etc/config.pm
make fixperms insert-install WEB_USER=www DESTDIR=$RPM_BUILD_ROOT

#
# Copy in the files needed again after install
#
mkdir -p $RPM_BUILD_ROOT/opt/rt2/postinstall/bin
cp -rp Makefile etc tools $RPM_BUILD_ROOT/opt/rt2/postinstall
cp -rp bin/initacls.* $RPM_BUILD_ROOT/opt/rt2/postinstall/bin

# logging in /var/log/rt2
mkdir -p $RPM_BUILD_ROOT/var/log/rt2
chown www $RPM_BUILD_ROOT/var/log/rt2
chgrp rt $RPM_BUILD_ROOT/var/log/rt2
chmod ug=rwx,o= $RPM_BUILD_ROOT/var/log/rt2

%clean
if [ x$RPM_BUILD_ROOT != x ]; then
rm -rf $RPM_BUILD_ROOT
fi

#
# A new rt groups is required
#
%pre
groupadd rt || true

#
# Show the user the site specific steps required after install
#
%post
cat <<EOF
-----------------------------------------------------------------------
rt2 installation is complete. Now create the rt2 database by running:
-----------------------------------------------------------------------

# cd /opt/rt2/postinstall
# make config-replace initialize.mysql insert RT_LOG_PATH=/var/log/rt2 DB_RT_PASS=new_rt_user_password

Choose your own new_rt_user_password. You will need the mysql root password.
You can try Pg or Oracle instead of mysql - untested.

Review and configure your site specific details in /opt/rt2/etc/config.pm
EOF

%preun

%files
%dir /opt/rt2
/opt/rt2/bin
/opt/rt2/WebRT
/opt/rt2/lib
/opt/rt2/local
/opt/rt2/man
/opt/rt2/postinstall
%dir /opt/rt2/etc
/opt/rt2/etc/insertdata
%config /opt/rt2/etc/config.pm
%dir /var/log/rt2

%changelog
* Mon Sep 24 2001 Jesse Vincent <jesse@bestpractical.com>
  Switch to rt DESTDIR support
* Fri Sep 14 2001 Cris Bailiff <c.bailiff@devsecure.com>
  Fix permissions on created /var/log/rt2 and roll in 2.0.7
* Tue Sep 4 2001 Cris Bailiff <c.bailiff@devsecure.com>
- created initial spec file
* Tue Sep 4 2001 Cris Bailiff <c.bailiff@devsecure.com>
- created initial spec file
* Tue Sep 4 2001 Cris Bailiff <c.bailiff@devsecure.com>
- created initial spec file
