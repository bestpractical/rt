#!/usr/bin/perl -w
#
# $Header$
# RT is (c) 1996-2000 Jesse Vincent (jesse@fsck.com);


$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};

package RT;
use strict;
use vars qw($VERSION $Handle $Nobody $SystemUser);

$VERSION="!!RT_VERSION!!";

use lib "!!RT_LIB_PATH!!";
use lib "!!RT_ETC_PATH!!";

#This drags in  RT's config.pm
use config;
# Now that we've got the config loaded, we can drop the setgidness
$) = $(;



use Carp;



use RT::Handle;
$RT::Handle = new RT::Handle($RT::DatabaseType);
{
$RT::Handle->Connect();
}

use RT::CurrentUser;
#RT's system user is a genuine database user. its id lives here

$RT::SystemUser = new RT::CurrentUser();
$RT::SystemUser->LoadByUserId('RT_System');

#RT's "nobody user" is a genuine database user. its ID lives here.
$RT::Nobody = new RT::CurrentUser();
$RT::Nobody->LoadByUserId('Nobody');

my $program = $0; 

$program =~ s/(.*)\///;

if ($program eq '!!RT_ADMIN_BIN!!') {
  #load rt_admin
  require rt::support::utils;     
  require rt::ui::cli::support;
  require rt::ui::cli::admin;
  &rt::ui::cli::admin::activate();
}

elsif ($program eq '!!RT_MAILGATE_BIN!!') {
    require RT::Interface::Email;
    &RT::Interface::Email::activate();
}

else {
    $RT::Logger->crit( "RT Has been launched with an illegal launch program ($program)");
    $RT::Handle->Disconnect();
    exit(1);
}

$RT::Handle->Disconnect();


1;

