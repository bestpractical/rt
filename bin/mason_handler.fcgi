#!!!PERL!!
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

#This drags in  RT's config.pm
RT::LoadConfig();

package RT::Mason;
use HTML::Mason;    # brings in subpackages: Parser, Interp, etc.
use HTML::Mason::CGIHandler;

use vars qw( $CGI);

# List of modules that you want to use from components (see Admin
# manual for details)

#Clean up our umask...so that the session files aren't world readable, writable or executable
umask(0077);

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
    use CGI::Cookie;
    use Date::Parse;
    use HTML::Entities;
    use Text::Wrapper;

    #TODO: make this use DBI
    use Apache::Session::File;
    use CGI::Fast;

    # set the page's content type.
    # In this case, just save it to a variable that we can pull later;

}

# Die if WebSessionDir doesn't exist or we can't write to it

stat($RT::MasonSessionDir);
die "Can't read and write $RT::MasonSessionDir"
  unless ( ( -d _ ) and ( -r _ ) and ( -w _ ) );

RT::Init();


# Response loop
while ( my $cgi = new CGI::Fast ) {
    my $h = RT::Interface::Web::NewCGIHandler();
    unless ($h->interp->comp_exists($cgi->path_info)) {
	$cgi->path_info($cgi->path_info."/index.html");
    }
    $h->handle_cgi_object($cgi);
    # _should_ always be tied
}
