#!perl
# BEGIN LICENSE BLOCK
# 
# Copyright (c) 1996-2002 Jesse Vincent <jesse@bestpractical.com>
# 
# (Except where explictly superceded by other copyright notices)
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# 
# Unless otherwise specified, all modifications, corrections or
# extensions to this work which alter its source code become the
# property of Best Practical Solutions, LLC when submitted for
# inclusion in the work.
# 
# 
# END LICENSE BLOCK

package RT::Mason;
use strict;

use CGI;
use HTML::Mason;                   # brings in subpackages: Parser, Interp, etc.
use HTML::Mason::ApacheHandler;

use vars qw(%session $Nobody $SystemUser $r);

#Clean up our umask...so that the session files aren't world readable, writable or executable
umask(0077);

use lib "/opt/rt3/lib/";
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
