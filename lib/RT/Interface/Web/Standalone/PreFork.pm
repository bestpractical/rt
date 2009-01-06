# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
# 
# This software is Copyright (c) 1996-2009 Best Practical Solutions, LLC
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

use warnings;
use strict;

package RT::Interface::Web::Standalone::PreFork;
use base qw/Net::Server::PreFork/;

my %option_map = (
    min_servers       => 'StandaloneMinServers',
    max_servers       => 'StandaloneMaxServers',
    min_spare_servers => 'StandaloneMinSpareServers',
    max_spare_servers => 'StandaloneMaxSpareServers',
    max_requests      => 'StandaloneMaxRequests',
);

=head2 default_values

Produces the default values for L<Net::Server> configuration from RT's config
files.

=cut

sub default_values {
    my %forking = (
        map  { $_ => RT->Config->Get( $option_map{$_} ) }
        grep { defined( RT->Config->Get( $option_map{$_} ) ) }
        keys %option_map,
    );

    return {
        %forking,
        log_level => 1,
        RT->Config->Get('NetServerOptions')
    };
}

=head2 post_bind_hook

After binding to the specified ports, let the user know that the server is
prepared to handle connections.

=cut

sub post_bind_hook {
    my $self = shift;
    my @ports = @{ $self->{server}->{port} };

    print $0
        . ": You can connect to your server at "
        . (join ' , ', map { "http://localhost:$_/" } @ports)
        . "\n";

    $self->SUPER::post_bind_hook(@_);
}

1;
