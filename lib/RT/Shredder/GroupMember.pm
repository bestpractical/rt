use RT::GroupMember ();
package RT::GroupMember;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;

# No dependencies that should be deleted with record

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

    my $objs = RT::CachedGroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->MemberId );
    $objs->Limit( FIELD => 'ImmediateParentId', VALUE => $self->GroupId );
    push( @$list, $objs );

    # XXX: right delegations should be cleaned here

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );

    my $group = $self->GroupObj->Object;
    # XXX: If we delete member of the ticket owner role group then we should also
    # fix ticket object, but only if we don't plan to delete group itself!
    unless( ($group->Type || '') eq 'Owner' &&
        ($group->Domain || '') eq 'RT::Ticket-Role' ) {
        return $self->SUPER::__DependsOn( %args );
    }

    # we don't delete group, so we have to fix Ticket and Group
    $deps->_PushDependencies(
                BaseObject => $self,
                Flags => DEPENDS_ON | VARIABLE,
                TargetObjects => $group,
                Shredder => $args{'Shredder'}
        );
    $args{'Shredder'}->PutResolver(
            BaseClass => ref $self,
            TargetClass => ref $group,
            Code => sub {
                my %args = (@_);
                my $group = $args{'TargetObject'};
                return if $args{'Shredder'}->GetState( Object => $group ) & (WIPED|IN_WIPING);
                return unless ($group->Type || '') eq 'Owner';
                return unless ($group->Domain || '') eq 'RT::Ticket-Role';

                return if $group->MembersObj->Count > 1;

                my $group_member = $args{'BaseObject'};

                if( $group_member->MemberObj->id == $RT::Nobody->id ) {
                    RT::Shredder::Exception->throw( "Couldn't delete Nobody from owners role group" );
                }

                my( $status, $msg ) = $group->AddMember( $RT::Nobody->id );
                RT::Shredder::Exception->throw( $msg ) unless $status;

                my $ticket = RT::Ticket->new( $group->CurrentUser );
                $ticket->Load( $group->Instance );
                RT::Shredder::Exception->throw( "Couldn't load ticket" ) unless $ticket->id;

                ( $status, $msg ) = $ticket->_Set( Field => 'Owner',
                                   Value => $RT::Nobody->id,
                                 );
                RT::Shredder::Exception->throw( $msg ) unless $status;

                return;
            },
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
