#!/usr/bin/perl -T
#
# $Header$
# RT is (c) 1997 Jesse Vincent (jesse@fsck.com)

require "ctime.pl";
$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};

package rt;

#this is the RT path
$rt_dir = "!!RT_PATH!!";

push (@INC, "!!RT_LIB_PATH!!");
require "!!RT_ETC_PATH!!/config.pm";

use DBIx::Handle;
use DBIx::Record;
use DBIx::EasySearch;
#TODO: need to identify the database user here....
DBIx::Handle::Connect($host, $dbname, $rtuser,  $rtpass, $rt_db);



require "!!RT_ETC_PATH!!/config.pm";          

$program = shift @ARGV;
&initialize();
if ($program eq '!!RT_ACTION_BIN!!') {
  # load rt-cli
  require rt::ui::cli::support;
   require rt::ui::cli::manipulate;
  require rt::database::manipulate; 
  &rt::ui::cli::manipulate::activate();
}
elsif ($program eq '!!RT_QUERY_BIN!!') {
  # load rt-query
  require rt::database;      
  require rt::ui::cli::query;
  &rt::ui::cli::query::activate();
  
}
elsif ($program eq '!!RT_ADMIN_BIN!!') {
  #load rt_admin
  require rt::database::admin;
  require rt::support::utils;     
  require rt::ui::cli::support;
  require rt::ui::cli::admin;
  &rt::ui::cli::admin::activate();
}
elsif ($program eq '!!RT_WEB_QUERY_BIN!!') {
  # WebRT
  require rt::ui::web::support;
  require rt::ui::web::auth;     
  require rt::ui::web::manipulate;
  &rt::ui::web::activate();
}
elsif ($program eq '!!RT_WEB_ADMIN_BIN!!') {
  #load web-admin
  require rt::ui::web::support;
  require rt::ui::web::auth;
  require rt::support::utils;   
  require rt::ui::web::admin;
  &rt::ui::web::activate();

}
elsif ($program eq '!!RT_MAILGATE_BIN!!') {
  require rt::database::manipulate;
  require rt::support::utils;      
  require rt::support::mail;
  require rt::ui::mail::manipulate;
  &rt::ui::mail::manipulate::activate();
}
else {
  print STDERR "RT Has been launched with an illegal launch program ($program)\n";
  exit(1);
}


sub initialize{
  my ($in_current_user) = @_;
  $rtversion="!!RT_VERSION!!";
  $rtusernum=(getpwnam($rtuser))[2];
    $rtgroupnum=(getgrnam($rtgroup))[2];
  $time=time();
    umask(0022);
    return(1,"Welcome to Request Tracker $rtversion");     
}

