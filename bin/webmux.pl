# $Header: /raid/cvsroot/rt/bin/webmux.pl,v 1.2.2.1 2002/01/28 05:27:12 jesse Exp $
# RT is (c) 1996-2000 Jesse Vincent (jesse@fsck.com);

use strict;
$ENV{'PATH'}   = '/bin:/usr/bin';                      # or whatever you need
$ENV{'CDPATH'} = '' if defined $ENV{'CDPATH'};
$ENV{'SHELL'}  = '/bin/sh' if defined $ENV{'SHELL'};
$ENV{'ENV'}    = '' if defined $ENV{'ENV'};
$ENV{'IFS'}    = '' if defined $ENV{'IFS'};

# We really don't want apache to try to eat all vm
# see http://perl.apache.org/guide/control.html#Preventing_mod_perl_Processes_Fr

use lib "!!RT_LIB_PATH!!";
use RT;

package RT::Mason;
use CGI qw(-private_tempfiles);    #bring this in before mason, to make sure we
                                   #set private_tempfiles
use HTML::Mason::ApacheHandler( args_method => 'CGI' );
use HTML::Mason;                   # brings in subpackages: Parser, Interp, etc.

use vars qw($Nobody $SystemUser $r);

#Clean up our umask...so that the session files aren't world readable, writable or executable
umask(0077);

#This drags in  RT's config.pm
RT::LoadConfig();

use Carp;

{

    package HTML::Mason::Commands;

    use RT::Tickets;
    use RT::Transactions;
    use RT::Users;
    use RT::CurrentUser;
    use RT::Templates;
    use RT::Queues;
    use RT::ScripActions;
    use RT::ScripConditions;
    use RT::Scrips;
    use RT::Groups;
    use RT::GroupMembers;
    use RT::CustomFields;
    use RT::CustomFieldValues;
    use RT::TicketCustomFieldValues;

    use RT::Interface::Web;
    use MIME::Entity;
    use Text::Wrapper;
    use CGI::Cookie;
    use Date::Parse;
    use HTML::Entities;

    #TODO: make this use DBI
    use Apache::Session::File;

    # Set this page's content type to whatever we are called with
    sub CGIObject {
        #$m->cgi_object();
    }

}


my $ah = &RT::Interface::Web::NewApacheHandler();

# Activate the following if running httpd as root (the normal case).
# Resets ownership of all files created by Mason at startup.
#
chown( Apache->server->uid, Apache->server->gid, [$RT::MasonSessionDir] );

#chown( Apache->server->uid, Apache->server->gid, $interp->files_written );

# Die if WebSessionDir doesn't exist or we can't write to it

stat($RT::MasonSessionDir);
die "Can't read and write $RT::MasonSessionDir"
  unless ( ( -d _ ) and ( -r _ ) and ( -w _ ) );

sub handler {
    ($r) = @_;

    RT::Init();

    # We don't need to handle non-text items
    return -1 if defined( $r->content_type ) && $r->content_type !~ m|^text/|io;

    my $status = $ah->handle_request($r);

    return $status;

}
1;

