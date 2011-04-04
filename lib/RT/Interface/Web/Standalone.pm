# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
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

use strict;
use warnings;
package RT::Interface::Web::Standalone;

use base 'HTTP::Server::Simple::Mason';
use RT::Interface::Web::Handler;
use RT::Interface::Web;
use URI;

sub handler_class { "RT::Interface::Web::Handler" }

sub setup_escapes {
    my $self = shift;
    my $handler = shift;

    # Override HTTP::Server::Simple::Mason's version of this method to do
    # nothing.  (RT::Interface::Web::Handler does this already for us in
    # NewHandler.)
} 

sub default_mason_config {
    return RT->Config->Get('MasonParameters');
} 

sub handle_request {

    my $self = shift;
    my $cgi = shift;

    Module::Refresh->refresh if RT->Config->Get('DevelMode');
    RT::ConnectToDatabase() unless RT->InstallMode;

    # Each environment has its own way of handling .. and so on in paths,
    # so RT consistently forbids such paths.
    if ( $cgi->path_info =~ m{/\.} ) {
        $RT::Logger->crit("Invalid request for ".$cgi->path_info." aborting");
        print STDOUT "HTTP/1.0 400\r\n\r\n";
        return RT::Interface::Web::Handler->CleanupRequest();
    }

    $self->SUPER::handle_request($cgi);
    $RT::Logger->crit($@) if $@ && $RT::Logger;
    warn $@ if $@ && !$RT::Logger;
    RT::Interface::Web::Handler->CleanupRequest();
}

sub net_server {
    my $self = shift;
    $self->{rt_net_server} = shift if @_;
    return $self->{rt_net_server};
}


=head2  print_banner

This routine prints a banner before the server request-handling loop
starts.

Methods below this point are probably not terribly useful to define
yourself in subclasses.

=cut

sub print_banner {
    my $self = shift;
    
    my $url = URI->new(           RT->Config->Get('WebBaseURL'));
    $url->host('127.0.0.1') if ($url->host() eq 'localhost');
    $url->port($self->port);
    print(   
            "You can connect to your server at "
            . $url->canonical
            . "\n" );

}


1;
