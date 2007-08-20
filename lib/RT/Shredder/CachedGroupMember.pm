use RT::CachedGroupMember ();
package RT::CachedGroupMember;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependency;


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

# deep memebership
    my $objs = RT::CachedGroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Via', VALUE => $self->Id );
    $objs->Limit( FIELD => 'id', OPERATOR => '!=', VALUE => $self->Id );
    push( @$list, $objs );

# principal lost group membership and lost some rights which he could delegate to
# some body

# XXX: Here is problem cause HasMemberRecursively would return true allways
# cause we didn't delete anything yet. :(
    # if pricipal is not member anymore(could be via other groups) then proceed
    if( $self->GroupObj->Object->HasMemberRecursively( $self->MemberObj ) ) {
        my $acl = RT::ACL->new( $self->CurrentUser );
        $acl->LimitToPrincipal( Id => $self->GroupId );

        # look into all rights that have group
        while( my $ace = $acl->Next ) {
            my $delegations = RT::ACL->new( $self->CurrentUser );
            $delegations->DelegatedFrom( Id => $ace->Id );
            $delegations->DelegatedBy( Id => $self->MemberId );
            push( @$list, $delegations );
        }
    }

# XXX: Do we need to delete records if user lost right 'DelegateRights'?

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );

    return $self->SUPER::__DependsOn( %args );
}

#TODO: If we plan write export tool we also should fetch parent groups
# now we only wipeout things.

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

    my $obj = $self->MemberObj;
    if( $obj && $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related Principal #". $self->MemberId ." object.";
    }

    $obj = $self->GroupObj;
    if( $obj && $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related Principal #". $self->GroupId ." object.";
    }

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => RELATES,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__Relates( %args );
}
1;
