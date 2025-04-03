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

package RT::Report::Assets;

use base qw/RT::Report RT::Assets/;
use RT::Report::Assets::Entry;

use strict;
use warnings;
use 5.26.3;

=head1 NAME

RT::Report::Assets - Asset search charts

=head1 DESCRIPTION

This is the backend class for asset search charts.

=cut

our @GROUPINGS = (
    Status        => 'Enum',            #loc_left_pair
    Name          => 'Enum',            #loc_left_pair
    Description   => 'Enum',            #loc_left_pair
    Catalog       => 'Catalog',         #loc_left_pair
    Creator       => 'User',            #loc_left_pair
    LastUpdatedBy => 'User',            #loc_left_pair
    Owner         => 'Watcher',         #loc_left_pair
    HeldBy        => 'Watcher',         #loc_left_pair
    Contact       => 'Watcher',         #loc_left_pair
    Watcher       => 'Watcher',         #loc_left_pair
    CustomRole    => 'Watcher',
    Created       => 'Date',            #loc_left_pair
    LastUpdated   => 'Date',            #loc_left_pair
    CF            => 'CustomField',     #loc_left_pair
);

# loc'able strings below generated with (s/loq/loc/):
#   perl -MRT=-init -MRT::Report::Assets -E 'say qq{\# loq("$_->[0]")} while $_ = splice @RT::Report::Assets::STATISTICS, 0, 2'
#
# loc("Asset count")
# loc("Summary of Created to LastUpdated")
# loc("Total Created to LastUpdated")
# loc("Average Created to LastUpdated")
# loc("Minimum Created to LastUpdated")
# loc("Maximum Created to LastUpdated")

our @STATISTICS = (
    COUNT => ['Asset count', 'Count', 'id'],
);

foreach my $pair (
    'Created to LastUpdated',
) {
    my ($from, $to) = split / to /, $pair;
    push @STATISTICS, (
        "ALL($pair)" => ["Summary of $pair", 'DateTimeIntervalAll', $from, $to ],
        "SUM($pair)" => ["Total $pair", 'DateTimeInterval', 'SUM', $from, $to ],
        "AVG($pair)" => ["Average $pair", 'DateTimeInterval', 'AVG', $from, $to ],
        "MIN($pair)" => ["Minimum $pair", 'DateTimeInterval', 'MIN', $from, $to ],
        "MAX($pair)" => ["Maximum $pair", 'DateTimeInterval', 'MAX', $from, $to ],
    );
    push @GROUPINGS, $pair => 'Duration';
}

sub _DoSearch {
    my $self = shift;

    # When groupby/calculation can't be done at SQL level, do it at Perl level
    return $self->_DoSearchInPerl(@_) if $self->{_query};

    $self->SUPER::_DoSearch( @_ );
    $self->_PostSearch();
}

sub new {
    my $self = shift;
    $self->_SetupCustomDateRanges;
    return $self->SUPER::new(@_);
}

sub _Init {
    my $self = shift;
    $self->SUPER::_Init(@_);

    # Reset OrderBy to not order by name by default
    $self->OrderByCols();
}

RT::Base->_ImportOverlays();

1;
