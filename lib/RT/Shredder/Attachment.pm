use RT::Attachment ();
package RT::Attachment;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RT::Shredder::Exceptions;
use RT::Shredder::Constants;
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

# Nested attachments
    my $objs = RT::Attachments->new( $self->CurrentUser );
    $objs->Limit(
            FIELD => 'Parent',
            OPERATOR        => '=',
            VALUE           => $self->Id
           );
    $objs->Limit(
            FIELD => 'id',
            OPERATOR        => '!=',
            VALUE           => $self->Id
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

# Parent, nested parts
    if( $self->Parent ) {
        if( $self->ParentObj && $self->ParentId ) {
            push( @$list, $self->ParentObj );
        } else {
            my $rec = $args{'Shredder'}->GetRecord( Object => $self );
            $self = $rec->{'Object'};
            $rec->{'State'} |= INVALID;
            $rec->{'Description'} = "Have no parent attachment #". $self->Parent ." object";
        }
    }

# Transaction
    my $obj = $self->TransactionObj;
    if( defined $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related transaction #". $self->TransactionId ." object";
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
