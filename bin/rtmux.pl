#!/usr/bin/perl -w
#
# $Header$
# RT is (c) 1997 Jesse Vincent (jesse@fsck.com)

$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};

package RT;

$VERSION="!!RT_VERSION!!";

use strict;
#this is the RT path

use lib "!!RT_LIB_PATH!!";
use lib "!!RT_ETC_PATH!!";
use config;

use Carp;
use DBIx::Handle;

#TODO: need to identify the database user here....
$RT::Handle = new DBIx::Handle;

$RT::Handle->Connect(Host => $RT::DatabaseHost, 
		      Database => $RT::DatabaseName, 
		      User => $RT::DatabaseUser,
		      Password => $RT::DatabasePassword,
		      Driver => $RT::DatabaseType);



require "!!RT_ETC_PATH!!/config.pm";          

my $program = $0; 
$program =~ s/(.*)\///;
#shift @ARGV;


if ($program eq '!!RT_ACTION_BIN!!') {
  # load rt-cli
  require rt::ui::cli::support;
   require rt::ui::cli::manipulate;

  &rt::ui::cli::manipulate::activate();
}
elsif ($program eq '!!RT_QUERY_BIN!!') {
  # load rt-query

  require rt::ui::cli::query;
  &rt::ui::cli::query::activate();
  
}

elsif ($program eq '!!RT_ADMIN_BIN!!') {
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
  print STDERR "RT Has been launched with an illegal launch program ($program)\n";
  exit(1);
}


$RT::Handle->Disconnect();
