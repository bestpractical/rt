package RT::Shredder::Dependencies;

use strict;
use RT::Shredder::Exceptions;
use RT::Shredder::Constants;
use RT::Shredder::Dependency;
use RT::Record;



=head1 METHODS

=head2 new

Creates new empty collection of dependecies.

=cut

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->{'list'} = [];
    return $self;
}

=head2 _PushDependencies

Put in objects into collection.
Takes
BaseObject - any supported object of RT::Record subclass;
Flags - flags that describe relationship between target and base objects;
TargetObjects - any of RT::SearchBuilder or RT::Record subclassed objects
or array ref on list of this objects;
Shredder - RT::Shredder object.

SeeAlso: _PushDependecy, RT::Shredder::Dependency

=cut

sub _PushDependencies
{
    my $self = shift;
    my %args = ( TargetObjects => undef, Shredder => undef, @_ );
    my @objs = $args{'Shredder'}->CastObjectsToRecords( Objects => delete $args{'TargetObjects'} );
    $self->_PushDependency( %args, TargetObject => $_ ) foreach @objs;
    return;
}

sub _PushDependency
{
    my $self = shift;
    my %args = (
            BaseObject => undef,
            Flags => undef,
            TargetObject => undef,
            Shredder => undef,
            @_
           );
    my $rec = $args{'Shredder'}->PutObject( Object => $args{'TargetObject'} );
    return if $rec->{'State'} & WIPED; # there is no object anymore

    push @{ $self->{'list'} },
        RT::Shredder::Dependency->new(
            BaseObject => $args{'BaseObject'},
            Flags => $args{'Flags'},
            TargetObject => $rec->{'Object'},
        );

    if( scalar @{ $self->{'list'} } > ( $RT::DependenciesLimit || 1000 ) ) {
        RT::Shredder::Exception::Info->throw( 'DependenciesLimit' );
    }
    return;
}

=head2 List


=cut

sub List
{
    my $self = shift;
    my %args = (
        WithFlags => undef,
        WithoutFlags => undef,
        Callback => undef,
        @_
    );

    my $wflags = delete $args{'WithFlags'};
    my $woflags = delete $args{'WithoutFlags'};

    return
        map $args{'Callback'}? $args{'Callback'}->($_): $_,
        grep !defined( $wflags ) || ($_->Flags & $wflags) == $wflags,
        grep !defined( $woflags ) || !($_->Flags & $woflags),
        @{ $self->{'list'} };
}

1;
