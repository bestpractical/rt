#!perl
package RT::Mason;
use strict;

use CGI;
use HTML::Mason;                   # brings in subpackages: Parser, Interp, etc.
use HTML::Mason::ApacheHandler;

use vars qw(%session $Nobody $SystemUser $r);

#Clean up our umask...so that the session files aren't world readable, writable or executable
umask(0077);

use lib "/opt/rt22/lib/";
#This drags in  RT's config.pm
use RT;
RT::LoadConfig();

{ no strict 'vars'; use vars '%HTML::Mason::Commands::session' }

use Carp;
 
my $ah = HTML::Mason::ApacheHandler->new(
    args_method	=> 'CGI',
    comp_root	=> [
	[ local		=> $RT::MasonLocalComponentRoot ],
	[ standard	=> $RT::MasonComponentRoot ]
    ],
    data_dir	=> "$RT::MasonDataDir"
);

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

sub handler {
    ($r) = @_;
    
    RT::Init();

    # We don't need to handle non-text items
    return -1 if defined( $r->content_type ) && $r->content_type !~ m|^text/|io;
    
    my $status = $ah->handle_request($r);

    untie %HTML::Mason::Commands::session;
    return $status;
}

1;
