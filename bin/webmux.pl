# $Header$
# RT is (c) 1996-2000 Jesse Vincent (jesse@fsck.com);

use strict;

$ENV{'PATH'} = '/bin:/usr/bin';    # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'} = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'} = '' if defined $ENV{'ENV'};
$ENV{'IFS'} = ''          if defined $ENV{'IFS'};

package HTML::Mason;
use HTML::Mason;  # brings in subpackages: Parser, Interp, etc.

$VERSION="!!RT_VERSION!!";

use lib "!!RT_LIB_PATH!!";
use lib "!!RT_ETC_PATH!!";

#This drags in  RT's config.pm
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

my $parser = new HTML::Mason::Parser;

#TODO: Make this draw from the config file
my $interp = new HTML::Mason::Interp (
            parser=>$parser,
            comp_root=>'/opt/rt/WebRT/html',
            data_dir=>'/opt/rt/WebRT/data');
my $ah = new HTML::Mason::ApacheHandler (interp=>$interp);
chown ( [getpwnam('nobody')]->[2], [getgrnam('nobody')]->[2],
        $interp->files_written );   # chown nobody

sub handler {
    my ($r) = @_;
        return -1 if defined($r->content_type) && $r->content_type !~ m|^text/|io;
    $ah->handle_request($r);
}
1;

