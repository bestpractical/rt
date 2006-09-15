package RT::Shredder::Plugin::Objects;

use strict;
use warnings FATAL => 'all';
use base qw(RT::Shredder::Plugin::Base::Search);

use RT::Shredder;

=head1 NAME

RT::Shredder::Plugin::Objects - search plugin for wiping any selected object.

=head1 ARGUMENTS

This plugin searches and RT object you want, so you can use
the object name as argument and id as value, for example if
you want select ticket #123 then from CLI you write next
command:

  rt-shredder --plugin 'Objects=Ticket,123'

=cut

sub SupportArgs
{
    return $_[0]->SUPER::SupportArgs, @RT::Shredder::SUPPORTED_OBJECTS;
}

sub TestArgs
{
    my $self = shift;
    my %args = @_;

    my @strings;
    foreach my $name( @RT::Shredder::SUPPORTED_OBJECTS ) {
        next unless $args{$name};

        my $list = $args{$name};
        $list = [$list] unless UNIVERSAL::isa( $list, 'ARRAY' );
        push @strings, map "RT::$name\-$_", @$list;
    }

    my @objs = RT::Shredder->CastObjectsToRecords( Objects => \@strings );

    my @res = $self->SUPER::TestArgs( %args );

    $self->{'opt'}->{'objects'} = \@objs;

    return (@res);
}

sub Run
{
    my $self = shift;
    my %args = ( Shredder => undef, @_ );
    return (1, @{$self->{'opt'}->{'objects'}});
}

1;
