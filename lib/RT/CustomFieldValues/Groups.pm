# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2018 Best Practical Solutions, LLC
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

package RT::CustomFieldValues::Groups;

use strict;
use warnings;

use base qw(RT::CustomFieldValues::External);

=head1 NAME

RT::CustomFieldValues::Groups - Provide RT's groups as a dynamic list of CF values

=head1 SYNOPSIS

To use as a source of CF values, add the following to your F<RT_SiteConfig.pm>
and restart RT.

    # In RT_SiteConfig.pm
    Set( @CustomFieldValuesSources, "RT::CustomFieldValues::Groups" );

Then visit the modify CF page in the RT admin configuration.

=head1 METHODS

Most methods are inherited from L<RT::CustomFieldValues::External>, except the
ones below.

=head2 SourceDescription

Returns a brief string describing this data source.

=cut

sub SourceDescription {
    return 'RT user defined groups';
}

=head2 ExternalValues

Returns an arrayref containing a hashref for each possible value in this data
source, where the value name is the group name.

=cut

sub ExternalValues {
    my $self = shift;

    my @res;
    my $i = 0;
    my $groups = RT::Groups->new( $self->CurrentUser );
    $groups->LimitToUserDefinedGroups;
    $groups->OrderByCols( { FIELD => 'Name' } );
    while( my $group = $groups->Next ) {
        push @res, {
            name        => $group->Name,
            description => $group->Description,
            sortorder   => $i++,
        };
    }
    return \@res;
}

RT::Base->_ImportOverlays();

1;
