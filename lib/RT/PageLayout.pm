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

package RT::PageLayout;
use strict;
use warnings;

=head1 NAME

RT::PageLayout

=head1 SYNOPSIS

    use RT::PageLayout;

=head1 DESCRIPTION

Functions for working with RT page layouts.

=head1 FUNCTIONS

=cut

=head2 PageLayoutValidWidget Available => \%widgets Widget => $WidgetName

Confirms a provided C<$WidgetName> is in the list of available widgets.

This is in a function because there are special cases where the widget
name can have additional configuration, like "CustomFieldCustomGroupings:Custom".

Returns the name, possibly modified.

=cut

sub ValidateWidget {
    my %args = (
        @_,
    );

    my $widget_key = ParseWidgetKey($args{'Widget'});
    my $name = $args{Available}->{ $widget_key };

    if ( $name && $name =~ /^CustomFieldCustomGroupings/ ) {
        # If we have a name, it's an available widget.
        # Use the original name to retain any additional configuration
        # at the end, like "CustomFieldCustomGroupings:Custom".
        $name = $args{Widget};
    }

    return $name;
}

=head2 ParseWidgetKey(PAGE_LAYOUT_ENTRY)

Accepts an entry from a page layout configuration.

Returns a widget name.

=cut

sub ParseWidgetKey {
    my $widget = shift;

    return
        ref $widget
        ? join( '-', grep defined, $widget->{portlet_type}, $widget->{component} || $widget->{id} )
        : $widget =~ /^([^:]*)/ && $1;
}

1;
