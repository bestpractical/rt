package RT::Shredder::Dependency;

use strict;
use RT::Shredder::Constants;
use RT::Shredder::Exceptions;

my %FlagDescs = (
    DEPENDS_ON, 'depends on',
    VARIABLE,   'resolvable dependency',
    WIPE_AFTER, 'delete after',
    RELATES,    'relates with',
);

sub new
{
    my $proto = shift;
    my $self = bless( {}, ref $proto || $proto );
    $self->Set( @_ );
    return $self;
}

sub Set
{
    my $self = shift;
    my %args = ( Flags => DEPENDS_ON, @_ );
    my @keys = qw(Flags BaseObject TargetObject);
    @$self{ @keys } = @args{ @keys };

    return;
}

sub AsString
{
    my $self = shift;
    my $res = $self->BaseObject->_AsString;
    $res .= " ". $self->FlagsAsString;
    $res .= " ". $self->TargetObject->_AsString;
    return $res;
}

sub Flags { return $_[0]->{'Flags'} }
sub FlagsAsString
{
    my $self = shift;
    my @res = ();
    foreach ( sort keys %FlagDescs ) {
        if( $self->Flags() & $_ ) {
            push( @res, $FlagDescs{ $_ } );
        }
    }
    push @res, 'no flags' unless( @res );
    return "(" . join( ',', @res ) . ")";
}


sub BaseObject { return $_[0]->{'BaseObject'} }
sub TargetObject { return $_[0]->{'TargetObject'} }
sub Object { return shift()->{ ({@_})->{Type}. "Object" } }

sub TargetClass { return ref $_[0]->{'TargetObject'} }
sub BaseClass {    return ref $_[0]->{'BaseObject'} }
sub Class { return ref shift()->Object( @_ ) }

1;
