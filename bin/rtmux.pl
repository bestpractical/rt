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

push (@INC, "$rt_dir/lib/");

require "$rt_dir/etc/config.pm";          

my ($program) = shift @ARGV;
&initialize();
if ($program eq 'rt') {
  # load rt-cli
  require rt::ui::cli::support;
 
  require rt::ui::cli::manipulate;
  require rt::database::manipulate; 
  &rt::ui::cli::manipulate::activate();
}
elsif ($program eq 'rtq') {
  # load rt-query
  require rt::database;      
  require rt::ui::cli::query;
  &rt::ui::cli::query::activate();
  
}
elsif ($program eq 'rtadmin') {
  #load rt_admin
  require rt::database::admin;
  require rt::support::utils;     
  require rt::ui::cli::support;
  require rt::ui::cli::admin;
  &rt::ui::cli::admin::activate();
}
elsif ($program eq 'nph-webrt.cgi') {
  #
  require rt::ui::web::support;
  require rt::ui::web::auth;     
  require rt::ui::web::manipulate;
  &rt::ui::web::activate();
}
elsif ($program eq 'nph-admin-webrt.cgi') {
  #load web-admin
  require rt::ui::web::support;
  require rt::ui::web::auth;
  require rt::support::utils;   
  require rt::ui::web::admin;
  &rt::ui::web::activate();

}
elsif ($program eq 'rt-mailgate') {
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


push(@INC,"$rt_dir/lib/routines");

sub initialize{
  my ($in_current_user) = @_;
  $rtversion="!!RT_VERSION!!";
  $rtusernum=(getpwnam($rtuser))[2];
    $rtgroupnum=(getgrnam($rtgroup))[2];
  $time=time();
    umask(0022);
    return(1,"Welcome to Request Tracker $rtversion");     
}

