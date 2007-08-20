use RT::Group ();
package RT::Group;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;


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

# User is inconsistent without own Equivalence group
    if( $self->Domain eq 'ACLEquivalence' ) {
        # delete user entry after ACL equiv group
        # in other case we will get deep recursion
        my $objs = RT::User->new($self->CurrentUser);
        $objs->Load( $self->Instance );
        $deps->_PushDependency(
                BaseObject => $self,
                Flags => DEPENDS_ON | WIPE_AFTER,
                TargetObject => $objs,
                Shredder => $args{'Shredder'}
            );
    }

# Principal
    $deps->_PushDependency(
            BaseObject => $self,
            Flags => DEPENDS_ON | WIPE_AFTER,
            TargetObject => $self->PrincipalObj,
            Shredder => $args{'Shredder'}
        );

# Group members records
    my $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->LimitToMembersOfGroup( $self->PrincipalId );
    push( @$list, $objs );

# Group member records group belongs to
    $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit(
            VALUE => $self->PrincipalId,
            FIELD => 'MemberId',
            ENTRYAGGREGATOR => 'OR',
            QUOTEVALUE => 0
            );
    push( @$list, $objs );

# Cached group members records
    push( @$list, $self->DeepMembersObj );

# Cached group member records group belongs to
    $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit(
            VALUE => $self->PrincipalId,
            FIELD => 'MemberId',
            ENTRYAGGREGATOR => 'OR',
            QUOTEVALUE => 0
            );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__DependsOn( %args );
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

# Equivalence group id inconsistent without User
    if( $self->Domain eq 'ACLEquivalence' ) {
        my $obj = RT::User->new($self->CurrentUser);
        $obj->Load( $self->Instance );
        if( $obj->id ) {
            push( @$list, $obj );
        } else {
            my $rec = $args{'Shredder'}->GetRecord( Object => $self );
            $self = $rec->{'Object'};
            $rec->{'State'} |= INVALID;
            $rec->{'Description'} = "ACLEguvivalence group have no related User #". $self->Instance ." object.";
        }
    }

# Principal
    my $obj = $self->PrincipalObj;
    if( $obj && $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related Principal #". $self->id ." object.";
    }

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => RELATES,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__Relates( %args );
}

sub BeforeWipeout
{
    my $self = shift;
    if( $self->Domain eq 'SystemInternal' ) {
        RT::Shredder::Exception::Info->throw('SystemObject');
    }
    return $self->SUPER::BeforeWipeout( @_ );
}

1;
