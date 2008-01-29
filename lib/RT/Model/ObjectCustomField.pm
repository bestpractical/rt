use warnings;
use strict;

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

package RT::Model::ObjectCustomField;

no warnings qw(redefine);

use base qw/RT::Record/;
sub table {'ObjectCustomFields'}
use Jifty::DBI::Schema;
use Jifty::DBI::Record schema {
    column custom_field => type is 'int(11)', max_length is 11, default is '0';
    column Creator     => type is 'int(11)', max_length is 11, default is '0';
    column object_id   => type is 'int(11)', max_length is 11, default is '0';
    column
        LastUpdatedBy => type is 'int(11)',
        max_length is 11, default is '0';
    column SortOrder => type is 'int(11)', max_length is 11, default is '0';
    column Created     => type is 'datetime', default is '';
    column LastUpdated => type is 'datetime', default is '';

};

sub create {
    my $self = shift;
    my %args = (
        custom_field => 0,
        object_id   => 0,
        SortOrder   => undef,
        @_
    );

    my $cf = $self->custom_field_obj( $args{'custom_field'} );
    unless ( $cf->id ) {
        Jifty->log->error(
            "Couldn't load '$args{'custom_field'}' custom field");
        return 0;
    }

    #XXX: Where is ACL check for 'AssignCustomFields'?

    my $ObjectCFs = RT::Model::ObjectCustomFieldCollection->new;
    $ObjectCFs->limit_to_object_id( $args{'object_id'} );
    $ObjectCFs->limit_to_custom_field( $cf->id );
    $ObjectCFs->limit_to_lookup_type( $cf->lookup_type );
    if ( my $first = $ObjectCFs->first ) {
        $self->load( $first->id );
        return $first->id;
    }

    unless ( defined $args{'SortOrder'} ) {
        my $ObjectCFs = RT::Model::ObjectCustomFieldCollection->new(
            current_user => RT->system_user );
        $ObjectCFs->limit_to_object_id( $args{'object_id'} );
        $ObjectCFs->limit_to_lookup_type( $cf->lookup_type );
        $ObjectCFs->order_by( column => 'SortOrder', order => 'DESC' );
        if ( my $first = $ObjectCFs->first ) {
            $args{'SortOrder'} = $first->sort_order + 1;
        } else {
            $args{'SortOrder'} = 0;
        }
    }

    return $self->SUPER::create(
        custom_field => $args{'custom_field'},
        object_id   => $args{'object_id'},
        SortOrder   => $args{'SortOrder'},
    );
}

sub delete {
    my $self = shift;

    my $ObjectCFs = RT::Model::ObjectCustomFieldCollection->new;
    $ObjectCFs->limit_to_object_id( $self->object_id );
    $ObjectCFs->limit_to_lookup_type( $self->custom_field_obj->lookup_type );

    # Move everything below us up
    my $sort_order = $self->sort_order;
    while ( my $OCF = $ObjectCFs->next ) {
        my $this_order = $OCF->sort_order;
        next if $this_order <= $sort_order;
        $OCF->set_sort_order( $this_order - 1 );
    }

    $self->SUPER::delete;
}

sub custom_field_obj {
    my $self = shift;
    my $id   = shift || $self->custom_field;
    my $CF   = RT::Model::CustomField->new;
    $CF->load($id);
    return $CF;
}

1;
