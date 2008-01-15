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
use RT::Record ();
package RT::Record;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;

=head2 _AsString

Returns string in format Classname-object_id.

=cut

sub _AsString { return ref($_[0]) ."-". $_[0]->id }

=head2 _AsInsertQuery

Returns INSERT query string that duplicates current record and
can be used to insert record back into DB after delete.

=cut

sub _AsInsertQuery
{
    my $self = shift;

    my $dbh = Jifty->handle->dbh;

    my $res = "INSERT INTO ". $dbh->quote_identifier( $self->table );
    my $values = $self->{'values'};
    $res .= "(". join( ",", map { $dbh->quote_identifier( $_ ) } sort keys %$values ) .")";
    $res .= " VALUES";
    $res .= "(". join( ",", map { $dbh->quote( $values->{$_} ) } sort keys %$values ) .")";
    $res .= ";";

    return $res;
}

sub BeforeWipeout { return 1 }

=head2 Dependencies

Returns L<RT::Shredder::Dependencies> object.

=cut

sub Dependencies
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Flags => DEPENDS_ON,
            @_,
           );

    unless( $self->id ) {
        RT::Shredder::Exception->throw('Object is not loaded');
    }

    my $deps = RT::Shredder::Dependencies->new();
    if( $args{'Flags'} & DEPENDS_ON ) {
        $self->__DependsOn( %args, Dependencies => $deps );
    }
    if( $args{'Flags'} & RELATES ) {
        $self->__Relates( %args, Dependencies => $deps );
    }
    return $deps;
}

sub __DependsOn
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Object custom field values
    my $objs = $self->custom_field_values;
    $objs->{'find_expired_rows'} = 1;
    push( @$list, $objs );

# Object attributes
    $objs = $self->attributes;
    push( @$list, $objs );

# Transactions
    $objs = RT::Model::TransactionCollection->new;
    $objs->limit( column => 'object_type', value => ref $self );
    $objs->limit( column => 'object_id', value => $self->id );
    push( @$list, $objs );

# Links
    if ( $self->can('_Links') ) {
        # XXX: We don't use Links->next as it's dies when object
        #      is linked to object that doesn't exist
        #      also, ->next skip links to deleted tickets :(
        foreach ( qw(Base Target) ) {
            my $objs = $self->_links( $_ );
            $objs->_do_search;
            push @$list, $objs->items_array_ref;
        }
    }

# ACE records
    $objs = RT::Model::ACECollection->new;
    $objs->limit_to_object( $self );
    push( @$list, $objs );

    $deps->_PushDependencies(
            base_object => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return;
}

sub __Relates
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

    if( $self->can('Creator')) {
        my $obj = RT::Model::Principal->new;
        $obj->load( $self->Creator );

        if( $obj && defined $obj->id ) {
            push( @$list, $obj );
        } else {
            my $rec = $args{'Shredder'}->GetRecord( Object => $self );
            $self = $rec->{'Object'};
            $rec->{'State'} |= INVALID;
            push @{ $rec->{'Description'} },
                "Have no related User(Creator) #". $self->Creator ." object";
        }
    }

    if( $self->can( 'LastUpdatedBy') ) {
        my $obj = RT::Model::Principal->new;
        $obj->load( $self->LastUpdatedBy );

        if( $obj && defined $obj->id ) {
            push( @$list, $obj );
        } else {
            my $rec = $args{'Shredder'}->GetRecord( Object => $self );
            $self = $rec->{'Object'};
            $rec->{'State'} |= INVALID;
            push @{ $rec->{'Description'} },
                "Have no related User(LastUpdatedBy) #". $self->LastUpdatedBy ." object";
        }
    }

    $deps->_PushDependencies(
            base_object => $self,
            Flags => RELATES,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );

    # cause of this $self->SUPER::__Relates should be called last
    # in overridden subs
    my $rec = $args{'Shredder'}->GetRecord( Object => $self );
    $rec->{'State'} |= VALID unless( $rec->{'State'} & INVALID );

    return;
}

# implement proxy method because some RT classes
# override Delete method
sub __Wipeout
{
    my $self = shift;
    my $msg = $self->_AsString ." wiped out";
    $self->SUPER::delete;
    Jifty->log->warn( $msg );
    return;
}

sub validate_Relations
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            @_
           );
    unless( $args{'Shredder'} ) {
        $args{'Shredder'} = RT::Shredder->new();
    }

    my $rec = $args{'Shredder'}->PutObject( Object => $self );
    return if( $rec->{'State'} & VALID );
    $self = $rec->{'Object'};

    $self->_ValidateRelations( %args, Flags => RELATES );
    $rec->{'State'} |= VALID unless( $rec->{'State'} & INVALID );

    return;
}

sub _ValidateRelations
{
    my $self = shift;
    my %args = ( @_ );

    my $deps = $self->Dependencies( %args );

    $deps->validate_Relations( %args );

    return;
}

1;
