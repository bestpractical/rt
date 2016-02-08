# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
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

use RT::Record ();
package RT::Record;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;

=head2 _AsString

Returns string in format ClassName-ObjectId.

=cut

sub _AsString { return ref($_[0]) ."-". $_[0]->id }

=head2 _AsInsertQuery

Returns INSERT query string that duplicates current record and
can be used to insert record back into DB after delete.

=cut

sub _AsInsertQuery
{
    my $self = shift;

    my $dbh = $RT::Handle->dbh;

    my $res = "INSERT INTO ". $dbh->quote_identifier( $self->Table );
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
    my $objs = $self->CustomFieldValues;
    $objs->{'find_expired_rows'} = 1;
    push( @$list, $objs );

# Object attributes
    $objs = $self->Attributes;
    push( @$list, $objs );

# Transactions
    $objs = RT::Transactions->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'ObjectType', VALUE => ref $self );
    $objs->Limit( FIELD => 'ObjectId', VALUE => $self->id );
    push( @$list, $objs );

# Links
    if ( $self->can('_Links') ) {
        # XXX: We don't use Links->Next as it's dies when object
        #      is linked to object that doesn't exist
        #      also, ->Next skip links to deleted tickets :(
        foreach ( qw(Base Target) ) {
            my $objs = $self->_Links( $_ );
            $objs->_DoSearch;
            push @$list, $objs->ItemsArrayRef;
        }
    }

# ACE records
    $objs = RT::ACL->new( $self->CurrentUser );
    $objs->LimitToObject( $self );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
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

    if( $self->_Accessible( 'Creator', 'read' ) ) {
        my $obj = RT::Principal->new( $self->CurrentUser );
        $obj->Load( $self->Creator );

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

    if( $self->_Accessible( 'LastUpdatedBy', 'read' ) ) {
        my $obj = RT::Principal->new( $self->CurrentUser );
        $obj->Load( $self->LastUpdatedBy );

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
            BaseObject => $self,
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
    $self->SUPER::Delete;
    $RT::Logger->info( $msg );
    return;
}

sub ValidateRelations
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

    $deps->ValidateRelations( %args );

    return;
}

1;
