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

=head1 NAME

  RT::Dashboards - a pseudo-collection for Dashboard objects.

=head1 SYNOPSIS

  use RT::Dashboards

=head1 DESCRIPTION

  Dashboards is an object consisting of a number of Dashboard objects.
  It works more or less like a DBIx::SearchBuilder collection, although it
  is not.

=head1 METHODS


=cut

package RT::Dashboards;

use strict;
use warnings;
use base 'RT::SharedSettings';

use RT::Dashboard;

sub RecordClass {
    return 'RT::Dashboard';
}

=head2 LimitToPrivacy

Takes one argument: a privacy string, of the format "<class>-<id>", as produced
by RT::Dashboard::Privacy(). The Dashboards object will load the dashboards
belonging to that user or group. Repeated calls to the same object should DTRT.

=cut

sub LimitToPrivacy {
    my $self = shift;
    my $privacy = shift;

    my $object = $self->_GetObject($privacy);

    if ($object) {
        $self->{'objects'} = [];
        my @dashboard_atts = $object->Attributes->Named('Dashboard');
        foreach my $att (@dashboard_atts) {
            my $dashboard = RT::Dashboard->new($self->CurrentUser);
            $dashboard->Load($privacy, $att->Id);
            push(@{$self->{'objects'}}, $dashboard);
        }
    } else {
        $RT::Logger->error("Could not load object $privacy");
    }
}

=head2 SortDashboards

Sort the list of dashboards. The default is to sort alphabetically.

=cut

sub SortDashboards {
    my $self = shift;

    # Work directly with the internal data structure since Dashboards
    # aren't fully backed by a DB table and can't support typical OrderBy, etc.
    my @sorted = sort { lcfirst($a->Name) cmp lcfirst($b->Name) } @{$self->{'objects'}};
    @{$self->{'objects'}} = @sorted;
    return;
}

sub ColumnMapClassName {
    return 'RT__Dashboard';
}

RT::Base->_ImportOverlays();

1;
