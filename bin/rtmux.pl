#!/usr/bin/perl 
#
#
# RT is (c) 1997 Jesse Vincent (jesse@fsck.com)

require "ctime.pl";
package rt;

#set this to the root of your RT Installation
$rt_dir = "/projects/rt";
push (@INC, "$rt_dir/lib/");

require "$rt_dir/etc/config.pm";          


&initialize();

if ($ARGV[0] eq 'rt') {
  # load rt-cli
  require rt::ui::cli::support;
 
  require rt::ui::cli::manipulate;
  require rt::database::manipulate; 
  &rt::ui::cli::manipulate::activate();
}
elsif ($ARGV[0] eq 'rtq') {
  # load rt-query
  require rt::database;      
  require rt::ui::cli::query;
  &rt::ui::cli::query::activate();
  
}
elsif ($ARGV[0] eq 'rtadmin') {
  #load rt_admin
  require rt::database::admin;
  require rt::support::utils;     
  require rt::ui::cli::support;
  require rt::ui::cli::admin;
  &rt::ui::cli::admin::activate();
}
elsif ($ARGV[0] eq 'webrt') {
  #
  require rt::ui::web::support;
  require rt::ui::web::auth;     
  require rt::ui::web::manipulate;
  &rt::ui::web::manipulate::activate();
}
elsif ($ARGV[0] eq 'webadminrt') {
  #load web-admin
  require rt::ui::web::support;
  require rt::ui::web::auth;
  require rt::support::utils;   
  require rt::ui::web::admin;
  &rt::ui::web::admin::activate();

}
elsif ($ARGV[0] eq 'rtmailgate') {
  require rt::database::manipulate;
  require rt::support::utils;      
  require rt::support::mail;
  &rt::ui::mail::manipulate::activate();
}
else {
  print STDERR "RT Has been launched with an illegal launch program ($ARGV[0])\n";
  exit(1);
}


push(@INC,"$rt_dir/lib/routines");

sub initialize{
  my ($in_current_user) = @_;
  $rtversion="0.9.0";
  $rtusernum=(getpwnam($rtuser))[2];
    $rtgroupnum=(getgrnam($rtgroup))[2];
  $time=time();
    umask(0022);
    return(1,"Welcome to Request Tracker $rtversion");     
}

