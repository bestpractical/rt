use RT::Template ();
package RT::Template;

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

# Scrips
    my $objs = RT::Scrips->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Template', VALUE => $self->Id );
    push( @$list, $objs );

    $deps->_PushDependencies(
        BaseObject => $self,
        Flags => DEPENDS_ON,
        TargetObjects => $list,
        Shredder => $args{'Shredder'},
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

# Queue
    my $obj = $self->QueueObj;
    if( $obj && defined $obj->id ) {
        push( @$list, $obj );
    } else {
        my $rec = $args{'Shredder'}->GetRecord( Object => $self );
        $self = $rec->{'Object'};
        $rec->{'State'} |= INVALID;
        $rec->{'Description'} = "Have no related Queue #". $self->id ." object";
    }

# TODO: Users(Creator, LastUpdatedBy)

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => RELATES,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__Relates( %args );
}

1;
