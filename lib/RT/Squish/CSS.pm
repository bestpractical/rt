# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2025 Best Practical Solutions, LLC
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

=head1 SYNOPSIS

  use RT::Squish::CSS;
  my $squish = RT::Squish::CSS->new( Style => 'elevator');

=head1 DESCRIPTION

This module lets you create squished content of CSS files.

=head1 METHODS

=cut

use strict;
use warnings;

package RT::Squish::CSS;
use base 'RT::Squish', 'CSS::Squish';
use CSS::Minifier::XS ();

__PACKAGE__->mk_accessors(qw/Style/);

=head2 Squish

use CSS::Squish to squish CSS

=cut

sub Squish {
    my $self = shift;
    my $style = $self->Style;
    return $self->Filter(
      $self->concatenate( "$style/main.css", RT->Config->Get('CSSFiles') )
    );
}

sub roots {
    map { "$_/css" } RT::Interface::Web->StaticRoots
}

sub Filter {
    my ( $self, $content ) = @_;
    return CSS::Minifier::XS::minify($content);
}

RT::Base->_ImportOverlays();

1;
