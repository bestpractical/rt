# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2024 Best Practical Solutions, LLC
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

package RT::Interface::Web::Scrubber::Restrictive;
use strict;
use warnings;
use 5.010;
use base qw/RT::Interface::Web::Scrubber/;


=head1 NAME

RT::Interface::Web::Scrubber::Restrictive

=head1 DESCRIPTION

This is a subclass of L<RT::Interface::Web::Scrubber>. It's stricter than
L<RT::Interface::Web::Scrubber> with the following additional restrictions:

=over 4

=item Links

External domains not defined in L<RT_Config/RestrictLinkDomains> will be removed.

=back

=head1 VARIABLES

These variables can be altered by creating a C<Restrictive_Local.pm>
file, containing something of the form:

    package RT::Interface::Web::Scrubber::Restrictive;

    # Deny the "alt" attribute of images
    $RULES{'img'} = { alt => 0 };

=over

=item C<%RULES>

Passed to L<HTML::Scrubber/rules>.

=back

=cut

our %RULES = (
    a => {
        $RT::Interface::Web::Scrubber::RULES{a} ? %{ $RT::Interface::Web::Scrubber::RULES{a} } : (),
        href => sub {
            my ( $self, $tag, $attr, $href ) = @_;
            return $href unless $href;

            # Allow internal RT macros like __WebPath__, etc.
            return $href if $href !~ /^\w+:/ && $href =~ $RT::Interface::Web::Scrubber::ALLOWED_ATTRIBUTES{'href'};

            my $uri = URI->new($href);
            unless ( $uri->can("host") && $uri->host ) {
                RT->Logger->warn("Unknown link: $href");
                return '';
            }

            my $rt_host = RT::Interface::Web::_NormalizeHost( RT->Config->Get('WebBaseURL') )->host;
            my $host    = lc $uri->host;
            for my $allowed_domain ( $rt_host, @{ RT->Config->Get('RestrictLinkDomains') || [] } ) {
                if ( $allowed_domain =~ /\*/ ) {

                    # Turn a literal * into a domain component or partial component match.
                    my $regex = join "[a-zA-Z0-9\-]*", map { quotemeta($_) }
                        split /\*/, $allowed_domain;
                    return $href if $host =~ /^$regex$/i;
                }
                else {
                    return $href if $host eq lc($allowed_domain);
                }
            }

            RT->Logger->warning("Blocked link: $href");
            return '';
        },
    },
);

=head1 METHODS

=head2 new

Returns a new L<RT::Interface::Web::Scrubber::Restrictive> object.

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->rules(%RULES);
    return $self;
}

RT::Base->_ImportOverlays();

1;
