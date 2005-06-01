# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2005 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
package RT::Interface::Web::Standalone;

use strict;
use base 'HTTP::Server::Simple::Mason';
use RT::Interface::Web::Handler;
use RT::Interface::Web;

sub new_handler {
   my $m;
   $m=  RT::Interface::Web::Handler->new(@RT::MasonParameters,
   # Override mason's default output method so 
   # we can change the binmode to our encoding if
   # we happen to be handed character data instead
   # of binary data.
   # 
   # Cloned from HTML::Mason::CGIHandler
    out_method => 
      sub {
            my $m = HTML::Mason::Request->instance;
            my $r = $m->cgi_request;
            # Send headers if they have not been sent by us or by user.
            # We use instance here because if we store $request we get a
            # circular reference and a big memory leak.
                unless ($r->http_header_sent) {
                       $r->send_http_header();
                }
            {
            if ($r->content_type =~ /charset=([\w-]+)$/ ) {
                my $enc = $1;
                binmode *STDOUT, ":encoding($enc)";
            }
            # We could perhaps install a new, faster out_method here that
            # wouldn't have to keep checking whether headers have been
            # sent and what the $r->method is.  That would require
            # additions to the Request interface, though.
             print STDOUT grep {defined} @_;
            }
        }
    );
        return ($m); 
}

sub handle_request {

    my $self = shift;
    my $cgi = shift;

    Module::Refresh->refresh if $RT::DevelMode;

    $self->SUPER::handle_request($cgi);
    $RT::Logger->crit($@) if ($@);

    RT::Interface::Web::Handler->CleanupRequest();

}

1;
