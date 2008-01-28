# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
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
# http://www.gnu.org/copyleft/gpl.html.
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

package RT::Model::ObjectCustomFieldCollection;
use base qw/RT::SearchBuilder/;

sub limit_to_custom_field {
    my $self = shift;
    my $id   = shift;
    $self->limit( column => 'custom_field', value => $id );
}

sub limit_to_object_id {
    my $self = shift;
    my $id = shift || 0;
    $self->limit( column => 'object_id', value => $id );
}

sub limit_to_lookup_type {
    my $self   = shift;
    my $lookup = shift;

    $self->{'_cfs_alias'} ||= $self->join(
        alias1  => 'main',
        column1 => 'custom_field',
        table2  => 'CustomFields',
        column2 => 'id',
    );
    $self->limit(
        alias    => $self->{'_cfs_alias'},
        column   => 'LookupType',
        operator => '=',
        value    => $lookup,
    );
}

sub has_entry_for_custom_field {
    my $self = shift;
    my $id   = shift;

    my @items = grep { $_->custom_field == $id } @{ $self->items_array_ref };

    if ( $#items > 1 ) {
        die
            "$self HasEntry had a list with more than one of $id in it. this can never happen";
    }
    if ( $#items == -1 ) {
        return undef;
    } else {
        return ( $items[0] );
    }
}

sub custom_fields {
    my $self = shift;
    my %seen;
    map { $_->custom_field_obj } @{ $self->items_array_ref };
}

sub _do_search {
    my $self = shift;
    if ( $self->{'_cfs_alias'} ) {
        $self->limit(
            alias    => $self->{'_cfs_alias'},
            column   => 'disabled',
            operator => '!=',
            value    => 1
        );
    }
    $self->SUPER::_do_search();
}

1;
