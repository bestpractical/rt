# RT is (c) 1997 Jesse Vincent (jesse@fsck.com)


require "ctime.pl";
package rt;
#This file needs to be sourced to get all the app's defaults.
require "/usr/local/rt/etc/config.pm";          
&initialize();

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

