# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2021 Best Practical Solutions, LLC
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

package RT::Interface::Web::Scrubber::Permissive;
use strict;
use warnings;
use 5.010;
use base qw/RT::Interface::Web::Scrubber/;


=head1 NAME

RT::Interface::Web::Scrubber::Permissive

=head1 DESCRIPTION

This is a subclass of RT::Interface::Web::Scrubber. As a permissive version,
it's more suitable for trusted content. It permits nearly all items allowed
in HTML body except <script>, <style> and comments by default.

=head1 VARIABLES

These variables can be altered by creating a C<Permissive_Local.pm> file,
containing something of the form:

    package RT::Interface::Web::Scrubber::Permissive;

    # Deny the "style" attribute
    $ATTRIBUTES{style} = 0;

=over

=item C<@DENIED_TAGS>

Passed to L<HTML::Scrubber/deny>.

=item C<%ATTRIBUTES>

Passed into L<HTML::Scrubber/default>.

=item C<%RULES>

Passed to L<HTML::Scrubber/rules>.

=back

=cut

our @DENIED_TAGS;

# Initally from PermissiveHTMLMail extension.
our %ATTRIBUTES = (
    '*'    => 1,
    'href' => qr{^(?!(?:java)?script)}i,
    'src'  => qr{^(?!(?:java)?script)}i,
    'cite' => qr{^(?!(?:java)?script)}i,
    (
        map { +( "on$_" => 0 ) }
            qw/blur change click dblclick error focus
            keydown keypress keyup load mousedown
            mousemove mouseout mouseover mouseup reset
            select submit unload/
    ),
);

our %RULES = (
    script => 0,
    html   => 0,
    head   => 0,
    body   => 0,
    meta   => 0,
    base   => 0,
);

=head1 METHODS

=head2 new

Returns a new L<RT::Interface::Web::Scrubber::Permissive> object, configured
with the above globals. Takes no arguments.

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->default( 1, \%ATTRIBUTES );
    $self->deny(@DENIED_TAGS);
    $self->rules(%RULES);

    # Scrubbing comments is vital since IE conditional comments can contain
    # arbitrary HTML and we'd pass it right on through.
    $self->comment(0);

    return $self;
}

RT::Base->_ImportOverlays();

1;
