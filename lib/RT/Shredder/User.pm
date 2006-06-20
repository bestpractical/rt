use RT::User ();
package RT::User;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Constants;
use RT::Shredder::Exceptions;
use RT::Shredder::Dependencies;

my @OBJECTS = qw(
    Attachments
    CachedGroupMembers
    CustomFields
    CustomFieldValues
    GroupMembers
    Groups
    Links
    Principals
    Queues
    ScripActions
    ScripConditions
    Scrips
    Templates
    ObjectCustomFieldValues
    Tickets
    Transactions
    Users
);

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

# Principal
    $deps->_PushDependency(
            BaseObject => $self,
            Flags => DEPENDS_ON | WIPE_AFTER,
            TargetObject => $self->PrincipalObj,
            Shredder => $args{'Shredder'}
        );

# ACL equivalence group
# don't use LoadACLEquivalenceGroup cause it may not exists any more
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'ACLEquivalence' );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    push( @$list, $objs );

# Cleanup user's membership
    $objs = RT::GroupMembers->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'MemberId', VALUE => $self->Id );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );

# TODO: Almost all objects has Creator, LastUpdatedBy and etc. fields
# which are references on users(Principal actualy)
    my @var_objs;
    foreach( @OBJECTS ) {
        my $class = "RT::$_";
        foreach my $method ( qw(Creator LastUpdatedBy) ) {
            my $objs = $class->new( $self->CurrentUser );
            next unless $objs->NewItem->_Accessible( $method => 'read' );
            $objs->Limit( FIELD => $method, VALUE => $self->id );
            push @var_objs, $objs;
        }
    }
    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON | VARIABLE,
            TargetObjects => \@var_objs,
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

# Principal
    my $obj = $self->PrincipalObj;
    if( $obj && defined $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related ACL equivalence Group object";
    }

    $obj = RT::Group->new( $RT::SystemUser );
    $obj->LoadACLEquivalenceGroup( $self->PrincipalObj );
    if( $obj && defined $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related Principal #". $self->id ." object";
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
    if( $self->Name =~ /^(RT_System|Nobody)$/ ) {
        RT::Shredder::Exception::Info->throw('SystemObject');
    }
    return $self->SUPER::BeforeWipeout( @_ );
}

1;
